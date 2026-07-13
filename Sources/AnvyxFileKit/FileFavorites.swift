//
//  FileFavorites.swift
//  FileManagerKit
//
//  Created by AnhPT on 13/07/2026.
//

import Foundation

/// Persistence backend for ``FileFavorites`` — stores the favorited file paths.
public protocol FavoritesStore: Sendable {
    func load() -> [String]
    func save(_ paths: [String])
}

/// `UserDefaults`-backed favorites persistence.
public struct UserDefaultsFavoritesStore: FavoritesStore {
    // UserDefaults is thread-safe but not marked Sendable.
    nonisolated(unsafe) private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "com.anvyx.filekit.favorites") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> [String] { defaults.stringArray(forKey: key) ?? [] }
    public func save(_ paths: [String]) { defaults.set(paths, forKey: key) }
}

/// An app-managed **favorites** set for files/folders — iOS has no Finder tags, so
/// favorites are tracked here and persisted through a ``FavoritesStore``. Observable,
/// so a star button / favorites section updates automatically.
@MainActor
@Observable
public final class FileFavorites {
    @ObservationIgnored private let store: FavoritesStore
    private var paths: Set<String>

    public init(store: FavoritesStore = UserDefaultsFavoritesStore()) {
        self.store = store
        self.paths = Set(store.load())
    }

    /// Favorited URLs (order not guaranteed).
    public var urls: [URL] { paths.map { URL(fileURLWithPath: $0) } }

    public var count: Int { paths.count }

    public func isFavorite(_ url: URL) -> Bool {
        paths.contains(url.standardizedFileURL.path)
    }

    public func add(_ url: URL) {
        guard paths.insert(url.standardizedFileURL.path).inserted else { return }
        persist()
    }

    public func remove(_ url: URL) {
        guard paths.remove(url.standardizedFileURL.path) != nil else { return }
        persist()
    }

    /// Flip favorite state; returns the new state.
    @discardableResult
    public func toggle(_ url: URL) -> Bool {
        let favorite = isFavorite(url)
        if favorite { remove(url) } else { add(url) }
        return !favorite
    }

    private func persist() {
        store.save(Array(paths))
    }
}
