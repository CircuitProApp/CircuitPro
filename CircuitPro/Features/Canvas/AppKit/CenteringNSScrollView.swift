//
//  CenteringNSScrollView.swift
//  CircuitPro
//
//  Created by Gemini on 7/29/25.
//

import AppKit

/// An `NSScrollView` subclass that centers its document view initially.
class CenteringNSScrollView: NSScrollView {
    private var hasCentered = false

    override func layout() {
        super.layout()
        
        if !hasCentered, let documentView = documentView, documentView.frame.width > 0, documentView.frame.height > 0 {
            let clip = contentView.bounds.size
            let doc = documentView.frame.size
            
            let origin = NSPoint(x: (doc.width - clip.width) * 0.5, y: (doc.height - clip.height) * 0.5)
            contentView.scroll(to: origin)
            reflectScrolledClipView(contentView)
            hasCentered = true
        }
    }
}
