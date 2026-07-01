import Foundation
import FamilyControls
import DeviceActivity

let appGroupID = "group.ndenterprises.Friction"

struct UserProfile: Codable, Equatable {
    var name: String
    var age: Int
    var dailyWasteHours: Double
    var occupation: String
    var cutbackReason: String
}

extension DeviceActivityName {
    static let work = Self("friction.work")
    static let quickBlock = Self("friction.quickblock")

    static func schedule(id: UUID, weekday: Int) -> DeviceActivityName {
        Self("friction.schedule.\(id.uuidString).\(weekday)")
    }
}

/// A one-shot "Block Now" lockdown: starts immediately and runs for a fixed window,
/// instead of repeating weekly like `BlockSchedule`. While one is active it takes
/// precedence over schedules for the mascot prompt (Locky goes emergencies-only).
struct QuickBlock: Codable {
    var id: UUID = UUID()
    var startTime: Date
    var endTime: Date
    var selection: FamilyActivitySelection
    var reason: String = ""

    func isActive(at now: Date = Date()) -> Bool { now >= startTime && now < endTime }
    func remaining(at now: Date = Date()) -> TimeInterval { max(0, endTime.timeIntervalSince(now)) }
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
        name: String = "",
        startHour: Int = 9, startMinute: Int = 0,
        endHour: Int = 17, endMinute: Int = 0,
        activeDays: Set<Int> = [],
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
    private static let quickBlockKey = "quickBlock"
    private static let pendingTypeKey = "pendingUnlockType"
    private static let pendingDataKey = "pendingUnlockData"
    private static let pendingScheduleNameKey = "pendingScheduleName"
    private static let pendingScheduleReasonKey = "pendingScheduleReason"
    private static let pendingIsQuickBlockKey = "pendingIsQuickBlock"

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

    // MARK: - Quick block (one-shot "Block Now")

    static func saveQuickBlock(_ block: QuickBlock) {
        guard let data = try? JSONEncoder().encode(block) else { return }
        defaults.set(data, forKey: quickBlockKey)
    }

    static func loadQuickBlock() -> QuickBlock? {
        guard let data = defaults.data(forKey: quickBlockKey),
              let block = try? JSONDecoder().decode(QuickBlock.self, from: data)
        else { return nil }
        return block
    }

    static func clearQuickBlock() {
        defaults.removeObject(forKey: quickBlockKey)
    }

    /// Returns the stored quick block only while it's still running; an expired one is
    /// cleared as a side effect so callers never have to defend against stale blocks.
    static func activeQuickBlock(now: Date = Date()) -> QuickBlock? {
        guard let block = loadQuickBlock() else { return nil }
        guard block.isActive(at: now) else {
            clearQuickBlock()
            return nil
        }
        return block
    }

    static func savePendingIsQuickBlock(_ value: Bool) {
        defaults.set(value, forKey: pendingIsQuickBlockKey)
    }

    static func loadPendingIsQuickBlock() -> Bool {
        defaults.bool(forKey: pendingIsQuickBlockKey)
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

    private static let userProfileKey    = "userProfile"
    private static let onboardingDoneKey = "onboardingComplete"

    static func saveUserProfile(_ profile: UserProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: userProfileKey)
        defaults.set(true, forKey: onboardingDoneKey)
    }

    static func loadUserProfile() -> UserProfile? {
        guard let data = defaults.data(forKey: userProfileKey),
              let p = try? JSONDecoder().decode(UserProfile.self, from: data) else { return nil }
        return p
    }

    static var hasCompletedOnboarding: Bool {
        defaults.bool(forKey: onboardingDoneKey)
    }

    static func resetOnboarding() {
        defaults.removeObject(forKey: onboardingDoneKey)
        defaults.removeObject(forKey: userProfileKey)
        defaults.removeObject(forKey: unlockCountKey)
        defaults.removeObject(forKey: unlockCountDateKey)
    }

    // MARK: - Daily unlock counter
    // Drives the mascot's escalation: the more unlocks today, the more fed up Locky gets.
    // Stored in the App Group so the value is consistent across the main app and extensions.
    private static let unlockCountKey = "unlockCount"
    private static let unlockCountDateKey = "unlockCountDate"

    static func unlocksToday(now: Date = Date()) -> Int {
        let today = Calendar.current.startOfDay(for: now)
        guard let stored = defaults.object(forKey: unlockCountDateKey) as? Date,
              Calendar.current.isDate(stored, inSameDayAs: today)
        else { return 0 }
        return defaults.integer(forKey: unlockCountKey)
    }

    @discardableResult
    static func recordUnlockToday(now: Date = Date()) -> Int {
        let today = Calendar.current.startOfDay(for: now)
        let next = unlocksToday(now: now) + 1
        defaults.set(next, forKey: unlockCountKey)
        defaults.set(today, forKey: unlockCountDateKey)
        return next
    }

    static func clearPendingUnlock() {
        defaults.removeObject(forKey: pendingTypeKey)
        defaults.removeObject(forKey: pendingDataKey)
        defaults.removeObject(forKey: pendingScheduleNameKey)
        defaults.removeObject(forKey: pendingScheduleReasonKey)
        defaults.removeObject(forKey: pendingAppNameKey)
        defaults.removeObject(forKey: pendingIsQuickBlockKey)
    }
}
