//
//  SmartInboxFeatures.swift
//  Sapphire
//

#if !SAPPHIRE_FULL_BUILD
import Foundation
import Combine
import CryptoKit

struct OTPEvent: Identifiable, Equatable {
    let id: String
    let code: String
    let source: String
    let title: String
    let body: String
    let date: Date
}

struct ParcelShipment: Identifiable, Equatable, Codable {
    let id: String
    var trackingNumber: String
    var carrier: ParcelCarrier
    var title: String
    var status: String
    var detail: String
    var lastUpdated: Date
    var sourceEmailSubject: String?
    var isDelivered: Bool

    var trackingURL: URL? { carrier.trackingURL(trackingNumber) }
}

enum ParcelCarrier: String, Codable, CaseIterable {
    case ups, fedex, usps, dhl, amazon, unknown

    var displayName: String {
        switch self {
        case .ups: return "UPS"
        case .fedex: return "FedEx"
        case .usps: return "USPS"
        case .dhl: return "DHL"
        case .amazon: return "Amazon"
        case .unknown: return "快递承运商"
        }
    }

    var trackingURL: (String) -> URL? {
        { rawNumber in
            let encoded = rawNumber.trimmingCharacters(in: .whitespacesAndNewlines)
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? rawNumber
            guard !encoded.isEmpty else { return nil }
            switch self {
            case .ups:
                return URL(string: "https://www.ups.com/track?tracknum=\(encoded)")
            case .fedex:
                return URL(string: "https://www.fedex.com/fedextrack/?trknbr=\(encoded)")
            case .usps:
                return URL(string: "https://tools.usps.com/go/TrackConfirmAction?tLabels=\(encoded)")
            case .dhl:
                return URL(string: "https://www.dhl.com/cn-zh/home/tracking.html?tracking-id=\(encoded)")
            case .amazon:
                return URL(string: "https://www.amazon.com/progress-tracker/package/?trackingId=\(encoded)")
            case .unknown:
                return URL(string: "https://www.kuaidi100.com/chaxun?nu=\(encoded)")
            }
        }
    }
}

final class SmartInboxMonitor: ObservableObject {
    static let shared = SmartInboxMonitor()

    @Published private(set) var latestOTP: OTPEvent?
    @Published private(set) var activeParcels: [ParcelShipment] = []

    private let lock = NSLock()
    private let storageURL: URL
    private let maxStoredHashes = 500
    private var consumedHashes: [String] = []
    private var consumedHashSet: Set<String> = []

    init(storageURL: URL? = nil) {
        if let storageURL {
            self.storageURL = storageURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.storageURL = appSupport
                .appendingPathComponent("StarIsland", isDirectory: true)
                .appendingPathComponent("consumed_otp_hashes.json", isDirectory: false)
        }
        loadConsumedHashes()
    }

    func presentOTP(code: String, source: String, title: String, body: String) {
        let normalized = Self.normalize(code)
        guard !normalized.isEmpty, !hasConsumedOTP(normalized) else { return }

        let event = OTPEvent(
            id: "otp-\(Self.sha256Hex(for: normalized).prefix(12))-\(Int(Date().timeIntervalSince1970))",
            code: normalized,
            source: source.isEmpty ? "通知" : source,
            title: title.isEmpty ? "验证码" : title,
            body: body,
            date: Date()
        )
        if Thread.isMainThread {
            latestOTP = event
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.latestOTP = event
            }
        }
    }

    func consumeOTP(_ code: String) {
        let normalized = Self.normalize(code)
        guard !normalized.isEmpty else { return }
        let digest = Self.sha256Hex(for: normalized)

        lock.lock()
        if !consumedHashSet.contains(digest) {
            consumedHashSet.insert(digest)
            consumedHashes.append(digest)
            if consumedHashes.count > maxStoredHashes {
                let overflow = consumedHashes.count - maxStoredHashes
                let evicted = consumedHashes.prefix(overflow)
                for old in evicted { consumedHashSet.remove(old) }
                consumedHashes.removeFirst(overflow)
            }
            persistConsumedHashesLocked()
        }
        lock.unlock()
    }

    func hasConsumedOTP(_ code: String) -> Bool {
        let normalized = Self.normalize(code)
        guard !normalized.isEmpty else { return false }
        let digest = Self.sha256Hex(for: normalized)
        lock.lock()
        defer { lock.unlock() }
        return consumedHashSet.contains(digest)
    }

    func dismissOTP() {
        let clearBlock = { [weak self] in
            guard let self else { return }
            if let code = self.latestOTP?.code {
                self.consumeOTP(code)
            }
            self.latestOTP = nil
        }
        if Thread.isMainThread {
            clearBlock()
        } else {
            DispatchQueue.main.async(execute: clearBlock)
        }
    }

    private static func normalize(_ code: String) -> String {
        code.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func sha256Hex(for code: String) -> String {
        let salted = Data(("starisland.otp.v2:" + code).utf8)
        let digest = SHA256.hash(data: salted)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func loadConsumedHashes() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return
        }
        consumedHashes = Array(decoded.suffix(maxStoredHashes))
        consumedHashSet = Set(consumedHashes)
    }

    private func persistConsumedHashesLocked() {
        let dir = storageURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(consumedHashes) {
            try? data.write(to: storageURL, options: .atomic)
        }
    }
}
#endif
