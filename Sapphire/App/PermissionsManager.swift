//
//  PermissionsManager.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2025-07-10.
//

import SwiftUI
import Combine
import CoreLocation
import EventKit
import AVFoundation
import UserNotifications
import ScreenCaptureKit
import CoreBluetooth
import Intents
import ApplicationServices
import AppKit
import CoreServices
import Network
import dnssd

// MARK: - Permission Enums
enum PermissionType: Identifiable, CaseIterable {
    case accessibility, notifications, location, calendar, reminders, bluetooth, focusStatus, fullDiskAccess, screenRecording, localNetwork, automation
    var id: Self { self }
}

enum PermissionStatus: String, CaseIterable {
    case granted, denied, notRequested
}

enum PermissionCategory: String, CaseIterable {
    case required = "Required"
    case recommended = "Recommended"
    case optional = "Optional"

    var displayName: String {
        switch self {
        case .required: return "必需权限"
        case .recommended: return "推荐权限"
        case .optional: return "可选权限"
        }
    }
}

struct PermissionItem: Identifiable {
    let id = UUID()
    let type: PermissionType, title: String, description: String, iconName: String
    let iconColor: Color
    let category: PermissionCategory
}

// MARK: - PermissionsManager
@MainActor
class PermissionsManager: NSObject, ObservableObject, @MainActor CLLocationManagerDelegate, @MainActor CBCentralManagerDelegate {
    static let shared = PermissionsManager()

    @Published var accessibilityStatus: PermissionStatus = .notRequested
    @Published var notificationsStatus: PermissionStatus = .notRequested
    @Published var locationStatus: PermissionStatus = .notRequested
    @Published var calendarStatus: PermissionStatus = .notRequested
    @Published var remindersStatus: PermissionStatus = .notRequested
    @Published var bluetoothStatus: PermissionStatus = .notRequested
    @Published var focusStatusStatus: PermissionStatus = .notRequested
    @Published var fullDiskAccessStatus: PermissionStatus = .notRequested
    @Published var screenRecordingStatus: PermissionStatus = .notRequested
    @Published var localNetworkStatus: PermissionStatus = .notRequested
    @Published var automationStatus: PermissionStatus = .notRequested
    @Published private(set) var isProbingLocalNetwork = false
    @Published private(set) var isRequestingAutomation = false

    private var locationManager: CLLocationManager?
    private lazy var bluetoothManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: 0])

    private let automationPermissionRequestedKey = "automationPermissionRequested"
    private let automationActiveTargetIDsKey = "automationActiveTargetIDs"

    private struct AutomationTarget {
        let name: String
        let bundleIdentifier: String
    }

    private let automationTargets = [
        AutomationTarget(name: "Music", bundleIdentifier: "com.apple.Music"),
        AutomationTarget(name: "Spotify", bundleIdentifier: "com.spotify.client"),
        AutomationTarget(name: "System Events", bundleIdentifier: "com.apple.systemevents"),
    ]

    private var localNetworkProbe: LocalNetworkAccessProbe?
    private let localNetworkStatusKey = "localNetworkPermissionStatus.v3"
    private let localNetworkRequestedKey = "localNetworkPermissionRequested"
    private let screenRecordingRequestedAtKey = "screenRecordingRequestedAt"

    private static let automationRecheckInterval: TimeInterval = 120
    private var lastAutomationCheck = Date.distantPast
    private var automationCheckInFlight = false
    private var installedAutomationTargetIDs: Set<String>?
    private var unlaunchableAutomationTargetIDs = Set<String>()

    private var cancellables = Set<AnyCancellable>()

    public let allPermissions: [PermissionItem] = [
        .init(type: .accessibility, title: "辅助功能", description: "用于响应媒体按键、窗口磁吸分区以及显示 HUD 浮层。", iconName: "figure.wave.circle.fill", iconColor: .purple, category: .required),
        .init(type: .fullDiskAccess, title: "完全磁盘访问权限", description: "启用文件暂存架、智能助手文件访问及更深度的系统集成。", iconName: "folder.badge.gearshape", iconColor: .gray, category: .recommended),
        .init(type: .screenRecording, title: "屏幕录制", description: "用于 Gemini Live 屏幕共享、按应用音频采集、实时窗口预览以及合盖角度桌面动画。", iconName: "record.circle", iconColor: .orange, category: .recommended),
        .init(type: .localNetwork, title: "本地网络", description: "用于发现并控制局域网内受支持的媒体播放器。", iconName: "network", iconColor: .cyan, category: .recommended),
        .init(type: .automation, title: "自动化", description: "用于控制 Spotify、Apple Music 及隔空播放系统事件。", iconName: "play.display", iconColor: .green, category: .recommended),
        .init(type: .notifications, title: "通知", description: "用于显示消息和系统事件的自定义提醒。", iconName: "bell.badge.fill", iconColor: .red, category: .recommended),
        .init(type: .location, title: "定位服务", description: "用于为当前所在位置提供实时天气更新。", iconName: "location.fill", iconColor: .blue, category: .recommended),
        .init(type: .calendar, title: "日历", description: "用于显示即将到来的日程事项。", iconName: "calendar", iconColor: .red, category: .recommended),
        .init(type: .bluetooth, title: "蓝牙", description: "用于检测已连接的蓝牙设备及其电池电量。", iconName: "ipad.landscape.and.iphone", iconColor: .blue, category: .recommended),
        .init(type: .reminders, title: "提醒事项", description: "用于显示即将到期的提醒事项。", iconName: "checklist", iconColor: .orange, category: .optional),
        .init(type: .focusStatus, title: "专注状态", description: "用于显示专注模式的开启状态。", iconName: "moon.fill", iconColor: .indigo, category: .optional)
    ]

    var requiredPermissions: [PermissionItem] { allPermissions.filter { $0.category == .required } }
    var recommendedPermissions: [PermissionItem] { allPermissions.filter { $0.category == .recommended } }
    var optionalPermissions: [PermissionItem] { allPermissions.filter { $0.category == .optional } }

    var areAllRequiredPermissionsGranted: Bool {
        requiredPermissions.allSatisfy { status(for: $0.type) == PermissionStatus.granted }
    }

    func arePermissionsGranted(for types: [PermissionType]) -> Bool {
        types.allSatisfy { status(for: $0) == PermissionStatus.granted }
    }

    func missingPermissions(in types: [PermissionType]) -> [PermissionItem] {
        allPermissions.filter { types.contains($0.type) && status(for: $0.type) != PermissionStatus.granted }
    }

    func permissionItems(for types: [PermissionType]) -> [PermissionItem] {
        types.compactMap { type in allPermissions.first(where: { $0.type == type }) }
    }

    var areIntelligencePermissionsGranted: Bool {
        arePermissionsGranted(for: SettingsSection.intelligence.requiredPermissions)
    }

    private override init() {
        super.init()
        self.locationManager = CLLocationManager()
        self.locationManager?.delegate = self
        checkAllPermissions()

        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                self.refreshLightweightStatuses()
                let now = Date()
                if self.automationStatus != .granted || now.timeIntervalSince(self.lastAutomationCheck) >= Self.automationRecheckInterval {
                    self.checkAutomationStatus()
                }
                if self.localNetworkProbeRequested, self.localNetworkStatus != .granted {
                    self.probeLocalNetwork(triggeredByUser: false)
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: AccessibilityTrustMonitor.trustDidChange)
            .sink { [weak self] _ in
                self?.checkAccessibilityStatus()
            }
            .store(in: &cancellables)
    }

    private func assign(_ keyPath: ReferenceWritableKeyPath<PermissionsManager, PermissionStatus>, _ value: PermissionStatus) {
        if self[keyPath: keyPath] != value { self[keyPath: keyPath] = value }
    }

    func refreshLightweightStatuses() {
        checkAccessibilityStatus()
        checkFullDiskAccessStatus()
        checkScreenRecordingStatus()
    }

    private func checkAccessibilityStatus() {
        let isTrusted = AccessibilityTrustMonitor.shared.isTrusted
        assign(\.accessibilityStatus, isTrusted ? .granted : .notRequested)
    }

    private func checkFullDiskAccessStatus() {
        if let preflight = Self.tccPreflight {
            let result = preflight(Self.serviceSystemPolicyAllFiles, nil)
            switch result {
            case 0: assign(\.fullDiskAccessStatus, .granted)
            case 1: assign(\.fullDiskAccessStatus, .denied)
            default: assign(\.fullDiskAccessStatus, .notRequested)
            }
        } else {
            let testUrl = URL(fileURLWithPath: "/Library/Application Support/com.apple.TCC/TCC.db")
            let canAccess = FileManager.default.isReadableFile(atPath: testUrl.path)
            assign(\.fullDiskAccessStatus, canAccess ? .granted : .notRequested)
        }
    }

    private func checkScreenRecordingStatus() {
        let defaults = UserDefaults.standard
        var requestedAt = defaults.object(forKey: screenRecordingRequestedAtKey) as? Date
        if requestedAt == nil, defaults.bool(forKey: "screenRecordingRequested") {
            requestedAt = .distantPast
        }
        assign(\.screenRecordingStatus, ScreenRecordingStatusPolicy.status(
            preflightGranted: CGPreflightScreenCaptureAccess(),
            requestedAt: requestedAt,
            now: Date()
        ))
    }

    func checkAllPermissions() {
        checkAccessibilityStatus()
        checkFullDiskAccessStatus()
        checkScreenRecordingStatus()
        checkLocalNetworkStatus()
        checkAutomationStatus()

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let status: PermissionStatus
            switch settings.authorizationStatus {
            case .authorized, .provisional: status = .granted
            case .denied: status = .denied
            case .notDetermined: status = .notRequested
            @unknown default: status = .notRequested
            }
            DispatchQueue.main.async {
                self.assign(\.notificationsStatus, status)
            }
        }

        updateLocationStatus(for: locationManager?.authorizationStatus ?? .notDetermined)

        let calStatus = EKEventStore.authorizationStatus(for: .event)
        switch calStatus {
        case .fullAccess, .writeOnly: assign(\.calendarStatus, .granted)
        case .denied, .restricted: assign(\.calendarStatus, .denied)
        case .notDetermined: assign(\.calendarStatus, .notRequested)
        @unknown default: assign(\.calendarStatus, .notRequested)
        }

        let remStatus = EKEventStore.authorizationStatus(for: .reminder)
        switch remStatus {
        case .fullAccess, .writeOnly: assign(\.remindersStatus, .granted)
        case .denied, .restricted: assign(\.remindersStatus, .denied)
        case .notDetermined: assign(\.remindersStatus, .notRequested)
        @unknown default: assign(\.remindersStatus, .notRequested)
        }

        updateBluetoothStatus(for: CBManager.authorization)

        let focusAuthStatus = INFocusStatusCenter.default.authorizationStatus
        switch focusAuthStatus {
        case .authorized: assign(\.focusStatusStatus, .granted)
        case .denied, .restricted: assign(\.focusStatusStatus, .denied)
        case .notDetermined: assign(\.focusStatusStatus, .notRequested)
        @unknown default: assign(\.focusStatusStatus, .notRequested)
        }
    }

    func status(for type: PermissionType) -> PermissionStatus {
        switch type {
        case .accessibility: return accessibilityStatus
        case .notifications: return notificationsStatus
        case .location: return locationStatus
        case .calendar: return calendarStatus
        case .reminders: return remindersStatus
        case .bluetooth: return bluetoothStatus
        case .focusStatus: return focusStatusStatus
        case .fullDiskAccess: return fullDiskAccessStatus
        case .screenRecording: return screenRecordingStatus
        case .localNetwork: return localNetworkStatus
        case .automation: return automationStatus
        }
    }

    func openSystemSettings(for type: PermissionType) {
        switch type {
        case .accessibility: SystemPreferencesPane.accessibility.open()
        case .fullDiskAccess: SystemPreferencesPane.allFiles.open()
        case .screenRecording: SystemPreferencesPane.screenCapture.open()
        case .localNetwork: SystemPreferencesPane.localNetwork.open()
        case .automation: SystemPreferencesPane.automation.open()
        case .bluetooth: SystemPreferencesPane.bluetooth.open()
        case .calendar: SystemPreferencesPane.calendars.open()
        case .reminders: SystemPreferencesPane.reminders.open()
        case .location: SystemPreferencesPane.locationServices.open()
        case .notifications: SystemPreferencesPane.notifications.open()
        case .focusStatus: SystemPreferencesPane.privacyRoot.open()
        }
    }

    func requestPermission(_ type: PermissionType) {
        switch type {
        case .accessibility:
            AccessibilityPermission.request()

        case .fullDiskAccess:
            requestFullDiskAccessPrePopulation()
            openFullDiskAccessSettings()

        case .screenRecording:
            if screenRecordingStatus == .denied {
                openSystemSettings(for: .screenRecording)
            } else {
                UserDefaults.standard.set(Date(), forKey: screenRecordingRequestedAtKey)
                UserDefaults.standard.set(true, forKey: "screenRecordingRequested")
                CGRequestScreenCaptureAccess()
                checkScreenRecordingStatus()
            }

        case .automation:
            if automationStatus == .denied {
                openSystemSettings(for: .automation)
            } else {
                triggerAutomationPermissionRequest()
            }

        case .localNetwork:
            if localNetworkStatus == .denied {
                openSystemSettings(for: .localNetwork)
                probeLocalNetwork(triggeredByUser: false)
            } else {
                probeLocalNetwork(triggeredByUser: true)
            }

        case .notifications:
            if notificationsStatus == .denied {
                openSystemSettings(for: .notifications)
            } else {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in
                    DispatchQueue.main.async { self.checkAllPermissions() }
                }
            }

        case .location:
            if locationStatus == .denied {
                openSystemSettings(for: .location)
            } else {
                locationManager?.requestWhenInUseAuthorization()
            }

        case .calendar:
            if calendarStatus == .denied {
                openSystemSettings(for: .calendar)
            } else {
                Task {
                    do { _ = try await EKEventStore().requestFullAccessToEvents() } catch {}
                    await MainActor.run { self.checkAllPermissions() }
                }
            }

        case .reminders:
            if remindersStatus == .denied {
                openSystemSettings(for: .reminders)
            } else {
                Task {
                    do { _ = try await EKEventStore().requestFullAccessToReminders() } catch {}
                    await MainActor.run { self.checkAllPermissions() }
                }
            }

        case .bluetooth:
            if CBManager.authorization == .denied {
                SystemPreferencesPane.bluetooth.open()
            } else {
                bluetoothManager.scanForPeripherals(withServices: nil, options: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.bluetoothManager.stopScan()
                }
            }

        case .focusStatus:
            if focusStatusStatus == .denied {
                openSystemSettings(for: .focusStatus)
            } else {
                INFocusStatusCenter.default.requestAuthorization { _ in
                    DispatchQueue.main.async { self.checkAllPermissions() }
                }
            }
        }
    }

    // MARK: - Automation Logic

    private func checkAutomationStatus() {
        lastAutomationCheck = Date()
        guard UserDefaults.standard.bool(forKey: automationPermissionRequestedKey) else {
            assign(\.automationStatus, .notRequested)
            return
        }
        guard !automationCheckInFlight else { return }
        automationCheckInFlight = true

        let targets = automationTargets
        let unlaunchableIDs = unlaunchableAutomationTargetIDs
        let persistedActiveIDs = Set(UserDefaults.standard.stringArray(forKey: automationActiveTargetIDsKey) ?? [])
        Task {
            defer { automationCheckInFlight = false }
            if installedAutomationTargetIDs == nil {
                let ids = await Task.detached(priority: .utility) {
                    Set(targets.map(\.bundleIdentifier).filter {
                        NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil
                    })
                }.value
                installedAutomationTargetIDs = ids
            }
            let runningIDs = Set(targets.map(\.bundleIdentifier).filter {
                !NSRunningApplication.runningApplications(withBundleIdentifier: $0).isEmpty
            })
            let candidateIDs: Set<String>
            if !persistedActiveIDs.isEmpty {
                candidateIDs = persistedActiveIDs.union(runningIDs).subtracting(unlaunchableIDs)
            } else {
                candidateIDs = (installedAutomationTargetIDs ?? []).subtracting(unlaunchableIDs)
            }
            let evaluableTargets = targets.filter { candidateIDs.contains($0.bundleIdentifier) }

            var statuses: [PermissionStatus] = []
            for target in evaluableTargets {
                statuses.append(await getAutomationPermissionStatus(for: target))
            }

            assign(\.automationStatus, AutomationStatusPolicy.aggregateStatus(statuses: statuses))
        }
    }

    private func triggerAutomationPermissionRequest() {
        guard !isRequestingAutomation else { return }
        isRequestingAutomation = true

        Task(priority: .userInitiated) {
            defer { self.isRequestingAutomation = false }
            var activeTargetIDs = Set<String>()

            for target in automationTargets {
                guard await launchAutomationTarget(target) else {
                    self.unlaunchableAutomationTargetIDs.insert(target.bundleIdentifier)
                    continue
                }
                self.unlaunchableAutomationTargetIDs.remove(target.bundleIdentifier)
                activeTargetIDs.insert(target.bundleIdentifier)

                print("[PermissionsManager] Requesting Automation permission for \(target.name)...")
                let status = await Self.determineAutomationPermission(
                    for: target.bundleIdentifier,
                    askUserIfNeeded: true
                )
                print("[PermissionsManager] Automation request for \(target.name) returned \(status).")
                if let mapped = AutomationStatusPolicy.permissionStatus(from: status) {
                    let cacheKey = "automationPermissionStatus.\(target.bundleIdentifier)"
                    UserDefaults.standard.set(mapped.rawValue, forKey: cacheKey)
                }
            }

            guard !activeTargetIDs.isEmpty else {
                self.openSystemSettings(for: .automation)
                return
            }
            UserDefaults.standard.set(true, forKey: automationPermissionRequestedKey)
            UserDefaults.standard.set(Array(activeTargetIDs), forKey: automationActiveTargetIDsKey)
            self.installedAutomationTargetIDs = nil

            self.checkAutomationStatus()
        }
    }

    nonisolated static func shouldAutoLaunchForAutomation(bundleIdentifier: String) -> Bool {
        bundleIdentifier == "com.apple.systemevents"
    }

    private func launchAutomationTarget(_ target: AutomationTarget) async -> Bool {
        if !NSRunningApplication.runningApplications(withBundleIdentifier: target.bundleIdentifier).isEmpty {
            return true
        }

        // 绝不强行拉起未运行的音乐或第三方播放器（避免在受限系统上弹出“应用程序“音乐.app”已不能再打开”报错）
        guard Self.shouldAutoLaunchForAutomation(bundleIdentifier: target.bundleIdentifier) else {
            return false
        }

        guard let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: target.bundleIdentifier) else {
            print("[PermissionsManager] Application '\(target.name)' not found.")
            return false
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.addsToRecentItems = false
        configuration.promptsUserIfNeeded = false

        return await withCheckedContinuation { continuation in
            NSWorkspace.shared.openApplication(at: applicationURL, configuration: configuration) { application, error in
                if let error {
                    print("[PermissionsManager] Could not launch \(target.name) for Automation permission: \(error.localizedDescription)")
                }
                continuation.resume(returning: application != nil)
            }
        }
    }

    private nonisolated static func determineAutomationPermission(
        for bundleIdentifier: String,
        askUserIfNeeded: Bool
    ) async -> OSStatus {
        await Task.detached(priority: .userInitiated) {
            let target = NSAppleEventDescriptor(bundleIdentifier: bundleIdentifier)
            guard let descriptor = target.aeDesc else { return OSStatus(paramErr) }

            return AEDeterminePermissionToAutomateTarget(
                descriptor,
                AEEventClass(typeWildCard),
                AEEventID(typeWildCard),
                askUserIfNeeded
            )
        }.value
    }

    private func getAutomationPermissionStatus(for target: AutomationTarget) async -> PermissionStatus {
        let cacheKey = "automationPermissionStatus.\(target.bundleIdentifier)"
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: target.bundleIdentifier).isEmpty else {
            return UserDefaults.standard.string(forKey: cacheKey).flatMap(PermissionStatus.init(rawValue:)) ?? .notRequested
        }
        let rawStatus = await Self.determineAutomationPermission(for: target.bundleIdentifier, askUserIfNeeded: false)
        if let status = AutomationStatusPolicy.permissionStatus(from: rawStatus) {
            UserDefaults.standard.set(status.rawValue, forKey: cacheKey)
            return status
        }
        return UserDefaults.standard.string(forKey: cacheKey).flatMap(PermissionStatus.init(rawValue:)) ?? .notRequested
    }

    // MARK: - Full Disk Access

    private func requestFullDiskAccessPrePopulation() {
        guard let request = Self.tccRequest else { return }
        request(Self.serviceSystemPolicyAllFiles, nil) { _ in }
    }

    private func openFullDiskAccessSettings() {
        SystemPreferencesPane.allFiles.open()
    }

    // MARK: - TCC Private SPI (dynamic loading)

    private typealias TCCPreflightFunc = @convention(c) (CFString, CFDictionary?) -> Int
    private typealias TCCRequestFunc = @convention(c) (CFString, CFDictionary?, @escaping (Bool) -> Void) -> Void

    private static let tccHandle: UnsafeMutableRawPointer? = {
        dlopen("/System/Library/PrivateFrameworks/TCC.framework/Versions/A/TCC", RTLD_NOW)
    }()

    private static let tccPreflight: TCCPreflightFunc? = {
        guard let handle = tccHandle,
              let sym = dlsym(handle, "TCCAccessPreflight") else { return nil }
        return unsafeBitCast(sym, to: TCCPreflightFunc.self)
    }()

    private static let tccRequest: TCCRequestFunc? = {
        guard let handle = tccHandle,
              let sym = dlsym(handle, "TCCAccessRequest") else { return nil }
        return unsafeBitCast(sym, to: TCCRequestFunc.self)
    }()

    private static let serviceSystemPolicyAllFiles = "kTCCServiceSystemPolicyAllFiles" as CFString

    // MARK: - Local Network Logic

    private func checkLocalNetworkStatus() {
        let stored = UserDefaults.standard.string(forKey: localNetworkStatusKey).flatMap(PermissionStatus.init(rawValue:))
        assign(\.localNetworkStatus, stored ?? .notRequested)
    }

    private var localNetworkProbeRequested: Bool {
        UserDefaults.standard.bool(forKey: localNetworkRequestedKey)
    }

    private func probeLocalNetwork(triggeredByUser: Bool) {
        let wasPreviouslyRequested = UserDefaults.standard.bool(forKey: localNetworkRequestedKey)
        if triggeredByUser {
            UserDefaults.standard.set(true, forKey: localNetworkRequestedKey)
            if wasPreviouslyRequested {
                openSystemSettings(for: .localNetwork)
            }
        }
        guard localNetworkProbe == nil else { return }
        if triggeredByUser { isProbingLocalNetwork = true }
        let startedAt = Date()
        let probe = LocalNetworkAccessProbe(triggeredByUser: triggeredByUser) { [weak self] result in
            guard let self else { return }
            self.localNetworkProbe = nil
            self.isProbingLocalNetwork = false
            switch result {
            case .granted:
                self.updateLocalNetworkStatus(.granted)
            case .denied:
                self.updateLocalNetworkStatus(.denied)
                if triggeredByUser && (wasPreviouslyRequested || Date().timeIntervalSince(startedAt) < 3.5) {
                    self.openSystemSettings(for: .localNetwork)
                }
            case .undetermined:
                if triggeredByUser {
                    self.openSystemSettings(for: .localNetwork)
                }
            }
        }
        localNetworkProbe = probe
        probe.start()
    }

    func retryLocalNetworkPermission() {
        localNetworkProbe?.cancel()
        localNetworkProbe = nil
        isProbingLocalNetwork = false
        UserDefaults.standard.removeObject(forKey: localNetworkStatusKey)
        assign(\.localNetworkStatus, .notRequested)
        probeLocalNetwork(triggeredByUser: true)
    }

    private func updateLocalNetworkStatus(_ newStatus: PermissionStatus) {
        assign(\.localNetworkStatus, newStatus)
        UserDefaults.standard.set(newStatus.rawValue, forKey: localNetworkStatusKey)
    }

    // MARK: - CLLocationManagerDelegate
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let wasGranted = locationStatus == PermissionStatus.granted
        updateLocationStatus(for: manager.authorizationStatus)
        if locationStatus == PermissionStatus.granted && !wasGranted {
            WeatherViewModel.shared.fetch()
        }
    }

private func updateLocationStatus(for status: CLAuthorizationStatus) {
        switch status {
        case .authorized, .authorizedAlways, .authorizedWhenInUse: assign(\.locationStatus, .granted)
        case .denied, .restricted: assign(\.locationStatus, .denied)
        case .notDetermined: assign(\.locationStatus, .notRequested)
        @unknown default: assign(\.locationStatus, .notRequested)
        }
    }

    // MARK: - CBCentralManagerDelegate
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        self.updateBluetoothStatus(for: CBManager.authorization)
    }

    private func updateBluetoothStatus(for authorization: CBManagerAuthorization) {
        switch authorization {
        case .allowedAlways: assign(\.bluetoothStatus, .granted)
        case .denied, .restricted: assign(\.bluetoothStatus, .denied)
        case .notDetermined: assign(\.bluetoothStatus, .notRequested)
        @unknown default: assign(\.bluetoothStatus, .notRequested)
        }
    }
}
// MARK: - Screen Recording status

enum ScreenRecordingStatusPolicy {
    static let answerGracePeriod: TimeInterval = 120

    static func status(preflightGranted: Bool, requestedAt: Date?, now: Date) -> PermissionStatus {
        if preflightGranted { return .granted }
        guard let requestedAt else { return .notRequested }
        return now.timeIntervalSince(requestedAt) < answerGracePeriod ? .notRequested : .denied
    }
}

// MARK: - Automation status

enum AutomationStatusPolicy {
    nonisolated static func permissionStatus(from status: OSStatus) -> PermissionStatus? {
        switch status {
        case noErr: return .granted
        case OSStatus(errAEEventNotPermitted): return .denied
        case OSStatus(errAEEventWouldRequireUserConsent): return .notRequested
        default: return nil
        }
    }

    nonisolated static func aggregateStatus(statuses: [PermissionStatus]) -> PermissionStatus {
        if statuses.contains(.denied) {
            return .denied
        }
        if !statuses.isEmpty && statuses.allSatisfy({ $0 == .granted }) {
            return .granted
        }
        return .notRequested
    }
}

// MARK: - Local Network probe

@MainActor
final class LocalNetworkAccessProbe {
    enum Result { case granted, denied, undetermined }

    nonisolated static let bonjourServiceType = "_starisland._tcp"
    private static let userTimeout: TimeInterval = 5
    private static let backgroundTimeout: TimeInterval = 4

    private let triggeredByUser: Bool
    private let completion: @MainActor (Result) -> Void
    private let serviceName = "SapphireLNP-\(UUID().uuidString.prefix(8))"
    private let queue = DispatchQueue(label: "com.sapphire.local-network-probe", qos: .userInitiated)
    private var listener: NWListener?
    private var browser: NWBrowser?
    private var udpTrigger: NWConnection?
    private var timeoutWork: DispatchWorkItem?
    private var postActivationWork: DispatchWorkItem?
    private var activeObserver: NSObjectProtocol?
    private var startedAt = Date.distantPast
    private var sawPolicyDenied = false
    private var isFinished = false

    init(triggeredByUser: Bool = false, completion: @escaping @MainActor (Result) -> Void) {
        self.triggeredByUser = triggeredByUser
        self.completion = completion
    }

    func start() {
        startedAt = Date()
        if triggeredByUser {
            startUDPTrigger()
        }
        startListener()

        let name = serviceName
        let browser = NWBrowser(for: .bonjour(type: Self.bonjourServiceType, domain: nil), using: NWParameters())
        browser.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                DispatchQueue.main.async {
                    guard let self, !self.isFinished else { return }
                    if self.sawPolicyDenied {
                        self.restartListener()
                    }
                }
            case .waiting(let error):
                guard Self.isDeniedError(error) else { return }
                DispatchQueue.main.async {
                    self?.handleDeniedSignal()
                }
            case .failed(let error):
                let isDenied = Self.isDeniedError(error)
                DispatchQueue.main.async {
                    guard let self else { return }
                    if isDenied {
                        self.handleDeniedSignal()
                    } else {
                        self.finish(.undetermined)
                    }
                }
            default:
                break
            }
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard !results.isEmpty else { return }
            let sawSelf = results.contains { result in
                if case .service(let found, _, _, _) = result.endpoint { return found == name }
                return false
            }
            guard sawSelf || !results.isEmpty else { return }
            DispatchQueue.main.async { self?.finish(.granted) }
        }
        self.browser = browser
        browser.start(queue: queue)

        if triggeredByUser {
            activeObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, !self.isFinished else { return }
                    guard Date().timeIntervalSince(self.startedAt) >= 0.4 else { return }
                    self.postActivationWork?.cancel()
                    let check = DispatchWorkItem { [weak self] in
                        guard let self, !self.isFinished else { return }
                        if self.sawPolicyDenied {
                            self.finish(.denied)
                        }
                    }
                    self.postActivationWork = check
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9, execute: check)
                }
            }
        }

        let timeoutInterval = triggeredByUser ? Self.userTimeout : Self.backgroundTimeout
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.finish(self.sawPolicyDenied ? .denied : .undetermined)
        }
        timeoutWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + timeoutInterval, execute: work)
    }

    func cancel() {
        guard !isFinished else { return }
        isFinished = true
        cleanupResources()
    }

    private func startUDPTrigger() {
        let connection = NWConnection(
            host: NWEndpoint.Host("224.0.0.251"),
            port: NWEndpoint.Port(rawValue: 9)!,
            using: .udp
        )
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard case .ready = state, let connection else { return }
            connection.send(content: Data([0]), completion: .contentProcessed { _ in
                connection.cancel()
                DispatchQueue.main.async {
                    if self?.udpTrigger === connection {
                        self?.udpTrigger = nil
                    }
                }
            })
        }
        udpTrigger = connection
        connection.start(queue: queue)
    }

    private func startListener() {
        do {
            let listener = try NWListener(using: .tcp)
            listener.service = NWListener.Service(name: serviceName, type: Self.bonjourServiceType)
            listener.newConnectionHandler = { $0.cancel() }
            self.listener = listener
            listener.start(queue: queue)
        } catch {
            print("[LocalNetworkAccessProbe] Listener creation failed: \(error.localizedDescription)")
        }
    }

    private func restartListener() {
        listener?.cancel()
        listener = nil
        startListener()
    }

    private func handleDeniedSignal() {
        guard !isFinished else { return }
        sawPolicyDenied = true
        if !triggeredByUser {
            let work = DispatchWorkItem { [weak self] in
                guard let self, !self.isFinished else { return }
                self.finish(.denied)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
        }
    }

    nonisolated static func isDeniedError(_ error: NWError) -> Bool {
        if case .dns(let code) = error {
            return code == DNSServiceErrorType(kDNSServiceErr_PolicyDenied)
        }
        return false
    }

    private func cleanupResources() {
        if let activeObserver {
            NotificationCenter.default.removeObserver(activeObserver)
            self.activeObserver = nil
        }
        postActivationWork?.cancel()
        postActivationWork = nil
        timeoutWork?.cancel()
        timeoutWork = nil
        udpTrigger?.cancel()
        udpTrigger = nil
        browser?.cancel()
        browser = nil
        listener?.cancel()
        listener = nil
    }

    private func finish(_ result: Result) {
        guard !isFinished else { return }
        isFinished = true
        cleanupResources()
        completion(result)
    }
}