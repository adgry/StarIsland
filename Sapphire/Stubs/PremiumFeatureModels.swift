//
//  PremiumFeatureModels.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2026-09-15

#if !SAPPHIRE_FULL_BUILD
import AppKit
import Combine
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

    private init() {}
    func startPolling() {}
    func stopPolling() {}
    func refresh(completion: (() -> Void)? = nil) { completion?() }
}

@MainActor
final class DMGInstallerManager: ObservableObject {
    static let shared = DMGInstallerManager()
    @Published private(set) var currentTransferTask: FileTransferTask?

    private init() {}
    func handleOpenURLs(_ urls: [URL]) {}
    func reconcileDefaultHandlerIfNeeded() {}
    static func isDefaultDMGHandler() -> Bool { false }
    static func setAsDefaultDMGHandler() {}
    static func shadowingCopy() -> URL? { nil }
}

struct DockLayout: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var name: String = "新建预设"
}

struct StorageSpaceMapSnapshot {
    static func make(
        from entries: [StorageEntry],
        maximumItems: Int,
        used: Int64,
        total: Int64,
        deepScanEnabled: Bool,
        entriesSortedBySize: Bool
    ) -> StorageSpaceMapSnapshot {
        StorageSpaceMapSnapshot()
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