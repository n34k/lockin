import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    private let sharedDefaults = UserDefaults(suiteName: "group.ndenterprises.Friction")!

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        if let name = application.localizedDisplayName {
            sharedDefaults.set(name, forKey: "pendingAppName")
        }
        return ShieldConfiguration(
            title: ShieldConfiguration.Label(text: "You're blocked.", color: .white),
            subtitle: ShieldConfiguration.Label(text: "Earn your way back in.", color: .lightGray),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Request unlock", color: .white),
            primaryButtonBackgroundColor: UIColor.systemOrange
        )
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        if let name = application.localizedDisplayName {
            sharedDefaults.set(name, forKey: "pendingAppName")
        } else if let name = category.localizedDisplayName {
            sharedDefaults.set(name, forKey: "pendingAppName")
        }
        return configuration(shielding: application)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        ShieldConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        ShieldConfiguration()
    }
}
