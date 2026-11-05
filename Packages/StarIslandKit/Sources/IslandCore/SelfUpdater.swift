import AppKit
import Combine
import Darwin
import Foundation

public struct SemanticVersion: Comparable, Equatable, Codable, Sendable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public init(_ raw: String) {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "^[vV]", with: "", options: .regularExpression)
        let parts = cleaned.split(separator: ".").compactMap { Int($0.prefix(while: \.isNumber)) }
        self.major = parts.count > 0 ? parts[0] : 0
        self.minor = parts.count > 1 ? parts[1] : 0
        self.patch = parts.count > 2 ? parts[2] : 0
    }

    public var buildNumber: Int {
        max(1, major * 10000 + minor * 100 + patch)
    }

    public var description: String {
        "\(major).\(minor).\(patch)"
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }
}

public struct GitHubReleaseInfo: Equatable, Sendable {
    public let tagName: String
    public let version: SemanticVersion
    public let title: String
    public let notes: String
    public let htmlURL: URL?
    public let downloadURL: URL?

    public init(tagName: String, version: SemanticVersion, title: String, notes: String, htmlURL: URL?, downloadURL: URL?) {
        self.tagName = tagName
        self.version = version
        self.title = title
        self.notes = notes
        self.htmlURL = htmlURL
        self.downloadURL = downloadURL
    }
}

public enum GitHubReleaseParser {
    private struct WireRelease: Decodable {
        struct Asset: Decodable {
            let name: String
            let browser_download_url: String
        }
        let tag_name: String
        let name: String?
        let body: String?
        let html_url: String?
        let assets: [Asset]
    }

    public static func parse(data: Data) throws -> GitHubReleaseInfo {
        let wire = try JSONDecoder().decode(WireRelease.self, from: data)
        let preferredAsset = wire.assets.first(where: { $0.name.hasSuffix(".zip") && $0.name.localizedCaseInsensitiveContains("StarIsland") })
            ?? wire.assets.first(where: { $0.name.hasSuffix(".zip") })
        return GitHubReleaseInfo(
            tagName: wire.tag_name,
            version: SemanticVersion(wire.tag_name),
            title: wire.name ?? wire.tag_name,
            notes: wire.body ?? "",
            htmlURL: wire.html_url.flatMap(URL.init(string:)),
            downloadURL: preferredAsset.flatMap { URL(string: $0.browser_download_url) }
        )
    }
}

@MainActor
public final class SelfUpdater: ObservableObject {
    public static let shared = SelfUpdater()
    public static let repositorySlug = "adgry/StarIsland"
    public static let repositoryWebURL = URL(string: "https://github.com/adgry/StarIsland")!
    public static let latestReleaseAPIURL = URL(string: "https://api.github.com/repos/adgry/StarIsland/releases/latest")!

    public enum UpdateState: Equatable, Sendable {
        case idle
        case checking
        case upToDate(SemanticVersion)
        case updateAvailable(GitHubReleaseInfo)
        case downloading
        case installing
        case failed(String)
    }

    @Published public private(set) var state: UpdateState = .idle

    public init() {}

    public var currentVersion: SemanticVersion {
        let str = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        return SemanticVersion(str)
    }

    public func checkForUpdates() async {
        state = .checking
        var request = URLRequest(url: Self.latestReleaseAPIURL, timeoutInterval: 10)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("StarIsland-macOS", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 404 {
                state = .upToDate(currentVersion)
                return
            }
            let release = try GitHubReleaseParser.parse(data: data)
            if release.version > currentVersion {
                state = .updateAvailable(release)
            } else {
                state = .upToDate(currentVersion)
            }
        } catch {
            state = .failed("检查更新失败：\(error.localizedDescription)")
        }
    }

    public func downloadAndInstall(_ release: GitHubReleaseInfo) async {
        guard let downloadURL = release.downloadURL else {
            state = .failed("该版本未附带可下载的 .zip 安装包")
            return
        }
        state = .downloading
        let stagingRoot = FileManager.default.temporaryDirectory.appendingPathComponent("StarIslandUpdate-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: stagingRoot, withIntermediateDirectories: true)
            let (tempZip, _) = try await URLSession.shared.download(from: downloadURL)
            let localZip = stagingRoot.appendingPathComponent("StarIsland-arm64.zip")
            try FileManager.default.moveItem(at: tempZip, to: localZip)

            state = .installing
            let unpackDir = stagingRoot.appendingPathComponent("unpacked", isDirectory: true)
            try FileManager.default.createDirectory(at: unpackDir, withIntermediateDirectories: true)
            try Self.runProcess("/usr/bin/ditto", arguments: ["-x", "-k", localZip.path, unpackDir.path])

            let stagedApp = unpackDir.appendingPathComponent("StarIsland.app")
            guard FileManager.default.fileExists(atPath: stagedApp.path) else {
                state = .failed("更新包中未找到 StarIsland.app")
                return
            }

            _ = try? Self.runProcess("/usr/bin/xattr", arguments: ["-cr", stagedApp.path])

            let targetPath = Bundle.main.bundleURL.path.hasSuffix(".app")
                ? Bundle.main.bundleURL.path
                : "/Applications/StarIsland.app"

            if FileManager.default.isWritableFile(atPath: (targetPath as NSString).deletingLastPathComponent) {
                if FileManager.default.fileExists(atPath: targetPath) {
                    try FileManager.default.removeItem(atPath: targetPath)
                }
                try Self.runProcess("/usr/bin/ditto", arguments: [stagedApp.path, targetPath])
                Self.relaunch(at: targetPath)
            } else if let helper = ServiceRegistry.shared.helperService,
                      try await helper.installStagedUpdate(from: stagedApp.path, to: targetPath) {
                Self.relaunch(at: targetPath)
            } else {
                let script = "do shell script \"rm -rf '\(targetPath)' && /usr/bin/ditto '\(stagedApp.path)' '\(targetPath)' && /usr/bin/xattr -cr '\(targetPath)'\" with administrator privileges"
                try Self.runProcess("/usr/bin/osascript", arguments: ["-e", script])
                Self.relaunch(at: targetPath)
            }
        } catch {
            state = .failed("更新安装失败：\(error.localizedDescription)")
        }
    }

    @discardableResult
    nonisolated private static func runProcess(_ launchPath: String, arguments: [String]) throws -> Int32 {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: launchPath)
        proc.arguments = arguments
        try proc.run()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else {
            throw NSError(domain: "StarIslandUpdater", code: Int(proc.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "\(launchPath) 退出码 \(proc.terminationStatus)"])
        }
        return proc.terminationStatus
    }

    nonisolated private static func relaunch(at appPath: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-c", "sleep 0.8; /usr/bin/open -n \"\(appPath)\""]
        try? proc.run()
        DispatchQueue.main.async {
            NSApplication.shared.terminate(nil)
        }
    }
}
