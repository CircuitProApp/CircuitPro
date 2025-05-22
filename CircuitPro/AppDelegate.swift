//
//  AppDelegate.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 22.05.25.
//
import AppKit
import Sparkle

final class AppDelegate: NSObject, NSApplicationDelegate {
    // starts Sparkle immediately
    let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
}
