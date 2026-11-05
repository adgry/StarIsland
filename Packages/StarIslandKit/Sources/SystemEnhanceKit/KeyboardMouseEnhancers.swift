import AppKit
import ApplicationServices
import Combine
import CoreGraphics
import Foundation
import IslandCore

/// 鼠标微动开关硬件连击消抖过滤器
public struct ClickDebounceFilter: Sendable {
    public var thresholdMs: Int
    private var lastAcceptedTimestampNsByButton: [Int64: UInt64] = [:]

    public init(thresholdMs: Int = 40) {
        self.thresholdMs = max(0, thresholdMs)
    }

    /// 返回 `true` 表示判定为阈值内的微动硬件抖动连点，应当拦截；返回 `false` 表示正常点击放行
    public mutating func shouldSuppressPress(button: Int64, timestampNs: UInt64) -> Bool {
        guard thresholdMs > 0 else {
            lastAcceptedTimestampNsByButton[button] = timestampNs
            return false
        }
        let windowNs = UInt64(thresholdMs) * 1_000_000
        if let lastNs = lastAcceptedTimestampNsByButton[button],
           timestampNs >= lastNs,
           (timestampNs - lastNs) < windowNs {
            return true
        }
        lastAcceptedTimestampNsByButton[button] = timestampNs
        return false
    }

    public mutating func shouldSuppressPress(button: Int64, timestampSeconds: TimeInterval) -> Bool {
        let ns = UInt64(max(0, timestampSeconds) * 1_000_000_000)
        return shouldSuppressPress(button: button, timestampNs: ns)
    }

    public mutating func reset() {
        lastAcceptedTimestampNsByButton.removeAll()
    }
}

/// 机械键盘轴体双击抖动消抖过滤器（保留正常长按自动连发）
public struct KeyboardDebounceFilter: Sendable {
    public var thresholdMs: Int
    private var lastKeyDownNsByCode: [Int64: UInt64] = [:]

    public init(thresholdMs: Int = 0) {
        self.thresholdMs = max(0, thresholdMs)
    }

    public mutating func shouldSuppressKeyDown(keyCode: Int64, isAutoRepeat: Bool, timestampNs: UInt64) -> Bool {
        if isAutoRepeat { return false }
        guard thresholdMs > 0 else {
            lastKeyDownNsByCode[keyCode] = timestampNs
            return false
        }
        let windowNs = UInt64(thresholdMs) * 1_000_000
        if let previous = lastKeyDownNsByCode[keyCode],
           timestampNs >= previous,
           (timestampNs - previous) < windowNs {
            return true
        }
        lastKeyDownNsByCode[keyCode] = timestampNs
        return false
    }

    public mutating func reset() {
        lastKeyDownNsByCode.removeAll()
    }
}

/// 长按 ⌘Q 防误触状态机决策结果
public enum HoldCommandQDecision: Equatable, Sendable {
    case interceptHolding(progress: Double)
    case allowQuit
    case cancelled
}

/// 长按 ⌘Q 防误触退出状态机
public struct HoldCommandQStateMachine: Sendable {
    public var holdDuration: TimeInterval
    public var whitelistedBundleIDs: Set<String>
    public private(set) var activeBundleID: String?
    public private(set) var pressStartTime: TimeInterval?
    public private(set) var hasTriggeredQuit: Bool = false

    public init(holdDuration: TimeInterval = 0.8, whitelistedBundleIDs: Set<String> = []) {
        self.holdDuration = max(0.1, holdDuration)
        self.whitelistedBundleIDs = whitelistedBundleIDs
    }

    public var isHolding: Bool {
        pressStartTime != nil && !hasTriggeredQuit
    }

    public mutating func handleKeyDown(bundleID: String?, timestamp: TimeInterval) -> HoldCommandQDecision {
        if let bid = bundleID, whitelistedBundleIDs.contains(bid) {
            reset()
            return .allowQuit
        }
        if pressStartTime == nil || activeBundleID != bundleID {
            pressStartTime = timestamp
            activeBundleID = bundleID
            hasTriggeredQuit = false
            return .interceptHolding(progress: 0.0)
        }
        return evaluateHoldProgress(at: timestamp)
    }

    public mutating func evaluateHoldProgress(at timestamp: TimeInterval) -> HoldCommandQDecision {
        guard let start = pressStartTime else { return .cancelled }
        if hasTriggeredQuit { return .allowQuit }
        let elapsed = max(0, timestamp - start)
        if elapsed >= holdDuration {
            hasTriggeredQuit = true
            return .allowQuit
        }
        let progress = min(max(elapsed / holdDuration, 0.0), 0.999)
        return .interceptHolding(progress: progress)
    }

    @discardableResult
    public mutating func handleKeyRelease() -> HoldCommandQDecision {
        reset()
        return .cancelled
    }

    public mutating func reset() {
        pressStartTime = nil
        activeBundleID = nil
        hasTriggeredQuit = false
    }
}

/// Finder ⌘X 剪切与 ⌘V 自动转移动状态机
public struct FinderCutPasteTracker: Sendable {
    public enum Action: Equatable, Sendable {
        case none
        case synthesizeCopyAndArmCut
        case convertPasteToMove
    }

    public private(set) var isCutArmed: Bool = false

    public init() {}

    public mutating func handleFinderCommandKey(keyCode: Int64, flags: CGEventFlags) -> Action {
        let relevant = flags.intersection([.maskCommand, .maskAlternate, .maskControl, .maskShift])
        guard relevant == .maskCommand else { return .none }
        switch keyCode {
        case 7:
            isCutArmed = true
            return .synthesizeCopyAndArmCut
        case 8:
            isCutArmed = false
            return .none
        case 9:
            if isCutArmed {
                isCutArmed = false
                return .convertPasteToMove
            }
            return .none
        default:
            return .none
        }
    }
}

/// 键盘与鼠标全套效率增强协调器
@MainActor
public final class KeyboardMouseEnhancersController: ObservableObject {
    public static let shared = KeyboardMouseEnhancersController()

    private final class LockedEventState: @unchecked Sendable {
        let lock = NSLock()
        var clickDebounce = ClickDebounceFilter(thresholdMs: 0)
        var keyDebounce = KeyboardDebounceFilter(thresholdMs: 0)
        var holdCmdQ = HoldCommandQStateMachine(holdDuration: 0.8)
        var finderCutTracker = FinderCutPasteTracker()
        var smoothedScrollResidue: Double = 0

        func evaluateHoldProgressSync(at uptime: TimeInterval) -> HoldCommandQDecision {
            lock.withLock { holdCmdQ.evaluateHoldProgress(at: uptime) }
        }
    }

    private let settingsStore: SettingsStore
    private let stateMachine: IslandStateMachine
    private let eventTapBus: EventTapBus
    private let windowRegistry: WindowRegistry
    private let mutationJournal: MutationJournal
    private let eventState = LockedEventState()

    private var tapRegistrationID: UUID?
    private var settingsCancellable: AnyCancellable?
    private var holdProgressTask: Task<Void, Never>?
    private var lastFocusFollowCheck: TimeInterval = 0
    private var savedZoomPreMaximizeFrames: [String: CGRect] = [:]

    private let holdHUDActivityID = "systemenhance.hold-cmd-q"
    private let finderCutHUDActivityID = "systemenhance.finder-cut"

    public init(
        settingsStore: SettingsStore? = nil,
        stateMachine: IslandStateMachine? = nil,
        eventTapBus: EventTapBus? = nil,
        windowRegistry: WindowRegistry? = nil,
        mutationJournal: MutationJournal? = nil
    ) {
        self.settingsStore = settingsStore ?? .shared
        self.stateMachine = stateMachine ?? .shared
        self.eventTapBus = eventTapBus ?? .shared
        self.windowRegistry = windowRegistry ?? .shared
        self.mutationJournal = mutationJournal ?? .shared

        applySettingsSnapshot(self.settingsStore.settings)
        settingsCancellable = self.settingsStore.$settings
            .receive(on: RunLoop.main)
            .sink { [weak self] updated in self?.applySettingsSnapshot(updated) }
    }

    public func start() {
        recoverPendingMouseMutationsIfNeeded()
        guard tapRegistrationID == nil else { return }
        let mask = EventTapEntry.mask(for: [
            .leftMouseDown, .rightMouseDown, .otherMouseDown,
            .mouseMoved, .scrollWheel, .keyDown, .keyUp, .flagsChanged
        ])
        let entry = EventTapEntry(name: "KeyboardMouseEnhancers", priority: 80, eventMask: mask) { [weak self] context in
            guard let self else { return .passThrough }
            return self.processEventNonisolated(context)
        }
        tapRegistrationID = eventTapBus.register(entry)
    }

    public func stop() {
        if let id = tapRegistrationID {
            eventTapBus.unregister(id)
            tapRegistrationID = nil
        }
        holdProgressTask?.cancel()
        holdProgressTask = nil
        stateMachine.dismiss(id: holdHUDActivityID)
        mutationJournal.clear(.mouseAcceleration)
    }

    private func applySettingsSnapshot(_ s: StarIslandSettings) {
        eventState.lock.lock()
        eventState.clickDebounce.thresholdMs = s.mouseClickDebounceMs
        eventState.keyDebounce.thresholdMs = s.keyboardDebounceMs
        eventState.holdCmdQ.holdDuration = max(0.2, s.holdCommandQDurationSeconds)
        eventState.lock.unlock()

        if s.enableSmoothMouseScroll || s.reverseMouseScrollOnly {
            mutationJournal.record(
                MutationRecord(
                    kind: .mouseAcceleration,
                    previousValue: "system-default",
                    appliedValue: "reverse:\(s.reverseMouseScrollOnly),smooth:\(s.enableSmoothMouseScroll)"
                )
            )
        } else {
            mutationJournal.clear(.mouseAcceleration)
        }
    }

    private func recoverPendingMouseMutationsIfNeeded() {
        if mutationJournal.pendingRecords().contains(where: { $0.kind == .mouseAcceleration }),
           !settingsStore.settings.enableSmoothMouseScroll,
           !settingsStore.settings.reverseMouseScrollOnly {
            mutationJournal.clear(.mouseAcceleration)
        }
    }

    // MARK: - 实时事件处理管线

    private nonisolated func processEventNonisolated(_ context: EventTapContext) -> EventTapDisposition {
        switch context.eventType {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            return handleMousePressNonisolated(context)
        case .scrollWheel:
            return handleScrollWheelNonisolated(context)
        case .mouseMoved:
            Task { @MainActor [weak self] in self?.handleFocusFollowsMouse(quartzLocation: context.location) }
            return .passThrough
        case .keyDown:
            return handleKeyDownNonisolated(context)
        case .keyUp, .flagsChanged:
            return handleKeyReleaseOrFlagsNonisolated(context)
        default:
            return .passThrough
        }
    }

    private nonisolated func handleMousePressNonisolated(_ context: EventTapContext) -> EventTapDisposition {
        eventState.lock.lock()
        let suppressBounce = eventState.clickDebounce.shouldSuppressPress(
            button: context.mouseButtonNumber,
            timestampNs: context.timestampNs
        )
        eventState.lock.unlock()
        if suppressBounce { return .suppress }

        if context.eventType == .leftMouseDown,
           !context.flags.contains(.maskAlternate),
           Thread.isMainThread {
            let greenEnabled = MainActor.assumeIsolated { self.settingsStore.settings.enableGreenButtonZoomMaximize }
            if greenEnabled,
               let hit = AXWindowHelper.elementAndParentWindow(atQuartzPoint: context.location),
               hit.subrole == (kAXZoomButtonSubrole as String) {
                let winElement = hit.window
                let clickPoint = context.location
                Task { @MainActor [weak self] in
                    self?.toggleZoomDesktopMaximize(windowElement: winElement, quartzPoint: clickPoint)
                }
                return .suppress
            }
        }
        return .passThrough
    }

    private nonisolated func handleScrollWheelNonisolated(_ context: EventTapContext) -> EventTapDisposition {
        guard !context.scrollIsContinuous, let cgEvent = context.cgEvent else { return .passThrough }
        var reverseOnly = false
        var smoothScroll = false
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                reverseOnly = self.settingsStore.settings.reverseMouseScrollOnly
                smoothScroll = self.settingsStore.settings.enableSmoothMouseScroll
            }
        }
        guard reverseOnly || smoothScroll, let cloned = cgEvent.copy() else { return .passThrough }

        var lineDelta = cloned.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        var pointDelta = cloned.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
        var fixedDelta = cloned.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
        if pointDelta == 0 && lineDelta != 0 { pointDelta = lineDelta * 12 }

        if reverseOnly {
            lineDelta = -lineDelta
            pointDelta = -pointDelta
            fixedDelta = -fixedDelta
        }
        if smoothScroll {
            eventState.lock.lock()
            let blended = Double(pointDelta) * 0.72 + eventState.smoothedScrollResidue * 0.28
            eventState.smoothedScrollResidue = blended
            eventState.lock.unlock()
            pointDelta = Int64(blended.rounded())
        }

        cloned.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: lineDelta)
        cloned.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: pointDelta)
        cloned.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: fixedDelta)
        return .replace(cloned)
    }

    private nonisolated func handleKeyDownNonisolated(_ context: EventTapContext) -> EventTapDisposition {
        eventState.lock.lock()
        let suppressChatter = eventState.keyDebounce.shouldSuppressKeyDown(
            keyCode: context.keyCode,
            isAutoRepeat: context.isAutoRepeat,
            timestampNs: context.timestampNs
        )
        eventState.lock.unlock()
        if suppressChatter { return .suppress }

        let frontApp = NSWorkspace.shared.frontmostApplication
        let frontBundleID = frontApp?.bundleIdentifier
        let frontName = frontApp?.localizedName ?? "当前应用"

        var holdQEnabled = false
        var finderCutEnabled = false
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                holdQEnabled = self.settingsStore.settings.enableHoldCommandQ
                finderCutEnabled = self.settingsStore.settings.enableFinderCutPaste
            }
        }

        let relevantMods = context.flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift])
        if holdQEnabled && context.keyCode == 12 && relevantMods == .maskCommand {
            let nowUptime = ProcessInfo.processInfo.systemUptime
            eventState.lock.lock()
            let decision = eventState.holdCmdQ.handleKeyDown(bundleID: frontBundleID, timestamp: nowUptime)
            eventState.lock.unlock()

            switch decision {
            case .allowQuit:
                Task { @MainActor [weak self] in self?.completeHoldQuit(targetApp: frontApp) }
                return .passThrough
            case .interceptHolding(let progress):
                Task { @MainActor [weak self] in
                    self?.presentAndMonitorHoldCommandQ(targetApp: frontApp, appName: frontName, initialProgress: progress)
                }
                return .suppress
            case .cancelled:
                return .suppress
            }
        }

        if finderCutEnabled && frontBundleID == "com.apple.finder" {
            eventState.lock.lock()
            let action = eventState.finderCutTracker.handleFinderCommandKey(keyCode: context.keyCode, flags: context.flags)
            eventState.lock.unlock()

            switch action {
            case .none:
                break
            case .synthesizeCopyAndArmCut:
                if let copyEvent = context.cgEvent?.copy() {
                    copyEvent.setIntegerValueField(.keyboardEventKeycode, value: 8)
                    copyEvent.flags = .maskCommand
                    Task { @MainActor [weak self] in self?.presentFinderCutArmedHUD() }
                    return .replace(copyEvent)
                }
            case .convertPasteToMove:
                if let moveEvent = context.cgEvent?.copy() {
                    moveEvent.flags = [.maskCommand, .maskAlternate]
                    return .replace(moveEvent)
                }
            }
        }
        return .passThrough
    }

    private nonisolated func handleKeyReleaseOrFlagsNonisolated(_ context: EventTapContext) -> EventTapDisposition {
        let releasedQ = (context.eventType == .keyUp && context.keyCode == 12)
        let releasedCommand = (context.eventType == .flagsChanged && !context.flags.contains(.maskCommand))
        guard releasedQ || releasedCommand else { return .passThrough }

        eventState.lock.lock()
        let wasHolding = eventState.holdCmdQ.isHolding
        if wasHolding { eventState.holdCmdQ.handleKeyRelease() }
        eventState.lock.unlock()

        if wasHolding {
            Task { @MainActor [weak self] in self?.cancelHoldCommandQHUD() }
        }
        return .passThrough
    }

    // MARK: - 主线程灵动岛 HUD 联动与窗口最大化

    private func presentAndMonitorHoldCommandQ(targetApp: NSRunningApplication?, appName: String, initialProgress: Double) {
        submitHoldProgressHUD(appName: appName, progress: initialProgress)
        guard holdProgressTask == nil else { return }

        holdProgressTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 45_000_000)
                guard let self, !Task.isCancelled else { return }
                let now = ProcessInfo.processInfo.systemUptime
                let decision = self.eventState.evaluateHoldProgressSync(at: now)

                switch decision {
                case .interceptHolding(let p):
                    self.submitHoldProgressHUD(appName: appName, progress: p)
                case .allowQuit:
                    self.completeHoldQuit(targetApp: targetApp)
                    return
                case .cancelled:
                    self.cancelHoldCommandQHUD()
                    return
                }
            }
        }
    }

    private func submitHoldProgressHUD(appName: String, progress: Double) {
        let pct = Int((progress * 100).rounded())
        stateMachine.submit(
            IslandActivityItem(
                id: holdHUDActivityID,
                category: .systemHUD,
                title: "继续按住 ⌘Q 退出「\(appName)」",
                subtitle: "防误触保护生效中",
                iconSymbol: "power.circle.fill",
                trailingBadge: "\(pct)%",
                progress: progress,
                priority: .interactive,
                isAlertHUD: true,
                autoDismissAfter: 1.5
            )
        )
    }

    private func completeHoldQuit(targetApp: NSRunningApplication?) {
        holdProgressTask?.cancel()
        holdProgressTask = nil
        eventState.lock.lock()
        eventState.holdCmdQ.reset()
        eventState.lock.unlock()
        stateMachine.dismiss(id: holdHUDActivityID)
        targetApp?.terminate()
    }

    private func cancelHoldCommandQHUD() {
        holdProgressTask?.cancel()
        holdProgressTask = nil
        stateMachine.dismiss(id: holdHUDActivityID)
    }

    private func presentFinderCutArmedHUD() {
        stateMachine.submit(IslandActivityItem(
            id: finderCutHUDActivityID, category: .systemHUD, title: "Finder 已标记剪切",
            subtitle: "前往目标目录按 ⌘V 即可移动文件", iconSymbol: "scissors",
            priority: .interactive, isAlertHUD: true, autoDismissAfter: 2.0
        ))
    }

    private func toggleZoomDesktopMaximize(windowElement: AXUIElement, quartzPoint: CGPoint) {
        let primaryHeight = AXWindowHelper.primaryScreenHeight()
        let appKitClick = AXWindowHelper.appKitPoint(fromQuartz: quartzPoint, primaryHeight: primaryHeight)
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(appKitClick) }) ?? NSScreen.main,
              let currentQuartz = AXWindowHelper.readQuartzFrame(of: windowElement) else { return }

        let currentAppKit = AXWindowHelper.appKitRect(fromQuartz: currentQuartz, primaryHeight: primaryHeight)
        let visible = screen.visibleFrame
        let key = "\(Unmanaged.passUnretained(windowElement).toOpaque())"
        let isMaximized = abs(currentAppKit.width - visible.width) < 16 && abs(currentAppKit.height - visible.height) < 16

        if isMaximized, let restored = savedZoomPreMaximizeFrames.removeValue(forKey: key) {
            _ = AXWindowHelper.setAppKitFrame(restored, for: windowElement, primaryHeight: primaryHeight)
        } else {
            savedZoomPreMaximizeFrames[key] = currentAppKit
            _ = AXWindowHelper.setAppKitFrame(visible, for: windowElement, primaryHeight: primaryHeight)
        }
    }

    private func handleFocusFollowsMouse(quartzLocation: CGPoint) {
        guard settingsStore.settings.enableFocusFollowsMouse else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastFocusFollowCheck >= 0.14 else { return }
        lastFocusFollowCheck = now

        guard let targetWin = windowRegistry.topWindow(atQuartzPoint: quartzLocation),
              let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              targetWin.ownerPID != frontPID,
              let targetApp = NSRunningApplication(processIdentifier: targetWin.ownerPID) else { return }
        _ = targetApp.activate()
    }
}
