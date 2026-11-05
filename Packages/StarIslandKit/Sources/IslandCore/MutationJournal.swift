import Foundation

public enum MutationKind: String, Codable, CaseIterable, Sendable {
    case batteryChargeLimit
    case batteryChargeInhibit
    case fanManualControl
    case focusHostsBlock
    case mouseAcceleration
}

public struct MutationRecord: Codable, Equatable, Sendable {
    public let kind: MutationKind
    public let previousValue: String
    public let appliedValue: String
    public let recordedAt: Date

    public init(kind: MutationKind, previousValue: String, appliedValue: String, recordedAt: Date = Date()) {
        self.kind = kind
        self.previousValue = previousValue
        self.appliedValue = appliedValue
        self.recordedAt = recordedAt
    }
}

public final class MutationJournal: @unchecked Sendable {
    public static let shared = MutationJournal(
        fileURL: StarIslandPaths.appSupportDirectory.appendingPathComponent("mutation-journal.json")
    )

    private let fileURL: URL
    private let lock = NSLock()
    private var records: [MutationKind: MutationRecord] = [:]

    public init(fileURL: URL) {
        self.fileURL = fileURL
        if let data = try? Data(contentsOf: fileURL),
           let list = try? JSONDecoder().decode([MutationRecord].self, from: data) {
            for item in list {
                records[item.kind] = item
            }
        }
    }

    public func record(_ entry: MutationRecord) {
        lock.lock()
        defer { lock.unlock() }
        records[entry.kind] = entry
        persistLocked()
    }

    public func clear(_ kind: MutationKind) {
        lock.lock()
        defer { lock.unlock() }
        records.removeValue(forKey: kind)
        persistLocked()
    }

    public func pendingRecords() -> [MutationRecord] {
        lock.lock()
        defer { lock.unlock() }
        return records.values.sorted { $0.recordedAt < $1.recordedAt }
    }

    private func persistLocked() {
        if records.isEmpty {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let sorted = records.values.sorted { $0.kind.rawValue < $1.kind.rawValue }
        if let data = try? JSONEncoder().encode(sorted) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
