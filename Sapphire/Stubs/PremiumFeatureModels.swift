//
//  PremiumFeatureModels.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2026-09-15

#if !SAPPHIRE_FULL_BUILD
import AppKit
import Combine
import CoreWLAN
import Foundation

enum CaretPositionTracker {
    struct CaretInfo {
        let anchorPoint: NSPoint
        let lineNumber: Int?
        let isExact: Bool
    }

    static func caretInfo() -> CaretInfo? { nil }
    static func anchorPoint() -> NSPoint? { nil }
}

@MainActor
final class WiFiStatusMonitor: ObservableObject {
    struct State: Equatable {
        var isConnected = false
        var networkName: String?
        var isInterfacePowerOn = false
    }

    static let shared = WiFiStatusMonitor()
    @Published private(set) var state = State()
    private var pollTimer: Timer?

    private init() {}

    func startPolling() {
        guard pollTimer == nil else { return }
        refresh()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func refresh(completion: (() -> Void)? = nil) {
        if let iface = CWWiFiClient.shared().interface() {
            let powered = iface.powerOn()
            let ssid = iface.ssid()
            let connected = powered && (ssid != nil || iface.wlanChannel() != nil)
            state = State(isConnected: connected, networkName: ssid, isInterfacePowerOn: powered)
        } else {
            state = State()
        }
        completion?()
    }
}

@MainActor
final class DMGInstallerManager: ObservableObject {
    static let shared = DMGInstallerManager()
    @Published private(set) var currentTransferTask: FileTransferTask?
    @Published private(set) var lastStatusMessage: String = ""

    private init() {}

    func handleOpenURLs(_ urls: [URL]) {
        let dmgURLs = urls.filter { $0.pathExtension.lowercased() == "dmg" }
        guard !dmgURLs.isEmpty else { return }
        Task {
            for url in dmgURLs {
                await installDMG(at: url)
            }
        }
    }

    @discardableResult
    func installDMG(at dmgURL: URL) async -> Bool {
        let trashAfter = SettingsModel.shared.settings.dmgInstallerTrashAfterInstall
        let useUserApps = SettingsModel.shared.settings.dmgInstallerInstallLocation == .homeApplications
        let destDir: URL = useUserApps
            ? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
            : URL(fileURLWithPath: "/Applications", isDirectory: true)

        lastStatusMessage = "正在挂载 \(dmgURL.lastPathComponent)…"
        let installedApp: URL? = await Task.detached(priority: .userInitiated) {
            let attach = Process()
            attach.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
            attach.arguments = ["attach", "-nobrowse", "-readonly", "-plist", dmgURL.path]
            let pipe = Pipe()
            attach.standardInput = FileHandle.nullDevice
            attach.standardOutput = pipe
            attach.standardError = FileHandle.nullDevice
            try? attach.run()
            attach.waitUntilExit()
            guard attach.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                  let entities = plist["system-entities"] as? [[String: Any]] else {
                return nil
            }
            let mountPoint = entities.compactMap { $0["mount-point"] as? String }.first
            guard let mountPoint else { return nil }
            defer {
                let detach = Process()
                detach.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
                detach.arguments = ["detach", mountPoint, "-quiet"]
                detach.standardInput = FileHandle.nullDevice
                try? detach.run()
                detach.waitUntilExit()
            }
            let fm = FileManager.default
            let mountURL = URL(fileURLWithPath: mountPoint, isDirectory: true)
            guard let items = try? fm.contentsOfDirectory(at: mountURL, includingPropertiesForKeys: nil),
                  let appSource = items.first(where: { $0.pathExtension.lowercased() == "app" }) else {
                return nil
            }
            try? fm.createDirectory(at: destDir, withIntermediateDirectories: true)
            let appDest = destDir.appendingPathComponent(appSource.lastPathComponent)
            let stagedURL = destDir.appendingPathComponent(".StarIslandStage-\(UUID().uuidString).app")
            do {
                try fm.copyItem(at: appSource, to: stagedURL)
                if fm.fileExists(atPath: appDest.path) {
                    _ = try fm.replaceItemAt(appDest, withItemAt: stagedURL)
                } else {
                    try fm.moveItem(at: stagedURL, to: appDest)
                }
                return appDest
            } catch {
                try? fm.removeItem(at: stagedURL)
                return nil
            }
        }.value

        if let installedApp {
            if trashAfter {
                NSWorkspace.shared.recycle([dmgURL], completionHandler: nil)
            }
            lastStatusMessage = "已成功安装 \(installedApp.lastPathComponent)"
            if SettingsModel.shared.settings.dmgInstallerPostInstallAction == .open {
                NSWorkspace.shared.open(installedApp)
            } else if SettingsModel.shared.settings.dmgInstallerPostInstallAction == .revealInFinder {
                NSWorkspace.shared.activateFileViewerSelecting([installedApp])
            }
            return true
        } else {
            lastStatusMessage = "安装 \(dmgURL.lastPathComponent) 失败"
            return false
        }
    }

    func reconcileDefaultHandlerIfNeeded() {}

    static func isDefaultDMGHandler() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier,
              let handler = LSCopyDefaultRoleHandlerForContentType("com.apple.disk-image-udif" as CFString, .viewer)?.takeRetainedValue() as String? else {
            return false
        }
        return handler.caseInsensitiveCompare(bundleID) == .orderedSame
    }

    static func setAsDefaultDMGHandler() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        LSSetDefaultRoleHandlerForContentType("com.apple.disk-image-udif" as CFString, .viewer, bundleID as CFString)
    }

    static func shadowingCopy() -> URL? { nil }
}

struct DockLayout: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var name: String = "新建预设"
    var plistDataBase64: String? = nil
    var appCount: Int? = nil
}

struct StorageSpaceMapSnapshot {
    struct Slice: Identifiable, Equatable {
        let id: URL
        let name: String
        let bytes: Int64
        let category: StorageCategory
    }

    var items: [Slice] = []
    var accountedBytes: Int64 = 0
    var usedBytes: Int64 = 0
    var totalBytes: Int64 = 0
    var freeBytes: Int64 = 0
    var usedRatio: Double = 0

    static func make(
        from entries: [StorageEntry],
        maximumItems: Int,
        used: Int64,
        total: Int64,
        deepScanEnabled: Bool,
        entriesSortedBySize: Bool
    ) -> StorageSpaceMapSnapshot {
        let ordered = entriesSortedBySize ? entries : entries.sorted { $0.size > $1.size }
        let cap = max(1, maximumItems)
        let slices = ordered.prefix(cap).map { entry in
            Slice(id: entry.url, name: entry.name, bytes: max(0, entry.size), category: entry.category)
        }
        let accounted = ordered.reduce(Int64(0)) { partial, entry in
            let next = max(0, entry.size)
            let (sum, overflow) = partial.addingReportingOverflow(next)
            return overflow ? Int64.max : sum
        }
        let safeTotal = max(0, total)
        let safeUsed = min(safeTotal > 0 ? safeTotal : max(0, used), max(0, used))
        let free = max(0, safeTotal - safeUsed)
        let ratio = safeTotal > 0 ? min(1.0, max(0.0, Double(safeUsed) / Double(safeTotal))) : 0
        return StorageSpaceMapSnapshot(
            items: slices,
            accountedBytes: accounted,
            usedBytes: safeUsed,
            totalBytes: safeTotal,
            freeBytes: free,
            usedRatio: ratio
        )
    }
}

enum OCRScreenTextSupport {
    struct RecognizedLine: Equatable {
        var text: String
        var boundingBox: CGRect
    }

    private static let significantModifiers: CGEventFlags = [.maskCommand, .maskShift, .maskAlternate, .maskControl]

    static func modifiersMatchExactly(eventFlags: CGEventFlags, required: CGEventFlags) -> Bool {
        eventFlags.intersection(significantModifiers) == required.intersection(significantModifiers)
    }

    static func captureSourceRect(selectionInView: CGRect, displaySize: CGSize, scale: CGFloat) -> CGRect? {
        let bounds = CGRect(origin: .zero, size: displaySize)
        let clipped = selectionInView.standardized.intersection(bounds)
        guard !clipped.isNull, !clipped.isEmpty else { return nil }
        let s = max(scale, 1)
        let minX = floor(clipped.minX * s) / s
        let minY = floor(clipped.minY * s) / s
        let maxX = ceil(clipped.maxX * s) / s
        let maxY = ceil(clipped.maxY * s) / s
        let snapped = CGRect(x: minX, y: minY, width: min(maxX, displaySize.width) - minX, height: min(maxY, displaySize.height) - minY)
        guard snapped.width >= 4, snapped.height >= 4 else { return nil }
        return snapped
    }

    static func capturePixelSize(for rect: CGRect, scale: CGFloat) -> (width: Int, height: Int) {
        let s = max(scale, 1)
        return (Int((rect.width * s).rounded()), Int((rect.height * s).rounded()))
    }

    static func indexOfScreen(containing point: CGPoint, in frames: [CGRect]) -> Int? {
        guard !frames.isEmpty else { return nil }
        if let hit = frames.firstIndex(where: { $0.contains(point) }) {
            return hit
        }
        return 0
    }

    static func recognitionLanguages(preferred: String, supported: [String]) -> [String] {
        let trimmed = preferred.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        if let exact = supported.first(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return [exact]
        }
        let prefix = trimmed.lowercased() + "-"
        return supported.filter { $0.lowercased().hasPrefix(prefix) }
    }

    static func orderedText(_ lines: [RecognizedLine]) -> String {
        let valid = lines.compactMap { line -> RecognizedLine? in
            let t = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : RecognizedLine(text: t, boundingBox: line.boundingBox)
        }
        guard !valid.isEmpty else { return "" }
        let sortedByY = valid.sorted { $0.boundingBox.midY > $1.boundingBox.midY }
        var rows: [[RecognizedLine]] = []
        for line in sortedByY {
            if let lastIdx = rows.indices.last {
                let rowMidY = rows[lastIdx].map(\.boundingBox.midY).reduce(0, +) / CGFloat(rows[lastIdx].count)
                let avgH = rows[lastIdx].map(\.boundingBox.height).reduce(0, +) / CGFloat(rows[lastIdx].count)
                if abs(line.boundingBox.midY - rowMidY) < min(avgH, line.boundingBox.height) * 0.5 {
                    rows[lastIdx].append(line)
                    continue
                }
            }
            rows.append([line])
        }
        return rows.map { row in
            row.sorted { $0.boundingBox.minX < $1.boundingBox.minX }.map(\.text).joined(separator: " ")
        }.joined(separator: "\n")
    }

    static func webURL(fromBarcodePayload payload: String) -> URL? {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: \.isWhitespace) else { return nil }
        guard let components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host, !host.isEmpty else {
            return nil
        }
        return components.url
    }
}

struct SnippetEntry: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var trigger: String = ""
    var replacement: String = ""
    var isEnabled: Bool = true
}

enum EmojiSkinTone: String, Codable, CaseIterable, Identifiable {
    case none, light, mediumLight, medium, mediumDark, dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: "默认"
        case .light: "浅肤色"
        case .mediumLight: "中浅肤色"
        case .medium: "中等肤色"
        case .mediumDark: "中深肤色"
        case .dark: "深肤色"
        }
    }
}

enum MouseButtonAction: String, Codable, CaseIterable, Identifiable {
    case none, back, forward, copy, paste, cut, undo, redo, selectAll
    case missionControl, launchpad, showDesktop, appSwitcher, spotlight
    case closeWindow, minimize, newTab, newWindow, reload, fullScreen
    case lockScreen, openSapphireSettings

    var id: String { rawValue }
}

struct MouseModifierSelection: Codable, Equatable {
    var rawValue: UInt

    init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    init(flags: NSEvent.ModifierFlags) {
        rawValue = flags.intersection([.control, .option, .command, .shift]).rawValue
    }

    var flags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: rawValue)
            .intersection([.control, .option, .command, .shift])
    }

    static let control = MouseModifierSelection(flags: .control)
    static let `default` = MouseModifierSelection(flags: .control)
}

enum SEQuitProtectionMode: String, CaseIterable, Identifiable {
    case hold, doublePress, extraModifier
    var id: String { rawValue }
}

enum SEQuitProtectionExtraModifier: String, CaseIterable, Identifiable {
    case option, control, shift
    var id: String { rawValue }
}

enum SEDockClickAction: String, CaseIterable, Identifiable {
    case minimize, hide, cycle
    var id: String { rawValue }
}

enum SESuperKeyKey: String, CaseIterable, Identifiable {
    case rightCommand, leftCommand, capsLock
    var id: String { rawValue }
}

enum SESuperKeyCombo: String, CaseIterable, Identifiable {
    case hyper
    var id: String { rawValue }
}

enum SESuperKeyTapAction: String, CaseIterable, Identifiable {
    case none
    var id: String { rawValue }
}

enum SEPreviewLayout: String {
    case grid, list, carousel
}

enum SEPreviewTrigger: String {
    case hover, middleClick, modifierClick
}

enum SESwitcherActivation: String {
    case command, option, both
}

extension Settings {
    var systemEnhancePreviewLayout: SEPreviewLayout {
        get { SEPreviewLayout(rawValue: systemEnhancePreviewLayoutRaw) ?? .grid }
        set { systemEnhancePreviewLayoutRaw = newValue.rawValue }
    }

    var systemEnhanceWindowSwitcherLayout: SEPreviewLayout {
        get { SEPreviewLayout(rawValue: systemEnhanceWindowSwitcherLayoutRaw) ?? .grid }
        set { systemEnhanceWindowSwitcherLayoutRaw = newValue.rawValue }
    }

    var systemEnhancePreviewTrigger: SEPreviewTrigger {
        get { SEPreviewTrigger(rawValue: systemEnhancePreviewTriggerRaw) ?? .hover }
        set { systemEnhancePreviewTriggerRaw = newValue.rawValue }
    }

    var systemEnhanceSwitcherActivation: SESwitcherActivation {
        get { SESwitcherActivation(rawValue: systemEnhanceSwitcherActivationRaw) ?? .both }
        set { systemEnhanceSwitcherActivationRaw = newValue.rawValue }
    }

    var systemEnhanceQuitProtectionMode: SEQuitProtectionMode {
        get { SEQuitProtectionMode(rawValue: systemEnhanceQuitProtectionModeRaw) ?? .hold }
        set { systemEnhanceQuitProtectionModeRaw = newValue.rawValue }
    }

    var systemEnhanceQuitProtectionExtraModifier: SEQuitProtectionExtraModifier {
        get { SEQuitProtectionExtraModifier(rawValue: systemEnhanceQuitProtectionExtraModifierRaw) ?? .option }
        set { systemEnhanceQuitProtectionExtraModifierRaw = newValue.rawValue }
    }

    var systemEnhanceDockClickAction: SEDockClickAction {
        get { SEDockClickAction(rawValue: systemEnhanceDockClickActionRaw) ?? .minimize }
        set { systemEnhanceDockClickActionRaw = newValue.rawValue }
    }

    var superKeyKey: SESuperKeyKey {
        get { SESuperKeyKey(rawValue: superKeyKeyRaw) ?? .rightCommand }
        set { superKeyKeyRaw = newValue.rawValue }
    }

    var superKeyCombo: SESuperKeyCombo {
        get { SESuperKeyCombo(rawValue: superKeyComboRaw) ?? .hyper }
        set { superKeyComboRaw = newValue.rawValue }
    }

    var superKeyTapAction: SESuperKeyTapAction {
        get { SESuperKeyTapAction(rawValue: superKeyTapActionRaw) ?? .none }
        set { superKeyTapActionRaw = newValue.rawValue }
    }
}

enum MenuBarRevealConditionKind: String, Codable, CaseIterable, Identifiable {
    case batteryBelow, batteryAbove, charging, onBatteryPower
    case focusActive, focusIdentifier, wifiEquals, wifiConnected
    case scriptSucceeds, scriptFails, scriptExitCode

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .batteryBelow: "电池电量低于"
        case .batteryAbove: "电池电量高于"
        case .charging: "正在充电"
        case .onBatteryPower: "使用电池供电"
        case .focusActive: "任意专注模式已开启"
        case .focusIdentifier: "专注模式为"
        case .wifiEquals: "Wi-Fi 网络为"
        case .wifiConnected: "已连接 Wi-Fi"
        case .scriptSucceeds: "脚本执行成功"
        case .scriptFails: "脚本执行失败"
        case .scriptExitCode: "脚本退出码为"
        }
    }

    var systemImage: String {
        switch self {
        case .batteryBelow, .batteryAbove: "battery.25"
        case .charging: "bolt.fill"
        case .onBatteryPower: "battery.100"
        case .focusActive, .focusIdentifier: "moon.fill"
        case .wifiEquals, .wifiConnected: "wifi"
        case .scriptSucceeds, .scriptFails, .scriptExitCode: "terminal"
        }
    }
}

struct MenuBarRevealCondition: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var kind: MenuBarRevealConditionKind = .batteryBelow
    var batteryThreshold = 20
    var focusIdentifier = ""
    var wifiNetworkName = ""
    var scriptPath = ""
    var scriptArgument = ""
    var scriptExitCode = 0
    var scriptPollInterval: TimeInterval = 30

    init() {}

    init(kind: MenuBarRevealConditionKind) {
        self.kind = kind
    }
}

enum MenuBarProfileDisplayScope: String, Codable, CaseIterable {
    case allDisplays, selectedDisplays
}

struct MenuBarDisplayBinding: Codable, Equatable, Identifiable, Hashable {
    var id: String { displayIdentifier }
    var displayIdentifier: String
    var displayLabel = ""
}

struct MenuBarProfile: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var name = "新建配置"
    var symbolName = "menubar.rectangle"
    var revealConditions: [MenuBarRevealCondition] = []
    var isEnabled = true
    var bindsToDisplays = false
    var displayScope: MenuBarProfileDisplayScope = .selectedDisplays
    var displayBindings: [MenuBarDisplayBinding] = []
    var bindsToSpaces = false
    var spaceNumbers: [Int] = []
    var bindsToFocus = false
    var focusIdentifiers: [String] = []

    init() {}

    init(name: String) {
        self.name = name
    }

    var summaryText: String {
        revealConditions.isEmpty ? "无触发条件" : "\(revealConditions.count) 个条件"
    }
}

final class MenuBarProfileEngine {
    struct FocusModeOption: Identifiable, Sendable {
        let identifier: String
        let name: String
        let symbolName: String

        var id: String { identifier }
    }

    static let shared = MenuBarProfileEngine()

    private(set) var isRevealRequested = false

    private init() {}

    func start() {}
    func stop() {}
    func refresh() {}

    static func fetchAvailableFocusModes() -> [FocusModeOption] { [] }
}

enum QuarantineAttribute {
    nonisolated static func copy(from sources: [URL], to destination: URL, recursively: Bool = false) {}
}

extension Notification.Name {
    static let menuBarProfilesDidChange = Notification.Name("com.sapphire.menuBarProfilesDidChange")
}
#endif