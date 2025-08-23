//
//  KeyActivatingPanel.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/11/25.
//

import AppKit
import Carbon.HIToolbox.Events

// A custom NSPanel subclass that can become the key window.
class KeyActivatingPanel: NSPanel {
    override var canBecomeKey: Bool {
        // By returning true, we're telling AppKit that this panel
        // is allowed to receive keyboard focus and become the active window.
        return true
    }
    
    override func sendEvent(_ event: NSEvent) {
        // Check if the event is a key down event and if the key pressed is Escape.
        if event.type == .keyDown && event.keyCode == kVK_Escape {
            // If it's the Escape key, we close the panel and stop processing the event.
            self.close()
            return
        }
        
        // For all other events, we pass them along to the default implementation.
        super.sendEvent(event)
    }
}
