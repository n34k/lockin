import Foundation
import Combine
import ManagedSettings
import FamilyControls

struct UnlockedEntry: Identifiable {
    let id = UUID()
    let appToken: ApplicationToken?
    let categoryToken: ActivityCategoryToken?
    let name: String
    let expiresAt: Date?

    func isExpired(at date: Date = Date()) -> Bool {
        guard let exp = expiresAt else { return false }
        return date >= exp
    }
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()
    @Published var showingUnlock = false
    @Published var pendingUnlockApp: ApplicationToken? = nil
    @Published var pendingUnlockCategory: ActivityCategoryToken? = nil
    @Published var pendingAppName: String = ""
    @Published var pendingScheduleName: String = ""
    @Published var pendingScheduleReason: String = ""
    // True when the pending unlock happens while a one-shot quick block is active —
    // flips Locky into the strict, emergencies-only persona.
    @Published var pendingIsQuickBlock = false
    // True when the pending unlock is a request to END the active quick block early
    // (rather than freeing a single app). Gated by the same strict mascot prompt.
    @Published var pendingQuickBlockCancel = false
    @Published var unlockedEntries: [UnlockedEntry] = []

    func recordUnlock(app: ApplicationToken?, category: ActivityCategoryToken?, name: String, duration: Int?) {
        let expiresAt = duration.map { Date().addingTimeInterval(TimeInterval($0 * 60)) }
        unlockedEntries.append(UnlockedEntry(appToken: app, categoryToken: category, name: name, expiresAt: expiresAt))
    }
}
