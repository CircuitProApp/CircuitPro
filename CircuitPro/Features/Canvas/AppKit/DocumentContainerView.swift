//
//  DocumentContainerView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 20.07.25.
//

import AppKit

/// A view that holds the main canvas content view, centers it,
/// and applies a background color and shadow effect.
final class DocumentContainerView: NSView {

    /// A separate view for the "out of bounds" background color.
    private let documentBackgroundView = DocumentBackgroundView()

    /// The main content view (our `CanvasHostView`).
    let canvasHostView: NSView

    /// Initializes the container with the provided canvas content view.
    init(canvasHost: NSView) {
        self.canvasHostView = canvasHost
        super.init(frame: .zero)
        
        setupShadow()
        
        // Add subviews in Z-order (background first, then content).
        addSubview(documentBackgroundView)
        addSubview(canvasHostView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupShadow() {
        // The canvas host view must have a layer to support a shadow.
        canvasHostView.wantsLayer = true
        
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
        shadow.shadowBlurRadius = 7.0
        
        canvasHostView.shadow = shadow
    }

    // MARK: - Layout

    override func layout() {
        super.layout()
        
        // The background always fills the entire container.
        documentBackgroundView.frame = bounds
        
        // Center the canvas host view within this container.
        let hostSize = canvasHostView.frame.size
        let containerSize = bounds.size
        
        let origin = CGPoint(
            x: (containerSize.width - hostSize.width) / 2,
            y: (containerSize.height - hostSize.height) / 2
        )
        
        canvasHostView.frame = CGRect(origin: origin, size: hostSize)
    }
}
