import SwiftUI
import FoundationModels
import Playgrounds

#Playground {
    let context = UnlockContext(
        appName: "Instagram",
        scheduleName: "Work Focus",
        blockReason: "Stay focused during work hours",
        unlocksToday: 5
    )

    let session = LanguageModelSession {
        Instructions(mascotSystemInstructions)
    }

    let response = try await session.respond(
        to: buildUnlockPrompt(userMessage: "i need to check something real quick", context: context),
        generating: MascotResponse.self
    )

    let mascot = response.content
    print("Dialogue: \(mascot.dialogue)")
    print("Unlock: \(mascot.shouldUnlock)")
    if let duration = mascot.unlockDurationMinutes {
        print("Duration: \(duration) min")
    }
    if let question = mascot.followUpQuestion {
        print("Follow-up: \(question)")
    }
}
