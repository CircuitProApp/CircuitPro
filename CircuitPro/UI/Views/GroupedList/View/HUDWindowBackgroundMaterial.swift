//
//  HUDWindowBackgroundMaterial.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/19/25.
//

import SwiftUI
import AppKit

struct HUDWindowBackgroundMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.state = .active
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
