import SwiftUI
import SwiftData
import WelcomeWindow
import AboutWindow

@main
struct CircuitProApp: App {

    @Environment(\.openWindow)
    private var openWindow

    @State private var appManager = AppManager()
    @State private var componentDesignManager = ComponentDesignManager()

    init() {
        _ = CircuitProjectDocumentController.shared
    }

    var body: some Scene {
        Group {
            WelcomeWindow(
                actions: { dismiss in
                    WelcomeButton(iconName: CircuitProSymbols.Generic.plus, title: "Create New Project...") {
                        CircuitProjectDocumentController.shared.createFileDocumentWithDialog(
                            configuration:
                                    .init(allowedContentTypes: [.circuitProject], defaultFileType: .circuitProject),
                            onDialogPresented: { dismiss() }
                        )
                    }
                    .symbolVariant(.rectangle)
                    WelcomeButton(iconName: CircuitProSymbols.Generic.folder, title: "Open Existing Project...") {
                        CircuitProjectDocumentController.shared.openDocumentWithDialog(
                            configuration: .init(allowedContentTypes: [.circuitProject]),
                            onDialogPresented: { dismiss() }
                        )
                    }
                    .symbolVariant(.rectangle)
                    WelcomeButton(iconName: CircuitProSymbols.Generic.plus, title: "Create New Component...") {
                        openWindow(id: "ComponentDesignWindow")
                    }
                    .symbolVariant(.rectangle)
                },
                onDrop: { url, dismiss in
                    Task {
                        CircuitProjectDocumentController.shared.openDocument(at: url, onCompletion: { dismiss() })
                    }
                }
            )

            AboutWindow(actions: {}, footer: { AboutFooterView() })
            .commands {
                CircuitProCommands()
            }
        }
        .environment(\.appManager, appManager)

        Window("Component Design", id: "ComponentDesignWindow") {
            ComponentDesignView()
                .modelContainer(ModelContainerManager.shared.container)
                .environment(\.componentDesignManager, componentDesignManager)
                .task {
                    if let window = NSApp.findWindow("ComponentDesignWindow") {
                        window.makeKeyAndOrderFront(nil)
                        window.makeFirstResponder(window.contentView)
                    }
                }
        }
    }
}

extension NSApplication {
    func closeWindow(_ id: String) {
        windows.first { $0.identifier?.rawValue == id }?.close()
    }

    func closeWindows(_ ids: [String]) {
        ids.forEach { closeWindow($0) }
    }

    func findWindow(_ id: String) -> NSWindow? {
        windows.first { $0.identifier?.rawValue == id }
    }

    var openSwiftUIWindowIDs: [String] {
        windows.compactMap { $0.identifier?.rawValue }
    }
}
