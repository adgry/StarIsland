import AIConnectKit
import AppKit
import ApplicationServices
import Combine
import Darwin
import HardwareCleanKit
import IslandCore
import LiveWidgetsKit
import MediaAudioKit
import ProductivityKit
import ServiceManagement
import SQLite3
import SwiftUI
import SystemEnhanceKit

@MainActor
public final class AppCoordinator: NSObject, ObservableObject, NSApplicationDelegate {
    public static let shared = AppCoordinator()

    @Published public var selectedSettingsSection: SettingSection = .general

    private let settingsStore = SettingsStore.shared
    private let stateMachine = IslandStateMachine.shared
    private var islandWindowController: IslandWindowController?
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var statusItem: NSStatusItem?

    private var cancellables = Set<AnyCancellable>()
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?
    private var mediaKeyMonitor: Any?
    private var mediaEventTapID: UUID?
    private var widgetRefreshTimer: Timer?
    private var notificationPollTimer: Timer?
    private var lastNotificationCheckRefTime: Double = Date().timeIntervalSinceReferenceDate
    private var lastAppliedLaunchAtLogin: Bool?
    private var isTerminatingGracefully: Bool = false

    private override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        stateMachine.startObservingSystemLockNotifications()

        // 1. Wire cross-module protocol registry
        ServiceRegistry.shared.aiService = AIAssistantCoordinator.shared
        ServiceRegistry.shared.helperService = HelperCoordinator.shared
        ServiceRegistry.shared.onOpenSettingsSection = { [weak self] section in
            self?.openSettings(section: section)
        }

        // 2. Wire mobile remote media & system commands
        LANContinuityServer.shared.onMediaCommand = { command in
            switch command {
            case .playPause:
                NowPlayingService.shared.togglePlayPause()
            case .next:
                NowPlayingService.shared.nextTrack()
            case .previous:
                NowPlayingService.shared.previousTrack()
            case .volumeUp:
                _ = SystemHUDInterceptor.shared.handleMediaKey(keyType: 0, isKeyDown: true, applyHardwareStep: true)
            case .volumeDown:
                _ = SystemHUDInterceptor.shared.handleMediaKey(keyType: 1, isKeyDown: true, applyHardwareStep: true)
            case .lockScreen:
                Self.lockMacScreenImmediately()
            }
        }

        // 3. Start Dynamic Island multi-screen window host
        let windowHost = IslandWindowController(
            stateMachine: stateMachine,
            settingsStore: settingsStore
        ) { [weak self] in
            AnyView(
                StarIslandRootView(
                    stateMachine: self?.stateMachine ?? .shared,
                    settingsStore: self?.settingsStore ?? .shared,
                    onOpenSettings: { [weak self] in
                        self?.openSettings()
                    }
                )
            )
        }
        self.islandWindowController = windowHost
        windowHost.start()

        // 4. Reconcile crash-recovery journal & helper connection in background
        Task {
            await HelperCoordinator.shared.reconcileConnection()
            await BatteryFanManager.shared.recoverPendingMutationsIfNeeded()
            await FocusBlockerService.shared.recoverPendingMutationsIfNeeded()
        }

        // 5. Start feature subsystems & reactive settings binding
        bindSettingsAndSubsystems()
        installGlobalShortcutsAndMediaKeys()
        setupVolumeMountDMGWatcher()
        startPeriodicWidgetAndNotificationLoops()

        // 6. Auto-check GitHub updates if enabled
        if settingsStore.settings.autoCheckUpdates {
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await SelfUpdater.shared.checkForUpdates()
            }
        }

        // 7. Show non-blocking welcome guide on very first launch
        if !settingsStore.settings.hasCompletedOnboarding {
            openOnboarding()
        }
    }

    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !isTerminatingGracefully else { return .terminateLater }
        isTerminatingGracefully = true

        widgetRefreshTimer?.invalidate()
        notificationPollTimer?.invalidate()
        if let tapID = mediaEventTapID {
            EventTapBus.shared.unregister(tapID)
            mediaEventTapID = nil
        }
        islandWindowController?.stop()
        NowPlayingService.shared.stopMonitoring()
        SystemHUDInterceptor.shared.stopObserving()
        ClipboardManager.shared.stopMonitoring()
        DropzoneShelfManager.shared.stopGlobalDragMonitor()
        SystemEnhanceCoordinator.shared.stop()
        BatteryFanManager.shared.stopMonitoring()
        TerminalActivityService.shared.stopListening()
        LANContinuityServer.shared.stop()

        var didReply = false
        let finishTermination: @MainActor () -> Void = {
            guard !didReply else { return }
            didReply = true
            sender.reply(toApplicationShouldTerminate: true)
        }

        // 2 秒兜底超时确保任何情况下都不会卡死退出流程
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            finishTermination()
        }

        Task { @MainActor in
            await BatteryFanManager.shared.restoreSystemDefaultsOnTermination()
            await FocusBlockerService.shared.stopFocus()
            HelperCoordinator.shared.disconnectXPC()
            finishTermination()
        }

        return .terminateLater
    }

    // MARK: - Subsystem Orchestration

    private func bindSettingsAndSubsystems() {
        settingsStore.$settings
            .receive(on: RunLoop.main)
            .sink { [weak self] s in
                self?.reconcileSubsystems(with: s)
            }
            .store(in: &cancellables)

        SystemEnhanceCoordinator.shared.start()
        reconcileSubsystems(with: settingsStore.settings)
    }

    private func reconcileSubsystems(with s: StarIslandSettings) {
        updateStatusBarVisibility(s.showMenuBarIcon)
        syncLaunchAtLoginIfNeeded(s.launchAtLogin)

        if s.enableNowPlaying {
            NowPlayingService.shared.startMonitoring()
        } else {
            NowPlayingService.shared.stopMonitoring()
        }

        if s.enableCustomVolumeHUD || s.enableCustomBrightnessHUD {
            SystemHUDInterceptor.shared.startObserving()
            registerMediaKeyEventTapIfNeeded()
        } else {
            SystemHUDInterceptor.shared.stopObserving()
            if let tapID = mediaEventTapID {
                EventTapBus.shared.unregister(tapID)
                mediaEventTapID = nil
            }
        }

        SpatialAudioProcessor.shared.rotationHz = s.eightDRotationHz
        if s.enableEightDAudio {
            SpatialAudioProcessor.shared.setMode(.eightD, startHardwareEngine: false)
        } else if s.enableSurroundAudio {
            SpatialAudioProcessor.shared.setMode(.surround, startHardwareEngine: false)
        } else {
            SpatialAudioProcessor.shared.setMode(.off, startHardwareEngine: false)
        }

        if s.enableClipboardHistory {
            ClipboardManager.shared.startMonitoring()
        } else {
            ClipboardManager.shared.stopMonitoring()
        }

        if s.enableDropzoneShelf {
            DropzoneShelfManager.shared.startGlobalDragMonitor()
        } else {
            DropzoneShelfManager.shared.stopGlobalDragMonitor()
        }

        if s.enableBatteryChargeLimit || s.enableThermalChargeProtection || s.fanControlMode != "auto" {
            BatteryFanManager.shared.startMonitoring()
        } else {
            BatteryFanManager.shared.stopMonitoring()
        }

        TimersEyeBreakManager.shared.startEyeBreakMonitorIfNeeded()

        if s.enableTerminalLiveActivity {
            TerminalActivityService.shared.startListening()
        } else {
            TerminalActivityService.shared.stopListening()
        }

        if s.enableLANContinuityServer {
            if !LANContinuityServer.shared.isRunning {
                LANContinuityServer.shared.start()
            }
        } else {
            LANContinuityServer.shared.stop()
        }
    }

    // MARK: - Menu Bar Status Item

    private func updateStatusBarVisibility(_ visible: Bool) {
        if visible {
            guard statusItem == nil else { return }
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            if let button = item.button {
                button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "星岛")
                button.title = " 星岛"
                button.imagePosition = .imageLeading
            }
            let menu = NSMenu()
            menu.addItem(withTitle: "展开星岛工作台", action: #selector(menuExpandIsland), keyEquivalent: "")
            menu.addItem(.separator())
            menu.addItem(withTitle: "剪贴板历史选择器 (⌥⌘V)", action: #selector(menuOpenClipboard), keyEquivalent: "")
            menu.addItem(withTitle: "离线框选文字识别 OCR (⇧⌘2)", action: #selector(menuTriggerOCR), keyEquivalent: "")
            menu.addItem(withTitle: "圈选屏幕 AI 识图搜索 (⇧⌘S)", action: #selector(menuTriggerCircleSearch), keyEquivalent: "")
            menu.addItem(.separator())
            menu.addItem(withTitle: "星岛设置中心...", action: #selector(menuOpenSettings), keyEquivalent: ",")
            menu.addItem(withTitle: "检查 GitHub 更新...", action: #selector(menuCheckUpdates), keyEquivalent: "")
            menu.addItem(.separator())
            menu.addItem(withTitle: "退出星岛", action: #selector(menuQuitApp), keyEquivalent: "q")
            for menuItem in menu.items {
                menuItem.target = self
            }
            item.menu = menu
            statusItem = item
        } else if let existing = statusItem {
            NSStatusBar.system.removeStatusItem(existing)
            statusItem = nil
        }
    }

    @objc private func menuExpandIsland() {
        stateMachine.selectTab(.nowPlaying)
    }

    @objc private func menuOpenClipboard() {
        ClipboardManager.shared.presentPicker()
    }

    @objc private func menuTriggerOCR() {
        CircleToSearchController.shared.beginSelection(
            aiService: ServiceRegistry.shared.aiService,
            mode: .ocrOnly
        )
    }

    @objc private func menuTriggerCircleSearch() {
        CircleToSearchController.shared.beginSelection(
            aiService: ServiceRegistry.shared.aiService,
            mode: .circleToSearch
        )
    }

    @objc private func menuOpenSettings() {
        openSettings()
    }

    @objc private func menuCheckUpdates() {
        openSettings(section: .about)
        Task { await SelfUpdater.shared.checkForUpdates() }
    }

    @objc private func menuQuitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Windows (Settings & Onboarding)

    public func openSettings(section: SettingSection? = nil) {
        if let section {
            selectedSettingsSection = section
        }

        if let existing = settingsWindow {
            NSApp.activate(ignoringOtherApps: true)
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let sectionBinding = Binding<SettingSection>(
            get: { [weak self] in self?.selectedSettingsSection ?? .general },
            set: { [weak self] newVal in self?.selectedSettingsSection = newVal }
        )

        let rootView = UnifiedSettingsWindowView(
            selectedSection: sectionBinding,
            settingsStore: settingsStore,
            stateMachine: stateMachine,
            onReopenOnboarding: { [weak self] in
                self?.openOnboarding()
            }
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 940, height: 650),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "星岛设置中心"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: rootView)
        settingsWindow = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    public func openOnboarding() {
        if let existing = onboardingWindow {
            NSApp.activate(ignoringOtherApps: true)
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let view = OnboardingWindowView(settingsStore: settingsStore) { [weak self] in
            self?.onboardingWindow?.close()
            self?.onboardingWindow = nil
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 520),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "欢迎使用星岛 StarIsland"
        window.titlebarAppearsTransparent = true
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: view)
        onboardingWindow = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - Global Hotkeys & Media Keys

    private func installGlobalShortcutsAndMediaKeys() {
        let handler: (NSEvent) -> Bool = { [weak self] event in
            guard let self else { return false }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            // ⌥⌘V -> Clipboard Picker
            if flags == [.command, .option], event.keyCode == 9 {
                Task { @MainActor in ClipboardManager.shared.presentPicker() }
                return true
            }
            // ⇧⌘2 -> Offline Vision OCR
            if flags == [.command, .shift], event.keyCode == 19 {
                Task { @MainActor in
                    CircleToSearchController.shared.beginSelection(
                        aiService: ServiceRegistry.shared.aiService,
                        mode: .ocrOnly
                    )
                }
                return true
            }
            // ⇧⌘S -> Circle to Search
            if flags == [.command, .shift], event.keyCode == 1 {
                Task { @MainActor in
                    CircleToSearchController.shared.beginSelection(
                        aiService: ServiceRegistry.shared.aiService,
                        mode: .circleToSearch
                    )
                }
                return true
            }
            _ = self
            return false
        }

        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            _ = handler(event)
        }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handler(event) ? nil : event
        }

        mediaKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .systemDefined) { [weak self] event in
            guard let self, event.subtype.rawValue == 8 else { return }
            // 当辅助功能 EventTap 已激活时，由 EventTap 拦截原生 OSD 并完成硬件步进，避免重复触发
            guard !EventTapBus.shared.isTapInstalled else { return }
            let data1 = event.data1
            let keyType = Int32((data1 & 0xFFFF0000) >> 16)
            let keyState = ((data1 & 0x0000FF00) >> 8)
            let isKeyDown = (keyState == 0x0A)
            guard isKeyDown else { return }
            let fine = event.modifierFlags.contains([.option, .shift])
            Task { @MainActor in
                let s = self.settingsStore.settings
                guard s.enableCustomVolumeHUD || s.enableCustomBrightnessHUD else { return }
                _ = SystemHUDInterceptor.shared.handleMediaKey(
                    keyType: keyType,
                    isKeyDown: true,
                    fineStep: fine,
                    applyHardwareStep: false
                )
            }
        }
    }

    private func registerMediaKeyEventTapIfNeeded() {
        guard mediaEventTapID == nil,
              let sysDefinedType = CGEventType(rawValue: 14) else {
            return
        }
        let entry = EventTapEntry(
            name: "MediaHUDInterceptor",
            priority: 120,
            eventMask: EventTapEntry.mask(for: [sysDefinedType])
        ) { [weak self] context in
            guard let self,
                  let cgEvent = context.cgEvent,
                  let nsEvent = NSEvent(cgEvent: cgEvent),
                  nsEvent.subtype.rawValue == 8 else {
                return .passThrough
            }
            let data1 = nsEvent.data1
            let keyType = Int32((data1 & 0xFFFF0000) >> 16)
            let keyState = ((data1 & 0x0000FF00) >> 8)
            let isKeyDown = (keyState == 0x0A)
            let isKeyUp = (keyState == 0x0B)
            guard isKeyDown || isKeyUp else { return .passThrough }

            let fine = nsEvent.modifierFlags.contains([.option, .shift])
            var shouldSuppress = false
            if Thread.isMainThread {
                MainActor.assumeIsolated {
                    let s = self.settingsStore.settings
                    let isVolKey = (keyType == 0 || keyType == 1 || keyType == 7)
                    let isBrightKey = (keyType == 2 || keyType == 3 || keyType == 21 || keyType == 22)
                    if (isVolKey && s.enableCustomVolumeHUD) || (isBrightKey && s.enableCustomBrightnessHUD) {
                        shouldSuppress = true
                        if isKeyDown {
                            _ = SystemHUDInterceptor.shared.handleMediaKey(
                                keyType: keyType,
                                isKeyDown: true,
                                fineStep: fine,
                                applyHardwareStep: true
                            )
                        }
                    }
                }
            }
            return shouldSuppress ? .suppress : .passThrough
        }
        mediaEventTapID = EventTapBus.shared.register(entry)
    }

    private func syncLaunchAtLoginIfNeeded(_ enabled: Bool) {
        guard lastAppliedLaunchAtLogin != enabled else { return }
        lastAppliedLaunchAtLogin = enabled
        guard Bundle.main.bundleURL.pathExtension.lowercased() == "app" else { return }
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            // 非 /Applications 临时运行目录或用户手动在系统设置变更时静默忽略
        }
    }

    private nonisolated static func lockMacScreenImmediately() {
        if let handle = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_LAZY),
           let sym = dlsym(handle, "SACLockScreenImmediate") {
            typealias LockFn = @convention(c) () -> Void
            let fn = unsafeBitCast(sym, to: LockFn.self)
            fn()
            return
        }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        proc.arguments = ["displaysleepnow"]
        try? proc.run()
    }

    // MARK: - Periodic Widget Refresh & Safe Fresh-Only Notification OTP Tailer

    private func startPeriodicWidgetAndNotificationLoops() {
        Task {
            await refreshEnabledWidgets()
        }

        widgetRefreshTimer = Timer.scheduledTimer(withTimeInterval: 180, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshEnabledWidgets()
            }
        }

        notificationPollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollFreshSystemNotificationsIfPermitted()
            }
        }
    }

    private func refreshEnabledWidgets() async {
        let s = settingsStore.settings
        if s.enableWeatherWidget {
            await WeatherService.shared.refresh()
        }
        if s.enableSportsLiveActivity {
            await SportsLiveService.shared.refresh()
        }
        if s.enableFinanceWidget {
            await FinanceLiveService.shared.refresh()
        }
        if s.enableCalendarWidget || s.enableRemindersWidget || s.enableBluetoothBatteryWidget {
            await CalendarBluetoothService.shared.refreshAll()
        }
    }

    private func pollFreshSystemNotificationsIfPermitted() {
        let s = settingsStore.settings
        guard s.enableSmartOTP || s.enableParcelTracking else { return }

        let dbPath = (NSHomeDirectory() as NSString)
            .appendingPathComponent("Library/Group Containers/group.com.apple.usernoted/db2/db")
        guard FileManager.default.isReadableFile(atPath: dbPath) else { return }

        let sinceRef = lastNotificationCheckRefTime
        let queryStartedRef = Date().timeIntervalSinceReferenceDate

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK,
              let db else {
            return
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 150)

        let sql = """
        SELECT app.identifier, rec.data, rec.delivered_date
        FROM record rec
        LEFT JOIN app ON rec.app_id = app.app_id
        WHERE rec.delivered_date > ?
        ORDER BY rec.delivered_date ASC
        LIMIT 15;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_double(stmt, 1, sinceRef)

        var maxDeliveredDate = sinceRef
        var stepCode = sqlite3_step(stmt)
        while stepCode == SQLITE_ROW {
            let delivered = sqlite3_column_double(stmt, 2)
            if delivered > maxDeliveredDate {
                maxDeliveredDate = delivered
            }
            let appID = sqlite3_column_text(stmt, 0).map { String(cString: $0) } ?? "unknown"
            if let blobPtr = sqlite3_column_blob(stmt, 1) {
                let blobLen = Int(sqlite3_column_bytes(stmt, 1))
                if blobLen > 0 {
                    let plistData = Data(bytes: blobPtr, count: blobLen)
                    if let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
                       let req = plist["req"] as? [String: Any] {
                        let title = (req["titl"] as? String) ?? ""
                        let subtitle = (req["subt"] as? String) ?? ""
                        let body = (req["body"] as? String) ?? ""
                        let combinedBody = subtitle.isEmpty ? body : "\(subtitle) \(body)"
                        if !title.isEmpty || !combinedBody.isEmpty {
                            _ = SmartInboxCoordinator.shared.ingestNotification(
                                appBundleID: appID,
                                title: title,
                                body: combinedBody
                            )
                        }
                    }
                }
            }
            stepCode = sqlite3_step(stmt)
        }

        if stepCode == SQLITE_DONE {
            lastNotificationCheckRefTime = max(maxDeliveredDate, queryStartedRef)
        }
    }

    // MARK: - Mounted DMG Auto-Install Prompt

    private func setupVolumeMountDMGWatcher() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didMountNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let volumeURL = (note.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL)
                ?? (note.userInfo?["NSDevicePath"] as? String).map { URL(fileURLWithPath: $0) }
            guard let volumeURL else {
                return
            }
            Task { @MainActor in
                guard let self, self.settingsStore.settings.enableDMGAutoInstallHelper else { return }
                let entries = (try? FileManager.default.contentsOfDirectory(at: volumeURL, includingPropertiesForKeys: nil)) ?? []
                if let appURL = entries.first(where: { $0.pathExtension.lowercased() == "app" }) {
                    self.stateMachine.submit(
                        IslandActivityItem(
                            id: "dmg-\(appURL.lastPathComponent)",
                            category: .shelf,
                            title: "检测到安装包：\(appURL.deletingPathExtension().lastPathComponent)",
                            subtitle: "可在「电池风扇与清理 → DMG 安装助手」一键安装",
                            iconSymbol: "opticaldiscdrive.fill",
                            priority: .interactive,
                            isPeek: true,
                            autoDismissAfter: 5.0
                        )
                    )
                }
            }
        }
    }
}
