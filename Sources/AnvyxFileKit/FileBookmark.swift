//
//  FileBookmark.swift
//  FileManagerKit
//
//  Created by AnhPT on 13/07/2026.
//

import Foundation

/// Persist access to a file the user picked (e.g. from the document picker or an
/// external/iCloud location) across app launches, via **security-scoped
/// bookmarks**. Store the ``create(for:)`` data; on next launch ``resolve(_:)`` it
/// and wrap file work in ``withAccess(to:_:)`` so the sandbox grants access.
///
/// ```swift
/// let data = try FileBookmark.create(for: pickedURL)   // persist `data`
/// // …next launch:
/// let resolved = try FileBookmark.resolve(data)
/// let text = try FileBookmark.withAccess(to: resolved.url) { try String(contentsOf: $0) }
/// ```
public enum FileBookmark {

    /// A resolved bookmark: the URL plus whether the bookmark went **stale**
    /// (the file moved/changed) and should be re-created.
    public struct Resolved: Sendable {
        public let url: URL
        public let isStale: Bool
    }

    /// Create bookmark data that can be resolved later to regain access to `url`.
    public static func create(for url: URL) throws -> Data {
        #if os(macOS)
        try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        #else
        try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        #endif
    }

    /// Resolve bookmark data back into a URL.
    public static func resolve(_ data: Data) throws -> Resolved {
        var isStale = false
        #if os(macOS)
        let options: URL.BookmarkResolutionOptions = [.withSecurityScope]
        #else
        let options: URL.BookmarkResolutionOptions = []
        #endif
        let url = try URL(resolvingBookmarkData: data, options: options, relativeTo: nil, bookmarkDataIsStale: &isStale)
        return Resolved(url: url, isStale: isStale)
    }

    /// Resolve, and when the bookmark is stale, also return freshly-created
    /// bookmark data to persist in its place (`nil` when still valid or if the
    /// refresh itself fails).
    public static func resolveRefreshing(_ data: Data) throws -> (resolved: Resolved, refreshed: Data?) {
        let resolved = try resolve(data)
        let refreshed = resolved.isStale ? try? create(for: resolved.url) : nil
        return (resolved, refreshed)
    }

    /// Run `body` while the security-scoped resource at `url` is accessible,
    /// releasing the claim afterward. Non-scoped URLs (e.g. inside the app
    /// sandbox) simply run `body` without a claim.
    @discardableResult
    public static func withAccess<T>(to url: URL, _ body: (URL) throws -> T) rethrows -> T {
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }
        return try body(url)
    }
}
