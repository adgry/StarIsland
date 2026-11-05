import Foundation

/// 已安装应用元数据模型
public struct InstalledAppInfo: Identifiable, Equatable, Sendable {
    public var id: String { appURL.standardizedFileURL.path }
    public let name: String
    public let bundleID: String
    public let appURL: URL
    public let bundleSizeBytes: Int64
    public let lastUsedDate: Date?

    public init(
        name: String,
        bundleID: String,
        appURL: URL,
        bundleSizeBytes: Int64,
        lastUsedDate: Date? = nil
    ) {
        self.name = name
        self.bundleID = bundleID
        self.appURL = appURL
        self.bundleSizeBytes = bundleSizeBytes
        self.lastUsedDate = lastUsedDate
    }
}

/// 应用关联残留文件条目
public struct AppResidueItem: Identifiable, Equatable, Sendable {
    public var id: String { url.standardizedFileURL.path }
    public let url: URL
    public let category: String
    public let sizeBytes: Int64
    public var isSelected: Bool

    public init(url: URL, category: String, sizeBytes: Int64, isSelected: Bool = true) {
        self.url = url
        self.category = category
        self.sizeBytes = sizeBytes
        self.isSelected = isSelected
    }
}

/// 废纸篓清理结果报告
public struct AppTrashReport: Equatable, Sendable {
    public let trashedURLs: [URL]
    public let failedURLs: [URL]
    public let reclaimedBytes: Int64

    public init(trashedURLs: [URL], failedURLs: [URL], reclaimedBytes: Int64) {
        self.trashedURLs = trashedURLs
        self.failedURLs = failedURLs
        self.reclaimedBytes = reclaimedBytes
    }
}

/// 应用深度卸载与残留文件精准扫描服务
public enum AppCleanerService {

    /// 标准扫描的 `~/Library` 7 大残留子目录
    public static let defaultLibrarySubdirectories: [String] = [
        "Application Support",
        "Caches",
        "Preferences",
        "Saved Application State",
        "Containers",
        "Group Containers",
        "LaunchAgents",
    ]

    /// 生成当前用户的默认 7 大 `~/Library` 搜索根目录
    public static func defaultSearchRoots(
        homeDirectory: URL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
    ) -> [URL] {
        let libraryURL = homeDirectory.appendingPathComponent("Library", isDirectory: true)
        return defaultLibrarySubdirectories.map {
            libraryURL.appendingPathComponent($0, isDirectory: true)
        }
    }

    /// 扫描 `/Applications` 下的已安装 `.app` 应用列表与体积
    public static func scanInstalledApps(
        in directories: [URL] = [URL(fileURLWithPath: "/Applications", isDirectory: true)]
    ) -> [InstalledAppInfo] {
        let fm = FileManager.default
        var results: [InstalledAppInfo] = []
        var seenPaths = Set<String>()

        for dir in directories {
            guard let children = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for itemURL in children where itemURL.pathExtension.lowercased() == "app" {
                let canonical = itemURL.standardizedFileURL.path
                guard seenPaths.insert(canonical).inserted else { continue }

                let bundle = Bundle(url: itemURL)
                let bid = bundle?.bundleIdentifier ?? ""
                let displayName = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                    ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
                    ?? itemURL.deletingPathExtension().lastPathComponent
                let size = calculateSizeBytes(at: itemURL)
                let modDate = (try? itemURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate

                results.append(
                    InstalledAppInfo(
                        name: displayName,
                        bundleID: bid,
                        appURL: itemURL,
                        bundleSizeBytes: size,
                        lastUsedDate: modDate
                    )
                )
            }
        }

        return results.sorted { lhs, rhs in
            if lhs.bundleSizeBytes != rhs.bundleSizeBytes {
                return lhs.bundleSizeBytes > rhs.bundleSizeBytes
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    /// 在给定搜索根目录中精准定位匹配 `bundleID` 或 `appName` 的应用残留（严格边界匹配，绝不误伤前缀相似应用）
    public static func findResidueURLs(
        bundleID: String,
        appName: String,
        searchRoots: [URL]
    ) -> [AppResidueItem] {
        let normalizedBundleID = bundleID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanedAppName = sanitizeAppName(appName)

        guard !normalizedBundleID.isEmpty || !cleanedAppName.isEmpty else {
            return []
        }

        let fm = FileManager.default
        let expandedRoots = expandLibraryRootsIfNeeded(searchRoots)
        var foundItems: [AppResidueItem] = []
        var visitedPaths = Set<String>()

        for root in expandedRoots {
            guard let entries = try? fm.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            let categoryName = root.lastPathComponent
            for entryURL in entries {
                let entryName = entryURL.lastPathComponent
                guard isExactResidueMatch(
                    entryName: entryName,
                    normalizedBundleID: normalizedBundleID,
                    normalizedAppName: cleanedAppName
                ) else {
                    continue
                }

                let canonical = entryURL.standardizedFileURL.path
                guard visitedPaths.insert(canonical).inserted else { continue }

                let bytes = calculateSizeBytes(at: entryURL)
                foundItems.append(
                    AppResidueItem(
                        url: entryURL,
                        category: categoryName,
                        sizeBytes: bytes,
                        isSelected: true
                    )
                )
            }
        }

        return foundItems.sorted { $0.url.path < $1.url.path }
    }

    /// 将勾选的残留项与可选主应用包安全移入系统废纸篓并统计释放字节数
    public static func moveItemsToTrash(
        _ urls: [URL],
        includeAppBundleURL: URL? = nil
    ) -> AppTrashReport {
        let fm = FileManager.default
        var targets = urls
        if let appURL = includeAppBundleURL {
            targets.append(appURL)
        }

        var trashed: [URL] = []
        var failed: [URL] = []
        var reclaimed: Int64 = 0
        var seen = Set<String>()

        for target in targets {
            let canonical = target.standardizedFileURL.path
            guard seen.insert(canonical).inserted else { continue }
            guard fm.fileExists(atPath: canonical) else { continue }

            let itemSize = calculateSizeBytes(at: target)
            do {
                try fm.trashItem(at: target, resultingItemURL: nil)
                trashed.append(target)
                reclaimed += itemSize
            } catch {
                failed.append(target)
            }
        }

        return AppTrashReport(
            trashedURLs: trashed,
            failedURLs: failed,
            reclaimedBytes: reclaimed
        )
    }

    /// 递归计算单个文件或文件夹占用的字节体积
    public static func calculateSizeBytes(at url: URL) -> Int64 {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else {
            return 0
        }

        if !isDir.boolValue {
            let vals = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey])
            return Int64(vals?.totalFileAllocatedSize ?? vals?.fileSize ?? 0)
        }

        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let vals = try? fileURL.resourceValues(
                forKeys: [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileSizeKey]
            ), vals.isRegularFile == true else {
                continue
            }
            total += Int64(vals.totalFileAllocatedSize ?? vals.fileSize ?? 0)
        }
        return total
    }

    // MARK: - 精确边界匹配核心规则

    private static func sanitizeAppName(_ raw: String) -> String {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasSuffix(".app") {
            trimmed = String(trimmed.dropLast(4))
        }
        return trimmed.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func expandLibraryRootsIfNeeded(_ roots: [URL]) -> [URL] {
        let knownSet = Set(defaultLibrarySubdirectories.map { $0.lowercased() })
        var output: [URL] = []
        for root in roots {
            if root.lastPathComponent.lowercased() == "library" && !knownSet.contains(root.lastPathComponent.lowercased()) {
                for sub in defaultLibrarySubdirectories {
                    output.append(root.appendingPathComponent(sub, isDirectory: true))
                }
            } else {
                output.append(root)
            }
        }
        return output
    }

    private static func isExactResidueMatch(
        entryName: String,
        normalizedBundleID: String,
        normalizedAppName: String
    ) -> Bool {
        let lower = entryName.lowercased()

        // 1. Bundle ID 边界匹配：仅允许完整相等、点号后缀扩展（如 .plist/.savedState/.helper）或点号前缀容器（如 group.<bid> / <TeamID>.<bid>）
        if !normalizedBundleID.isEmpty && normalizedBundleID.contains(".") {
            if lower == normalizedBundleID {
                return true
            }
            if lower.hasPrefix(normalizedBundleID + ".") {
                return true
            }
            if lower.hasSuffix("." + normalizedBundleID) {
                return true
            }
            if lower.contains("." + normalizedBundleID + ".") {
                return true
            }
        }

        // 2. 应用名称精确匹配：仅匹配完全同名目录或标准配置文件后缀，严禁前缀模糊匹配（避免 DemoApp 误伤 DemoAppHelperPro）
        if normalizedAppName.count >= 2 {
            if lower == normalizedAppName {
                return true
            }
            let allowedAppExtensions = [".plist", ".savedstate", ".binarycookies", ".sfl2", ".sfl3"]
            for ext in allowedAppExtensions where lower == normalizedAppName + ext {
                return true
            }
        }

        return false
    }
}
