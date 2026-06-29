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
    @State private var session: LanguageModelSession

    init(onUnlock: @escaping (Int?) -> Void) {
        self.onUnlock = onUnlock
        let instructions = buildMascotSystemInstructions(profile: SharedState.loadUserProfile())
        print("=== [Friction] SYSTEM INSTRUCTIONS ===\n\(instructions)\n=======================================")
        self._session = State(wrappedValue: LanguageModelSession {
            Instructions(instructions)
        })
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 20) {
                Image(currentEmotion.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 180)
                    .animation(.spring(duration: 0.35), value: currentEmotion)

                if isLoading && mascotDialogue == nil {
                    ProgressView()
                } else if mascotDialogue != nil {
                    VStack(spacing: 10) {
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
                    }
                }

                if !didUnlock && mascotDialogue != nil {
                    if isLoading {
                        ProgressView()
                    } else {
                        VStack(spacing: 14) {
                            TextField("Give me a reason...", text: $userMessage, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                                .lineLimit(4...8)
                                .focused($inputFocused)

                            Button("Send it") {
                                Task { await sendMessage() }
                            }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                            .disabled(userMessage.isEmpty)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 0)
        }
        .task { await resolveNameThenOpen() }
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
