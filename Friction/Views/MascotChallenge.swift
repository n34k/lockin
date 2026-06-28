import SwiftUI
import FoundationModels

struct MascotChallenge: UnlockChallenge {
    let onUnlock: () -> Void

    @State private var userMessage = ""
    @State private var mascotDialogue: String? = nil
    @State private var followUpQuestion: String? = nil
    @State private var didUnlock = false
    @State private var isLoading = false
    @State private var session = LanguageModelSession {
        Instructions(mascotSystemInstructions)
    }

    init(onUnlock: @escaping () -> Void) {
        self.onUnlock = onUnlock
    }

    var body: some View {
        VStack(spacing: 24) {
            if let dialogue = mascotDialogue {
                Text(dialogue)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            } else {
                Text("Why should I let you in?")
                    .font(.title.bold())
            }

            if let question = followUpQuestion {
                Text(question)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }

            if isLoading {
                ProgressView()
            } else if !didUnlock {
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
    }

    private func sendMessage() async {
        let message = userMessage
        userMessage = ""
        isLoading = true

        let result = try? await session.respond(
            to: buildUnlockPrompt(userMessage: message, context: .placeholder),
            generating: MascotResponse.self
        )

        isLoading = false

        guard let content = result?.content else { return }

        withAnimation { mascotDialogue = content.dialogue }
        followUpQuestion = content.shouldUnlock ? nil : content.followUpQuestion

        if content.shouldUnlock {
            didUnlock = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                onUnlock()
            }
        }
    }
}
