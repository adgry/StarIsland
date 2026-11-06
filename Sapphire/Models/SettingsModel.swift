//
//  SettingsModel.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2025-11-22

import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers

extension UTType {
    static let sapphireSettingsBackup = UTType(exportedAs: "com.cshariq.sapphire.settings-backup")
}

public struct StatThreshold: Codable, Equatable {
    var isEnabled: Bool = false
    var value: Int = 80
}

public struct NotchSizeOverride: Codable, Equatable {
    var width: CGFloat = 0
    var height: CGFloat = 0
}

struct FloatingIslandStyle: Codable, Equatable {
    static let sidePaddingRange: ClosedRange<CGFloat> = 0...30
    static let centerGapRange: ClosedRange<CGFloat> = 0...160
    static let openCornerRadiusRange: ClosedRange<CGFloat> = 12...60
    static let openPaddingRange: ClosedRange<CGFloat> = 0...60
    static let openTopPaddingRange: ClosedRange<CGFloat> = 0...30

    var sidePadding: CGFloat = 9
    var centerGap: CGFloat = 56
    var openCornerRadius: CGFloat = 36
    var openPadding: CGFloat = 14
    var openTopPadding: CGFloat = 8

    static let legacyDefault: FloatingIslandStyle = {
        var style = FloatingIslandStyle()
        style.sidePadding = 10
        style.centerGap = 40
        style.openCornerRadius = 38
        style.openPadding = 6
        style.openTopPadding = 8
        return style
    }()
    static let legacyTopOffset: CGFloat = 8

    static let previousDefaults: [FloatingIslandStyle] = [
        legacyDefault,
        {
            var style = FloatingIslandStyle()
            style.sidePadding = 10
            style.centerGap = 40
            style.openCornerRadius = 32
            style.openPadding = 12
            style.openTopPadding = 8
            return style
        }(),
        {
            var style = FloatingIslandStyle()
            style.sidePadding = 9
            style.centerGap = 56
            style.openCornerRadius = 40
            style.openPadding = 16
            style.openTopPadding = 8
            return style
        }(),
        {
            var style = FloatingIslandStyle()
            style.sidePadding = 9
            style.centerGap = 56
            style.openCornerRadius = 40
            style.openPadding = 24
            style.openTopPadding = 8
            return style
        }(),
        {
            var style = FloatingIslandStyle()
            style.sidePadding = 9
            style.centerGap = 56
            style.openCornerRadius = 36
            style.openPadding = 8
            style.openTopPadding = 8
            return style
        }(),
    ]

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = FloatingIslandStyle()
        sidePadding = try container.decodeIfPresent(CGFloat.self, forKey: .sidePadding) ?? defaults.sidePadding
        centerGap = try container.decodeIfPresent(CGFloat.self, forKey: .centerGap) ?? defaults.centerGap
        openCornerRadius = try container.decodeIfPresent(CGFloat.self, forKey: .openCornerRadius) ?? defaults.openCornerRadius
        openPadding = try container.decodeIfPresent(CGFloat.self, forKey: .openPadding) ?? defaults.openPadding
        openTopPadding = try container.decodeIfPresent(CGFloat.self, forKey: .openTopPadding) ?? defaults.openTopPadding
    }
}

enum FullScreenActivityVisibility: String, Codable, CaseIterable, Identifiable {
    case showAll
    case hidePersistent
    case hideSelected
    case hideAll

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .showAll: "全部显示"
        case .hidePersistent: "隐藏常驻活动"
        case .hideSelected: "隐藏所选活动"
        case .hideAll: "全部隐藏"
        }
    }

    var detail: String {
        switch self {
        case .showAll: "全屏时继续显示所有实时活动。"
        case .hidePersistent: "隐藏音乐、计时器和常驻状态等长时间运行的活动；HUD、通知和大写锁定等短暂事件仍会显示。"
        case .hideSelected: "仅隐藏你手动勾选的活动。"
        case .hideAll: "隐藏所有内容，包括音量和亮度 HUD 等基础提示。"
        }
    }
}

struct FullScreenBehavior: Codable, Equatable {
    var activityVisibility: FullScreenActivityVisibility = .showAll
    var hideNotch: Bool = false
    var hideLyrics: Bool = true

    init(activityVisibility: FullScreenActivityVisibility = .showAll, hideNotch: Bool = false, hideLyrics: Bool = true) {
        self.activityVisibility = activityVisibility
        self.hideNotch = hideNotch
        self.hideLyrics = hideLyrics
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = FullScreenBehavior()
        activityVisibility = try container.decodeIfPresent(FullScreenActivityVisibility.self, forKey: .activityVisibility) ?? defaults.activityVisibility
        hideNotch = try container.decodeIfPresent(Bool.self, forKey: .hideNotch) ?? defaults.hideNotch
        hideLyrics = try container.decodeIfPresent(Bool.self, forKey: .hideLyrics) ?? defaults.hideLyrics
    }
}

public enum StatType: String, Codable, CaseIterable, Identifiable {
    case cpu, ram, gpu, disk, systemPower, batteryPower

    public var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .cpu: return "CPU 使用率"
        case .ram: return "内存使用率"
        case .gpu: return "GPU 使用率"
        case .disk: return "磁盘活动"
        case .systemPower: return "系统功耗"
        case .batteryPower: return "电池功耗"
        }
    }

    var systemImage: String {
        switch self {
        case .cpu: return "cpu"
        case .ram: return "memorychip"
        case .gpu: return "tv"
        case .disk: return "internaldrive"
        case .systemPower: return "bolt.fill"
        case .batteryPower: return "battery.75"
        }
    }
}

// MARK: - Animation Configuration
enum AnimationProfile: String, Codable, CaseIterable, Identifiable {
    case snappy, fluid, bouncy, calm, custom
    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .snappy: "利落"
        case .fluid: "流畅"
        case .bouncy: "弹性"
        case .calm: "舒缓"
        case .custom: "自定义"
        }
    }
}

enum WidgetSwitchEffect: String, Codable, CaseIterable, Identifiable {
    case smooth, bouncy
    var id: String { self.rawValue }
    var displayName: String {
        switch self {
        case .smooth: "平滑"
        case .bouncy: "弹性"
        }
    }
}

enum WidgetSwitchTransition: String, Codable, CaseIterable, Identifiable {
    case slide, fade, blurAndFade
    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .slide: "滑动"
        case .fade: "淡入淡出"
        case .blurAndFade: "模糊与淡出"
        }
    }
}

struct CustomizableAnimationConfiguration: Codable, Equatable {
    var expandResponse: Double = 0.45
    var expandDamping: Double = 0.68
    var swipeOpenResponse: Double = 0.5
    var swipeOpenDamping: Double = 0.85
    var collapseResponse: Double = 0.3
    var collapseDamping: Double = 0.98

    var hoverResponse: Double = 0.38
    var hoverDamping: Double = 0.96
    var autoExpandResponse: Double = 0.42
    var autoExpandDamping: Double = 0.92

    var contentTransitionResponse: Double = 0.35
    var contentTransitionDamping: Double = 0.9
    var activityToActivityResponse: Double = 0.4
    var activityToActivityDamping: Double = 0.98
    var activityMorphResponse: Double = 0.5
    var activityMorphDamping: Double = 0.88

    var bottomContentResponse: Double = 0.42
    var bottomContentDamping: Double = 0.999
    var heightIncreaseResponse: Double = 0.38
    var heightIncreaseDamping: Double = 0.995
    var heightDecreaseResponse: Double = 0.36
    var heightDecreaseDamping: Double = 0.999
    var largeMenuResponse: Double = 0.5
    var largeMenuDamping: Double = 0.97
}

enum ReleaseChannel: String, Codable, CaseIterable {
    case stable
    case beta
}

// MARK: - Customizable Configuration
struct CustomizableNotchConfiguration: Codable, Equatable {
    var universalWidth: CGFloat = 195
    var universalHeight: CGFloat = 32
    var initialCornerRadius: CGFloat = 10
    var topBuffer: CGFloat = 0

    var scaleFactor: CGFloat = 1.10
    var hoverExpandedCornerRadius: CGFloat = 18

    var autoExpandedCornerRadius: CGFloat = 13
    var autoExpandedTallHeight: CGFloat = 80
    var autoExpandedContentVerticalPadding: CGFloat = 8

    var clickExpandedCornerRadius: CGFloat = 40
    var liveActivityBottomCornerRadius: CGFloat = 20

    var collapseAnimationDelay: TimeInterval = 0.07
    var dragActivationCollapseDelay: TimeInterval = 0.1

    var expandAnimationResponse: Double = 0.45
    var expandAnimationDamping: Double = 0.68
    var swipeOpenAnimationResponse: Double = 0.5
    var swipeOpenAnimationDamping: Double = 0.85
    var collapseAnimationResponse: Double = 0.3
    var collapseAnimationDamping: Double = 0.98

    var widgetBlurRadiusMax: CGFloat = 30
    var activityBlurRadiusMax: CGFloat = 40
    var expandedShadowRadius: CGFloat = 18
    var expandedShadowOffsetY: CGFloat = 8

    var contentTopPadding: CGFloat = 10
    var contentBottomPadding: CGFloat = 10
    var contentHorizontalPadding: CGFloat = 35

    static func == (lhs: CustomizableNotchConfiguration, rhs: CustomizableNotchConfiguration) -> Bool {
        return lhs.universalWidth == rhs.universalWidth &&
               lhs.universalHeight == rhs.universalHeight &&
               lhs.initialCornerRadius == rhs.initialCornerRadius &&
               lhs.topBuffer == rhs.topBuffer &&
               lhs.scaleFactor == rhs.scaleFactor &&
               lhs.hoverExpandedCornerRadius == rhs.hoverExpandedCornerRadius &&
               lhs.autoExpandedCornerRadius == rhs.autoExpandedCornerRadius &&
               lhs.autoExpandedTallHeight == rhs.autoExpandedTallHeight &&
               lhs.autoExpandedContentVerticalPadding == rhs.autoExpandedContentVerticalPadding &&
               lhs.clickExpandedCornerRadius == rhs.clickExpandedCornerRadius &&
               lhs.liveActivityBottomCornerRadius == rhs.liveActivityBottomCornerRadius &&
               lhs.collapseAnimationDelay == rhs.collapseAnimationDelay &&
               lhs.dragActivationCollapseDelay == rhs.dragActivationCollapseDelay &&
               lhs.expandAnimationResponse == rhs.expandAnimationResponse &&
               lhs.expandAnimationDamping == rhs.expandAnimationDamping &&
               lhs.swipeOpenAnimationResponse == rhs.swipeOpenAnimationResponse &&
               lhs.swipeOpenAnimationDamping == rhs.swipeOpenAnimationDamping &&
               lhs.collapseAnimationResponse == rhs.collapseAnimationResponse &&
               lhs.collapseAnimationDamping == rhs.collapseAnimationDamping &&
               lhs.widgetBlurRadiusMax == rhs.widgetBlurRadiusMax &&
               lhs.activityBlurRadiusMax == rhs.activityBlurRadiusMax &&
               lhs.expandedShadowRadius == rhs.expandedShadowRadius &&
               lhs.expandedShadowOffsetY == rhs.expandedShadowOffsetY &&
               lhs.contentTopPadding == rhs.contentTopPadding &&
               lhs.contentBottomPadding == rhs.contentBottomPadding &&
               lhs.contentHorizontalPadding == rhs.contentHorizontalPadding
    }
}

enum WeatherInfoType: String, Codable, CaseIterable, Identifiable {
    case temperature, condition, wind, humidity, feelsLike, precipitation, sunrise, sunset, uvIndex, visibility, pressure, locationName, conditionDescription, highLowTemp
    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .temperature: "当前温度"
        case .condition: "天气图标"
        case .wind: "风速"
        case .humidity: "湿度"
        case .feelsLike: "体感温度"
        case .precipitation: "降水概率"
        case .sunrise: "日出时间"
        case .sunset: "日落时间"
        case .uvIndex: "紫外线指数"
        case .visibility: "能见度"
        case .pressure: "气压"
        case .locationName: "位置名称"
        case .conditionDescription: "天气状况描述"
        case .highLowTemp: "最高 / 最低温度"
        }
    }

    static var selectableCases: [WeatherInfoType] {
        return [.temperature, .condition, .conditionDescription, .highLowTemp, .locationName, .wind, .humidity, .feelsLike, .precipitation, .sunrise, .sunset, .uvIndex, .visibility, .pressure]
    }
}

enum FocusDisplayMode: String, Codable, CaseIterable, Identifiable {
    case full, compact
    var id: String { self.rawValue }
    var displayName: String {
        switch self {
        case .full: "显示完整名称"
        case .compact: "仅图标（开/关）"
        }
    }
}

enum LockScreenMainWidgetType: String, Codable, CaseIterable, Identifiable {
    case music, weather, calendar, battery, focus, timer, notes, clipboard
    var id: String { self.rawValue }
    var displayName: String {
        switch self {
        case .music: return "音乐"
        case .weather: return "天气"
        case .calendar: return "日历"
        case .battery: return "电池"
        case .focus: return "专注模式"
        case .timer: return "计时器"
        case .notes: return "备忘录"
        case .clipboard: return "剪贴板"
        }
    }

    static var selectableCases: [LockScreenMainWidgetType] {
        return [.music, .weather, .calendar, .battery, .focus, .timer, .notes, .clipboard]
    }
}

enum LockScreenWidgetType: String, Codable, CaseIterable, Identifiable {
    case none, weather, calendar, music, focus, bluetooth, battery, caffeine, timer, clock, notes, clipboard, system
    var id: String { self.rawValue }
    var displayName: String {
        switch self {
        case .none: return "无"
        case .weather: return "天气"
        case .calendar: return "日历"
        case .music: return "音乐"
        case .focus: return "专注模式"
        case .bluetooth: return "蓝牙"
        case .battery: return "电池"
        case .caffeine: return "保持唤醒"
        case .timer: return "计时器"
        case .clock: return "时钟"
        case .notes: return "备忘录"
        case .clipboard: return "剪贴板"
        case .system: return "系统"
        }
    }

    static var selectableCases: [LockScreenWidgetType] {
        return [.weather, .calendar, .music, .focus, .bluetooth, .battery, .caffeine, .timer, .clock, .notes, .clipboard, .system]
    }
}

enum LockScreenMiniWidgetType: String, Codable, CaseIterable, Identifiable {
    case none, weather, calendar, music, battery, focus, caffeine, timer, bluetooth, clipboard, notes, system
    var id: String { self.rawValue }
    var displayName: String {
        switch self {
        case .none: return "无"
        case .weather: return "天气"
        case .calendar: return "日历"
        case .music: return "音乐"
        case .battery: return "电池"
        case .focus: return "专注模式"
        case .caffeine: return "保持唤醒"
        case .timer: return "计时器"
        case .bluetooth: return "蓝牙"
        case .clipboard: return "剪贴板"
        case .notes: return "备忘录"
        case .system: return "系统"
        }
    }

    static var selectableCases: [LockScreenMiniWidgetType] {
        return [.weather, .calendar, .battery, .focus, .caffeine, .timer, .bluetooth, .clipboard, .notes, .system]
    }
}

enum BatteryInfoType: String, Codable, CaseIterable, Identifiable {
    case percentage, statusIcon, statusText, batteryIcon, estimatedTime
    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .percentage: "电量百分比"
        case .statusIcon: "状态图标"
        case .statusText: "状态文字"
        case .batteryIcon: "电池图标"
        case .estimatedTime: "预计剩余时间"
        }
    }
}

enum SnapZoneViewMode: String, Codable, CaseIterable, Identifiable {
    case single, multi
    var id: String { self.rawValue }
    var displayName: String {
        switch self {
        case .single: "单布局"
        case .multi: "多布局"
        }
    }
}

enum SnapWindowAnimation: String, Codable, CaseIterable, Identifiable {
    case fast, smooth
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .fast: "快速"
        case .smooth: "平滑"
        }
    }

    var summary: String {
        switch self {
        case .fast: return "窗口直接跳转至目标分区。"
        case .smooth: return "窗口通过简短的缓动动画滑入目标分区。"
        }
    }
}

enum FaceIDLocationPolicy: String, Codable, CaseIterable, Identifiable {
    case everywhere
    case selectedWiFiNetworks

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .everywhere: return "所有位置"
        case .selectedWiFiNetworks: return "指定 Wi-Fi 网络"
        }
    }
}

enum AppSnapLayoutConfiguration: Codable, Equatable {
    case useGlobalDefault
    case single(layoutID: UUID)
    case multi(layoutIDs: [UUID])

    enum CodingKeys: String, CodingKey {
        case type, payload
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "useGlobalDefault":
            self = .useGlobalDefault
        case "single":
            let layoutID = try container.decode(UUID.self, forKey: .payload)
            self = .single(layoutID: layoutID)
        case "multi":
            let layoutIDs = try container.decode([UUID].self, forKey: .payload)
            self = .multi(layoutIDs: layoutIDs)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Invalid type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .useGlobalDefault:
            try container.encode("useGlobalDefault", forKey: .type)
        case .single(let layoutID):
            try container.encode("single", forKey: .type)
            try container.encode(layoutID, forKey: .payload)
        case .multi(let layoutIDs):
            try container.encode("multi", forKey: .type)
            try container.encode(layoutIDs, forKey: .payload)
        }
    }
}

enum RestorableNotchMenu: String, Codable, Equatable {
    case defaultWidgets
    case musicPlayer
    case musicQueueAndPlaylists
    case musicDevices
    case sportsPlayer
    case financePlayer
    case notesPlayer
    case clipboardPlayer
    case mirrorPlayer
    case nearbyTransfer
    case fileShelf
    case multiAudio
    case weatherPlayer
    case calendarPlayer
    case timerDetailView
    case focusSessionDetailView

    func toNotchWidgetMode() -> NotchWidgetMode {
        switch self {
        case .defaultWidgets: return .defaultWidgets
        case .musicPlayer: return .musicPlayer
        case .musicQueueAndPlaylists: return .musicQueueAndPlaylists
        case .musicDevices: return .musicDevices
        case .sportsPlayer: return .sportsPlayer
        case .financePlayer: return .financePlayer
        case .notesPlayer: return .notesPlayer
        case .clipboardPlayer: return .clipboardPlayer
        case .mirrorPlayer: return .mirrorPlayer
        case .nearbyTransfer: return .nearbyTransfer
        case .fileShelf: return .fileShelf
        case .multiAudio: return .multiAudio
        case .weatherPlayer: return .weatherPlayer
        case .calendarPlayer: return .calendarPlayer
        case .timerDetailView: return .timerDetailView
        case .focusSessionDetailView: return .focusSessionDetailView
        }
    }
}

enum NotchAppearanceMode: String, Codable, CaseIterable, Identifiable {
    case `default`
    case liquidGlass
    case blur
    case custom

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .default: return "默认"
        case .liquidGlass: return "液态玻璃"
        case .blur: return "模糊"
        case .custom: return "自定义"
        }
    }
}

struct NotchAppearanceSettings: Codable, Equatable {
    var mode: NotchAppearanceMode = .default

    var backgroundStyle: NotchBackgroundStyle = .solid
    var solidColor: CodableColor = CodableColor(color: .black)
    var gradientColors: [CodableColor] = [
        CodableColor(color: Color(red: 0.2, green: 0.3, blue: 0.9), location: 0.0),
        CodableColor(color: .black, location: 1.0)
    ]
    var gradientAngle: Double = 90.0
    var opacity: Double = 1.0
    var enableTransparencyBlur: Bool = true
    var liquidGlassLook: Bool = false
    var liquidGlassStyle: LiquidGlassMaterial = .frosted
    var liquidGlassTintHex: String = LiquidGlassOptions.notchDefault.tintHex
    var liquidGlassAppearance: LiquidGlassAppearance = LiquidGlassOptions.notchDefault.appearance
    var liquidGlassHovered: Bool = false
    var bottomFadeEnabled: Bool = false

    var liquidGlassOptions: LiquidGlassOptions {
        get {
            LiquidGlassOptions(
                material: liquidGlassStyle,
                tintHex: liquidGlassTintHex,
                cornerRadius: 0,
                appearance: liquidGlassAppearance,
                hovered: liquidGlassHovered
            )
        }
        set {
            liquidGlassStyle = newValue.material
            liquidGlassTintHex = newValue.tintHex
            liquidGlassAppearance = newValue.appearance
            liquidGlassHovered = newValue.hovered
        }
    }

    var usesLiquidGlass: Bool { mode == .liquidGlass || liquidGlassLook }

    mutating func normalize() {
        opacity = min(max(opacity, 0), 1)
        if mode != .custom {
            liquidGlassLook = mode == .liquidGlass
        }
    }
}

enum MediaSource: String, Codable, CaseIterable, Identifiable {
    case system, spotify, appleMusic
    var id: String { self.rawValue }
    var displayName: String {
        switch self {
        case .system: "系统全局"
        case .spotify: "Spotify"
        case .appleMusic: "Apple Music"
        }
    }

    var preferredBundleID: String? {
        switch self {
        case .system: return nil
        case .spotify: return "com.spotify.client"
        case .appleMusic: return "com.apple.Music"
        }
    }
}

enum DockStaticOnlyTransitionPolicy {
    static func shouldSuppressSuggestedApps(
        enabled: Bool,
        showRecents: Bool,
        suppressionWasStored: Bool
    ) -> Bool {
        enabled && showRecents || (!enabled && suppressionWasStored)
    }

    static func shouldRestoreSuggestedApps(enabled: Bool, suppressionWasStored: Bool) -> Bool {
        !enabled && suppressionWasStored
    }
}

extension Settings {
    var enabledWidgetTypes: [WidgetType] {
        widgetOrder.filter { widget in
            switch widget {
            case .weather: return weatherWidgetEnabled
            case .calendar: return calendarWidgetEnabled
            case .shortcuts: return shortcutsWidgetEnabled
            case .music: return musicWidgetEnabled
            case .sports: return sportsWidgetEnabled
            case .finance: return financeWidgetEnabled
            case .shopify: return shopifyWidgetEnabled
            case .notes: return notesWidgetEnabled
            case .clipboard: return clipboardWidgetEnabled
            case .mirror: return mirrorWidgetEnabled
            case .battery: return batteryWidgetEnabled
            case .timer: return timerWidgetEnabled
            case .focusSession: return focusSessionWidgetEnabled
            case .storage: return storageWidgetEnabled
            case .dev: return devWidgetEnabled
            case .agent: return false
            }
        }
    }
}

extension Settings {
    func isMediaAppVisible(bundleID: String?) -> Bool {
        guard let bundleID, !bundleID.isEmpty else { return true }
        let normalized = bundleID.lowercased()

        if mediaSource != .system, prioritizeMediaSource,
           let preferred = mediaSource.preferredBundleID?.lowercased() {
            if preferred == "com.spotify.client" {
                return normalized.hasPrefix("com.spotify.client")
            }
            return normalized == preferred
        }

        if let explicit = mediaAppVisibility[bundleID] ?? mediaAppVisibility[normalized] {
            return explicit
        }
        return true
    }
}

enum NotchDisplayTarget: String, Codable, CaseIterable, Identifiable {
    case macbookDisplay, mainDisplay, allDisplays
    var id: String { self.rawValue }
    var displayName: String {
        switch self {
        case .macbookDisplay: "仅 MacBook 显示器"
        case .mainDisplay: "仅主显示器"
        case .allDisplays: "所有显示器"
        }
    }
}

enum HUDVisualStyle: String, Codable, CaseIterable, Identifiable {
    case white, color, adaptive
    var id: String { self.rawValue.capitalized }
}

enum HUDAdaptiveTransitionStyle: String, Codable, CaseIterable, Identifiable {
    case smooth, thresholds

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .smooth: "平滑渐变"
        case .thresholds: "分段阈值"
        }
    }
}

enum NotchBackgroundStyle: String, Codable, CaseIterable, Identifiable {
    case solid, gradient, radial
    var id: String { self.rawValue }
    var displayName: String {
        switch self {
        case .solid: "纯色"
        case .gradient: "线性渐变"
        case .radial: "径向渐变"
        }
    }
}

enum MusicPlayerButtonType: String, Codable, CaseIterable, Identifiable, Equatable {
    case like, shuffle, `repeat`, playlists, devices
    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .like: "喜欢"
        case .shuffle: "随机播放"
        case .repeat: "循环播放"
        case .playlists: "队列与歌单"
        case .devices: "播放设备"
        }
    }

    var systemImage: String {
        switch self {
        case .like: "heart.fill"
        case .shuffle: "shuffle"
        case .repeat: "repeat"
        case .playlists: "list.bullet"
        case .devices: "hifispeaker"
        }
    }
}

enum MusicLongPressAction: String, Codable, CaseIterable, Identifiable, Equatable {
    case none
    case seek
    case shuffle
    case repeatMode
    case like
    case playPause
    case nextTrack
    case previousTrack
    case openQueue
    case openDevices

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "无（仅点按）"
        case .seek: return "快进 / 快退"
        case .shuffle: return "随机播放"
        case .repeatMode: return "循环模式"
        case .like: return "喜欢"
        case .playPause: return "播放 / 暂停"
        case .nextTrack: return "下一首"
        case .previousTrack: return "上一首"
        case .openQueue: return "打开播放队列"
        case .openDevices: return "打开播放设备"
        }
    }

    static var skipButtonOptions: [MusicLongPressAction] {
        [.none, .seek, .shuffle, .repeatMode, .like, .playPause, .nextTrack, .previousTrack, .openQueue, .openDevices]
    }

    static var accessoryButtonOptions: [MusicLongPressAction] {
        [.none, .shuffle, .repeatMode, .like, .playPause, .nextTrack, .previousTrack, .openQueue, .openDevices]
    }
}

enum MusicLongPressTarget: String, CaseIterable, Identifiable {
    case previous
    case next
    case playPause
    case playlists
    case devices
    case like
    case shuffle
    case repeatMode

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .previous: return "上一首"
        case .next: return "下一首"
        case .playPause: return "播放 / 暂停"
        case .playlists: return "播放队列"
        case .devices: return "播放设备"
        case .like: return "喜欢"
        case .shuffle: return "随机播放"
        case .repeatMode: return "循环播放"
        }
    }

    var isTransportControl: Bool {
        switch self {
        case .previous, .next, .playPause: return true
        default: return false
        }
    }

    var isSecondaryButton: Bool { !isTransportControl }

    var pickerOptions: [MusicLongPressAction] {
        switch self {
        case .previous, .next: return MusicLongPressAction.skipButtonOptions
        default: return MusicLongPressAction.accessoryButtonOptions
        }
    }

    func defaultAction(in settings: Settings) -> MusicLongPressAction {
        switch self {
        case .previous: return settings.musicLongPressPrevious
        case .next: return settings.musicLongPressNext
        case .playPause: return settings.musicLongPressPlayPause
        case .playlists: return settings.musicLongPressPlaylists
        case .devices: return settings.musicLongPressDevices
        case .like: return settings.musicLongPressLike
        case .shuffle: return settings.musicLongPressShuffle
        case .repeatMode: return settings.musicLongPressRepeat
        }
    }

    static func from(buttonType: MusicPlayerButtonType) -> MusicLongPressTarget? {
        switch buttonType {
        case .playlists: return .playlists
        case .devices: return .devices
        case .like: return .like
        case .shuffle: return .shuffle
        case .repeat: return .repeatMode
        }
    }
}

extension Settings {
    mutating func setLongPressAction(_ action: MusicLongPressAction, for target: MusicLongPressTarget) {
        switch target {
        case .previous: musicLongPressPrevious = action
        case .next: musicLongPressNext = action
        case .playPause: musicLongPressPlayPause = action
        case .playlists: musicLongPressPlaylists = action
        case .devices: musicLongPressDevices = action
        case .like: musicLongPressLike = action
        case .shuffle: musicLongPressShuffle = action
        case .repeatMode: musicLongPressRepeat = action
        }
    }

    func resolvedSkipHoldAction(for target: MusicLongPressTarget) -> MusicLongPressAction {
        if !musicLongPressActionsEnabled { return .seek }
        return target.defaultAction(in: self)
    }

    func resolvedAccessoryHoldAction(for target: MusicLongPressTarget) -> MusicLongPressAction? {
        guard musicLongPressActionsEnabled else { return nil }
        let configured = target.defaultAction(in: self)
        return configured == .none ? nil : configured
    }
}

// MARK: - Swipe Action Customization

enum NotesSwipeAction: String, Codable, CaseIterable, Identifiable {
    case toggleDone, copy, delete, none
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .toggleDone: return "切换完成状态"
        case .copy: return "复制"
        case .delete: return "删除"
        case .none: return "无"
        }
    }
}

enum ClipboardSwipeAction: String, Codable, CaseIterable, Identifiable {
    case share, copy, delete, none
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .share: return "分享"
        case .copy: return "复制"
        case .delete: return "删除"
        case .none: return "无"
        }
    }
}

enum FileDropSwipeAction: String, Codable, CaseIterable, Identifiable {
    case share, delete, none
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .share: return "分享"
        case .delete: return "删除"
        case .none: return "无"
        }
    }
}

struct SwipeActionSettings: Codable, Equatable {
    var notesLeading: NotesSwipeAction = .toggleDone
    var notesTrailing: NotesSwipeAction = .delete
    var clipboardLeading: ClipboardSwipeAction = .share
    var clipboardTrailing: ClipboardSwipeAction = .delete
    var fileDropLeading: FileDropSwipeAction = .share
    var fileDropTrailing: FileDropSwipeAction = .delete
}

// MARK: - DMG Installer

enum DMGInstallLocation: String, Codable, CaseIterable, Identifiable {
    case systemApplications
    case homeApplications

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .systemApplications: "/Applications"
        case .homeApplications: "~/Applications"
        }
    }

    var url: URL {
        switch self {
        case .systemApplications: URL(fileURLWithPath: "/Applications", isDirectory: true)
        case .homeApplications: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        }
    }
}

enum DMGPostInstallAction: String, Codable, CaseIterable, Identifiable {
    case open
    case revealInFinder
    case none

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .open: "打开应用"
        case .revealInFinder: "在访达中显示"
        case .none: "不执行操作"
        }
    }

    var systemImage: String {
        switch self {
        case .open: "play.fill"
        case .revealInFinder: "magnifyingglass"
        case .none: "square.dashed"
        }
    }
}

enum FileOperationProgressDisplay: String, Codable, CaseIterable, Identifiable {
    case liveActivity
    case popup

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .liveActivity: "实时活动"
        case .popup: "弹出窗口"
        }
    }
}

enum ShortcutIdentifier {
    static let circleToSearch = "circleToSearch"
    static let clipboardPicker = "clipboardPicker"
    static let emojiPicker = "emojiPicker"
    static let focusStart = "focusStart"
    static let ocrScreenshot = "ocrScreenshot"
    static let menuBarToggleHidden = "menuBarToggleHidden"
    static let menuBarToggleAlwaysHidden = "menuBarToggleAlwaysHidden"
    static let menuBarSearch = "menuBarSearch"
    static let menuBarZenMode = "menuBarZenMode"

    static func snapZone(layoutID: UUID, zoneID: UUID) -> String { "snapZone:\(layoutID.uuidString):\(zoneID.uuidString)" }
    static func plane(_ planeID: UUID) -> String { "plane:\(planeID.uuidString)" }
    static func dockLayouts(_ presetID: UUID) -> String { "dockLayouts:\(presetID.uuidString)" }
}

// MARK: - Main Settings Struct
struct Settings: Codable, Equatable {
    var animationProfile: AnimationProfile = .fluid
    var customAnimationConfiguration: CustomizableAnimationConfiguration = .init()
    var widgetSwitchEffect: WidgetSwitchEffect = .smooth
    var widgetSwitchTransition: WidgetSwitchTransition = .slide

    var swipeToSwitchWidgets: Bool = true
    var enableWidgetSwitchFade: Bool = true
    var enableWidgetSwitchSlide: Bool = true
    var enableWidgetSwitchBounce: Bool = true
    var enableOpeningBounce: Bool = true

    var enableXDRBrightness: Bool = isDeviceSupported()
    var brightness: Float = 1.0
    var xdrBrightnessLevel: Float = 1.6
    var xdrBrightnessLock: Bool = false
    var notchWidth: CGFloat = 0
    var notchHeight: CGFloat = 0

    var perDisplayNotchSize: [String: NotchSizeOverride] = [:]
    var perDisplayHideNotchWhenInactive: [String: Bool] = [:]
    var perDisplayFullScreenBehavior: [String: FullScreenBehavior] = [:]
    var perDisplayShowNotch: [String: Bool] = [:]
    var perDisplayFloatingIsland: [String: Bool] = [:]
    var perDisplayFloatingIslandTopOffset: [String: CGFloat] = [:]
    var perDisplayFloatingIslandStyle: [String: FloatingIslandStyle] = [:]
    var perDisplayNotchWidgetAppearance: [String: NotchAppearanceSettings] = [:]
    var perDisplayNotchLiveActivityAppearance: [String: NotchAppearanceSettings] = [:]

    var useCustomNotchConfiguration: Bool = false
    var customNotchConfiguration: CustomizableNotchConfiguration = .init()
    var lockScreenShowInfoWidget: Bool = true
    var lockScreenWidgets: [LockScreenWidgetType] = [.weather, .bluetooth]
    var lockScreenHideInactiveInfoWidgets: Bool = true
    var lockScreenShowMainWidget: Bool = false
    var lockScreenMainWidgets: [LockScreenMainWidgetType] = [.weather]
    var lockScreenShowMiniWidgets: Bool = true
    var lockScreenMiniWidgets: [LockScreenMiniWidgetType] = []
    var lockScreenShowNotch: Bool = true
    var lockScreenCustomWallpaperEnabled: Bool = false
    var lockScreenCustomWallpaperPath: String? = nil
    var lockScreenKeepWallpaperAfterUnlock: Bool = false
    var desktopWallpaperEnabled: Bool = false
    var desktopWallpaperPath: String? = nil
    var liveWallpaperScaling: WallpaperScaling = .fill
    var liveWallpaperPlaybackMode: LiveWallpaperPlaybackMode = .adaptive
    var liveWallpaperPauseOnLowPower: Bool = false
    var liveWallpaperPauseOnBattery: Bool = false
    var lockScreenLiveWallpaperShowsClock: Bool = false
    var lockScreenLiveWallpaperIdleDelay: Double = 8
    var lockScreenLiveActivityEnabled: Bool = true
    var lockScreenLiquidGlassLook: Bool = true
    var lockScreenGlass: LiquidGlassOptions = .lockScreenDefault
    var lockScreenShowInfoWidgetBackgrounds: Bool = true
    var lockScreenShowMusicWhenPaused: Bool = true
    var lockScreenWeatherInfo: [WeatherInfoType] = [.temperature]
    var lockScreenBatteryInfo: [BatteryInfoType] = [.batteryIcon, .percentage, .statusText]
    var notchWidgetAppearance: NotchAppearanceSettings = .init()
    var systemEnhanceDockPreviewsEnabled: Bool = false
    var systemEnhanceWindowSwitcherEnabled: Bool = false
    var systemEnhanceSwitcherActivationRaw: String = "both"
    var systemEnhanceSwitcherIncludeOtherSpaces: Bool = false
    var systemEnhanceCalendarIntegrationEnabled: Bool = false
    var systemEnhanceCompactPreviewEnabled: Bool = false
    var systemEnhanceEnhancedPreviewsEnabled: Bool = false
    var systemEnhanceDockLocked: Bool = false
    var systemEnhanceLockedDisplayID: String? = nil
    var systemEnhancePreviewLayoutRaw: String = "grid"
    var systemEnhanceWindowSwitcherLayoutRaw: String = "grid"
    var systemEnhancePreviewTriggerRaw: String = "hover"
    var systemEnhancePreviewDelay: Double = 0.25
    var systemEnhanceLivePreviewKeepAlive: Int = 2
    var systemEnhancePasteAsPlainTextEnabled: Bool = false
    var systemEnhancePasteAsPlainStripLinks: Bool = false
    var systemEnhancePasteAsPlainStripEmojis: Bool = false
    var systemEnhancePasteAsPlainStripListMarkers: Bool = false
    var systemEnhancePasteAsPlainShortcut: KeyboardShortcut = KeyboardShortcut(key: "V", modifiers: [.command, .option, .shift])

    // MARK: - Hinge-driven desktop animation

    var systemEnhanceHingeAnimationEnabled: Bool = false
    var systemEnhanceHingeAnimationActivationAngle: Double = 90
    var systemEnhanceHingeAnimationIntensity: Double = 1
    var systemEnhanceHingeAnimationBlur: Double = 135

    var systemEnhancePasteAsPlainNeedsSanitization: Bool {
        systemEnhancePasteAsPlainStripLinks
            || systemEnhancePasteAsPlainStripEmojis
            || systemEnhancePasteAsPlainStripListMarkers
    }

    // MARK: - Dock clicks (Vorssaint-style)

    var systemEnhanceDockClicksEnabled: Bool = false
    var systemEnhanceDockClickActionRaw: String = "minimize"
    var systemEnhanceDockClicksAllAppsEnabled: Bool = true
    var systemEnhanceDockClicksSelectedApps: [String] = []
    var systemEnhanceDockClicksExcludedApps: [String] = []

    func isDockClickEnabled(for bundleIdentifier: String) -> Bool {
        if systemEnhanceDockClicksAllAppsEnabled {
            return !systemEnhanceDockClicksExcludedApps.contains(bundleIdentifier)
        }
        return systemEnhanceDockClicksSelectedApps.contains(bundleIdentifier)
    }

    // MARK: - DockLayouts (Dock layout presets)

    var dockLayoutsEnabled: Bool = false
    var dockLayoutsPresets: [DockLayout] = []

    // MARK: - Media Optimizer (image/video/audio compression & OCR)

    var mediaToolsAutoOptimizeClipboard: Bool = false
    var mediaToolsImageQuality: Double = 0.75
    var mediaToolsMaxImageDimension: Double = 2048
    var mediaToolsShowShelfActions: Bool = false
    var mediaToolsOCRLanguage: String = "en-US"
    var mediaToolsOCRShortcutEnabled: Bool = false
    var mediaToolsOCRShortcut: KeyboardShortcut = KeyboardShortcut(key: "T", modifiers: [.control, .shift])

    // MARK: - Quit on close (Vorssaint-style)

    var systemEnhanceAutoQuitEnabled: Bool = false
    var systemEnhanceAutoQuitExcludedApps: [String] = []

    // MARK: - Quit & close protection (Vorssaint-style)

    var systemEnhanceQuitProtectionEnabled: Bool = false
    var systemEnhanceQuitProtectionModeRaw: String = "hold"
    var systemEnhanceQuitProtectionExtraModifierRaw: String = "option"
    var systemEnhanceQuitProtectionProtectQuit: Bool = true
    var systemEnhanceQuitProtectionProtectClose: Bool = true
    var systemEnhanceQuitProtectionHoldInterval: Double = 1.2
    var systemEnhanceQuitProtectionDoublePressInterval: Double = 0.5
    var systemEnhanceQuitProtectionExcludedApps: [String] = []
    var systemEnhanceQuitProtectionCloseModeRaw: String = ""
    var systemEnhanceQuitProtectionCloseHoldInterval: Double = 1.2
    var systemEnhanceQuitProtectionCloseDoublePressInterval: Double = 0.5
    var systemEnhanceQuitProtectionShowHUD: Bool = true

    // MARK: - Green button maximize (Vorssaint-style)

    var systemEnhanceGreenMaximizeEnabled: Bool = false
    var systemEnhanceGreenMaximizeExcludedApps: [String] = []

    var notchLiveActivityAppearance: NotchAppearanceSettings = .init()
    var launchAtLogin: Bool = true
    var appLanguage: String = "en"
    var hapticFeedbackEnabled: Bool = true
    var googleAnalyticsEnabled: Bool = true
    var hideFromScreenSharing: Bool = false
    var notchDisplayTarget: NotchDisplayTarget = .allDisplays
    var floatingIslandOnNotchlessDisplays: Bool = true
    var floatingIslandTopOffset: CGFloat = 3
    var floatingIslandStyle = FloatingIslandStyle()
    var expandOnHover: Bool = false
    var expandOnHoverDelay: TimeInterval = 0.0
    var suppressHoverExpansionForTransientLiveActivities: Bool = false
    var showLiveActivitySatellites: Bool = true
    var liveActivitySatelliteLimit: Int = 2
    var capsLockHorizontalLockEnabled: Bool = false
    var capsLockHorizontalLockAppStates: [String: Bool] = [:]
    var launchpadEnabled: Bool = false
    var caffeinateEnabled: Bool = true
    var notesIconEnabled: Bool = true
    var clipboardIconEnabled: Bool = true
    var fileShelfIconEnabled: Bool = true
    var focusSessionIconEnabled: Bool = true
    var batteryEstimatorEnabled: Bool = true
    var showMultiAudioIcon: Bool = true
    var intelligenceEnabled: Bool = true
    var intelligenceBackend: LLMBackend = .auto
    var intelligenceGeminiSpeedMode: GeminiSpeedMode = .fast
    var intelligenceGeminiModel: GeminiModelOption = .flash35Lite
    var intelligenceOpenAIModel: OpenAIModelOption = .auto
    var intelligenceAnthropicModel: AnthropicModelOption = .auto
    var intelligenceOpenRouterModel: String = OpenRouterModelPreset.auto.rawValue
    var intelligenceXAIModel: XAIModelOption = .auto
    var intelligenceNVIDIAModel: NVIDIAModelOption = .auto
    var pinEnabled: Bool = true
    var hideNotchWhenInactive: Bool = false
    var swipeToHideNotch: Bool = false
    var preventNotchExpandWhenLocked: Bool = false
    var releaseChannel: ReleaseChannel = .stable
    var automaticUpdateChecksEnabled: Bool = true
    var automaticallyDownloadSapphireUpdates: Bool = true
    var updateAvailableNotificationsEnabled: Bool = true
    var showUpdateAvailableLiveActivity: Bool = true

    // MARK: - Installed app updates (Latest-style)

    var installedAppUpdatesEnabled: Bool = false
    var installedAppUpdateNotificationsEnabled: Bool = false
    var notchButtonOrder: [NotchButtonType] = [.settings, .fileShelf, .notes, .clipboard, .intelligence, .focusSession, .spacer, .continuity, .battery, .multiAudio, .caffeine, .pin]
    var notchBarSpacerWidth: CGFloat = NotchBarSpacerPolicy.automaticWidth
    var circleToSearchEnabled: Bool = true
    var circleToSearchShortcut: KeyboardShortcut = KeyboardShortcut(key: "C", modifiers: [.control, .shift])
    var circleToSearchBrowserEngine: CircleSearchBrowserEngine = .google

    // MARK: - Per-display resolution helpers

    func resolvedNotchWidth(forDisplayID displayID: String?) -> CGFloat {
        if let override = DisplaySettingsKey.value(in: perDisplayNotchSize, for: displayID),
           override.width > 0 {
            return override.width
        }
        return notchWidth
    }

    func resolvedNotchHeight(forDisplayID displayID: String?) -> CGFloat {
        if let override = DisplaySettingsKey.value(in: perDisplayNotchSize, for: displayID),
           override.height > 0 {
            return override.height
        }
        return notchHeight
    }

    func resolvedHideNotchWhenInactive(forDisplayID displayID: String?) -> Bool {
        if let perDisplay = DisplaySettingsKey.value(in: perDisplayHideNotchWhenInactive, for: displayID) {
            return perDisplay
        }
        return hideNotchWhenInactive
    }

    var defaultFullScreenBehavior: FullScreenBehavior {
        FullScreenBehavior(
            activityVisibility: fullScreenActivityVisibility,
            hideNotch: hideNotchInFullScreen,
            hideLyrics: hideLyricsInFullScreen
        )
    }

    func resolvedFloatingIsland(forDisplayID displayID: String?) -> Bool {
        if let perDisplay = DisplaySettingsKey.value(in: perDisplayFloatingIsland, for: displayID) {
            return perDisplay
        }
        return floatingIslandOnNotchlessDisplays
    }

    func resolvedNotchWidgetAppearance(forDisplayID displayID: String?) -> NotchAppearanceSettings {
        DisplaySettingsKey.value(in: perDisplayNotchWidgetAppearance, for: displayID) ?? notchWidgetAppearance
    }

    func resolvedNotchLiveActivityAppearance(forDisplayID displayID: String?) -> NotchAppearanceSettings {
        DisplaySettingsKey.value(in: perDisplayNotchLiveActivityAppearance, for: displayID) ?? notchLiveActivityAppearance
    }

    func hasAppearanceOverride(forDisplayID displayID: String?) -> Bool {
        DisplaySettingsKey.value(in: perDisplayNotchWidgetAppearance, for: displayID) != nil
            || DisplaySettingsKey.value(in: perDisplayNotchLiveActivityAppearance, for: displayID) != nil
    }

    mutating func applyAppearanceToAllDisplays(from displayID: String) {
        notchWidgetAppearance = resolvedNotchWidgetAppearance(forDisplayID: displayID)
        notchLiveActivityAppearance = resolvedNotchLiveActivityAppearance(forDisplayID: displayID)
        perDisplayNotchWidgetAppearance = [:]
        perDisplayNotchLiveActivityAppearance = [:]
    }

    func resolvedFloatingIslandStyle(forDisplayID displayID: String?) -> FloatingIslandStyle {
        if let perDisplay = DisplaySettingsKey.value(in: perDisplayFloatingIslandStyle, for: displayID) {
            return perDisplay
        }
        return floatingIslandStyle
    }

    func resolvedFloatingIslandTopOffset(forDisplayID displayID: String?) -> CGFloat {
        if let perDisplay = DisplaySettingsKey.value(in: perDisplayFloatingIslandTopOffset, for: displayID) {
            return perDisplay
        }
        return floatingIslandTopOffset
    }

    mutating func applyDisplaySettingsToAllDisplays(from displayID: String, includeFloatingIsland: Bool = false) {
        let size = DisplaySettingsKey.value(in: perDisplayNotchSize, for: displayID)
        let hideWhenInactive = resolvedHideNotchWhenInactive(forDisplayID: displayID)
        let fullScreen = resolvedFullScreenBehavior(forDisplayID: displayID)
        let floatingIsland = resolvedFloatingIsland(forDisplayID: displayID)
        let islandTopOffset = resolvedFloatingIslandTopOffset(forDisplayID: displayID)
        let islandStyle = resolvedFloatingIslandStyle(forDisplayID: displayID)

        if let size {
            if size.width > 0 { notchWidth = size.width }
            if size.height > 0 { notchHeight = size.height }
        }
        hideNotchWhenInactive = hideWhenInactive
        fullScreenActivityVisibility = fullScreen.activityVisibility
        hideNotchInFullScreen = fullScreen.hideNotch
        hideLyricsInFullScreen = fullScreen.hideLyrics
        if includeFloatingIsland {
            floatingIslandOnNotchlessDisplays = floatingIsland
            floatingIslandTopOffset = islandTopOffset
            floatingIslandStyle = islandStyle
            perDisplayFloatingIsland = [:]
            perDisplayFloatingIslandTopOffset = [:]
            perDisplayFloatingIslandStyle = [:]
        }

        perDisplayNotchSize = [:]
        perDisplayHideNotchWhenInactive = [:]
        perDisplayFullScreenBehavior = [:]
    }

    mutating func setHideLyricsInFullScreenOnAllDisplays(_ hide: Bool) {
        hideLyricsInFullScreen = hide
        for key in perDisplayFullScreenBehavior.keys {
            perDisplayFullScreenBehavior[key]?.hideLyrics = hide
        }
    }

    mutating func applyDisplayDefaultToAllDisplays(_ key: String) {
        switch key {
        case "notchWidth":
            for id in perDisplayNotchSize.keys { perDisplayNotchSize[id]?.width = notchWidth }
        case "notchHeight":
            for id in perDisplayNotchSize.keys { perDisplayNotchSize[id]?.height = notchHeight }
        case "hideNotchWhenInactive":
            for id in perDisplayHideNotchWhenInactive.keys { perDisplayHideNotchWhenInactive[id] = hideNotchWhenInactive }
        case "hideNotchInFullScreen":
            for id in perDisplayFullScreenBehavior.keys { perDisplayFullScreenBehavior[id]?.hideNotch = hideNotchInFullScreen }
        case "fullScreenActivityVisibility":
            for id in perDisplayFullScreenBehavior.keys { perDisplayFullScreenBehavior[id]?.activityVisibility = fullScreenActivityVisibility }
        case "hideLyricsInFullScreen":
            setHideLyricsInFullScreenOnAllDisplays(hideLyricsInFullScreen)
        case "floatingIslandOnNotchlessDisplays":
            for id in perDisplayFloatingIsland.keys { perDisplayFloatingIsland[id] = floatingIslandOnNotchlessDisplays }
        case "floatingIslandTopOffset":
            for id in perDisplayFloatingIslandTopOffset.keys { perDisplayFloatingIslandTopOffset[id] = floatingIslandTopOffset }
        default:
            break
        }
    }

    func resolvedFullScreenBehavior(forDisplayID displayID: String?) -> FullScreenBehavior {
        if let perDisplay = DisplaySettingsKey.value(in: perDisplayFullScreenBehavior, for: displayID) {
            return perDisplay
        }
        return defaultFullScreenBehavior
    }

    // MARK: - Legacy migration shims (read-only computed, not persisted)
    var geminiEnabled: Bool { intelligenceEnabled }
    var geminiApiKey: String {
        get { APIKeyManager.shared.geminiAPIKey }
        set { APIKeyManager.shared.geminiAPIKey = newValue }
    }
    var agentSEnabled: Bool { intelligenceEnabled }
    var agentSApiKey: String {
        get { APIKeyManager.shared.geminiAPIKey }
        set { APIKeyManager.shared.geminiAPIKey = newValue }
    }
    var agentSBackend: LLMBackend {
        get { intelligenceBackend }
        set { intelligenceBackend = newValue }
    }
    var rememberLastMenu: Bool = false
    var lastNotchNavigationStack: [RestorableNotchMenu]? = nil
    var showDividersBetweenWidgets: Bool = false
    var bypassWidgetSpaceLimit: Bool = false
    var widgetOrder: [WidgetType] = [.music, .weather, .sports, .finance, .calendar, .focusSession, .battery, .timer, .shortcuts, .notes, .clipboard, .mirror, .shopify, .storage, .dev, .agent]
    var musicWidgetEnabled: Bool = true
    var weatherWidgetEnabled: Bool = true
    var sportsWidgetEnabled: Bool = false
    var financeWidgetEnabled: Bool = false
    var shopifyWidgetEnabled: Bool = false
    var calendarWidgetEnabled: Bool = true
    var shortcutsWidgetEnabled: Bool = false
    var notesWidgetEnabled: Bool = false
    var clipboardWidgetEnabled: Bool = false
    var mirrorWidgetEnabled: Bool = false
    var mirrorOpenOnClick: Bool = true
    var mirrorFlipHorizontally: Bool = true
    var mirrorRotationMode: MirrorRotationMode = .auto
    var notesOpenOnClick: Bool = true
    var clipboardOpenOnClick: Bool = true
    var clipboardHistoryLimit: Int = ClipboardHistoryBudget.defaultItemLimit
    var clipboardMonitoringEnabled: Bool = true
    var clipboardHistoryUnlimited: Bool = false
    var clipboardIgnoreConcealedItems: Bool = true
    var clipboardHistoryStorageLimitMB: Int = ClipboardHistoryBudget.defaultStorageLimitMB
    var clipboardHistoryRetentionVersion: Int = 1
    var clipboardIgnoredAppBundleIDs: [String] = ClipboardIgnoredApps.defaultBundleIDs
    var clipboardPickerEnabled: Bool = false
    var clipboardPickerShortcut: KeyboardShortcut = KeyboardShortcut(key: "V", modifiers: [.command, .shift])

    // MARK: - Auto-clear clipboard (Vorssaint-style)

    var clipboardAutoClearEnabled: Bool = false
    var clipboardAutoClearInterval: Double = 30
    var clipboardAutoClearOnSleep: Bool = true
    var clipboardAutoClearOnLock: Bool = true

    // MARK: - Clean URL (Vorssaint-style)

    var clipboardCleanURLEnabled: Bool = false
    var clipboardCleanURLAutoClean: Bool = true
    var clipboardCleanURLCustomParams: [String] = []

    // MARK: - Finder cut & paste (Vorssaint-style)

    var clipboardFinderCutPasteEnabled: Bool = false
    var clipboardFinderPasteImagesAsPNG: Bool = true
    var clipboardFinderF2RenameEnabled: Bool = false

    // MARK: - Text snippets (Vorssaint-style)

    var snippetsEnabled: Bool = false
    var snippetsExpandAfterSpace: Bool = true
    var snippetsList: [SnippetEntry] = []

    var emojiEnabled: Bool = false
    var emojiSuggestOnColon: Bool = true
    var emojiDisabledAppBundleIDs: Set<String> = []
    var emojiSkinTone: EmojiSkinTone = .none
    var emojiPickerShortcut: KeyboardShortcut = KeyboardShortcut(key: "Space", modifiers: [.control, .command])
    var mouseControlEnabled: Bool = false
    var mouseInvertScroll: Bool = false
    var mouseInvertHorizontalScroll: Bool = false
    var mouseScrollSpeed: Double = 1.0
    var mouseDisableAcceleration: Bool = false
    var mouseAccelerationStrength: Double = 1.0
    var mouseMiddleButtonAction: MouseButtonAction = .none
    var mouseButton4Action: MouseButtonAction = .back
    var mouseButton5Action: MouseButtonAction = .forward
    var mouseMiddleModifiedAction: MouseButtonAction = .none
    var mouseButton4ModifiedAction: MouseButtonAction = .none
    var mouseButton5ModifiedAction: MouseButtonAction = .none
    var mouseModifierButtonEnabled: Bool = false
    var mouseModifierButtonNumber: Int = 3
    var mouseModifierSelection: MouseModifierSelection = .default

    // MARK: - Vorssaint-style mouse & keyboard additions

    var mouseFocusFollowsEnabled: Bool = false
    var mouseFocusFollowsDelay: Double = 0.5
    var mouseExtraClickFilterEnabled: Bool = false
    var mouseExtraClickFilterInterval: Double = 0.04
    var keyboardDebounceEnabled: Bool = false
    var keyboardDebounceInterval: Double = 0.045
    var superKeyEnabled: Bool = false
    var superKeyKeyRaw: String = "rightCommand"
    var superKeyComboRaw: String = "hyper"
    var superKeyTapActionRaw: String = "none"
    var mouseExcludedAppBundleIDs: [String] = []
    var mouseLinearScrollEnabled: Bool = false
    var mouseLinearScrollLines: Double = 3
    var mouseHorizontalScrollModifierRaw: String = "none"
    var mouseSmoothScrollEnabled: Bool = false
    var mouseSmoothScrollSpeed: Double = 1.0
    var mouseSmoothScrollResponse: Double = 0.5
    var superKeyExcludedAppBundleIDs: [String] = []
    var keyboardDebounceKeyIntervals: [String: Double] = [:]

    // MARK: - Monitoring (Vorssaint-style)

    var monitoringMenuBarReadoutsEnabled: Bool = false
    var monitoringReadoutShowCPU: Bool = true
    var monitoringReadoutShowMemory: Bool = true
    var monitoringReadoutShowNetwork: Bool = true
    var monitoringAlertsEnabled: Bool = false
    var monitoringAlertSustainedCPUEnabled: Bool = true
    var monitoringAlertCPUThreshold: Double = 90
    var monitoringAlertMemoryPressureEnabled: Bool = true
    var monitoringAlertLowDiskEnabled: Bool = true
    var monitoringAlertDiskThresholdGB: Double = 10
    var monitoringAlertTemperatureEnabled: Bool = false
    var monitoringAlertTemperatureThreshold: Double = 95
    var monitoringAlertLowBatteryEnabled: Bool = false
    var monitoringAlertLowBatteryThreshold: Double = 15

    var archiveExtractorEnabled: Bool = false
    var archiveExtractionMode: ArchiveExtractionMode = .smart
    var archivePostExtractAction: ArchivePostExtractAction = .reveal
    var archiveDeleteAfterExtract: Bool = false
    var archivePromptForPasswords: Bool = true
    var archiveProgressDisplay: FileOperationProgressDisplay = .liveActivity
    var dmgInstallerEnabled: Bool = false
    var dmgInstallerTrashAfterInstall: Bool = true
    var dmgInstallerPostInstallAction: DMGPostInstallAction = .open
    var dmgInstallerInstallLocation: DMGInstallLocation = .systemApplications
    var dmgInstallerReplaceNewerVersions: Bool = true
    var dmgInstallerReplaceWithoutPrompting: Bool = false
    var dmgInstallerProgressDisplay: FileOperationProgressDisplay = .liveActivity
    var dmgInstallerOfferOnManualMount: Bool = false
    var timerWidgetEnabled: Bool = false
    var batteryWidgetEnabled: Bool = true
    var focusSessionWidgetEnabled: Bool = true
    var storageWidgetEnabled: Bool = false
    var storageOpenOnClick: Bool = true
    var selectedShortcuts: [ShortcutInfo] = []
    var liveActivityOrder: [LiveActivityType] = LiveActivityType.allCases
    var capsLockLiveActivityEnabled: Bool = true
    var musicLiveActivityEnabled: Bool = true
    var musicLiveActivityRightTextMode: MusicLiveActivityRightTextMode = .continuityOnly
    var musicLiveActivityWaveformMode: MusicLiveActivityWaveformMode = .continuityOff
    var musicLiveActivityWaveformStyle: MusicLiveActivityWaveformStyle = .classic
    var weatherLiveActivityEnabled: Bool = true
    var calendarLiveActivityEnabled: Bool = true
    var remindersLiveActivityEnabled: Bool = true
    var timersLiveActivityEnabled: Bool = true
    var batteryLiveActivityEnabled: Bool = true
    var eyeBreakLiveActivityEnabled: Bool = false
    var desktopLiveActivityEnabled: Bool = true
    var focusLiveActivityEnabled: Bool = true
    var focusSessionLiveActivityEnabled: Bool = true
    var focusSessionLiveActivityShowTime: Bool = true
    var focusNotificationsEnabled: Bool = true
    var focusSessionDuration: TimeInterval = 90 * 60
    var focusBreakEnabled: Bool = false
    var focusBreakDuration: TimeInterval = 0
    var focusBlockingEnabled: Bool = true
    var focusBlockingDuringBreaks: Bool = false
    var focusIntensity: FocusIntensity = .standard
    var focusStrictUnblockCooldown: TimeInterval = 15 * 60
    var focusBlockingMode: FocusBlockingMode = .blocklist
    var focusBlockedApps: Set<String> = []
    var focusAllowedApps: Set<String> = []

    var focusDimInactiveApps: Bool = true
    var focusDimInactiveOpacity: Double = 0.45
    var focusDisableDimInMissionControl: Bool = false
    var focusHideWallpaper: Bool = false
    var focusAppLimitEnabled: Bool = false
    var focusAppLimit: Int = 2
    var focusAmbientSoundEnabled: Bool = false
    var focusAmbientSoundType: FocusAmbientSoundType = .rain
    var focusAmbientSoundVolume: Double = 0.4
    var focusStartShortcutName: String = ""
    var focusEndShortcutName: String = ""
    var focusBlockedWebsites: Set<String> = []
    var focusStartShortcut: KeyboardShortcut = KeyboardShortcut(key: "F", modifiers: [.command, .shift])
    var clickToShowFocusSessionView: Bool = true
    var focusShortcutsEnabled: Bool = false
    var focusShortcutSyncMode: FocusShortcutSyncMode = .none
    var scheduledFocusSessions: [ScheduledFocusSession] = []

    var appLockEnabled: Bool = false
    var appLockProtectedApps: Set<String> = []
    var appLockFaceIDEnabled: Bool = true
    var appLockTouchIDEnabled: Bool = true
    var appLockPasswordFallbackEnabled: Bool = true
    var appLockPreventOpenUntilAuth: Bool = true
    var appLockCloseAppOnAuthFailures: Bool = true
    var appLockAutoLockIdleEnabled: Bool = false
    var appLockAutoLockIdleMinutes: Int = 3
    var appLockAutoCloseOnLock: Bool = false
    var appLockLockOnLeave: Bool = false
    var appLockLockOnSleep: Bool = true
    var appLockPanicKeyEnabled: Bool = true
    var fileShelfLiveActivityEnabled: Bool = true
    var fileProgressLiveActivityEnabled: Bool = false
    var appActivitiesEnabled: Bool = true
    var appActivitiesDisabled: Set<String> = []
    var appActivityRestoreFocus: Bool = true
    var fileProgressDisabledApps: Set<String> = []
    var fileProgressShowSpeed: Bool = true
    var fileProgressShowTimeRemaining: Bool = true
    var fileProgressKeepFinishedSeconds: Double = 6
    var fileProgressAddFinishedToShelf: Bool = false
    var fileProgressOpenOnClick: Bool = true
    var fileProgressExtraFolders: [String] = []

    var microphoneLiveActivityEnabled: Bool = true
    var microphoneLiveActivityBehavior: MicrophoneLiveActivityBehavior = .iconAndGesture

    var statsLiveActivityEnabled: Bool = false
    var selectedStats: [StatType] = [.cpu, .ram, .gpu, .disk]
    var selectedSensorKeys: [String] = []

    var statsLiveActivityThresholdEnabled: Bool = false
    var statThresholds: [StatType: StatThreshold] = [
        .cpu: StatThreshold(),
        .ram: StatThreshold(),
        .gpu: StatThreshold()
    ]

    var sportsLiveActivityEnabled: Bool = false
    var sportsCommentaryInLiveActivity: Bool = false
    var sportsLiveActivityWhenLiveOnly: Bool = false
    var financeLiveActivityEnabled: Bool = false
    var financeLiveActivityActiveHoursOnly: Bool = false
    var sportsOpenOnClick: Bool = true
    var financeOpenOnClick: Bool = true
    var sportsPreferLogo: Bool = true
    var sportsFavoriteTeams: [String] = ["Kansas City Chiefs"]
    var financeFavoriteSymbols: [String] = ["AAPL", "MSFT", "NVDA"]
    var financeShares: [String: Double] = [:]
    var financeInvested: [String: Double] = [:]
    var financeInvestmentStartDates: [String: Date] = [:]
    var sportsFavoriteTeamIndex: Int = 0
    var financeFavoriteSymbolIndex: Int = 0

    mutating func normalizedSportsFavoriteTeamIndex() {
        guard !sportsFavoriteTeams.isEmpty else { sportsFavoriteTeamIndex = 0; return }
        sportsFavoriteTeamIndex = max(0, min(sportsFavoriteTeamIndex, sportsFavoriteTeams.count - 1))
    }

    mutating func normalizedFinanceFavoriteSymbolIndex() {
        guard !financeFavoriteSymbols.isEmpty else { financeFavoriteSymbolIndex = 0; return }
        financeFavoriteSymbolIndex = max(0, min(financeFavoriteSymbolIndex, financeFavoriteSymbols.count - 1))
    }

    func isShortcutEnabled(_ identifier: String) -> Bool {
        !disabledShortcutIDs.contains(identifier)
    }

    mutating func setSnapZoneShortcut(_ shortcut: KeyboardShortcut?, for layoutID: UUID, zoneID: UUID) {
        snapZoneShortcuts.removeAll { mapping in
            mapping.layoutID == layoutID && mapping.zoneID == zoneID
                || (shortcut != nil && mapping.shortcut.matches(shortcut!))
        }
        if let shortcut {
            snapZoneShortcuts.append(SnapZoneShortcut(layoutID: layoutID, zoneID: zoneID, shortcut: shortcut))
        }
    }

    func hasSameNormalizedCollections(as other: Settings) -> Bool {
        snapZoneShortcuts == other.snapZoneShortcuts
            && liveActivityOrder == other.liveActivityOrder
            && widgetOrder == other.widgetOrder
            && notchButtonOrder == other.notchButtonOrder
    }

    func hasSameNormalizationInputs(as other: Settings) -> Bool {
        hasSameNormalizedCollections(as: other) && customSnapLayouts == other.customSnapLayouts
    }

    mutating func normalizeCollectionOrders() {
        let availableLayouts = LayoutTemplate.allTemplates + customSnapLayouts
        let validLayoutIDs = Set(availableLayouts.map(\.id))
        var seenTargets = Set<String>()
        var seenShortcuts = Set<KeyboardShortcut>()
        snapZoneShortcuts = snapZoneShortcuts.filter { mapping in
            guard validLayoutIDs.contains(mapping.layoutID),
                  let layout = availableLayouts.first(where: { $0.id == mapping.layoutID }),
                  layout.zones.contains(where: { $0.id == mapping.zoneID }),
                  !mapping.shortcut.key.isEmpty else {
                return false
            }

            let targetKey = "\(mapping.layoutID.uuidString):\(mapping.zoneID.uuidString)"
            guard seenTargets.insert(targetKey).inserted,
                  seenShortcuts.insert(mapping.shortcut).inserted else {
                return false
            }
            return true
        }

        let allActivities = LiveActivityType.allCases
        liveActivityOrder = liveActivityOrder.filter { allActivities.contains($0) }.deduplicated()
        let missingActivities = allActivities.filter { !liveActivityOrder.contains($0) }
        if !missingActivities.isEmpty {
            liveActivityOrder.append(contentsOf: missingActivities)
        }

        let allWidgets = WidgetType.allCases
        widgetOrder = widgetOrder.filter { allWidgets.contains($0) }.deduplicated()
        let missingWidgets = allWidgets.filter { !widgetOrder.contains($0) }
        if !missingWidgets.isEmpty {
            widgetOrder.append(contentsOf: missingWidgets)
        }

        let allNotchButtons = NotchButtonType.allCases
        notchButtonOrder = notchButtonOrder.filter { allNotchButtons.contains($0) }.deduplicated()
        if !notchButtonOrder.contains(.continuity) {
            if let batteryIndex = notchButtonOrder.firstIndex(of: .battery) {
                notchButtonOrder.insert(.continuity, at: batteryIndex)
            }
        }
        let missingNotchButtons = allNotchButtons.filter { !notchButtonOrder.contains($0) }
        if !missingNotchButtons.isEmpty {
            if let spacerIndex = notchButtonOrder.firstIndex(of: .spacer) {
                notchButtonOrder.insert(contentsOf: missingNotchButtons, at: spacerIndex)
            } else {
                notchButtonOrder.append(contentsOf: missingNotchButtons)
            }
        }
    }

    func currentSportsFavoriteTeam() -> String? {
        guard !sportsFavoriteTeams.isEmpty else { return nil }
        let index = max(0, min(sportsFavoriteTeamIndex, sportsFavoriteTeams.count - 1))
        return sportsFavoriteTeams[index]
    }

    func currentFinanceFavoriteSymbol() -> String? {
        guard !financeFavoriteSymbols.isEmpty else { return nil }
        let index = max(0, min(financeFavoriteSymbolIndex, financeFavoriteSymbols.count - 1))
        return financeFavoriteSymbols[index]
    }

    func currentSportsTeam() -> String? {
        currentSportsFavoriteTeam()
    }

    func currentFinanceSymbol() -> String? {
        currentFinanceFavoriteSymbol()
    }

    var swipeActionSettings: SwipeActionSettings = .init()
    var swipeToDismissLiveActivity: Bool = true
    var fullScreenActivityVisibility: FullScreenActivityVisibility = .showAll
    var hideNotchInFullScreen: Bool = false
    var hideLyricsInFullScreen: Bool = true
    var hideActivitiesInFullScreen: [String: Bool] = [:]
    var showPersistentStatsLiveActivity: Bool = false
    var showPersistentBatteryLiveActivity: Bool = false
    var showPersistentWeatherLiveActivity: Bool = true
    var weatherLiveActivityInterval: Int = 10
    var focusDisplayMode: FocusDisplayMode = .full
    var mediaSource: MediaSource = .system
    var prioritizeMediaSource: Bool = true
    var mediaAppVisibility: [String: Bool] = [:]
    var hideLiveActivityWhenSourceActive: Bool = true
    var enableQuickPeekOnHover: Bool = true
    var showQuickPeekOnTrackChange: Bool = true
    var swipeToSkipMusic: Bool = true
    var swipeToRewindMusic: Bool = true
    var invertMusicGestures: Bool = false
    var twoFingerTapToPauseMusic: Bool = true
    var musicHoldSkipForSecondaryActions: Bool = true
    var musicLongPressActionsEnabled: Bool = true
    var musicLongPressPrevious: MusicLongPressAction = .none
    var musicLongPressNext: MusicLongPressAction = .none
    var musicLongPressPlayPause: MusicLongPressAction = .none
    var musicLongPressPlaylists: MusicLongPressAction = .openDevices
    var musicLongPressDevices: MusicLongPressAction = .openQueue
    var musicLongPressLike: MusicLongPressAction = .shuffle
    var musicLongPressShuffle: MusicLongPressAction = .repeatMode
    var musicLongPressRepeat: MusicLongPressAction = .like
    var waveformUseGradient: Bool = true
    var useStaticWaveform: Bool = false
    var waveformBarCount: Int = 3
    var waveformBarThickness: Double = 4.0
    var musicWaveformIsVolumeSensitive: Bool = false
    var spotifyClientId: String {
        get { APIKeyManager.shared.spotifyClientId }
        set { APIKeyManager.shared.spotifyClientId = newValue }
    }
    var spotifyClientSecret: String {
        get { APIKeyManager.shared.spotifyClientSecret }
        set { APIKeyManager.shared.spotifyClientSecret = newValue }
    }
    var skipSpotifyAd: Bool = false
    var spotifyAPIMode: SpotifyAPIMode = .privateAPI
    var defaultMusicPlayer: DefaultMusicPlayer = .appleMusic
    var showLyricsInLiveActivity: Bool = false
    var enableLyricTranslation: Bool = true
    var lyricTranslationLanguage: String = "en"
    var lyricOffset: Double = 0.0
    var generateWordTimedLyrics: Bool = false
    var musicAppStates: [String: Bool] = [:]
    var musicOpenOnClick: Bool = true
    var musicPlayerButtonOrder: [MusicPlayerButtonType] = [.playlists, .devices, .like, .shuffle, .repeat]
    var musicLikeButtonEnabled: Bool = false
    var musicShuffleButtonEnabled: Bool = false
    var musicRepeatButtonEnabled: Bool = false
    var musicPlaylistsButtonEnabled: Bool = true
    var musicDevicesButtonEnabled: Bool = true
    var showPopularityInMusicPlayer: Bool = true
    var hideMusicWidgetWhenNotPlaying: Bool = false
    var hideMusicWidgetWhenSpotifyPausedAndIdle: Bool = false
    var hideSpotifyWidgetWhenAppClosed: Bool = false
    var persistMusicWidgetWhenPaused: Bool = true
    var preferAirPlayOverSpotify: Bool = true
    var spotifyCanvasLiveVideo: Bool = true
    var showSpotifySourceTab: Bool = true
    var spotifyShowArtistProfile: Bool = true
    var spotifyShowSuggestedSongs: Bool = true
    var spotifyShowNextSong: Bool = true
    var spotifyShowNextSongAlbumArt: Bool = true
    var spotifyShowConcertTickets: Bool = false
    var spotifyShowAccountBadge: Bool = true

    var hudDuration: Double = 2.5
    var hudShowPercentage: Bool = true
    var hudShowFunctionName: Bool = false
    var hudVisualStyle: HUDVisualStyle = .adaptive
    var hudCustomColor: CodableColor? = CodableColor(color: .accentColor)
    var hudAdaptiveTransitionStyle: HUDAdaptiveTransitionStyle = .smooth
    var hudAdaptiveColor1: CodableColor = CodableColor(color: .cyan)
    var hudAdaptiveColor2: CodableColor = CodableColor(color: .purple)
    var hudAdaptiveColor3: CodableColor = CodableColor(color: .pink)
    var hudAdaptiveThreshold1: Double = 0.49
    var hudAdaptiveThreshold2: Double = 0.74
    var enableVolumeHUD: Bool = true
    var volumeHUDStyle: HUDStyle = .default
    var volumeHUDShowDots: Bool = false
    var volumeHUDSoundEnabled: Bool = true
    var showSpotifyVolumeHUD: Bool = true
    var showAppVolumeHUD: Bool = true
    var showAppVolumeInNormalHUD: Bool = false
    var perAppVolumeSystemDependent: Bool = true
    var volumeHUDShowDeviceIcon: Bool = true
    var excludeBuiltInSpeakersFromHUDIcon: Bool = true
    var enableBrightnessHUD: Bool = true
    var brightnessHUDStyle: HUDStyle = .default
    var brightnessHUDShowDots: Bool = false
    var hudPillPosition: PillHUDPosition = .right
    var hudPillStyle: PillHUDStyle = .contained
    var hudPillLength: Double = 340
    var hudPillThickness: Double = 64
    var volumesliderstep: Int = 6
    var volumesliderstepByDevice: [String: Int] = [:]
    var brightnessliderstep: Int = 6
    var brightnessKeyStep: BrightnessKeyStep = .full
    var displayExtraDimming: Bool = false

    var effectiveVolumeHUDStyle: HUDStyle { volumeHUDShowDots ? .dots : volumeHUDStyle }
    var effectiveBrightnessHUDStyle: HUDStyle { brightnessHUDShowDots ? .dots : brightnessHUDStyle }
    var snapZoneViewMode: SnapZoneViewMode = .multi
    var snapDragEnabled: Bool = true
    var snapOnWindowDragEnabled: Bool = true
    var snapActivationDelay: Double = 0.45
    var snapWindowAnimation: SnapWindowAnimation = .fast
    var defaultSnapLayout: SnapLayout = LayoutTemplate.columns
    var appSpecificLayoutConfigurations: [String: AppSnapLayoutConfiguration] = [:]
    var customSnapLayouts: [SnapLayout] = []
    var snapZoneLayoutOptions: [UUID] = [LayoutTemplate.fancy.id, LayoutTemplate.quarters.id, LayoutTemplate.splitscreen.id, LayoutTemplate.focus.id, LayoutTemplate.fullscreen.id]
    var snapZoneShortcuts: [SnapZoneShortcut] = []
    var planes: [Plane] = []

    // MARK: - Per-shortcut disabling (Keyboard Shortcuts page)

    var disabledShortcutIDs: Set<String> = []
    var batteryChargeLimit: Int = 100
    var lowBatteryNotificationPercentage: Int = 20
    var lowBatteryNotificationSoundEnabled: Bool = true
    var batteryNotificationStyle: BatteryNotificationStyle = .default
    var promptForLowPowerMode: Bool = true
    var showEstimatedBatteryTime: Bool = true
    var automaticDischargeEnabled: Bool = true
    var heatProtectionEnabled: Bool = true
    var heatProtectionThreshold: Double = 40.0
    var sailingModeEnabled: Bool = true
    var sailingModeLowerLimit: Int = 10
    var useHardwareBatteryPercentage: Bool = false
    var controlMagSafeLEDEnabled: Bool = true
    var stopChargingWhenSleeping: Bool = false
    var logBatteryDuringSleep: Bool = false
    var sleepLoggingIntervalMinutes: Int = 30
    var dischargeToLimitEnabled: Bool = false
    var oneTimeDischargeEnabled: Bool = false
    var oneTimeDischargeTarget: Int = 20
    var manualChargePaused: Bool = false
    var disableSleepUntilChargeLimit: Bool = false
    var lowPowerMode: LowPowerMode = .never
    var scheduledTasks: [ScheduledTask] = []
    var stopChargingWhenAppClosed: Bool = false
    var magSafeLEDBlinkOnDischarge: Bool = false
    var magSafeLEDSetting: MagSafeLEDSetting = .alwaysOn
    var preventSleepDuringCalibration: Bool = false
    var preventSleepDuringDischarge: Bool = false
    var fanControlModes: [String: StoredFanControlMode] = [:]
    var enableBiweeklyCalibration: Bool = false
    var magSafeGreenAtLimit: Bool = true
    var bluetoothNotifyLowBattery: Bool = true
    var bluetoothNotifySound: Bool = true
    var showBluetoothDeviceName: Bool = false
    var bluetoothLiveActivityEnabled: Bool = true
    var showBluetoothContinuityDevices: Bool = true
    var bluetoothUnlockEnabled: Bool = false
    var bluetoothUnlockDeviceID: String? = nil
    var bluetoothUnlockUnlockRSSI: Int = -65
    var bluetoothUnlockLockRSSI: Int = -75
    var bluetoothUnlockTimeout: Double = 5.0
    var bluetoothUnlockNoSignalTimeout: Double = 60.0
    var bluetoothUnlockMinScanRSSI: Int = -80
    var bluetoothUnlockPassiveMode: Bool = false
    var faceIDUnlockEnabled: Bool = false
    var faceIDLocationPolicy: FaceIDLocationPolicy = .everywhere
    var faceIDAllowedWiFiNetworks: [String] = []
    var faceIDAntiSpoofEnabled: Bool = true
    var hasRegisteredFaceID: Bool = false
    var faceIDSpoofLockDuration: Double = 3.0
    var faceIDAntiSpoofAcceptThreshold: Double = 0.50
    var faceIDMismatchTimeout: Double = 30.0
    var faceIDKeepModelsInMemory: Bool = true
    var bluetoothUnlockWakeOnProximity: Bool = true
    var bluetoothUnlockWakeWithoutUnlocking: Bool = false
    var bluetoothUnlockPauseMusicOnLock: Bool = false
    var bluetoothUnlockUseScreensaver: Bool = false
    var bluetoothUnlockTurnOffScreenOnLock: Bool = true
    var masterNotificationsEnabled: Bool = true
    var iMessageNotificationsEnabled: Bool = true
    var airDropNotificationsEnabled: Bool = true
    var faceTimeNotificationsEnabled: Bool = true
    var systemNotificationsEnabled: Bool = true
    var appNotificationStates: [String: Bool] = [:]
    var onlyShowVerificationCodeNotifications: Bool = true
    var showCopyButtonForVerificationCodes: Bool = true
    var smartInboxEnabled: Bool = true
    var mailOTPDetectionEnabled: Bool = true
    var autoCopyVerificationCodes: Bool = false
    var parcelTrackingEnabled: Bool = true
    var parcelLiveActivityEnabled: Bool = true
    var otpLiveActivityEnabled: Bool = true
    var nearbyShareEnabled: Bool = true
    var nearbyShareDeviceDisplayName: String = Host.current().localizedName ?? "我的 Mac"
    var nearbyShareDownloadLocationPath: String = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!.path
    var nearbyShareOpenOnClick: Bool = true

    // MARK: Android ⇄ Mac Continuity (see Sapphire/Services/Continuity)
    var continuityEnabled: Bool = false
    var continuityClipboardSync: Bool = true
    var continuityClipboardImages: Bool = true
    var continuityClipboardFiles: Bool = true
    var continuityNotifications: Bool = true
    var continuityNotificationsAsBanners: Bool = false
    var continuityNotificationsGeneral: Bool = false
    var continuityNotificationsSystem: Bool = false
    var continuityExternalLiveActivities: Bool = true
    var continuityPhoneMediaInMusicPlayer: Bool = true
    var continuityPhoneMediaLiveActivityEnabled: Bool = true
    var continuityPhoneMediaLyricsInLiveActivity: Bool = false
    var continuityHandoffToPhone: Bool = true
    var continuityCameraSystemDevice: Bool = true
    var continuityMic: Bool = true
    var continuityHandoffDiagnostics: Bool = false
    var continuityHandoffExperimentalApps: Bool = false
    var continuityBlockIPhoneMirroring: Bool = false
    var continuitySyncNotificationMode: Bool = true
    var continuitySyncFocusSessionStatus: Bool = true
    var continuitySyncFocusSessionSettings: Bool = false
    var continuitySyncFocus: Bool = true
    var continuityMediaControls: Bool = true
    var continuityShowPhoneBattery: Bool = true
    var continuityStatusLiveActivityEnabled: Bool = true
    var continuityHotspot: Bool = true
    var continuityFiles: Bool = true
    var continuityHandoff: Bool = true
    var continuityCamera: Bool = true
    var continuityScan: Bool = true
    var continuitySketch: Bool = true
    var continuityMirroring: Bool = true
    var continuitySidecar: Bool = false
    var continuityAskDeviceForMirrorExtend: Bool = true
    var continuityUniversalControl: Bool = false
    var continuityUniversalControlEdge: String = "right"
    var continuityUniversalControlNativeInput: Bool = true
    var continuityAudioCast: Bool = true
    var continuityWidgets: Bool = true
    var continuitySMS: Bool = false
    var continuityHotspotDataLink: Bool = false
    var continuityPhotoAutoSync: Bool = true
    var continuityPhotoAutoAlbumId: String = ""
    var continuityFinderPhotoAlbum: Bool = false
    var continuityFinderDisk: Bool = false
    var continuityEarbudHandoff: Bool = true
    var continuityEarbudPrioritizeLatest: Bool = true
    var continuityCloudflareRelay: Bool = true
    var continuityRemoteAccess: Bool = true

    var clickToOpenFileShelf: Bool = true
    var hoverToOpenFileShelf: Bool = true
    var removeFileFromShelfAfterDrag: Bool = false
    var fileShelfAirDropDestinationEnabled: Bool = false
    var fileShelfDeviceDestinationsEnabled: Bool = true
    var launchpadLayout: [[LaunchpadPageItem]] = []
    var weatherUseCelsius: Bool = false
    var weatherUseMetricSystem: Bool = false
    var weatherOpenOnClick: Bool = false
    var calendarShowAllDayEvents: Bool = true
    var calendarStartOfWeek: Day = .sunday
    var calendarOpenOnClick: Bool = true
    var eyeBreakWorkInterval: Double = 20
    var eyeBreakBreakDuration: Double = 20
    var eyeBreakSoundAlerts: Bool = true
    var eyeBreakPauseDuringGameMode: Bool = false
    var showEyeBreakGraph: Bool = true
    var clickToShowTimerView: Bool = true
    var sleepInClamshell: Bool = true
    var persistentCaffeinateAfterClamshell: Bool = false
    var caffeinateTimeoutMinutes: Double = 0
    var caffeinateTurnOffScreenUsingLidAngle: Bool = false
    var caffeinateLidAngleTrigger: Double = 15.0
    var caffeinateAutoDuringTasks: Bool = false
    var caffeinateAutoTaskGrace: Double = 120
    var caffeinateAutoTaskKinds: Set<String> = ["ai", "build"]
    var caffeinateWhileAppsRun: Bool = false
    var caffeinateTriggerAppBundleIDs: [String] = []
    var caffeinateWhileOnACPower: Bool = false
    var caffeinateWhileExternalDisplay: Bool = false
    var caffeinatePauseTriggersWhenLocked: Bool = false

    // MARK: - Developer Activity

    var devActivityEnabled: Bool = false
    var devActivityKinds: Set<String> = ["ai", "build", "command"]
    var devActivityDetectIDEAgents: Bool = true
    var devActivitySensitivity: Double = 1.0
    var devActivityHighPriority: Bool = false
    var devActivityOpenOnClick: Bool = true
    var devWidgetEnabled: Bool = false
    var lidAnglePauseMediaEnabled: Bool = false
    var lidAnglePauseMediaTrigger: Double = 18.0
    var lidAngleMuteAudioEnabled: Bool = false
    var lidAngleMuteAudioTrigger: Double = 14.0
    var lidAngleSleepDisplayEnabled: Bool = false
    var lidAngleSleepDisplayTrigger: Double = 12.0
    var lidAngleLowPowerModeEnabled: Bool = false
    var lidAngleLowPowerModeTrigger: Double = 35.0

    var menuBarEnabled: Bool = false
    var menuBarProfilesEnabled: Bool = false
    var menuBarProfiles: [MenuBarProfile] = []

    var showOnlyRunningAppsInDock: Bool = false

    var showOnClick: Bool = true
    var showOnHover: Bool = true
    var showOnHoverDelay: TimeInterval = 0.4
    var autoRehide: Bool = true
    var rehideStrategy: String = "smart"
    var tempShowInterval: TimeInterval = 5.0
    var hideMenuBarIcon: Bool = false
    var showSectionDividers: Bool = true
    var enableAlwaysHiddenSection: Bool = true
    var controlItemIconStyle: ControlItemIconStyle = .chevron
    var showOnScroll: Bool = true
    var hideAppMenusWhenShowingItems: Bool = false
    var showAlwaysHiddenOnDoubleClick: Bool = false
    var menuBarUseHiddenItemsBar: Bool = false
    var menuBarKeepOpenedItemsDelay: TimeInterval = 0
    var menuBarAutoZenWhilePresenting: Bool = false
    var menuBarAutoZenWhileCameraInUse: Bool = false
    var menuBarToggleHiddenShortcut: KeyboardShortcut = KeyboardShortcut(key: "", modifiers: [])
    var menuBarToggleAlwaysHiddenShortcut: KeyboardShortcut = KeyboardShortcut(key: "", modifiers: [])
    var menuBarSearchShortcut: KeyboardShortcut = KeyboardShortcut(key: "", modifiers: [])
    var menuBarZenModeShortcut: KeyboardShortcut = KeyboardShortcut(key: "", modifiers: [])
    var menuBarAdaptiveTintGradient: Bool = false

    var menuBarTintStyle: String = "none"
    var menuBarSolidColor: CodableColor = CodableColor(color: .blue)
    var menuBarGradientColors: [CodableColor] = [
        CodableColor(color: .blue, location: 0.0),
        CodableColor(color: .purple, location: 1.0)
    ]
    var menuBarGradientAngle: Double = 90.0
    var menuBarOpacity: Double = 1.0
    var menuBarBlur: Bool = false
    var menuBarLiquidGlass: Bool = false
    var menuBarLiquidGlassStyle: LiquidGlassMaterial = .frosted

    var menuBarBorderWidth: CGFloat = 0.0
    var menuBarBorderColor: CodableColor = CodableColor(color: .black)
    var menuBarShadowEnabled: Bool = false

    var menuBarShapeStyle: String = "none"
    var menuBarCornerRadius: CGFloat = 16.0

    var roundedCornersTop: Bool = false
    var roundedCornersBelowMenu: Bool = false
    var roundedCornersBottom: Bool = false
    var screenCornerRadius: CGFloat = 16.0
    var menuBarVerticalPadding: CGFloat = 0.0
    var menuBarSpacing: Int = 1
    var menuBarSelectionPadding: Int = 1

}

struct SettingsBackupPayload: Codable {
    let appName: String
    let schemaVersion: Int
    let exportedAt: Date
    let settings: Settings

    init(settings: Settings, exportedAt: Date = .now) {
        self.appName = "Sapphire"
        self.schemaVersion = 1
        self.exportedAt = exportedAt
        self.settings = settings
    }
}

struct SettingsBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.sapphireSettingsBackup, .json] }

    var payload: SettingsBackupPayload

    init(settings: Settings) {
        self.payload = SettingsBackupPayload(settings: settings)
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }

        self.payload = try Self.decodePayload(from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        return FileWrapper(regularFileWithContents: try encoder.encode(payload))
    }

    static func decodePayload(from data: Data) throws -> SettingsBackupPayload {
        let decoder = JSONDecoder()

        if let payload = try? decoder.decode(SettingsBackupPayload.self, from: data) {
            return payload
        }

        if let settings = SettingsPersistence.decodeFromPayload(data) {
            return SettingsBackupPayload(settings: settings)
        }

        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: [],
                debugDescription: "The file could not be read as a Sapphire settings backup."
            )
        )
    }
}

enum ControlItemIconStyle: String, Codable, CaseIterable, Identifiable {
    case chevron = "chevron"
    case arrow = "arrow"
    case dot = "dot"
    case line = "line"
    case bracket = "bracket"
    case circle = "circle"
    case triangle = "triangle"
    case diamond = "diamond"
    case squareFilled = "squareFilled"
    case ellipsis = "ellipsis"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chevron: return "尖角箭头"
        case .arrow: return "箭头"
        case .dot: return "圆点"
        case .line: return "斜线"
        case .bracket: return "花括号"
        case .circle: return "圆环"
        case .triangle: return "三角形"
        case .diamond: return "菱形"
        case .squareFilled: return "方形"
        case .ellipsis: return "省略号"
        }
    }

    func symbolName(isHidden: Bool) -> String {
        switch self {
        case .chevron:
            return isHidden ? "chevron.compact.right" : "chevron.compact.left"

        case .arrow:
            return isHidden ? "arrow.right" : "arrow.left"

        case .dot:
            return isHidden ? "circle" : "circle.fill"

        case .line:
            return isHidden ? "line.diagonal" : "line.diagonal.arrow"

        case .bracket:
            return "curlybraces"

        case .circle:
            return isHidden ? "circle" : "circle.fill"

        case .triangle:
            return isHidden ? "arrowtriangle.right" : "arrowtriangle.right.fill"

        case .diamond:
            return isHidden ? "diamond" : "diamond.fill"

        case .squareFilled:
            return isHidden ? "square" : "square.fill"

        case .ellipsis:
            return "ellipsis"
        }
    }

    var previewSymbol: String {
        return symbolName(isHidden: false)
    }
}

// MARK: - Settings Persistence Helpers

enum SettingsPersistence {
    static let payloadKey = "sapphire.settings.payload"
    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
    static let decoder = JSONDecoder()

    static let legacyAPIKeyUserDefaultsKeys: Set<String> = [
        "geminiAPIKey",
        "intelligenceApiKey",
        "hackClubAPIKey",
        "openAIAPIKey",
        "anthropicAPIKey",
        "openRouterAPIKey",
        "xaiAPIKey",
        "nvidiaAPIKey",
        "spotifyClientId",
        "spotifyClientSecret",
        "geminiApiKey",
        "agentSApiKey",
    ]

    static let settingsFileName = "settings.json"
    static let settingsBackupFileName = "settings.backup.json"

    static var directoryURL: URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sapphire", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static var fileURL: URL { directoryURL.appendingPathComponent(settingsFileName) }
    static var backupURL: URL { directoryURL.appendingPathComponent(settingsBackupFileName) }

    static func purgeLegacyAPIKeyUserDefaults() {
        let defaults = UserDefaults.standard
        for key in legacyAPIKeyUserDefaultsKeys {
            defaults.removeObject(forKey: key)
        }
    }

    static func encodeToDictionary(_ settings: Settings) -> [String: Any]? {
        guard let data = try? encoder.encode(settings),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object
    }

    static func decodeFromDictionary(_ dictionary: [String: Any]) -> Settings? {
        decodeDictionaryTolerantly(dictionary)
    }

    static func decodeStrictly(_ dictionary: [String: Any]) -> Settings? {
        decodeFromJSONDictionary(dictionary)
    }

    static func decodeFromPayload(_ data: Data) -> Settings? {
        decodeFromPayloadReportingTolerance(data)?.settings
    }

    static func decodeFromPayloadReportingTolerance(_ data: Data) -> (settings: Settings, decodedTolerantly: Bool)? {
        if var settings = try? decoder.decode(Settings.self, from: data) {
            settings.normalizeCollectionOrders()
            return (settings, false)
        }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        let settingsDictionary: [String: Any]
        if let wrapped = object["settings"] as? [String: Any] {
            settingsDictionary = wrapped
        } else {
            settingsDictionary = object
        }
        return decodeFromDictionary(settingsDictionary).map { ($0, true) }
    }

    // MARK: - Tolerant decoding

    private static func decodeDictionaryTolerantly(_ dictionary: [String: Any]) -> Settings? {
        var dictionary = dictionary
        if dictionary["systemEnhanceDockClicksAllAppsEnabled"] == nil,
           dictionary["systemEnhanceDockClicksSelectedApps"] != nil {
            dictionary["systemEnhanceDockClicksAllAppsEnabled"] = false
        }
        migrateLegacyGlassIntensity(in: &dictionary, from: "lockScreenLiquidGlassIntensity", to: "lockScreenLiquidGlassStyle")
        migrateLegacyGlassIntensity(in: &dictionary, from: "menuBarLiquidGlassIntensity", to: "menuBarLiquidGlassStyle")
        migrateLockScreenGlassStyle(in: &dictionary)
        migrateFullScreenVisibility(in: &dictionary)
        migrateClipboardHistoryRetention(in: &dictionary)
        for key in ["notchWidgetAppearance", "notchLiveActivityAppearance"] {
            guard var appearance = dictionary[key] as? [String: Any] else { continue }
            migrateLegacyGlassIntensity(in: &appearance, from: "liquidGlassIntensity", to: "liquidGlassStyle")
            dictionary[key] = appearance
        }
        if let settings = decodeFromJSONDictionary(dictionary) {
            return settings
        }
        guard let defaults = encodeToDictionary(Settings()) else { return nil }

        var merged = defaults
        var droppedKeys: [String] = []
        let entries: [(key: String, value: Any)] = dictionary.keys.sorted().compactMap { key in
            guard let incomingValue = dictionary[key] else { return nil }
            let value: Any
            if let incomingDict = incomingValue as? [String: Any],
               let defaultDict = defaults[key] as? [String: Any] {
                value = deepMergedDictionary(defaults: defaultDict, incoming: incomingDict)
            } else {
                value = incomingValue
            }
            return (key, value)
        }
        applyCompatibleEntries(entries[...], to: &merged, droppedKeys: &droppedKeys)
        if !droppedKeys.isEmpty {
            print("[SettingsModel] Settings import: reverted incompatible keys to defaults: \(droppedKeys.sorted())")
        }
        return decodeFromJSONDictionary(merged)
    }

    private static func applyCompatibleEntries(
        _ entries: ArraySlice<(key: String, value: Any)>,
        to merged: inout [String: Any],
        droppedKeys: inout [String]
    ) {
        guard !entries.isEmpty else { return }

        var candidate = merged
        for entry in entries {
            candidate[entry.key] = entry.value
        }
        if decodeFromJSONDictionary(candidate) != nil {
            merged = candidate
            return
        }

        guard entries.count > 1 else {
            if let entry = entries.first { droppedKeys.append(entry.key) }
            return
        }

        let midpoint = entries.index(entries.startIndex, offsetBy: entries.count / 2)
        applyCompatibleEntries(entries[..<midpoint], to: &merged, droppedKeys: &droppedKeys)
        applyCompatibleEntries(entries[midpoint...], to: &merged, droppedKeys: &droppedKeys)
    }

    private static func migrateClipboardHistoryRetention(in dictionary: inout [String: Any]) {
        guard dictionary["clipboardHistoryRetentionVersion"] == nil else { return }
        if dictionary["clipboardHistoryUnlimited"] == nil {
            dictionary["clipboardHistoryUnlimited"] = true
        }
        if dictionary["clipboardHistoryLimit"] == nil {
            dictionary["clipboardHistoryLimit"] = 0
        }
        dictionary["clipboardHistoryRetentionVersion"] = 1
    }

    private static func migrateLegacyGlassIntensity(
        in dictionary: inout [String: Any],
        from legacyKey: String,
        to styleKey: String
    ) {
        guard let legacyValue = dictionary.removeValue(forKey: legacyKey),
              dictionary[styleKey] == nil,
              let intensity = legacyValue as? Double else { return }
        dictionary[styleKey] = LiquidGlassMaterial.migrating(fromLegacyIntensity: intensity).rawValue
    }

    private static func migrateFullScreenVisibility(in dictionary: inout [String: Any]) {
        let legacyHideAll = dictionary.removeValue(forKey: "hideLiveActivityInFullScreen") as? Bool
        guard dictionary["fullScreenActivityVisibility"] == nil else { return }
        let hidesSome = (dictionary["hideActivitiesInFullScreen"] as? [String: Bool])?.values.contains(true) ?? false
        let visibility: FullScreenActivityVisibility = legacyHideAll == true ? .hideAll : (hidesSome ? .hideSelected : .showAll)
        dictionary["fullScreenActivityVisibility"] = visibility.rawValue
    }

    private static func migrateLockScreenGlassStyle(in dictionary: inout [String: Any]) {
        let legacyStyle = dictionary.removeValue(forKey: "lockScreenLiquidGlassStyle") as? String
        dictionary.removeValue(forKey: "lockScreenFrostedOverLiquidGlass")
        guard dictionary["lockScreenGlass"] == nil,
              let legacyStyle,
              legacyStyle != LiquidGlassMaterial.widgets.rawValue,
              let material = LiquidGlassMaterial(rawValue: legacyStyle) else { return }
        var options = LiquidGlassOptions.lockScreenDefault
        options.material = material
        if let data = try? JSONEncoder().encode(options),
           let object = try? JSONSerialization.jsonObject(with: data) {
            dictionary["lockScreenGlass"] = object
        }
    }

    private static func decodeFromJSONDictionary(_ dictionary: [String: Any]) -> Settings? {
        guard JSONSerialization.isValidJSONObject(dictionary),
              let data = try? JSONSerialization.data(withJSONObject: dictionary),
              var settings = try? decoder.decode(Settings.self, from: data) else {
            return nil
        }
        settings.normalizeCollectionOrders()
        return settings
    }

    private static func deepMergedDictionary(defaults: [String: Any], incoming: [String: Any]) -> [String: Any] {
        var result = defaults
        for (key, incomingValue) in incoming {
            if let incomingDict = incomingValue as? [String: Any],
               let defaultDict = result[key] as? [String: Any] {
                result[key] = deepMergedDictionary(defaults: defaultDict, incoming: incomingDict)
            } else {
                result[key] = incomingValue
            }
        }
        return result
    }

    static func isJSONCompatible(_ value: Any) -> Bool {
        if value is String || value is Bool || value is NSNull { return true }
        if value is Int || value is Double || value is Float { return true }
        if value is NSNumber { return true }
        if let array = value as? [Any] { return array.allSatisfy(isJSONCompatible) }
        if let dictionary = value as? [String: Any] { return dictionary.values.allSatisfy(isJSONCompatible) }
        if let array = value as? NSArray { return array.allSatisfy { isJSONCompatible($0) } }
        if let dictionary = value as? NSDictionary {
            return dictionary.allKeys.allSatisfy { $0 is String } && dictionary.allValues.allSatisfy { isJSONCompatible($0) }
        }
        return false
    }

    static func loadImportedSettingsSnapshot() -> Settings? {
        for url in [fileURL, backupURL] {
            guard FileManager.default.fileExists(atPath: url.path),
                  let data = try? Data(contentsOf: url),
                  let settings = decodeFromPayload(data) else {
                continue
            }
            return settings
        }
        return nil
    }

    static func removeImportedSettingsSnapshots() {
        try? FileManager.default.removeItem(at: fileURL)
        try? FileManager.default.removeItem(at: backupURL)
    }
}

struct EventHandlingSettingsSnapshot {
    let clipboardFinderCutPasteEnabled: Bool
    let clipboardFinderPasteImagesAsPNG: Bool
    let clipboardFinderF2RenameEnabled: Bool
    let snippetsEnabled: Bool
    let snippetsExpandAfterSpace: Bool
    let snippetByTrigger: [String: SnippetEntry]

    let enableVolumeHUD: Bool
    let enableBrightnessHUD: Bool

    let mouseControlEnabled: Bool
    let mouseInvertScroll: Bool
    let mouseInvertHorizontalScroll: Bool
    let mouseScrollSpeed: Double
    let mouseMiddleButtonAction: MouseButtonAction
    let mouseButton4Action: MouseButtonAction
    let mouseButton5Action: MouseButtonAction
    let mouseMiddleModifiedAction: MouseButtonAction
    let mouseButton4ModifiedAction: MouseButtonAction
    let mouseButton5ModifiedAction: MouseButtonAction
    let mouseModifierButtonEnabled: Bool
    let mouseModifierButtonNumber: Int
    let mouseModifierSelection: MouseModifierSelection
    let mouseExtraClickFilterEnabled: Bool
    let mouseExtraClickFilterInterval: Double
    let mouseExcludedAppBundleIDs: Set<String>
    let mouseLinearScrollEnabled: Bool
    let mouseLinearScrollLines: Double
    let mouseHorizontalScrollModifierRaw: String
    let mouseSmoothScrollEnabled: Bool
    let mouseSmoothScrollSpeed: Double
    let mouseSmoothScrollResponse: Double

    let systemEnhanceGreenMaximizeEnabled: Bool
    let systemEnhanceQuitProtectionEnabled: Bool
    let systemEnhanceQuitProtectionProtectQuit: Bool
    let systemEnhanceQuitProtectionProtectClose: Bool
    let systemEnhanceQuitProtectionHoldInterval: Double
    let systemEnhanceQuitProtectionDoublePressInterval: Double
    let systemEnhanceQuitProtectionExcludedApps: Set<String>
    let systemEnhanceQuitProtectionMode: SEQuitProtectionMode
    let systemEnhanceQuitProtectionExtraModifier: SEQuitProtectionExtraModifier
    let systemEnhanceQuitProtectionCloseModeRaw: String
    let systemEnhanceQuitProtectionCloseHoldInterval: Double
    let systemEnhanceQuitProtectionCloseDoublePressInterval: Double
    let systemEnhanceQuitProtectionShowHUD: Bool
    let systemEnhanceDockClicksEnabled: Bool
    let systemEnhanceDockClicksAllAppsEnabled: Bool
    let systemEnhanceDockClicksSelectedApps: Set<String>
    let systemEnhanceDockClicksExcludedApps: Set<String>
    let systemEnhanceDockClickAction: SEDockClickAction

    func isDockClickEnabled(for bundleIdentifier: String) -> Bool {
        if systemEnhanceDockClicksAllAppsEnabled {
            return !systemEnhanceDockClicksExcludedApps.contains(bundleIdentifier)
        }
        return systemEnhanceDockClicksSelectedApps.contains(bundleIdentifier)
    }

    let keyboardDebounceEnabled: Bool
    let keyboardDebounceInterval: TimeInterval
    let superKeyEnabled: Bool
    let superKeyKey: SESuperKeyKey
    let superKeyCombo: SESuperKeyCombo
    let superKeyTapAction: SESuperKeyTapAction
    let superKeyExcludedAppBundleIDs: Set<String>
    let keyboardDebounceKeyIntervals: [UInt16: TimeInterval]

    static func hasSameInputs(_ lhs: Settings, _ rhs: Settings) -> Bool {
        hasSameClipboardInputs(lhs, rhs)
            && hasSameMouseInputs(lhs, rhs)
            && hasSameSystemEnhanceInputs(lhs, rhs)
            && hasSameKeyboardInputs(lhs, rhs)
            && lhs.enableVolumeHUD == rhs.enableVolumeHUD
            && lhs.enableBrightnessHUD == rhs.enableBrightnessHUD
    }

    private static func hasSameClipboardInputs(_ lhs: Settings, _ rhs: Settings) -> Bool {
        lhs.clipboardFinderCutPasteEnabled == rhs.clipboardFinderCutPasteEnabled
            && lhs.clipboardFinderPasteImagesAsPNG == rhs.clipboardFinderPasteImagesAsPNG
            && lhs.clipboardFinderF2RenameEnabled == rhs.clipboardFinderF2RenameEnabled
            && lhs.snippetsEnabled == rhs.snippetsEnabled
            && lhs.snippetsExpandAfterSpace == rhs.snippetsExpandAfterSpace
            && lhs.snippetsList == rhs.snippetsList
    }

    private static func hasSameMouseInputs(_ lhs: Settings, _ rhs: Settings) -> Bool {
        lhs.mouseControlEnabled == rhs.mouseControlEnabled
            && lhs.mouseInvertScroll == rhs.mouseInvertScroll
            && lhs.mouseInvertHorizontalScroll == rhs.mouseInvertHorizontalScroll
            && lhs.mouseScrollSpeed == rhs.mouseScrollSpeed
            && lhs.mouseMiddleButtonAction == rhs.mouseMiddleButtonAction
            && lhs.mouseButton4Action == rhs.mouseButton4Action
            && lhs.mouseButton5Action == rhs.mouseButton5Action
            && lhs.mouseMiddleModifiedAction == rhs.mouseMiddleModifiedAction
            && lhs.mouseButton4ModifiedAction == rhs.mouseButton4ModifiedAction
            && lhs.mouseButton5ModifiedAction == rhs.mouseButton5ModifiedAction
            && lhs.mouseModifierButtonEnabled == rhs.mouseModifierButtonEnabled
            && lhs.mouseModifierButtonNumber == rhs.mouseModifierButtonNumber
            && lhs.mouseModifierSelection == rhs.mouseModifierSelection
            && lhs.mouseExtraClickFilterEnabled == rhs.mouseExtraClickFilterEnabled
            && lhs.mouseExtraClickFilterInterval == rhs.mouseExtraClickFilterInterval
            && lhs.mouseExcludedAppBundleIDs == rhs.mouseExcludedAppBundleIDs
            && lhs.mouseLinearScrollEnabled == rhs.mouseLinearScrollEnabled
            && lhs.mouseLinearScrollLines == rhs.mouseLinearScrollLines
            && lhs.mouseHorizontalScrollModifierRaw == rhs.mouseHorizontalScrollModifierRaw
            && lhs.mouseSmoothScrollEnabled == rhs.mouseSmoothScrollEnabled
            && lhs.mouseSmoothScrollSpeed == rhs.mouseSmoothScrollSpeed
            && lhs.mouseSmoothScrollResponse == rhs.mouseSmoothScrollResponse
    }

    private static func hasSameSystemEnhanceInputs(_ lhs: Settings, _ rhs: Settings) -> Bool {
        lhs.systemEnhanceGreenMaximizeEnabled == rhs.systemEnhanceGreenMaximizeEnabled
            && lhs.systemEnhanceQuitProtectionEnabled == rhs.systemEnhanceQuitProtectionEnabled
            && lhs.systemEnhanceQuitProtectionProtectQuit == rhs.systemEnhanceQuitProtectionProtectQuit
            && lhs.systemEnhanceQuitProtectionProtectClose == rhs.systemEnhanceQuitProtectionProtectClose
            && lhs.systemEnhanceQuitProtectionHoldInterval == rhs.systemEnhanceQuitProtectionHoldInterval
            && lhs.systemEnhanceQuitProtectionDoublePressInterval == rhs.systemEnhanceQuitProtectionDoublePressInterval
            && lhs.systemEnhanceQuitProtectionExcludedApps == rhs.systemEnhanceQuitProtectionExcludedApps
            && lhs.systemEnhanceQuitProtectionMode == rhs.systemEnhanceQuitProtectionMode
            && lhs.systemEnhanceQuitProtectionExtraModifier == rhs.systemEnhanceQuitProtectionExtraModifier
            && lhs.systemEnhanceQuitProtectionCloseModeRaw == rhs.systemEnhanceQuitProtectionCloseModeRaw
            && lhs.systemEnhanceQuitProtectionCloseHoldInterval == rhs.systemEnhanceQuitProtectionCloseHoldInterval
            && lhs.systemEnhanceQuitProtectionCloseDoublePressInterval == rhs.systemEnhanceQuitProtectionCloseDoublePressInterval
            && lhs.systemEnhanceQuitProtectionShowHUD == rhs.systemEnhanceQuitProtectionShowHUD
            && lhs.systemEnhanceDockClicksEnabled == rhs.systemEnhanceDockClicksEnabled
            && lhs.systemEnhanceDockClicksAllAppsEnabled == rhs.systemEnhanceDockClicksAllAppsEnabled
            && lhs.systemEnhanceDockClicksSelectedApps == rhs.systemEnhanceDockClicksSelectedApps
            && lhs.systemEnhanceDockClicksExcludedApps == rhs.systemEnhanceDockClicksExcludedApps
            && lhs.systemEnhanceDockClickAction == rhs.systemEnhanceDockClickAction
    }

    private static func hasSameKeyboardInputs(_ lhs: Settings, _ rhs: Settings) -> Bool {
        lhs.keyboardDebounceEnabled == rhs.keyboardDebounceEnabled
            && lhs.keyboardDebounceInterval == rhs.keyboardDebounceInterval
            && lhs.superKeyEnabled == rhs.superKeyEnabled
            && lhs.superKeyKey == rhs.superKeyKey
            && lhs.superKeyCombo == rhs.superKeyCombo
            && lhs.superKeyTapAction == rhs.superKeyTapAction
            && lhs.superKeyExcludedAppBundleIDs == rhs.superKeyExcludedAppBundleIDs
            && lhs.keyboardDebounceKeyIntervals == rhs.keyboardDebounceKeyIntervals
    }

    init(settings: Settings) {
        clipboardFinderCutPasteEnabled = settings.clipboardFinderCutPasteEnabled
        clipboardFinderPasteImagesAsPNG = settings.clipboardFinderPasteImagesAsPNG
        clipboardFinderF2RenameEnabled = settings.clipboardFinderF2RenameEnabled
        snippetsEnabled = settings.snippetsEnabled
        snippetsExpandAfterSpace = settings.snippetsExpandAfterSpace
        var snippets = [String: SnippetEntry](minimumCapacity: settings.snippetsList.count)
        for entry in settings.snippetsList
            where entry.isEnabled && !entry.trigger.isEmpty && snippets[entry.trigger] == nil {
            snippets[entry.trigger] = entry
        }
        snippetByTrigger = snippets

        enableVolumeHUD = settings.enableVolumeHUD
        enableBrightnessHUD = settings.enableBrightnessHUD

        mouseControlEnabled = settings.mouseControlEnabled
        mouseInvertScroll = settings.mouseInvertScroll
        mouseInvertHorizontalScroll = settings.mouseInvertHorizontalScroll
        mouseScrollSpeed = settings.mouseScrollSpeed
        mouseMiddleButtonAction = settings.mouseMiddleButtonAction
        mouseButton4Action = settings.mouseButton4Action
        mouseButton5Action = settings.mouseButton5Action
        mouseMiddleModifiedAction = settings.mouseMiddleModifiedAction
        mouseButton4ModifiedAction = settings.mouseButton4ModifiedAction
        mouseButton5ModifiedAction = settings.mouseButton5ModifiedAction
        mouseModifierButtonEnabled = settings.mouseModifierButtonEnabled
        mouseModifierButtonNumber = settings.mouseModifierButtonNumber
        mouseModifierSelection = settings.mouseModifierSelection
        mouseExtraClickFilterEnabled = settings.mouseExtraClickFilterEnabled
        mouseExtraClickFilterInterval = settings.mouseExtraClickFilterInterval
        mouseExcludedAppBundleIDs = Set(settings.mouseExcludedAppBundleIDs)
        mouseLinearScrollEnabled = settings.mouseLinearScrollEnabled
        mouseLinearScrollLines = settings.mouseLinearScrollLines
        mouseHorizontalScrollModifierRaw = settings.mouseHorizontalScrollModifierRaw
        mouseSmoothScrollEnabled = settings.mouseSmoothScrollEnabled
        mouseSmoothScrollSpeed = settings.mouseSmoothScrollSpeed
        mouseSmoothScrollResponse = settings.mouseSmoothScrollResponse

        systemEnhanceGreenMaximizeEnabled = settings.systemEnhanceGreenMaximizeEnabled
        systemEnhanceQuitProtectionEnabled = settings.systemEnhanceQuitProtectionEnabled
        systemEnhanceQuitProtectionProtectQuit = settings.systemEnhanceQuitProtectionProtectQuit
        systemEnhanceQuitProtectionProtectClose = settings.systemEnhanceQuitProtectionProtectClose
        systemEnhanceQuitProtectionHoldInterval = settings.systemEnhanceQuitProtectionHoldInterval
        systemEnhanceQuitProtectionDoublePressInterval = settings.systemEnhanceQuitProtectionDoublePressInterval
        systemEnhanceQuitProtectionExcludedApps = Set(settings.systemEnhanceQuitProtectionExcludedApps)
        systemEnhanceQuitProtectionMode = settings.systemEnhanceQuitProtectionMode
        systemEnhanceQuitProtectionExtraModifier = settings.systemEnhanceQuitProtectionExtraModifier
        systemEnhanceQuitProtectionCloseModeRaw = settings.systemEnhanceQuitProtectionCloseModeRaw
        systemEnhanceQuitProtectionCloseHoldInterval = settings.systemEnhanceQuitProtectionCloseHoldInterval
        systemEnhanceQuitProtectionCloseDoublePressInterval = settings.systemEnhanceQuitProtectionCloseDoublePressInterval
        systemEnhanceQuitProtectionShowHUD = settings.systemEnhanceQuitProtectionShowHUD
        systemEnhanceDockClicksEnabled = settings.systemEnhanceDockClicksEnabled
        systemEnhanceDockClicksAllAppsEnabled = settings.systemEnhanceDockClicksAllAppsEnabled
        systemEnhanceDockClicksSelectedApps = Set(settings.systemEnhanceDockClicksSelectedApps)
        systemEnhanceDockClicksExcludedApps = Set(settings.systemEnhanceDockClicksExcludedApps)
        systemEnhanceDockClickAction = settings.systemEnhanceDockClickAction

        keyboardDebounceEnabled = settings.keyboardDebounceEnabled
        keyboardDebounceInterval = settings.keyboardDebounceInterval
        superKeyEnabled = settings.superKeyEnabled
        superKeyKey = settings.superKeyKey
        superKeyCombo = settings.superKeyCombo
        superKeyTapAction = settings.superKeyTapAction
        superKeyExcludedAppBundleIDs = Set(settings.superKeyExcludedAppBundleIDs)
        var debounceIntervals = [UInt16: TimeInterval](minimumCapacity: settings.keyboardDebounceKeyIntervals.count)
        for (key, interval) in settings.keyboardDebounceKeyIntervals {
            if let keyCode = UInt16(key) { debounceIntervals[keyCode] = interval }
        }
        keyboardDebounceKeyIntervals = debounceIntervals
    }
}

// MARK: - SettingsModel Class
final class SettingsModel: ObservableObject {
    static let shared = SettingsModel()

    private(set) var revision: UInt64 = 0

    private let snapshotLock = NSLock()
    private var eventHandlingSnapshot = EventHandlingSettingsSnapshot(settings: Settings())

    var eventHandlingSettings: EventHandlingSettingsSnapshot {
        snapshotLock.lock()
        defer { snapshotLock.unlock() }
        return eventHandlingSnapshot
    }

    private func publishSnapshot(_ value: Settings) {
        let snapshot = EventHandlingSettingsSnapshot(settings: value)
        snapshotLock.lock()
        eventHandlingSnapshot = snapshot
        snapshotLock.unlock()
    }

    private(set) var current = Settings()

    @StoredThenPublished var settings: Settings = Settings() {
        willSet {
            if !EventHandlingSettingsSnapshot.hasSameInputs(current, newValue) {
                publishSnapshot(newValue)
            }
            current = newValue
            revision &+= 1
        }
        didSet {
            SettingsObserver.shared.fieldTracker.didChange(from: oldValue, to: settings)
            guard !isApplyingLoadedSettings else { return }
            noteUserChangeWhileHoldingNewerPayload()
            if settings.volumeHUDSoundEnabled != oldValue.volumeHUDSoundEnabled {
                SystemSoundFeedback.isVolumeChangeFeedbackEnabled = settings.volumeHUDSoundEnabled
            }
            if Self.intelligenceRuntimePreferencesChanged(from: oldValue, to: settings) {
                applyIntelligenceRuntimePreferences(from: settings)
            }
            guard !settings.hasSameNormalizationInputs(as: oldValue) else {
                scheduleSaveSettings()
                return
            }
            var sanitized = settings
            sanitized.normalizeCollectionOrders()
            if !sanitized.hasSameNormalizedCollections(as: settings) {
                isApplyingLoadedSettings = true
                settings = sanitized
                isApplyingLoadedSettings = false
                scheduleSaveSettings()
                return
            }
            scheduleSaveSettings()
        }
    }

    // MARK: High-frequency runtime state
    private static let brightnessKey = "runtime.brightness"
    static let animationProfileKey = "sapphire.settings.animationProfile"
    private static let notchNavigationStackKey = "runtime.lastNotchNavigationStack"

    private let brightnessChanges = PassthroughSubject<Float, Never>()
    var brightnessPublisher: AnyPublisher<Float, Never> {
        brightnessChanges.eraseToAnyPublisher()
    }

    var brightness: Float = 1.0 {
        didSet {
            guard brightness != oldValue else { return }
            brightnessChanges.send(brightness)
            defaults.set(brightness, forKey: Self.brightnessKey)
        }
    }

    var lastNotchNavigationStack: [RestorableNotchMenu]? {
        didSet {
            guard lastNotchNavigationStack != oldValue else { return }
            if let stack = lastNotchNavigationStack, let data = try? JSONEncoder().encode(stack) {
                defaults.set(data, forKey: Self.notchNavigationStackKey)
            } else {
                defaults.removeObject(forKey: Self.notchNavigationStackKey)
            }
        }
    }

    private let defaults = UserDefaults.standard
    private let settingsAccessQueue = DispatchQueue(label: "com.cshariq.sapphire.settings.sync.queue")
    private let settingsAccessQueueKey = DispatchSpecificKey<UInt8>()
    private let persistenceStateLock = NSLock()
    private var isApplyingLoadedSettings = false
    private var saveTimer: DispatchSourceTimer?
    private var pendingSave: (settings: Settings, revision: UInt64)?

    private var lastPersistedRevision: UInt64?

    private var isSettingsWriter = true
    private var hasSettingsPeers = false
    private var instanceGuard: SettingsInstanceGuard?

    private var lastWrittenPayload: Data?
    private var presetsInFile: [DockLayout]?

    private var isHoldingNewerPayload = false

    private init() {
        settingsAccessQueue.setSpecific(key: settingsAccessQueueKey, value: 1)
        let saveTimer = DispatchSource.makeTimerSource(queue: settingsAccessQueue)
        saveTimer.setEventHandler { [weak self] in
            self?.persistPendingSave()
        }
        saveTimer.schedule(deadline: .distantFuture)
        saveTimer.resume()
        self.saveTimer = saveTimer

        _ = APIKeyManager.shared
        let stored = Self.readSettingsFromStorage()
        var loaded = stored.settings
        loaded.normalizeCollectionOrders()
        loaded.volumeHUDSoundEnabled = SystemSoundFeedback.isVolumeChangeFeedbackEnabled
        isApplyingLoadedSettings = true
        settings = loaded
        isApplyingLoadedSettings = false
        applyIntelligenceRuntimePreferences(from: loaded)
        brightness = (defaults.object(forKey: Self.brightnessKey) as? NSNumber)?.floatValue ?? loaded.brightness
        lastNotchNavigationStack = defaults.data(forKey: Self.notchNavigationStackKey)
            .flatMap { try? JSONDecoder().decode([RestorableNotchMenu].self, from: $0) }
            ?? loaded.lastNotchNavigationStack

        lastWrittenPayload = stored.payload
        presetsInFile = stored.presetsInFile
        let instanceGuard = SettingsInstanceGuard(
            onRoleChange: { [weak self] old, new in self?.instanceRoleChanged(from: old, to: new) },
            onPeerPersisted: { [weak self] in self?.reloadAfterPeerWrite() }
        )
        self.instanceGuard = instanceGuard
        isSettingsWriter = instanceGuard.role.isWriter
        hasSettingsPeers = instanceGuard.role.hasPeers

        let plan = SettingsLaunchPlan.make(for: stored.assessment)
        isHoldingNewerPayload = plan.holdUntilUserChange
        if plan.holdUntilUserChange {
            print("[SettingsModel] Settings were saved by a newer Sapphire (schema \(stored.assessment.storedSchemaVersion ?? 1) > \(SettingsPayloadFormat.currentSchemaVersion)). Keeping them untouched until a setting is changed here; unknown keys use defaults in memory.")
        } else if stored.assessment.decodedTolerantly {
            print("[SettingsModel] Stored settings needed a tolerant decode; backing up the original payload before rewriting it.")
        }
        if !plan.persistNow {
            markPersisted(revision: revision)
        }

        let initialSettings = settings
        let initialRevision = revision
        let originalPayload = plan.backUpOriginal ? stored.payload : nil
        let loadedFromPayload = stored.assessment.loadedFromPayload
        let decodedTolerantly = stored.assessment.decodedTolerantly
        settingsAccessQueue.async { [weak self] in
            guard let self else { return }
            guard self.mayWriteSettings().mayWrite else {
                self.markPersisted(revision: initialRevision)
                return
            }
            if let originalPayload, SettingsPayloadBackups.save(originalPayload) == nil, decodedTolerantly {
                self.markPersisted(revision: initialRevision)
                return
            }
            var persisted = false
            if plan.persistNow {
                persisted = self.persistSettingsUnlocked(initialSettings, revision: initialRevision)
            }
            if persisted || loadedFromPayload {
                SettingsPersistence.removeImportedSettingsSnapshots()
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.flushPendingSave()
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.flushPendingSave()
        }
    }

    private struct StoredSettingsLoad {
        var settings: Settings
        var payload: Data?
        var assessment: SettingsLoadAssessment
        var presetsInFile: [DockLayout]?
    }

    static func restoreAnimationProfileAfterOlderBuild(
        _ settings: inout Settings,
        assessment: SettingsLoadAssessment,
        defaults: UserDefaults
    ) {
        guard assessment.loadedFromPayload,
              (assessment.storedSchemaVersion ?? 1) < SettingsPayloadFormat.currentSchemaVersion,
              settings.animationProfile == .snappy,
              let raw = defaults.string(forKey: animationProfileKey),
              let saved = AnimationProfile(rawValue: raw),
              saved != settings.animationProfile else { return }
        print("[SettingsModel] An older Sapphire reset the animation profile; restoring \(saved.rawValue).")
        settings.animationProfile = saved
    }

    static func adoptFluidAnimationProfile(_ settings: inout Settings) {
        guard settings.animationProfile == .snappy else { return }
        settings.animationProfile = .fluid
    }

    static func adoptRedesignedFloatingIsland(_ settings: inout Settings) {
        guard settings.floatingIslandTopOffset == FloatingIslandStyle.legacyTopOffset else { return }
        let current = Settings()
        if !settings.floatingIslandOnNotchlessDisplays, settings.perDisplayFloatingIsland.isEmpty {
            settings.floatingIslandOnNotchlessDisplays = current.floatingIslandOnNotchlessDisplays
        }
        settings.floatingIslandTopOffset = current.floatingIslandTopOffset
        adoptCurrentFloatingIslandStyle(&settings)
    }

    static func adoptCurrentFloatingIslandStyle(_ settings: inout Settings) {
        guard FloatingIslandStyle.previousDefaults.contains(settings.floatingIslandStyle) else { return }
        settings.floatingIslandStyle = Settings().floatingIslandStyle
    }

    private static func readSettingsFromStorage() -> StoredSettingsLoad {
        SettingsPersistence.purgeLegacyAPIKeyUserDefaults()
        let defaults = UserDefaults.standard

        var loaded: Settings
        var assessment = SettingsLoadAssessment(
            loadedFromPayload: false,
            storedSchemaVersion: nil,
            decodedTolerantly: false,
            migratedOnLoad: false
        )
        let storedPayload = defaults.data(forKey: SettingsPersistence.payloadKey)
        if let storedPayload,
           let decoded = SettingsPersistence.decodeFromPayloadReportingTolerance(storedPayload) {
            loaded = decoded.settings
            assessment.loadedFromPayload = true
            assessment.storedSchemaVersion = SettingsPayloadFormat.schemaVersion(of: storedPayload)
            assessment.decodedTolerantly = decoded.decodedTolerantly
        } else if let snapshot = SettingsPersistence.loadImportedSettingsSnapshot() {
            loaded = snapshot
        } else if let merged = decodeSettingsFromUserDefaults(defaults) {
            loaded = merged
        } else {
            loaded = Settings()
        }
        Self.restoreAnimationProfileAfterOlderBuild(&loaded, assessment: assessment, defaults: defaults)
        let asDecoded = loaded

        if defaults.object(forKey: "musicLongPressActionsMigratedV2") == nil {
            loaded.musicLongPressPrevious = .none
            loaded.musicLongPressNext = .none
            loaded.musicLongPressPlayPause = .none
            if loaded.musicLongPressPlaylists == .none {
                loaded.musicLongPressPlaylists = .openDevices
            }
            if loaded.musicLongPressDevices == .none {
                loaded.musicLongPressDevices = .openQueue
            }
            defaults.set(true, forKey: "musicLongPressActionsMigratedV2")
        } else if defaults.object(forKey: "musicLongPressPrevious") == nil {
            if loaded.musicHoldSkipForSecondaryActions {
                loaded.musicLongPressActionsEnabled = true
            } else {
                loaded.musicLongPressActionsEnabled = false
            }
            loaded.musicLongPressPrevious = .none
            loaded.musicLongPressNext = .none
        }

        if defaults.object(forKey: "focusDefaultsAppliedV1") == nil {
            loaded.focusSessionDuration = 90 * 60
            loaded.focusBreakEnabled = false
            loaded.focusBreakDuration = 0
            defaults.set(true, forKey: "focusDefaultsAppliedV1")
        }

        if defaults.object(forKey: "hingeAnimationDuoTuningV2") == nil {
            if loaded.systemEnhanceHingeAnimationActivationAngle == 105 {
                loaded.systemEnhanceHingeAnimationActivationAngle = 90
            }
            if loaded.systemEnhanceHingeAnimationBlur == 18 {
                loaded.systemEnhanceHingeAnimationBlur = 135
            }
            defaults.set(true, forKey: "hingeAnimationDuoTuningV2")
        }

        if defaults.object(forKey: "fluidAnimationProfileV1") == nil {
            Self.adoptFluidAnimationProfile(&loaded)
            defaults.set(true, forKey: "fluidAnimationProfileV1")
        }

        if defaults.object(forKey: "notchlessFloatingIslandV1") == nil {
            Self.adoptRedesignedFloatingIsland(&loaded)
            defaults.set(true, forKey: "notchlessFloatingIslandV1")
        }
        if defaults.object(forKey: "notchlessFloatingIslandV5") == nil {
            Self.adoptCurrentFloatingIslandStyle(&loaded)
            defaults.set(true, forKey: "notchlessFloatingIslandV5")
        }

        loaded.normalizeCollectionOrders()
        let migrated = loaded != asDecoded

        var presetsInFile: [DockLayout]?
        if case .loaded(let presets) = DockLayoutPresetFile.load() {
            presetsInFile = presets
        }
        let inlinePresets = loaded.dockLayoutsPresets
        loaded.dockLayoutsPresets = DockLayoutPresetFile.merged(file: presetsInFile, payload: inlinePresets)
        assessment.migratedOnLoad = migrated || !inlinePresets.isEmpty

        return StoredSettingsLoad(
            settings: loaded,
            payload: assessment.loadedFromPayload ? storedPayload : nil,
            assessment: assessment,
            presetsInFile: presetsInFile
        )
    }

    private static func decodeSettingsFromUserDefaults(_ defaults: UserDefaults) -> Settings? {
        let fallback = Settings()
        guard var dictionary = SettingsPersistence.encodeToDictionary(fallback) else {
            return nil
        }

        for key in dictionary.keys {
            guard !SettingsPersistence.legacyAPIKeyUserDefaultsKeys.contains(key),
                  let savedValue = defaults.object(forKey: key),
                  SettingsPersistence.isJSONCompatible(savedValue) else {
                continue
            }

            var candidate = dictionary
            candidate[key] = savedValue
            if SettingsPersistence.decodeFromDictionary(candidate) != nil {
                dictionary[key] = savedValue
            }
        }

        if defaults.object(forKey: "systemEnhanceDockClicksSelectedApps") != nil,
           defaults.object(forKey: "systemEnhanceDockClicksAllAppsEnabled") == nil {
            dictionary["systemEnhanceDockClicksAllAppsEnabled"] = false
        }

        return SettingsPersistence.decodeFromDictionary(dictionary)
    }

    private func applyIntelligenceRuntimePreferences(from loadedSettings: Settings) {
        UserDefaults.standard.set(loadedSettings.intelligenceGeminiModel.rawValue, forKey: "geminiModelID")
        UserDefaults.standard.set(loadedSettings.intelligenceGeminiSpeedMode.rawValue, forKey: "geminiSpeedMode")
        UserDefaults.standard.set(loadedSettings.intelligenceBackend.rawValue, forKey: "llmBackend")
        BlipModelPreferences.openAIModel = loadedSettings.intelligenceOpenAIModel.rawValue
        BlipModelPreferences.anthropicModel = loadedSettings.intelligenceAnthropicModel.rawValue
        BlipModelPreferences.openRouterModelStored = loadedSettings.intelligenceOpenRouterModel
        BlipModelPreferences.xaiModel = loadedSettings.intelligenceXAIModel.rawValue
        BlipModelPreferences.nvidiaModel = loadedSettings.intelligenceNVIDIAModel.rawValue
    }

    private static func intelligenceRuntimePreferencesChanged(from old: Settings, to new: Settings) -> Bool {
        old.intelligenceGeminiModel != new.intelligenceGeminiModel
            || old.intelligenceGeminiSpeedMode != new.intelligenceGeminiSpeedMode
            || old.intelligenceBackend != new.intelligenceBackend
            || old.intelligenceOpenAIModel != new.intelligenceOpenAIModel
            || old.intelligenceAnthropicModel != new.intelligenceAnthropicModel
            || old.intelligenceOpenRouterModel != new.intelligenceOpenRouterModel
            || old.intelligenceXAIModel != new.intelligenceXAIModel
            || old.intelligenceNVIDIAModel != new.intelligenceNVIDIAModel
    }

    private func scheduleSaveSettings() {
        guard revision != persistedRevision() else { return }
        persistenceStateLock.lock()
        pendingSave = (settings, revision)
        persistenceStateLock.unlock()

        saveTimer?.schedule(
            deadline: .now() + .milliseconds(250),
            leeway: .milliseconds(50)
        )
    }

    private func persistPendingSave() {
        persistenceStateLock.lock()
        let save = pendingSave
        pendingSave = nil
        persistenceStateLock.unlock()

        guard let save, save.revision != persistedRevision() else { return }
        _ = persistSettingsUnlocked(save.settings, revision: save.revision)
    }

    func flushPendingSave() {
        persistenceStateLock.lock()
        pendingSave = nil
        persistenceStateLock.unlock()
        saveTimer?.schedule(deadline: .distantFuture)

        let snapshot = settings
        let snapshotRevision = revision
        guard snapshotRevision != persistedRevision() else { return }

        let write: () -> Void = { [self] in
            _ = persistSettingsUnlocked(snapshot, revision: snapshotRevision)
        }
        if DispatchQueue.getSpecific(key: settingsAccessQueueKey) != nil {
            write()
        } else {
            settingsAccessQueue.sync(execute: write)
        }
    }

    @discardableResult
    private func persistSettingsUnlocked(_ settingsToPersist: Settings, revision persistedRevision: UInt64) -> Bool {
        let permission = mayWriteSettings()
        guard permission.mayWrite else { return false }

        var settingsToSave = settingsToPersist
        if Thread.isMainThread {
            settingsToSave.normalizeCollectionOrders()
        }

        var wroteSomething = false
        let presets = settingsToSave.dockLayoutsPresets
        if presets == presetsInFile || (presets.isEmpty && presetsInFile == nil) {
            settingsToSave.dockLayoutsPresets = []
        } else if DockLayoutPresetFile.write(presets, previouslyLoaded: presetsInFile != nil) {
            presetsInFile = presets
            settingsToSave.dockLayoutsPresets = []
            wroteSomething = true
        }

        guard let encoded = try? SettingsPersistence.encoder.encode(settingsToSave) else {
            print("[SettingsModel] Failed to encode settings payload.")
            return false
        }
        let payload = SettingsPayloadFormat.stamped(encoded)
        if payload != lastWrittenPayload {
            defaults.set(payload, forKey: SettingsPersistence.payloadKey)
            lastWrittenPayload = payload
            wroteSomething = true
        }
        let profile = settingsToSave.animationProfile.rawValue
        if defaults.string(forKey: Self.animationProfileKey) != profile {
            defaults.set(profile, forKey: Self.animationProfileKey)
        }
        if wroteSomething, permission.hasPeers {
            instanceGuard?.postDidPersist()
        }

        markPersisted(revision: persistedRevision)
        return true
    }

    private func markPersisted(revision persistedRevision: UInt64) {
        persistenceStateLock.lock()
        lastPersistedRevision = persistedRevision
        persistenceStateLock.unlock()
    }

    private func mayWriteSettings() -> (mayWrite: Bool, hasPeers: Bool) {
        persistenceStateLock.lock()
        defer { persistenceStateLock.unlock() }
        return (isSettingsWriter, hasSettingsPeers)
    }

    private func hasUnsavedChanges() -> Bool {
        persistenceStateLock.lock()
        defer { persistenceStateLock.unlock() }
        return pendingSave != nil || lastPersistedRevision != revision
    }

    // MARK: Newer-schema hold and other running copies

    private func noteUserChangeWhileHoldingNewerPayload() {
        guard isHoldingNewerPayload else { return }
        isHoldingNewerPayload = false
        print("[SettingsModel] A setting changed; saving over the newer build's settings (the original is in \(SettingsPayloadBackups.directoryURL.path)).")
    }

    private func instanceRoleChanged(from old: SettingsInstanceGuard.Role, to new: SettingsInstanceGuard.Role) {
        if old.isWriter && !new.isWriter {
            flushPendingSave()
        }
        persistenceStateLock.lock()
        isSettingsWriter = new.isWriter
        hasSettingsPeers = new.hasPeers
        persistenceStateLock.unlock()

        if !old.isWriter && new.isWriter {
            if hasUnsavedChanges() {
                print("[SettingsModel] Now the settings writer; saving the changes made while read-only.")
                flushPendingSave()
            } else {
                reloadFromStorage(reason: "became the settings writer")
            }
        }
    }

    private func reloadAfterPeerWrite() {
        guard !hasUnsavedChanges() else {
            print("[SettingsModel] Another Sapphire saved settings, but this copy has unsaved changes; keeping this copy's.")
            return
        }
        reloadFromStorage(reason: "another Sapphire saved settings")
    }

    private func reloadFromStorage(reason: String) {
        settingsAccessQueue.async { [weak self] in
            guard let self else { return }
            CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication)
            guard let payload = self.defaults.data(forKey: SettingsPersistence.payloadKey),
                  var decoded = SettingsPersistence.decodeFromPayload(payload) else { return }
            var presetsInFile: [DockLayout]?
            if case .loaded(let presets) = DockLayoutPresetFile.load() {
                presetsInFile = presets
            }
            decoded.dockLayoutsPresets = DockLayoutPresetFile.merged(file: presetsInFile, payload: decoded.dockLayoutsPresets)
            self.lastWrittenPayload = payload
            self.presetsInFile = presetsInFile
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.hasUnsavedChanges() else { return }
                var reloaded = decoded
                reloaded.volumeHUDSoundEnabled = self.current.volumeHUDSoundEnabled
                guard reloaded != self.current else { return }
                print("[SettingsModel] Reloading settings: \(reason).")
                self.isApplyingLoadedSettings = true
                self.settings = reloaded
                self.isApplyingLoadedSettings = false
                self.markPersisted(revision: self.revision)
                self.applyIntelligenceRuntimePreferences(from: reloaded)
            }
        }
    }

    private func persistedRevision() -> UInt64? {
        persistenceStateLock.lock()
        defer { persistenceStateLock.unlock() }
        return lastPersistedRevision
    }

    func makeBackupDocument() -> SettingsBackupDocument {
        var snapshot = settings
        snapshot.brightness = brightness
        snapshot.lastNotchNavigationStack = lastNotchNavigationStack
        return SettingsBackupDocument(settings: snapshot)
    }

    func volumeSliderStep(forDeviceUID uid: String?) -> Int {
        guard let uid = uid else { return settings.volumesliderstep }
        return settings.volumesliderstepByDevice[uid] ?? settings.volumesliderstep
    }

    func importSettings(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let importedPayload = try SettingsBackupDocument.decodePayload(from: data)
        var importedSettings = importedPayload.settings
        importedSettings.normalizeCollectionOrders()
        settings = importedSettings
        lastNotchNavigationStack = importedSettings.lastNotchNavigationStack
    }

    func resetAllSettings() {
        settings = Settings()
        lastNotchNavigationStack = nil
    }

    func removeReferences(toApplication bundleIdentifier: String) {
        guard AppSecurityValidator.isSafeIdentifier(bundleIdentifier) else { return }
        var updated = settings
        updated.systemEnhanceDockClicksSelectedApps.removeAll { $0 == bundleIdentifier }
        updated.systemEnhanceDockClicksExcludedApps.removeAll { $0 == bundleIdentifier }
        updated.systemEnhanceAutoQuitExcludedApps.removeAll { $0 == bundleIdentifier }
        updated.systemEnhanceQuitProtectionExcludedApps.removeAll { $0 == bundleIdentifier }
        updated.capsLockHorizontalLockAppStates.removeValue(forKey: bundleIdentifier)
        updated.emojiDisabledAppBundleIDs.remove(bundleIdentifier)
        updated.mouseExcludedAppBundleIDs.removeAll { $0 == bundleIdentifier }
        updated.superKeyExcludedAppBundleIDs.removeAll { $0 == bundleIdentifier }
        updated.focusBlockedApps.remove(bundleIdentifier)
        updated.focusAllowedApps.remove(bundleIdentifier)
        updated.appLockProtectedApps.remove(bundleIdentifier)
        updated.mediaAppVisibility.removeValue(forKey: bundleIdentifier)
        updated.musicAppStates.removeValue(forKey: bundleIdentifier)
        updated.appSpecificLayoutConfigurations.removeValue(forKey: bundleIdentifier)
        updated.appNotificationStates.removeValue(forKey: bundleIdentifier)
        if updated != settings {
            settings = updated
            flushPendingSave()
        }
    }
}

// MARK: - Supporting Enums and Structs

private extension Array where Element: Equatable {
    func deduplicated() -> [Element] {
        var seen: [Element] = []
        return filter { element in
            if seen.contains(element) {
                return false
            }
            seen.append(element)
            return true
        }
    }
}

enum MagSafeLEDSetting: String, Codable, CaseIterable, Identifiable {
    case alwaysOn, off
    var id: String { self.rawValue }
    var displayName: String {
        switch self {
        case .alwaysOn: "始终开启"
        case .off: "始终关闭"
        }
    }
}

enum LowPowerMode: String, Codable, CaseIterable, Identifiable {
    case alwaysOn, onBattery, never
    var id: String { self.rawValue }
    var displayName: String {
        switch self {
        case .alwaysOn: "始终开启"
        case .onBattery: "仅使用电池时"
        case .never: "从不"
        }
    }
}

enum WidgetType: String, Codable, CaseIterable, Identifiable, Equatable {
    case weather, calendar, shortcuts, music, sports, finance, shopify, notes, clipboard, mirror, battery, timer, focusSession, storage, dev, agent
    var id: String { self.rawValue }
    var displayName: String {
        switch self {
        case .weather: return "天气"
        case .calendar: return "日历"
        case .shortcuts: return "快捷指令"
        case .music: return "音乐"
        case .sports: return "体育"
        case .finance: return "财经"
        case .shopify: return "Shopify 订单"
        case .notes: return "备忘录"
        case .clipboard: return "剪贴板"
        case .mirror: return "随身镜"
        case .battery: return "电池"
        case .timer: return "计时器"
        case .focusSession: return "专注时段"
        case .storage: return "存储空间"
        case .dev: return "开发动态"
        case .agent: return "智能体"
        }
    }
}

enum MusicLiveActivityRightTextMode: String, Codable, CaseIterable, Identifiable, Equatable {
    case off
    case continuityOnly
    case always

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off: return "关闭"
        case .continuityOnly: return "仅手机媒体"
        case .always: return "始终显示"
        }
    }
}

enum MusicLiveActivityWaveformMode: String, Codable, CaseIterable, Identifiable, Equatable {
    case off
    case continuityOff
    case always

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off: return "关闭"
        case .continuityOff: return "播放手机媒体时隐藏"
        case .always: return "始终显示"
        }
    }
}

enum SpotifyAPIMode: String, Codable, CaseIterable, Identifiable, Equatable {
    case privateAPI
    case officialAPI

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .privateAPI: return "私有 API"
        case .officialAPI: return "官方 API"
        }
    }
}

enum MusicLiveActivityWaveformStyle: String, Codable, CaseIterable, Identifiable, Equatable {
    case classic
    case continuity

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic: return "经典"
        case .continuity: return "跨端互通"
        }
    }
}

enum MusicLiveActivityChromePolicy {
    static func resolvedWaveformMode(
        waveformMode: MusicLiveActivityWaveformMode,
        rightTextMode: MusicLiveActivityRightTextMode
    ) -> MusicLiveActivityWaveformMode {
        if waveformMode == .off, rightTextMode != .always {
            return .continuityOff
        }
        return waveformMode
    }

    static func showsRightText(mode: MusicLiveActivityRightTextMode, isPhoneMedia: Bool) -> Bool {
        switch mode {
        case .off: return false
        case .always: return true
        case .continuityOnly: return isPhoneMedia
        }
    }

    static func showsWaveform(
        mode: MusicLiveActivityWaveformMode,
        rightTextMode: MusicLiveActivityRightTextMode,
        isPhoneMedia: Bool
    ) -> Bool {
        switch resolvedWaveformMode(waveformMode: mode, rightTextMode: rightTextMode) {
        case .off: return false
        case .always: return true
        case .continuityOff: return !isPhoneMedia
        }
    }
}

enum LiveActivityType: String, Codable, CaseIterable, Identifiable, Equatable {
    case capsLock, fileShelf, eyeBreak, focus, desktop, battery, timers, calendar, reminders, weather, music, fileProgress, stats, microphone, devActivity, sports, finance
    var id: String { self.rawValue }
    var displayName: String {
        switch self {
        case .capsLock: "大写锁定"; case .music: "音乐"; case .weather: "天气"; case .calendar: "日历"; case .reminders: "提醒事项"; case .timers: "计时器"; case .battery: "电池"; case .eyeBreak: "护眼休息"; case .desktop: "桌面空间"; case .focus: "专注模式"; case .fileShelf: "文件暂存架"; case .fileProgress: "文件传输进度"; case .stats: "系统监控"; case .microphone: "麦克风"; case .devActivity: "开发动态"; case .sports: "体育"; case .finance: "财经"
        }
    }
}

enum FocusIntensity: String, Codable, CaseIterable, Identifiable {
    case minimal
    case gentle
    case standard
    case strict

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .minimal: return "轻量"
        case .gentle: return "温和"
        case .standard: return "标准"
        case .strict: return "严格"
        }
    }

    var systemImage: String {
        switch self {
        case .minimal: return "hand.raised"
        case .gentle: return "hand.raised.fill"
        case .standard: return "lock.shield"
        case .strict: return "shield.lefthalf.filled"
        }
    }

    var blurb: String {
        switch self {
        case .minimal:
            return "受限应用会被模糊遮罩，通知仍保持可见；你可以点击按钮立即解除单个应用的限制，应用不会被关闭。"
        case .gentle:
            return "受限应用会被模糊遮罩，通知仍保持可见且应用保持打开；不提供单个应用解封按钮，但你可以随时结束专注时段。"
        case .standard:
            return "受限应用在打开瞬间会被强制关闭，且隐藏相关通知；期间无法解封单个应用，但你可以随时结束专注时段。"
        case .strict:
            return "受限应用会被强制关闭且隐藏通知；解封请求需等待 10 分钟冷却（或直至专注结束），且专注时段无法提前终止。"
        }
    }

    var suppressesNotifications: Bool {
        switch self {
        case .minimal, .gentle: return false
        case .standard, .strict: return true
        }
    }

    var forceClosesBlockedApps: Bool {
        switch self {
        case .minimal, .gentle: return false
        case .standard, .strict: return true
        }
    }

    var canEndSessionEarly: Bool {
        switch self {
        case .minimal, .gentle, .standard: return true
        case .strict: return false
        }
    }
}

enum MirrorRotationMode: String, Codable, CaseIterable, Identifiable {
    case auto
    case angle90
    case angle180
    case angle270

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return "自动"
        case .angle90: return "90°"
        case .angle180: return "180°"
        case .angle270: return "270°"
        }
    }

    var systemImage: String {
        switch self {
        case .auto: return "rotate.right"
        case .angle90: return "90.rotation"
        case .angle180: return "180.rotation"
        case .angle270: return "270.rotation"
        }
    }

    var angle: CGFloat? {
        switch self {
        case .auto: return nil
        case .angle90: return 90
        case .angle180: return 180
        case .angle270: return 270
        }
    }

    var next: MirrorRotationMode {
        switch self {
        case .auto: return .angle90
        case .angle90: return .angle180
        case .angle180: return .angle270
        case .angle270: return .auto
        }
    }
}

enum FocusShortcutSyncMode: String, Codable, CaseIterable, Identifiable {
    case none
    case timer
    case stopwatch

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .none: return "关闭"
        case .timer: return "同步倒计时"
        case .stopwatch: return "同步秒表"
        }
    }
}

enum FocusBlockingMode: String, Codable, CaseIterable, Identifiable {
    case blocklist
    case allowlist

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .blocklist: return "屏蔽所选应用"
        case .allowlist: return "仅允许所选应用"
        }
    }

    var blurb: String {
        switch self {
        case .blocklist:
            return "仅屏蔽你添加到列表中的应用（及网站），其余所有内容均可正常访问。"
        case .allowlist:
            return "屏蔽除白名单以外的所有应用，非常适合只需要少数工具的深度工作时段。"
        }
    }
}

enum FocusAmbientSoundType: String, Codable, CaseIterable, Identifiable {
    case whiteNoise
    case pinkNoise
    case brownNoise
    case rain

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .whiteNoise: return "白噪音"
        case .pinkNoise: return "粉红噪音"
        case .brownNoise: return "棕噪音"
        case .rain: return "雨声"
        }
    }

    var systemImage: String {
        switch self {
        case .whiteNoise: return "waveform"
        case .pinkNoise: return "waveform.circle"
        case .brownNoise: return "water.waves"
        case .rain: return "cloud.rain.fill"
        }
    }
}

enum MicrophoneLiveActivityBehavior: String, Codable, CaseIterable, Identifiable {
    case iconOnly
    case iconAndGesture

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .iconOnly: return "仅显示图标"
        case .iconAndGesture: return "图标与手势控制"
        }
    }
}

enum BatteryNotificationStyle: String, CaseIterable, Identifiable, Decodable, Encodable {
    case `default`
    case compact
    case persistent

    var id: String { self.rawValue.capitalized }

    static var userSelectableCases: [BatteryNotificationStyle] {
        return [.default, .compact]
    }
}

enum NotificationSource: String, CaseIterable, Identifiable {
    case iMessage, faceTime, airDrop
    var id: String { rawValue }
    var displayName: String { switch self { case .iMessage: "iMessage"; case .faceTime: "FaceTime"; case .airDrop: "AirDrop" } }
    var systemImage: String { switch self { case .iMessage: "message.fill"; case .faceTime: "video.fill"; case .airDrop: "shareplay" } }
    var iconColor: Color { switch self { case .iMessage, .faceTime: .green; case .airDrop: .blue } }
}

enum GeneralSettingType: String, CaseIterable, Identifiable, Equatable {
    case expandOnHover, swipeToSwitchWidgets, enableOpeningBounce, capsLockHorizontalLock
    var id: String { self.rawValue }
    var displayName: String {
        switch self {
        case .expandOnHover: "悬停时展开"
        case .swipeToSwitchWidgets: "滑动切换小组件"
        case .enableOpeningBounce: "展开小组件时启用回弹动效"
        case .capsLockHorizontalLock: "按住大写锁定键时水平锁定光标"
        }
    }
    var systemImage: String {
        switch self {
        case .expandOnHover: "cursorarrow.motionlines"
        case .swipeToSwitchWidgets: "hand.draw.fill"
        case .enableOpeningBounce: "arrowshape.bounce.forward.fill"
        case .capsLockHorizontalLock: "capslock"
        }
    }
    var iconColor: Color {
        switch self {
        case .expandOnHover: .cyan
        case .swipeToSwitchWidgets: .orange
        case .enableOpeningBounce: .blue
        case .capsLockHorizontalLock: .green
        }
    }
}

enum NotchButtonType: String, Codable, Identifiable, Equatable {
    case settings, fileShelf, notes, clipboard, intelligence, intelligenceLive, focusSession, caffeine, spacer, multiAudio, continuity, battery, pin
    var id: String { self.rawValue }

    static let allCases: [NotchButtonType] = [
        .settings, .fileShelf, .notes, .clipboard, .intelligence,
        .focusSession, .caffeine, .spacer, .multiAudio, .continuity, .battery, .pin,
    ]

    var displayName: String {
        switch self {
        case .settings: "设置"; case .fileShelf: "文件暂存架"; case .notes: "备忘录"; case .clipboard: "剪贴板"
        case .intelligence: "Blip"; case .intelligenceLive: "Gemini";
        case .focusSession: "专注时段";
        case .caffeine: "保持唤醒"; case .spacer: "弹性空白";
        case .multiAudio: "多音频控制（测试版）"; case .continuity: "跨端互通"; case .battery: "电池"; case .pin: "固定"
        }
    }

    var systemImage: String {
        switch self {
        case .settings: "gearshape"; case .fileShelf: "tray.full"; case .notes: "note.text"; case .clipboard: "list.clipboard"
        case .intelligence: "sparkle"; case .intelligenceLive: "waveform";
        case .focusSession: "moon.fill";
        case .caffeine: "cup.and.saucer"; case .spacer: "space";
        case .multiAudio: "hifispeaker.and.homepod.mini.fill"; case .continuity: "iphone"; case .battery: "battery.100"; case .pin: "pin"
        }
    }
}

struct SystemApp: Identifiable, Equatable, Sendable {
    let id: String, name: String, isBrowser: Bool, url: URL
}

enum AppIconLoader {
    static func icon(for url: URL, maxDimension: CGFloat = 32) -> NSImage {
        InstalledAppIconRepository.shared.icon(
            for: url,
            modifiedAt: nil,
            maxDimension: maxDimension
        )
    }

    static func releaseCache() {
        InstalledAppIconRepository.shared.removeAll()
    }
}

enum Day: String, Codable, CaseIterable, Identifiable {
    case sunday, monday
    var id: String { self.rawValue.capitalized }

    var firstWeekday: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        }
    }

    var configuredCalendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = self.firstWeekday
        return cal
    }

    var weekdayHeaders: [String] {
        let symbols = configuredCalendar.shortWeekdaySymbols
        let offset = self.firstWeekday - 1
        return Array(symbols[offset...] + symbols[..<offset])
    }
}

enum DefaultMusicPlayer: String, Codable, CaseIterable, Identifiable {
    case appleMusic, spotify, tidal, youtubeMusic
    var id: String { self.rawValue }
    var displayName: String {
        switch self {
        case .appleMusic: "Apple Music"
        case .spotify: "Spotify"
        case .tidal: "TIDAL"
        case .youtubeMusic: "YouTube Music"
        }
    }

    var bundleIdentifier: String? {
        switch self {
        case .appleMusic: "com.apple.Music"
        case .spotify: "com.spotify.client"
        case .tidal: "com.tidal.desktop"
        case .youtubeMusic: nil
        }
    }

    var webURL: URL? {
        switch self {
        case .appleMusic: nil
        case .spotify: nil
        case .tidal: URL(string: "https://tidal.com")
        case .youtubeMusic: URL(string: "https://music.youtube.com")
        }
    }

    var isAppInstalled: Bool {
        guard let bundleIdentifier else { return false }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
    }

    func open() {
        if let bundleIdentifier,
           NSWorkspace.shared.launchApplication(
               withBundleIdentifier: bundleIdentifier,
               options: [],
               additionalEventParamDescriptor: nil,
               launchIdentifier: nil
           ) {
            return
        }
        if let webURL {
            NSWorkspace.shared.open(webURL)
        }
    }
}

enum HUDStyle: String, Codable, CaseIterable, Identifiable {
    case `default`, thin, dots, pill
    var id: String { self.rawValue.capitalized }
}

enum PillHUDPosition: String, Codable, CaseIterable, Identifiable {
    case left, right, top, bottom
    var id: String { self.rawValue.capitalized }
}

enum PillHUDStyle: String, Codable, CaseIterable, Identifiable {
    case contained, bare
    var id: String { self.rawValue.capitalized }
}

struct LaunchpadItem: Codable, Equatable, Identifiable, Hashable {
    var id: String { appBundleID }
    let appBundleID: String
}

struct LaunchpadFolder: Codable, Equatable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var items: [LaunchpadItem]
}

enum LaunchpadPageItem: Codable, Equatable, Identifiable, Hashable {
    case app(LaunchpadItem)
    case folder(LaunchpadFolder)

    var id: String {
        switch self {
        case .app(let item): return item.id
        case .folder(let folder): return folder.id.uuidString
        }
    }

    var appItem: LaunchpadItem? {
        if case .app(let item) = self { return item }
        return nil
    }
}

extension LaunchpadPageItem: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .launchpadItem)
    }
}

extension UTType {
    static let launchpadItem = UTType(exportedAs: "com.cshariq.sapphire.launchpaditem")
}

enum SettingsSection: String, CaseIterable, Identifiable {
    case overview, general, systemEnhance, apps, storage, widgets, liveActivities, appActivities, fileProgress, appearance, lockScreen, bluetoothUnlock, shortcuts, keyboardShortcuts, snapZones, audio, battery, bluetooth, hud, notifications, nearbyShare, continuity, fileShelf, notes, clipboard, emoji, mouse, monitoring, devActivity, archives, mirror, caffeine, music, weather, calendar, eyeBreak, focusSession, appLock, intelligence, sports, finance, dockLayouts, mediaOptimizer, about

    var id: String { self.rawValue }

    var requiredPremiumFeature: AppFeature? {
        switch self {
        case .intelligence:
            return .geminiLive
        case .sports:
            return .liveSports
        case .finance:
            return .financeWidget
        case .appLock:
            return .appLock
        default:
            return nil
        }
    }

    var isBeta: Bool {
        switch self {
        case .continuity, .appActivities, .fileProgress: true
        default: false
        }
    }

    var minimumRequiredTier: SubscriptionTier? {
        guard let requiredPremiumFeature else { return nil }
        return SubscriptionFeatureCatalog.minimumTier(for: requiredPremiumFeature)
    }

    var isPremiumLocked: Bool {
        guard let requiredPremiumFeature else { return false }
        return !SubscriptionAccess.hasAccess(to: requiredPremiumFeature)
    }

    var shortDescription: String {
        switch self {
        case .overview: "询问任意设置项、获取配置建议，并快速调整最常用的设置。"
        case .general: "核心应用行为、登录启动选项、动画效果与灵动岛控制。"
        case .systemEnhance: "窗口预览、应用切换器、程序坞控制与显示器交互行为。"
        case .apps: "查看已安装应用、检查应用包详情，并将不需要的应用安全移至废纸篓。"
        case .storage: "查找占用空间较大的文件夹，通过透明可控的清理释放磁盘空间。"
        case .widgets: "选择在灵动岛中显示的小组件及其排列顺序。"
        case .liveActivities: "控制在灵动岛中浮现与自动展开的实时活动。"
        case .appActivities: "为 Zoom、Google Meet、Teams、Slack、Discord、FaceTime 及录屏录音工具提供实时活动与快捷控制。"
        case .fileProgress: "按应用追踪下载、拷贝与 AirDrop 进度 — 支持 Safari、Chrome、Edge、Firefox、访达等。"
        case .appearance: "调整灵动岛与菜单栏的外观风格、材质、配色及布局样式。"
        case .lockScreen: "配置 Mac 处于锁定屏幕状态时的 Sapphire 内容与交互行为。"
        case .bluetoothUnlock: "设置基于距离感应的蓝牙靠近解锁、Face ID 认证与受信任设备行为。"
        case .shortcuts: "管理在 Sapphire 中展示的快捷操作与快捷指令入口。"
        case .keyboardShortcuts: "汇总查看 Sapphire 的全部键盘快捷键 — 包括全局热键、窗口磁吸分区与内置快捷键。"
        case .snapZones: "配置窗口贴靠行为、分屏布局与窗口磁吸分区操作。"
        case .audio: "管理多设备音频调节、均衡器（EQ）及单应用独立音量控制。"
        case .battery: "配置电池小组件、电量历史记录、充电上限保护与电源控制。"
        case .bluetooth: "管理蓝牙设备集成、状态显示与连接提醒行为。"
        case .hud: "配置音量、亮度、键盘与媒体反馈的 HUD 浮层样式。"
        case .notifications: "选择由 Sapphire 镜像展示或增强处理的系统与应用通知。"
        case .nearbyShare: "配置附近分享偏好、文件传输与设备发现选项。"
        case .continuity: "配对 Android 手机，实现剪贴板互通、通知同步、媒体控制、电量显示与即时热点。"
        case .fileShelf: "管理文件暂存架的临时存储、拖拽目标与交互行为。"
        case .notes: "配置速记备忘录小组件、点击展开行为与灵动岛栏入口。"
        case .clipboard: "配置剪贴板历史记录、自动监听与灵动岛剪贴板快捷入口。"
        case .emoji: "支持输入 :短代码: 自动联想表情符号，并提供完整表情搜索面板。"
        case .mouse: "自定义鼠标与触控板的滚动方向、指针加速度及侧键映射。"
        case .monitoring: "在菜单栏显示 CPU、内存、磁盘与网络读数，并配置高负载提醒。"
        case .devActivity: "追踪 AI 智能体、项目构建与终端命令进度，并在任务运行期间使 Mac 保持唤醒。"
        case .archives: "随处自动解压 ZIP、RAR、7-Zip、TAR 等归档文件，或自动挂载并安装 DMG 磁盘映像。"
        case .mirror: "在灵动岛小组件中显示实时摄像头画面，并支持展开全屏查看。"
        case .caffeine: "使 Mac 保持唤醒、配置合盖防休眠行为及基于屏幕开合角度的显示控制。"
        case .music: "配置音乐小组件媒体源、播放控制手势与音乐平台集成。"
        case .weather: "配置天气小组件数据源、温度与度量单位及定位行为。"
        case .calendar: "配置在小组件与实时活动中展示的日历日程与提醒事项集成。"
        case .eyeBreak: "设置护眼休息提醒、工作时长间隔与健康用眼提示。"
        case .focusSession: "管理带计时器、应用与网站屏蔽、专注强度及跨设备同步的专注时段配置。"
        case .appLock: "使用 Touch ID、Face ID 或密码锁定受保护应用，支持模糊遮罩、空闲/睡眠自动上锁与防窥关闭。"
        case .intelligence: "Sapphire Blip — 具备记忆、技能、工具调用与桌面操作能力的 Mac 智能体。"
        case .sports: "配置体育赛事小组件、关注球队与实时比分展示。"
        case .finance: "配置股票行情代码、自选股持仓与走势图展示。"
        case .dockLayouts: "将程序坞布局保存为预设，并通过点击或快捷键一键切换，同时提供程序坞增强控制。"
        case .mediaOptimizer: "自动压缩剪贴板图片、缩减媒体体积，并通过 OCR 提取屏幕文字。"

        case .about: "查看应用版本详情、Sapphire 软件更新、发布渠道、致谢名单与项目链接。"
        }
    }

    var searchTokens: [String] {
        switch self {
        case .overview: ["overview", "assistant", "ask", "ai", "apple intelligence", "suggest", "quick", "notch size", "full screen", "inactive", "概览", "助手", "建议", "常用"]
        case .general: ["startup", "login", "animation", "notch", "system", "behavior", "analytics", "google", "privacy", "tracking", "telemetry", "swipe", "hide", "lock", "通用", "启动", "登录", "动画", "灵动岛", "隐私", "触感"]
        case .systemEnhance: ["dock", "preview", "previews", "alt tab", "cmd tab", "window", "switcher", "calendar", "compact", "layout", "lock dock", "monitor", "paste", "plain text", "formatting", "running apps", "hide apps", "static only", "hinge", "lid", "angle", "fold", "folding", "animation", "iphone duo", "系统增强", "窗口切换", "纯文本", "防误退", "最大化", "转轴"]
        case .apps: ["apps", "applications", "uninstall", "cleaner", "appcleaner", "bundle", "extensions", "startup", "update", "updates", "check for updates", "upgrade", "version", "new version", "auto update", "release", "应用管理", "卸载", "清理", "应用更新"]
        case .storage: ["storage", "disk", "space", "large files", "cache", "cleanup", "daisy disk", "scanner", "存储空间", "磁盘", "大文件", "缓存清理"]
        case .widgets: ["widget", "widgets", "reorder", "layout", "小组件", "排序", "分隔线"]
        case .liveActivities: ["live", "activity", "activities", "dynamic", "focus", "实时活动", "伴随挂件", "两侧挂件"]
        case .appActivities: ["zoom", "meet", "google meet", "teams", "slack", "huddle", "discord", "facetime", "webex", "meeting", "call", "mute", "recording", "voice memos", "quicktime", "handbrake", "应用活动", "会议", "通话", "录屏", "静音"]
        case .fileProgress: ["download", "downloads", "progress", "copy", "transfer", "chrome", "safari", "edge", "firefox", "airdrop", "finder", "文件传输", "下载进度", "拷贝进度", "访达"]
        case .appearance: ["theme", "appearance", "style", "glass", "color", "material", "外观", "主题", "液态玻璃", "菜单栏", "灵动岛尺寸", "悬浮灵动岛"]
        case .lockScreen: ["lock", "screen", "locked", "锁定屏幕", "锁屏", "壁纸", "动态壁纸"]
        case .bluetoothUnlock: ["authentication", "unlock", "proximity", "trusted", "device", "蓝牙靠近解锁", "身份验证", "自动解锁", "自动锁屏", "人脸识别"]
        case .shortcuts: ["shortcut", "action", "launcher", "快捷指令", "快捷操作"]
        case .keyboardShortcuts: ["shortcut", "keyboard", "hotkey", "key", "keys", "reference", "cheat sheet", "list", "global", "command", "modifier", "键盘快捷键", "热键", "画圈搜屏"]
        case .snapZones: ["snap", "zones", "window", "tiling", "layout", "shortcut", "keyboard", "hotkey", "窗口磁吸分区", "分屏", "贴靠", "窗口布局"]
        case .audio: ["audio", "EQ", "volume", "app", "devices", "音频", "均衡器", "音量", "声道"]
        case .battery: ["battery", "charging", "power", "history", "电池", "充电上限", "放电", "低电量", "电源"]
        case .bluetooth: ["bluetooth", "devices", "connections", "蓝牙", "耳机", "设备连接"]
        case .hud: ["hud", "overlay", "volume", "brightness", "media", "pill", "position", "edge", "side", "浮层", "音量", "亮度", "胶囊"]
        case .notifications: ["notifications", "alerts", "imessage", "facetime", "airdrop", "通知", "验证码", "快递", "包裹"]
        case .nearbyShare: ["nearby", "share", "drop", "transfer", "附近分享", "安卓互传", "跨端传输"]
        case .continuity: ["android", "continuity", "phone", "kde connect", "handoff", "universal clipboard", "instant hotspot", "notification mirroring", "phone link", "跨端互通", "手机互联", "剪贴板同步", "屏幕镜像", "热点", "随航", "接力"]
        case .fileShelf: ["file", "shelf", "drag", "drop", "storage", "remove", "文件暂存架", "中转站", "拖拽暂存"]
        case .notes: ["notes", "note", "memo", "quick note", "备忘录", "笔记", "便签"]
        case .clipboard: ["clipboard", "pasteboard", "history", "copy", "paste", "剪贴板", "历史记录", "复制粘贴", "文本片段"]
        case .emoji: ["emoji", "emoticon", "shortcut", "shortcode", "slack", "rocket", "smiley", "smile", "gif", "picker", "skin tone", "colon", "symbols", "kaomoji", "表情符号", "颜文字", "肤色"]
        case .mouse: ["mouse", "trackpad", "scroll", "scrolling", "acceleration", "pointer", "cursor", "buttons", "remap", "remapping", "linearmouse", "linear mouse", "natural scrolling", "wheel", "sensitivity", "speed", "invert", "modifier", "back", "forward", "鼠标", "触控板", "滚轮", "平滑滚动", "指针加速", "侧键", "防抖"]
        case .monitoring: ["monitor", "readout", "menu bar", "cpu", "ram", "memory", "network", "speed", "alerts", "notifications", "disk", "space", "pressure", "usage", "stats", "系统监控", "菜单栏监控", "处理器", "内存", "网速", "温度告警"]
        case .devActivity: ["dev", "developer", "ai", "agent", "agents", "build", "builds", "compile", "compiling", "terminal", "command", "task", "tasks", "progress", "claude", "codex", "cursor", "antigravity", "copilot", "devin", "windsurf", "gemini", "aider", "xcode", "android studio", "gradle", "npm", "cargo", "make", "iterm", "warp", "ghostty", "caffeinate", "awake", "开发动态", "编译", "构建", "终端", "智能体"]
        case .archives: ["archive", "unarchive", "extract", "extractor", "unarchiver", "zip", "unzip", "rar", "7z", "7-zip", "tar", "gzip", "bzip2", "xz", "compressed", "password", "encrypted", "iso", "cpio", "uncompress", "dmg", "disk image", "install", "mount", "unmount", "eject", "trash", "cleanup", "归档", "解压", "压缩包", "磁盘映像", "自动安装"]
        case .mirror: ["mirror", "camera", "camera feed", "selfie", "webcam", "随身镜", "镜子", "摄像头", "自拍"]
        case .caffeine: ["caffeinate", "caffeine", "sleep", "awake", "clamshell", "lid", "timeout", "timer", "保持唤醒", "防休眠", "不休眠", "合盖", "屏幕角度"]
        case .music: ["music", "media", "spotify", "playback", "音乐", "歌词", "波形", "播放器"]
        case .weather: ["weather", "forecast", "temperature", "location", "天气", "温度", "摄氏度", "华氏度", "天气预报"]
        case .calendar: ["calendar", "reminders", "events", "schedule", "日历", "提醒事项", "日程"]
        case .eyeBreak: ["eye", "break", "rest", "wellness", "focus", "护眼休息", "休息提醒", "用眼健康"]
        case .focusSession: ["focus", "session", "timer", "pomodoro", "block", "distraction", "website", "app", "blocking", "shortcut", "history", "stopwatch", "streak", "专注时段", "番茄钟", "应用屏蔽", "白噪音"]
        case .appLock: ["lock", "app lock", "protect", "touch id", "password", "privacy", "overlay", "idle", "sleep", "panic", "auto-close", "secure", "应用锁", "指纹锁", "密码保护", "隐私锁"]
        case .intelligence: ["intelligence", "blip", "facet", "nova", "octo", "claw", "connected", "accounts", "gmail", "github", "outlook", "findmy", "gemini", "ai", "assistant", "agent", "automation", "task", "voice", "live", "computer", "control", "accessibility", "memory", "skills", "personalization", "profiling", "monitoring", "privacy", "learning", "behavior", "screenshots", "calendar", "notes", "spotify", "clipboard", "settings", "data", "tracking", "circle", "search", "lasso", "智能体", "语音助手", "大模型"]
        case .sports: ["sports", "score", "game", "nfl", "nba", "mlb", "nhl", "team", "体育", "比分", "球队", "赛事"]
        case .finance: ["finance", "stocks", "market", "ticker", "portfolio", "aapl", "财经", "股票", "行情", "自选股"]
        case .dockLayouts: ["dock", "layout", "preset", "preset switch", "hotkey", "apps", "程序坞", "程序坞布局", "窗口预览"]
        case .mediaOptimizer: ["image", "video", "audio", "compress", "shrink", "optimize", "ocr", "clipboard", "file shelf", "媒体优化", "图片压缩", "文字识别", "截图识字"]

        case .about: ["about", "version", "credits", "support", "sapphire update", "check for updates", "release channel", "beta", "automatic updates", "关于", "版本", "检查更新", "测试版", "稳定版"]
        }
    }

    var requiredPermissions: [PermissionType] {
        switch self {
        case .systemEnhance, .hud, .music, .snapZones, .appearance, .dockLayouts, .mediaOptimizer: return [.accessibility]
        case .notifications: return [.notifications]
        case .weather: return [.location]
        case .calendar: return [.calendar, .reminders]
        case .bluetooth, .bluetoothUnlock: return [.bluetooth, .accessibility]
        case .continuity: return [.bluetooth]
        case .liveActivities: return [.focusStatus]
        case .audio: return [.screenRecording]
        case .clipboard: return [.accessibility]
        case .emoji: return [.accessibility]
        case .mouse: return [.accessibility]
        case .intelligence: return [.accessibility, .fullDiskAccess, .screenRecording]
        default: return []
        }
    }

    var label: String {
        switch self {
        case .overview: "概览"; case .general: "通用"; case .systemEnhance: "系统增强"; case .apps: "应用管理"; case .storage: "存储空间"; case .widgets: "小组件"; case .liveActivities: "实时活动"; case .appActivities: "应用活动"; case .fileProgress: "文件传输"; case .appearance: "外观"; case .lockScreen: "锁定屏幕"; case .bluetoothUnlock: "蓝牙靠近解锁"; case .shortcuts: "快捷指令"; case .keyboardShortcuts: "键盘快捷键"; case .snapZones: "窗口磁吸分区"; case .audio: "音频"; case .battery: "电池"; case .bluetooth: "蓝牙"; case .hud: "HUD 浮层"; case .notifications: "通知"; case .nearbyShare: "附近分享"; case .continuity: "跨端互通"; case .fileShelf: "文件暂存架"; case .notes: "备忘录";        case .clipboard: "剪贴板"; case .emoji: "表情符号"; case .mouse: "鼠标"; case .monitoring: "系统监控"; case .devActivity: "开发动态"; case .archives: "归档与 DMG"; case .mirror: "随身镜"; case .caffeine: "保持唤醒"; case .music: "音乐"; case .weather: "天气";        case .calendar: "日历"; case .eyeBreak: "护眼休息"; case .focusSession: "专注时段"; case .appLock: "应用锁"; case .intelligence: "Blip"; case .sports: "体育"; case .finance: "财经"; case .dockLayouts: "程序坞"; case .mediaOptimizer: "媒体优化"; case .about: "关于"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "sparkles"; case .general: "gear"; case .systemEnhance: "macwindow.on.rectangle"; case .apps: "square.stack.3d.up.fill"; case .storage: "internaldrive.fill"; case .widgets: "square.grid.2x2.fill"; case .liveActivities: "timer"; case .appActivities: "video.bubble.fill"; case .fileProgress: "arrow.down.circle.fill"; case .appearance: "paintpalette"; case .lockScreen: "lock.fill"; case .bluetoothUnlock: "lock.laptopcomputer"; case .shortcuts: "square.grid.3x1.below.line.grid.1x2"; case .keyboardShortcuts: "keyboard"; case .snapZones: "uiwindow.split.2x1"; case .audio: "waveform"; case .battery: "battery.100"; case .bluetooth: "macbook.and.ipad"; case .hud: "macwindow.on.rectangle"; case .notifications: "bell"; case .nearbyShare: "shareplay"; case .continuity: "iphone.gen3.radiowaves.left.and.right"; case .fileShelf: "tray.full.fill"; case .notes: "note.text";        case .clipboard: "list.clipboard"; case .emoji: "face.smiling"; case .mouse: "computermouse.fill"; case .monitoring: "gauge.with.dots.needle.50percent"; case .devActivity: "hammer.circle.fill"; case .archives: "archivebox.fill"; case .mirror: "camera.fill"; case .caffeine: "cup.and.saucer.fill"; case .music: "music.note"; case .weather: "cloud.sun.fill";        case .calendar: "calendar"; case .eyeBreak: "eye.fill"; case .focusSession: "moon.fill"; case .appLock: "lock.shield.fill"; case .intelligence: "sparkle"; case .sports: "sportscourt"; case .finance: "chart.line.uptrend.xyaxis"; case .dockLayouts: "dock.rectangle"; case .mediaOptimizer: "photo"; case .about: "info.circle"
        }
    }

    var iconBackgroundColor: Color {
        switch self {
        case .overview: .purple; case .general: .black; case .systemEnhance: .blue; case .apps: .purple; case .storage: .orange; case .widgets: .gray; case .liveActivities: .cyan; case .appActivities: .green; case .fileProgress: .blue; case .appearance: .indigo; case .lockScreen: .red; case .bluetoothUnlock: .indigo; case .shortcuts: .orange; case .keyboardShortcuts: .purple; case .snapZones: .blue; case .audio: .red; case .battery: .green; case .bluetooth: .blue; case .hud: .indigo; case .notifications: .red; case .nearbyShare: .blue; case .continuity: .green; case .fileShelf: .orange; case .notes: .yellow;        case .clipboard: .mint; case .emoji: .indigo; case .mouse: .teal; case .monitoring: .green; case .devActivity: .purple; case .archives: .brown; case .mirror: .indigo; case .caffeine: .brown; case .music: .pink; case .weather: .blue;        case .calendar: .red; case .eyeBreak: .teal; case .focusSession: .purple; case .appLock: .red; case .intelligence: .mint; case .sports: .green; case .finance: .green; case .dockLayouts: .cyan; case .mediaOptimizer: .orange; case .about: .blue
        }
    }

    var iconGradientColors: [Color] {
        switch self {
        case .overview: return [Color(hue: 0.78, saturation: 0.45, brightness: 0.90), Color(hue: 0.62, saturation: 0.55, brightness: 0.70)]
        case .general: return [.black, .gray]
        case .systemEnhance: return [Color(hue: 0.52, saturation: 0.34, brightness: 0.82), Color(hue: 0.52, saturation: 0.48, brightness: 0.56)]
        case .apps: return [Color(hue: 0.58, saturation: 0.38, brightness: 0.88), Color(hue: 0.58, saturation: 0.52, brightness: 0.64)]
        case .storage: return [Color(hue: 0.09, saturation: 0.42, brightness: 0.82), Color(hue: 0.09, saturation: 0.54, brightness: 0.57)]
        case .widgets: return [.gray, .blue]
        case .liveActivities: return [.cyan, .green]
        case .appActivities: return [.green, .teal]
        case .fileProgress: return [.blue, .cyan]
        case .appearance: return [Color(hue: 0.70, saturation: 0.38, brightness: 0.86), Color(hue: 0.70, saturation: 0.52, brightness: 0.60)]
        case .lockScreen: return [Color(hue: 0.98, saturation: 0.48, brightness: 0.88), Color(hue: 0.98, saturation: 0.60, brightness: 0.62)]
        case .bluetoothUnlock: return [.indigo, .teal]
        case .shortcuts: return [Color(hue: 0.75, saturation: 0.36, brightness: 0.86), Color(hue: 0.75, saturation: 0.50, brightness: 0.60)]
        case .keyboardShortcuts: return [Color(hue: 0.78, saturation: 0.40, brightness: 0.86), Color(hue: 0.78, saturation: 0.54, brightness: 0.60)]
        case .snapZones: return [Color(hue: 0.60, saturation: 0.46, brightness: 0.88), Color(hue: 0.60, saturation: 0.60, brightness: 0.63)]
        case .audio: return [Color(hue: 0.57, saturation: 0.40, brightness: 0.87), Color(hue: 0.57, saturation: 0.54, brightness: 0.61)]
        case .battery: return [Color(hue: 0.36, saturation: 0.44, brightness: 0.84), Color(hue: 0.36, saturation: 0.58, brightness: 0.58)]
        case .bluetooth: return [.blue, .cyan]
        case .hud: return [.indigo, .cyan]
        case .notifications: return [.red, .pink]
        case .nearbyShare: return [Color(hue: 0.56, saturation: 0.44, brightness: 0.88), Color(hue: 0.56, saturation: 0.58, brightness: 0.62)]
        case .continuity: return [Color(hue: 0.38, saturation: 0.42, brightness: 0.84), Color(hue: 0.38, saturation: 0.56, brightness: 0.58)]
        case .fileShelf: return [.orange, .brown]
        case .notes: return [Color(hue: 0.13, saturation: 0.48, brightness: 0.93), Color(hue: 0.13, saturation: 0.60, brightness: 0.69)]
        case .clipboard: return [Color(hue: 0.46, saturation: 0.38, brightness: 0.86), Color(hue: 0.46, saturation: 0.52, brightness: 0.59)]
        case .emoji: return [Color(hue: 0.13, saturation: 0.44, brightness: 0.94), Color(hue: 0.13, saturation: 0.56, brightness: 0.70)]
        case .mouse: return [Color(hue: 0.61, saturation: 0.08, brightness: 0.70), Color(hue: 0.61, saturation: 0.14, brightness: 0.43)]
        case .monitoring: return [Color(hue: 0.47, saturation: 0.40, brightness: 0.82), Color(hue: 0.47, saturation: 0.54, brightness: 0.56)]
        case .devActivity: return [Color(hue: 0.64, saturation: 0.40, brightness: 0.84), Color(hue: 0.64, saturation: 0.54, brightness: 0.58)]
        case .archives: return [.brown, .gray]
        case .mirror: return [Color(hue: 0.52, saturation: 0.40, brightness: 0.88), Color(hue: 0.52, saturation: 0.54, brightness: 0.60)]
        case .caffeine: return [Color(hue: 0.07, saturation: 0.38, brightness: 0.72), Color(hue: 0.07, saturation: 0.50, brightness: 0.48)]
        case .music: return [Color(hue: 0.91, saturation: 0.42, brightness: 0.88), Color(hue: 0.91, saturation: 0.56, brightness: 0.61)]
        case .weather: return [.blue, .mint]
        case .calendar: return [Color(hue: 0.01, saturation: 0.44, brightness: 0.89), Color(hue: 0.01, saturation: 0.58, brightness: 0.63)]
        case .eyeBreak: return [Color(hue: 0.48, saturation: 0.34, brightness: 0.84), Color(hue: 0.48, saturation: 0.48, brightness: 0.57)]
        case .focusSession: return [Color(hue: 0.74, saturation: 0.38, brightness: 0.84), Color(hue: 0.74, saturation: 0.52, brightness: 0.58)]
        case .appLock: return [Color(hue: 0.98, saturation: 0.48, brightness: 0.84), Color(hue: 0.98, saturation: 0.62, brightness: 0.54)]
        case .intelligence: return [Color(hue: 0.45, saturation: 0.42, brightness: 0.86), Color(hue: 0.78, saturation: 0.46, brightness: 0.78)]
        case .sports: return [Color(hue: 0.61, saturation: 0.42, brightness: 0.86), Color(hue: 0.61, saturation: 0.56, brightness: 0.59)]
        case .finance: return [Color(hue: 0.43, saturation: 0.42, brightness: 0.80), Color(hue: 0.43, saturation: 0.56, brightness: 0.53)]
        case .dockLayouts: return [Color(hue: 0.52, saturation: 0.40, brightness: 0.87), Color(hue: 0.52, saturation: 0.54, brightness: 0.60)]
        case .mediaOptimizer: return [Color(hue: 0.76, saturation: 0.38, brightness: 0.86), Color(hue: 0.76, saturation: 0.52, brightness: 0.60)]
        case .about: return [Color(hue: 0.60, saturation: 0.12, brightness: 0.76), Color(hue: 0.60, saturation: 0.24, brightness: 0.50)]
        }
    }
}

extension SettingsSection {
    static func features(requiring permission: PermissionType) -> [SettingsSection] {
        allCases.filter { $0.requiredPermissions.contains(permission) }
    }
}

@MainActor
class SystemAppFetcher: ObservableObject {
    static let shared = SystemAppFetcher()

    @Published private(set) var apps: [SystemApp] = []
    @Published private(set) var foundBundleIDs: Set<String> = []
    private var shouldDiscardFetch = false
    private var fetchTask: Task<Void, Never>?

    private init() {}

    func fetchApps() {
        guard apps.isEmpty, fetchTask == nil else { return }
        shouldDiscardFetch = false

        fetchTask = Task { @MainActor [weak self] in
            let worker = Task.detached(priority: .utility) {
                Self.scanInstalledApps()
            }
            let result = await withTaskCancellationHandler {
                await worker.value
            } onCancel: {
                worker.cancel()
            }

            guard let self else { return }
            defer { self.fetchTask = nil }
            guard !self.shouldDiscardFetch, !Task.isCancelled, let result else { return }
            self.apps = result.apps
            self.foundBundleIDs = result.bundleIDs
        }
    }

    nonisolated private static func scanInstalledApps() -> (apps: [SystemApp], bundleIDs: Set<String>)? {
        var fetchedApps: [SystemApp] = []
        var seenBundleIDs = Set<String>()
        let fileManager = FileManager.default
        let searchPaths = ["/System/Applications", "/Applications"]
            + NSSearchPathForDirectoriesInDomains(.applicationDirectory, .userDomainMask, true)

        for path in searchPaths {
            guard !Task.isCancelled else { return nil }
            guard let enumerator = fileManager.enumerator(
                at: URL(fileURLWithPath: path),
                includingPropertiesForKeys: [.isApplicationKey, .nameKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: nil
            ) else { continue }

            while let url = enumerator.nextObject() as? URL {
                guard !Task.isCancelled else { return nil }
                guard url.pathExtension == "app",
                      let bundle = Bundle(url: url),
                      let bundleID = bundle.bundleIdentifier,
                      seenBundleIDs.insert(bundleID).inserted else { continue }

                fetchedApps.append(SystemApp(
                    id: bundleID,
                    name: fileManager.displayName(atPath: url.path),
                    isBrowser: isBrowser(bundle: bundle),
                    url: url
                ))
            }
        }

        fetchedApps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return (fetchedApps, seenBundleIDs)
    }

    func releaseCachedApps() {
        shouldDiscardFetch = true
        fetchTask?.cancel()
        fetchTask = nil
        apps.removeAll(keepingCapacity: false)
        foundBundleIDs.removeAll(keepingCapacity: false)
        AppIconLoader.releaseCache()
    }

    nonisolated private static func isBrowser(bundle: Bundle?) -> Bool {
        guard let bundle = bundle, let urlTypes = bundle.infoDictionary?["CFBundleURLTypes"] as? [[String: Any]] else { return false }

        return urlTypes.contains { type in
            if let schemes = type["CFBundleURLSchemes"] as? [String] {
                return schemes.contains("http") || schemes.contains("https")
            }
            return false
        }
    }
}