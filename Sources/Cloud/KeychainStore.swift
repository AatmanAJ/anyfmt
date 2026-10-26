import Foundation
import Security
import AnyfmtCore

/// Where secrets live. The real one is the Keychain; tests may inject a
/// memory store for flows that don't test the Keychain itself.
protocol CloudSecretStore: Sendable {
    func read(account: String) throws -> Data?
    func write(_ data: Data, account: String) throws
    func delete(account: String) throws
}

enum KeychainError: Error, Equatable, CustomStringConvertible {
    case unexpectedStatus(OSStatus)
    var description: String {
        switch self {
        case .unexpectedStatus(let status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "?"
            return "Keychain error \(status): \(message)"
        }
    }
}

/// Generic-password items in the login keychain.
/// Service `"<bundle id>.cloud"`, one account per server (host[:port][/path]),
/// so a self-hosted server and the hosted one keep separate sign-ins.
struct KeychainStore: CloudSecretStore {
    let service: String

    init(service: String = CloudConfig.keychainService) {
        self.service = service
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    func read(account: String) throws -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        switch status {
        case errSecSuccess: return out as? Data
        case errSecItemNotFound: return nil
        default: throw KeychainError.unexpectedStatus(status)
        }
    }

    func write(_ data: Data, account: String) throws {
        let query = baseQuery(account: account)
        let update: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecSuccess { return }
        guard status == errSecItemNotFound else { throw KeychainError.unexpectedStatus(status) }
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrLabel as String] = "\(Brand.name) Cloud (\(account))"
        // Never synced through iCloud Keychain: tokens belong to this Mac.
        add[kSecAttrSynchronizable as String] = false
        let addStatus = SecItemAdd(add as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw KeychainError.unexpectedStatus(addStatus) }
    }

    func delete(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError.unexpectedStatus(status) }
    }

    /// Removes every item under this service (tests and "Reset" use it).
    func deleteAll() throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError.unexpectedStatus(status) }
    }

    /// Accounts stored under this service (for tests and diagnostics; never the secrets).
    func accounts() throws -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]
        var out: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess, let items = out as? [[String: Any]] else { throw KeychainError.unexpectedStatus(status) }
        return items.compactMap { $0[kSecAttrAccount as String] as? String }.sorted()
    }
}

/// Typed access to the tokens for a server.
struct CloudCredentialVault: Sendable {
    let store: any CloudSecretStore

    func load(for server: URL) -> CloudCredentials? {
        do {
            guard let data = try store.read(account: CloudServerAddress.accountKey(for: server)) else { return nil }
            return try JSONDecoder().decode(CloudCredentials.self, from: data)
        } catch {
            Log.cloud.error("couldn't read stored sign-in: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    func save(_ credentials: CloudCredentials, for server: URL) throws {
        let data = try JSONEncoder().encode(credentials)
        try store.write(data, account: CloudServerAddress.accountKey(for: server))
    }

    func remove(for server: URL) {
        do { try store.delete(account: CloudServerAddress.accountKey(for: server)) } catch {
            Log.cloud.error("couldn't delete stored sign-in: \(String(describing: error), privacy: .public)")
        }
    }
}
