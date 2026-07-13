//
//  FileBookmarkTests.swift
//  FileManagerKit
//
//  Created by AnhPT on 13/07/2026.
//

import XCTest
@testable import AnvyxFileKit

final class FileBookmarkTests: XCTestCase {

    private func makeTempFile(_ contents: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("bookmark-\(UUID().uuidString).txt")
        try Data(contents.utf8).write(to: url)
        return url
    }

    func testRoundTripResolvesToSameFile() throws {
        let url = try makeTempFile("hello world")
        defer { try? FileManager.default.removeItem(at: url) }

        let data = try FileBookmark.create(for: url)
        let resolved = try FileBookmark.resolve(data)

        XCTAssertFalse(resolved.isStale)
        let readBack = try FileBookmark.withAccess(to: resolved.url) { try Data(contentsOf: $0) }
        XCTAssertEqual(String(decoding: readBack, as: UTF8.self), "hello world")
    }

    func testWithAccessRunsBodyForNonScopedURL() throws {
        let url = try makeTempFile("x")
        defer { try? FileManager.default.removeItem(at: url) }

        // A plain sandbox URL isn't security-scoped, but the body must still run.
        let exists = FileBookmark.withAccess(to: url) { FileManager.default.fileExists(atPath: $0.path) }
        XCTAssertTrue(exists)
    }

    func testResolveRefreshingReturnsNoRefreshWhenValid() throws {
        let url = try makeTempFile("data")
        defer { try? FileManager.default.removeItem(at: url) }

        let data = try FileBookmark.create(for: url)
        let (resolved, refreshed) = try FileBookmark.resolveRefreshing(data)

        XCTAssertFalse(resolved.isStale)
        XCTAssertNil(refreshed, "a valid bookmark needs no refresh")
    }

    func testResolveInvalidDataThrows() {
        XCTAssertThrowsError(try FileBookmark.resolve(Data("not a bookmark".utf8)))
    }
}

final class UbiquityContainerTests: XCTestCase {
    func testIsSignedInIsQueryableWithoutCrashing() {
        _ = UbiquityContainer.isSignedIn   // false on Simulator without iCloud — must not crash
    }

    func testURLLookupIsSafeWhenUnavailable() async {
        // No iCloud entitlement in the test host → nil, but must not crash/block main.
        let url = await UbiquityContainer.url()
        XCTAssertNil(url)
    }
}
