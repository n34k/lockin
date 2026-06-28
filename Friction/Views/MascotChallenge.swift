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
    @State private var session = LanguageModelSession {
        Instructions(mascotSystemInstructions)
    }

    init(onUnlock: @escaping (Int?) -> Void) {
        self.onUnlock = onUnlock
    }

    var body: some View {
        VStack(spacing: 24) {
            appLabel
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if isLoading && mascotDialogue == nil {
                ProgressView()
            } else if let dialogue = mascotDialogue {
                Text(dialogue)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }

            if let question = followUpQuestion {
                Text(question)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }

            if isLoading && mascotDialogue != nil {
                ProgressView()
            } else if !didUnlock && mascotDialogue != nil {
                VStack(spacing: 12) {
                    TextField("Give me a reason...", text: $userMessage, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3)
                        .padding(.horizontal, 32)

                    Button("Send it") {
                        Task { await sendMessage() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(userMessage.isEmpty)
                }
            }
        }
        .task { await resolveNameThenOpen() }
    }

    @ViewBuilder
    private var appLabel: some View {
        if let app = appState.pendingUnlockApp {
            Label(app)
        } else if let category = appState.pendingUnlockCategory {
            Label(category)
        } else {
            EmptyView()
        }
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
