import Foundation

public enum URLCleaner {
    public static let defaultBlockedExactKeys: Set<String> = [
        "fbclid", "gclid", "dclid", "msclkid", "twclid", "ttclid", "yclid", "wbraid", "gbraid",
        "spm", "spm_id_from", "vd_source", "from_spmid", "from", "isappinstalled",
        "share_source", "share_medium", "share_plat", "share_session_id", "share_tag", "unique_k",
        "igshid", "igsh", "mc_cid", "mc_eid", "_hsenc", "_hsmi", "mkt_tok",
        "vero_id", "oly_enc_id", "oly_anon_id", "rb_clickid", "s_kwcid", "wickedid"
    ]

    public static let defaultBlockedPrefixes: [String] = [
        "utm_", "hsa_", "mtm_", "pk_", "stm_"
    ]

    /// 清洗链接中的追踪参数；若输入不是 HTTP(S) 链接或不含任何需剥离的追踪参数，则返回 nil。
    public static func clean(_ raw: String, customBlockedKeys: Set<String> = []) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.contains(where: \.isWhitespace),
              var components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              components.host != nil,
              let items = components.queryItems,
              !items.isEmpty else {
            return nil
        }

        let normalizedCustom = Set(
            customBlockedKeys
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
        )

        var removedAny = false
        var keptItems: [URLQueryItem] = []
        keptItems.reserveCapacity(items.count)

        for item in items {
            let lowerName = item.name.lowercased()
            if isTrackingParameter(lowerName, customKeys: normalizedCustom) {
                removedAny = true
            } else {
                keptItems.append(item)
            }
        }

        guard removedAny else {
            return nil
        }

        components.queryItems = keptItems.isEmpty ? nil : keptItems
        guard let result = components.string, result != trimmed else {
            return nil
        }
        return result
    }

    public static func cleanOrOriginal(_ raw: String, customBlockedKeys: Set<String> = []) -> String {
        clean(raw, customBlockedKeys: customBlockedKeys) ?? raw
    }

    public static func isTrackingParameter(_ lowercasedKey: String, customKeys: Set<String> = []) -> Bool {
        if defaultBlockedExactKeys.contains(lowercasedKey) || customKeys.contains(lowercasedKey) {
            return true
        }
        for prefix in defaultBlockedPrefixes where lowercasedKey.hasPrefix(prefix) {
            return true
        }
        for custom in customKeys where custom.hasSuffix("*") {
            let stem = String(custom.dropLast())
            if !stem.isEmpty && lowercasedKey.hasPrefix(stem) {
                return true
            }
        }
        return false
    }
}
