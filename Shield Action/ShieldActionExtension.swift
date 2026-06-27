//
//  ShieldActionExtension.swift
//  Shield Action
//
//  Created by Nick Davis on 6/26/26.
//

import ManagedSettings

class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            // Phase 1: remove shield directly for testing. Phase 2: fire a notification instead.
            ManagedSettingsStore().shield.applications = nil
            completionHandler(.close)
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
