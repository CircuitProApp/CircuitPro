import SwiftUI
import SwiftData

struct LibraryMetadata: Codable {
    let version: String
}

enum UpdateError: Error {
    case metadataFetchFailed(Error)
    case metadataDecodingFailed(Error)
    case localMetadataMissing
    case downloadFailed(Error)
    case replacementFailed(Error)
}

@ModelActor
final actor LibraryUpdater {

    private static let metadataFileName = "appLibrary.json"

    static func checkForUpdates() async throws -> String? {
        print("🔎 Checking for library updates...")
        
        let remoteURL = URL(string: "https://raw.githubusercontent.com/georgetchelidze/CircuitProAppLibrary/main/appLibrary.json")!
        let remoteMetadata = try await fetchRemoteMetadata(from: remoteURL)
        
        guard let localMetadata = loadLocalMetadata() else {
            print("⚠️ Local metadata not found. Proceeding with update.")
            try await downloadAndApplyUpdate(from: remoteMetadata)
            return remoteMetadata.version
        }
        
        if remoteMetadata.version > localMetadata.version {
            print("⬆️ New version found: \(remoteMetadata.version) (current: \(localMetadata.version))")
            try await downloadAndApplyUpdate(from: remoteMetadata)
            return remoteMetadata.version
        } else {
            print("👍 Library is up-to-date. (Version: \(localMetadata.version))")
            return nil
        }
    }

    private static func fetchRemoteMetadata(from url: URL) async throws -> LibraryMetadata {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try JSONDecoder().decode(LibraryMetadata.self, from: data)
        } catch let error as DecodingError {
            throw UpdateError.metadataDecodingFailed(error)
        } catch {
            throw UpdateError.metadataFetchFailed(error)
        }
    }

    private static func loadLocalMetadata() -> LibraryMetadata? {
        guard let applicationSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let metadataURL = applicationSupportDirectory.appendingPathComponent(self.metadataFileName)
        guard let data = try? Data(contentsOf: metadataURL) else { return nil }
        return try? JSONDecoder().decode(LibraryMetadata.self, from: data)
    }

    private static func downloadAndApplyUpdate(from metadata: LibraryMetadata) async throws {
        guard let downloadURL = URL(string: "https://github.com/CircuitProApp/CircuitProAppLibrary/blob/main/appLibrary.store") else {
            fatalError("Hardcoded download URL is invalid.")
        }
        print("📥 Downloading update from: \(downloadURL)...")
        
        do {
            let (tempLocalURL, _) = try await URLSession.shared.download(from: downloadURL)
            let schema = Schema([Component.self, Symbol.self, Footprint.self])
            let config = ModelConfiguration("update", schema: schema, url: tempLocalURL, allowsSave: false)
            let updateContainer = try ModelContainer(for: schema, configurations: config)
            
            let backgroundContext = ModelContext(ModelContainerManager.shared.container)

            // --- DELETION PHASE (Corrected) ---
            // The logic now correctly uses the stable '.uuid' property to compare objects
            // across different database stores, instead of the unstable 'PersistentIdentifier'.
            print("--- Starting Deletion Phase ---")
            
            // 1. Get all UUIDs from the NEW downloaded database.
            let newComponentIDs = Set(try await updateContainer.mainContext.fetch(FetchDescriptor<Component>()).map { $0.uuid })
            let newSymbolIDs = Set(try await updateContainer.mainContext.fetch(FetchDescriptor<Symbol>()).map { $0.uuid })
            let newFootprintIDs = Set(try await updateContainer.mainContext.fetch(FetchDescriptor<Footprint>()).map { $0.uuid })

            // 2. Get all UUIDs from the LOCAL live database.
            let localComponentIDs = Set(try backgroundContext.fetch(FetchDescriptor<Component>()).map { $0.uuid })
            let localSymbolIDs = Set(try backgroundContext.fetch(FetchDescriptor<Symbol>()).map { $0.uuid })
            let localFootprintIDs = Set(try backgroundContext.fetch(FetchDescriptor<Footprint>()).map { $0.uuid })

            // 3. Calculate which UUIDs need to be deleted.
            let componentIDsToDelete = localComponentIDs.subtracting(newComponentIDs)
            let symbolIDsToDelete = localSymbolIDs.subtracting(newSymbolIDs)
            let footprintIDsToDelete = localFootprintIDs.subtracting(newFootprintIDs)
            
            print("Found \(componentIDsToDelete.count) components, \(symbolIDsToDelete.count) symbols, and \(footprintIDsToDelete.count) footprints to delete.")

            // 4. Fetch the actual local objects to delete using their UUIDs and perform deletion.
            if !componentIDsToDelete.isEmpty {
                let descriptor = FetchDescriptor<Component>(predicate: #Predicate { componentIDsToDelete.contains($0.uuid) })
                for object in try backgroundContext.fetch(descriptor) { backgroundContext.delete(object) }
            }
            if !symbolIDsToDelete.isEmpty {
                let descriptor = FetchDescriptor<Symbol>(predicate: #Predicate { symbolIDsToDelete.contains($0.uuid) })
                for object in try backgroundContext.fetch(descriptor) { backgroundContext.delete(object) }
            }
            if !footprintIDsToDelete.isEmpty {
                let descriptor = FetchDescriptor<Footprint>(predicate: #Predicate { footprintIDsToDelete.contains($0.uuid) })
                for object in try backgroundContext.fetch(descriptor) { backgroundContext.delete(object) }
            }

            // --- UPSERT PHASE ---
            print("--- Starting Upsert Phase ---")
            let newComponents = try await updateContainer.mainContext.fetch(FetchDescriptor<Component>())
            let newSymbols = try await updateContainer.mainContext.fetch(FetchDescriptor<Symbol>())
            let newFootprints = try await updateContainer.mainContext.fetch(FetchDescriptor<Footprint>())
            
            // Inserting objects with existing UUIDs will perform an update (upsert).
            for symbol in newSymbols { backgroundContext.insert(symbol) }
            for footprint in newFootprints { backgroundContext.insert(footprint) }
            for component in newComponents { backgroundContext.insert(component) }
            
            // --- FINALIZATION PHASE ---
            print("--- Starting Finalization Phase ---")
            try backgroundContext.save()
            
            guard let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                throw UpdateError.replacementFailed(NSError(domain: "AppUpdater", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not find App Support directory."]))
            }
            
            let metadataDestinationURL = appSupportURL.appendingPathComponent(self.metadataFileName)
            
            let newMetadataData = try JSONEncoder().encode(metadata)
            try newMetadataData.write(to: metadataDestinationURL)
            
            print("✅ Hot-swap with deletion support complete. Library is now version \(metadata.version).")
            
        } catch {
            throw UpdateError.downloadFailed(error)
        }
    }
}
