//  SplitPaneView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/21/25.

import SwiftUI

public struct SplitPaneView<Primary: View, Handle: View, Secondary: View>: View {

    // 1. State Machine
    private enum SplitterState: Equatable {
        case collapsed
        case expanded(height: CGFloat)

        var isCollapsed: Bool {
            if case .collapsed = self { return true }
            return false
        }

        var height: CGFloat {
            switch self {
            case .collapsed: return 0
            case .expanded(let height): return height
            }
        }
    }

    private enum StateChangeSource: String {
        case external
        case internalDrag
    }

    // 2. Bindings & Configuration
    @Binding private var isCollapsed: Bool
    private let primary: Primary
    private let handle: Handle
    private let secondary: Secondary
    private let minPrimary: CGFloat
    private let minSecondary: CGFloat
    private let handleHeight: CGFloat
    private let secondaryCollapsible: Bool

    // 3. Internal State
    @State private var splitterState: SplitterState
    @State private var lastNonCollapsedHeight: CGFloat
    @State private var collapseSource: StateChangeSource? = nil

    // 4. Transient Drag State
    @State private var isDragging: Bool = false
    @State private var dragInitialHeight: CGFloat = 0
    @State private var currentDragHeight: CGFloat = 0
    @State private var isHovering: Bool = false

    // 5. Utilities
    private let dragSpace = "SplitPaneDragSpace"
    private var showResizeCursor: Bool { isDragging || isHovering }

    // 6. Init
    public init(
        isCollapsed: Binding<Bool>,
        minPrimary: CGFloat = 100,
        minSecondary: CGFloat = 200,
        handleHeight: CGFloat? = nil,
        secondaryCollapsible: Bool = true,
        @ViewBuilder primary: () -> Primary,
        @ViewBuilder handle: () -> Handle,
        @ViewBuilder secondary: () -> Secondary
    ) {
        _isCollapsed = isCollapsed
        self.minPrimary = minPrimary
        self.minSecondary = minSecondary
        self.secondaryCollapsible = secondaryCollapsible
        self.primary = primary()
        self.handle = handle()
        self.secondary = secondary()

        #if os(macOS)
        if #available(macOS 26, *), handleHeight == nil {
            self.handleHeight = 36
        } else {
            self.handleHeight = handleHeight ?? 29
        }
        #else
        self.handleHeight = handleHeight ?? 29
        #endif

        let initialRestoreHeight = minSecondary
        let initialState: SplitterState = isCollapsed.wrappedValue
            ? .collapsed
            : .expanded(height: initialRestoreHeight)
        _splitterState = State(initialValue: initialState)
        _lastNonCollapsedHeight = State(initialValue: initialRestoreHeight)
    }

    // 7. Body
    public var body: some View {
        GeometryReader { geo in
            // 7.1. Ensure there is enough space for the view
            if geo.size.height - handleHeight < 0 {
                primary
            } else {
                splitViewContent(for: geo)
            }
        }
    }

    // 8. View Builders
    private func splitViewContent(for geo: GeometryProxy) -> some View {
        let usableHeight = geo.size.height - handleHeight
        let displayHeight = isDragging ? currentDragHeight : splitterState.height
        let dragGesture = DragGesture(minimumDistance: 0, coordinateSpace: .named(dragSpace))
            .onChanged { value in handleDragChanged(value: value, usableHeight: usableHeight) }
            .onEnded { _ in handleDragEnded() }

        return VStack(spacing: 0) {
            primary
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            handleAssembly
                .gesture(dragGesture)

            secondary
                .frame(maxWidth: .infinity)
                .frame(height: max(0, displayHeight), alignment: .top)
                .clipped()
                .allowsHitTesting(displayHeight > 0)
        }
        .frame(height: geo.size.height)
        .coordinateSpace(name: dragSpace)
        .onChange(of: isCollapsed) { _, newValue in
            handleExternalCollapseChange(isCollapsing: newValue)
        }
        .onChange(of: showResizeCursor) { _, show in
            show ? NSCursor.resizeUpDown.push() : NSCursor.pop()
        }
    }
    
    private var handleAssembly: some View {
        ZStack {
            // 8.1. Handle Background and hover area
            VStack(spacing: 0) {
                Divider()
                Color.clear
                if !isCollapsed {
                    Divider()
                }
            }
            .contentShape(Rectangle()) // Ensure entire area is hoverable
            .onHover { self.isHovering = $0 }
            
            // 8.2. User-provided handle view
            handle
        }
        .frame(height: handleHeight)
        .background(.ultraThinMaterial)
    }

    // 9. Drag Handling Logic
    private func handleDragChanged(value: DragGesture.Value, usableHeight: CGFloat) {
        // 9.1. Initialize Drag
        if !isDragging {
            beginDrag()
        }

        // 9.2. Calculate Drag Height
        let potentialHeight = dragInitialHeight - value.translation.height
        let collapseThreshold = minSecondary / 2

        // 9.3. Process Drag
        if shouldCollapse(potentialHeight: potentialHeight, collapseThreshold: collapseThreshold) {
            processDragCollapse()
        } else {
            processDragExpand(potentialHeight: potentialHeight, usableHeight: usableHeight)
        }
    }
    
    private func handleDragEnded() {
        guard isDragging else { return }
        isDragging = false

        // 9.4. Finalize Drag State
        guard !splitterState.isCollapsed else { return }
        
        let finalHeight = currentDragHeight
        lastNonCollapsedHeight = finalHeight

        if splitterState != .expanded(height: finalHeight) {
            updateState(to: .expanded(height: finalHeight), source: .internalDrag)
        }
    }

    // 10. Drag Handling Helpers
    private func beginDrag() {
        isDragging = true
        dragInitialHeight = splitterState.height
    }

    private func shouldCollapse(potentialHeight: CGFloat, collapseThreshold: CGFloat) -> Bool {
        return secondaryCollapsible && potentialHeight < collapseThreshold
    }

    private func processDragCollapse() {
        if !splitterState.isCollapsed {
            lastNonCollapsedHeight = splitterState.height
            updateState(to: .collapsed, source: .internalDrag)
        }
        currentDragHeight = 0
    }

    private func processDragExpand(potentialHeight: CGFloat, usableHeight: CGFloat) {
        let newHeight = max(minSecondary, potentialHeight)
        let clampedHeight = min(newHeight, usableHeight - minPrimary)

        if splitterState.isCollapsed {
            updateState(to: .expanded(height: clampedHeight), source: .internalDrag)
        }
        currentDragHeight = clampedHeight
    }
    
    // 11. External State Change Handling
    private func handleExternalCollapseChange(isCollapsing: Bool) {
        guard isCollapsing != splitterState.isCollapsed else { return }

        if isCollapsing {
            // 11.1. Collapse from external trigger
            lastNonCollapsedHeight = splitterState.height
            updateState(to: .collapsed, source: .external)
        } else {
            // 11.2. Expand from external trigger
            let restoreHeight = calculateRestoreHeight()
            updateState(to: .expanded(height: restoreHeight), source: .external)
        }
    }
    
    private func calculateRestoreHeight() -> CGFloat {
        // 11.3. Determine height to restore to
        if collapseSource == .internalDrag {
            return minSecondary
        } else {
            return max(lastNonCollapsedHeight, minSecondary)
        }
    }

    // 12. Core State Update
    private func updateState(to newState: SplitterState, source: StateChangeSource) {
        guard newState != splitterState else { return }

        // 12.1. Update collapse source if view is collapsing
        if newState.isCollapsed {
            self.collapseSource = source
        }

        // 12.2. Determine animation
        let animation: Animation? = (source == .external) ? .linear : nil

        // 12.3. Apply state change with animation
        if let animation {
            withAnimation(animation) {
                splitterState = newState
            }
        } else {
            splitterState = newState
        }

        // 12.4. Sync external binding if needed
        if isCollapsed != newState.isCollapsed {
            isCollapsed = newState.isCollapsed
        }
    }
}
