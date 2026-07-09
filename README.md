# FileManagerKit

A small base for a "My Files" screen: list, sort, multi-select, and file
operations (create folder, save, rename, move, copy, duplicate, delete) with
Files-app-style collision naming — behind a testable port.

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/iOS-17%2B-blue.svg)](https://developer.apple.com/ios/)
[![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)

## Features

- **`FileItem`** — file/folder metadata (kind, size, dates, display name, SF Symbol).
- **`FileStore`** — the operations port; **`DocumentFileStore`** implements it over
  `FileManager` with auto-increment naming (`"note (1)"`) on collision.
- **`FilesModel`** — an `@Observable` view model: sorting (folders first), multi-select,
  **search** (`searchText` / recursive `search(_:)`), navigation into folders, and all
  operations forwarded to the port.
- **`FileClipboard`** — shared **cut / copy / paste** across folders.
- **`FileThumbnail`** — QuickLook thumbnails for any file type.

> Merge is format-specific (e.g. combining PDFs) — feed `selectedItems` to
> [PDFKitWrapper](https://github.com/theanvyx/PDFKitWrapper)'s `PDFDocument.merged`.

## Installation

```swift
.package(url: "https://github.com/theanvyx/FileManagerKit.git", branch: "main")
```

## Usage

```swift
import AnvyxFileKit

@State private var files = FilesModel(store: DocumentFileStore())

// List
ForEach(files.items) { item in
    Label(item.displayName, systemImage: item.kind.systemImageName)
}

// Operations
files.createFolder(named: "Invoices")
files.rename(item, to: "March")
files.duplicate(item)
files.deleteSelected()

// Search
files.searchText = "invoice"          // filters files.visibleItems
let hits = files.search("2026")       // recursive

// Cut / copy / paste across folders (share one FileClipboard)
let clipboard = FileClipboard()
let a = FilesModel(store: store, directory: folderA, clipboard: clipboard)
let b = FilesModel(store: store, directory: folderB, clipboard: clipboard)
a.cut(a.selectedItems); b.paste()

// Thumbnail
let image = await FileThumbnail.generate(for: item.url, size: CGSize(width: 80, height: 100))
```

Inject a temp-directory `DocumentFileStore(root:)` in tests — no real Documents folder needed.

## Requirements

- iOS 17+ · Swift 5.9+

## License

MIT
