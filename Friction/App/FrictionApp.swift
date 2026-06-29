import SwiftUI
import UserNotifications
import ManagedSettings

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.notification.request.identifier == "friction.unlock" {
            let type = SharedState.loadPendingUnlockType()
            let data = SharedState.loadPendingUnlockData()
            let scheduleContext = SharedState.loadPendingScheduleContext()
            let appName = SharedState.loadPendingAppName() ?? ""
            Task { @MainActor in
                let state = AppState.shared
                if let data {
                    if type == "app", let token = try? JSONDecoder().decode(ApplicationToken.self, from: data) {
                        state.pendingUnlockApp = token
                    } else if type == "category", let token = try? JSONDecoder().decode(ActivityCategoryToken.self, from: data) {
                        state.pendingUnlockCategory = token
                    }
                }
                state.pendingAppName = appName
                state.pendingScheduleName = scheduleContext.name
                state.pendingScheduleReason = scheduleContext.reason
                state.showingUnlock = true
            }
        }
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

@main
struct FrictionApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}
