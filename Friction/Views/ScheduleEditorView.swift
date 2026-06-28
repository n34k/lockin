import SwiftUI
import FamilyControls

struct ScheduleEditorView: View {
    @State private var schedule: BlockSchedule
    var onSave: (BlockSchedule) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isPickerPresented = false

    init(schedule: BlockSchedule, onSave: @escaping (BlockSchedule) -> Void) {
        _schedule = State(initialValue: schedule)
        self.onSave = onSave
        let cal = Calendar.current
        _startDate = State(initialValue: cal.date(from: DateComponents(
            hour: schedule.startHour, minute: schedule.startMinute)) ?? Date())
        _endDate = State(initialValue: cal.date(from: DateComponents(
            hour: schedule.endHour, minute: schedule.endMinute)) ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $schedule.name)
                    Toggle("Enabled", isOn: $schedule.isEnabled)
                }

                Section("Blocking hours") {
                    DatePicker("Start", selection: $startDate, displayedComponents: .hourAndMinute)
                    DatePicker("End",   selection: $endDate,   displayedComponents: .hourAndMinute)
                }
                .disabled(!schedule.isEnabled)

                Section("Days") {
                    DayToggleRow(activeDays: $schedule.activeDays)
                }
                .disabled(!schedule.isEnabled)

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.orange)
                            Text("Why are you blocking these apps?")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        Text("Loki will use this to call you out when you try to unlock. Be honest — vague reasons get less mercy.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("e.g. Stay off social media while I work", text: $schedule.reason, axis: .vertical)
                            .lineLimit(2...4)
                            .padding(.top, 2)
                    }
                    .padding(.vertical, 4)
                }
                .disabled(!schedule.isEnabled)

                Section("Apps") {
                    Button {
                        isPickerPresented = true
                    } label: {
                        HStack {
                            Text("Choose apps")
                            Spacer()
                            if let summary = schedule.selectionSummary {
                                Text(summary)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .disabled(!schedule.isEnabled)
            }
            .navigationTitle(schedule.name.isEmpty ? "New Schedule" : schedule.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        commitTimes()
                        onSave(schedule)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .familyActivityPicker(isPresented: $isPickerPresented, selection: $schedule.selection)
        }
    }

    private func commitTimes() {
        let cal = Calendar.current
        schedule.startHour   = cal.component(.hour,   from: startDate)
        schedule.startMinute = cal.component(.minute, from: startDate)
        schedule.endHour     = cal.component(.hour,   from: endDate)
        schedule.endMinute   = cal.component(.minute, from: endDate)
    }
}

private struct DayToggleRow: View {
    @Binding var activeDays: Set<Int>
    private let labels = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...7, id: \.self) { weekday in
                let active = activeDays.contains(weekday)
                Button(labels[weekday - 1]) {
                    if active { activeDays.remove(weekday) }
                    else      { activeDays.insert(weekday) }
                }
                .buttonStyle(.bordered)
                .tint(active ? .orange : .secondary)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 4)
    }
}
