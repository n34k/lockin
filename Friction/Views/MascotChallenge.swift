import SwiftUI
import FoundationModels
import FamilyControls

struct MascotChallenge: UnlockChallenge {
    let onUnlock: (Int?) -> Void

    @EnvironmentObject private var appState: AppState
    @State private var userMessage = ""
    @State private var mascotDialogue: String? = nil
    @State private var displayedDialogue: String = ""
    @State private var typingTask: Task<Void, Never>? = nil
    @State private var isTyping: Bool = false
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
            let instructions = buildMascotSystemInstructions(profile: SharedState.loadUserProfile())
            print("=== [Friction] SYSTEM INSTRUCTIONS ===\n\(instructions)\n=======================================")
            session = LanguageModelSession { Instructions(instructions) }
            await resolveNameThenOpen()
        }
        .onAppear { inputFocused = true }
    }

    private var unlockContext: UnlockContext {
        UnlockContext(
            appName: appState.pendingAppName,
            scheduleName: appState.pendingScheduleName,
            blockReason: appState.pendingScheduleReason,
            unlocksToday: 0
        )
    }

    private func resolveNameThenOpen() async {
        if appState.pendingAppName.isEmpty {
            if let token = appState.pendingUnlockApp {
                appState.pendingAppName = await AppNameResolver.resolveName(for: token) ?? ""
            } else if let token = appState.pendingUnlockCategory {
                appState.pendingAppName = await AppNameResolver.resolveName(for: token) ?? ""
            }
        }
        await fireOpener()
    }

    private func fireOpener() async {
        guard let session else { return }
        isLoading = true
        let openerPrompt = buildOpenerPrompt(context: unlockContext)
        print("=== [Friction] OPENER PROMPT ===\n\(openerPrompt)\n================================")
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
        let haptic = UIImpactFeedbackGenerator(style: .light)
        haptic.prepare()
        typingTask = Task {
            for (i, char) in text.enumerated() {
                guard !Task.isCancelled else { break }
                displayedDialogue.append(char)
                if i % 3 == 0 {
                    haptic.impactOccurred(intensity: 0.35)
                }
                try? await Task.sleep(for: .milliseconds(28))
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
        print("=== [Friction] UNLOCK PROMPT ===\n\(unlockPrompt)\n================================")
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                onUnlock(content.unlockDurationMinutes)
            }
        }
    }
}
