// ThickSplitView.swift
import AppKit

/// A split view with a 32-pt thick, “line-space-line” divider.
class ThickSplitView: NSSplitView {
    override var dividerThickness: CGFloat { 32 }

    override func drawDivider(in rect: NSRect) {
        NSColor.separatorColor.setFill()
        // Top 1-pt line
        NSBezierPath(rect: NSRect(x: rect.minX,
                                  y: rect.maxY - 1,
                                  width: rect.width,
                                  height: 1)).fill()
        // Bottom 1-pt line
        NSBezierPath(rect: NSRect(x: rect.minX,
                                  y: rect.minY,
                                  width: rect.width,
                                  height: 1)).fill()
        // Middle transparent
    }
    
}


// ThickSplitViewController.swift
import AppKit
import SwiftUI

/// Hosts a `ThickSplitView` and applies horizontal/vertical orientation.
class ThickSplitViewController: NSSplitViewController {
    private let customSplitView: ThickSplitView

    init(axis: Axis) {
        // Create our custom ThickSplitView first
        self.customSplitView = ThickSplitView()
        self.customSplitView.isVertical = (axis == .horizontal)
        self.customSplitView.dividerStyle = .paneSplitter
        self.customSplitView.autosaveName = "CircuitPro.SplitView"

        super.init(nibName: nil, bundle: nil)

        // Assign custom split view BEFORE view is loaded
        self.setValue(customSplitView, forKey: "splitView")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        // Set view here, but splitView must already be assigned
        self.view = customSplitView
    }
}



// SplitView.swift
import SwiftUI
import AppKit

/// SwiftUI wrapper around `ThickSplitViewController`.
/// Collapses/uncollapses the **second** pane based on the binding.
struct SplitView<First: View, Second: View>: NSViewControllerRepresentable {
    let axis: Axis
    @Binding var isSecondCollapsed: Bool
    let first: First
    let second: Second

    init(
        axis: Axis = .horizontal,
        isSecondCollapsed: Binding<Bool>,
        @ViewBuilder first: () -> First,
        @ViewBuilder second: () -> Second
    ) {
        self.axis = axis
        self._isSecondCollapsed = isSecondCollapsed
        self.first = first()
        self.second = second()
    }

    func makeNSViewController(context: Context) -> NSSplitViewController {
        let controller = ThickSplitViewController(axis: axis)

        let firstItem = NSSplitViewItem(viewController: NSHostingController(rootView: first))
        let secondItem = NSSplitViewItem(viewController: NSHostingController(rootView: second))
        secondItem.canCollapse = true

        controller.addSplitViewItem(firstItem)
        controller.addSplitViewItem(secondItem)
        return controller
    }

    func updateNSViewController(_ controller: NSSplitViewController, context: Context) {
        guard controller.splitViewItems.count > 1 else { return }
        let secondItem = controller.splitViewItems[1]
        if secondItem.isCollapsed != isSecondCollapsed {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.25
                secondItem.animator().isCollapsed = isSecondCollapsed
            })
        }
    }
}
