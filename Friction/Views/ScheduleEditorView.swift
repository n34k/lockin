import SwiftUI

struct ScheduleEditorView: View {
    @Binding var schedule: BlockSchedule
    var onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var startDate: Date
    @State private var endDate: Date

    init(schedule: Binding<BlockSchedule>, onSave: @escaping () -> Void) {
        _schedule = schedule
        self.onSave = onSave
        let cal = Calendar.current
        _startDate = State(initialValue: cal.date(from: DateComponents(
            hour: schedule.wrappedValue.startHour,
            minute: schedule.wrappedValue.startMinute)) ?? Date())
        _endDate = State(initialValue: cal.date(from: DateComponents(
            hour: schedule.wrappedValue.endHour,
            minute: schedule.wrappedValue.endMinute)) ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Enable schedule", isOn: $schedule.isEnabled)
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
            }
            .navigationTitle("Block schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        commitTimes()
                        onSave()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
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
