//
//  FileStore.swift
//  FileManagerKit
//
//  Created by AnhPT on 04/07/2026.
//

import Foundation

public enum FileStoreError: Error, Sendable {
    case nameAlreadyExists
    case notFound
}

/// The file-operations port a view model depends on — inject `any FileStore` so
/// features stay decoupled from `FileManager` and can be driven by a stub/temp
/// directory in tests.
public protocol FileStore: Sendable {
    /// Root folder the store manages (e.g. the app's Documents directory).
    var root: URL { get }

    func contents(of directory: URL) throws -> [FileItem]

    /// Recursively find items whose name contains `query` (case-insensitive).
    func search(_ query: String, in directory: URL) throws -> [FileItem]

    @discardableResult
    func createFolder(named name: String, in directory: URL) throws -> FileItem

    /// Write `data` as `name` (with extension). Auto-renames on collision.
    @discardableResult
    func save(_ data: Data, name: String, in directory: URL) throws -> FileItem

    /// Rename in place. Throws `nameAlreadyExists` if the target exists.
    @discardableResult
    func rename(_ item: FileItem, to newName: String) throws -> FileItem

    /// Move into `directory`, auto-renaming on collision.
    @discardableResult
    func move(_ item: FileItem, to directory: URL) throws -> FileItem

    /// Copy into `directory`, auto-renaming on collision.
    @discardableResult
    func copy(_ item: FileItem, to directory: URL) throws -> FileItem

    /// Copy next to the original with an incremented name (e.g. "note (1)").
    @discardableResult
    func duplicate(_ item: FileItem) throws -> FileItem

    func delete(_ item: FileItem) throws
}
