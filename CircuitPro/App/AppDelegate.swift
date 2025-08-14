//
//  AppDelegate.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/14/25.
//

import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        // By returning false, we disable state restoration. The app will not
        // attempt to reopen windows that were open when it was last quit.
        // This ensures we always start with a clean slate (e.g., the Welcome Window).
        return false
    }
}
