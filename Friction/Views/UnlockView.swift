import SwiftUI
import ManagedSettings

// Swap this one line to change the unlock strategy:
typealias ActiveUnlockChallenge = MascotChallenge
// typealias ActiveUnlockChallenge = MathChallenge

protocol UnlockChallenge: View {
    init(onUnlock: @escaping () -> Void)
}

struct UnlockView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingSuccess = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            if showingSuccess {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.green)
                    Text("Fine. You're in.")
                        .font(.title.bold())
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                ActiveUnlockChallenge(onUnlock: handleUnlock)
            }
            Spacer()
        }
        .padding()
        .interactiveDismissDisabled(true)
    }

    private func handleUnlock() {
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
