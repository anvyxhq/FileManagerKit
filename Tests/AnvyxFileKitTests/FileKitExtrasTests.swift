//
//  FileKitExtrasTests.swift
//  FileManagerKit
//
//  Created by AnhPT on 13/07/2026.
//

import XCTest
@testable import AnvyxFileKit

private final class MemoryFavoritesStore: FavoritesStore, @unchecked Sendable {
    private var paths: [String] = []
    func load() -> [String] { paths }
    func save(_ paths: [String]) { self.paths = paths }
}

private func makeTempDir() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("fk-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

// MARK: - Favorites

@MainActor
final class FileFavoritesTests: XCTestCase {
    func testAddRemoveToggle() {
        let favorites = FileFavorites(store: MemoryFavoritesStore())
        let url = URL(fileURLWithPath: "/tmp/doc.pdf")

        XCTAssertFalse(favorites.isFavorite(url))
        favorites.add(url)
        XCTAssertTrue(favorites.isFavorite(url))
        XCTAssertEqual(favorites.count, 1)

        XCTAssertFalse(favorites.toggle(url))   // now un-favorited
        XCTAssertFalse(favorites.isFavorite(url))
        XCTAssertTrue(favorites.toggle(url))     // back on
    }

    func testPersistsAcrossInstances() {
        let store = MemoryFavoritesStore()
        let url = URL(fileURLWithPath: "/tmp/keep.txt")

        let first = FileFavorites(store: store)
        first.add(url)

        let second = FileFavorites(store: store)   // loads persisted state
        XCTAssertTrue(second.isFavorite(url))
    }
}

// MARK: - Undo

final class FileUndoManagerTests: XCTestCase {
    func testMoveAndUndo() async throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("a.txt")
        let subdir = root.appendingPathComponent("sub", isDirectory: true)
        try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)
        try Data("hi".utf8).write(to: source)

        let undo = try FileUndoManager(trashDirectory: root.appendingPathComponent(".trash"))
        let moved = try await undo.move(source, into: subdir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: moved.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))

        try await undo.undo()
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: moved.path))
    }

    func testDeleteAndUndoRestores() async throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("gone.txt")
        try Data("bye".utf8).write(to: file)

        let undo = try FileUndoManager(trashDirectory: root.appendingPathComponent(".trash"))
        try await undo.delete(file)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path), "soft-deleted")

        let canUndo = await undo.canUndo
        XCTAssertTrue(canUndo)
        try await undo.undo()
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path), "restored from trash")
    }
}

// MARK: - Search index

final class FileSearchIndexTests: XCTestCase {
    func testRanksPrefixMatchesFirst() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        for name in ["invoice.pdf", "my-invoice.pdf", "notes.txt"] {
            try Data().write(to: root.appendingPathComponent(name))
        }
        let items = try FileManager.default
            .contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .map(FileItem.init)

        let hits = FileSearchIndex(indexing: items).search("invoice")
        XCTAssertEqual(hits.map(\.name), ["invoice.pdf", "my-invoice.pdf"])   // prefix match first
    }

    func testEmptyQueryReturnsEverything() {
        let items = [URL(fileURLWithPath: "/a.txt"), URL(fileURLWithPath: "/b.txt")].map(FileItem.init)
        XCTAssertEqual(FileSearchIndex(indexing: items).search("").count, 2)
    }
}

// MARK: - Directory monitor

final class DirectoryMonitorTests: XCTestCase {
    func testEmitsWhenDirectoryChanges() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let stream = DirectoryMonitor.changes(of: dir)
        let observed = Task {
            await withTaskGroup(of: Bool.self) { group in
                group.addTask { for await _ in stream { return true }; return false }
                group.addTask { try? await Task.sleep(nanoseconds: 3_000_000_000); return false }
                let result = await group.next() ?? false
                group.cancelAll()
                return result
            }
        }

        try await Task.sleep(nanoseconds: 150_000_000)   // let the watch attach
        try Data("x".utf8).write(to: dir.appendingPathComponent("new.txt"))

        let got = await observed.value
        XCTAssertTrue(got, "monitor should emit when a file is added")
    }
}
