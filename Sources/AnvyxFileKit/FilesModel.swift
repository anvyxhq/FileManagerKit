//
//  FilesModel.swift
//  FileManagerKit
//
//  Created by AnhPT on 04/07/2026.
//

import Foundation
import Observation

/// The view model for a "My Files" screen. Lists a directory, sorts, supports
/// multi-select, and forwards operations to the injected `FileStore` port.
@MainActor
@Observable
public final class FilesModel {
    public enum Sort: String, CaseIterable, Sendable {
        case name, dateNewest, dateOldest, sizeLargest
    }

    public private(set) var items: [FileItem] = []
    public let directory: URL
    public var sort: Sort = .dateNewest { didSet { items = sorted(items) } }
    /// In-folder name filter applied to `visibleItems`.
    public var searchText: String = ""
    public private(set) var isSelecting = false
    public private(set) var selection: Set<URL> = []
    public private(set) var errorMessage: String?

    /// Items after applying `searchText` (what the list should render).
    public var visibleItems: [FileItem] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return items }
        return items.filter { $0.displayName.localizedCaseInsensitiveContains(query) }
    }

    @ObservationIgnored private let store: any FileStore
    @ObservationIgnored private let clipboard: FileClipboard

    public init(store: any FileStore, directory: URL? = nil, clipboard: FileClipboard = FileClipboard()) {
        self.store = store
        self.directory = directory ?? store.root
        self.clipboard = clipboard
        reload()
    }

    // MARK: - Loading / navigation

    public func reload() {
        do {
            items = sorted(try store.contents(of: directory))
        } catch {
            errorMessage = error.localizedDescription
            items = []
        }
    }

    /// A child model for opening a folder (nil for non-folders).
    public func open(_ item: FileItem) -> FilesModel? {
        guard item.isDirectory else { return nil }
        return FilesModel(store: store, directory: item.url)
    }

    // MARK: - Operations

    public func createFolder(named name: String) {
        perform { _ = try store.createFolder(named: name, in: directory) }
    }

    public func rename(_ item: FileItem, to newName: String) {
        perform { _ = try store.rename(item, to: newName) }
    }

    public func duplicate(_ item: FileItem) {
        perform { _ = try store.duplicate(item) }
    }

    public func copy(_ targets: [FileItem], to destination: URL) {
        perform { for item in targets { _ = try store.copy(item, to: destination) } }
    }

    /// Recursive name search from this directory (does not mutate `items`).
    public func search(_ query: String) -> [FileItem] {
        (try? store.search(query, in: directory)) ?? []
    }

    // MARK: - Clipboard (cut / copy / paste)

    public func cut(_ targets: [FileItem]) {
        clipboard.set(.cut, targets)
        setSelecting(false)
    }

    public func copyToClipboard(_ targets: [FileItem]) {
        clipboard.set(.copy, targets)
        setSelecting(false)
    }

    public var canPaste: Bool { !clipboard.isEmpty }

    /// Paste the shared clipboard into the current directory — moves (cut) or copies.
    public func paste() {
        guard let action = clipboard.action, !clipboard.items.isEmpty else { return }
        perform {
            for item in clipboard.items {
                switch action {
                case .cut:  _ = try store.move(item, to: directory)
                case .copy: _ = try store.copy(item, to: directory)
                }
            }
        }
        clipboard.clear()
    }

    public func delete(_ targets: [FileItem]) {
        perform { for item in targets { try store.delete(item) } }
    }

    public func move(_ targets: [FileItem], to destination: URL) {
        perform { for item in targets { _ = try store.move(item, to: destination) } }
    }

    // MARK: - Selection

    public func setSelecting(_ on: Bool) {
        isSelecting = on
        if !on { selection.removeAll() }
    }

    public func toggle(_ item: FileItem) {
        if selection.contains(item.url) { selection.remove(item.url) }
        else { selection.insert(item.url) }
    }

    public var selectedItems: [FileItem] {
        items.filter { selection.contains($0.url) }
    }

    public func deleteSelected() {
        delete(selectedItems)
        setSelecting(false)
    }

    // MARK: - Private

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func sorted(_ list: [FileItem]) -> [FileItem] {
        list.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }  // folders first
            switch sort {
            case .name:        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            case .dateNewest:  return lhs.modifiedAt > rhs.modifiedAt
            case .dateOldest:  return lhs.modifiedAt < rhs.modifiedAt
            case .sizeLargest: return lhs.size > rhs.size
            }
        }
    }
}
