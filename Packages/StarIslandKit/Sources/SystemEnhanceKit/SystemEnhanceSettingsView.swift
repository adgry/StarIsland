import AppKit
import Combine
import Foundation
import IslandCore
import SwiftUI
import UniformTypeIdentifiers

/// 系统增强模块总协调器：统一按用户设置开关动态启停各子模块，空闲时自动释放 EventTap 零开销
@MainActor
public final class SystemEnhanceCoordinator: ObservableObject {
    public static let shared = SystemEnhanceCoordinator()

    public let settingsStore: SettingsStore
    public let stateMachine: IslandStateMachine
    public let eventTapBus: EventTapBus
    public let windowRegistry: WindowRegistry
    public let windowSwitcher: WindowSwitcherPanelController
    public let windowSnapManager: WindowSnapManager
    public let dockPreviewController: DockPreviewController
    public let keyboardMouseController: KeyboardMouseEnhancersController
    public let emojiInputController: EmojiInputController
    public let appLockService: AppLockService

    @Published public private(set) var isRunning: Bool = false

    private var settingsCancellable: AnyCancellable?

    public init(
        settingsStore: SettingsStore? = nil,
        stateMachine: IslandStateMachine? = nil,
        mutationJournal: MutationJournal? = nil,
        eventTapBus: EventTapBus? = nil
    ) {
        let store = settingsStore ?? .shared
        let machine = stateMachine ?? .shared
        let journal = mutationJournal ?? .shared
        let bus = eventTapBus ?? .shared
        let registry = WindowRegistry.shared

        self.settingsStore = store
        self.stateMachine = machine
        self.eventTapBus = bus
        self.windowRegistry = registry

        let switcher = WindowSwitcherPanelController(windowRegistry: registry)
        self.windowSwitcher = switcher
        self.windowSnapManager = WindowSnapManager(settingsStore: store, eventTapBus: bus, windowRegistry: registry, switcherController: switcher)
        self.dockPreviewController = DockPreviewController(settingsStore: store, eventTapBus: bus, windowRegistry: registry)
        self.keyboardMouseController = KeyboardMouseEnhancersController(
            settingsStore: store, stateMachine: machine, eventTapBus: bus, windowRegistry: registry, mutationJournal: journal
        )
        self.emojiInputController = EmojiInputController(settingsStore: store, eventTapBus: bus)
        self.appLockService = AppLockService(settingsStore: store, stateMachine: machine, observeWorkspace: false)
    }

    public func start() {
        isRunning = true
        reconcileActiveSubsystems(with: settingsStore.settings)
        if settingsCancellable == nil {
            settingsCancellable = settingsStore.$settings.receive(on: RunLoop.main).sink { [weak self] updated in
                guard let self, self.isRunning else { return }
                self.reconcileActiveSubsystems(with: updated)
            }
        }
    }

    public func stop() {
        isRunning = false
        settingsCancellable?.cancel()
        settingsCancellable = nil
        windowSnapManager.stop()
        windowSwitcher.dismiss()
        dockPreviewController.stop()
        keyboardMouseController.stop()
        emojiInputController.stop()
        appLockService.stop()
    }

    private func reconcileActiveSubsystems(with s: StarIslandSettings) {
        (s.enableWindowSnap || s.enableWindowSwitcher) ? windowSnapManager.start() : windowSnapManager.stop()
        (s.enableDockHoverPreview || s.enableDockClickMinimize) ? dockPreviewController.start() : dockPreviewController.stop()

        let needsKeyMouseTap = s.enableHoldCommandQ || s.enableFinderCutPaste || s.enableGreenButtonZoomMaximize
            || s.enableSmoothMouseScroll || s.reverseMouseScrollOnly || s.enableFocusFollowsMouse
            || s.mouseClickDebounceMs > 0 || s.keyboardDebounceMs > 0
        needsKeyMouseTap ? keyboardMouseController.start() : keyboardMouseController.stop()
        s.enableEmojiShortcut ? emojiInputController.start() : emojiInputController.stop()
        s.enableAppLock ? appLockService.start() : appLockService.stop()
    }
}

/// 「窗口、Dock 与键鼠安全增强」完整简体中文设置面板
public struct SystemEnhanceSettingsPaneView: View {
    @ObservedObject private var settingsStore: SettingsStore
    @ObservedObject private var coordinator: SystemEnhanceCoordinator
    @ObservedObject private var permissionsCenter: PermissionsCenter
    @ObservedObject private var appLockService: AppLockService

    @State private var installedApps: [InstalledAppCandidate] = []
    @State private var appSearchText: String = ""
    @State private var emojiTestInput: String = ":火箭"
    @State private var dockBackupMessage: String?

    @MainActor
    public init(
        settingsStore: SettingsStore? = nil,
        coordinator: SystemEnhanceCoordinator? = nil,
        permissionsCenter: PermissionsCenter? = nil
    ) {
        let resolvedStore = settingsStore ?? .shared
        let resolvedCoord = coordinator ?? .shared
        let resolvedPerms = permissionsCenter ?? .shared
        self._settingsStore = ObservedObject(wrappedValue: resolvedStore)
        self._coordinator = ObservedObject(wrappedValue: resolvedCoord)
        self._permissionsCenter = ObservedObject(wrappedValue: resolvedPerms)
        self._appLockService = ObservedObject(wrappedValue: resolvedCoord.appLockService)
    }

    private var filteredApps: [InstalledAppCandidate] {
        let q = appSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return installedApps }
        return installedApps.filter {
            $0.displayName.lowercased().contains(q) || $0.bundleIdentifier.lowercased().contains(q)
        }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                permissionsBannerSection
                windowSnapSection
                dockEnhanceSection
                keyboardMouseSection
                emojiShortcutSection
                appLockSection
            }
            .padding(20)
        }
        .onAppear {
            permissionsCenter.refreshAll()
            if installedApps.isEmpty {
                installedApps = AppLockService.discoverInstalledApps()
            }
        }
    }

    // MARK: - 1. 权限引导横幅

    private var permissionsBannerSection: some View {
        GroupBox {
            HStack(spacing: 16) {
                permissionBadge(
                    title: "辅助功能权限",
                    granted: permissionsCenter.status(for: .accessibility) == .granted,
                    kind: .accessibility
                )
                Divider().frame(height: 32)
                permissionBadge(
                    title: "屏幕录制权限（窗口缩略图）",
                    granted: permissionsCenter.status(for: .screenRecording) == .granted,
                    kind: .screenRecording
                )
                Spacer()
                Button("刷新状态") {
                    permissionsCenter.refreshAll()
                    coordinator.eventTapBus.refreshTapBinding()
                }
                .controlSize(.small)
            }
            .padding(6)
        } label: {
            Label("权限与事件总线状态", systemImage: "hand.raised.shield.fill")
                .font(.headline)
        }
    }

    private func permissionBadge(title: String, granted: Bool, kind: PermissionKind) -> some View {
        HStack(spacing: 8) {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(granted ? .green : .orange)
            Text(title)
                .font(.subheadline)
            if !granted {
                Button("前往授权") {
                    permissionsCenter.request(kind)
                }
                .controlSize(.mini)
            } else {
                Text("已就绪")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 2. 窗口磁吸分屏与切换器

    private var windowSnapSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("拖拽窗口靠近屏幕左/右/上边缘或四角自动磁吸分屏（快捷键 ⌃⌥ + 方向键 / U I J K / D F G）", isOn: $settingsStore.settings.enableWindowSnap)
                Toggle("启用增强型桌面窗口切换浮层（快捷键 ⌃⌥Tab 查看实时窗口缩略图）", isOn: $settingsStore.settings.enableWindowSwitcher)

                HStack(spacing: 8) {
                    Text("快捷验证操作：")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach([SnapZone.leftHalf, .rightHalf, .topMaximize, .leftThird, .centerThird, .rightThird]) { zone in
                        Button {
                            _ = coordinator.windowSnapManager.snapFocusedWindow(to: zone)
                        } label: {
                            Label(zone.title, systemImage: zone.iconSymbol)
                        }
                        .controlSize(.small)
                    }
                    Spacer()
                    Button("打开窗口切换器") {
                        coordinator.windowSwitcher.present()
                    }
                    .controlSize(.small)
                }
            }
            .padding(8)
        } label: {
            Label("窗口磁吸分屏与切换器", systemImage: "macwindow.on.rectangle")
                .font(.headline)
        }
    }

    // MARK: - 3. Dock 悬停预览与布局导入导出

    private var dockEnhanceSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("鼠标悬停在 Dock 应用图标上时弹出毛玻璃实时窗口预览（支持点击切换与直接关窗）", isOn: $settingsStore.settings.enableDockHoverPreview)
                Toggle("点击当前已处于前台激活状态的 Dock 应用图标时一键隐藏/最小化窗口", isOn: $settingsStore.settings.enableDockClickMinimize)

                HStack(spacing: 12) {
                    Button {
                        exportDockLayoutAction()
                    } label: {
                        Label("导出 Dock 常用应用布局", systemImage: "square.and.arrow.up")
                    }
                    .controlSize(.small)

                    Button {
                        importDockLayoutAction()
                    } label: {
                        Label("导入恢复 Dock 布局", systemImage: "square.and.arrow.down")
                    }
                    .controlSize(.small)

                    if let msg = dockBackupMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(8)
        } label: {
            Label("Dock 实时预览与增强", systemImage: "dock.rectangle")
                .font(.headline)
        }
    }

    // MARK: - 4. 键盘与鼠标效率调校

    private var keyboardMouseSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("长按 ⌘Q 防误触退出应用（在灵动岛显示环形按住进度条）", isOn: $settingsStore.settings.enableHoldCommandQ)

                if settingsStore.settings.enableHoldCommandQ {
                    HStack {
                        Text("按住触发退出时长：\(String(format: "%.1f 秒", settingsStore.settings.holdCommandQDurationSeconds))")
                            .font(.subheadline)
                            .frame(width: 190, alignment: .leading)
                        Slider(value: $settingsStore.settings.holdCommandQDurationSeconds, in: 0.4...2.0, step: 0.1)
                    }
                }

                Toggle("Finder 内支持 ⌘X 剪切文件并在目标目录按 ⌘V 直接移动（自动合成 ⌥⌘V）", isOn: $settingsStore.settings.enableFinderCutPaste)
                Toggle("单击窗口左上角绿色按钮执行桌面填满真最大化（不新建独立全屏空间）", isOn: $settingsStore.settings.enableGreenButtonZoomMaximize)
                Toggle("外接物理鼠标滚轮平滑滚动插值", isOn: $settingsStore.settings.enableSmoothMouseScroll)
                Toggle("仅反转外接鼠标滚轮方向（保持触控板双指自然滚动不变）", isOn: $settingsStore.settings.reverseMouseScrollOnly)
                Toggle("窗口焦点自动跟随鼠标悬停切换", isOn: $settingsStore.settings.enableFocusFollowsMouse)

                Divider()

                HStack {
                    Text("鼠标微动防连击阈值：\(settingsStore.settings.mouseClickDebounceMs == 0 ? "关闭" : "\(settingsStore.settings.mouseClickDebounceMs) ms")")
                        .font(.subheadline)
                        .frame(width: 210, alignment: .leading)
                    Slider(
                        value: Binding(
                            get: { Double(settingsStore.settings.mouseClickDebounceMs) },
                            set: { settingsStore.settings.mouseClickDebounceMs = Int($0.rounded()) }
                        ),
                        in: 0...80,
                        step: 5
                    )
                }

                HStack {
                    Text("机械键盘按键消抖阈值：\(settingsStore.settings.keyboardDebounceMs == 0 ? "关闭" : "\(settingsStore.settings.keyboardDebounceMs) ms")")
                        .font(.subheadline)
                        .frame(width: 210, alignment: .leading)
                    Slider(
                        value: Binding(
                            get: { Double(settingsStore.settings.keyboardDebounceMs) },
                            set: { settingsStore.settings.keyboardDebounceMs = Int($0.rounded()) }
                        ),
                        in: 0...50,
                        step: 5
                    )
                }
            }
            .padding(8)
        } label: {
            Label("键盘与外接鼠标精细调校", systemImage: "keyboard.fill")
                .font(.headline)
        }
    }

    // MARK: - 5. Emoji 快捷输入联想

    private var emojiShortcutSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("启用全局 `:关键词` Emoji 快捷联想（支持中文如 `:火箭`、`:大笑` 与英文 `:rocket`）", isOn: $settingsStore.settings.enableEmojiShortcut)

                HStack(spacing: 10) {
                    TextField("输入例如 :火箭 或 :大笑 测试联想…", text: $emojiTestInput)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 220)

                    let preview = EmojiSuggestEngine.match(token: emojiTestInput, limit: 6)
                    if preview.isEmpty {
                        Text("无匹配候选")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(preview) { item in
                            Text("\(item.emoji) \(item.primaryName)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.14), in: Capsule())
                        }
                    }
                }
            }
            .padding(8)
        } label: {
            Label("Emoji 双语快捷联想", systemImage: "face.smiling.inverse")
                .font(.headline)
        }
    }

    // MARK: - 6. 生物识别应用锁

    private var appLockSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Toggle("启用 Touch ID 指纹与系统密码应用隐私锁", isOn: $settingsStore.settings.enableAppLock)
                    Spacer()
                    Button("立即重新锁定全部应用") {
                        appLockService.lockAllImmediately()
                    }
                    .controlSize(.small)
                    .disabled(settingsStore.settings.lockedAppBundleIDs.isEmpty)
                }

                HStack {
                    Text("应用切至后台后自动重新上锁时间：")
                        .font(.subheadline)
                    Picker("", selection: $settingsStore.settings.appLockRelockIntervalSeconds) {
                        Text("立即重锁（每次切换验证）").tag(5)
                        Text("30 秒").tag(30)
                        Text("1 分钟").tag(60)
                        Text("5 分钟").tag(300)
                        Text("15 分钟").tag(900)
                    }
                    .frame(width: 220)
                }

                HStack {
                    TextField("搜索已安装应用名称或 Bundle ID…", text: $appSearchText)
                        .textFieldStyle(.roundedBorder)
                    Button("手动选择应用…") {
                        chooseCustomAppToLock()
                    }
                    .controlSize(.small)
                }

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(filteredApps) { candidate in
                            let isLocked = settingsStore.settings.lockedAppBundleIDs.contains(candidate.bundleIdentifier)
                            HStack(spacing: 10) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: candidate.bundlePath))
                                    .resizable()
                                    .frame(width: 22, height: 22)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(candidate.displayName)
                                        .font(.system(size: 13, weight: .medium))
                                    Text(candidate.bundleIdentifier)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { isLocked },
                                    set: { shouldLock in
                                        var current = Set(settingsStore.settings.lockedAppBundleIDs)
                                        if shouldLock {
                                            current.insert(candidate.bundleIdentifier)
                                        } else {
                                            current.remove(candidate.bundleIdentifier)
                                        }
                                        settingsStore.settings.lockedAppBundleIDs = current.sorted()
                                    }
                                ))
                                .labelsHidden()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(isLocked ? Color.accentColor.opacity(0.10) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .frame(height: 190)
                .background(Color.black.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
            }
            .padding(8)
        } label: {
            Label("Touch ID 生物识别应用隐私锁（已保护 \(settingsStore.settings.lockedAppBundleIDs.count) 款应用）", systemImage: "lock.shield.fill")
                .font(.headline)
        }
    }

    // MARK: - 导入导出辅助方法

    private func exportDockLayoutAction() {
        let panel = NSSavePanel()
        panel.title = "导出 Dock 常用应用布局备份"
        panel.nameFieldStringValue = "星岛-Dock布局备份.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let targetURL = panel.url else { return }

        do {
            let data = try coordinator.dockPreviewController.exportDockLayout()
            try data.write(to: targetURL, options: .atomic)
            dockBackupMessage = "已成功导出至 \(targetURL.lastPathComponent)"
        } catch {
            dockBackupMessage = "导出失败：\(error.localizedDescription)"
        }
    }

    private func importDockLayoutAction() {
        let panel = NSOpenPanel()
        panel.title = "选择 Dock 布局备份 JSON 文件"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let sourceURL = panel.url else { return }

        do {
            let data = try Data(contentsOf: sourceURL)
            let backup = try coordinator.dockPreviewController.importDockLayout(data, restartDock: true)
            dockBackupMessage = "已恢复 \(backup.apps.count) 款应用并刷新 Dock"
        } catch {
            dockBackupMessage = "导入失败：\(error.localizedDescription)"
        }
    }

    private func chooseCustomAppToLock() {
        let panel = NSOpenPanel()
        panel.title = "选择需要启用隐私锁的应用程序"
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }

        var updated = Set(settingsStore.settings.lockedAppBundleIDs)
        for url in panel.urls {
            guard let bundle = Bundle(url: url),
                  let bid = bundle.bundleIdentifier,
                  bid != StarIslandHelperConstants.appBundleIdentifier else { continue }
            updated.insert(bid)
            if !installedApps.contains(where: { $0.bundleIdentifier == bid }) {
                let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
                installedApps.insert(InstalledAppCandidate(bundleIdentifier: bid, displayName: name, bundlePath: url.path), at: 0)
            }
        }
        settingsStore.settings.lockedAppBundleIDs = updated.sorted()
    }
}
