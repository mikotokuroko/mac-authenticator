import Foundation
import Security
import AuthenticatorCore

struct KeychainVault {
    var service = "local.lam.mac-authenticator.accounts.v1"
    private var query: [String: Any] { [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: "accounts"] }
    func load() throws -> [OTPAccount] {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return [] }
        try check(status)
        guard let data = result as? Data else { throw OTPError.invalid("The saved accounts could not be read.") }
        let decoded = try JSONDecoder().decode([OTPAccount].self, from: data)
        // Revalidate persisted values before they reach the code generator.
        return try decoded.map { try OTPAccount(id: $0.id, name: $0.name, issuer: $0.issuer, secret: $0.secret, algorithm: $0.algorithm, digits: $0.digits, period: $0.period) }
    }
    func save(_ accounts: [OTPAccount]) throws {
        let data = try JSONEncoder().encode(accounts)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var request = query
            request[kSecValueData as String] = data
            request[kSecAttrLabel as String] = "Mac Authenticator accounts"
            // The login Keychain uses its native macOS ACL; iOS accessibility attributes do not apply.
            try check(SecItemAdd(request as CFDictionary, nil))
        } else { try check(status) }
    }
    func delete() throws {
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecItemNotFound { try check(status) }
    }
    private func check(_ status: OSStatus) throws {
        guard status == errSecSuccess else { throw OTPError.invalid("Keychain could not complete the request (\(status)). Your saved accounts have not been replaced.") }
    }
}
