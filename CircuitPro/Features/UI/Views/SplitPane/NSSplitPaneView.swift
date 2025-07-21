import SwiftUI
import AppKit

// MARK: - 1.  NSView  ─────────────────────────────────────────────────────────

public final class NSSplitPaneView: NSView {

    // MARK: configuration
    private let minPrimary:        CGFloat
    private let minSecondary:      CGFloat
    private let handleHeight:      CGFloat
    private let secondaryCollapsible: Bool

    // MARK: sub-views
    private let primaryHosting:   NSHostingView<AnyView>
    private let handleHosting:    NSHostingView<AnyView>   // suppresses arrow on whole bar
    private let secondaryHosting: NSHostingView<AnyView>
    private let handleBackground  = NSView()
    private let topDivider        = NSView()
    private let bottomDivider     = NSView()

    // MARK: state
    private enum CollapseSource { case external, drag }
    private var collapseSource: CollapseSource = .external

    private var isCollapsed            = false
    private var secondaryHeight: CGFloat
    private var lastExternalHeight: CGFloat?
    var onCollapseChange: ((Bool) -> Void)?

    // MARK: drag
    private var dragAnchor: CGFloat = 0
    private var isDragging = false

    // MARK: constants
    private static let animDuration: TimeInterval = 0.20

    // MARK: init
    init(primary:            AnyView,
         handle:             AnyView,
         secondary:          AnyView,
         minPrimary:         CGFloat,
         minSecondary:       CGFloat,
         handleHeight:       CGFloat,
         secondaryCollapsible: Bool)
    {
        self.minPrimary          = minPrimary
        self.minSecondary        = minSecondary
        self.handleHeight        = handleHeight
        self.secondaryCollapsible = secondaryCollapsible
        self.secondaryHeight     = minSecondary                  // start minimised

        self.primaryHosting   = NSHostingView(rootView: primary)
        self.handleHosting    = NSHostingView(rootView: handle)
        self.secondaryHosting = NSHostingView(rootView: secondary)

        super.init(frame: .zero)

        wantsLayer = true

        handleBackground.wantsLayer = true
        handleBackground.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        [topDivider, bottomDivider].forEach {
            $0.wantsLayer = true
            $0.layer?.backgroundColor = NSColor.separatorColor.cgColor
        }

        addSubview(primaryHosting)
        addSubview(handleBackground)
        addSubview(secondaryHosting)
        addSubview(handleHosting)

        handleBackground.addSubview(topDivider)
        handleBackground.addSubview(bottomDivider)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: update from SwiftUI
    func update(isCollapsed newValue: Bool,
                primary:   AnyView,
                handle:    AnyView,
                secondary: AnyView)
    {
        primaryHosting.rootView   = primary
        handleHosting.rootView    = handle
        secondaryHosting.rootView = secondary

        guard isCollapsed != newValue else { return }

        collapseSource = .external
        if !isCollapsed { lastExternalHeight = secondaryHeight }

        DispatchQueue.main.async { [weak self] in
            self?.setCollapsed(newValue, animated: true)
        }
    }

    // MARK: layout
    private var usableHeight: CGFloat { bounds.height - handleHeight }
    private var collapseThreshold: CGFloat { minSecondary / 2 }

    public override func layout() {
        super.layout()

        let usable = usableHeight

        if isCollapsed {
            secondaryHeight           = 0
            bottomDivider.isHidden    = true
        } else {
            bottomDivider.isHidden    = false
            secondaryHeight           = min(secondaryHeight, max(0, usable - minPrimary))
            secondaryHeight           = max(minSecondary, secondaryHeight)
        }

        let primaryHeight = usable - secondaryHeight
        let total         = bounds.height

        primaryHosting.frame = NSRect(x: 0, y: total - primaryHeight,
                                      width: bounds.width, height: primaryHeight)

        handleBackground.frame = NSRect(x: 0, y: secondaryHeight,
                                        width: bounds.width, height: handleHeight)

        // FULL-WIDTH handle so Spacer() expands
        handleHosting.frame    = handleBackground.frame

        secondaryHosting.frame = NSRect(x: 0, y: 0,
                                        width: bounds.width, height: secondaryHeight)

        topDivider.frame    = NSRect(x: 0, y: handleHeight - 1,
                                     width: bounds.width, height: 1)
        bottomDivider.frame = NSRect(x: 0, y: 0,
                                     width: bounds.width, height: 1)

        window?.invalidateCursorRects(for: self)
    }

    // MARK: collapse / expand
    private func setCollapsed(_ collapsed: Bool, animated: Bool) {
        let previous = isCollapsed
        isCollapsed  = collapsed

        if collapsed {
            secondaryHeight = 0
        } else {
            switch collapseSource {
            case .external: secondaryHeight = lastExternalHeight ?? minSecondary
            case .drag:     break
            }
        }

        let apply = { [weak self] in
            self?.needsLayout = true
            self?.layoutSubtreeIfNeeded()
        }

        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration              = Self.animDuration
                ctx.timingFunction        = CAMediaTimingFunction(name: .linear)
                ctx.allowsImplicitAnimation = true
                apply()
            }
        } else {
            apply()
        }

        if previous != collapsed { onCollapseChange?(collapsed) }
    }
}

// MARK: mouse & cursors
extension NSSplitPaneView {

    public override func resetCursorRects() {
        super.resetCursorRects()

        let bar = handleBackground.frame
        guard bar.width > 0, bar.height > 0 else { return }

        // 1. Collect horizontal ranges that should keep the arrow cursor
        var holes: [ClosedRange<CGFloat>] = []

        func collectXRanges(from view: NSView) {
            // Any focusable / pressable sub-view inside `handleHosting`
            if view !== handleHosting,
               view.acceptsFirstResponder,
               view.window === self.window          // visible & in same window
            {
                let r = view.convert(view.bounds, to: self)
                let clipped = r.intersection(bar)
                if clipped.width > 0 {
                    holes.append(clipped.minX ... clipped.maxX)
                }
            }
            view.subviews.forEach(collectXRanges(from:))
        }
        collectXRanges(from: handleHosting)

        // Nothing to subtract → whole bar gets resize cursor
        guard !holes.isEmpty else {
            addCursorRect(bar, cursor: .resizeUpDown)
            return
        }

        // 2. Merge overlapping X-ranges
        holes.sort { $0.lowerBound < $1.lowerBound }
        var merged: [ClosedRange<CGFloat>] = []
        for h in holes {
            if let last = merged.last, last.overlaps(h) || last.upperBound == h.lowerBound {
                merged[merged.count - 1] = last.lowerBound ... max(last.upperBound, h.upperBound)
            } else {
                merged.append(h)
            }
        }

        // 3. Add resize rects for every horizontal gap
        var cursorStart = bar.minX
        for m in merged {
            if cursorStart < m.lowerBound {
                let w = m.lowerBound - cursorStart
                addCursorRect(NSRect(x: cursorStart,
                                     y: bar.minY,
                                     width: w,
                                     height: bar.height),
                              cursor: .resizeUpDown)
            }
            cursorStart = m.upperBound
        }
        // right-most gap, if any
        if cursorStart < bar.maxX {
            addCursorRect(NSRect(x: cursorStart,
                                 y: bar.minY,
                                 width: bar.maxX - cursorStart,
                                 height: bar.height),
                          cursor: .resizeUpDown)
        }
    }

    public override func mouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        guard handleBackground.frame.contains(loc) else { return }

        isDragging     = true
        collapseSource = .drag

        let currentSecondary = isCollapsed ? 0 : secondaryHeight
        dragAnchor = event.locationInWindow.y - currentSecondary
    }

    public override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }

        let usable       = usableHeight
        var newSecondary = event.locationInWindow.y - dragAnchor
        let maxSecondary = usable - minPrimary

        if secondaryCollapsible {
            if isCollapsed {
                if newSecondary > collapseThreshold {
                    setCollapsed(false, animated: false)
                } else {
                    newSecondary = 0
                }
            } else {
                if newSecondary < collapseThreshold {
                    setCollapsed(true, animated: false)
                    newSecondary = 0
                } else {
                    newSecondary = min(newSecondary, maxSecondary)
                }
            }
        } else {
            newSecondary = min(max(newSecondary, minSecondary), maxSecondary)
        }

        secondaryHeight = max(0, newSecondary)
        needsLayout     = true
    }

    public override func mouseUp(with event: NSEvent) {
        isDragging = false
        if secondaryCollapsible && !isCollapsed && secondaryHeight < minSecondary {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = Self.animDuration
                ctx.allowsImplicitAnimation = true
                self.secondaryHeight = self.minSecondary
                self.needsLayout = true
                self.layoutSubtreeIfNeeded()
            }
        }
    }
}
