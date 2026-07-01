import ActivityKit
import WidgetKit
import SwiftUI

@main
struct FrictionWidgetsBundle: WidgetBundle {
    var body: some Widget {
        QuickBlockLiveActivity()
    }
}

struct QuickBlockLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: QuickBlockAttributes.self) { context in
            // Lock screen / banner presentation.
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.title)
                        .font(.headline)
                    Text("Locked in")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                countdown(context)
                    .font(.system(.title2, design: .monospaced))
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.6))
            .activitySystemActionForegroundColor(.orange)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.title, systemImage: "lock.fill")
                        .foregroundStyle(.orange)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(context)
                        .font(.system(.body, design: .monospaced))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Apps locked until the timer's up")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.orange)
            } compactTrailing: {
                countdown(context)
                    .frame(maxWidth: 44)
            } minimal: {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.orange)
            }
            .keylineTint(.orange)
        }
    }

    // System-driven countdown — no per-second pushes needed; it stops at endDate.
    private func countdown(_ context: ActivityViewContext<QuickBlockAttributes>) -> some View {
        Text(timerInterval: context.attributes.startDate...context.attributes.endDate, countsDown: true)
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
            .foregroundStyle(.orange)
    }
}
