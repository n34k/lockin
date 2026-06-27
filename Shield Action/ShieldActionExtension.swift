import ManagedSettings
import UserNotifications

class ShieldActionExtension: ShieldActionDelegate {
    private let sharedDefaults = UserDefaults(suiteName: "group.ndenterprises.Friction")

    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            if let data = try? JSONEncoder().encode(application) {
                sharedDefaults?.set("app", forKey: "pendingUnlockType")
                sharedDefaults?.set(data, forKey: "pendingUnlockData")
            }
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
                sharedDefaults?.set("category", forKey: "pendingUnlockType")
                sharedDefaults?.set(data, forKey: "pendingUnlockData")
            }
            fireNotification { completionHandler(.defer) }
        default:
            completionHandler(.close)
        }
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
