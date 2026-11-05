import AppKit
import ApplicationServices
import AVFoundation
import Combine
import CoreBluetooth
import CoreLocation
import dnssd
import EventKit
import Foundation
import Network
import UserNotifications

public enum PermissionKind: String, CaseIterable, Identifiable, Sendable {
    case accessibility
    case screenRecording
    case localNetwork
    case automation
    case notifications
    case location
    case calendar
    case reminders
    case bluetooth
    case camera
    case fullDiskAccess

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .accessibility: return "辅助功能"
        case .screenRecording: return "屏幕录制"
        case .localNetwork: return "本地网络"
        case .automation: return "自动化"
        case .notifications: return "通知"
        case .location: return "定位服务"
        case .calendar: return "日历"
        case .reminders: return "提醒事项"
        case .bluetooth: return "蓝牙"
        case .camera: return "摄像头"
        case .fullDiskAccess: return "完全磁盘访问权限"
        }
    }

    public var summary: String {
        switch self {
        case .accessibility: return "用于窗口磁吸分屏、系统 HUD 媒体键拦截与键鼠效率增强。"
        case .screenRecording: return "用于离线 OCR 框选、圈选搜索及 Dock 悬停实时窗口预览。"
        case .localNetwork: return "用于局域网手机扫码双向快传、剪贴板互联与隔空播放发现。"
        case .automation: return "用于静默联动 Apple Music、Spotify、终端与系统事件。"
        case .notifications: return "用于显示完成提醒、护眼提示与实时活动通知。"
        case .location: return "用于根据当前位置自动更新本地实时天气。"
        case .calendar: return "用于在灵动岛展示即将开始的日程与会议倒计时。"
        case .reminders: return "用于在灵动岛看板查看并勾选待办提醒事项。"
        case .bluetooth: return "用于读取已连接蓝牙耳机与外设的电池状态。"
        case .camera: return "用于展开灵动岛内的高清随身镜预览。"
        case .fullDiskAccess: return "用于扫描本地通知验证码与更完整的应用卸载残留清理。"
        }
    }

    public var iconSymbol: String {
        switch self {
        case .accessibility: return "figure.wave.circle.fill"
        case .screenRecording: return "menubar.dock.rectangle.badge.record"
        case .localNetwork: return "network"
        case .automation: return "gearshape.2.fill"
        case .notifications: return "bell.badge.fill"
        case .location: return "location.fill"
        case .calendar: return "calendar"
        case .reminders: return "checklist"
        case .bluetooth: return "airpodspro"
        case .camera: return "camera.fill"
        case .fullDiskAccess: return "externaldrive.fill.badge.checkmark"
        }
    }

    public var settingsDeepLink: String {
        switch self {
        case .accessibility: return "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .screenRecording: return "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        case .localNetwork: return "x-apple.systempreferences:com.apple.preference.security?Privacy_LocalNetwork"
        case .automation: return "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
        case .notifications: return "x-apple.systempreferences:com.apple.Notifications-Settings.extension"
        case .location: return "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices"
        case .calendar: return "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"
        case .reminders: return "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders"
        case .bluetooth: return "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth"
        case .camera: return "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera"
        case .fullDiskAccess: return "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        }
    }
}

public enum PermissionGrantState: String, Codable, Equatable, Sendable {
    case granted
    case denied
    case notDetermined
}

public enum LocalNetworkErrorPolicy {
    public static let bonjourServiceType = "_starisland._tcp"

    public static func isPolicyDenied(dnsErrorCode: Int32) -> Bool {
        dnsErrorCode == Int32(kDNSServiceErr_PolicyDenied)
    }

    public static func isDeniedError(_ error: NWError) -> Bool {
        if case .dns(let code) = error {
            return isPolicyDenied(dnsErrorCode: Int32(code))
        }
        return false
    }
}

@MainActor
public final class PermissionsCenter: NSObject, ObservableObject {
    public static let shared = PermissionsCenter()

    @Published public private(set) var states: [PermissionKind: PermissionGrantState] = {
        var initial: [PermissionKind: PermissionGrantState] = [:]
        for kind in PermissionKind.allCases {
            initial[kind] = .notDetermined
        }
        return initial
    }()

    @Published public private(set) var isProbingLocalNetwork = false
    @Published public private(set) var isRequestingAutomation = false

    private let localNetworkKey = "starisland.localNetwork.state.v1"
    private let queue = DispatchQueue(label: "com.adgry.starisland.permissions", qos: .userInitiated)
    private var browser: NWBrowser?
    private var listener: NWListener?
    private var udpTrigger: NWConnection?

    public override init() {
        super.init()
        if let raw = UserDefaults.standard.string(forKey: localNetworkKey),
           let saved = PermissionGrantState(rawValue: raw) {
            states[.localNetwork] = saved
        }
    }

    public func status(for kind: PermissionKind) -> PermissionGrantState {
        states[kind] ?? .notDetermined
    }

    public func refreshAll() {
        states[.accessibility] = AXIsProcessTrusted() ? .granted : .notDetermined
        states[.screenRecording] = CGPreflightScreenCaptureAccess() ? .granted : .notDetermined

        let tccPath = "/Library/Application Support/com.apple.TCC/TCC.db"
        states[.fullDiskAccess] = FileManager.default.isReadableFile(atPath: tccPath) ? .granted : .notDetermined

        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .writeOnly: states[.calendar] = .granted
        case .denied, .restricted: states[.calendar] = .denied
        default: states[.calendar] = .notDetermined
        }

        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .fullAccess, .writeOnly: states[.reminders] = .granted
        case .denied, .restricted: states[.reminders] = .denied
        default: states[.reminders] = .notDetermined
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: states[.camera] = .granted
        case .denied, .restricted: states[.camera] = .denied
        default: states[.camera] = .notDetermined
        }

        switch CBManager.authorization {
        case .allowedAlways: states[.bluetooth] = .granted
        case .denied, .restricted: states[.bluetooth] = .denied
        default: states[.bluetooth] = .notDetermined
        }

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let mapped: PermissionGrantState
            switch settings.authorizationStatus {
            case .authorized, .provisional: mapped = .granted
            case .denied: mapped = .denied
            default: mapped = .notDetermined
            }
            Task { @MainActor in
                self.states[.notifications] = mapped
            }
        }
    }

    public func openSystemSettings(for kind: PermissionKind) {
        if let url = URL(string: kind.settingsDeepLink) {
            NSWorkspace.shared.open(url)
        }
    }

    public func request(_ kind: PermissionKind) {
        switch kind {
        case .accessibility:
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
            refreshAll()
        case .screenRecording:
            _ = CGRequestScreenCaptureAccess()
            refreshAll()
        case .localNetwork:
            retryLocalNetworkProbe()
        case .automation:
            Task { await requestAutomationSafely() }
        case .notifications:
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
                Task { @MainActor in self.refreshAll() }
            }
        case .calendar:
            Task {
                _ = try? await EKEventStore().requestFullAccessToEvents()
                refreshAll()
            }
        case .reminders:
            Task {
                _ = try? await EKEventStore().requestFullAccessToReminders()
                refreshAll()
            }
        case .camera:
            AVCaptureDevice.requestAccess(for: .video) { _ in
                Task { @MainActor in self.refreshAll() }
            }
        case .location, .bluetooth, .fullDiskAccess:
            openSystemSettings(for: kind)
        }
    }

    public func retryLocalNetworkProbe() {
        cleanupLocalNetworkProbe()
        UserDefaults.standard.removeObject(forKey: localNetworkKey)
        states[.localNetwork] = .notDetermined
        isProbingLocalNetwork = true

        // Outbound UDP multicast triggers macOS NECP local network dialog & registers app in System Settings
        let udp = NWConnection(host: NWEndpoint.Host("224.0.0.251"), port: NWEndpoint.Port(rawValue: 9)!, using: .udp)
        udp.stateUpdateHandler = { state in
            if case .ready = state {
                udp.send(content: Data([0]), completion: .contentProcessed { _ in udp.cancel() })
            }
        }
        udpTrigger = udp
        udp.start(queue: queue)

        let serviceName = "StarIsland-\(UUID().uuidString.prefix(6))"
        if let nwListener = try? NWListener(using: .tcp) {
            nwListener.service = NWListener.Service(name: serviceName, type: LocalNetworkErrorPolicy.bonjourServiceType)
            nwListener.newConnectionHandler = { $0.cancel() }
            listener = nwListener
            nwListener.start(queue: queue)
        }

        let nwBrowser = NWBrowser(for: .bonjour(type: LocalNetworkErrorPolicy.bonjourServiceType, domain: nil), using: NWParameters())
        nwBrowser.stateUpdateHandler = { [weak self] state in
            switch state {
            case .waiting(let err), .failed(let err):
                guard LocalNetworkErrorPolicy.isDeniedError(err) else { return }
                Task { @MainActor in
                    self?.completeLocalNetworkProbe(.denied)
                }
            default:
                break
            }
        }
        nwBrowser.browseResultsChangedHandler = { [weak self] results, _ in
            guard !results.isEmpty else { return }
            Task { @MainActor in
                self?.completeLocalNetworkProbe(.granted)
            }
        }
        browser = nwBrowser
        nwBrowser.start(queue: queue)

        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 12_000_000_000)
            guard let self, self.isProbingLocalNetwork else { return }
            self.isProbingLocalNetwork = false
            self.cleanupLocalNetworkProbe()
        }
    }

    private func completeLocalNetworkProbe(_ result: PermissionGrantState) {
        isProbingLocalNetwork = false
        states[.localNetwork] = result
        UserDefaults.standard.set(result.rawValue, forKey: localNetworkKey)
        cleanupLocalNetworkProbe()
    }

    private func cleanupLocalNetworkProbe() {
        udpTrigger?.cancel()
        udpTrigger = nil
        browser?.cancel()
        browser = nil
        listener?.cancel()
        listener = nil
    }

    private func requestAutomationSafely() async {
        guard !isRequestingAutomation else { return }
        isRequestingAutomation = true
        defer { isRequestingAutomation = false }

        let targetIDs = ["com.apple.systemevents", "com.apple.Music", "com.spotify.client"]
        var results: [PermissionGrantState] = []

        for bundleID in targetIDs {
            guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
                continue
            }
            if NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty {
                let config = NSWorkspace.OpenConfiguration()
                config.activates = false
                config.addsToRecentItems = false
                config.promptsUserIfNeeded = false
                let launched = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                    NSWorkspace.shared.openApplication(at: appURL, configuration: config) { app, _ in
                        cont.resume(returning: app != nil)
                    }
                }
                guard launched else { continue }
            }

            let status = await Task.detached(priority: .userInitiated) { () -> OSStatus in
                let desc = NSAppleEventDescriptor(bundleIdentifier: bundleID)
                guard let ae = desc.aeDesc else { return OSStatus(paramErr) }
                return AEDeterminePermissionToAutomateTarget(ae, AEEventClass(typeWildCard), AEEventID(typeWildCard), true)
            }.value

            if status == noErr {
                results.append(.granted)
            } else if status == OSStatus(errAEEventNotPermitted) {
                results.append(.denied)
            }
        }

        if results.contains(.denied) {
            states[.automation] = .denied
        } else if !results.isEmpty && results.allSatisfy({ $0 == .granted }) {
            states[.automation] = .granted
        } else {
            states[.automation] = .notDetermined
        }
    }
}
