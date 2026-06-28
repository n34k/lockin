import Foundation
import Combine
import ManagedSettings

class AppState: ObservableObject {
    static let shared = AppState()
    @Published var showingUnlock = false
    @Published var pendingUnlockApp: ApplicationToken? = nil
    @Published var pendingUnlockCategory: ActivityCategoryToken? = nil
    @Published var pendingAppName: String = ""
    @Published var pendingScheduleName: String = ""
    @Published var pendingScheduleReason: String = ""
}
