import ManagedSettings
import UserNotifications

class ShieldActionExtension: ShieldActionDelegate {
    private let sharedDefaults = UserDefaults(suiteName: "group.ndenterprises.Friction")!

    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            if let data = try? JSONEncoder().encode(application) {
                sharedDefaults.set("app", forKey: "pendingUnlockType")
                sharedDefaults.set(data, forKey: "pendingUnlockData")
            }
            writeActiveScheduleContext()
            fireNotification { completionHandler(.defer) }
        default:
            completionHandler(.close)
        }
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(.close)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            if let data = try? JSONEncoder().encode(category) {
                sharedDefaults.set("category", forKey: "pendingUnlockType")
                sharedDefaults.set(data, forKey: "pendingUnlockData")
            }
            writeActiveScheduleContext()
            fireNotification { completionHandler(.defer) }
        default:
            completionHandler(.close)
        }
    }

    private func writeActiveScheduleContext() {
        guard let data = sharedDefaults.data(forKey: "blockSchedules"),
              let schedules = try? JSONDecoder().decode([ScheduleInfo].self, from: data),
              let active = schedules.first(where: { $0.isCurrentlyActive() })
        else { return }
        sharedDefaults.set(active.name, forKey: "pendingScheduleName")
        sharedDefaults.set(active.reason, forKey: "pendingScheduleReason")
    }

    private func fireNotification(completion: @escaping () -> Void) {
        let content = UNMutableNotificationContent()
        content.title = "Time to earn it"
        content.body = "Tap to start the unlock ritual."
        content.sound = .default
        let request = UNNotificationRequest(identifier: "friction.unlock", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { _ in completion() }
    }
}

// Minimal decodable mirror of BlockSchedule — only the fields we need.
// JSONDecoder ignores unknown keys (like `selection`, `id`), so this works
// even though BlockSchedule has FamilyControls types we don't have access to here.
private struct ScheduleInfo: Decodable {
    var name: String
    var reason: String
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int
    var activeDays: Set<Int>
    var isEnabled: Bool

    func isCurrentlyActive() -> Bool {
        guard isEnabled else { return false }
        let cal = Calendar.current
        let now = Date()
        guard activeDays.contains(cal.component(.weekday, from: now)) else { return false }
        let nowM   = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        let startM = startHour * 60 + startMinute
        let endM   = endHour   * 60 + endMinute
        return nowM >= startM && nowM < endM
    }
}
