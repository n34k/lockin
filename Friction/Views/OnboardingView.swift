import SwiftUI
import FamilyControls
import UserNotifications

struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var step = 0
    @State private var name = ""
    @State private var age = ""
    @State private var wasteHours: Double = 3
    @State private var selectedOccupations: Set<String> = []
    @State private var occupationOther = ""
    @State private var selectedReasons: Set<String> = []
    @State private var reasonOther = ""
    @State private var setupSubstep = 0
    @State private var showingScheduleEditor = false
    @State private var showImpactCTA = false

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var effectiveOccupation: String {
        var parts = selectedOccupations.sorted()
        let other = occupationOther.trimmingCharacters(in: .whitespaces)
        if !other.isEmpty { parts.append(other) }
        return parts.joined(separator: ", ")
    }
    private var effectiveReason: String {
        var parts = selectedReasons.sorted()
        let other = reasonOther.trimmingCharacters(in: .whitespaces)
        if !other.isEmpty { parts.append(other) }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        Group {
            switch step {
            case 0: nameScreen
            case 1: ageScreen
            case 2: wasteScreen
            case 3: occupationScreen
            case 4: reasonScreen
            case 5: impactScreen
            case 6: setupScreen
            case 7: doneScreen
            default: Color.clear
            }
        }
        .sheet(isPresented: $showingScheduleEditor) {
            ScheduleEditorView(schedule: BlockSchedule()) { saved in
                finishSetup(with: saved)
            }
        }
    }

    // MARK: - Screen 0: Name

    private var nameScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("What's your name?")
                .font(.largeTitle).bold()
            TextField("First name", text: $name)
                .textFieldStyle(.roundedBorder)
                .font(.title3)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
            Spacer()
            Button("Continue →") { step = 1 }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .disabled(trimmedName.isEmpty)
        }
        .padding(32)
    }

    // MARK: - Screen 1: Age

    private var ageScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("How old are you, \(trimmedName)?")
                .font(.largeTitle).bold()
                .multilineTextAlignment(.center)
            TextField("Age", text: $age)
                .textFieldStyle(.roundedBorder)
                .font(.title3)
                .keyboardType(.numberPad)
            Spacer()
            Button("Continue →") { step = 2 }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .disabled(Int(age) == nil)
        }
        .padding(32)
    }

    // MARK: - Screen 2: Daily Waste

    private var wasteScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 8) {
                Text("\(trimmedName), how much time do you waste on your phone each day?")
                    .font(.largeTitle).bold()
                    .multilineTextAlignment(.center)
                Text("Be honest. We won't judge. (We'll judge a little.)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            VStack(spacing: 12) {
                Text(wasteHours >= 12 ? "12+ hours" : "\(Int(wasteHours)) hour\(Int(wasteHours) == 1 ? "" : "s")")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                Slider(value: $wasteHours, in: 0...12, step: 0.5)
                Group {
                    if wasteHours >= 12 {
                        Text("We're glad you're here.")
                    } else if wasteHours >= 8 {
                        Text("okay. okay.")
                    } else if wasteHours >= 6 {
                        Text("That's basically a part-time job.")
                    } else {
                        Text(" ")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(height: 16)
            }
            Spacer()
            Button("Continue →") { step = 3 }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
        }
        .padding(32)
    }

    // MARK: - Screen 3: Occupation

    private let occupationOptions = ["Student", "Work from home", "Office job", "Parent", "Creative / freelance"]

    private var occupationScreen: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("What do you do?")
                        .font(.largeTitle).bold()
                    Text("Just so we know what you're supposed to be doing instead.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                VStack(spacing: 10) {
                    ForEach(occupationOptions, id: \.self) { option in
                        Button(option) {
                            if selectedOccupations.contains(option) {
                                selectedOccupations.remove(option)
                            } else {
                                selectedOccupations.insert(option)
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(selectedOccupations.contains(option) ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                    }
                }
                TextField("Other...", text: $occupationOther)
                    .textFieldStyle(.roundedBorder)
                Button("Continue →") { step = 4 }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .disabled(effectiveOccupation.isEmpty)
            }
            .padding(32)
        }
    }

    // MARK: - Screen 4: Cut-back reason

    private let reasonOptions = [
        "Wasting time I don't have",
        "It's affecting my work / school",
        "I want to be more present",
        "Feeling anxious or drained",
        "I just feel out of control"
    ]

    private var reasonScreen: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Why are you trying to cut back?")
                        .font(.largeTitle).bold()
                        .multilineTextAlignment(.center)
                    Text("You can just say it.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 10) {
                    ForEach(reasonOptions, id: \.self) { option in
                        Button(option) {
                            if selectedReasons.contains(option) {
                                selectedReasons.remove(option)
                            } else {
                                selectedReasons.insert(option)
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(selectedReasons.contains(option) ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                    }
                }
                TextField("Other...", text: $reasonOther)
                    .textFieldStyle(.roundedBorder)
                Button("Continue →") { step = 5 }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .disabled(effectiveReason.isEmpty)
            }
            .padding(32)
        }
    }

    // MARK: - Screen 5: Impact

    private var hoursPerYear: Int { Int(wasteHours * 365) }
    private var daysPerYear: Int { Int(wasteHours * 365 / 24) }

    private var impactScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("\(trimmedName), here's what that costs you.")
                .font(.largeTitle).bold()
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 10) {
                Text(wasteHours >= 12 ? "12+ hours a day" : "\(Int(wasteHours)) hour\(Int(wasteHours) == 1 ? "" : "s") a day")
                    .font(.title2)
                Text("That's \(hoursPerYear) hours a year.")
                    .font(.title2).bold()
                Text("That's **\(daysPerYear) days** you'll never get back.")
                    .font(.title2)
            }
            Text("That's longer than most people's vacations. Combined.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("Friction won't give those days back. But it'll make you actually think before you throw more away.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
            Spacer()
            if showImpactCTA {
                Button("Let's fix it →") { step = 6 }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .transition(.opacity)
            }
        }
        .padding(32)
        .onAppear {
            showImpactCTA = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { showImpactCTA = true }
            }
        }
    }

    // MARK: - Screen 6: Setup

    private var setupScreen: some View {
        Group {
            switch setupSubstep {
            case 0: notificationsSetup
            case 1: screenTimeSetup
            case 2: scheduleCreationStep
            default: Color.clear
            }
        }
    }

    private var notificationsSetup: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("We need to be able to tap you on the shoulder.")
                .font(.title).bold()
                .multilineTextAlignment(.center)
            Button("Allow Notifications") {
                Task {
                    _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                    await MainActor.run { setupSubstep = 1 }
                }
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            Spacer()
        }
        .padding(32)
    }

    private var screenTimeSetup: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("This is the part where you give us the keys.")
                .font(.title).bold()
                .multilineTextAlignment(.center)
            Button("Enable Screen Time Access") {
                Task {
                    try? await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                    await MainActor.run { setupSubstep = 2 }
                }
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            Spacer()
        }
        .padding(32)
    }

    private var scheduleCreationStep: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Let's set up your first schedule.")
                .font(.title).bold()
                .multilineTextAlignment(.center)
            Text("You can always add more from the app later.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Create Schedule →") { showingScheduleEditor = true }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            Spacer()
        }
        .padding(32)
    }

    // MARK: - Screen 7: Done

    private var doneScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("You're ready, \(trimmedName).")
                .font(.largeTitle).bold()
                .multilineTextAlignment(.center)
            Text("Next time you reach for one of those apps, we'll be there.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Got it →") { onComplete() }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
        }
        .padding(32)
    }

    // MARK: - Completion

    private func finishSetup(with schedule: BlockSchedule) {
        let profile = UserProfile(
            name: trimmedName,
            age: Int(age) ?? 0,
            dailyWasteHours: wasteHours,
            occupation: effectiveOccupation,
            cutbackReason: effectiveReason
        )
        SharedState.saveUserProfile(profile)

        var schedules = SharedState.loadSchedules()
        schedules.append(schedule)
        SharedState.saveSchedules(schedules)

        step = 7
    }
}
