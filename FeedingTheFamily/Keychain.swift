import Foundation
import Security

/// Tiny generic-password wrapper for the Anthropic API key. Replaces the old
/// "store the key in plaintext JSON" approach so a stolen device backup or
/// extracted Application Support directory won't leak the key.
enum Keychain {
    private static let service = "britt.FeedingTheFamily"
    private static let account = "anthropic-api-key"

    static func setApiKey(_ key: String) {
        let trimmed = key
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

        if trimmed.isEmpty {
            deleteApiKey()
            return
        }
        guard let data = trimmed.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        // Replace any existing entry.
        SecItemDelete(query as CFDictionary)

        var add = query
        add[kSecValueData as String] = data
        // Available after first unlock so it works during background save.
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(add as CFDictionary, nil)
        if status != errSecSuccess {
            print("Keychain.setApiKey failed:", status)
        }
    }

    static func getApiKey() -> String {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8)
        else { return "" }
        return key
    }

    static func deleteApiKey() {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
