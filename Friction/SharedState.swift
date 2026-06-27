import Foundation
import FamilyControls
import DeviceActivity

let appGroupID = "group.ndenterprises.Friction"

extension DeviceActivityName {
    static let work = Self("friction.work")
}

enum SharedState {
    private static let defaults = UserDefaults(suiteName: appGroupID)!
    private static let selectionKey = "blockedApps"

    static func saveSelection(_ selection: FamilyActivitySelection) {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        defaults.set(data, forKey: selectionKey)
    }

    static func loadSelection() -> FamilyActivitySelection? {
        guard let data = defaults.data(forKey: selectionKey) else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }
}
