import Foundation

public enum HostsBlocklistRenderer {
    public static let beginMarker = "# BEGIN STARISLAND FOCUS"
    public static let endMarker = "# END STARISLAND FOCUS"

    public static func normalizeDomains(_ domains: [String]) -> [String] {
        var collected = Set<String>()
        let allowedChars = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789.-")

        for raw in domains {
            var token = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !token.isEmpty else { continue }

            if token.contains("://"), let url = URL(string: token), let host = url.host?.lowercased() {
                token = host
            } else {
                if token.hasPrefix("https://") { token.removeFirst("https://".count) }
                if token.hasPrefix("http://") { token.removeFirst("http://".count) }
                if let slashIdx = token.firstIndex(where: { $0 == "/" || $0 == "?" || $0 == ":" || $0 == "#" }) {
                    token = String(token[..<slashIdx])
                }
            }

            token = token.trimmingCharacters(in: CharacterSet(charactersIn: "."))
            guard token.contains("."),
                  token != "localhost",
                  token.unicodeScalars.allSatisfy({ allowedChars.contains($0) }) else {
                continue
            }

            collected.insert(token)
            if token.hasPrefix("www.") {
                let bare = String(token.dropFirst(4))
                if bare.contains(".") {
                    collected.insert(bare)
                }
            } else if token.filter({ $0 == "." }).count == 1 {
                collected.insert("www.\(token)")
            }
        }

        return collected.sorted()
    }

    public static func applyBlockDomains(_ domains: [String], to hostsContent: String) -> String {
        let base = removeManagedBlock(from: hostsContent)
        let normalized = normalizeDomains(domains)
        guard !normalized.isEmpty else { return base }

        var blockLines: [String] = [
            beginMarker,
            "# 由星岛 (StarIsland) 专注模式自动维护，请勿手动修改此区块"
        ]
        for domain in normalized {
            blockLines.append("127.0.0.1 \(domain)")
            blockLines.append("::1 \(domain)")
        }
        blockLines.append(endMarker)
        let block = blockLines.joined(separator: "\n")

        if base.isEmpty {
            return block
        } else if base.hasSuffix("\n") {
            return base + "\n" + block + "\n"
        } else {
            return base + "\n" + block
        }
    }

    public static func removeManagedBlock(from hostsContent: String) -> String {
        var current = hostsContent
        while let beginRange = current.range(of: beginMarker),
              let endRange = current.range(of: endMarker, range: beginRange.upperBound..<current.endIndex) {
            var removeStart = beginRange.lowerBound
            var removeEnd = endRange.upperBound

            let hadLeadingNewline: Bool
            if removeStart > current.startIndex, current[current.index(before: removeStart)] == "\n" {
                removeStart = current.index(before: removeStart)
                hadLeadingNewline = true
            } else {
                hadLeadingNewline = false
            }

            if removeEnd < current.endIndex, current[removeEnd] == "\n" {
                if hadLeadingNewline || removeStart == current.startIndex {
                    removeEnd = current.index(after: removeEnd)
                }
            }

            current.removeSubrange(removeStart..<removeEnd)
        }
        return current
    }
}
