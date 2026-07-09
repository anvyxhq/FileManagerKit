//
//  FileClipboard.swift
//  FileManagerKit
//
//  Created by AnhPT on 04/07/2026.
//

import Foundation
import Observation

public enum FileClipboardAction: Sendable { case cut, copy }

/// A shared cut/copy buffer so items copied in one folder can be pasted in
/// another. Inject the same instance into every `FilesModel`.
@MainActor
@Observable
public final class FileClipboard {
    public private(set) var action: FileClipboardAction?
    public private(set) var items: [FileItem] = []

    public nonisolated init() {}

    public var isEmpty: Bool { action == nil || items.isEmpty }

    public func set(_ action: FileClipboardAction, _ items: [FileItem]) {
        self.action = action
        self.items = items
    }

    public func clear() {
        action = nil
        items = []
    }
}
