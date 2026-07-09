//
//  FileItem.swift
//  FileManagerKit
//
//  Created by AnhPT on 04/07/2026.
//

import Foundation

/// A file or folder on disk, with the metadata a "My Files" screen needs.
public struct FileItem: Identifiable, Hashable, Sendable {
    public let url: URL
    public let isDirectory: Bool
    public let size: Int64
    public let createdAt: Date
    public let modifiedAt: Date

    public var id: URL { url }

    /// Full name including extension (e.g. "invoice.pdf").
    public var name: String { url.lastPathComponent }

    /// Name for display — extension stripped for files, kept for folders.
    public var displayName: String {
        isDirectory ? name : url.deletingPathExtension().lastPathComponent
    }

    public var kind: FileKind {
        isDirectory ? .folder : FileKind(extension: url.pathExtension)
    }

    public init(url: URL) {
        self.url = url
        let values = try? url.resourceValues(forKeys: [
            .isDirectoryKey, .fileSizeKey, .creationDateKey, .contentModificationDateKey,
        ])
        self.isDirectory = values?.isDirectory ?? false
        self.size = Int64(values?.fileSize ?? 0)
        self.createdAt = values?.creationDate ?? .distantPast
        self.modifiedAt = values?.contentModificationDate ?? .distantPast
    }

    /// Human-readable size, e.g. "1.2 MB".
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

/// Coarse file classification (for icons, filtering, multi-select rules).
public enum FileKind: String, Sendable, CaseIterable {
    case folder, pdf, image, text, other

    public init(extension ext: String) {
        switch ext.lowercased() {
        case "pdf":                                   self = .pdf
        case "png", "jpg", "jpeg", "heic", "heif", "gif", "webp", "tiff": self = .image
        case "txt", "md", "rtf":                      self = .text
        default:                                       self = .other
        }
    }

    /// An SF Symbol name suitable for this kind.
    public var systemImageName: String {
        switch self {
        case .folder: "folder.fill"
        case .pdf:    "doc.richtext"
        case .image:  "photo"
        case .text:   "doc.text"
        case .other:  "doc"
        }
    }
}
