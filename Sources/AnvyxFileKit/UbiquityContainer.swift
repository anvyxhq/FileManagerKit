//
//  UbiquityContainer.swift
//  FileManagerKit
//
//  Created by AnhPT on 13/07/2026.
//

import Foundation

/// Access to the app's **iCloud Drive (ubiquity) container** — the folder whose
/// contents sync across the user's devices. Requires the iCloud Documents
/// capability + an `iCloud.<bundleID>` container entitlement.
///
/// ```swift
/// guard UbiquityContainer.isSignedIn else { /* fall back to local */ }
/// let documents = await UbiquityContainer.documentsURL()
/// ```
public enum UbiquityContainer {

    /// `true` when the user is signed into iCloud (a cheap, non-blocking check).
    /// It does not guarantee the container is provisioned — resolve a URL for that.
    public static var isSignedIn: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    /// The ubiquity container URL for `identifier` (or the app's default when
    /// `nil`). Runs off the main actor because `FileManager` performs a **blocking**
    /// lookup here. Returns `nil` when iCloud is unavailable / not entitled.
    public static func url(for identifier: String? = nil) async -> URL? {
        await Task.detached(priority: .utility) {
            FileManager.default.url(forUbiquityContainerIdentifier: identifier)
        }.value
    }

    /// The `Documents` subfolder of the container — where user-visible iCloud
    /// Drive files live.
    public static func documentsURL(for identifier: String? = nil) async -> URL? {
        await url(for: identifier)?.appendingPathComponent("Documents", isDirectory: true)
    }
}
