//
//  DocumentFileStore.swift
//  FileManagerKit
//
//  Created by AnhPT on 04/07/2026.
//

import Foundation

/// `FileStore` backed by `FileManager`, rooted at a directory (Documents by
/// default). Collision handling appends " (1)", " (2)", … like the Files app.
public struct DocumentFileStore: FileStore {
    public let root: URL
    private var fileManager: FileManager { .default }

    public init(root: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]) {
        self.root = root
    }

    public func contents(of directory: URL) throws -> [FileItem] {
        let urls = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .creationDateKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        return urls.map(FileItem.init(url:))
    }

    public func search(_ query: String, in directory: URL) throws -> [FileItem] {
        guard !query.isEmpty,
              let enumerator = fileManager.enumerator(
                at: directory,
                // Prefetch exactly the keys FileItem reads, so building a match
                // hits the cache instead of an extra stat per file.
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .creationDateKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
              )
        else { return [] }

        var results: [FileItem] = []
        for case let url as URL in enumerator where url.lastPathComponent.localizedCaseInsensitiveContains(query) {
            results.append(FileItem(url: url))
        }
        return results
    }

    @discardableResult
    public func createFolder(named name: String, in directory: URL) throws -> FileItem {
        let url = uniqueURL(baseName: name, extension: nil, in: directory)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return FileItem(url: url)
    }

    @discardableResult
    public func save(_ data: Data, name: String, in directory: URL) throws -> FileItem {
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        let url = uniqueURL(baseName: base, extension: ext.isEmpty ? nil : ext, in: directory)
        try data.write(to: url, options: .atomic)
        return FileItem(url: url)
    }

    @discardableResult
    public func rename(_ item: FileItem, to newName: String) throws -> FileItem {
        let directory = item.url.deletingLastPathComponent()
        var destination = directory.appendingPathComponent(newName)
        if !item.isDirectory, !item.url.pathExtension.isEmpty {
            destination = destination.appendingPathExtension(item.url.pathExtension)
        }
        guard destination != item.url else { return item }
        guard !fileManager.fileExists(atPath: destination.path) else { throw FileStoreError.nameAlreadyExists }
        try fileManager.moveItem(at: item.url, to: destination)
        return FileItem(url: destination)
    }

    @discardableResult
    public func move(_ item: FileItem, to directory: URL) throws -> FileItem {
        let destination = uniqueURL(for: item, in: directory)
        try fileManager.moveItem(at: item.url, to: destination)
        return FileItem(url: destination)
    }

    @discardableResult
    public func copy(_ item: FileItem, to directory: URL) throws -> FileItem {
        let destination = uniqueURL(for: item, in: directory)
        try fileManager.copyItem(at: item.url, to: destination)
        return FileItem(url: destination)
    }

    @discardableResult
    public func duplicate(_ item: FileItem) throws -> FileItem {
        try copy(item, to: item.url.deletingLastPathComponent())
    }

    public func delete(_ item: FileItem) throws {
        try fileManager.removeItem(at: item.url)
    }

    // MARK: - Collision-safe naming

    private func uniqueURL(for item: FileItem, in directory: URL) -> URL {
        let base = item.isDirectory ? item.name : item.url.deletingPathExtension().lastPathComponent
        let ext = item.isDirectory ? nil : (item.url.pathExtension.isEmpty ? nil : item.url.pathExtension)
        return uniqueURL(baseName: base, extension: ext, in: directory)
    }

    /// Collision-safe name in `directory`. Reads the directory **once** and picks
    /// the smallest free `" (n)"` index (reusing gaps) — instead of probing the
    /// filesystem with a `fileExists` syscall per candidate.
    private func uniqueURL(baseName: String, extension ext: String?, in directory: URL) -> URL {
        func compose(_ name: String) -> URL {
            let url = directory.appendingPathComponent(name)
            return ext.map { url.appendingPathExtension($0) } ?? url
        }

        let existing = Set((try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? [])
        let fullExtension = ext.map { ".\($0)" } ?? ""

        // Index 0 = the bare name.
        if !existing.contains("\(baseName)\(fullExtension)") {
            return compose(baseName)
        }

        // Gather taken " (n)" indices in one pass, then take the smallest free one.
        let openPrefix = "\(baseName) ("
        let closeSuffix = ")\(fullExtension)"
        var taken: Set<Int> = []
        for name in existing
        where name.hasPrefix(openPrefix)
            && name.hasSuffix(closeSuffix)
            && name.count > openPrefix.count + closeSuffix.count {
            let inner = name.dropFirst(openPrefix.count).dropLast(closeSuffix.count)
            if let index = Int(inner), index > 0 { taken.insert(index) }
        }

        var index = 1
        while taken.contains(index) { index += 1 }   // in-memory O(1) lookups
        return compose("\(baseName) (\(index))")
    }
}
