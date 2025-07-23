//
//  ModelContainerManager.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 14.06.25.
//

import SwiftData
import SwiftUI

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

            // Log the container's store file location
            if let storeURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                print("📁 SwiftData Store Path: \(storeURL.appendingPathComponent("appLibrary.store").path)")
            }

        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }
}
