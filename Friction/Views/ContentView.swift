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
    @State private var schedules = SharedState.loadSchedules()
    @State private var isAuthorized = false
    @State private var editingSchedule: BlockSchedule? = nil

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
                ForEach(Array(schedules.enumerated()), id: \.element.id) { idx, schedule in
                    ScheduleRow(schedule: schedule) {
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

private struct ScheduleRow: View {
    let schedule: BlockSchedule
    let onTap: () -> Void
    let onToggle: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(schedule.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("\(schedule.daysSummary), \(schedule.timeSummary)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let summary = schedule.selectionSummary {
                        Text("\(summary) blocked")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
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

#Preview {
    ContentView()
}
