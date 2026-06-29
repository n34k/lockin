import SwiftUI
import ManagedSettings
import FamilyControls

// Swap this one line to change the unlock strategy:
typealias ActiveUnlockChallenge = MascotChallenge
// typealias ActiveUnlockChallenge = MathChallenge

protocol UnlockChallenge: View {
    init(onUnlock: @escaping (Int?) -> Void)
}

struct UnlockView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingSuccess = false
    @State private var unlockDuration: Int? = nil

    var body: some View {
        NavigationStack {
            Group {
                if showingSuccess {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(.green)
                        Text("Fine. You're in.")
                            .font(.title.bold())
                        if let duration = unlockDuration {
                            Text("You have \(duration) minute\(duration == 1 ? "" : "s").")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.scale.combined(with: .opacity))
                } else {
                    ActiveUnlockChallenge(onUnlock: handleUnlock)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
            .toolbar {
                if !showingSuccess {
                    ToolbarItem(placement: .topBarLeading) {
                        appLabel.font(.headline)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            appState.pendingUnlockApp = nil
                            appState.pendingUnlockCategory = nil
                            SharedState.clearPendingUnlock()
                            appState.showingUnlock = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(true)
    }

    @ViewBuilder
    private var appLabel: some View {
        if let app = appState.pendingUnlockApp {
            Label(app)
        } else if let category = appState.pendingUnlockCategory {
            Label(category)
        }
    }

    private func handleUnlock(_ duration: Int?) {
        unlockDuration = duration
        appState.recordUnlock(
            app: appState.pendingUnlockApp,
            category: appState.pendingUnlockCategory,
            name: appState.pendingAppName,
            duration: duration
        )
        unlockTargeted()
        withAnimation { showingSuccess = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            appState.showingUnlock = false
        }
    }

    private func unlockTargeted() {
        let store = ManagedSettingsStore()
        if let app = appState.pendingUnlockApp {
            store.shield.applications?.remove(app)
            appState.pendingUnlockApp = nil
        } else if let category = appState.pendingUnlockCategory {
            switch store.shield.applicationCategories {
            case .specific(let cats, let exceptions):
                let remaining = cats.subtracting([category])
                store.shield.applicationCategories = remaining.isEmpty ? nil : .specific(remaining, except: exceptions)
            default:
                store.shield.applicationCategories = nil
            }
            appState.pendingUnlockCategory = nil
        } else {
            store.shield.applications = nil
            store.shield.applicationCategories = nil
        }
        SharedState.clearPendingUnlock()
    }
}
