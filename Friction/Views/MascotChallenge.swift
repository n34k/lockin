import SwiftUI
import FoundationModels
import FamilyControls
import CoreHaptics

/// Drives the typewriter "clack" haptics with a single Core Haptics pattern per
/// line instead of repeated `UIImpactFeedbackGenerator.impactOccurred` calls.
/// Each `impactOccurred` sends its own message to the system haptic server, and
/// firing them throughout the animation trips the 32hz reporter limit, spamming
/// "Message send exceeds rate-limit threshold and will be dropped" in the log.
/// Pre-building all the taps into one pattern means a single message — no spam.
final class TypewriterHaptics {
    private let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    private var engine: CHHapticEngine?
    private var player: CHHapticPatternPlayer?

    init() {
        guard supportsHaptics else { return }
        engine = try? CHHapticEngine()
        engine?.isAutoShutdownEnabled = true
        engine?.resetHandler = { [weak self] in try? self?.engine?.start() }
    }

    /// Plays one transient tap every `everyN` characters, spaced `interval`
    /// apart, matching the visual typewriter cadence.
    func play(charCount: Int, everyN: Int, interval: TimeInterval, intensity: Float) {
        guard supportsHaptics, let engine else { return }
        stop()
        var events: [CHHapticEvent] = []
        var i = 0
        while i < charCount {
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5),
                ],
                relativeTime: Double(i) * interval
            ))
            i += everyN
        }
        guard !events.isEmpty else { return }
        do {
            try engine.start()
            let pattern = try CHHapticPattern(events: events, parameters: [])
            player = try engine.makePlayer(with: pattern)
            try player?.start(atTime: CHHapticTimeImmediate)
        } catch {
            // Haptics are non-essential; never let a failure break the animation.
        }
    }

    func stop() {
        try? player?.stop(atTime: CHHapticTimeImmediate)
        player = nil
    }
}

struct MascotChallenge: UnlockChallenge {
    let onUnlock: (Int?) -> Void

    @EnvironmentObject private var appState: AppState
    @State private var userMessage = ""
    @State private var mascotDialogue: String? = nil
    @State private var displayedDialogue: String = ""
    @State private var typingTask: Task<Void, Never>? = nil
    @State private var unlockTask: Task<Void, Never>? = nil
    @State private var isTyping: Bool = false
    @State private var haptics = TypewriterHaptics()
    @State private var followUpQuestion: String? = nil
    @State private var currentEmotion: MascotEmotion = .serious
    @State private var didUnlock = false
    @State private var isLoading = false
    @FocusState private var inputFocused: Bool
    @State private var session: LanguageModelSession?

    init(onUnlock: @escaping (Int?) -> Void) {
        self.onUnlock = onUnlock
    }

    var body: some View {
        VStack(spacing: 0) {
            // Pinned top: Locky image, fixed size, never moves
            Image(currentEmotion.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 160, height: 160)
                .animation(.spring(duration: 0.35), value: currentEmotion)
                .padding(.vertical, 12)

            // Flexible middle: generated text, scrollable on overflow
            ScrollView {
                VStack(spacing: 8) {
                    if isLoading && mascotDialogue == nil {
                        ProgressView()
                    } else if mascotDialogue != nil {
                        Text(displayedDialogue)
                            .font(.title3)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        if let question = followUpQuestion, !isTyping {
                            Text(question)
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .transition(.opacity)
                        }

                        if isLoading {
                            ProgressView()
                                .padding(.top, 4)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
            }
        }
        // Ignore keyboard so this section never shifts when keyboard opens
        .ignoresSafeArea(.keyboard)
        // Input lives outside the ignore scope — safeAreaInset sees keyboard and floats above it
        .safeAreaInset(edge: .bottom) {
            if !didUnlock {
                TextField("Give me a reason...", text: $userMessage)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
                    .focused($inputFocused)
                    .submitLabel(.send)
                    .onSubmit {
                        guard !userMessage.isEmpty && !isLoading else {
                            inputFocused = true
                            return
                        }
                        Task { await sendMessage() }
                        inputFocused = true
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
            }
        }
        .task {
            // Fast path: the main screen pre-warmed a session and pre-generated the
            // opener. Hand it off so the opener shows instantly and the model is hot.
            if let pair = MascotPreloader.shared.take() {
                session = pair.session
                isLoading = false
                withAnimation { currentEmotion = pair.opener.emotion }
                mascotDialogue = pair.opener.dialogue
                typewrite(pair.opener.dialogue)
                inputFocused = true
                return
            }
            // Fallback (e.g. reached via notification, or preload not finished): build
            // the session live and generate the opener now.
            let instructions = buildMascotSystemInstructions(
                profile: SharedState.loadUserProfile(),
                isQuickBlock: appState.pendingIsQuickBlock
            )
            #if DEBUG
            print("=== [Friction] SYSTEM INSTRUCTIONS ===\n\(instructions)\n=======================================")
            #endif
            session = LanguageModelSession { Instructions(instructions) }
            await fireOpener()
        }
        .onAppear { inputFocused = true }
        .onDisappear {
            typingTask?.cancel()
            unlockTask?.cancel()
            haptics.stop()
        }
    }

    private var unlockContext: UnlockContext {
        let remaining = SharedState.activeQuickBlock().map { Int(ceil($0.remaining() / 60)) }
        return UnlockContext(
            scheduleName: appState.pendingScheduleName,
            blockReason: appState.pendingScheduleReason,
            unlocksToday: SharedState.unlocksToday(),
            isQuickBlock: appState.pendingIsQuickBlock,
            remainingMinutes: remaining
        )
    }

    private func fireOpener() async {
        guard let session else { return }
        isLoading = true
        let openerPrompt = buildOpenerPrompt(context: unlockContext)
        #if DEBUG
        print("=== [Friction] OPENER PROMPT ===\n\(openerPrompt)\n================================")
        #endif
        let result = try? await session.respond(
            to: openerPrompt,
            generating: MascotResponse.self
        )
        isLoading = false
        if let content = result?.content {
            withAnimation { currentEmotion = content.emotion }
            mascotDialogue = content.dialogue
            typewrite(content.dialogue)
            inputFocused = true
        }
    }

    @MainActor
    private func typewrite(_ text: String) {
        typingTask?.cancel()
        displayedDialogue = ""
        isTyping = true
        let interval = 0.028
        haptics.play(charCount: text.count, everyN: 3, interval: interval, intensity: 0.35)
        typingTask = Task {
            for char in text {
                guard !Task.isCancelled else { break }
                displayedDialogue.append(char)
                try? await Task.sleep(for: .seconds(interval))
            }
            isTyping = false
        }
    }

    private func sendMessage() async {
        guard let session else { return }
        let message = userMessage
        userMessage = ""
        isLoading = true

        let unlockPrompt = buildUnlockPrompt(userMessage: message, context: unlockContext)
        #if DEBUG
        print("=== [Friction] UNLOCK PROMPT ===\n\(unlockPrompt)\n================================")
        #endif
        let result = try? await session.respond(
            to: unlockPrompt,
            generating: MascotResponse.self
        )

        isLoading = false
        inputFocused = true

        guard let content = result?.content else { return }

        withAnimation { currentEmotion = content.emotion }
        mascotDialogue = content.dialogue
        followUpQuestion = content.shouldUnlock ? nil : content.followUpQuestion
        typewrite(content.dialogue)

        if content.shouldUnlock {
            didUnlock = true
            // The model may grant an unlock without specifying a duration; never leave it
            // open-ended (that would be a permanent escape that never re-blocks).
            let minutes = content.unlockDurationMinutes.map { min(max($0, 1), 30) } ?? 5
            unlockTask?.cancel()
            unlockTask = Task {
                try? await Task.sleep(for: .seconds(1.2))
                guard !Task.isCancelled else { return }
                onUnlock(minutes)
            }
        }
    }
}
