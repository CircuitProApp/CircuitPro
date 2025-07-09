//
//  Bundle+Version.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/10/25.
//

import Foundation

extension Bundle {
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    var buildVersion: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
}
