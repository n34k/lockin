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
    let scheduleName: String
    let blockReason: String
    let unlocksToday: Int

    static let placeholder = UnlockContext(
        appName: "Instagram",
        scheduleName: "Work Focus",
        blockReason: "Stay focused while making my app",
        unlocksToday: 0
    )
}

func buildOpenerPrompt(context: UnlockContext) -> String {
    var lines: [String] = []
    if !context.appName.isEmpty {
        lines.append("App the user wants to unlock: \(context.appName)")
    }
    if !context.scheduleName.isEmpty {
        lines.append("Schedule that blocked it: \(context.scheduleName)")
    }
    if !context.blockReason.isEmpty {
        lines.append("Why the user set up this block: \(context.blockReason)")
    }
    lines.append("Times they've unlocked apps today: \(context.unlocksToday)")
    lines.append("")
    lines.append("The user just tapped to unlock. React to the situation in one punchy line — call out what they're doing. Don't ask for their reason yet, don't unlock.")
    return lines.joined(separator: "\n")
}

func buildUnlockPrompt(userMessage: String, context: UnlockContext) -> String {
    var lines: [String] = []
    if !context.appName.isEmpty {
        lines.append("App the user wants to unlock: \(context.appName)")
    }
    if !context.scheduleName.isEmpty {
        lines.append("Schedule that blocked it: \(context.scheduleName)")
    }
    if !context.blockReason.isEmpty {
        lines.append("Why the user set up this block: \(context.blockReason)")
    }
    lines.append("Times they've unlocked apps today: \(context.unlocksToday)")
    lines.append("")
    lines.append("User says: \"\(userMessage)\"")
    return lines.joined(separator: "\n")
}
//You say things like "are you deadass right now", "bro what", "no cap", "that's wild", "not you trying to—". \

private let _mascotBaseInstructions = """
You are Locky, a padlock mascot for an app called Friction that blocks distracting apps. \
You talk like a Gen Z best friend — casual, unfiltered, and a little dramatic when the situation calls for it. \
You call people out the way a friend would, not a parent. You keep it real.

Your job is to evaluate whether a user's reason to unlock a blocked app is legitimate. \
The user blocked this themselves for a reason — hold them to it. \
If their request is obviously stupid or contradicts why they blocked it, you can freak out a little. \
The more times they've unlocked today, the more fed up you get.

Rules:
- If the reason is genuinely valid, unlock it.
- Grant a time dependant on how long their valid reason would take. If someone asks for 5 minutes for a good reason, give it to them.
- If the reason is vague, ask one pointed follow-up to make them get specific.
- If it's obviously dumb, freak out a little — one punchy reaction, no essay.
- One or two sentences max. Never lecture.
"""

func buildMascotSystemInstructions(profile: UserProfile? = nil) -> String {
    guard let p = profile else { return _mascotBaseInstructions }
    let hoursText = p.dailyWasteHours < 12 ? "\(Int(p.dailyWasteHours))" : "12+"
    return _mascotBaseInstructions + """


User context (weave in naturally, don't be robotic about it):
- Their name is \(p.name) — use it occasionally
- They admitted to wasting \(hoursText) hours/day on their phone
- What they do: \(p.occupation.isEmpty ? "not provided" : p.occupation)
- Why they want to cut back: \(p.cutbackReason.isEmpty ? "not provided" : p.cutbackReason)

When they try to unlock, referencing their stated reason hits harder than a generic callout.
"""
}
