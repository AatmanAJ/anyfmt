import Foundation
import AnyfmtCore

/// The app was called Halo (bundle id `dev.aiwithaj.halo`) before it became anyfmt.
/// On the first launch under the new id, carry over what the old one stored on this Mac:
/// settings, keychain items (cloud sign-in, licence) and the Application Support folder.
/// Runs once; never deletes anything from the old locations.
enum LegacyBrandMigration {
    static let legacyBundleID = "dev.aiwithaj.halo"
    static let legacyName = "Halo"
    private static let doneKey = "migration.legacyBrand.done"

    static func runIfNeeded(defaults: UserDefaults = .standard, fileManager: FileManager = .default) {
        guard !defaults.bool(forKey: doneKey) else { return }
        defer { defaults.set(true, forKey: doneKey) }
        migrateDefaults(into: defaults)
        migrateKeychain()
        migrateSupportFolder(fileManager: fileManager)
    }

    /// Copies old preferences for keys the new domain doesn't have yet.
    static func migrateDefaults(into defaults: UserDefaults) {
        guard let old = UserDefaults(suiteName: legacyBundleID)?.persistentDomain(forName: legacyBundleID), !old.isEmpty else { return }
        var copied = 0
        for (key, value) in old where defaults.object(forKey: key) == nil {
            defaults.set(value, forKey: key)
            copied += 1
        }
        Log.app.info("migrated \(copied, privacy: .public) settings from \(legacyBundleID, privacy: .public)")
    }

    /// Copies `<old id>.cloud` and `<old id>.licence` items to the new services.
    static func migrateKeychain() {
        let pairs = [
            (KeychainStore(service: "\(legacyBundleID).cloud"), KeychainStore(service: CloudConfig.keychainService)),
            (KeychainStore(service: "\(legacyBundleID).licence"), KeychainStore(service: LicenceStore.keychainService)),
        ]
        for (from, to) in pairs {
            do {
                for account in try from.accounts() {
                    guard try to.read(account: account) == nil, let data = try from.read(account: account) else { continue }
                    try to.write(data, account: account)
                }
            } catch {
                Log.app.error("keychain migration from \(from.service, privacy: .public) failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    /// Copies `Application Support/Halo` to `Application Support/anyfmt` when the new folder doesn't exist yet.
    static func migrateSupportFolder(fileManager: FileManager) {
        guard let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let old = base.appendingPathComponent(legacyName, isDirectory: true)
        let new = base.appendingPathComponent(Brand.name, isDirectory: true)
        guard fileManager.fileExists(atPath: old.path), !fileManager.fileExists(atPath: new.path) else { return }
        do {
            try fileManager.copyItem(at: old, to: new)
        } catch {
            Log.app.error("support folder migration failed: \(String(describing: error), privacy: .public)")
        }
    }
}
