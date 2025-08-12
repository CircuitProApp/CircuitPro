//
//  RemoteLibraryMetadata.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 8/12/25.
//

import SwiftUI
import SwiftData

// The metadata structure is now as simple as possible.
struct RemoteLibraryMetadata: Codable {
    let version: String
}

// Custom error enum remains the same.
enum UpdateError: Error {
    case metadataFetchFailed(Error)
    case metadataDecodingFailed(Error)
    case localMetadataMissing
    case downloadFailed(Error)
    case replacementFailed(Error)
}

final class LibraryUpdater {

    // This is the single public entry point for the update process.
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

    // The NEW, more accurate version
    private static func fetchRemoteMetadata(from url: URL) async throws -> RemoteLibraryMetadata {
        let data: Data
        do {
            // First, try to get the data from the network
            (data, _) = try await URLSession.shared.data(from: url)
        } catch {
            // If this fails, it's a network/fetch error.
            throw UpdateError.metadataFetchFailed(error)
        }

        do {
            // Now, try to decode the data we received.
            return try JSONDecoder().decode(RemoteLibraryMetadata.self, from: data)
        } catch {
            // If this fails, it's a JSON decoding error.
            throw UpdateError.metadataDecodingFailed(error)
        }
    }

    private static func loadLocalMetadata() -> RemoteLibraryMetadata? {
        guard let applicationSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let metadataURL = applicationSupportDirectory.appendingPathComponent("shippedAppLibrary.json")
        guard let data = try? Data(contentsOf: metadataURL) else { return nil }
        return try? JSONDecoder().decode(RemoteLibraryMetadata.self, from: data)
    }

    private static func downloadAndApplyUpdate(from metadata: RemoteLibraryMetadata) async throws {
        guard let downloadURL = URL(string: "https://github.com/georgetchelidze/CircuitProAppLibrary/raw/main/appLibrary.store") else {
            fatalError("Hardcoded download URL is invalid.")
        }
        
        print("📥 Downloading update from hardcoded URL: \(downloadURL)...")
        
        do {
            // 1. Download the new database to a temporary location
            let (tempLocalURL, _) = try await URLSession.shared.download(from: downloadURL)
            
            // 2. Create a temporary, read-only ModelContainer for the NEW data
            let schema = Schema([Component.self, Symbol.self, Footprint.self])
            let config = ModelConfiguration("update", schema: schema, url: tempLocalURL, allowsSave: false)
            let updateContainer = try ModelContainer(for: schema, configurations: config)
            let updateContext = await updateContainer.mainContext
            
            // 3. Get the MAIN, active model context from our singleton
            let mainContext = await ModelContainerManager.shared.container.mainContext

            // --- 4. Perform the "Hot-Swap" migration ---
            // Fetch all items from the new database
            let newComponents = try updateContext.fetch(FetchDescriptor<Component>())
            let newSymbols = try updateContext.fetch(FetchDescriptor<Symbol>())
            let newFootprints = try updateContext.fetch(FetchDescriptor<Footprint>())
            
            // Insert or update symbols and footprints first, as components depend on them
            for symbol in newSymbols {
                mainContext.insert(symbol)
            }
            for footprint in newFootprints {
                mainContext.insert(footprint)
            }
            
            // Insert or update components. Because of @Attribute(.unique), SwiftData/CoreData
            // will handle this as an "upsert". If an object with the same ID exists,
            // it will be updated. If not, it will be inserted.
            for component in newComponents {
                mainContext.insert(component)
            }
            
            // 5. Save changes to our main, live database
            try mainContext.save()
            
            // 6. Update our local metadata file version
            let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let metadataDestinationURL = appSupportURL.appendingPathComponent("shippedAppLibrary.json")
            let encoder = JSONEncoder()
            let newMetadataData = try encoder.encode(metadata)
            try newMetadataData.write(to: metadataDestinationURL)
            
            print("✅ Hot-swap complete. Library is now version \(metadata.version).")
            
        } catch {
            throw UpdateError.downloadFailed(error)
        }
    }
}
