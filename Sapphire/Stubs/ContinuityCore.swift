//
//  ContinuityCore.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2026-09-15

#if !SAPPHIRE_FULL_BUILD
import AppKit
import Combine
import CryptoKit
import SwiftUI
import UserNotifications

enum ContinuityProtocol {
    static let manufacturerID: UInt16 = 0xFFFF
}

enum ContinuityLog {
    static func f(_ message: @autoclosure () -> String) {}
    static func fErr(_ message: @autoclosure () -> String) {}
}

enum ContinuityBluetoothAddress {
    static func normalize(_ address: String?) -> String? {
        guard let address else { return nil }
        let hex = address.uppercased().filter(\.isHexDigit)
        guard hex.count == 12 else {
            let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        var pairs: [String] = []
        var idx = hex.startIndex
        for _ in 0..<6 {
            let next = hex.index(idx, offsetBy: 2)
            pairs.append(String(hex[idx..<next]))
            idx = next
        }
        return pairs.joined(separator: ":")
    }

    static func dashed(_ address: String?) -> String? {
        normalize(address)?.replacingOccurrences(of: ":", with: "-")
    }

    static func matches(_ lhs: String?, _ rhs: String?) -> Bool {
        guard let a = normalize(lhs), let b = normalize(rhs) else { return false }
        return a.caseInsensitiveCompare(b) == .orderedSame
    }
}

struct ContinuityAdvertisement: Equatable {
    var peripheralID: UUID
    var handle: Data
    var capabilitiesMask: UInt16
    var batteryPercent: Int
    var isPairing: Bool?

    static func parse(manufacturerData: Data, peripheralID: UUID) -> ContinuityAdvertisement? {
        let bytes = [UInt8](manufacturerData)
        guard bytes.count >= 15 else { return nil }
        let company = UInt16(bytes[0]) | (UInt16(bytes[1]) << 8)
        guard company == ContinuityProtocol.manufacturerID else { return nil }
        let handle = Data(bytes[4..<12])
        let caps = UInt16(bytes[12]) | (UInt16(bytes[13]) << 8)
        let battery = Int(bytes[14])
        let isPairing: Bool? = bytes.count >= 16 ? ((bytes[15] & 0x01) != 0) : nil
        return ContinuityAdvertisement(
            peripheralID: peripheralID,
            handle: handle,
            capabilitiesMask: caps,
            batteryPercent: battery,
            isPairing: isPairing
        )
    }

    func matches(pairedPeer: ContinuityPairedPeer) -> Bool {
        let expected = Data(SHA256.hash(data: Data(pairedPeer.id.utf8)).prefix(8))
        return handle == expected
    }
}

enum ContinuityDeviceType: String, Codable, Sendable {
    case phone, tablet, mac, unknown

    var glyph: String {
        switch self {
        case .phone: "iphone"
        case .tablet: "ipad"
        case .mac: "macbook"
        case .unknown: "questionmark.circle"
        }
    }
}

enum ContinuityCapability: String, Codable, CaseIterable, Sendable {
    case clipboard, notifications, media, status, hotspot, files, handoff
    case mirroring, camera, sidecar, universalControl, sms, scan, sketch
    case audioCast, widgets, externalActivities, microphone
}

enum ContinuityLinkState: String, Equatable {
    case offline, nearby, connected, online

    var isUsable: Bool { self == .connected || self == .online }
}

enum ContinuityNetworkKind: String, Codable {
    case wifi, cellular, none
}

struct ContinuityConnectivitySnapshot: Equatable {
    enum Severity: Equatable {
        case noDevice, healthy, degraded, offline

        var tint: Color {
            switch self {
            case .noDevice: .secondary
            case .healthy: .green
            case .degraded: .orange
            case .offline: .red
            }
        }
    }

    var severity: Severity = .noDevice
    var deviceName = ""
    var linkState: ContinuityLinkState = .offline
    var headline = ""
    var detail = ""
    var suggestion: String?
    var bluetoothWarning: String?
    var linkError: String?
    var phoneBatteryPercent: Int?
    var phoneCharging = false
    var phoneNetwork: ContinuityNetworkKind?
    var phoneSSID: String?
    var phoneSignalLevel: Int = 0
    var phoneCarrier: String?
    var rssi: Int?
    var isRelayed = false

    var hasDevice: Bool { severity != .noDevice }
    var isIssue: Bool { severity == .degraded || severity == .offline }

    static let none = ContinuityConnectivitySnapshot()
}

struct ContinuityPairedPeer: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var deviceType: ContinuityDeviceType
    var publicKeyBase64: String = ""
    var linkKeyBase64: String = ""
    var addedAt: Date = Date()
    var lastSeenAt: Date? = nil
}

@MainActor
@Observable
final class ContinuityPeer: Identifiable {
    nonisolated let record: ContinuityPairedPeer
    nonisolated var id: String { record.id }
    var linkState: ContinuityLinkState = .offline
    var capabilities: Set<ContinuityCapability> = []

    init(record: ContinuityPairedPeer) {
        self.record = record
    }

    var displayName: String { record.name }
    func supports(_ capability: ContinuityCapability) -> Bool { capabilities.contains(capability) }
    func send<T: Encodable>(_ kind: ContinuityWireKind, _ payload: T) {}
}

enum ContinuityWireKind: String {
    case earbudCommand, earbudStatus
}

struct ContinuityEarbudCommand: Codable, Equatable {
    var action: String
    var stringValue: String? = nil
    var intValue: Int? = nil
    var boolValue: Bool? = nil
}

struct ContinuityEarbudStatus: Codable, Equatable {
    var vendor: String
    var name: String
    var address: String?
    var connected: Bool
    var ownedLocally: Bool
    var noiseMode: String
    var ancHigh: Bool
    var eqPreset: String
    var batteryLeft: Int
    var batteryRight: Int
    var batteryCase: Int
    var batteryMain: Int
    var dsee: Bool
    var seamless: Bool
    var detectConversations: Bool
    var ambientLevel: Int
    var supportsANC: Bool
    var supportsAdaptive: Bool
    var supportsEQ: Bool
    var supportsDSEE: Bool
    var supportsSeamless: Bool
    var supportsFind: Bool
    var supportsCustomEQ: Bool
    var customEQBands: [Int]
    var gamingMode: Bool
    var spatialAudio: Bool
    var touchpadLocked: Bool
    var touchLeft: Int
    var touchRight: Int
    var speakSeamlessly: Bool
    var ancOneEarbud: Bool
    var autoSwitchAudio: Bool
    var pauseOnOneBudRemoved: Bool
    var sidetone: Bool
    var extraHighAmbient: Bool
    var amplifyAmbient: Bool
    var inBandRingtone: Bool
    var callPathControl: Bool
    var ambientDuringCall: Bool
    var detectConversationsDuration: Int
    var outsideDoubleTap: Bool
    var muteLeft: Bool
    var muteRight: Bool
    var wearingLeft: Bool
    var wearingRight: Bool
    var fitTesting: Bool
    var fitLeftGood: Bool
    var fitRightGood: Bool
    var supportsGaming: Bool
    var supportsSpatial: Bool
    var supportsTouchLock: Bool
    var supportsFitTest: Bool
    var supportsAmbientExtras: Bool
    var supportsCallExtras: Bool
    var supportsDetectConversations: Bool
    var supportsExtraClearCall: Bool
    var supportsPassthrough: Bool
    var supportsOutsideDoubleTap: Bool
    var extraClearCall: Bool
    var passthrough: Bool
}

@MainActor
final class ContinuityFocusModeStub {
    var isApplyingRemoteFocus: Bool { false }
}

struct ContinuityMediaState: Codable, Equatable {
    var sessionId: String
    var appId: String
    var appName: String
    var title: String
    var artist: String?
    var album: String?
    var isPlaying: Bool
    var positionMs: Int
    var durationMs: Int
    var canNext: Bool
    var canPrev: Bool
    var canSeek: Bool
    var artwork: String?

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        appId = try values.decodeIfPresent(String.self, forKey: .appId) ?? ""
        sessionId = try values.decodeIfPresent(String.self, forKey: .sessionId) ?? appId
        appName = try values.decodeIfPresent(String.self, forKey: .appName) ?? appId
        title = try values.decodeIfPresent(String.self, forKey: .title) ?? ""
        artist = try values.decodeIfPresent(String.self, forKey: .artist)
        album = try values.decodeIfPresent(String.self, forKey: .album)
        isPlaying = try values.decodeIfPresent(Bool.self, forKey: .isPlaying) ?? false
        positionMs = try values.decodeIfPresent(Int.self, forKey: .positionMs) ?? 0
        durationMs = try values.decodeIfPresent(Int.self, forKey: .durationMs) ?? 0
        canNext = try values.decodeIfPresent(Bool.self, forKey: .canNext) ?? false
        canPrev = try values.decodeIfPresent(Bool.self, forKey: .canPrev) ?? false
        canSeek = try values.decodeIfPresent(Bool.self, forKey: .canSeek) ?? false
        artwork = try values.decodeIfPresent(String.self, forKey: .artwork)
    }
}

enum ContinuityMediaAction: String, Codable {
    case play, pause, toggle, next, previous, seek, stop
}

enum ContinuityActivitySlotKind: String, Codable {
    case icon, text, progress, timer, image, none
}

struct ContinuityActivitySlot: Codable, Equatable {
    var kind: ContinuityActivitySlotKind
    var text: String?
    var glyph: String?
    var imageDigest: String?
    var tintHex: String?
    var progress: Double?
}

struct ContinuityActivityProgress: Codable, Equatable {
    var current: Int
    var max: Int
    var indeterminate: Bool
}

struct ContinuityExternalActivity: Codable, Equatable, Identifiable {
    var key: String
    var appId: String
    var appName: String
    var title: String
    var text: String?
    var shortText: String?
    var left: ContinuityActivitySlot
    var right: ContinuityActivitySlot
    var progress: ContinuityActivityProgress?

    var id: String { key }
}

struct ContinuityLiveExternalActivity: Identifiable, Equatable {
    var activity: ContinuityExternalActivity
    var peerID: String
    var peerName: String
    var appIcon: NSImage?
    var leftImage: NSImage?
    var rightImage: NSImage?
    var expandedImage: NSImage?
    var lastUpdated: Date

    var id: String { activity.key }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.activity == rhs.activity }
}

struct ContinuityMirroredNotification: Identifiable, Equatable {
    var id: String
}

@MainActor
final class ContinuityNotificationBridge: ObservableObject {
    @Published private(set) var latest: ContinuityMirroredNotification?
    func clearLatest() { latest = nil }
}

@MainActor
final class ContinuityExternalActivityBridge: ObservableObject {
    @Published private(set) var featured: ContinuityLiveExternalActivity?
}

@MainActor
final class ContinuityMediaBridge: ObservableObject {
    @Published private(set) var phoneMedia: ContinuityMediaState?
    @Published private(set) var phoneArtwork: NSImage?
    @Published private(set) var phoneDeviceName: String?
    var shouldSurfacePhoneMedia: Bool { false }
}

final class ContinuityHandoffBridge {
    static let openActionID = "CONTINUITY_OPEN"
    func handleBannerTap() {}
}

final class ContinuityNotificationResponseBridgeStub {
    func handleNotificationResponse(_ response: UNNotificationResponse) {}
}

@MainActor
@Observable
final class ContinuityManager {
    static let shared = ContinuityManager()

    private(set) var peers: [ContinuityPeer] = []
    private(set) var connectivity: ContinuityConnectivitySnapshot = .none
    var connectedPeer: ContinuityPeer? { peers.first(where: { $0.linkState.isUsable }) }
    var activePeerID: String? { connectedPeer?.id }

    let notificationBridge = ContinuityNotificationBridge()
    let liveActivityBridge = ContinuityExternalActivityBridge()
    let mediaBridge = ContinuityMediaBridge()
    let handoffBridge = ContinuityHandoffBridge()
    let messagesBridge = ContinuityNotificationResponseBridgeStub()
    let callsBridge = ContinuityNotificationResponseBridgeStub()
    let focusModeManager = ContinuityFocusModeStub()

    private init() {
        StarIslandLANPortalServer.shared.onStateChanged = { [weak self] in
            self?.syncFromPortal()
        }
    }

    func startIfEnabled() {
        guard SettingsModel.shared.settings.continuityEnabled else {
            stop()
            return
        }
        if !StarIslandLANPortalServer.shared.isRunning {
            StarIslandLANPortalServer.shared.start()
        }
        syncFromPortal()
    }

    func stop() {
        if StarIslandLANPortalServer.shared.isRunning {
            StarIslandLANPortalServer.shared.stop()
        }
        peers = []
        connectivity = .none
    }

    private func syncFromPortal() {
        let portal = StarIslandLANPortalServer.shared
        let sessions = portal.connectedSessions
        peers = sessions.map { s in
            let peer = ContinuityPeer(record: ContinuityPairedPeer(id: s.id, name: s.deviceName, deviceType: .phone, addedAt: s.pairedAt, lastSeenAt: s.pairedAt))
            peer.linkState = .connected
            peer.capabilities = [.clipboard, .files, .media]
            return peer
        }
        if let first = sessions.first {
            connectivity = ContinuityConnectivitySnapshot(
                severity: .healthy,
                deviceName: first.deviceName,
                linkState: .connected,
                headline: "\(first.deviceName) 已连接",
                detail: "\(portal.localIPAddress):\(portal.listeningPort)"
            )
        } else if portal.isRunning {
            connectivity = ContinuityConnectivitySnapshot(
                severity: .noDevice,
                deviceName: "",
                linkState: .nearby,
                headline: "等待扫码配对",
                detail: "PIN \(portal.currentPIN)"
            )
        } else {
            connectivity = .none
        }
    }

    func openWidgets(focus: Int? = nil) {}
    func sendMediaCommand(_ action: ContinuityMediaAction, seekMs: Int? = nil) {}

    func sendFiles(_ urls: [URL], toPeerID peerID: String) {
        StarIslandLANPortalServer.shared.addSharedFiles(urls)
        startIfEnabled()
    }

    func dismissNotificationOnPhone(peerID: String, key: String) {}
    func invokeNotificationAction(peerID: String, key: String, actionId: String, replyText: String?) {}
    func takePhoto() {}
    func scanDocument() {}
    func setActivePeer(id: String) {}

    func unpair(peerID: String) {
        StarIslandLANPortalServer.shared.refreshPIN()
        syncFromPortal()
    }
}

@MainActor
final class ContinuityServicesProvider: NSObject {
    static let shared = ContinuityServicesProvider()
    func install() {}
}

struct ContinuityNotchDetailView: View {
    @Binding var navigationStack: [NotchWidgetMode]
    @ObservedObject private var portal = StarIslandLANPortalServer.shared

    var body: some View {
        HStack(spacing: 16) {
            if let qr = portal.qrCodeImage {
                Image(nsImage: qr)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 96, height: 96)
                    .padding(6)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("星岛跨端快传", systemImage: "iphone.radiowaves.left.and.right")
                        .font(.system(size: 13, weight: .bold))
                    Spacer()
                    if !navigationStack.isEmpty {
                        Button("返回") { _ = navigationStack.popLast() }
                            .buttonStyle(.borderless)
                            .font(.system(size: 11))
                    }
                }

                HStack(spacing: 8) {
                    Text("6 位安全码：")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text(portal.currentPIN)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(.cyan)
                    Button {
                        portal.refreshPIN()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.borderless)
                }

                Text(portal.isRunning ? portal.statusMessage : "点击启用局域网免装 App 扫码互传")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Button(portal.isRunning ? "刷新服务" : "启动服务") {
                        SettingsModel.shared.settings.continuityEnabled = true
                        ContinuityManager.shared.startIfEnabled()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button("添加共享文件…") {
                        let panel = NSOpenPanel()
                        panel.allowsMultipleSelection = true
                        if panel.runModal() == .OK {
                            portal.addSharedFiles(panel.urls)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(12)
        .onAppear {
            if SettingsModel.shared.settings.continuityEnabled && !portal.isRunning {
                portal.start()
            }
        }
    }
}

struct ContinuityExternalActivityDetailView: View {
    let bridge: ContinuityExternalActivityBridge
    var body: some View { EmptyView() }
}

enum ContinuityNotchActivityView {
    @ViewBuilder static func left(for snapshot: ContinuityConnectivitySnapshot) -> some View {
        Image(systemName: "iphone.radiowaves.left.and.right")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(snapshot.severity.tint)
    }

    @ViewBuilder static func right(for snapshot: ContinuityConnectivitySnapshot) -> some View {
        Text(snapshot.deviceName.isEmpty ? "互联" : snapshot.deviceName)
            .font(.system(size: 11, weight: .medium))
            .lineLimit(1)
    }
}

enum ContinuityExternalActivityView {
    @ViewBuilder static func left(for activity: ContinuityLiveExternalActivity) -> some View { EmptyView() }
    @ViewBuilder static func right(for activity: ContinuityLiveExternalActivity) -> some View { EmptyView() }
}

enum ContinuityMediaActivityView {
    @ViewBuilder static func left(state: ContinuityMediaState, artwork: NSImage?) -> some View { EmptyView() }
    @ViewBuilder static func right(state: ContinuityMediaState, deviceName: String) -> some View { EmptyView() }
}

struct ContinuityNotificationActivityView: View {
    let entry: ContinuityMirroredNotification
    let bridge: ContinuityNotificationBridge
    @Binding var isHovered: Bool
    var body: some View { EmptyView() }
}

extension Notification.Name {
    static let continuityClipboardReceived = Notification.Name("com.shariq.sapphire.continuity.clipboardReceived")
}
#endif