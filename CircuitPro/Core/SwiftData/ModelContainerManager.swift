import SwiftData
import SwiftUI
import SQLite3

// Centralized naming convention for all store and metadata files.
private struct StoreFileNames {
    // The name used for the ModelConfiguration, which should be consistent.
    static let appLibraryConfigurationName = "appLibrary"
    static let userLibraryConfigurationName = "userLibrary"
    
    // The actual filenames on disk.
    static let releaseAppStore = "appLibrary.store"
    static let debugAppStore = "appLibrary_debug.store"
    static let userStore = "userLibrary.store"
    
    // Metadata file, now consistent across the app.
    static let metadata = "appLibrary.json"
}


final class ModelContainerManager {

    static let shared = ModelContainerManager()
    let container: ModelContainer
    private(set) var appLibraryStoreURL: URL?

    // A helper to get the application support directory URL.
    static var applicationSupportDirectory: URL {
        guard let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Unable to determine Application Support directory.")
        }
        return url
    }

    private init() {
        let schema = Schema([Component.self, Symbol.self, Footprint.self])
        
        do {
            #if DEBUG
            // --- DEBUG MODE ---
            print("🔬 Running in DEBUG mode. App and User libraries are writable.")
            
            // Explicitly define URLs for debug versions of the stores.
            let appLibraryURL = Self.applicationSupportDirectory.appendingPathComponent(StoreFileNames.debugAppStore)
            let userLibraryURL = Self.applicationSupportDirectory.appendingPathComponent(StoreFileNames.userStore)

            let appLibraryConfig = ModelConfiguration(
                StoreFileNames.appLibraryConfigurationName, // Consistent config name
                schema: schema,
                url: appLibraryURL, // Specific debug file URL
                allowsSave: true
            )
            let userLibraryConfig = ModelConfiguration(
                StoreFileNames.userLibraryConfigurationName,
                schema: schema,
                url: userLibraryURL,
                allowsSave: true
            )
            
            container = try ModelContainer(for: schema, configurations: [appLibraryConfig, userLibraryConfig])
            self.appLibraryStoreURL = appLibraryURL
            
            #else
            // --- RELEASE MODE ---
            print("🚀 Running in RELEASE mode. App library is managed; User library is writable.")
            
            // 1. Prepare the release library.
            let (preparedStoreURL, _) = Self.prepareReleaseAppLibrary()
            self.appLibraryStoreURL = preparedStoreURL

            // 2. Create a writable configuration for the main app library to allow for hot-swapping.
            let appLibraryConfig = ModelConfiguration(
                StoreFileNames.appLibraryConfigurationName,
                schema: schema,
                url: preparedStoreURL,
                allowsSave: true // Required for the updater to function.
            )
            
            // 3. User library is standard.
            let userLibraryConfig = ModelConfiguration(StoreFileNames.userLibraryConfigurationName, schema: schema, allowsSave: true)
            
            container = try ModelContainer(for: schema, configurations: [appLibraryConfig, userLibraryConfig])
            
            #endif
            print("✅ ModelContainer initialized successfully.")
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    private static func prepareReleaseAppLibrary() -> (storeURL: URL, metadataURL: URL) {
        let storeURL = self.applicationSupportDirectory.appendingPathComponent(StoreFileNames.releaseAppStore)
        let metadataURL = self.applicationSupportDirectory.appendingPathComponent(StoreFileNames.metadata)
        
        // If the store file already exists, we're done.
        if FileManager.default.fileExists(atPath: storeURL.path) {
            return (storeURL, metadataURL)
        }
        
        // If not, create a new empty library and its corresponding metadata file.
        print("ℹ️ App library not found. Creating a new empty library and metadata...")
        do {
            try createEmptySwiftDataStore(at: storeURL, models: [Component.self, Symbol.self, Footprint.self])
            try setSQLiteJournalModeDelete(at: storeURL)
            
            // Use the consistent metadata struct.
            let initialMetadata = LibraryMetadata(version: "0.0.1")
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let metadataData = try encoder.encode(initialMetadata)
            try metadataData.write(to: metadataURL)

            print("✅ Successfully created initial library and metadata files.")
        } catch {
            fatalError("Failed to create initial library from scratch: \(error)")
        }
        
        return (storeURL, metadataURL)
    }
}

// MARK: - SQLite and SwiftData Helpers

private extension ModelContainerManager {
    static func createEmptySwiftDataStore(at url: URL, models: [any PersistentModel.Type]) throws {
        let schema = Schema(models)
        let config = ModelConfiguration(url: url) // Name is irrelevant for this temporary container.
        _ = try ModelContainer(for: schema, configurations: config)
    }

    static func setSQLiteJournalModeDelete(at url: URL) throws {
        var db: OpaquePointer?
        defer { sqlite3_close(db) }
        let rcOpen = sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READWRITE, nil)
        guard rcOpen == SQLITE_OK else {
            throw NSError(domain: "SQLite", code: Int(rcOpen), userInfo: [NSLocalizedDescriptionKey: "Failed to open database at \(url.path)"])
        }
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
