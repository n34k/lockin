import SwiftUI

struct MathChallenge: UnlockChallenge {
    let onUnlock: (Int?) -> Void

    @State private var problem = MathProblem.random()
    @State private var answer = ""
    @State private var showingWrong = false

    init(onUnlock: @escaping (Int?) -> Void) {
        self.onUnlock = onUnlock
    }

    var body: some View {
        VStack(spacing: 32) {
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
                    onUnlock(nil)
                } else {
                    withAnimation { showingWrong = true }
                    answer = ""
                    problem = MathProblem.random()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(answer.isEmpty)
        }
    }
}

private struct MathProblem {
    let a: Int
    let b: Int

    static func random() -> MathProblem {
        MathProblem(a: Int.random(in: 10...99), b: Int.random(in: 10...99))
    }
}
