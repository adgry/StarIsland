import Foundation
import Security

public enum KeychainVaultError: LocalizedError, Equatable, Sendable {
    case unexpectedStatus(OSStatus)
    case invalidDataEncoding

    public var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            if let msg = SecCopyErrorMessageString(status, nil) as String? {
                return "系统钥匙串访问失败（\(status)）：\(msg)"
            }
            return "系统钥匙串访问失败（错误码：\(status)）"
        case .invalidDataEncoding:
            return "钥匙串中的密钥数据编码无效"
        }
    }
}

/// 基于 macOS Security.framework 的安全凭据保险箱，绝不明文落盘 API Key
public struct KeychainVault: Sendable {
    public static let serviceName = "com.adgry.starisland.ai-keys"
    public static let shared = KeychainVault()

    public enum Account: String, CaseIterable, Sendable {
        case gemini = "gemini_api_key"
        case openAICompatible = "openai_compatible_api_key"
    }

    public let service: String

    public init(service: String = KeychainVault.serviceName) {
        self.service = service
    }

    public func saveSecret(_ secret: String, for account: String) throws {
        let trimmed = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            try deleteSecret(for: account)
            return
        }

        let secretData = Data(trimmed.utf8)
        let baseQuery = makeBaseQuery(for: account)

        let existingStatus = SecItemCopyMatching(baseQuery as CFDictionary, nil)
        switch existingStatus {
        case errSecSuccess:
            let attributesToUpdate: [String: Any] = [
                kSecValueData as String: secretData
            ]
            let updateStatus = SecItemUpdate(
                baseQuery as CFDictionary,
                attributesToUpdate as CFDictionary
            )
            guard updateStatus == errSecSuccess else {
                throw KeychainVaultError.unexpectedStatus(updateStatus)
            }

        case errSecItemNotFound:
            var addQuery = baseQuery
            addQuery[kSecValueData as String] = secretData
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainVaultError.unexpectedStatus(addStatus)
            }

        default:
            throw KeychainVaultError.unexpectedStatus(existingStatus)
        }
    }

    public func readSecret(for account: String) throws -> String? {
        var query = makeBaseQuery(for: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data,
                  let decoded = String(data: data, encoding: .utf8) else {
                throw KeychainVaultError.invalidDataEncoding
            }
            return decoded
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainVaultError.unexpectedStatus(status)
        }
    }

    public func deleteSecret(for account: String) throws {
        let query = makeBaseQuery(for: account)
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainVaultError.unexpectedStatus(status)
        }
    }

    // MARK: - AIProviderKind 便捷方法

    public func saveAPIKey(_ apiKey: String, for provider: AIProviderKind) throws {
        guard let account = Self.account(for: provider) else { return }
        try saveSecret(apiKey, for: account.rawValue)
    }

    public func readAPIKey(for provider: AIProviderKind) -> String? {
        guard let account = Self.account(for: provider) else { return nil }
        return (try? readSecret(for: account.rawValue))?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func deleteAPIKey(for provider: AIProviderKind) throws {
        guard let account = Self.account(for: provider) else { return }
        try deleteSecret(for: account.rawValue)
    }

    public func hasAPIKey(for provider: AIProviderKind) -> Bool {
        guard provider.requiresAPIKey else { return true }
        guard let key = readAPIKey(for: provider) else { return false }
        return !key.isEmpty
    }

    public static func account(for provider: AIProviderKind) -> Account? {
        switch provider {
        case .gemini:
            return .gemini
        case .openAICompatible:
            return .openAICompatible
        case .ollama:
            return nil
        }
    }

    private func makeBaseQuery(for account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
