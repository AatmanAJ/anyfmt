import Foundation
import HaloCore

/// Why `LicenceStore.activate(_:)` refused a key. `message` is for the person.
struct LicenceActivationError: Error, Equatable, Sendable, CustomStringConvertible {
    let verification: LicenceVerification
    var message: String { verification.message }
    var description: String { message }
}

/// The one licence key on this Mac, kept in the login Keychain.
///
/// The stored string is re-verified on every read, so a key that expires
/// (or whose signing key a later build stops trusting) stays stored but
/// contributes nothing. Nothing here touches the network.
final class LicenceStore: Sendable {
    static var keychainService: String { "\(Brand.bundleID).licence" }
    static let keychainAccount = "licence-key"

    private let secrets: any CloudSecretStore
    private let verifier: LicenceVerifier
    private let now: @Sendable () -> Date
    private let stored: CloudLocked<String?>
    private let observers = CloudLocked<[UUID: @Sendable (LicenceStore) -> Void]>([:])

    init(secrets: any CloudSecretStore = KeychainStore(service: LicenceStore.keychainService),
         verifier: LicenceVerifier = .shipped,
         now: @escaping @Sendable () -> Date = { Date() }) {
        self.secrets = secrets
        self.verifier = verifier
        self.now = now
        var initial: String?
        do {
            if let data = try secrets.read(account: Self.keychainAccount) { initial = String(decoding: data, as: UTF8.self) }
        } catch {
            Log.cloud.error("couldn't read stored licence: \(String(describing: error), privacy: .public)")
        }
        stored = CloudLocked(initial)
    }

    /// The stored key as the person pasted it (normalised), or nil.
    var storedKey: String? { stored.current }

    /// Verification of the stored key right now; nil when none is stored.
    var status: LicenceVerification? {
        storedKey.map { verifier.verify($0, now: now()) }
    }

    /// The stored licence whose signature checks out, even if it's out of date.
    var current: Licence? { status?.licence }

    /// The stored licence if it's valid right now.
    var active: Licence? {
        guard case .valid(let l) = status else { return nil }
        return l
    }

    /// What the stored licence can contribute to the cloud entitlements.
    /// Carries its own validity window; `CloudEntitlements.merging` checks it.
    var entitlements: LicenceEntitlements? {
        current.map { LicenceEntitlements($0, clockSkew: verifier.clockSkew) }
    }

    /// Verifies and stores `key`, replacing any stored licence.
    /// - Throws: `LicenceActivationError` (not valid now) or a Keychain error.
    @discardableResult
    func activate(_ key: String) throws -> Licence {
        let result = verifier.verify(key, now: now())
        guard case .valid(let licence) = result else { throw LicenceActivationError(verification: result) }
        // Store the canonical spelling so a later read never depends on how it was pasted.
        let parts = try LicenceKey.decode(key)
        let canonical = LicenceKey.encode(payload: parts.payload, signature: parts.signature)
        try secrets.write(Data(canonical.utf8), account: Self.keychainAccount)
        stored.withLock { $0 = canonical }
        Log.cloud.info("licence activated (\(licence.plan.rawValue, privacy: .public), kid \(licence.keyID, privacy: .public))")
        notify()
        return licence
    }

    /// Removes the stored licence from this Mac. (A server-side revoke, when
    /// signed in, belongs to the caller.)
    func deactivate() throws {
        try secrets.delete(account: Self.keychainAccount)
        let had = stored.withLock { old -> Bool in
            defer { old = nil }
            return old != nil
        }
        if had { notify() }
    }

    /// Called after every activate/deactivate that changed something.
    @discardableResult
    func observe(_ block: @escaping @Sendable (LicenceStore) -> Void) -> UUID {
        let id = UUID()
        observers.withLock { $0[id] = block }
        return id
    }

    func removeObserver(_ id: UUID) {
        observers.withLock { $0[id] = nil }
    }

    /// Keeps `state.snapshot.licence` in step with this store, starting now.
    /// Returns the observer id (pass it to `removeObserver` to stop).
    @discardableResult
    func connect(to state: CloudState) -> UUID {
        let push: @Sendable (LicenceStore) -> Void = { store in
            let value = store.entitlements
            state.update { $0.licence = value }
        }
        push(self)
        return observe(push)
    }

    private func notify() {
        for o in observers.current.values { o(self) }
    }
}
