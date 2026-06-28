import SwiftUI
import FoundationModels
import FamilyControls

struct MascotChallenge: UnlockChallenge {
    let onUnlock: (Int?) -> Void

    @EnvironmentObject private var appState: AppState
    @State private var userMessage = ""
    @State private var mascotDialogue: String? = nil
    @State private var followUpQuestion: String? = nil
    @State private var didUnlock = false
    @State private var isLoading = false
    @FocusState private var inputFocused: Bool
    @State private var session = LanguageModelSession {
        Instructions(mascotSystemInstructions)
    }

    init(onUnlock: @escaping (Int?) -> Void) {
        self.onUnlock = onUnlock
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                if isLoading && mascotDialogue == nil {
                    ProgressView()
                } else if let dialogue = mascotDialogue {
                    VStack(spacing: 10) {
                        Text(dialogue)
                            .font(.title3)
                            .multilineTextAlignment(.center)

                        if let question = followUpQuestion {
                            Text(question)
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .transition(.opacity)
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

            Spacer()
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
        let result = try? await session.respond(
            to: buildOpenerPrompt(context: unlockContext),
            generating: MascotResponse.self
        )
        isLoading = false
        if let dialogue = result?.content.dialogue {
            withAnimation { mascotDialogue = dialogue }
            inputFocused = true
        }
    }

    private func sendMessage() async {
        let message = userMessage
        userMessage = ""
        isLoading = true

        let result = try? await session.respond(
            to: buildUnlockPrompt(userMessage: message, context: unlockContext),
            generating: MascotResponse.self
        )

        isLoading = false

        guard let content = result?.content else { return }

        withAnimation { mascotDialogue = content.dialogue }
        followUpQuestion = content.shouldUnlock ? nil : content.followUpQuestion

        if content.shouldUnlock {
            didUnlock = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                onUnlock(content.unlockDurationMinutes)
            }
        }
    }
}
