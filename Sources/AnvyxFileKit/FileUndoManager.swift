//
//  FileUndoManager.swift
//  FileManagerKit
//
//  Created by AnhPT on 13/07/2026.
//

import Foundation

/// Performs **undoable** move and delete operations. Deletes are soft — the file
/// is moved to a trash directory — so they can be restored. `undo()` reverses the
/// most recent operation; call it from an undo button or a "shake to undo".
///
/// ```swift
/// let undo = try FileUndoManager(trashDirectory: trashURL)
/// try await undo.delete(fileURL)     // moved to trash
/// try await undo.undo()              // restored
/// ```
public actor FileUndoManager {
    private enum Operation {
        case move(from: URL, to: URL)
        case delete(original: URL, trashed: URL)
    }

    private let fileManager = FileManager.default
    private let trash: URL
    private var history: [Operation] = []

    public init(trashDirectory: URL) throws {
        trash = trashDirectory
        try FileManager.default.createDirectory(at: trashDirectory, withIntermediateDirectories: true)
    }

    public var canUndo: Bool { !history.isEmpty }

    /// Move `url` into `directory`, recording it for undo. Returns the new URL.
    @discardableResult
    public func move(_ url: URL, into directory: URL) throws -> URL {
        let destination = directory.appendingPathComponent(url.lastPathComponent)
        try fileManager.moveItem(at: url, to: destination)
        history.append(.move(from: url, to: destination))
        return destination
    }

    /// Soft-delete `url` by moving it to the trash directory, recording it for undo.
    public func delete(_ url: URL) throws {
        let trashed = trash.appendingPathComponent("\(UUID().uuidString)-\(url.lastPathComponent)")
        try fileManager.moveItem(at: url, to: trashed)
        history.append(.delete(original: url, trashed: trashed))
    }

    /// Reverse the most recent operation (move back / restore from trash).
    public func undo() throws {
        guard let operation = history.popLast() else { return }
        switch operation {
        case let .move(from, to):
            try fileManager.moveItem(at: to, to: from)
        case let .delete(original, trashed):
            try fileManager.moveItem(at: trashed, to: original)
        }
    }

    /// Permanently discard everything in the trash (undo history for deletes is
    /// dropped too, since those files are gone).
    public func emptyTrash() throws {
        for url in (try? fileManager.contentsOfDirectory(at: trash, includingPropertiesForKeys: nil)) ?? [] {
            try? fileManager.removeItem(at: url)
        }
        history.removeAll { if case .delete = $0 { return true }; return false }
    }
}
