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
                    Component.self,
                    Symbol.self,
                    Footprint.self,
                    Model.self,
                configurations: appLibraryConfig
            )
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }
}
