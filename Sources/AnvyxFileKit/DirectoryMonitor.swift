//
//  DirectoryMonitor.swift
//  FileManagerKit
//
//  Created by AnhPT on 13/07/2026.
//

import Foundation

/// Observes a directory for changes made **outside** the app (iCloud sync, a share
/// extension, the Files app) and reports them as an `AsyncStream`, so a file list
/// can refresh itself. Backed by a kernel `DispatchSource` file-system watch —
/// lighter than `NSFilePresenter` when you only need "something changed here".
///
/// ```swift
/// for await _ in DirectoryMonitor.changes(of: folderURL) {
///     await reload()
/// }
/// ```
public enum DirectoryMonitor {

    /// Yields once for each change to `url`'s contents (write / rename / delete).
    /// The watch stops when the consumer stops iterating.
    public static func changes(of url: URL) -> AsyncStream<Void> {
        AsyncStream { continuation in
            let descriptor = open(url.path, O_EVTONLY)
            guard descriptor >= 0 else {
                continuation.finish()
                return
            }

            let queue = DispatchQueue(label: "com.anvyx.filekit.directory-monitor")
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: descriptor,
                eventMask: [.write, .rename, .delete],
                queue: queue)

            source.setEventHandler { continuation.yield(()) }
            source.setCancelHandler { close(descriptor) }
            continuation.onTermination = { _ in source.cancel() }
            source.resume()
        }
    }
}
