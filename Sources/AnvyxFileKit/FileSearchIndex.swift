//
//  FileSearchIndex.swift
//  FileManagerKit
//
//  Created by AnhPT on 13/07/2026.
//

import Foundation

/// A prebuilt, in-memory name index for fast, repeated file search — build it once
/// from a directory tree, then query it many times without re-walking the disk
/// (unlike ``FileStore/search(_:in:)``, which enumerates on every call).
///
/// ```swift
/// let index = FileSearchIndex(indexing: allItems)
/// let hits = index.search("invoice")   // prefix matches rank first
/// ```
public struct FileSearchIndex: Sendable {
    private struct Entry: Sendable {
        let lowercasedName: String
        let item: FileItem
    }
    private let entries: [Entry]

    /// Index a flat list of items (e.g. gathered recursively by the caller).
    public init(indexing items: [FileItem]) {
        entries = items.map { Entry(lowercasedName: $0.name.lowercased(), item: $0) }
    }

    /// Recursively index every file/folder under `directory`.
    public init(indexing directory: URL, fileManager: FileManager = .default) {
        var items: [FileItem] = []
        if let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: nil) {
            for case let url as URL in enumerator {
                items.append(FileItem(url: url))
            }
        }
        self.init(indexing: items)
    }

    /// Items whose name contains `query` (case-insensitive). Results are ranked:
    /// name-prefix matches first, then earliest match position, then alphabetically.
    public func search(_ query: String) -> [FileItem] {
        let needle = query.lowercased()
        guard !needle.isEmpty else { return entries.map(\.item) }

        let matches = entries.compactMap { entry -> (item: FileItem, offset: Int)? in
            guard let range = entry.lowercasedName.range(of: needle) else { return nil }
            return (entry.item, entry.lowercasedName.distance(from: entry.lowercasedName.startIndex, to: range.lowerBound))
        }
        return matches
            .sorted { lhs, rhs in
                lhs.offset != rhs.offset ? lhs.offset < rhs.offset : lhs.item.name < rhs.item.name
            }
            .map(\.item)
    }

    public var count: Int { entries.count }
}
