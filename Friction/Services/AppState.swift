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
    @Published var unlockedEntries: [UnlockedEntry] = []

    func recordUnlock(app: ApplicationToken?, category: ActivityCategoryToken?, name: String, duration: Int?) {
        let expiresAt = duration.map { Date().addingTimeInterval(TimeInterval($0 * 60)) }
        unlockedEntries.append(UnlockedEntry(appToken: app, categoryToken: category, name: name, expiresAt: expiresAt))
    }
}
