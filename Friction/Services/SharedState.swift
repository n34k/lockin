import Foundation
import FamilyControls
import DeviceActivity

let appGroupID = "group.ndenterprises.Friction"

extension DeviceActivityName {
    static let work = Self("friction.work")

    static func schedule(for weekday: Int) -> DeviceActivityName {
        Self("friction.schedule.\(weekday)")
    }
}

struct BlockSchedule: Codable {
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int
    var activeDays: Set<Int>  // Calendar weekday: 1=Sun … 7=Sat
    var isEnabled: Bool

    static let `default` = BlockSchedule(
        startHour: 9, startMinute: 0,
        endHour: 17, endMinute: 0,
        activeDays: [2, 3, 4, 5, 6],  // Mon–Fri
        isEnabled: false
    )

    var displaySummary: String {
        guard isEnabled else { return "Schedule off" }
        let abbr = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let days = (1...7).filter { activeDays.contains($0) }.map { abbr[$0] }.joined(separator: " ")
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        let s = Calendar.current.date(from: DateComponents(hour: startHour, minute: startMinute))!
        let e = Calendar.current.date(from: DateComponents(hour: endHour,   minute: endMinute))!
        return "\(days), \(fmt.string(from: s)) – \(fmt.string(from: e))"
    }

    func isCurrentlyActive() -> Bool {
        guard isEnabled else { return false }
        let cal = Calendar.current
        let now = Date()
        guard activeDays.contains(cal.component(.weekday, from: now)) else { return false }
        let nowM   = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        let startM = startHour * 60 + startMinute
        let endM   = endHour   * 60 + endMinute
        return nowM >= startM && nowM < endM
    }
}

enum SharedState {
    private static let defaults = UserDefaults(suiteName: appGroupID)!
    private static let selectionKey = "blockedApps"
    private static let pendingTypeKey = "pendingUnlockType"
    private static let pendingDataKey = "pendingUnlockData"
    private static let scheduleKey = "blockSchedule"

    static func saveSelection(_ selection: FamilyActivitySelection) {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        defaults.set(data, forKey: selectionKey)
    }

    static func loadSelection() -> FamilyActivitySelection? {
        guard let data = defaults.data(forKey: selectionKey) else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    static func saveSchedule(_ schedule: BlockSchedule) {
        guard let data = try? JSONEncoder().encode(schedule) else { return }
        defaults.set(data, forKey: scheduleKey)
    }

    static func loadSchedule() -> BlockSchedule {
        guard let data = defaults.data(forKey: scheduleKey),
              let s = try? JSONDecoder().decode(BlockSchedule.self, from: data)
        else { return .default }
        return s
    }

    static func loadPendingUnlockType() -> String? {
        defaults.string(forKey: pendingTypeKey)
    }

    static func loadPendingUnlockData() -> Data? {
        defaults.data(forKey: pendingDataKey)
    }

    static func clearPendingUnlock() {
        defaults.removeObject(forKey: pendingTypeKey)
        defaults.removeObject(forKey: pendingDataKey)
    }
}
