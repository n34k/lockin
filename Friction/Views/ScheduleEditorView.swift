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

                Section {
                    DatePicker("Start", selection: $startDate, displayedComponents: .hourAndMinute)
                    DatePicker("End",   selection: $endDate,   displayedComponents: .hourAndMinute)
                } header: {
                    Text("Blocking hours")
                } footer: {
                    if !endIsAfterStart {
                        Text("End time must be after the start time. Overnight schedules aren't supported yet.")
                            .foregroundStyle(.red)
                    }
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
                    .disabled(!canSave)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .familyActivityPicker(isPresented: $isPickerPresented, selection: $schedule.selection)
        }
    }

    private var canSave: Bool {
        !schedule.name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !schedule.activeDays.isEmpty &&
        (schedule.selection.applicationTokens.count + schedule.selection.categoryTokens.count) > 0 &&
        !schedule.reason.trimmingCharacters(in: .whitespaces).isEmpty &&
        endIsAfterStart
    }

    // Overnight (end-before-start) ranges aren't supported by isCurrentlyActive() or
    // DeviceActivitySchedule, so block them at the editor instead of silently misbehaving.
    private var endIsAfterStart: Bool {
        let cal = Calendar.current
        let startM = cal.component(.hour, from: startDate) * 60 + cal.component(.minute, from: startDate)
        let endM   = cal.component(.hour, from: endDate)   * 60 + cal.component(.minute, from: endDate)
        return endM > startM
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
