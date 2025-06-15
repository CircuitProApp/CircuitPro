//
//  ModelContainerManager.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 14.06.25.
//

import SwiftData

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
                for:
                    Project.self,
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
