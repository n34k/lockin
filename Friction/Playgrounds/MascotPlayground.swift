import SwiftUI
import FoundationModels
import Playgrounds

#Playground {
    let context = UnlockContext(
        scheduleName: "Work Focus",
        blockReason: "Stay focused during work hours",
        unlocksToday: 0
    )

    // Mirror the in-app flow: instructions are built with the user's profile.
    let profile = UserProfile(
        name: "Nick",
        age: 28,
        dailyWasteHours: 4,
        occupation: "indie app developer",
        cutbackReason: "ship my app instead of doomscrolling"
    )

    let session = LanguageModelSession {
        Instructions(buildMascotSystemInstructions(profile: profile))
    }

    // Step 1 — Locky reacts to the situation before the user says anything.
    let opener = try await session.respond(
        to: buildOpenerPrompt(context: context),
        generating: MascotResponse.self
    ).content
    print("=== OPENER ===")
    print("Emotion: \(opener.emotion)")
    print("Dialogue: \(opener.dialogue)")

    // Step 2 — The user pleads their case; Locky decides whether to unlock.
    let reply = try await session.respond(
        to: buildUnlockPrompt(userMessage: "i need to check something real quick", context: context),
        generating: MascotResponse.self
    ).content
    print("\n=== REPLY ===")
    print("Emotion: \(reply.emotion)")
    print("Dialogue: \(reply.dialogue)")
    print("Unlock: \(reply.shouldUnlock)")
    if let duration = reply.unlockDurationMinutes {
        print("Duration: \(duration) min")
    }
    if let question = reply.followUpQuestion {
        print("Follow-up: \(question)")
    }
}
