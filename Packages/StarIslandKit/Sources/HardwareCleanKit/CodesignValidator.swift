import Darwin
import Foundation
import Security
import IslandCore

/// 供主程序与特权守护进程共用的严格代码签名与父级应用包归属校验器
public enum CodesignValidator {

    /// 提取可执行文件或子组件所在的最近父级 `.app` 应用包路径
    public static func enclosingAppBundleURL(for url: URL) -> URL? {
        let normalized = normalizeURL(url)
        if normalized.pathExtension.lowercased() == "app" {
            return normalized
        }

        var cursor = normalized.deletingLastPathComponent()
        while cursor.path != "/" && !cursor.path.isEmpty {
            if cursor.pathExtension.lowercased() == "app" {
                let contentsPrefix = cursor.path + "/Contents/"
                if normalized.path.hasPrefix(contentsPrefix) {
                    return cursor
                }
                return nil
            }
            let parent = cursor.deletingLastPathComponent()
            if parent.path == cursor.path {
                break
            }
            cursor = parent
        }
        return nil
    }

    /// 严格校验客户端 `.app` 包是否正是特权 Helper 可执行文件所属的同一个父级 `.app` 包
    public static func isParentAppMatch(helperExecutableURL: URL, clientBundleURL: URL) -> Bool {
        let normalizedClient = normalizeURL(clientBundleURL)
        guard normalizedClient.pathExtension.lowercased() == "app" else {
            return false
        }

        let normalizedHelper = normalizeURL(helperExecutableURL)
        guard let helperParentApp = enclosingAppBundleURL(for: normalizedHelper) else {
            return false
        }

        guard helperParentApp.path == normalizedClient.path else {
            return false
        }

        return normalizedHelper.path.hasPrefix(normalizedClient.path + "/Contents/")
    }

    /// 基于 XPC 客户端 `audit_token_t` 执行运行时与静态代码签名完整性校验（兼容 Developer ID 与本地 Ad-hoc 构建，支持 root 权限下运行）
    public static func validateClient(auditToken: audit_token_t) -> Bool {
        validateClient(auditToken: auditToken, helperExecutableURL: nil)
    }

    /// 带可选自定义 Helper 路径的代码签名校验入口
    public static func validateClient(auditToken: audit_token_t, helperExecutableURL: URL?) -> Bool {
        var mutableToken = auditToken
        let tokenData = Data(bytes: &mutableToken, count: MemoryLayout<audit_token_t>.size)
        let attributes: [CFString: Any] = [
            kSecGuestAttributeAudit: tokenData
        ]

        var guestCodeRef: SecCode?
        let guestStatus = SecCodeCopyGuestWithAttributes(
            nil,
            attributes as CFDictionary,
            SecCSFlags(),
            &guestCodeRef
        )
        guard guestStatus == errSecSuccess, let guestCode = guestCodeRef else {
            return false
        }

        // 校验客户端进程运行时代码签名有效且未被篡改
        guard SecCodeCheckValidity(guestCode, SecCSFlags(), nil) == errSecSuccess else {
            return false
        }

        var staticCodeRef: SecStaticCode?
        guard SecCodeCopyStaticCode(guestCode, SecCSFlags(), &staticCodeRef) == errSecSuccess,
              let clientStaticCode = staticCodeRef else {
            return false
        }

        guard SecStaticCodeCheckValidity(clientStaticCode, SecCSFlags(), nil) == errSecSuccess else {
            return false
        }

        guard let clientInfo = signingInformation(for: clientStaticCode) else {
            return false
        }

        // 1. 校验主程序 Bundle Identifier
        guard let clientIdentifier = clientInfo[kSecCodeInfoIdentifier as String] as? String,
              clientIdentifier == StarIslandHelperConstants.appBundleIdentifier else {
            return false
        }

        // 2. 提取客户端所在 .app 包路径并与 Helper 所属父级 .app 比对
        var clientMainURLRef: CFURL?
        guard SecCodeCopyPath(clientStaticCode, SecCSFlags(), &clientMainURLRef) == errSecSuccess,
              let clientPathURL = clientMainURLRef as URL?,
              let clientAppURL = enclosingAppBundleURL(for: clientPathURL) else {
            return false
        }

        guard let resolvedHelperURL = helperExecutableURL ?? currentExecutableURL() else {
            return false
        }

        guard isParentAppMatch(helperExecutableURL: resolvedHelperURL, clientBundleURL: clientAppURL) else {
            return false
        }

        // 3. 若 Helper 自身包含 Developer ID TeamIdentifier，则要求客户端具备完全相同的 TeamIdentifier
        if let selfTeamID = teamIdentifier(forExecutableAt: resolvedHelperURL), !selfTeamID.isEmpty {
            let clientTeamID = clientInfo[kSecCodeInfoTeamIdentifier as String] as? String
            guard clientTeamID == selfTeamID else {
                return false
            }
        }

        return true
    }

    /// 读取当前进程可执行文件的开发者团队标识符（Ad-hoc 签名时返回 nil）
    public static func currentExecutableTeamIdentifier() -> String? {
        guard let url = currentExecutableURL() else { return nil }
        return teamIdentifier(forExecutableAt: url)
    }

    // MARK: - 私有辅助方法

    private static func normalizeURL(_ url: URL) -> URL {
        let standardized = url.standardizedFileURL
        if FileManager.default.fileExists(atPath: standardized.path) {
            return standardized.resolvingSymlinksInPath().standardizedFileURL
        }
        var cleanedPath = standardized.path
        while cleanedPath.count > 1 && cleanedPath.hasSuffix("/") {
            cleanedPath.removeLast()
        }
        return URL(fileURLWithPath: cleanedPath)
    }

    private static func currentExecutableURL() -> URL? {
        var size: UInt32 = 0
        _ = _NSGetExecutablePath(nil, &size)
        guard size > 0 else { return Bundle.main.executableURL }

        var buffer = [CChar](repeating: 0, count: Int(size))
        guard _NSGetExecutablePath(&buffer, &size) == 0 else {
            return Bundle.main.executableURL
        }
        let path = String(cString: buffer)
        return URL(fileURLWithPath: path)
    }

    private static func signingInformation(for staticCode: SecStaticCode) -> [String: Any]? {
        var infoRef: CFDictionary?
        let flags = SecCSFlags(rawValue: UInt32(kSecCSSigningInformation))
        guard SecCodeCopySigningInformation(staticCode, flags, &infoRef) == errSecSuccess,
              let dict = infoRef as? [String: Any] else {
            return nil
        }
        return dict
    }

    private static func teamIdentifier(forExecutableAt url: URL) -> String? {
        var staticCodeRef: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, SecCSFlags(), &staticCodeRef) == errSecSuccess,
              let staticCode = staticCodeRef,
              let info = signingInformation(for: staticCode) else {
            return nil
        }
        return info[kSecCodeInfoTeamIdentifier as String] as? String
    }
}
