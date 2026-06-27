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
        guard let selection = SharedState.loadSelection(),
              !selection.applicationTokens.isEmpty else { return }
        store.shield.applications = selection.applicationTokens
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        store.shield.applications = nil
    }
}
