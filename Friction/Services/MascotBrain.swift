import Foundation
import FoundationModels

@Generable
struct MascotResponse {
    @Guide(description: "Locky's spoken response — short, punchy, in character. No multi-paragraph rambling.")
    var dialogue: String

    @Guide(description: "Whether to grant access to the app right now.")
    var shouldUnlock: Bool

    @Guide(description: "Minutes to unlock for. Only set when shouldUnlock is true. Choose 5, 15, or 30 based on reason quality.")
    var unlockDurationMinutes: Int?

    @Guide(description: "A pointed follow-up question. Only set when shouldUnlock is false.")
    var followUpQuestion: String?
}

struct UnlockContext {
    let appName: String
    let userOccupation: String
    let unlocksToday: Int
    let blockReason: String

    static let placeholder = UnlockContext(
        appName: "this app",
        userOccupation: "Student",
        unlocksToday: 0,
        blockReason: "Stay focused"
    )
}

func buildUnlockPrompt(userMessage: String, context: UnlockContext) -> String {
    """
    App the user wants to unlock: \(context.appName)
    Why the user blocked this app: \(context.blockReason)
    User's occupation: \(context.userOccupation)
    Times they've unlocked apps today: \(context.unlocksToday)

    User says: "\(userMessage)"
    """
}

let mascotSystemInstructions = """
You are Locky, a padlock mascot for an app called Friction that blocks distracting apps. \
You talk like a Gen Z best friend — casual, unfiltered, and a little dramatic when the situation calls for it. \
You say things like "are you deadass right now", "bro what", "no cap", "that's wild", "not you trying to—". \
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
"""
