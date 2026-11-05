import CryptoKit
import Foundation

public final class ConsumedEventStore: @unchecked Sendable {
    public static let shared = ConsumedEventStore(
        fileURL: StarIslandPaths.appSupportDirectory.appendingPathComponent("consumed-events.json")
    )

    private struct Entry: Codable {
        let fingerprint: String
        let consumedAt: Date
    }

    private let fileURL: URL
    private let maxEntries: Int
    private let ttl: TimeInterval
    private let lock = NSLock()
    private var entries: [Entry] = []

    public init(fileURL: URL, maxEntries: Int = 500, ttl: TimeInterval = 86_400) {
        self.fileURL = fileURL
        self.maxEntries = max(1, maxEntries)
        self.ttl = max(1, ttl)
        self.entries = Self.loadFromDisk(url: fileURL)
    }

    public static func sha256Hex(_ raw: String) -> String {
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public func hasConsumed(fingerprint: String, now: Date = Date()) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        pruneExpiredLocked(now: now)
        return entries.contains { $0.fingerprint == fingerprint }
    }

    @discardableResult
    public func tryConsume(fingerprint: String, now: Date = Date()) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        pruneExpiredLocked(now: now)
        if entries.contains(where: { $0.fingerprint == fingerprint }) {
            return false
        }
        entries.append(Entry(fingerprint: fingerprint, consumedAt: now))
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        persistLocked()
        return true
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        entries.removeAll()
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func pruneExpiredLocked(now: Date) {
        let beforeCount = entries.count
        entries.removeAll { now.timeIntervalSince($0.consumedAt) > ttl }
        if entries.count != beforeCount {
            persistLocked()
        }
    }

    private func persistLocked() {
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func loadFromDisk(url: URL) -> [Entry] {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Entry].self, from: data) else {
            return []
        }
        return decoded
    }
}

public enum StarIslandPaths {
    public static var appSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let dir = base.appendingPathComponent("StarIsland", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    public static var cachesDirectory: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Caches")
        let dir = base.appendingPathComponent("StarIsland", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
