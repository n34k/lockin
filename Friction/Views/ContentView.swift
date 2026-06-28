//
//  ContentView.swift
//  Friction
//
//  Created by Nick Davis on 6/26/26.
//

import SwiftUI
import FamilyControls
import DeviceActivity
import ManagedSettings

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var isPickerPresented = false
    @State private var selection = FamilyActivitySelection()
    @State private var isAuthorized = false

    private let activityCenter = DeviceActivityCenter()

    var body: some View {
        VStack(spacing: 24) {
            if !isAuthorized {
                Text("Friction needs permission to block apps.")
                    .multilineTextAlignment(.center)
                Button("Enable Friction") {
                    Task {
                        try? await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
                    }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("Friction is active.")
                    .font(.headline)
                Text("\(selection.applicationTokens.count + selection.categoryTokens.count) item(s) blocked 9am–5pm")
                    .foregroundStyle(.secondary)
                Button("Change blocked apps") {
                    isPickerPresented = true
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .familyActivityPicker(isPresented: $isPickerPresented, selection: $selection)
        .onChange(of: selection) { _, newValue in
            SharedState.saveSelection(newValue)
            applyShieldNow(newValue)
            startMonitoring()
        }
        .onAppear {
            isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
        }
        .sheet(isPresented: $appState.showingUnlock) {
            UnlockView()
                .environmentObject(appState)
        }
    }

    private func applyShieldNow(_ selection: FamilyActivitySelection) {
        let store = ManagedSettingsStore()
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens, except: [])
    }

    private func startMonitoring() {
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 9, minute: 0),
            intervalEnd: DateComponents(hour: 17, minute: 0),
            repeats: true
        )
        activityCenter.stopMonitoring([.work])
        try? activityCenter.startMonitoring(.work, during: schedule)
    }
}

#Preview {
    ContentView()
}
