import SwiftUI
import SwiftData
import SQLite3
import UniformTypeIdentifiers

#if DEBUG
/// Developer-only utilities for exporting a clean, single-file SwiftData store.
/// This version correctly handles the macOS App Sandbox by using an NSSavePanel
/// to ask the developer where to save the exported file.
final class DeveloperTools {

    static func exportAndSavePopulatedLibrary() {
        print("🛠️ Starting populated library export...")
        do {
            let tempURL = try exportToTemporaryFile()
            presentFolderPicker(for: tempURL, fileBaseName: "appLibrary")
        } catch {
            print("❌ Export failed: \(error)")
        }
    }

    static func exportAndSaveEmptyLibrary() {
        print("🛠️ Starting empty library export...")
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("store")
        do {
            try createEmptySwiftDataStore(at: tempURL, models: [Component.self, Symbol.self, Footprint.self])
            try setSQLiteJournalModeDelete(at: tempURL)
            try vacuum(at: tempURL)
            presentFolderPicker(for: tempURL, fileBaseName: "appLibrary")
        } catch {
            print("❌ Export failed: \(error)")
        }
    }
    
    /// Presents an NSOpenPanel configured to select a folder, then saves the .store and .json files inside it.
    private static func presentFolderPicker(for sourceStoreURL: URL, fileBaseName: String) {
        // --- THIS IS THE CORRECT IMPLEMENTATION ---
        // Use NSOpenPanel, not NSSavePanel, to select a directory.
        let panel = NSOpenPanel()
        
        panel.title = "Choose Folder to Export Library Files"
        panel.prompt = "Choose" // The button text
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        // ------------------------------------------

        if panel.runModal() == .OK {
            // panel.url will be the URL of the FOLDER the user chose.
            guard let folderURL = panel.url else {
                print("❌ Could not get destination folder URL from panel.")
                return
            }
            
            // Construct the final URLs for both files INSIDE the chosen folder.
            let storeDestinationURL = folderURL.appendingPathComponent("\(fileBaseName).store")
            let jsonDestinationURL = folderURL.appendingPathComponent("\(fileBaseName).json")
            
            do {
                // Save the .store file
                try? FileManager.default.removeItem(at: storeDestinationURL)
                try FileManager.default.copyItem(at: sourceStoreURL, to: storeDestinationURL)
                print("✅ Library .store file successfully exported to \(storeDestinationURL.path)")

                // Save the .json file
                let jsonTemplate = """
                {
                    "version": "0.0.1",
                }
                """
                try jsonTemplate.write(to: jsonDestinationURL, atomically: true, encoding: .utf8)
                print("✅ Template .json file also created at \(jsonDestinationURL.path)")
                
            } catch {
                print("❌ Failed to copy file or create JSON template in the chosen folder: \(error)")
            }
        } else {
            print("ℹ️ Export was cancelled by the user.")
        }
    }
    
    private static func exportToTemporaryFile() throws -> URL {
        guard let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { fatalError("Cannot find Application Support directory.") }
        let sourceURL = appSupportURL.appendingPathComponent("appLibrary.store")
        guard FileManager.default.fileExists(atPath: sourceURL.path) else { throw NSError(domain: "DevTools", code: 1, userInfo: [NSLocalizedDescriptionKey: "Source developer library not found."]) }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("store")
        try vacuumInto(from: sourceURL, to: tempURL)
        try setSQLiteJournalModeDelete(at: tempURL)
        print("✅ Export to temporary location successful: \(tempURL.path)")
        return tempURL
    }
}

// MARK: - UTType Definition
private extension UTType {
    // Define a Uniform Type Identifier for our .store file extension so the Save Panel can use it.
    static let database = UTType(filenameExtension: "store")!
}

// MARK: - SwiftData helper for creating an empty store
private extension DeveloperTools {
    static func createEmptySwiftDataStore(at url: URL, models: [any PersistentModel.Type]) throws {
        let schema = Schema(models)
        let config = ModelConfiguration(url: url)
        _ = try ModelContainer(for: schema, configurations: config)
    }
}

// MARK: - SQLite helpers
private extension DeveloperTools {
    static func vacuumInto(from source: URL, to dest: URL) throws {
        try? FileManager.default.removeItem(at: dest)
        var db: OpaquePointer?
        // Note: Open source in READONLY mode for safety during export.
        try openSQLite(at: source, flags: SQLITE_OPEN_READONLY, db: &db)
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 4000)
        let safePath = dest.path.replacingOccurrences(of: "'", with: "''")
        let sql = "VACUUM INTO '\(safePath)';"
        try exec(db, sql: sql)
    }

    static func setSQLiteJournalModeDelete(at url: URL) throws {
        var db: OpaquePointer?
        try openSQLite(at: url, flags: SQLITE_OPEN_READWRITE, db: &db)
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 4000)
        try exec(db, sql: "PRAGMA journal_mode=DELETE;")
    }

    static func vacuum(at url: URL) throws {
        var db: OpaquePointer?
        try openSQLite(at: url, flags: SQLITE_OPEN_READWRITE, db: &db)
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 4000)
        try exec(db, sql: "VACUUM;")
    }

    static func openSQLite(at url: URL, flags: Int32, db: inout OpaquePointer?) throws {
        let rc = sqlite3_open_v2(url.path, &db, flags, nil)
        guard rc == SQLITE_OK, db != nil else {
            let message = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            throw NSError(domain: "SQLiteOpen", code: Int(rc), userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    static func exec(_ db: OpaquePointer?, sql: String) throws {
        var errMsg: UnsafeMutablePointer<Int8>? = nil
        let rc = sqlite3_exec(db, sql, nil, nil, &errMsg)
        if rc != SQLITE_OK {
            let message = String(cString: errMsg!)
            sqlite3_free(errMsg)
            throw NSError(domain: "SQLiteExec", code: Int(rc), userInfo: [NSLocalizedDescriptionKey: message, "sql": sql])
        }
    }
}
#endif
