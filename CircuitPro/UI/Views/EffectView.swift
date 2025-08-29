//
//  EffectView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/30/25.
//


import SwiftUI
import AppKit

struct EffectView: NSViewRepresentable {
    // MARK: - Properties
    
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var state: NSVisualEffectView.State
    var isEmphasized: Bool

    // MARK: - NSViewRepresentable
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        // It's crucial to set properties in both makeNSView and updateNSView
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
        nsView.isEmphasized = isEmphasized
    }
    
    // MARK: - Initialization for Custom Views
    
    init(
        material: NSVisualEffectView.Material,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        state: NSVisualEffectView.State = .active,
        isEmphasized: Bool = true
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
        self.isEmphasized = isEmphasized
    }
}

// MARK: - Default Cases / Presets

extension EffectView {
    
    /// A preset that mimics the appearance of a standard heads-up display window.
    static var hudWindow: Self {
        .init(material: .hudWindow, isEmphasized: true)
    }
    
    /// The material for the background of a window's sidebar.
    static var sidebar: Self {
        .init(material: .sidebar)
    }
    
    /// The material for the background of sheet windows.
    static var sheet: Self {
        .init(material: .sheet)
    }
    
    /// The material for a window's titlebar.
    static var titlebar: Self {
        .init(material: .titlebar)
    }
    
    /// The material for the background of opaque windows.
    static var windowBackground: Self {
        .init(material: .windowBackground)
    }
    
    /// The material for the background of popover windows.
    static var popover: Self {
        .init(material: .popover)
    }
    
    /// The material for menus.
    static var menu: Self {
        .init(material: .menu)
    }
}