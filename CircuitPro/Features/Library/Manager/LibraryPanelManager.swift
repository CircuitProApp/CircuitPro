//
//  LibraryPanelManager.swift
//  CircuitPro
//

import SwiftUI
import SwiftDataPacks
import AppKit

final class LibraryPanelManager {
    private static var libraryPanel: NSPanel?
    private static let panelDelegate = PanelDelegate()
    private static var resignKeyObserver: Any?
    private static var onDismiss: (() -> Void)?

    public static func show(onDismiss: @escaping () -> Void) {
        // If already created, just bring to front.
        if let panel = libraryPanel {
            self.onDismiss = onDismiss
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        self.onDismiss = onDismiss

        let initialSize = NSSize(width: 682, height: 373)
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let initialRect = NSRect(
            x: screenFrame.midX - initialSize.width / 2,
            y: screenFrame.midY - initialSize.height / 2,
            width: initialSize.width,
            height: initialSize.height
        )

        let panel = KeyActivatingPanel(
            contentRect: initialRect,
            styleMask: [
                .titled,
                .resizable,
                .fullSizeContentView
            ],
            backing: .buffered,
            defer: false
        )

        panel.title = "Component Library"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.delegate = panelDelegate
        panel.isReleasedWhenClosed = false

        // Titlebar chrome off (clean glass sheet look)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        // Important for glass/material windows
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true

        let rootView = LibraryPanelView()
            .packContainer(for: [ComponentDefinition.self, SymbolDefinition.self, FootprintDefinition.self])

        let hostingController = NSHostingController(rootView: rootView)


            let glass = NSGlassEffectView()
            glass.cornerRadius = 20
            glass.tintColor = nil

            // Make edge treatment smooth and ensure clipping matches radius.
            glass.wantsLayer = true
            glass.layer?.masksToBounds = true
            glass.layer?.cornerRadius = 20
            glass.layer?.cornerCurve = .continuous

            // Put SwiftUI inside the glass container.
            glass.contentView = hostingController.view
            panel.contentView = glass

        // Close when it loses key, like a palette.
        self.resignKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { _ in
            panel.close()
        }

        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.libraryPanel = panel
    }

    public static func hide() {
        guard let panel = libraryPanel else { return }
        panel.close()
    }

    public static func toggle() {
        if let panel = libraryPanel, panel.isVisible {
            hide()
        } else {
            show(onDismiss: {})
        }
    }

    private final class PanelDelegate: NSObject, NSWindowDelegate {
        func windowWillClose(_ notification: Notification) {
            if let observer = LibraryPanelManager.resignKeyObserver {
                NotificationCenter.default.removeObserver(observer)
                LibraryPanelManager.resignKeyObserver = nil
            }

            LibraryPanelManager.onDismiss?()
            LibraryPanelManager.onDismiss = nil
            LibraryPanelManager.libraryPanel = nil
        }
    }
}
