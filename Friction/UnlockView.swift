import SwiftUI
import ManagedSettings

struct UnlockView: View {
    @EnvironmentObject var appState: AppState
    @State private var problem = MathProblem.random()
    @State private var answer = ""
    @State private var showingWrong = false
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
                    Text("Don't make it weird.")
                        .foregroundStyle(.secondary)
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                Text("Prove you mean it.")
                    .font(.title.bold())

                VStack(spacing: 8) {
                    Text("What is \(problem.a) + \(problem.b)?")
                        .font(.largeTitle)
                    Text("(yes, really)")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }

                TextField("Answer", text: $answer)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.title2)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 60)

                if showingWrong {
                    Text("Nope. Try again.")
                        .foregroundStyle(.red)
                        .transition(.opacity)
                }

                Button("Submit") {
                    if answer == "\(problem.a + problem.b)" {
                        unlockTargeted()
                        withAnimation { showingSuccess = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            appState.showingUnlock = false
                        }
                    } else {
                        withAnimation { showingWrong = true }
                        answer = ""
                        problem = MathProblem.random()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(answer.isEmpty)
            }

            Spacer()
        }
        .padding()
        .interactiveDismissDisabled(true)
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

private struct MathProblem {
    let a: Int
    let b: Int

    static func random() -> MathProblem {
        MathProblem(a: Int.random(in: 10...99), b: Int.random(in: 10...99))
    }
}
