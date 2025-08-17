//
//  LibraryPanelManager.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/11/25.
//
//

import SwiftUI
import SwiftDataPacks

class LibraryPanelManager {
    private static var libraryPanel: NSPanel?
    private static let panelDelegate = PanelDelegate()
    private static var resignKeyObserver: Any?
    
    // This closure will be called when the panel is dismissed.
    private static var onDismiss: (() -> Void)?

    // Shows the panel if it's not already visible.
    public static func show(onDismiss: @escaping () -> Void) {
        guard libraryPanel == nil else { return }

        // Store the dismiss handler to be called later.
        self.onDismiss = onDismiss
        
        let panel = KeyActivatingPanel(
            contentRect: .zero,
            styleMask: [.borderless, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )

        panel.title = "Component Library"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.delegate = panelDelegate
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true

        
        let rootView = LibraryPanelView()
            .packContainer(for: [Component.self, Symbol.self, Footprint.self])
        
        let hostingController = NSHostingController(rootView: rootView)
        panel.contentViewController = hostingController

        self.resignKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { _ in
            panel.close()
        }
        
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        self.libraryPanel = panel
    }

    // Hides the panel if it's currently visible.
    public static func hide() {
        guard let panel = libraryPanel, panel.isVisible else { return }
        panel.close()
    }
    
    // Toggles the visibility of the panel.
    public static func toggle() {
        if let panel = libraryPanel, panel.isVisible {
            hide()
        } else if libraryPanel == nil {
            // When toggling, there's no specific view state to update on dismiss,
            // so we pass an empty closure.
            show(onDismiss: {})
        }
    }
    
    private class PanelDelegate: NSObject, NSWindowDelegate {
        func windowWillClose(_ notification: Notification) {
            if let observer = LibraryPanelManager.resignKeyObserver {
                NotificationCenter.default.removeObserver(observer)
                LibraryPanelManager.resignKeyObserver = nil
            }
            
            // Call the dismiss handler to update the binding in SwiftUI if it was provided.
            LibraryPanelManager.onDismiss?()

            // Clean up static properties.
            LibraryPanelManager.libraryPanel = nil
            LibraryPanelManager.onDismiss = nil
        }
    }
}
