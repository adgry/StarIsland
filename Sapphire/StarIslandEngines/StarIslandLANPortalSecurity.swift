//
//  StarIslandLANPortalSecurity.swift
//  Sapphire
//

#if !SAPPHIRE_FULL_BUILD
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import CryptoKit
import Darwin
import Foundation

struct StarIslandPairedSession: Identifiable, Equatable, Sendable {
    let id: String
    let deviceName: String
    let pairedAt: Date
    let expiresAt: Date
}

struct StarIslandPairingTokenManager: Sendable {
    private final class Storage: @unchecked Sendable {
        let lock = NSLock()
        let sessionTTL: TimeInterval
        var currentPIN: String
        var failedAttempts: Int = 0
        var sessionsByToken: [String: StarIslandPairedSession] = [:]

        init(sessionTTL: TimeInterval) {
            self.sessionTTL = max(60, sessionTTL)
            self.currentPIN = Self.randomSixDigitPIN(excluding: nil)
        }

        static func randomSixDigitPIN(excluding previous: String?) -> String {
            var rng = SystemRandomNumberGenerator()
            for _ in 0..<8 {
                let formatted = String(format: "%06d", Int.random(in: 0...999_999, using: &rng))
                if formatted != previous { return formatted }
            }
            return String(format: "%06d", Int.random(in: 0...999_999))
        }
    }

    private let storage: Storage

    init(sessionTTL: TimeInterval = 43_200) {
        self.storage = Storage(sessionTTL: sessionTTL)
    }

    var currentPIN: String {
        storage.lock.lock()
        defer { storage.lock.unlock() }
        return storage.currentPIN
    }

    @discardableResult
    func generateNewPIN() -> String {
        storage.lock.lock()
        defer { storage.lock.unlock() }
        let next = Storage.randomSixDigitPIN(excluding: storage.currentPIN)
        storage.currentPIN = next
        storage.failedAttempts = 0
        storage.sessionsByToken.removeAll()
        return next
    }

    func issueSessionToken(forPIN candidatePIN: String, deviceName: String = "移动浏览器") -> String? {
        let cleaned = candidatePIN.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count == 6, cleaned.allSatisfy({ $0.isASCII && $0.isNumber }) else {
            return nil
        }

        storage.lock.lock()
        defer { storage.lock.unlock() }

        guard Self.constantTimeEquals(cleaned, storage.currentPIN) else {
            storage.failedAttempts += 1
            if storage.failedAttempts >= 5 {
                storage.currentPIN = Storage.randomSixDigitPIN(excluding: storage.currentPIN)
                storage.failedAttempts = 0
            }
            return nil
        }

        storage.currentPIN = Storage.randomSixDigitPIN(excluding: storage.currentPIN)
        storage.failedAttempts = 0

        let randomKey = SymmetricKey(size: .bits256)
        let token = randomKey.withUnsafeBytes { buf in
            buf.map { String(format: "%02x", $0) }.joined()
        }
        let now = Date()
        let safeDevice = deviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let session = StarIslandPairedSession(
            id: String(token.prefix(12)),
            deviceName: safeDevice.isEmpty ? "移动浏览器" : String(safeDevice.prefix(48)),
            pairedAt: now,
            expiresAt: now.addingTimeInterval(storage.sessionTTL)
        )
        storage.sessionsByToken[token] = session
        return token
    }

    func isValidSession(_ token: String?) -> Bool {
        guard let token = token?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else {
            return false
        }
        storage.lock.lock()
        defer { storage.lock.unlock() }
        let now = Date()
        storage.sessionsByToken = storage.sessionsByToken.filter { $0.value.expiresAt > now }
        return storage.sessionsByToken[token] != nil
    }

    func activeSessions() -> [StarIslandPairedSession] {
        storage.lock.lock()
        defer { storage.lock.unlock() }
        let now = Date()
        storage.sessionsByToken = storage.sessionsByToken.filter { $0.value.expiresAt > now }
        return storage.sessionsByToken.values.sorted { $0.pairedAt > $1.pairedAt }
    }

    static func extractBearerToken(from header: String?) -> String? {
        guard let h = header?.trimmingCharacters(in: .whitespacesAndNewlines), h.count > 7,
              h.prefix(7).lowercased() == "bearer " else {
            return nil
        }
        let tok = h.dropFirst(7).trimmingCharacters(in: .whitespacesAndNewlines)
        return tok.isEmpty ? nil : tok
    }

    private static func constantTimeEquals(_ lhs: String, _ rhs: String) -> Bool {
        let a = Array(lhs.utf8)
        let b = Array(rhs.utf8)
        guard a.count == b.count else { return false }
        var diff: UInt8 = 0
        for i in 0..<a.count { diff |= (a[i] ^ b[i]) }
        return diff == 0
    }
}

enum StarIslandSafeFilename {
    static let fallbackFilename = "transfer.bin"
    private static let forbidden: Set<Character> = ["/", "\\", ":", "*", "?", "\"", "<", ">", "|", "\0"]

    static func sanitize(_ raw: String) -> String {
        let clean = String(raw.unicodeScalars.filter { $0.value >= 32 && $0.value != 127 })
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return fallbackFilename }
        let norm = clean.replacingOccurrences(of: "\\", with: "/")
        guard !norm.hasSuffix("/"), let tail = norm.split(separator: "/", omittingEmptySubsequences: false).last else {
            return fallbackFilename
        }
        var candidate = String(tail).trimmingCharacters(in: .whitespacesAndNewlines)
        if candidate.isEmpty || candidate == "." || candidate == ".." { return fallbackFilename }
        while candidate.hasPrefix(".") { candidate.removeFirst() }
        candidate = String(candidate.map { forbidden.contains($0) ? "_" : $0 })
        while candidate.contains("..") { candidate = candidate.replacingOccurrences(of: "..", with: "_") }
        candidate = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        let meaningful = candidate.filter { $0 != "_" && $0 != "." && !$0.isWhitespace }
        guard !candidate.isEmpty, !meaningful.isEmpty else { return fallbackFilename }
        if candidate.count > 160 {
            let ext = (candidate as NSString).pathExtension
            let stem = String((candidate as NSString).deletingPathExtension.prefix(120))
            candidate = ext.isEmpty ? stem : "\(stem).\(ext.prefix(24))"
        }
        return candidate
    }

    static func uniqueDestinationURL(in directory: URL, rawFilename: String) -> URL {
        let base = sanitize(rawFilename)
        let dir = directory.standardizedFileURL
        let stem = (base as NSString).deletingPathExtension
        let ext = (base as NSString).pathExtension
        for attempt in 0..<2000 {
            let name = attempt == 0 ? base : (ext.isEmpty ? "\(stem)-\(attempt)" : "\(stem)-\(attempt).\(ext)")
            let url = dir.appendingPathComponent(name, isDirectory: false).standardizedFileURL
            if url.path.hasPrefix(dir.path + "/") && !FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        return dir.appendingPathComponent("\(UUID().uuidString)-\(fallbackFilename)", isDirectory: false)
    }
}

enum StarIslandQRCodeGenerator {
    static func makeImage(from string: String, dimension: CGFloat = 220) -> NSImage? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, dimension > 0 else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(trimmed.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let extent = output.extent.integral
        guard extent.width > 0, extent.height > 0 else { return nil }
        let scale = max(1, floor(dimension / max(extent.width, extent.height)))
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let ctx = CIContext(options: [.useSoftwareRenderer: false])
        guard let cg = ctx.createCGImage(scaled, from: scaled.extent.integral) else { return nil }
        let rep = NSBitmapImageRep(cgImage: cg)
        let img = NSImage(size: NSSize(width: cg.width, height: cg.height))
        img.addRepresentation(rep)
        return img
    }
}

enum StarIslandLANAddressDetector {
    static func preferredIPv4Address() -> String {
        var ptr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ptr) == 0, let first = ptr else { return "127.0.0.1" }
        defer { freeifaddrs(ptr) }
        var candidates: [(String, String)] = []
        var cur: UnsafeMutablePointer<ifaddrs>? = first
        while let c = cur {
            let flags = Int32(c.pointee.ifa_flags)
            if (flags & IFF_UP) != 0, (flags & IFF_RUNNING) != 0, (flags & IFF_LOOPBACK) == 0,
               let addr = c.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) {
                let iface = String(cString: c.pointee.ifa_name)
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(addr, socklen_t(addr.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                    let ip = String(cString: host)
                    if !ip.hasPrefix("127."), !ip.hasPrefix("169.254.") {
                        candidates.append((iface, ip))
                    }
                }
            }
            cur = c.pointee.ifa_next
        }
        return candidates.first(where: { $0.0 == "en0" })?.1
            ?? candidates.first(where: { $0.0 == "en1" })?.1
            ?? candidates.first(where: { $0.0.hasPrefix("en") })?.1
            ?? candidates.first?.1
            ?? "127.0.0.1"
    }
}
#endif
