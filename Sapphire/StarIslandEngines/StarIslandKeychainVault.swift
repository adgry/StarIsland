//
//  StarIslandKeychainVault.swift
//  Sapphire
//

#if !SAPPHIRE_FULL_BUILD
import Foundation
import Security

enum StarIslandKeychainVault {
    private static let service = "com.adgry.starisland.vault"
    private static let lock = NSLock()
    private static var memoryFallback: [String: String] = [:]

    static func string(forAccount account: String, legacyDefaultsKey: String? = nil) -> String {
        if let legacyDefaultsKey,
           let legacy = UserDefaults.standard.string(forKey: legacyDefaultsKey),
           !legacy.isEmpty {
            UserDefaults.standard.removeObject(forKey: legacyDefaultsKey)
            setString(legacy, forAccount: account)
            return legacy
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess,
           let data = item as? Data,
           let str = String(data: data, encoding: .utf8) {
            return str
        }

        lock.lock()
        defer { lock.unlock() }
        return memoryFallback[account] ?? ""
    }

    static func setString(_ value: String, forAccount account: String, legacyDefaultsKey: String? = nil) {
        if let legacyDefaultsKey {
            UserDefaults.standard.removeObject(forKey: legacyDefaultsKey)
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        lock.lock()
        if trimmed.isEmpty {
            memoryFallback.removeValue(forKey: account)
        } else {
            memoryFallback[account] = trimmed
        }
        lock.unlock()

        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        if trimmed.isEmpty {
            SecItemDelete(baseQuery as CFDictionary)
            return
        }

        let data = Data(trimmed.utf8)
        let updateAttrs: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, updateAttrs as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addQuery = baseQuery
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }
}
#endif
