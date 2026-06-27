//
//  ShieldConfigurationExtension.swift
//  Shield Configuration
//
//  Created by Nick Davis on 6/26/26.
//

import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        ShieldConfiguration(
            title: ShieldConfiguration.Label(text: "You're blocked.", color: .white),
            subtitle: ShieldConfiguration.Label(text: "Earn your way back in.", color: .lightGray),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Request unlock", color: .white),
            primaryButtonBackgroundColor: UIColor.systemOrange
        )
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        configuration(shielding: application)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        ShieldConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        ShieldConfiguration()
    }
}
