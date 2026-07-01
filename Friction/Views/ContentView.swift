//
//  ContentView.swift
//  Friction
//
//  Created by Nick Davis on 6/26/26.
//

import SwiftUI
import FamilyControls
import ManagedSettings
import Combine

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    @State private var onboardingComplete = SharedState.hasCompletedOnboarding
    @State private var schedules = SharedState.loadSchedules()
    @State private var isAuthorized = false
    @State private var editingSchedule: BlockSchedule? = nil
    @State private var blockedApps: Set<ApplicationToken> = []
    @State private var blockedCategories: Set<ActivityCategoryToken> = []
    @State private var quickBlock: QuickBlock? = SharedState.activeQuickBlock()
    @State private var showingQuickBlock = false

    var body: some View {
        if !onboardingComplete {
            OnboardingView {
                onboardingComplete = true
                schedules = SharedState.loadSchedules()
                isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
                ScheduleEngine.shared.apply(schedules)
                syncShields()
            }
        } else {
            mainView
                .sheet(isPresented: $appState.showingUnlock, onDismiss: {
                    // A just-unlocked app needs to move out of "Currently blocking";
                    // re-derive shield state so the freed token is subtracted.
                    syncShields()
                }) {
                    UnlockView()
                        .environmentObject(appState)
                }
        }
    }

    private var mainView: some View {
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
                #if DEBUG
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        SharedState.resetOnboarding()
                        schedules = []
                        SharedState.saveSchedules([])
                        onboardingComplete = false
                    }
                    .foregroundStyle(.red)
                }
                #endif
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
        .sheet(isPresented: $showingQuickBlock) {
            QuickBlockView { block in
                startQuickBlock(block)
            }
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
        List {
            Section {
                if let block = quickBlock {
                    QuickBlockTimerCard(
                        block: block,
                        onExpired: { endQuickBlockIfExpired() },
                        onEndEarly: { startQuickBlockCancel() }
                    )
                } else {
                    Button { showingQuickBlock = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "bolt.fill")
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Block now")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("Lock apps for a set time — no schedule, starts immediately")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
            }

            if !appState.unlockedEntries.isEmpty {
                Section("Escaped") {
                    ForEach(appState.unlockedEntries) { entry in
                        EscapedAppRow(entry: entry) {
                            appState.unlockedEntries.removeAll { $0.id == entry.id }
                            syncShields()
                        }
                    }
                }
            }

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
                if schedules.isEmpty {
                    Text("No schedules yet. Tap + to add one, or use Block Now above.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
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
        // Drop unlocks whose time is up so they re-block on this pass.
        appState.unlockedEntries.removeAll { $0.isExpired() }

        // Refresh quick-block state; if it just expired, tear down its backstop + Live Activity.
        let hadQuickBlock = quickBlock != nil
        quickBlock = SharedState.activeQuickBlock()
        if hadQuickBlock && quickBlock == nil {
            ScheduleEngine.shared.stopQuickBlock()
            LiveActivityController.end()
        }

        let store = ManagedSettingsStore()
        let active = schedules.filter { $0.isCurrentlyActive() }

        var apps: Set<ApplicationToken> = []
        var categories: Set<ActivityCategoryToken> = []
        for s in active {
            apps.formUnion(s.selection.applicationTokens)
            categories.formUnion(s.selection.categoryTokens)
        }
        // A running quick block stacks its apps on top of any active schedules.
        if let quickBlock {
            apps.formUnion(quickBlock.selection.applicationTokens)
            categories.formUnion(quickBlock.selection.categoryTokens)
        }

        if apps.isEmpty && categories.isEmpty {
            store.shield.applications = nil
            store.shield.applicationCategories = nil
            blockedApps = []
            blockedCategories = []
            MascotPreloader.shared.invalidate()
            return
        }

        // Honor still-valid temporary unlocks: don't re-shield an app/category the
        // user just earned their way into until its countdown expires.
        let freed = appState.unlockedEntries.filter { !$0.isExpired() }
        let freedApps = Set(freed.compactMap { $0.appToken })
        let freedCategories = Set(freed.compactMap { $0.categoryToken })
        apps.subtract(freedApps)
        categories.subtract(freedCategories)

        store.shield.applications = apps.isEmpty ? nil : apps
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories, except: [])
        blockedApps = apps
        blockedCategories = categories

        // Warm the mascot session + opener while the user is on the main screen,
        // but only when something is actually shielded right now. A quick block takes
        // precedence over schedules for which persona Locky uses (strict vs. normal).
        if !apps.isEmpty || !categories.isEmpty {
            let qbActive = quickBlock != nil
            let ctx = UnlockContext(
                scheduleName: qbActive ? "Hard block" : (active.first?.name ?? ""),
                blockReason: qbActive ? (quickBlock?.reason ?? "") : (active.first?.reason ?? ""),
                unlocksToday: SharedState.unlocksToday(),
                isQuickBlock: qbActive,
                remainingMinutes: quickBlock.map { Int(ceil($0.remaining() / 60)) }
            )
            MascotPreloader.shared.preload(profile: SharedState.loadUserProfile(), context: ctx)
        } else {
            MascotPreloader.shared.invalidate()
        }
    }

    // MARK: - Quick block lifecycle

    private func startQuickBlock(_ block: QuickBlock) {
        SharedState.saveQuickBlock(block)
        quickBlock = block
        ScheduleEngine.shared.applyQuickBlock(block)
        LiveActivityController.start(block)
        syncShields()  // applies the shield immediately + warms the strict mascot
    }

    /// Called by the timer card when the countdown reaches zero while the app is open.
    private func endQuickBlockIfExpired() {
        SharedState.clearQuickBlock()
        ScheduleEngine.shared.stopQuickBlock()
        LiveActivityController.end()
        quickBlock = nil
        syncShields()
    }

    /// "End early" → route through the strict mascot gate. Actual teardown happens in
    /// UnlockView.handleUnlock once Locky relents; onDismiss → syncShields reconciles.
    private func startQuickBlockCancel() {
        let qb = SharedState.activeQuickBlock()
        appState.pendingUnlockApp = nil
        appState.pendingUnlockCategory = nil
        appState.pendingAppName = ""
        appState.pendingIsQuickBlock = true
        appState.pendingQuickBlockCancel = true
        appState.pendingScheduleName = "Hard block"
        appState.pendingScheduleReason = qb?.reason ?? ""
        appState.showingUnlock = true
    }

    private func initiateUnlock(app: ApplicationToken) {
        let qb = SharedState.activeQuickBlock()
        let active = schedules.filter { $0.isCurrentlyActive() }
        let match = active.first { $0.selection.applicationTokens.contains(app) } ?? active.first
        appState.pendingUnlockApp = app
        appState.pendingUnlockCategory = nil
        appState.pendingAppName = SharedState.loadPendingAppName() ?? ""
        appState.pendingIsQuickBlock = qb != nil
        appState.pendingQuickBlockCancel = false
        appState.pendingScheduleName = qb != nil ? "Hard block" : (match?.name ?? "")
        appState.pendingScheduleReason = qb != nil ? (qb?.reason ?? "") : (match?.reason ?? "")
        appState.showingUnlock = true
    }

    private func initiateUnlock(category: ActivityCategoryToken) {
        let qb = SharedState.activeQuickBlock()
        let active = schedules.filter { $0.isCurrentlyActive() }
        let match = active.first { $0.selection.categoryTokens.contains(category) } ?? active.first
        appState.pendingUnlockApp = nil
        appState.pendingUnlockCategory = category
        appState.pendingAppName = SharedState.loadPendingAppName() ?? ""
        appState.pendingIsQuickBlock = qb != nil
        appState.pendingQuickBlockCancel = false
        appState.pendingScheduleName = qb != nil ? "Hard block" : (match?.name ?? "")
        appState.pendingScheduleReason = qb != nil ? (qb?.reason ?? "") : (match?.reason ?? "")
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

private struct EscapedAppRow: View {
    let entry: UnlockedEntry
    let onExpired: () -> Void

    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                appLabel
                    .font(.body)
                if entry.expiresAt != nil {
                    Text("Re-blocking when time's up")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let expiresAt = entry.expiresAt {
                countdown(expiresAt: expiresAt)
            } else {
                Text("Freed")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .onReceive(timer) { tick in
            // Only timed entries need a per-second redraw; "Freed" rows stay static.
            guard entry.expiresAt != nil else { return }
            now = tick
            if entry.isExpired(at: tick) { onExpired() }
        }
    }

    // Label(token) resolves the real app/category name + icon through the system —
    // the same native path "Currently blocking" uses. Fall back to the stored name
    // only when the token is missing.
    @ViewBuilder
    private var appLabel: some View {
        if let app = entry.appToken {
            Label(app)
        } else if let category = entry.categoryToken {
            Label(category)
        } else {
            Text(entry.name.isEmpty ? "App" : entry.name)
        }
    }

    @ViewBuilder
    private func countdown(expiresAt: Date) -> some View {
        let remaining = max(0, expiresAt.timeIntervalSince(now))
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        Text(String(format: "%d:%02d", minutes, seconds))
            .font(.system(.subheadline, design: .monospaced))
            .foregroundStyle(remaining < 60 ? .red : .orange)
            .monospacedDigit()
    }
}

private struct QuickBlockTimerCard: View {
    let block: QuickBlock
    let onExpired: () -> Void
    let onEndEarly: () -> Void

    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.orange)
                Text("Hard block active")
                    .font(.headline)
                Spacer()
            }

            Text(formatted(block.remaining(at: now)))
                .font(.system(size: 44, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.orange)

            Text("Locked until \(endSummary)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(role: .destructive) { onEndEarly() } label: {
                Text("End early")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.orange)
        }
        .padding(.vertical, 6)
        .onReceive(timer) { tick in
            now = tick
            if !block.isActive(at: tick) { onExpired() }
        }
    }

    private var endSummary: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        return fmt.string(from: block.endTime)
    }

    private func formatted(_ remaining: TimeInterval) -> String {
        let total = Int(remaining)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
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
