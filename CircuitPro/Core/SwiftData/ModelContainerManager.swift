import SwiftData
import SwiftUI
import SQLite3

final class ModelContainerManager {

    static let shared = ModelContainerManager()
    let container: ModelContainer
    private(set) var appLibraryStoreURL: URL?

    private init() {
        let schema = Schema([Component.self, Symbol.self, Footprint.self])
        
        do {
            #if DEBUG
            print("🔬 Running in DEBUG mode. App Library is writable.")
            let appLibraryConfig = ModelConfiguration("appLibrary", schema: schema, allowsSave: true)
            let userLibraryConfig = ModelConfiguration("userLibrary", schema: schema, allowsSave: true)
            container = try ModelContainer(for: Component.self, Symbol.self, Footprint.self, configurations: appLibraryConfig, userLibraryConfig)
            #else
            print("🚀 Running in RELEASE mode. App Library is read-only.")
            let (preparedStoreURL, _) = Self.prepareAppLibraryForRelease()
            self.appLibraryStoreURL = preparedStoreURL
            let appLibraryConfig = ModelConfiguration("appLibrary", schema: schema, url: preparedStoreURL, allowsSave: false)
            let userLibraryConfig = ModelConfiguration("userLibrary", schema: schema, allowsSave: true)
            container = try ModelContainer(for: Component.self, Symbol.self, Footprint.self, configurations: appLibraryConfig, userLibraryConfig)
            #endif
            print("✅ ModelContainer initialized successfully.")
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    private static func prepareAppLibraryForRelease() -> (storeURL: URL, metadataURL: URL) {
        guard let applicationSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Unable to determine Application Support directory.")
        }
        
        let storeURL = applicationSupportDirectory.appendingPathComponent("shippedAppLibrary.store")
        let metadataURL = applicationSupportDirectory.appendingPathComponent("shippedAppLibrary.json")
        
        if FileManager.default.fileExists(atPath: storeURL.path) {
            return (storeURL, metadataURL)
        }
        
        print("ℹ️ Shipped library not found. Creating a new empty library and metadata...")
        do {
            try createEmptySwiftDataStore(at: storeURL, models: [Component.self, Symbol.self, Footprint.self])
            try setSQLiteJournalModeDelete(at: storeURL)
            
            // --- THIS IS THE NEW PART ---
            // Create and write the initial metadata JSON file.
            let initialMetadata = LibraryMetadata(version: "0.0.1")
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let metadataData = try encoder.encode(initialMetadata)
            try metadataData.write(to: metadataURL)
            // --------------------------

            print("✅ Successfully created initial library and metadata files.")
        } catch {
            fatalError("Failed to create initial library from scratch: \(error)")
        }
        
        return (storeURL, metadataURL)
    }
}

// MARK: - Models and Helpers

// Define the metadata structure that your app will use.
private struct LibraryMetadata: Codable {
    let version: String
    // You can add other fields here later for your full update mechanism
    // let releaseDate: Date?
    // let downloadURL: URL?
}

private extension ModelContainerManager {
    static func createEmptySwiftDataStore(at url: URL, models: [any PersistentModel.Type]) throws {
        let schema = Schema(models)
        let config = ModelConfiguration(url: url)
        _ = try ModelContainer(for: schema, configurations: config)
    }

    static func setSQLiteJournalModeDelete(at url: URL) throws {
        var db: OpaquePointer?
        defer { sqlite3_close(db) }
        let rcOpen = sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READWRITE, nil)
        guard rcOpen == SQLITE_OK else { throw NSError(domain: "SQLite", code: Int(rcOpen), userInfo: [NSLocalizedDescriptionKey: "Failed to open database at \(url.path)"]) }
        let sql = "PRAGMA journal_mode=DELETE;"
        var errMsg: UnsafeMutablePointer<Int8>?
        let rcExec = sqlite3_exec(db, sql, nil, nil, &errMsg)
        if rcExec != SQLITE_OK {
            let message = String(cString: errMsg!)
            sqlite3_free(errMsg)
            throw NSError(domain: "SQLite", code: Int(rcExec), userInfo: [NSLocalizedDescriptionKey: message, "sql": sql])
        }
    }
}
