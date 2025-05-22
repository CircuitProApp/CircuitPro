import SwiftUI
import SwiftData

@main
struct CircuitProApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self)
    var delegate

    var container: ModelContainer

    @State var appManager = AppManager()
    @State var projectManager = ProjectManager()
    @State var componentDesignManager = ComponentDesignManager()
    // MARK: - Initialization

    init() {

        _ = CircuitProjectDocumentController.shared

        do {
            // Create the workspace configuration (writable, instance types).
            let workspaceConfig = ModelConfiguration(
                "workspace",
                schema: Schema([
                    Project.self,
                    Design.self,
                    Schematic.self,
                    Layout.self,
                    Layer.self,
                    Net.self,
                    Via.self,
                    ComponentInstance.self,
                    SymbolInstance.self,
                    FootprintInstance.self
                ]),
                allowsSave: true
            )
            // Create the appLibrary configuration (read-only, default types).
            let appLibraryConfig = ModelConfiguration(
                "appLibrary",
                schema: Schema([
                    Component.self,
                    Symbol.self,
                    Footprint.self,
                    Model.self
                ]),
                allowsSave: true
            )
            // Create one unified ModelContainer that handles both configurations.
            container = try ModelContainer(
                for: Project.self,
                Design.self,
                Schematic.self,
                Layout.self,
                Layer.self,
                Net.self,
                Via.self,
                ComponentInstance.self,
                SymbolInstance.self,
                FootprintInstance.self,
                Component.self,
                Symbol.self,
                Footprint.self,
                Model.self,
                configurations: workspaceConfig, appLibraryConfig
            )
        } catch {
            fatalError("Failed to initialize container: \(error)")
        }
    }

    // MARK: - App Body

    var body: some Scene {
        Group {
            WelcomeWindow()
            AboutWindow()
                .commands {
                    CircuitProCommands()
                }
        }
        // Attach the container to the scene.
        .modelContainer(container)

        // Inject additional environment objects.
        .environment(\.appManager, appManager)
        .environment(\.projectManager, projectManager)
        .environment(\.componentDesignManager, componentDesignManager)

        WindowGroup(id: "SecondWindow") {
            SettingsView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.expanded)
    }
}
