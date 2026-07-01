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

    private func isFrictionActivity(_ activity: DeviceActivityName) -> Bool {
        activity.rawValue.hasPrefix("friction.schedule.") || activity == .quickBlock
    }

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard isFrictionActivity(activity) else { return }
        applyActiveShields()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard isFrictionActivity(activity) else { return }
        // The quick block's window just closed — drop it so it stops contributing
        // shields on this (and any future) recompute.
        if activity == .quickBlock { SharedState.clearQuickBlock() }
        applyActiveShields()
    }

    private func applyActiveShields() {
        let active = SharedState.loadSchedules().filter { $0.isCurrentlyActive() }
        let quickBlock = SharedState.activeQuickBlock()

        var apps: Set<ApplicationToken> = []
        var categories: Set<ActivityCategoryToken> = []
        for s in active {
            apps.formUnion(s.selection.applicationTokens)
            categories.formUnion(s.selection.categoryTokens)
        }
        if let quickBlock {
            apps.formUnion(quickBlock.selection.applicationTokens)
            categories.formUnion(quickBlock.selection.categoryTokens)
        }

        store.shield.applications = apps.isEmpty ? nil : apps
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories, except: [])
    }
}
