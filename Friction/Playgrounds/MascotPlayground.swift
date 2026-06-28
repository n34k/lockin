import SwiftUI
import FoundationModels
import Playgrounds

// MARK: - Structured output

@Generable
struct MascotResponse {
    @Guide(description: "Locky's spoken response — short, punchy, in character. No multi-paragraph rambling.")
    var dialogue: String

    @Guide(description: "Whether to grant access to the app right now.")
    var shouldUnlock: Bool

    @Guide(description: "Minutes to unlock the app for. Only set when shouldUnlock is true. Choose 5, 15, or 30 based on how legitimate the reason is.")
    var unlockDurationMinutes: Int?

    @Guide(description: "A pointed follow-up question to make the user justify themselves further. Only set when shouldUnlock is false.")
    var followUpQuestion: String?
}

// MARK: - Context

struct UnlockContext {
    let appName: String
    let userOccupation: String
    let unlocksToday: Int
    let blockReason: String
}

func buildPrompt(userMessage: String, context: UnlockContext) -> String {
    """
    App the user wants to unlock: \(context.appName)
    Why the user blocked this app: \(context.blockReason)
    User's occupation: \(context.userOccupation)
    Times they've unlocked apps today: \(context.unlocksToday)

    User says: "\(userMessage)"
    """
}

// MARK: - Playground

#Playground {
    let context = UnlockContext(
        appName: "Instagram",
        userOccupation: "Student",
        unlocksToday: 5,
        blockReason: "Stay focused during work hours"
    )

    let session = LanguageModelSession {
        Instructions("""
        You are Locky, a padlock mascot for an app called Friction that blocks distracting apps. \
        You talk like a Gen Z best friend — casual, unfiltered, and a little dramatic when the situation calls for it. \

        You call people out the way a friend would, not a parent. You keep it real but you're not mean about it.

        Your job is to evaluate whether a user's reason to unlock a blocked app is legitimate. \
        The user blocked this themselves for a reason — hold them to it. \
        If their request is obviously stupid or contradicts why they blocked it, you can freak out a little. \
        The more times they've unlocked today, the more fed up you get.

        Rules:
        - If the reason is genuinely valid, unlock it. Better reasons get more time (5, 15, or 30 min).
        - If the reason is vague, ask one pointed follow-up to make them get specific.
        - If it's obviously dumb, freak out a little — one punchy reaction, no essay.
        - One or two sentences max. Never lecture.
        """)
    }

    let response = try await session.respond(
        to: buildPrompt(userMessage: "i need to check something real quick", context: context),
        generating: MascotResponse.self
    )

    let mascot = response.content
//    print("Dialogue: \(mascot.dialogue)")
//    print("Unlock: \(mascot.shouldUnlock)")
//    if let duration = mascot.unlockDurationMinutes {
//        print("Duration: \(duration) min")
//    }
//    if let question = mascot.followUpQuestion {
//        print("Follow-up: \(question)")
//    }
}
