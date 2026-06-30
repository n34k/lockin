import Foundation
import FoundationModels

/// Pre-warms the on-device model and pre-generates Locky's opener while the user
/// is still on the main screen, so the unlock sheet can show an opening line
/// instantly instead of cold-loading the model and generating on appear.
///
/// The opener is app-agnostic (no app name in context), so a single warmed
/// session + opener covers whichever blocked app the user taps. State is
/// consumed on use: `take()` hands off the warmed session and clears the cache
/// so the next `preload()` builds a fresh session — a `LanguageModelSession`
/// accumulates transcript, so reusing one would replay the prior conversation
/// and repeat the opener.
@MainActor
final class MascotPreloader {
    static let shared = MascotPreloader()
    private init() {}

    private(set) var session: LanguageModelSession?
    private(set) var opener: MascotResponse?
    private var prepareTask: Task<Void, Never>?
    private var builtProfile: UserProfile?

    var isReady: Bool { session != nil && opener != nil }

    /// Idempotent: no-op if a ready pair already exists or a build is already in
    /// flight. Rebuilds from scratch if the user's profile changed.
    func preload(profile: UserProfile?, context: UnlockContext) {
        if profile != builtProfile { invalidate() }
        guard !isReady, prepareTask == nil else { return }
        builtProfile = profile
        prepareTask = Task { [weak self] in
            let instructions = buildMascotSystemInstructions(profile: profile)
            let session = LanguageModelSession { Instructions(instructions) }
            session.prewarm()
            let result = try? await session.respond(
                to: buildOpenerPrompt(context: context),
                generating: MascotResponse.self
            )
            guard let self else { return }
            self.prepareTask = nil
            // Only publish a usable pair; on failure (e.g. model unavailable) leave
            // state empty so callers fall back to live generation.
            if let opener = result?.content {
                self.session = session
                self.opener = opener
                #if DEBUG
                print("=== [Friction] PRELOADED OPENER ===\n\(opener.dialogue)\n===================================")
                #endif
            }
        }
    }

    /// Hands off the warmed session + cached opener and clears state so the next
    /// `preload()` builds a fresh one. Returns nil if nothing is ready.
    func take() -> (session: LanguageModelSession, opener: MascotResponse)? {
        guard let session, let opener else { return nil }
        self.session = nil
        self.opener = nil
        return (session, opener)
    }

    /// Cancels any in-flight build and drops cached state.
    func invalidate() {
        prepareTask?.cancel()
        prepareTask = nil
        session = nil
        opener = nil
        builtProfile = nil
    }
}
