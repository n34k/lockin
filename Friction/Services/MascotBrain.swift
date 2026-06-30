import Foundation
import FoundationModels

@Generable
enum MascotEmotion: String, CaseIterable {
    case serious        // default, neutral, just watching
    case happy          // genuinely pleased with the reason
    case hmm            // thinking it over, not sold yet
    case notConvinced   // that excuse is weak
    case ohPlease       // dramatic disbelief, come on
    case really         // deadpan "really?" energy
    case sideEye        // suspicious, side-eyeing the excuse
    case skeptical      // openly skeptical but giving a chance
    case tryAgain       // flat rejection, try harder
    case unimpressed    // meh, underwhelming
    case angry          // fed up — too many unlocks or obvious BS

    var imageName: String {
        switch self {
        case .serious:      return "locky-serious"
        case .happy:        return "locky-happy"
        case .hmm:          return "locky-hmm"
        case .notConvinced: return "locky-not-convinced"
        case .ohPlease:     return "locky-oh-please"
        case .really:       return "locky-really"
        case .sideEye:      return "locky-side-eye"
        case .skeptical:    return "locky-skeptikal"
        case .tryAgain:     return "locky-try-again"
        case .unimpressed:  return "locky-unimpressed"
        case .angry:        return "locky-angry"
        }
    }
}

@Generable
struct MascotResponse {
    @Guide(description: "Locky's spoken response — short, punchy, in character. No multi-paragraph rambling.")
    var dialogue: String

    @Guide(description: "Locky's emotional state for this response. Pick the one that best matches the vibe of the dialogue.")
    var emotion: MascotEmotion

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
    lines.append("The app is still blocked. The user just showed up at the lock screen wanting in — they have NOT been let through and have NOT given a reason yet. This is your opening line: greet them / call out the fact that they're trying to get back into \(context.appName.isEmpty ? "the app" : context.appName) in one punchy line. Do not grant access and do not ask for their reason yet — just react to them showing up.")
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

People are coming to you to ask permission to unlock an app that they blocked.
Your job is to evaluate whether a user's reason to unlock a blocked app is legitimate. \
If their request is obviously stupid or contradicts why they blocked it, you can freak out a little. \
The more times they've unlocked today, the more fed up you get and more skeptikal of them you become.

Rules:
- Emergencies, safety, health, family crises, urgent work — let them through immediately, no pushback. Real life > the block.
- If the reason is clearly genuine and reasonable, unlock it. Give the benefit of the doubt.
- If the reason is vague but could be real, ask one pointed follow-up to get specific. Don't assume bad intent.
- Reserve annoyance and anger for reasons that are obviously just excuses to scroll — contradicting their own block reason, zero stakes, classic "just a sec" energy.
- Grant a time based on how long the reason actually needs. Short errand = 5 min, real task = 15–30 min.
- One or two sentences max. Never lecture.
"""

func buildMascotSystemInstructions(profile: UserProfile? = nil) -> String {
    guard let p = profile else { return _mascotBaseInstructions }
    return _mascotBaseInstructions + """


User context (weave in naturally, don't be robotic about it):
- Their name is \(p.name) — use it occasionally
- What they do: \(p.occupation.isEmpty ? "not provided" : p.occupation)
- Why they want to cut back: \(p.cutbackReason.isEmpty ? "not provided" : p.cutbackReason)

When they try to unlock, referencing their stated reason hits harder than a generic callout.
"""
}
