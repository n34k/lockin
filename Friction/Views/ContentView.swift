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
    @State private var schedule = SharedState.loadSchedule()
    @State private var showingScheduleEditor = false

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
                Text(schedule.displaySummary)
                    .foregroundStyle(.secondary)
                Button("Edit schedule") {
                    showingScheduleEditor = true
                }
                .buttonStyle(.bordered)
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
            syncShields()
        }
        .onAppear {
            isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
            if let saved = SharedState.loadSelection() { selection = saved }
            ScheduleEngine.shared.apply(schedule)
            syncShields()
        }
        .sheet(isPresented: $showingScheduleEditor) {
            ScheduleEditorView(schedule: $schedule) {
                SharedState.saveSchedule(schedule)
                ScheduleEngine.shared.apply(schedule)
                syncShields()
            }
        }
        .sheet(isPresented: $appState.showingUnlock) {
            UnlockView()
                .environmentObject(appState)
        }
    }

    private func syncShields() {
        let store = ManagedSettingsStore()
        if schedule.isCurrentlyActive() {
            let sel = SharedState.loadSelection()
            store.shield.applications = sel?.applicationTokens.isEmpty == false ? sel!.applicationTokens : nil
            store.shield.applicationCategories = sel?.categoryTokens.isEmpty == false
                ? .specific(sel!.categoryTokens, except: []) : nil
        } else {
            store.shield.applications = nil
            store.shield.applicationCategories = nil
        }
    }
}

#Preview {
    ContentView()
}
