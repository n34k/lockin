//
//  ShieldActionExtension.swift
//  Shield Action
//
//  Created by Nick Davis on 6/26/26.
//

import ManagedSettings
import UserNotifications

class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            let content = UNMutableNotificationContent()
            content.title = "Time to earn it"
            content.body = "Tap to start the unlock ritual."
            content.sound = .default
            let request = UNNotificationRequest(identifier: "friction.unlock", content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request) { _ in
                completionHandler(.defer)
            }
        case .secondaryButtonPressed:
            completionHandler(.close)
        default:
            completionHandler(.close)
        }
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(.close)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(.close)
    }
}
