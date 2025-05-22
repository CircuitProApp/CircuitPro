//
//  RecentProjectsUtil.swift
//  CodeEdit
//
//  Created by Khan Winter on 10/22/24.
//
import AppKit

enum RecentProjectsStore {
    private static let bookmarksKey = "recentProjectBookmarks"
    static let didUpdateNotification = Notification.Name("RecentProjectsStore.didUpdate")

    private struct BookmarkEntry: Codable, Equatable {
        let urlPath: String
        let bookmarkData: Data

        var url: URL? {
            var isStale = false
            return try? URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withoutUI, .withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        }

        static func == (lhs: BookmarkEntry, rhs: BookmarkEntry) -> Bool {
            lhs.urlPath == rhs.urlPath
        }
    }

    // MARK: - Public API

    /// Return all recent project URLs (resolved from bookmarks).
    static func recentProjectURLs() -> [URL] {
        loadBookmarks()
            .compactMap { entry in
                guard let resolved = entry.url else { return nil }
                return resolved
            }
    }

    /// Notify the store that a project was opened.
    /// Saves its bookmark and moves it to the front.
    static func documentOpened(at url: URL) {
        do {
            let bookmark = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            var bookmarks = loadBookmarks()

            // Remove duplicates
            bookmarks.removeAll(where: { $0.urlPath == url.path })
            bookmarks.insert(BookmarkEntry(urlPath: url.path, bookmarkData: bookmark), at: 0)

            saveBookmarks(Array(bookmarks.prefix(100)))
        } catch {
            print("❌ Failed to create bookmark for recent project: \(error)")
        }
    }

    /// Remove selected projects from the recent list.
    static func removeRecentProjects(_ urlsToRemove: Set<URL>) -> [URL] {
        var bookmarks = loadBookmarks()
        bookmarks.removeAll(where: { entry in urlsToRemove.contains(where: { $0.path == entry.urlPath }) })
        saveBookmarks(bookmarks)
        return recentProjectURLs()
    }

    /// Clear all stored recent projects.
    static func clearList() {
        saveBookmarks([])
    }

    // MARK: - Bookmark Access

    /// Call this before opening a project from recent list.
    static func beginAccessing(_ url: URL) -> Bool {
        url.startAccessingSecurityScopedResource()
    }

    /// Call this after the project is fully opened.
    static func endAccessing(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
    }

    // MARK: - Internal

    private static func loadBookmarks() -> [BookmarkEntry] {
        guard let data = UserDefaults.standard.data(forKey: bookmarksKey),
              let decoded = try? PropertyListDecoder().decode([BookmarkEntry].self, from: data)
        else { return [] }
        return decoded
    }

    private static func saveBookmarks(_ entries: [BookmarkEntry]) {
        guard let data = try? PropertyListEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: bookmarksKey)
        NotificationCenter.default.post(name: didUpdateNotification, object: nil)
    }
}
