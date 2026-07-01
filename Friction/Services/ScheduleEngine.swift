import Foundation
import DeviceActivity

final class ScheduleEngine {
    static let shared = ScheduleEngine()
    private let center = DeviceActivityCenter()

    func apply(_ schedules: [BlockSchedule]) {
        // Stop every activity that could be registered — old or new — to ensure a clean slate.
        // We union the persisted (old) schedules and the incoming (new) ones so stale names get cleaned up.
        let persisted = SharedState.loadSchedules()
        let allRawNames = Set(
            (persisted + schedules).flatMap { s in
                (1...7).map { "friction.schedule.\(s.id.uuidString).\($0)" }
            } + ["friction.work"]
        )
        center.stopMonitoring(allRawNames.map { DeviceActivityName($0) })

        for schedule in schedules where schedule.isEnabled && !schedule.activeDays.isEmpty {
            for weekday in schedule.activeDays {
                let name = DeviceActivityName.schedule(id: schedule.id, weekday: weekday)
                let s = DeviceActivitySchedule(
                    intervalStart: DateComponents(
                        hour: schedule.startHour, minute: schedule.startMinute, weekday: weekday),
                    intervalEnd: DateComponents(
                        hour: schedule.endHour, minute: schedule.endMinute, weekday: weekday),
                    repeats: true
                )
                try? center.startMonitoring(name, during: s)
            }
        }
    }

    /// Backstop for a one-shot quick block: fires `intervalDidEnd` at the block's end
    /// time so the shield comes down even if the app is never reopened. The shield is
    /// applied directly and immediately at start time (the reliable synchronous path);
    /// this only guarantees teardown. Wall-clock based, so it shares the schedules'
    /// no-clean-overnight limitation — keep quick blocks short.
    func applyQuickBlock(_ qb: QuickBlock) {
        let cal = Calendar.current
        let s = DeviceActivitySchedule(
            intervalStart: cal.dateComponents([.hour, .minute, .second], from: qb.startTime),
            intervalEnd:   cal.dateComponents([.hour, .minute, .second], from: qb.endTime),
            repeats: false
        )
        try? center.startMonitoring(.quickBlock, during: s)
    }

    func stopQuickBlock() {
        center.stopMonitoring([.quickBlock])
    }
}
