//
//  ContentView.swift
//  Friction
//
//  Created by Nick Davis on 6/26/26.
//

import SwiftUI
import FamilyControls
import ManagedSettings

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    @State private var schedules = SharedState.loadSchedules()
    @State private var isAuthorized = false
    @State private var editingSchedule: BlockSchedule? = nil
    @State private var blockedApps: Set<ApplicationToken> = []
    @State private var blockedCategories: Set<ActivityCategoryToken> = []

    var body: some View {
        NavigationStack {
            Group {
                if !isAuthorized {
                    authPrompt
                } else {
                    scheduleList
                }
            }
            .navigationTitle("Friction")
            .toolbar {
                if isAuthorized {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Add", systemImage: "plus") {
                            editingSchedule = BlockSchedule()
                        }
                    }
                }
            }
        }
        .onAppear {
            isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
            ScheduleEngine.shared.apply(schedules)
            syncShields()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                schedules = SharedState.loadSchedules()
                syncShields()
            }
        }
        .sheet(item: $editingSchedule) { schedule in
            ScheduleEditorView(schedule: schedule) { updated in
                saveOrAppend(updated)
            }
        }
        .sheet(isPresented: $appState.showingUnlock) {
            UnlockView()
                .environmentObject(appState)
        }
    }

    @ViewBuilder
    private var authPrompt: some View {
        VStack(spacing: 16) {
            Text("Friction needs permission to block apps.")
                .multilineTextAlignment(.center)
            Button("Enable Friction") {
                Task {
                    try? await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                    isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    @ViewBuilder
    private var scheduleList: some View {
        if schedules.isEmpty {
            ContentUnavailableView(
                "No schedules",
                systemImage: "clock",
                description: Text("Tap + to add a blocking schedule.")
            )
        } else {
            List {
                if !blockedApps.isEmpty || !blockedCategories.isEmpty {
                    Section("Currently blocking") {
                        ForEach(Array(blockedApps), id: \.self) { token in
                            Button { initiateUnlock(app: token) } label: {
                                BlockedAppRow(token: token)
                            }
                        }
                        ForEach(Array(blockedCategories), id: \.self) { token in
                            Button { initiateUnlock(category: token) } label: {
                                BlockedCategoryRow(token: token)
                            }
                        }
                    }
                }

                Section("Schedules") {
                    ForEach(Array(schedules.enumerated()), id: \.element.id) { idx, schedule in
                        ScheduleRow(schedule: schedule, isActive: schedule.isCurrentlyActive()) {
                            editingSchedule = schedule
                        } onToggle: {
                            schedules[idx].isEnabled.toggle()
                            commit()
                        }
                    }
                    .onDelete { indexSet in
                        schedules.remove(atOffsets: indexSet)
                        commit()
                    }
                }
            }
        }
    }

    private func saveOrAppend(_ updated: BlockSchedule) {
        if let idx = schedules.firstIndex(where: { $0.id == updated.id }) {
            schedules[idx] = updated
        } else {
            schedules.append(updated)
        }
        commit()
    }

    private func commit() {
        SharedState.saveSchedules(schedules)
        ScheduleEngine.shared.apply(schedules)
        syncShields()
    }

    private func syncShields() {
        let store = ManagedSettingsStore()
        let active = schedules.filter { $0.isCurrentlyActive() }
        if active.isEmpty {
            store.shield.applications = nil
            store.shield.applicationCategories = nil
            blockedApps = []
            blockedCategories = []
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
        blockedApps = apps
        blockedCategories = categories
    }

    private func initiateUnlock(app: ApplicationToken) {
        let active = schedules.filter { $0.isCurrentlyActive() }
        let match = active.first { $0.selection.applicationTokens.contains(app) } ?? active.first
        appState.pendingUnlockApp = app
        appState.pendingUnlockCategory = nil
        appState.pendingAppName = SharedState.loadPendingAppName() ?? ""
        appState.pendingScheduleName = match?.name ?? ""
        appState.pendingScheduleReason = match?.reason ?? ""
        appState.showingUnlock = true
    }

    private func initiateUnlock(category: ActivityCategoryToken) {
        let active = schedules.filter { $0.isCurrentlyActive() }
        let match = active.first { $0.selection.categoryTokens.contains(category) } ?? active.first
        appState.pendingUnlockApp = nil
        appState.pendingUnlockCategory = category
        appState.pendingAppName = SharedState.loadPendingAppName() ?? ""
        appState.pendingScheduleName = match?.name ?? ""
        appState.pendingScheduleReason = match?.reason ?? ""
        appState.showingUnlock = true
    }
}

private struct ScheduleRow: View {
    let schedule: BlockSchedule
    let isActive: Bool
    let onTap: () -> Void
    let onToggle: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Active indicator dot
                Circle()
                    .fill(isActive ? .orange : .clear)
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut, value: isActive)

                VStack(alignment: .leading, spacing: 3) {
                    Text(schedule.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("\(schedule.daysSummary), \(schedule.timeSummary)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let summary = schedule.selectionSummary {
                        if isActive {
                            Text("Blocking now — \(summary)")
                                .font(.caption)
                                .foregroundStyle(Color.orange)
                        } else {
                            Text("\(summary) blocked")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { schedule.isEnabled },
                    set: { _ in onToggle() }
                ))
                .labelsHidden()
            }
        }
    }
}

private struct BlockedAppRow: View {
    let token: ApplicationToken

    var body: some View {
        HStack {
            Label(token)
                .foregroundStyle(.primary)
            Spacer()
            Text("Unlock")
                .font(.subheadline)
                .foregroundStyle(.orange)
        }
    }
}

private struct BlockedCategoryRow: View {
    let token: ActivityCategoryToken

    var body: some View {
        HStack {
            Label(token)
                .foregroundStyle(.primary)
            Spacer()
            Text("Unlock")
                .font(.subheadline)
                .foregroundStyle(.orange)
        }
    }
}

#Preview {
    ContentView()
}
