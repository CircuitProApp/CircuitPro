//
//  WelcomeRootView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/14/25.
//

import SwiftUI

struct WelcomeRootView: View {
    
    // MARK: - State
    @State private var isBeyondZero: Bool = true
    @State private var overlayHeight: CGFloat = 260.0 // Start at half height
    @State private var isScrollDisabled: Bool = true
    
    // MARK: - Constants
    private let minHeight: CGFloat = 540/2
    private let maxHeight: CGFloat = 540
    
    var body: some View {
        VStack {
            VStack {
                Text("Circuit Pro")
                    .font(.system(size: 32, weight: .semibold))
                    .padding(24)
                
                Button {
                    
                } label: {
                    Text("New Project")
                        .font(.system(size: 16))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 32)
                        .background(.gray.mix(with: .white, by: 0.9))
                        .clipShape(.capsule)
                      
                }
                .buttonStyle(.plain)
                Button {
                    
                } label: {
                    Text("New Component")
                        .font(.system(size: 16))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 32)
                        .background(.gray.mix(with: .white, by: 0.9))
                        .clipShape(.capsule)
                    
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.white)
            .clipShape(.rect(cornerRadius: 20))
            .padding(.vertical, 64)
            .padding(.horizontal, 160)
        }
        .ignoresSafeArea()
        .overlay(alignment: .bottom) {
            scrollViewContent
        }
        .windowResizeBehavior(.disabled)
        .windowFullScreenBehavior(.disabled)
        .task {
            if let window = NSApplication.shared.findWindow("WelcomeWindow") {
                window.isMovableByWindowBackground = true
            }
        }
    }
    
    private var scrollViewContent: some View {
        ScrollView {
            VStack {
                HStack {
                    Spacer()
                    Button {
                        
                    } label: {
                        Text("Search")
                    }

                }
                .padding(20)
                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(96), spacing: 16), count: 5), // fixed width & spacing
                    spacing: 16 // vertical spacing
                ) {
                    ForEach(0...100, id: \.self) { int in
                        Text(int.description)
                            .frame(width: 96, height: 96)
                            .background(.white)
                            .clipShape(.rect(cornerRadius: 5))
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .scrollDisabled(isScrollDisabled)
        .background(.ultraThinMaterial)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.visible, axes: .vertical)
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y <= geometry.contentInsets.top
        } action: { _, isAtTop in
            self.isBeyondZero = isAtTop
        }
        .frame(height: overlayHeight)
        .clipShape(.rect(topLeadingRadius: 15, topTrailingRadius: 15))
        .overlay {
            // Updated closure to receive the gesture phase.
            WheelCapture { _, deltaY, phase in
                handleScroll(deltaY: deltaY, phase: phase)
            }
        }
    }
    
    private func handleScroll(deltaY: CGFloat, phase: NSEvent.Phase) {
        // We only act on continuous scrolling when the phase is `.changed`.
        if phase == .changed {
            let isScrollingUp = deltaY > 0
            
            if isScrollingUp && isBeyondZero {
                isScrollDisabled = true
            }

            if isScrollDisabled {
                let newHeight = overlayHeight - deltaY
                overlayHeight = max(minHeight, min(newHeight, maxHeight))
                
                if deltaY < 0 && overlayHeight >= maxHeight {
                    isScrollDisabled = false
                }
            }
        }
        
        // When the user lets go, the phase will be `.ended`.
        // This is our trigger for the snap animation.
        if phase == .ended || phase == .cancelled {
            // Only perform the animation if we are in the resizing state.
            if isScrollDisabled {
                performSnapAnimation()
            }
        }
    }
    
    private func performSnapAnimation() {
        guard overlayHeight > minHeight && overlayHeight < maxHeight else { return }
        
        let snapThreshold = minHeight + (minHeight / 2)
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if overlayHeight > snapThreshold {
                overlayHeight = maxHeight
                isScrollDisabled = false
            } else {
                overlayHeight = minHeight
            }
        }
    }
}
