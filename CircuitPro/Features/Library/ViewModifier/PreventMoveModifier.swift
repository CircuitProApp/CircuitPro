//
//  PreventMoveModifier.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/12/25.
//

import SwiftUI

/// A view modifier that prevents a click-and-drag gesture on its content from moving the parent window,
/// even when the window has `isMovableByWindowBackground` set to `true`.
///
/// This is useful for enabling drag-and-drop on custom views inside a panel that should also be movable.
/// It works by wrapping the SwiftUI content in a custom `NSView` that overrides `mouseDownCanMoveWindow`.
struct PreventMoveModifier: ViewModifier {
    func body(content: Content) -> some View {
        Representable(content: content)
    }

    // A private NSViewRepresentable to host our SwiftUI content.
    private struct Representable: NSViewRepresentable {
        let content: Content

        func makeNSView(context: Context) -> NSView {
            // Create an instance of our custom view that blocks window movement.
            let view = NonMovableNSView()
            
            // Host the SwiftUI content inside an NSHostingView.
            let hostingView = NSHostingView(rootView: content)
            hostingView.translatesAutoresizingMaskIntoConstraints = false
            
            // Add the hosting view as a subview.
            view.addSubview(hostingView)
            
            // Ensure the hosting view fills our custom view completely.
            NSLayoutConstraint.activate([
                hostingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                hostingView.topAnchor.constraint(equalTo: view.topAnchor),
                hostingView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            
            return view
        }

        func updateNSView(_ nsView: NSView, context: Context) {
            // Find the NSHostingView we added as a subview.
            guard let hostingView = nsView.subviews.first as? NSHostingView<Content> else {
                return
            }
            
            // Update its rootView whenever the SwiftUI content changes.
            hostingView.rootView = content
        }
    }

    private class NonMovableNSView: NSView {
        /// By returning `false`, we tell the window that a mouse-down event on this view
        /// should not initiate a window move. This allows the view's own gesture
        /// recognizers (like for drag-and-drop) to take precedence.
        override var mouseDownCanMoveWindow: Bool {
            return false
        }
    }
}

extension View {
    func preventWindowMove() -> some View {
        self.modifier(PreventMoveModifier())
    }
}
