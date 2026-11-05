import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import CryptoKit
import Darwin
import Foundation

public struct PairedDeviceSession: Identifiable, Equatable, Sendable {
    public let id: String
    public let deviceName: String
    public let pairedAt: Date
    public let expiresAt: Date

    public init(id: String, deviceName: String, pairedAt: Date, expiresAt: Date) {
        self.id = id
        self.deviceName = deviceName
        self.pairedAt = pairedAt
        self.expiresAt = expiresAt
    }
}

/// 局域网一次性 6 位动态配对码与 Bearer 会话令牌管理器
public struct PairingTokenManager: Sendable {
    private final class Storage: @unchecked Sendable {
        let lock = NSLock()
        let sessionTTL: TimeInterval
        var currentPIN: String
        var sessionsByToken: [String: PairedDeviceSession] = [:]

        init(sessionTTL: TimeInterval) {
            self.sessionTTL = max(60, sessionTTL)
            self.currentPIN = Self.randomSixDigitPIN(excluding: nil)
        }

        static func randomSixDigitPIN(excluding previous: String?) -> String {
            var rng = SystemRandomNumberGenerator()
            for _ in 0..<8 {
                let value = Int.random(in: 0...999_999, using: &rng)
                let formatted = String(format: "%06d", value)
                if formatted != previous {
                    return formatted
                }
            }
            return String(format: "%06d", Int.random(in: 0...999_999))
        }
    }

    private let storage: Storage

    public init(sessionTTL: TimeInterval = 43_200) {
        self.storage = Storage(sessionTTL: sessionTTL)
    }

    public var currentPIN: String {
        storage.lock.lock()
        defer { storage.lock.unlock() }
        return storage.currentPIN
    }

    @discardableResult
    public func generateNewPIN() -> String {
        storage.lock.lock()
        defer { storage.lock.unlock() }
        let next = Storage.randomSixDigitPIN(excluding: storage.currentPIN)
        storage.currentPIN = next
        storage.sessionsByToken.removeAll()
        return next
    }

    public func issueSessionToken(forPIN candidatePIN: String, deviceName: String = "移动浏览器") -> String? {
        let cleaned = candidatePIN.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count == 6, cleaned.allSatisfy({ $0.isASCII && $0.isNumber }) else {
            return nil
        }

        storage.lock.lock()
        defer { storage.lock.unlock() }

        guard Self.constantTimeEquals(cleaned, storage.currentPIN) else {
            return nil
        }

        let randomKey = SymmetricKey(size: .bits256)
        let token = randomKey.withUnsafeBytes { rawBuffer in
            rawBuffer.map { String(format: "%02x", $0) }.joined()
        }

        let now = Date()
        let safeDevice = deviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let session = PairedDeviceSession(
            id: String(token.prefix(12)),
            deviceName: safeDevice.isEmpty ? "移动浏览器" : String(safeDevice.prefix(48)),
            pairedAt: now,
            expiresAt: now.addingTimeInterval(storage.sessionTTL)
        )
        storage.sessionsByToken[token] = session
        return token
    }

    public func isValidSession(_ token: String?) -> Bool {
        guard let token = token?.trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty else {
            return false
        }
        storage.lock.lock()
        defer { storage.lock.unlock() }

        let now = Date()
        storage.sessionsByToken = storage.sessionsByToken.filter { $0.value.expiresAt > now }
        return storage.sessionsByToken[token] != nil
    }

    public func activeSessions() -> [PairedDeviceSession] {
        storage.lock.lock()
        defer { storage.lock.unlock() }
        let now = Date()
        storage.sessionsByToken = storage.sessionsByToken.filter { $0.value.expiresAt > now }
        return storage.sessionsByToken.values.sorted { $0.pairedAt > $1.pairedAt }
    }

    public func revokeAllSessions() {
        storage.lock.lock()
        defer { storage.lock.unlock() }
        storage.sessionsByToken.removeAll()
    }

    public static func extractBearerToken(from authorizationHeader: String?) -> String? {
        guard let header = authorizationHeader?.trimmingCharacters(in: .whitespacesAndNewlines),
              header.count > 7 else {
            return nil
        }
        let prefix = header.prefix(7)
        guard prefix.lowercased() == "bearer " else {
            return nil
        }
        let token = header.dropFirst(7).trimmingCharacters(in: .whitespacesAndNewlines)
        return token.isEmpty ? nil : token
    }

    private static func constantTimeEquals(_ lhs: String, _ rhs: String) -> Bool {
        let leftBytes = Array(lhs.utf8)
        let rightBytes = Array(rhs.utf8)
        guard leftBytes.count == rightBytes.count else { return false }
        var diff: UInt8 = 0
        for idx in 0..<leftBytes.count {
            diff |= (leftBytes[idx] ^ rightBytes[idx])
        }
        return diff == 0
    }
}

/// 严格清洗上传文件名，彻底阻断路径穿越与非法系统文件写入
public enum SafeFilenameSanitizer {
    public static let fallbackFilename = "transfer.bin"

    private static let forbiddenCharacters: Set<Character> = [
        "/", "\\", ":", "*", "?", "\"", "<", ">", "|", "\0"
    ]

    public static func sanitize(_ raw: String) -> String {
        let withoutControls = String(
            raw.unicodeScalars.filter { scalar in
                scalar.value >= 32 && scalar.value != 127
            }
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        guard !withoutControls.isEmpty else {
            return fallbackFilename
        }

        let normalizedSlashes = withoutControls.replacingOccurrences(of: "\\", with: "/")
        guard !normalizedSlashes.hasSuffix("/") else {
            return fallbackFilename
        }

        let components = normalizedSlashes.split(separator: "/", omittingEmptySubsequences: false)
        guard let tailSub = components.last else {
            return fallbackFilename
        }

        var candidate = String(tailSub).trimmingCharacters(in: .whitespacesAndNewlines)
        if candidate.isEmpty || candidate == "." || candidate == ".." {
            return fallbackFilename
        }

        while candidate.hasPrefix(".") {
            candidate.removeFirst()
        }

        candidate = String(candidate.map { forbiddenCharacters.contains($0) ? "_" : $0 })
        while candidate.contains("..") {
            candidate = candidate.replacingOccurrences(of: "..", with: "_")
        }
        candidate = candidate.trimmingCharacters(in: .whitespacesAndNewlines)

        let meaningful = candidate.filter { $0 != "_" && $0 != "." && !$0.isWhitespace }
        guard !candidate.isEmpty, !meaningful.isEmpty else {
            return fallbackFilename
        }

        if candidate.count > 160 {
            let ext = (candidate as NSString).pathExtension
            let stem = (candidate as NSString).deletingPathExtension
            let clippedStem = String(stem.prefix(120))
            candidate = ext.isEmpty ? clippedStem : "\(clippedStem).\(ext.prefix(24))"
        }

        return candidate
    }

    public static func uniqueDestinationURL(in directory: URL, rawFilename: String) -> URL {
        let baseSafeName = sanitize(rawFilename)
        let dirStandard = directory.standardizedFileURL
        let nsName = baseSafeName as NSString
        let stem = nsName.deletingPathExtension
        let ext = nsName.pathExtension

        var attempt = 0
        while attempt < 5000 {
            let fileName: String
            if attempt == 0 {
                fileName = baseSafeName
            } else if ext.isEmpty {
                fileName = "\(stem)-\(attempt)"
            } else {
                fileName = "\(stem)-\(attempt).\(ext)"
            }

            let candidateURL = dirStandard.appendingPathComponent(fileName, isDirectory: false).standardizedFileURL
            if candidateURL.path.hasPrefix(dirStandard.path + "/") {
                if !FileManager.default.fileExists(atPath: candidateURL.path) {
                    return candidateURL
                }
            }
            attempt += 1
        }

        return dirStandard.appendingPathComponent("\(UUID().uuidString)-\(fallbackFilename)", isDirectory: false)
    }
}

/// 基于 CoreImage CIQRCodeGenerator 生成高清无模糊二维码位图
public enum QRCodeGenerator {
    public static func makeImage(from string: String, dimension: CGFloat = 260) -> NSImage? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, dimension > 0 else { return nil }

        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(trimmed.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }
        let extent = outputImage.extent.integral
        guard extent.width > 0, extent.height > 0 else { return nil }

        let scale = max(1, floor(dimension / max(extent.width, extent.height)))
        let scaledCIImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cgImage = context.createCGImage(scaledCIImage, from: scaledCIImage.extent.integral) else {
            return nil
        }

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        let image = NSImage(size: NSSize(width: cgImage.width, height: cgImage.height))
        image.addRepresentation(bitmapRep)
        return image
    }
}

/// 自动探测本机局域网活跃 IPv4 地址（优先 en0 / en1）
public enum LANAddressDetector {
    public static func preferredIPv4Address() -> String {
        var ifaddrPointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPointer) == 0, let firstAddr = ifaddrPointer else {
            return "127.0.0.1"
        }
        defer { freeifaddrs(ifaddrPointer) }

        var candidates: [(interface: String, ip: String)] = []
        var cursor: UnsafeMutablePointer<ifaddrs>? = firstAddr

        while let current = cursor {
            let flags = Int32(current.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) != 0
            let isRunning = (flags & IFF_RUNNING) != 0
            let isLoopback = (flags & IFF_LOOPBACK) != 0

            if isUp, isRunning, !isLoopback,
               let addr = current.pointee.ifa_addr,
               addr.pointee.sa_family == UInt8(AF_INET) {
                let name = String(cString: current.pointee.ifa_name)
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let result = getnameinfo(
                    addr,
                    socklen_t(addr.pointee.sa_len),
                    &hostname,
                    socklen_t(hostname.count),
                    nil,
                    0,
                    NI_NUMERICHOST
                )
                if result == 0 {
                    let ip = String(cString: hostname)
                    if !ip.hasPrefix("127.") && !ip.hasPrefix("169.254.") {
                        candidates.append((name, ip))
                    }
                }
            }
            cursor = current.pointee.ifa_next
        }

        if let en0 = candidates.first(where: { $0.interface == "en0" }) {
            return en0.ip
        }
        if let en1 = candidates.first(where: { $0.interface == "en1" }) {
            return en1.ip
        }
        if let anyEn = candidates.first(where: { $0.interface.hasPrefix("en") }) {
            return anyEn.ip
        }
        return candidates.first?.ip ?? "127.0.0.1"
    }
}
