import Foundation
import DeviceActivity

final class ScheduleEngine {
    static let shared = ScheduleEngine()
    private let center = DeviceActivityCenter()

    private static let allNames: [DeviceActivityName] =
        (1...7).map { .schedule(for: $0) } + [.work]

    func apply(_ schedule: BlockSchedule) {
        center.stopMonitoring(Self.allNames)
        guard schedule.isEnabled && !schedule.activeDays.isEmpty else { return }
        for weekday in schedule.activeDays {
            let s = DeviceActivitySchedule(
                intervalStart: DateComponents(
                    hour: schedule.startHour, minute: schedule.startMinute, weekday: weekday),
                intervalEnd: DateComponents(
                    hour: schedule.endHour, minute: schedule.endMinute, weekday: weekday),
                repeats: true
            )
            try? center.startMonitoring(.schedule(for: weekday), during: s)
        }
    }
}
