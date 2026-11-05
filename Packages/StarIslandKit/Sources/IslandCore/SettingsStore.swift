import Combine
import Foundation

public enum SettingSection: String, CaseIterable, Identifiable, Codable, Sendable {
    case general
    case island
    case media
    case productivity
    case systemEnhance
    case hardware
    case widgets
    case aiConnect
    case permissions
    case about

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .general: return "通用"
        case .island: return "灵动岛与外观"
        case .media: return "媒体与空间音效"
        case .productivity: return "效率与视觉工具"
        case .systemEnhance: return "窗口、Dock与键鼠"
        case .hardware: return "电池风扇与清理"
        case .widgets: return "小组件与实时活动"
        case .aiConnect: return "AI 助手与手机互联"
        case .permissions: return "系统权限"
        case .about: return "关于与更新"
        }
    }

    public var iconSymbol: String {
        switch self {
        case .general: return "gearshape.fill"
        case .island: return "menubar.dock.rectangle"
        case .media: return "waveform.circle.fill"
        case .productivity: return "sparkles.rectangle.stack.fill"
        case .systemEnhance: return "macwindow.on.rectangle"
        case .hardware: return "bolt.batteryblock.fill"
        case .widgets: return "square.grid.2x2.fill"
        case .aiConnect: return "brain.head.profile"
        case .permissions: return "hand.raised.shield.fill"
        case .about: return "star.circle.fill"
        }
    }
}

public struct SettingSearchItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let keywords: [String]
    public let section: SettingSection

    public init(id: String, title: String, detail: String, keywords: [String], section: SettingSection) {
        self.id = id
        self.title = title
        self.detail = detail
        self.keywords = keywords
        self.section = section
    }
}

public struct StarIslandSettings: Codable, Equatable, Sendable {
    // 通用与灵动岛外观
    public var launchAtLogin: Bool = false
    public var hasCompletedOnboarding: Bool = false
    public var showMenuBarIcon: Bool = true
    public var islandScale: Double = 1.0
    public var hoverExpandDelayMs: Int = 180
    public var showOnExternalDisplays: Bool = true
    public var showOnLockScreen: Bool = true
    public var autoCheckUpdates: Bool = true

    // 媒体、歌词与音效
    public var enableNowPlaying: Bool = true
    public var enableSyncedLyrics: Bool = true
    public var showDesktopFloatingLyrics: Bool = false
    public var enableAudioSpectrum: Bool = true
    public var enableSurroundAudio: Bool = false
    public var enableEightDAudio: Bool = false
    public var eightDRotationHz: Double = 0.14
    public var enableCustomVolumeHUD: Bool = true
    public var enableCustomBrightnessHUD: Bool = true

    // 效率与视觉工具
    public var enableSmartOTP: Bool = true
    public var autoCopyOTP: Bool = true
    public var enableParcelTracking: Bool = true
    public var enableClipboardHistory: Bool = true
    public var clipboardMaxItems: Int = 120
    public var clipboardAutoClearMinutes: Int = 0
    public var enableCleanURL: Bool = true
    public var customBlockedURLParams: [String] = []
    public var enableDropzoneShelf: Bool = true
    public var imageCompressionQuality: Double = 0.80

    // 窗口、Dock 与键鼠安全增强
    public var enableWindowSnap: Bool = true
    public var enableWindowSwitcher: Bool = true
    public var enableDockHoverPreview: Bool = true
    public var enableDockClickMinimize: Bool = false
    public var enableHoldCommandQ: Bool = true
    public var holdCommandQDurationSeconds: Double = 0.8
    public var enableFinderCutPaste: Bool = true
    public var enableGreenButtonZoomMaximize: Bool = false
    public var enableSmoothMouseScroll: Bool = false
    public var reverseMouseScrollOnly: Bool = false
    public var enableFocusFollowsMouse: Bool = false
    public var mouseClickDebounceMs: Int = 0
    public var keyboardDebounceMs: Int = 0
    public var enableEmojiShortcut: Bool = true
    public var enableAppLock: Bool = false
    public var lockedAppBundleIDs: [String] = []
    public var appLockRelockIntervalSeconds: Int = 60

    // 硬件电池风扇与系统清理
    public var enableBatteryChargeLimit: Bool = false
    public var batteryChargeLimit: Int = 80
    public var batterySailingDropPercent: Int = 5
    public var enableThermalChargeProtection: Bool = true
    public var maxChargeTemperatureCelsius: Double = 42.0
    public var fanControlMode: String = "auto" // auto, quiet, balanced, turbo, curve
    public var enableDMGAutoInstallHelper: Bool = true

    // 小组件与实时活动
    public var enableWeatherWidget: Bool = true
    public var weatherCityName: String = "北京"
    public var weatherLatitude: Double = 39.9042
    public var weatherLongitude: Double = 116.4074
    public var weatherUseCelsius: Bool = true
    public var enableCalendarWidget: Bool = true
    public var enableRemindersWidget: Bool = true
    public var enableBluetoothBatteryWidget: Bool = true
    public var enableSportsLiveActivity: Bool = true
    public var favoriteSportsLeague: String = "basketball/nba"
    public var enableFinanceWidget: Bool = true
    public var watchlistSymbols: [String] = ["AAPL", "NVDA", "BTCUSDT", "ETHUSDT"]
    public var enableEyeBreakReminder: Bool = false
    public var eyeBreakIntervalMinutes: Int = 20
    public var enableTerminalLiveActivity: Bool = true
    public var focusBlockedDomains: [String] = []
    public var focusBlockedAppBundleIDs: [String] = []

    // AI 助手与局域网手机互联
    public var activeAIProvider: String = "gemini" // gemini, openAICompatible, ollama
    public var geminiModel: String = "gemini-2.5-flash"
    public var openAIBaseURL: String = "https://api.openai.com/v1"
    public var openAIModel: String = "gpt-4o-mini"
    public var ollamaBaseURL: String = "http://127.0.0.1:11434"
    public var ollamaModel: String = "qwen2.5:7b"
    public var enableLANContinuityServer: Bool = true
    public var lanServerPort: UInt16 = 48620

    public init() {}
}

@MainActor
public final class SettingsStore: ObservableObject {
    public static let shared = SettingsStore(
        fileURL: StarIslandPaths.appSupportDirectory.appendingPathComponent("settings.json")
    )

    @Published public var settings: StarIslandSettings {
        didSet {
            guard settings != oldValue else { return }
            persist()
        }
    }

    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(StarIslandSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = StarIslandSettings()
        }
    }

    public func persist() {
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(settings) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    public func exportJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(settings)
    }

    public func importJSON(_ data: Data) throws {
        let decoded = try JSONDecoder().decode(StarIslandSettings.self, from: data)
        self.settings = decoded
    }

    public func resetToDefaults() {
        self.settings = StarIslandSettings()
    }

    public func search(_ query: String) -> [SettingSearchItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return Self.catalog }
        return Self.catalog.filter { item in
            item.title.lowercased().contains(trimmed)
                || item.detail.lowercased().contains(trimmed)
                || item.keywords.contains(where: { $0.lowercased().contains(trimmed) })
        }
    }

    public static let catalog: [SettingSearchItem] = [
        .init(id: "launchAtLogin", title: "开机自动启动", detail: "登录 macOS 时自动在后台启动星岛", keywords: ["启动", "登录", "launch", "login"], section: .general),
        .init(id: "islandScale", title: "灵动岛缩放比例与锁屏显示", detail: "调整灵动岛尺寸、外接显示器与锁屏展示", keywords: ["尺寸", "刘海", "锁屏", "外接屏", "notch"], section: .island),
        .init(id: "syncedLyrics", title: "逐行同步歌词与 8D 空间音效", detail: "Apple Music / Spotify 歌词同步、实时频谱与 8D 环绕声", keywords: ["歌词", "音乐", "频谱", "8d", "环绕声", "音量", "hud"], section: .media),
        .init(id: "smartOTP", title: "智能验证码与快递单号识别", detail: "双因子语义过滤验证码并严格去重，支持一键或自动复制", keywords: ["验证码", "otp", "短信", "快递", "通知"], section: .productivity),
        .init(id: "clipboard", title: "剪贴板历史选择器与追踪链接净化", detail: "全局快捷键呼出剪贴板历史，自动清洗 utm/spm 等追踪参数", keywords: ["剪贴板", "粘贴", "url", "链接", "隐私"], section: .productivity),
        .init(id: "ocrCircle", title: "文件暂存架、媒体压缩与离线 OCR 圈选搜索", detail: "图片/PDF/视频本地压缩转换，Apple Vision 离线文字识别与圈选识图", keywords: ["暂存架", "dropzone", "压缩", "ocr", "圈选", "pdf"], section: .productivity),
        .init(id: "windowDock", title: "窗口磁吸分屏与 Dock 悬停实时窗口预览", detail: "边缘拖拽多分屏磁吸、窗口切换器与 Dock 实时缩略图预览", keywords: ["窗口", "磁吸", "分屏", "dock", "预览"], section: .systemEnhance),
        .init(id: "keyMouseLock", title: "Finder 剪切、长按 ⌘Q、键鼠增强与 Touch ID 应用锁", detail: "防误触退出、绿灯最大化、鼠标平滑/防连击、Emoji 联想与指纹应用锁", keywords: ["finder", "剪切", "鼠标", "键盘", "emoji", "应用锁", "touch id", "指纹"], section: .systemEnhance),
        .init(id: "batteryChargeLimit", title: "电池充电上限、高温保护与风扇转速控制", detail: "SMC 80% 充电保护、巡航模式、风扇温控曲线与应用深度卸载", keywords: ["电池", "充电上限", "80%", "风扇", "温度", "卸载", "dmg"], section: .hardware),
        .init(id: "liveWidgets", title: "天气、日程、蓝牙、体育实时比分与股票行情", detail: "免 Key 实时天气、NBA/足球比分、美股港股加密货币、计时护眼与随身镜", keywords: ["天气", "日历", "蓝牙", "体育", "nba", "股票", "比特币", "随身镜", "专注", "终端"], section: .widgets),
        .init(id: "aiContinuity", title: "星岛 AI 灵动助手与手机免装 App 扫码互联", detail: "接入 Gemini / OpenAI / DeepSeek / 本地 Ollama，手机扫码双向快传与剪贴板同步", keywords: ["ai", "gemini", "openai", "ollama", "deepseek", "翻译", "手机", "安卓", "快传", "二维码"], section: .aiConnect),
        .init(id: "permissions", title: "系统权限状态与一键修复", detail: "管理辅助功能、屏幕录制、本地网络、自动化、日历与摄像头权限", keywords: ["权限", "辅助功能", "本地网络", "自动化", "屏幕录制"], section: .permissions),
        .init(id: "selfUpdate", title: "软件内检查更新与一键升级", detail: "连接 adgry/StarIsland GitHub 仓库检查新版本并自动安装", keywords: ["更新", "版本", "github", "升级"], section: .about),
    ]
}
