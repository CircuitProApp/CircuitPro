//
//  Bundle+Info.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze 08/13/2025.
//

import Foundation

extension Bundle {

    static var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Unknown App"
    }

    static var displayName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        ?? "Unknown App"
    }

    static var copyrightString: String? {
        Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String
    }

    /// Returns the main bundle's version string if available (e.g. 1.0.0)
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    var buildVersion: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    static var versionPostfix: String? {
        Bundle.main.object(forInfoDictionaryKey: "CE_VERSION_POSTFIX") as? String
    }
}
