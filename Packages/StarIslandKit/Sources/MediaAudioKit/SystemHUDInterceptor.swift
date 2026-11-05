import AppKit
import AudioToolbox
import CoreAudio
import Foundation
import IslandCore

/// 系统原生 HUD 接管类型
public enum SystemHUDKind: String, CaseIterable, Codable, Equatable, Sendable {
    case volume
    case brightness
    case keyboardBacklight
    case audioOutputRoute

    public var defaultTitle: String {
        switch self {
        case .volume: return "系统音量"
        case .brightness: return "屏幕亮度"
        case .keyboardBacklight: return "键盘背光"
        case .audioOutputRoute: return "音频输出已切换"
        }
    }
}

/// HUD 渲染状态快照
public struct SystemHUDSnapshot: Equatable, Sendable {
    public let kind: SystemHUDKind
    public let value: Double
    public let percentage: Int
    public let isMuted: Bool
    public let iconSymbol: String
    public let title: String
    public let subtitle: String
    public let badgeText: String
    public let effectiveProgress: Double
}

/// 原生系统音量 / 屏幕亮度 / 键盘背光 / 蓝牙音频设备 HUD 接管器
@MainActor
public final class SystemHUDInterceptor: ObservableObject {
    public static let shared = SystemHUDInterceptor()
    public static let activityID = "system.hud"

    public enum MediaKeyType {
        public static let soundUp: Int32 = 0
        public static let soundDown: Int32 = 1
        public static let brightnessUp: Int32 = 2
        public static let brightnessDown: Int32 = 3
        public static let mute: Int32 = 7
        public static let playPause: Int32 = 16
        public static let next: Int32 = 17
        public static let previous: Int32 = 18
        public static let rewind: Int32 = 20
        public static let illuminationUp: Int32 = 21
        public static let illuminationDown: Int32 = 22
    }

    @Published public private(set) var latestHUD: SystemHUDSnapshot?
    @Published public private(set) var currentVolume: Double = 0.5
    @Published public private(set) var isMuted: Bool = false
    @Published public private(set) var currentBrightness: Double = 0.75
    @Published public private(set) var currentKeyboardBacklight: Double = 0.5
    @Published public private(set) var outputDeviceName: String = "内置扬声器"
    @Published public private(set) var isObservingHardware: Bool = false

    private let stateMachine: IslandStateMachine
    private let settingsStore: SettingsStore

    private var monitoredDeviceID: AudioDeviceID = kAudioObjectUnknown
    private var defaultDeviceListenerBlock: AudioObjectPropertyListenerBlock?
    private var volumeListenerBlock: AudioObjectPropertyListenerBlock?
    private var muteListenerBlock: AudioObjectPropertyListenerBlock?
    private let listenerQueue = DispatchQueue(label: "com.adgry.starisland.coreaudio.hud", qos: .userInteractive)

    public init(
        stateMachine: IslandStateMachine? = nil,
        settingsStore: SettingsStore? = nil,
        observeCoreAudio: Bool = false
    ) {
        self.stateMachine = stateMachine ?? .shared
        self.settingsStore = settingsStore ?? .shared
        if observeCoreAudio { startObserving() }
    }

    /// 钳制输入百分比至 [0, 1] 安全区间
    public nonisolated static func clampUnitValue(_ raw: Double) -> Double {
        guard raw.isFinite else { return 0.0 }
        return min(max(raw, 0.0), 1.0)
    }

    /// 根据 HUD 类型、归一化数值与静音标志解析 SF Symbol 图标
    public static func resolveIconSymbol(kind: SystemHUDKind, clampedValue: Double, isMuted: Bool) -> String {
        switch kind {
        case .volume:
            if isMuted || clampedValue <= 0.001 { return "speaker.slash.fill" }
            if clampedValue < 0.34 { return "speaker.wave.1.fill" }
            if clampedValue < 0.67 { return "speaker.wave.2.fill" }
            return "speaker.wave.3.fill"
        case .brightness:
            return clampedValue < 0.5 ? "sun.min.fill" : "sun.max.fill"
        case .keyboardBacklight:
            return clampedValue <= 0.001 ? "light.min" : "light.max"
        case .audioOutputRoute:
            return "airpodspro"
        }
    }

    /// 推送系统 HUD 至灵动岛（生成 isAlertHUD = true 的高优瞬态浮层）
    public func presentHUD(
        kind: SystemHUDKind,
        value: Double,
        isMuted: Bool = false,
        customSubtitle: String? = nil
    ) {
        let clamped = Self.clampUnitValue(value)
        let percentage = Int((clamped * 100.0).rounded())
        let icon = Self.resolveIconSymbol(kind: kind, clampedValue: clamped, isMuted: isMuted)

        let effectiveProgress = (kind == .volume && isMuted) ? 0.0 : clamped
        let badge = (kind == .volume && isMuted) ? "静音" : "\(percentage)%"

        let subtitle: String
        if let customSubtitle, !customSubtitle.isEmpty {
            subtitle = customSubtitle
        } else {
            switch kind {
            case .volume:
                subtitle = isMuted ? "\(outputDeviceName) · 已静音" : outputDeviceName
            case .brightness:
                subtitle = "内建视网膜显示器"
            case .keyboardBacklight:
                subtitle = percentage == 0 ? "背光已关闭" : "环境光自适应背光"
            case .audioOutputRoute:
                subtitle = outputDeviceName
            }
        }

        switch kind {
        case .volume, .audioOutputRoute:
            currentVolume = clamped
            self.isMuted = isMuted
        case .brightness:
            currentBrightness = clamped
        case .keyboardBacklight:
            currentKeyboardBacklight = clamped
        }

        let snapshot = SystemHUDSnapshot(
            kind: kind,
            value: clamped,
            percentage: percentage,
            isMuted: isMuted,
            iconSymbol: icon,
            title: kind.defaultTitle,
            subtitle: subtitle,
            badgeText: badge,
            effectiveProgress: effectiveProgress
        )
        latestHUD = snapshot

        guard isHUDSettingEnabled(for: kind) else { return }

        stateMachine.submit(IslandActivityItem(
            id: Self.activityID,
            category: .systemHUD,
            title: snapshot.title,
            subtitle: snapshot.subtitle,
            iconSymbol: snapshot.iconSymbol,
            trailingBadge: snapshot.badgeText,
            progress: snapshot.effectiveProgress,
            priority: .interactive,
            isAlertHUD: true,
            isPeek: false,
            allowsOnLockScreen: true,
            autoDismissAfter: 1.65,
            updatedAt: Date()
        ))
    }

    // MARK: - 媒体功能键响应接口（标准 1/16 步进与 ⌥⇧ 1/64 微调步进）

    @discardableResult
    public func handleMediaKey(
        keyType: Int32,
        isKeyDown: Bool = true,
        fineStep: Bool = false,
        applyHardwareStep: Bool = true
    ) -> Bool {
        guard isKeyDown else { return true }
        let step = fineStep ? (1.0 / 64.0) : (1.0 / 16.0)

        switch keyType {
        case MediaKeyType.soundUp:
            guard settingsStore.settings.enableCustomVolumeHUD else { return false }
            if applyHardwareStep {
                let next = Self.clampUnitValue((isMuted ? 0.0 : currentVolume) + step)
                setSystemVolume(next)
                presentHUD(kind: .volume, value: next, isMuted: false)
            }
            return true

        case MediaKeyType.soundDown:
            guard settingsStore.settings.enableCustomVolumeHUD else { return false }
            if applyHardwareStep {
                let next = Self.clampUnitValue(currentVolume - step)
                setSystemVolume(next)
                presentHUD(kind: .volume, value: next, isMuted: next <= 0.001)
            }
            return true

        case MediaKeyType.mute:
            guard settingsStore.settings.enableCustomVolumeHUD else { return false }
            if applyHardwareStep {
                let nextMuted = !isMuted
                setSystemMute(nextMuted)
                presentHUD(kind: .volume, value: currentVolume, isMuted: nextMuted)
            }
            return true

        case MediaKeyType.brightnessUp:
            guard settingsStore.settings.enableCustomBrightnessHUD else { return false }
            let base = Self.readSystemDisplayBrightness() ?? currentBrightness
            let next = Self.clampUnitValue(base + step)
            if applyHardwareStep {
                Self.setSystemDisplayBrightness(next)
            }
            presentHUD(kind: .brightness, value: next)
            return true

        case MediaKeyType.brightnessDown:
            guard settingsStore.settings.enableCustomBrightnessHUD else { return false }
            let base = Self.readSystemDisplayBrightness() ?? currentBrightness
            let next = Self.clampUnitValue(base - step)
            if applyHardwareStep {
                Self.setSystemDisplayBrightness(next)
            }
            presentHUD(kind: .brightness, value: next)
            return true

        case MediaKeyType.illuminationUp:
            guard settingsStore.settings.enableCustomBrightnessHUD else { return false }
            presentHUD(kind: .keyboardBacklight, value: Self.clampUnitValue(currentKeyboardBacklight + step))
            return true

        case MediaKeyType.illuminationDown:
            guard settingsStore.settings.enableCustomBrightnessHUD else { return false }
            presentHUD(kind: .keyboardBacklight, value: Self.clampUnitValue(currentKeyboardBacklight - step))
            return true

        case MediaKeyType.playPause:
            if applyHardwareStep {
                NowPlayingService.shared.togglePlayPause()
            }
            return true

        case MediaKeyType.next:
            if applyHardwareStep {
                NowPlayingService.shared.nextTrack()
            }
            return true

        case MediaKeyType.previous, MediaKeyType.rewind:
            if applyHardwareStep {
                NowPlayingService.shared.previousTrack()
            }
            return true

        default:
            return false
        }
    }

    // MARK: - CoreAudio 默认输出设备与音量静音监听

    public func startObserving() {
        guard !isObservingHardware else { return }
        isObservingHardware = true
        syncHardwareState(emitHUD: false, isRouteChange: false)

        var defaultDevAddr = Self.makeAddress(kAudioHardwarePropertyDefaultOutputDevice, scope: kAudioObjectPropertyScopeGlobal)
        let routeBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in self?.rebindOutputDeviceListeners(emitRouteHUD: true) }
        }
        defaultDeviceListenerBlock = routeBlock
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &defaultDevAddr, listenerQueue, routeBlock)
        rebindOutputDeviceListeners(emitRouteHUD: false)
    }

    public func stopObserving() {
        guard isObservingHardware else { return }
        isObservingHardware = false

        if let routeBlock = defaultDeviceListenerBlock {
            var defaultDevAddr = Self.makeAddress(kAudioHardwarePropertyDefaultOutputDevice, scope: kAudioObjectPropertyScopeGlobal)
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &defaultDevAddr, listenerQueue, routeBlock)
            defaultDeviceListenerBlock = nil
        }
        detachDeviceListeners()
    }

    public func setSystemVolume(_ unitValue: Double) {
        let clamped = Float32(Self.clampUnitValue(unitValue))
        let deviceID = Self.readDefaultOutputDeviceID()
        guard deviceID != kAudioObjectUnknown else { return }

        if isMuted && clamped > 0.001 { setSystemMute(false) }

        var vol = clamped
        var virtualAddr = Self.makeAddress(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, scope: kAudioDevicePropertyScopeOutput)
        if AudioObjectHasProperty(deviceID, &virtualAddr) {
            AudioObjectSetPropertyData(deviceID, &virtualAddr, 0, nil, UInt32(MemoryLayout<Float32>.size), &vol)
        }
    }

    public func setSystemMute(_ muted: Bool) {
        let deviceID = Self.readDefaultOutputDeviceID()
        guard deviceID != kAudioObjectUnknown else { return }

        var flag: UInt32 = muted ? 1 : 0
        var muteAddr = Self.makeAddress(kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeOutput)
        if AudioObjectHasProperty(deviceID, &muteAddr) {
            AudioObjectSetPropertyData(deviceID, &muteAddr, 0, nil, UInt32(MemoryLayout<UInt32>.size), &flag)
        }
    }

    // MARK: - CoreAudio 私有辅助

    private func isHUDSettingEnabled(for kind: SystemHUDKind) -> Bool {
        switch kind {
        case .volume, .audioOutputRoute: return settingsStore.settings.enableCustomVolumeHUD
        case .brightness, .keyboardBacklight: return settingsStore.settings.enableCustomBrightnessHUD
        }
    }

    private func rebindOutputDeviceListeners(emitRouteHUD: Bool) {
        detachDeviceListeners()
        let deviceID = Self.readDefaultOutputDeviceID()
        guard deviceID != kAudioObjectUnknown else { return }
        monitoredDeviceID = deviceID

        syncHardwareState(emitHUD: emitRouteHUD, isRouteChange: emitRouteHUD)

        let volBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in self?.syncHardwareState(emitHUD: true, isRouteChange: false) }
        }
        volumeListenerBlock = volBlock
        var volAddr = Self.makeAddress(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, scope: kAudioDevicePropertyScopeOutput)
        if AudioObjectHasProperty(deviceID, &volAddr) {
            AudioObjectAddPropertyListenerBlock(deviceID, &volAddr, listenerQueue, volBlock)
        }

        let muteBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in self?.syncHardwareState(emitHUD: true, isRouteChange: false) }
        }
        muteListenerBlock = muteBlock
        var muteAddr = Self.makeAddress(kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeOutput)
        if AudioObjectHasProperty(deviceID, &muteAddr) {
            AudioObjectAddPropertyListenerBlock(deviceID, &muteAddr, listenerQueue, muteBlock)
        }
    }

    private func detachDeviceListeners() {
        guard monitoredDeviceID != kAudioObjectUnknown else { return }
        if let volBlock = volumeListenerBlock {
            var volAddr = Self.makeAddress(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, scope: kAudioDevicePropertyScopeOutput)
            AudioObjectRemovePropertyListenerBlock(monitoredDeviceID, &volAddr, listenerQueue, volBlock)
            volumeListenerBlock = nil
        }
        if let muteBlock = muteListenerBlock {
            var muteAddr = Self.makeAddress(kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeOutput)
            AudioObjectRemovePropertyListenerBlock(monitoredDeviceID, &muteAddr, listenerQueue, muteBlock)
            muteListenerBlock = nil
        }
        monitoredDeviceID = kAudioObjectUnknown
    }

    private func syncHardwareState(emitHUD: Bool, isRouteChange: Bool) {
        let deviceID = Self.readDefaultOutputDeviceID()
        guard deviceID != kAudioObjectUnknown else { return }

        if let name = Self.readDeviceName(deviceID: deviceID) { outputDeviceName = name }
        let vol = Self.readDeviceVolume(deviceID: deviceID) ?? currentVolume
        let muted = Self.readDeviceMute(deviceID: deviceID) ?? false

        if emitHUD {
            presentHUD(kind: isRouteChange ? .audioOutputRoute : .volume, value: vol, isMuted: muted)
        } else {
            currentVolume = Self.clampUnitValue(vol)
            isMuted = muted
            if let hwBrightness = Self.readSystemDisplayBrightness() {
                currentBrightness = Self.clampUnitValue(hwBrightness)
            }
        }
    }

    private nonisolated static func readSystemDisplayBrightness() -> Double? {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY),
              let sym = dlsym(handle, "DisplayServicesGetBrightness") else {
            return nil
        }
        typealias GetBrightnessFn = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
        let fn = unsafeBitCast(sym, to: GetBrightnessFn.self)
        var level: Float = 0
        guard fn(CGMainDisplayID(), &level) == 0, level.isFinite else {
            return nil
        }
        return Double(level)
    }

    private nonisolated static func setSystemDisplayBrightness(_ unitValue: Double) {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY),
              let sym = dlsym(handle, "DisplayServicesSetBrightness") else {
            return
        }
        typealias SetBrightnessFn = @convention(c) (UInt32, Float) -> Int32
        let fn = unsafeBitCast(sym, to: SetBrightnessFn.self)
        _ = fn(CGMainDisplayID(), Float(clampUnitValue(unitValue)))
    }

    private static func makeAddress(_ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private static func readDefaultOutputDeviceID() -> AudioDeviceID {
        var deviceID = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = makeAddress(kAudioHardwarePropertyDefaultOutputDevice, scope: kAudioObjectPropertyScopeGlobal)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &deviceID)
        return status == noErr ? deviceID : kAudioObjectUnknown
    }

    private static func readDeviceName(deviceID: AudioDeviceID) -> String? {
        var nameRef: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var addr = makeAddress(kAudioObjectPropertyName, scope: kAudioObjectPropertyScopeGlobal)
        let status = AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &nameRef)
        guard status == noErr, let cfStr = nameRef?.takeRetainedValue() else { return nil }
        return cfStr as String
    }

    private static func readDeviceVolume(deviceID: AudioDeviceID) -> Double? {
        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        var addr = makeAddress(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, scope: kAudioDevicePropertyScopeOutput)
        guard AudioObjectHasProperty(deviceID, &addr),
              AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &volume) == noErr else { return nil }
        return Double(volume)
    }

    private static func readDeviceMute(deviceID: AudioDeviceID) -> Bool? {
        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var addr = makeAddress(kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeOutput)
        guard AudioObjectHasProperty(deviceID, &addr),
              AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &muted) == noErr else { return nil }
        return muted != 0
    }
}
