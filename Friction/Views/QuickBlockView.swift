import SwiftUI
import FamilyControls

/// "Block Now" setup sheet: pick a duration and a set of apps, optionally a reason,
/// then start a one-shot hard block that runs from now until now + duration. The
/// caller (`ContentView`) does the actual applying via `onStart`.
struct QuickBlockView: View {
    var onStart: (QuickBlock) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var hours = 1
    @State private var minutes = 0
    @State private var selection = FamilyActivitySelection()
    @State private var reason = ""
    @State private var isPickerPresented = false

    // (label, hours, minutes)
    private let presets: [(String, Int, Int)] = [
        ("15m", 0, 15), ("30m", 0, 30), ("1h", 1, 0), ("2h", 2, 0), ("4h", 4, 0),
    ]

    private var totalMinutes: Int { hours * 60 + minutes }

    private var canStart: Bool {
        totalMinutes > 0 &&
        (selection.applicationTokens.count + selection.categoryTokens.count) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(presets, id: \.0) { preset in
                                let isOn = hours == preset.1 && minutes == preset.2
                                Button(preset.0) {
                                    hours = preset.1
                                    minutes = preset.2
                                }
                                .buttonStyle(.bordered)
                                .tint(isOn ? .orange : .secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    HStack(spacing: 0) {
                        Picker("Hours", selection: $hours) {
                            ForEach(0...12, id: \.self) { Text("\($0) h").tag($0) }
                        }
                        .pickerStyle(.wheel)
                        Picker("Minutes", selection: $minutes) {
                            ForEach([0, 5, 10, 15, 30, 45], id: \.self) { Text("\($0) m").tag($0) }
                        }
                        .pickerStyle(.wheel)
                    }
                    .frame(height: 120)
                } header: {
                    Text("Block for")
                } footer: {
                    if totalMinutes > 0 {
                        Text("Locks until \(endTimeSummary). Once it starts, getting back in early means getting past Locky — and during a hard block Locky only opens up for real emergencies.")
                    } else {
                        Text("Pick how long you want to be locked out.")
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.orange)
                            Text("Why are you locking in? (optional)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        Text("Locky will throw this back at you if you come crawling for an unlock.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("e.g. Deep work until this ships", text: $reason, axis: .vertical)
                            .lineLimit(2...4)
                            .padding(.top, 2)
                    }
                    .padding(.vertical, 4)
                }

                Section("Apps") {
                    Button {
                        isPickerPresented = true
                    } label: {
                        HStack {
                            Text("Choose apps")
                            Spacer()
                            if let summary = selectionSummary {
                                Text(summary)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Block Now")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        let now = Date()
                        let block = QuickBlock(
                            startTime: now,
                            endTime: now.addingTimeInterval(TimeInterval(totalMinutes * 60)),
                            selection: selection,
                            reason: reason
                        )
                        onStart(block)
                        dismiss()
                    }
                    .disabled(!canStart)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .familyActivityPicker(isPresented: $isPickerPresented, selection: $selection)
        }
    }

    private var endTimeSummary: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        let end = Date().addingTimeInterval(TimeInterval(totalMinutes * 60))
        return fmt.string(from: end)
    }

    private var selectionSummary: String? {
        let apps = selection.applicationTokens.count
        let cats = selection.categoryTokens.count
        guard apps > 0 || cats > 0 else { return nil }
        var parts: [String] = []
        if apps > 0 { parts.append("\(apps) app\(apps == 1 ? "" : "s")") }
        if cats > 0 { parts.append("\(cats) categor\(cats == 1 ? "y" : "ies")") }
        return parts.joined(separator: ", ")
    }
}
