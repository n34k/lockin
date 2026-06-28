//
//  DeviceActivityMonitorExtension.swift
//  Device Activity Monitor
//
//  Created by Nick Davis on 6/26/26.
//

import DeviceActivity
import ManagedSettings
import FamilyControls

class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let store = ManagedSettingsStore()

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard activity.rawValue.hasPrefix("friction.schedule.") else { return }
        applyActiveShields()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity.rawValue.hasPrefix("friction.schedule.") else { return }
        applyActiveShields()
    }

    private func applyActiveShields() {
        let active = SharedState.loadSchedules().filter { $0.isCurrentlyActive() }
        if active.isEmpty {
            store.shield.applications = nil
            store.shield.applicationCategories = nil
            return
        }
        var apps: Set<ApplicationToken> = []
        var categories: Set<ActivityCategoryToken> = []
        for s in active {
            apps.formUnion(s.selection.applicationTokens)
            categories.formUnion(s.selection.categoryTokens)
        }
        store.shield.applications = apps.isEmpty ? nil : apps
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories, except: [])
    }
}
