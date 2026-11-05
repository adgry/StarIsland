import AppKit
import Combine
import CryptoKit
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
    public let sha256URL: URL?

    public init(
        tagName: String,
        version: SemanticVersion,
        title: String,
        notes: String,
        htmlURL: URL?,
        downloadURL: URL?,
        sha256URL: URL? = nil
    ) {
        self.tagName = tagName
        self.version = version
        self.title = title
        self.notes = notes
        self.htmlURL = htmlURL
        self.downloadURL = downloadURL
        self.sha256URL = sha256URL
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
        let shaAsset = wire.assets.first(where: { $0.name.hasSuffix(".zip.sha256") || $0.name.hasSuffix(".sha256") })
        return GitHubReleaseInfo(
            tagName: wire.tag_name,
            version: SemanticVersion(wire.tag_name),
            title: wire.name ?? wire.tag_name,
            notes: wire.body ?? "",
            htmlURL: wire.html_url.flatMap(URL.init(string:)),
            downloadURL: preferredAsset.flatMap { URL(string: $0.browser_download_url) },
            sha256URL: shaAsset.flatMap { URL(string: $0.browser_download_url) }
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

    nonisolated public static func sha256Hex(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    nonisolated public static func matchesExpectedSHA256(data: Data, sha256FileText: String) -> Bool {
        let firstToken = sha256FileText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .first
            .map(String.init)?
            .lowercased() ?? ""
        guard firstToken.count == 64 else { return false }
        return sha256Hex(of: data) == firstToken
    }

    public func checkForUpdates() async {
        state = .checking
        var request = URLRequest(url: Self.latestReleaseAPIURL, timeoutInterval: 10)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("StarIsland-macOS", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                if http.statusCode == 404 {
                    state = .upToDate(currentVersion)
                    return
                }
                guard (200...299).contains(http.statusCode) else {
                    state = .failed("GitHub 接口返回状态码 \(http.statusCode)")
                    return
                }
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
        let stagingRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("StarIslandUpdate-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: stagingRoot, withIntermediateDirectories: true)
            let (tempZip, zipResp) = try await URLSession.shared.download(from: downloadURL)
            if let http = zipResp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                state = .failed("下载更新包失败（HTTP \(http.statusCode)）")
                return
            }
            let localZip = stagingRoot.appendingPathComponent("StarIsland-arm64.zip")
            try FileManager.default.moveItem(at: tempZip, to: localZip)

            if let shaURL = release.sha256URL {
                let (shaData, shaResp) = try await URLSession.shared.data(from: shaURL)
                if let http = shaResp as? HTTPURLResponse, (200...299).contains(http.statusCode),
                   let shaText = String(data: shaData, encoding: .utf8) {
                    let zipBytes = try Data(contentsOf: localZip, options: .mappedIfSafe)
                    guard Self.matchesExpectedSHA256(data: zipBytes, sha256FileText: shaText) else {
                        state = .failed("更新包 SHA-256 完整性校验未通过，已中止安装")
                        return
                    }
                }
            }

            state = .installing
            let unpackDir = stagingRoot.appendingPathComponent("unpacked", isDirectory: true)
            try FileManager.default.createDirectory(at: unpackDir, withIntermediateDirectories: true)
            try await Self.runProcessAsync("/usr/bin/ditto", arguments: ["-x", "-k", localZip.path, unpackDir.path])

            let stagedApp = unpackDir.appendingPathComponent("StarIsland.app")
            guard FileManager.default.fileExists(atPath: stagedApp.path) else {
                state = .failed("更新包中未找到 StarIsland.app")
                return
            }

            _ = try? await Self.runProcessAsync("/usr/bin/xattr", arguments: ["-cr", stagedApp.path])

            let targetPath = Bundle.main.bundleURL.path.hasSuffix(".app")
                ? Bundle.main.bundleURL.path
                : "/Applications/StarIsland.app"

            if FileManager.default.isWritableFile(atPath: (targetPath as NSString).deletingLastPathComponent) {
                if FileManager.default.fileExists(atPath: targetPath) {
                    try FileManager.default.removeItem(atPath: targetPath)
                }
                try await Self.runProcessAsync("/usr/bin/ditto", arguments: [stagedApp.path, targetPath])
                Self.relaunch(at: targetPath)
            } else if let helper = ServiceRegistry.shared.helperService,
                      (try? await helper.installStagedUpdate(from: stagedApp.path, to: targetPath)) == true {
                Self.relaunch(at: targetPath)
            } else {
                let script = """
                on run
                    set stagedPath to system attribute "STARISLAND_STAGED"
                    set targetPath to system attribute "STARISLAND_TARGET"
                    do shell script "rm -rf " & quoted form of targetPath & " && /usr/bin/ditto " & quoted form of stagedPath & " " & quoted form of targetPath & " && /usr/bin/xattr -cr " & quoted form of targetPath with administrator privileges
                end run
                """
                try await Self.runProcessAsync(
                    "/usr/bin/osascript",
                    arguments: ["-e", script],
                    environment: [
                        "STARISLAND_STAGED": stagedApp.path,
                        "STARISLAND_TARGET": targetPath,
                    ]
                )
                Self.relaunch(at: targetPath)
            }
        } catch {
            state = .failed("更新安装失败：\(error.localizedDescription)")
        }
    }

    @discardableResult
    nonisolated private static func runProcessAsync(
        _ launchPath: String,
        arguments: [String],
        environment: [String: String] = [:]
    ) async throws -> Int32 {
        try await withCheckedThrowingContinuation { continuation in
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: launchPath)
            proc.arguments = arguments
            if !environment.isEmpty {
                var merged = ProcessInfo.processInfo.environment
                for (k, v) in environment { merged[k] = v }
                proc.environment = merged
            }
            proc.terminationHandler = { finished in
                let code = finished.terminationStatus
                if code == 0 {
                    continuation.resume(returning: code)
                } else {
                    continuation.resume(throwing: NSError(
                        domain: "StarIslandUpdater",
                        code: Int(code),
                        userInfo: [NSLocalizedDescriptionKey: "\(launchPath) 退出码 \(code)"]
                    ))
                }
            }
            do {
                try proc.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    nonisolated private static func relaunch(at appPath: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-c", "sleep 0.8; /usr/bin/open -n \"$STARISLAND_APP_PATH\""]
        var env = ProcessInfo.processInfo.environment
        env["STARISLAND_APP_PATH"] = appPath
        proc.environment = env
        try? proc.run()
        DispatchQueue.main.async {
            NSApplication.shared.terminate(nil)
        }
    }
}
