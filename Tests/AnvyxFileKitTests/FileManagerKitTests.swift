//
//  FileManagerKitTests.swift
//  FileManagerKit
//
//  Created by AnhPT on 04/07/2026.
//

import XCTest
@testable import AnvyxFileKit

final class FileManagerKitTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testSaveListAndKind() throws {
        let store = DocumentFileStore(root: root)
        let item = try store.save(Data("hi".utf8), name: "note.txt", in: root)

        XCTAssertEqual(item.displayName, "note")
        XCTAssertEqual(item.kind, .text)
        XCTAssertEqual(try store.contents(of: root).count, 1)
    }

    func testCollisionAutoIncrements() throws {
        let store = DocumentFileStore(root: root)
        let a = try store.save(Data(), name: "doc.pdf", in: root)
        let b = try store.save(Data(), name: "doc.pdf", in: root)

        XCTAssertEqual(a.displayName, "doc")
        XCTAssertEqual(b.displayName, "doc (1)")
        XCTAssertEqual(try store.contents(of: root).count, 2)
    }

    func testCollisionReusesSmallestFreeGap() throws {
        let store = DocumentFileStore(root: root)
        let a = try store.save(Data(), name: "note.txt", in: root)   // note
        let b = try store.save(Data(), name: "note.txt", in: root)   // note (1)
        _ = try store.save(Data(), name: "note.txt", in: root)       // note (2)
        XCTAssertEqual(a.displayName, "note")
        XCTAssertEqual(b.displayName, "note (1)")

        // Free up the (1) slot, then the next save should reuse it — not jump to (3).
        try store.delete(b)
        let reused = try store.save(Data(), name: "note.txt", in: root)
        XCTAssertEqual(reused.displayName, "note (1)")
    }

    func testFolderRenameDuplicateDelete() throws {
        let store = DocumentFileStore(root: root)
        let folder = try store.createFolder(named: "Docs", in: root)
        XCTAssertTrue(folder.isDirectory)

        let file = try store.save(Data(), name: "a.txt", in: root)
        let renamed = try store.rename(file, to: "b")
        XCTAssertEqual(renamed.displayName, "b")

        let dup = try store.duplicate(renamed)
        XCTAssertEqual(dup.displayName, "b (1)")

        try store.delete(dup)
        // Docs folder + b.txt remain
        XCTAssertEqual(try store.contents(of: root).count, 2)
    }

    func testRenameToExistingThrows() throws {
        let store = DocumentFileStore(root: root)
        _ = try store.save(Data(), name: "taken.txt", in: root)
        let other = try store.save(Data(), name: "other.txt", in: root)
        XCTAssertThrowsError(try store.rename(other, to: "taken"))
    }

    func testRecursiveSearch() throws {
        let store = DocumentFileStore(root: root)
        let folder = try store.createFolder(named: "Sub", in: root)
        _ = try store.save(Data(), name: "report-2026.pdf", in: folder.url)
        _ = try store.save(Data(), name: "notes.txt", in: root)

        let hits = try store.search("report", in: root)
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.displayName, "report-2026")
    }

    @MainActor
    func testCutAndPasteMovesAcrossFolders() throws {
        let store = DocumentFileStore(root: root)
        let file = try store.save(Data(), name: "move-me.txt", in: root)
        let folder = try store.createFolder(named: "Dest", in: root)

        let clipboard = FileClipboard()
        let source = FilesModel(store: store, directory: root, clipboard: clipboard)
        source.cut([file])
        XCTAssertTrue(source.canPaste)

        let dest = FilesModel(store: store, directory: folder.url, clipboard: clipboard)
        dest.paste()
        XCTAssertEqual(dest.items.count, 1)
        XCTAssertEqual(try store.contents(of: folder.url).count, 1)
    }

    @MainActor
    func testSearchTextFilters() throws {
        let store = DocumentFileStore(root: root)
        _ = try store.save(Data(), name: "apple.txt", in: root)
        _ = try store.save(Data(), name: "banana.txt", in: root)
        let model = FilesModel(store: store, directory: root)
        model.searchText = "app"
        XCTAssertEqual(model.visibleItems.count, 1)
    }

    @MainActor
    func testFilesModelSelectionAndSort() {
        let store = DocumentFileStore(root: root)
        _ = try? store.createFolder(named: "Zed", in: root)
        _ = try? store.save(Data(), name: "apple.txt", in: root)

        let model = FilesModel(store: store, directory: root)
        model.sort = .name
        XCTAssertTrue(model.items.first?.isDirectory ?? false)  // folders first

        guard let file = model.items.first(where: { !$0.isDirectory }) else { return XCTFail() }
        model.setSelecting(true)
        model.toggle(file)
        XCTAssertEqual(model.selectedItems.count, 1)

        model.deleteSelected()
        XCTAssertFalse(model.isSelecting)
        XCTAssertNil(model.items.first(where: { !$0.isDirectory }))
    }
}
