import SwiftUI
import SwiftData
import WelcomeWindow

@main
struct CircuitProApp: App {
    
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    var delegate
    
    @Environment(\.openWindow)
    private var openWindow
    
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
            WelcomeWindow(actions: { dismiss in
                WelcomeActionView(iconName: AppIcons.plusApp, title: "Create New Project...") {
                    CircuitProjectDocumentController.shared.createFolderDocumentWithDialog(configuration: .init(allowedContentTypes: [.circuitProject], defaultFileType: .circuitProject))
                }
                WelcomeActionView(iconName: AppIcons.folder, title: "Open Existing Project...") {
                    CircuitProjectDocumentController.shared.openDocumentWithDialog(configuration: .init(allowedContentTypes: [.circuitProject]))
                }
                WelcomeActionView(iconName: AppIcons.plusApp, title: "Create New Component...") {
                    openWindow(id: "componentDesignerWindow")
                }
            },
                          onDrop: { url, dismiss in
                Task {
                    CircuitProjectDocumentController.shared.openDocument(at: url, onCompletion: { dismiss() })
                }
            })
            
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
        
        WindowGroup(id: "componentDesignerWindow") {
            ComponentDesignView()
        }
    }
}
