import SwiftUI
import AppKit

// MARK: – SwiftUI wrapper
public struct SplitPaneView<Primary: View, Handle: View, Secondary: View>: NSViewRepresentable {

    @Binding private var isCollapsed: Bool

    private let minPrimary: CGFloat
    private let minSecondary: CGFloat
    private let handleHeight: CGFloat
    private let secondaryCollapsible: Bool

    private let primaryView: Primary
    private let handleView: Handle
    private let secondaryView: Secondary

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
        self._isCollapsed = isCollapsed
        self.minPrimary = minPrimary
        self.minSecondary = minSecondary
        self.handleHeight = handleHeight
        self.secondaryCollapsible = secondaryCollapsible
        self.primaryView = primary()
        self.handleView = handle()
        self.secondaryView = secondary()
    }

    // MARK: – Coordinator
    public func makeCoordinator() -> Coordinator { Coordinator(isCollapsed: $isCollapsed) }
    public class Coordinator {
        @Binding var isCollapsed: Bool
        init(isCollapsed: Binding<Bool>) { _isCollapsed = isCollapsed }
    }

    // MARK: – NSViewRepresentable
    public func makeNSView(context: Context) -> NSSplitPaneView {
        let view = NSSplitPaneView(
            primary: AnyView(primaryView),
            handle: AnyView(handleView),
            secondary: AnyView(secondaryView),
            minPrimary: minPrimary,
            minSecondary: minSecondary,
            handleHeight: handleHeight,
            secondaryCollapsible: secondaryCollapsible
        )
        view.onCollapseChange = { context.coordinator.isCollapsed = $0 }
        return view
    }

    public func updateNSView(_ nsView: NSSplitPaneView, context: Context) {
        nsView.update(
            isCollapsed: isCollapsed,
            primary: AnyView(primaryView),
            handle: AnyView(handleView),
            secondary: AnyView(secondaryView)
        )
    }
}
