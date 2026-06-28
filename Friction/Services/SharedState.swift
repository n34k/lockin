import Foundation
import FamilyControls
import DeviceActivity

let appGroupID = "group.ndenterprises.Friction"

extension DeviceActivityName {
    static let work = Self("friction.work")

    static func schedule(id: UUID, weekday: Int) -> DeviceActivityName {
        Self("friction.schedule.\(id.uuidString).\(weekday)")
    }
}

struct BlockSchedule: Codable, Identifiable {
    var id: UUID
    var name: String
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int
    var activeDays: Set<Int>  // Calendar weekday: 1=Sun … 7=Sat
    var isEnabled: Bool
    var selection: FamilyActivitySelection

    // Why the user is blocking apps during this schedule.
    // Loki reads this to hold them accountable when they try to unlock.
    var reason: String

    init(
        id: UUID = UUID(),
        name: String = "New Schedule",
        startHour: Int = 9, startMinute: Int = 0,
        endHour: Int = 17, endMinute: Int = 0,
        activeDays: Set<Int> = [2, 3, 4, 5, 6],
        isEnabled: Bool = true,
        selection: FamilyActivitySelection = FamilyActivitySelection(),
        reason: String = ""
    ) {
        self.id = id
        self.name = name
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.activeDays = activeDays
        self.isEnabled = isEnabled
        self.selection = selection
        self.reason = reason
    }

    var timeSummary: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        let s = Calendar.current.date(from: DateComponents(hour: startHour, minute: startMinute))!
        let e = Calendar.current.date(from: DateComponents(hour: endHour,   minute: endMinute))!
        return "\(fmt.string(from: s)) – \(fmt.string(from: e))"
    }

    var daysSummary: String {
        if activeDays.count == 7 { return "Every day" }
        if activeDays == [2, 3, 4, 5, 6] { return "Weekdays" }
        if activeDays == [1, 7] { return "Weekends" }
        let abbr = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return (1...7).filter { activeDays.contains($0) }.map { abbr[$0] }.joined(separator: " ")
    }

    var selectionSummary: String? {
        let apps = selection.applicationTokens.count
        let cats = selection.categoryTokens.count
        guard apps > 0 || cats > 0 else { return nil }
        var parts: [String] = []
        if apps > 0 { parts.append("\(apps) app\(apps == 1 ? "" : "s")") }
        if cats > 0 { parts.append("\(cats) categor\(cats == 1 ? "y" : "ies")") }
        return parts.joined(separator: ", ")
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
    private static let schedulesKey = "blockSchedules"
    private static let pendingTypeKey = "pendingUnlockType"
    private static let pendingDataKey = "pendingUnlockData"
    private static let pendingScheduleNameKey = "pendingScheduleName"
    private static let pendingScheduleReasonKey = "pendingScheduleReason"

    static func saveSchedules(_ schedules: [BlockSchedule]) {
        guard let data = try? JSONEncoder().encode(schedules) else { return }
        defaults.set(data, forKey: schedulesKey)
    }

    static func loadSchedules() -> [BlockSchedule] {
        guard let data = defaults.data(forKey: schedulesKey),
              let schedules = try? JSONDecoder().decode([BlockSchedule].self, from: data)
        else { return [] }
        return schedules
    }

    static func loadPendingUnlockType() -> String? {
        defaults.string(forKey: pendingTypeKey)
    }

    static func loadPendingUnlockData() -> Data? {
        defaults.data(forKey: pendingDataKey)
    }

    // Written by ShieldConfigurationExtension, which receives the full Application
    // object (with localizedDisplayName populated by the system) before ShieldAction fires.
    private static let pendingAppNameKey = "pendingAppName"

    static func savePendingAppName(_ name: String) {
        defaults.set(name, forKey: pendingAppNameKey)
    }

    static func loadPendingAppName() -> String? {
        defaults.string(forKey: pendingAppNameKey)
    }

    static func savePendingScheduleContext(name: String, reason: String) {
        defaults.set(name, forKey: pendingScheduleNameKey)
        defaults.set(reason, forKey: pendingScheduleReasonKey)
    }

    static func loadPendingScheduleContext() -> (name: String, reason: String) {
        let name = defaults.string(forKey: pendingScheduleNameKey) ?? ""
        let reason = defaults.string(forKey: pendingScheduleReasonKey) ?? ""
        return (name, reason)
    }

    static func clearPendingUnlock() {
        defaults.removeObject(forKey: pendingTypeKey)
        defaults.removeObject(forKey: pendingDataKey)
        defaults.removeObject(forKey: pendingScheduleNameKey)
        defaults.removeObject(forKey: pendingScheduleReasonKey)
        defaults.removeObject(forKey: pendingAppNameKey)
    }
}
