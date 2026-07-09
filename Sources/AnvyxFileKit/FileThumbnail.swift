//
//  FileThumbnail.swift
//  FileManagerKit
//
//  Created by AnhPT on 04/07/2026.
//

#if canImport(UIKit)
import UIKit
import QuickLookThumbnailing

/// Generates file thumbnails via QuickLook — works for PDFs, images, and most
/// document types, so a file grid doesn't need per-type rendering.
public enum FileThumbnail {
    @MainActor
    public static func generate(for url: URL, size: CGSize, scale: CGFloat = 2) async -> UIImage? {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: scale,
            representationTypes: .thumbnail
        )
        let generation = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
        return generation?.uiImage
    }
}
#endif
