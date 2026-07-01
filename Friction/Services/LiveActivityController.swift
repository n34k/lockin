import ActivityKit
import Foundation

/// Manages the single "Block Now" Live Activity from the main app. The Device Activity
/// monitor extension never touches ActivityKit (it runs in a separate process); the
/// timer-interval countdown completes on its own at `endDate`, and the app tears the
/// activity down here when the quick block is cleared (expiry seen on foreground, or
/// an early cancel).
enum LiveActivityController {
    static func start(_ qb: QuickBlock) {
        // Only ever one hard-block activity at a time.
        end()
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = QuickBlockAttributes(
            title: "Hard block",
            startDate: qb.startTime,
            endDate: qb.endTime
        )
        let content = ActivityContent(
            state: QuickBlockAttributes.ContentState(),
            staleDate: qb.endTime
        )
        _ = try? Activity.request(attributes: attributes, content: content, pushType: nil)
    }

    static func end() {
        for activity in Activity<QuickBlockAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
