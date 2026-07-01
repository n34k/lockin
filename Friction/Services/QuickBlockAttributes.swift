import ActivityKit
import Foundation

/// Shared between the main app (which starts/ends the Live Activity) and the
/// FrictionWidgets extension (which renders it). Add this file's target membership
/// to BOTH the Friction app and the FrictionWidgets extension.
///
/// The countdown is rendered with `Text(timerInterval:)`, which the system advances
/// on its own, so there's no per-second state to push — `ContentState` is empty and
/// the fixed window lives in the static attributes.
struct QuickBlockAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {}

    var title: String
    var startDate: Date
    var endDate: Date
}
