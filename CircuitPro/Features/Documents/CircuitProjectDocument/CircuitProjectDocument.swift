//
//  CircuitProjectDocument.swift
//  CircuitPro
//
//  Updated 31 May 2025 — adds “Fix A” (skip folder creation during autosave)
//

import SwiftUI
import UniformTypeIdentifiers

// ───────── Helpers ──────────────────────────────────────────────────────────
private extension URL {
    /// True for sandbox safe-write bundles and any /TemporaryItems path.
    var isTemporaryWriteLocation: Bool {
        path.contains("/TemporaryItems") || lastPathComponent.contains(".sb-")
    }
}

// ───────── Document ────────────────────────────────────────────────────────
class CircuitProjectDocument: NSDocument {

    // MARK: – Model
    var model = CircuitProject(name: "Untitled", designs: [])
    /// Permanent parent folder of the .circuitproj file.
    private(set) var projectFolderURL: URL?

    // MARK: – Security-scope bookkeeping
    private var scopedAccessWasStarted = false
    private let bookmarkKeyPrefix = "CircuitPro.Bookmark."

    override class var autosavesInPlace: Bool { true }

    // MARK: – Init
    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    // MARK: – Window setup
    override func makeWindowControllers() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.center()
        window.title         = "CircuitPro Project"
        window.toolbarStyle  = .unifiedCompact
        window.contentView   = NSHostingView(rootView: WorkspaceView(document: self))
        window.toolbar       = NSToolbar(identifier: "CustomToolbar").apply {
            $0.displayMode = .iconOnly
            $0.allowsUserCustomization = false
        }

        addWindowController(NSWindowController(window: window))
    }

    // MARK: – Read
    override func read(from url: URL, ofType typeName: String) throws {
        // 1️⃣ try bookmark
        let folderName = url.deletingPathExtension().lastPathComponent
        if let restored = restoreBookmark(for: folderName) {
            scopedAccessWasStarted = true
            projectFolderURL = restored
            model = try JSONDecoder().decode(
                CircuitProject.self,
                from: Data(contentsOf: restored.appendingPathComponent("\(folderName).circuitproj"))
            )
            return
        }

        // 2️⃣ normal open
        var isDir = ObjCBool(false)
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            projectFolderURL = url
            model = try JSONDecoder().decode(
                CircuitProject.self,
                from: Data(contentsOf: url.appendingPathComponent("\(url.lastPathComponent).circuitproj"))
            )
        } else {
            projectFolderURL = url.deletingLastPathComponent()
            model = try JSONDecoder().decode(CircuitProject.self, from: Data(contentsOf: url))
        }

        // 3️⃣ security scope (only for real folders)
        if let folder = projectFolderURL,
           !folder.isTemporaryWriteLocation,
           folder.startAccessingSecurityScopedResource() {
            scopedAccessWasStarted = true
            saveBookmark(for: folder)
        }
    }

    // MARK: – Write / Autosave
    override func write(
        to url: URL,
        ofType typeName: String,
        for saveOperation: SaveOperationType,
        originalContentsURL: URL?
    ) throws {

        let fm            = FileManager.default
        let isTempURL     = url.isTemporaryWriteLocation
        let canonicalURL  = isTempURL ? (self.fileURL ?? url) : url
        let canonicalDir  = canonicalURL.deletingLastPathComponent()

        // ensure container exists (temp bundle or real dir)
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

        // make sure we have at least one design
        if model.designs.isEmpty {
            model.designs = [CircuitDesign(name: "Design 1", folderPath: "Design 1")]
        }

        // 3️⃣ write JSON file (always)
        try JSONEncoder().encode(model).write(to: url)

        // 4️⃣ create / update design folders ***only for real save***
        if !isTempURL {                                                 // ← Fix A guard
            for design in model.designs {
                let designFolder = canonicalDir.appendingPathComponent(design.folderPath)
                try fm.createDirectory(at: designFolder, withIntermediateDirectories: true)

                let files = [
                    designFolder.appendingPathComponent("schematic.sch"),
                    designFolder.appendingPathComponent("layout.pcb"),
                    designFolder.appendingPathComponent("components.json")
                ]
                for file in files where !fm.fileExists(atPath: file.path) {
                    if file.pathExtension == "json" {
                        try JSONSerialization.data(withJSONObject: []).write(to: file)
                    } else {
                        try Data().write(to: file)
                    }
                }
            }
            projectFolderURL = canonicalDir
            saveBookmark(for: canonicalDir)
        }

        // 5️⃣ let NSDocument know
        self.fileURL = canonicalURL
    }

    override func writableTypes(for _: NSDocument.SaveOperationType) -> [String] {
        [UTType.circuitProject.identifier]
    }

    // MARK: – Close
    override func close() {
        if scopedAccessWasStarted, let folder = projectFolderURL {
            folder.stopAccessingSecurityScopedResource()
            scopedAccessWasStarted = false
        }
        super.close()
    }

    // MARK: – App became active
    @objc private func applicationDidBecomeActive() {
        guard !scopedAccessWasStarted,
              let folder = projectFolderURL,
              !folder.isTemporaryWriteLocation,
              folder.startAccessingSecurityScopedResource() else { return }
        scopedAccessWasStarted = true
    }

    // MARK: – Rename Design (model-first, folder-second)
    func renameDesign(for design: CircuitDesign) throws {
        let trimmed = design.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != design.folderPath else { return }

        let oldFolderName = design.folderPath
        design.folderPath = trimmed
        updateChangeCount(.changeDone)

        guard let folderURL = projectFolderURL,
              FileManager.default.fileExists(atPath: folderURL.path),
              !folderURL.isTemporaryWriteLocation else { return }

        let fm        = FileManager.default
        let oldFolder = folderURL.appendingPathComponent(oldFolderName)
        let newFolder = folderURL.appendingPathComponent(trimmed)
        if fm.fileExists(atPath: oldFolder.path), oldFolder != newFolder {
            try fm.moveItem(at: oldFolder, to: newFolder)
        }
    }

    // MARK: – Bookmarks
    private func saveBookmark(for url: URL) {
        guard !url.isTemporaryWriteLocation else { return }
        do {
            let data = try url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess])
            UserDefaults.standard.set(data, forKey: bookmarkKeyPrefix + url.lastPathComponent)
        } catch {
            Swift.print("❌ Bookmark save failed:", error)
        }
    }

    private func restoreBookmark(for name: String) -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKeyPrefix + name) else { return nil }
        var stale = false
        do {
            let url = try URL(resolvingBookmarkData: data, options: [.withSecurityScope], bookmarkDataIsStale: &stale)
            return url.startAccessingSecurityScopedResource() ? url : nil
        } catch { return nil }
    }
}

// ───────── Small helper extension ───────────────────────────────────────────
private extension NSToolbar {
    func apply(_ build: (NSToolbar) -> Void) -> NSToolbar { build(self); return self }
}
