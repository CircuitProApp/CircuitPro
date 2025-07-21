//
//  SplitPaneView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 7/21/25.
//

import SwiftUI

public struct SplitPaneView<Primary: View, Handle: View, Secondary: View>: View {

    // MARK: - State Machine Definition
    
    private enum SplitterState: Equatable {
        case collapsed
        case expanded(height: CGFloat)

        var isCollapsed: Bool {
            switch self {
            case .collapsed: return true
            case .expanded: return false
            }
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

    // MARK: - Public binding
    @Binding private var isCollapsed: Bool

    // MARK: - Configuration
    private let primary: Primary
    private let handle: Handle
    private let secondary: Secondary
    private let minPrimary: CGFloat
    private let minSecondary: CGFloat
    private let handleHeight: CGFloat
    private let secondaryCollapsible: Bool

    // MARK: - Internal State
    @State private var splitterState: SplitterState
    @State private var lastNonCollapsedHeight: CGFloat
    @State private var collapseSource: StateChangeSource? = nil
    @State private var isHovering: Bool = false
    
    // MARK: - Transient Drag State
    @State private var isDragging: Bool = false
    @State private var dragInitialHeight: CGFloat = 0
    @State private var currentDragHeight: CGFloat = 0

    // MARK: - Coordinate Space Name
    private let dragSpace = "SplitPaneDragSpace"
    
    // MARK: - Computed Properties
    private var showResizeCursor: Bool {
        isHovering || isDragging
    }

    // MARK: - Init
    public init(
        isCollapsed: Binding<Bool>,
        minPrimary: CGFloat = 100,
        minSecondary: CGFloat = 200,
        handleHeight: CGFloat = 29,
        secondaryCollapsible: Bool = true,
        @ViewBuilder primary: () -> Primary,
        @ViewBuilder handle: () -> Handle,
        @ViewBuilder secondary: () -> Secondary
    ) {
        _isCollapsed = isCollapsed
        self.minPrimary = minPrimary
        self.minSecondary = minSecondary
        self.handleHeight = handleHeight
        self.secondaryCollapsible = secondaryCollapsible
        self.primary = primary()
        self.handle = handle()
        self.secondary = secondary()
        
        let initialRestoreHeight = minSecondary
        let initialState: SplitterState = isCollapsed.wrappedValue ? .collapsed : .expanded(height: initialRestoreHeight)
        _splitterState = State(initialValue: initialState)
        _lastNonCollapsedHeight = State(initialValue: initialRestoreHeight)
    }

    // MARK: - Body
    public var body: some View {
        GeometryReader { geo in
            let usableHeight = geo.size.height - handleHeight
            
            if usableHeight >= 0 {
                let displayHeight = isDragging ? currentDragHeight : splitterState.height

                let dragGesture = DragGesture(minimumDistance: 0, coordinateSpace: .named(dragSpace))
                    .onChanged { value in handleDragChanged(value: value, usableHeight: usableHeight) }
                    .onEnded { _ in handleDragEnded() }
                
                 VStack(spacing: 0) {
                    ZStack(alignment: .bottom) {
                        primary
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        handleAssembly
                            .gesture(dragGesture)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    secondary
                        .frame(maxWidth: .infinity)
                        .frame(height: max(0, displayHeight), alignment: .top)
                        .clipped()
                        .allowsHitTesting(displayHeight > 0)
                }
                .frame(height: geo.size.height)
                .coordinateSpace(name: dragSpace)
                .onChange(of: isCollapsed) { oldValue, newValue in
                    handleExternalCollapseChange(newValue: newValue)
                }
                .onChange(of: showResizeCursor) { oldValue, newValue in
                    if newValue {
                        NSCursor.resizeUpDown.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                
            } else {
                primary
            }
        }
    }

    // MARK: - Handle View
    private var handleAssembly: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onHover { self.isHovering = $0 }

            VStack(spacing: 0) {
                Divider()
                handle
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
            }
        }
        .frame(height: handleHeight)
        .background(.ultraThinMaterial)
        .contentShape(Rectangle())
    }
    
    // MARK: - State Machine Transition Logic

    private func handleDragChanged(value: DragGesture.Value, usableHeight: CGFloat) {
        if !isDragging {
            isDragging = true
            dragInitialHeight = splitterState.height
        }

        let potentialHeight = dragInitialHeight - value.translation.height
        let collapseThreshold = minSecondary / 2

        if secondaryCollapsible && potentialHeight < collapseThreshold {
            if !splitterState.isCollapsed {
                lastNonCollapsedHeight = splitterState.height
                updateState(to: .collapsed, source: .internalDrag)
            }
            currentDragHeight = 0
        } else {
            let newHeight = max(minSecondary, potentialHeight)
            let clampedNewHeight = min(newHeight, usableHeight - minPrimary)
            
            if splitterState.isCollapsed {
                updateState(to: .expanded(height: clampedNewHeight), source: .internalDrag)
            }
            currentDragHeight = clampedNewHeight
        }
    }

    private func handleDragEnded() {
        guard isDragging else { return }
        isDragging = false

        if !splitterState.isCollapsed {
            let finalHeight = currentDragHeight
            lastNonCollapsedHeight = finalHeight
            
            if splitterState != .expanded(height: finalHeight) {
                updateState(to: .expanded(height: finalHeight), source: .internalDrag)
            }
        }
    }
    
    private func handleExternalCollapseChange(newValue: Bool) {
        guard newValue != splitterState.isCollapsed else { return }

        if newValue {
            if !splitterState.isCollapsed {
                lastNonCollapsedHeight = splitterState.height
            }
            updateState(to: .collapsed, source: .external)
        } else {
            let restoreHeight: CGFloat
            if collapseSource == .internalDrag {
                restoreHeight = minSecondary
            } else {
                restoreHeight = max(lastNonCollapsedHeight, minSecondary)
            }
            updateState(to: .expanded(height: restoreHeight), source: .external)
        }
    }

    private func updateState(to newState: SplitterState, source: StateChangeSource) {
        guard newState != splitterState else { return }
        
        if newState.isCollapsed {
            self.collapseSource = source
        }
        
        let stateDescription = newState.isCollapsed ? "collapsed" : "expanded(height: \(Int(newState.height)))"
        print("SplitPaneView: State changed to \(stateDescription) via \(source.rawValue)")
        
        let animation: Animation? = (source == .external) ? .linear : nil

        if let animation = animation {
            withAnimation(animation) {
                splitterState = newState
            }
        } else {
            splitterState = newState
        }
        
        if isCollapsed != newState.isCollapsed {
            isCollapsed = newState.isCollapsed
        }
    }
}
