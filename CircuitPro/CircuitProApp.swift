import SwiftUI
import SwiftData
import WelcomeWindow
import AboutWindow

@main
struct CircuitProApp: App {
    
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    var delegate
    
    @Environment(\.openWindow)
    private var openWindow

    @State var appManager = AppManager()
    @State var componentDesignManager = ComponentDesignManager()
    // MARK: - Initialization
    
    init() {
        
        _ = CircuitProjectDocumentController.shared

    }
    
    // MARK: - App Body
    
    var body: some Scene {
        Group {
            WelcomeWindow(
                actions: { dismiss in
                    WelcomeActionView(iconName: AppIcons.plusApp, title: "Create New Project...") {
                        CircuitProjectDocumentController.shared.createFileDocumentWithDialog(configuration: .init(allowedContentTypes: [.circuitProject], defaultFileType: .circuitProject))
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
                }
            )
            
            AboutWindow(actions: {}, footer: { AboutFooterView() })
            .commands {
                CircuitProCommands()
            }
        }
        .environment(\.appManager, appManager)
      
        
        WindowGroup(id: "SecondWindow") {
            SettingsView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.expanded)
        
        WindowGroup(id: "componentDesignerWindow") {
            ComponentDesignView()
                .modelContainer(ModelContainerManager.shared.container)
                .environment(\.componentDesignManager, componentDesignManager)
        }
    }
}

final class ModelContainerManager {
    static let shared = ModelContainerManager()
    let container: ModelContainer

    private init() {
        do {
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
//                    ComponentInstance.self,
//                    SymbolInstance.self,
//                    FootprintInstance.self
                ]),
                allowsSave: true
            )
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
            container = try ModelContainer(
                for: Project.self,
                Design.self,
                Schematic.self,
                Layout.self,
                Layer.self,
                Net.self,
                Via.self,
//                ComponentInstance.self,
//                SymbolInstance.self,
//                FootprintInstance.self,
                Component.self,
                Symbol.self,
                Footprint.self,
                Model.self,
                configurations: workspaceConfig, appLibraryConfig
            )
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }
}
