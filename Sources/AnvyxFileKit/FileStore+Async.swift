//
//  FileStore+Async.swift
//  FileManagerKit
//
//  Created by AnhPT on 10/07/2026.
//

import Foundation

public extension FileStore {
    /// An off-main, `async` view of this store.
    ///
    /// The synchronous `FileStore` methods block the calling thread on
    /// `FileManager` I/O — fine for a stub or a quick lookup, but a `@MainActor`
    /// view model that calls them directly stalls the UI on a big-tree `search`
    /// or a large `copy`/`move`. Reach through `.async` to run the same operation
    /// on the concurrent executor instead:
    ///
    /// ```swift
    /// let hits = try await store.async.search(query, in: folder)
    /// try await store.async.copy(item, to: destination)
    /// ```
    var async: AsyncFileStore { AsyncFileStore(base: self) }
}

/// `async` wrapper around a `FileStore`. Each method forwards to the synchronous
/// core but is `@concurrent`, so the work runs off the caller's actor. `FileItem`
/// is `Sendable`, so results cross back without `sending`. `base` is `any
/// FileStore` (Sendable, since `FileStore` refines `Sendable`), so this is usable
/// through an existential — e.g. a view model holding `any FileStore`.
public struct AsyncFileStore: Sendable {
    let base: any FileStore

    @concurrent
    public func contents(of directory: URL) async throws -> [FileItem] {
        try base.contents(of: directory)
    }

    @concurrent
    public func search(_ query: String, in directory: URL) async throws -> [FileItem] {
        try base.search(query, in: directory)
    }

    @discardableResult
    @concurrent
    public func createFolder(named name: String, in directory: URL) async throws -> FileItem {
        try base.createFolder(named: name, in: directory)
    }

    @discardableResult
    @concurrent
    public func save(_ data: Data, name: String, in directory: URL) async throws -> FileItem {
        try base.save(data, name: name, in: directory)
    }

    @discardableResult
    @concurrent
    public func rename(_ item: FileItem, to newName: String) async throws -> FileItem {
        try base.rename(item, to: newName)
    }

    @discardableResult
    @concurrent
    public func move(_ item: FileItem, to directory: URL) async throws -> FileItem {
        try base.move(item, to: directory)
    }

    @discardableResult
    @concurrent
    public func copy(_ item: FileItem, to directory: URL) async throws -> FileItem {
        try base.copy(item, to: directory)
    }

    @discardableResult
    @concurrent
    public func duplicate(_ item: FileItem) async throws -> FileItem {
        try base.duplicate(item)
    }

    @concurrent
    public func delete(_ item: FileItem) async throws {
        try base.delete(item)
    }
}
