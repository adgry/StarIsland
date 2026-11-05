import AIConnectKit
import AppKit
import HardwareCleanKit
import IslandCore
import LiveWidgetsKit
import MediaAudioKit
import ProductivityKit
import ServiceManagement
import SwiftUI
import SystemEnhanceKit
import UniformTypeIdentifiers

public struct UnifiedSettingsWindowView: View {
    @ObservedObject private var settingsStore: SettingsStore
    @ObservedObject private var permissionsCenter: PermissionsCenter
    @ObservedObject private var updater: SelfUpdater
    @ObservedObject private var stateMachine: IslandStateMachine

    @Binding private var selectedSection: SettingSection
    @State private var searchQuery: String = ""
    @State private var configBannerMessage: String?

    private let onReopenOnboarding: () -> Void

    @MainActor
    public init(
        selectedSection: Binding<SettingSection>,
        settingsStore: SettingsStore? = nil,
        permissionsCenter: PermissionsCenter? = nil,
        updater: SelfUpdater? = nil,
        stateMachine: IslandStateMachine? = nil,
        onReopenOnboarding: @escaping () -> Void
    ) {
        self._selectedSection = selectedSection
        self._settingsStore = ObservedObject(wrappedValue: settingsStore ?? .shared)
        self._permissionsCenter = ObservedObject(wrappedValue: permissionsCenter ?? .shared)
        self._updater = ObservedObject(wrappedValue: updater ?? .shared)
        self._stateMachine = ObservedObject(wrappedValue: stateMachine ?? .shared)
        self.onReopenOnboarding = onReopenOnboarding
    }

    public var body: some View {
        NavigationSplitView {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("搜索设置项（如：验证码、80%、歌词）", text: $searchQuery)
                        .textFieldStyle(.plain)
                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 12)
                .padding(.top, 10)

                if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    searchResultsSidebar
                } else {
                    List(SettingSection.allCases, selection: $selectedSection) { section in
                        Label(section.title, systemImage: section.iconSymbol)
                            .tag(section)
                    }
                    .listStyle(.sidebar)
                }
            }
            .navigationSplitViewColumnWidth(min: 215, ideal: 230, max: 260)
        } detail: {
            VStack(spacing: 0) {
                detailHeader
                Divider()
                detailPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 900, minHeight: 620)
        .onAppear {
            permissionsCenter.refreshAll()
        }
    }

    private var searchResultsSidebar: some View {
        let matches = settingsStore.search(searchQuery)
        return ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                if matches.isEmpty {
                    Text("未找到匹配的中文设置项")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(14)
                } else {
                    ForEach(matches) { item in
                        Button {
                            selectedSection = item.section
                            searchQuery = ""
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Image(systemName: item.section.iconSymbol)
                                        .foregroundStyle(.cyan)
                                    Text(item.title)
                                        .font(.system(size: 12.5, weight: .semibold))
                                }
                                Text(item.detail)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 12)
        }
    }

    private var detailHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: selectedSection.iconSymbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.cyan)
            Text(selectedSection.title)
                .font(.system(size: 17, weight: .bold))
            Spacer()
            Text("全部功能免费解锁 · 零商业门控")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var detailPane: some View {
        switch selectedSection {
        case .general:
            generalPane
        case .island:
            islandAppearancePane
        case .media:
            MediaSettingsPaneView()
        case .productivity:
            ProductivitySettingsPaneView()
        case .systemEnhance:
            SystemEnhanceSettingsPaneView()
        case .hardware:
            HardwareCleanSettingsPaneView()
        case .widgets:
            LiveWidgetsSettingsPaneView()
        case .aiConnect:
            AIConnectSettingsPaneView()
        case .permissions:
            permissionsPane
        case .about:
            aboutAndUpdatePane
        }
    }

    private var generalPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                GroupBox("启动与状态栏") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("登录 macOS 时自动启动星岛", isOn: $settingsStore.settings.launchAtLogin)
                            .onChange(of: settingsStore.settings.launchAtLogin) { _, enabled in
                                applyLaunchAtLogin(enabled)
                            }
                        Toggle("在系统右上角菜单栏显示「星岛」快捷图标", isOn: $settingsStore.settings.showMenuBarIcon)
                        Toggle("启动时自动静默检查 GitHub 新版本", isOn: $settingsStore.settings.autoCheckUpdates)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("配置备份、迁移与引导") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Button("导出配置文件 (.json)") {
                                exportSettingsFile()
                            }
                            Button("导入配置文件 (.json)") {
                                importSettingsFile()
                            }
                            Button("重新打开首次启动引导") {
                                onReopenOnboarding()
                            }
                            Spacer()
                            Button("恢复出厂默认设置", role: .destructive) {
                                settingsStore.resetToDefaults()
                                configBannerMessage = "已恢复全部默认设置"
                            }
                        }
                        if let msg = configBannerMessage {
                            Text(msg)
                                .font(.system(size: 12))
                                .foregroundStyle(.cyan)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(20)
        }
    }

    private var islandAppearancePane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                GroupBox("灵动岛几何尺寸与交互手感") {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("灵动岛整体缩放比例")
                            Spacer()
                            Text(String(format: "%.0f%%", settingsStore.settings.islandScale * 100))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $settingsStore.settings.islandScale, in: 0.80...1.35, step: 0.05)

                        HStack {
                            Text("鼠标悬停展开延迟")
                            Spacer()
                            Text("\(settingsStore.settings.hoverExpandDelayMs) 毫秒")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(settingsStore.settings.hoverExpandDelayMs) },
                                set: { settingsStore.settings.hoverExpandDelayMs = Int($0.rounded()) }
                            ),
                            in: 60...450,
                            step: 10
                        )
                    }
                    .padding(10)
                }

                GroupBox("多显示器与锁屏安全视图") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("在外接显示器顶部同步显示悬浮灵动胶囊", isOn: $settingsStore.settings.showOnExternalDisplays)
                        Toggle("在锁屏界面展示灵动岛（自动隐藏剪贴板与受锁应用隐私信息）", isOn: $settingsStore.settings.showOnLockScreen)
                        HStack {
                            Button("立即在屏幕顶部展开预览灵动岛") {
                                stateMachine.selectTab(.nowPlaying)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.cyan)
                            Button("收起灵动岛") {
                                stateMachine.collapseExpanded()
                            }
                        }
                        .padding(.top, 4)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(20)
        }
    }

    private var permissionsPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("按需授予系统权限可解锁更深度的自动化与视觉体验。本地网络支持一键重新探测触发系统弹窗。")
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("全部刷新") {
                        permissionsCenter.refreshAll()
                    }
                }

                ForEach(PermissionKind.allCases) { kind in
                    let state = permissionsCenter.status(for: kind)
                    GroupBox {
                        HStack(spacing: 14) {
                            Image(systemName: kind.iconSymbol)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.cyan)
                                .frame(width: 32, height: 32)
                                .background(Color.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(kind.title)
                                    .font(.system(size: 13.5, weight: .semibold))
                                Text(kind.summary)
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            permissionStatusLabel(for: kind, state: state)

                            if kind == .localNetwork {
                                Button(permissionsCenter.isProbingLocalNetwork ? "正在探测..." : "重新检测") {
                                    permissionsCenter.retryLocalNetworkProbe()
                                }
                                .disabled(permissionsCenter.isProbingLocalNetwork)
                                .controlSize(.small)
                            }

                            if state != .granted {
                                Button("授权") {
                                    permissionsCenter.request(kind)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.cyan)
                                .controlSize(.small)
                            }

                            Button("去设置") {
                                permissionsCenter.openSystemSettings(for: kind)
                            }
                            .controlSize(.small)
                        }
                        .padding(6)
                    }
                }
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private func permissionStatusLabel(for kind: PermissionKind, state: PermissionGrantState) -> some View {
        switch state {
        case .granted:
            Label("已就绪", systemImage: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.green)
        case .denied:
            Label("已拒绝", systemImage: "xmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.red)
        case .notDetermined:
            Label("待授权", systemImage: "circle.dotted")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.orange)
        }
    }

    private var aboutAndUpdatePane: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.cyan)
                        .padding(.top, 8)
                    Text("星岛 StarIsland")
                        .font(.system(size: 22, weight: .bold))
                    Text("当前版本：v\(updater.currentVersion.description)（Apple Silicon 原生构建）")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                GroupBox("软件内自动更新（GitHub 源：\(SelfUpdater.repositorySlug)）") {
                    VStack(alignment: .leading, spacing: 12) {
                        updateStatusContent

                        HStack(spacing: 12) {
                            Button("立即检查更新") {
                                Task { await updater.checkForUpdates() }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.cyan)

                            Button("访问 GitHub 仓库 (\(SelfUpdater.repositorySlug))") {
                                NSWorkspace.shared.open(SelfUpdater.repositoryWebURL)
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(24)
        }
    }

    @ViewBuilder
    private var updateStatusContent: some View {
        switch updater.state {
        case .idle:
            Text("点击下方按钮可连接 GitHub 检查是否有新版本发布。")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
        case .checking:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("正在连接 GitHub 检查最新版本...")
                    .font(.system(size: 12.5))
            }
        case .upToDate(let ver):
            Label("当前已是最新版本（v\(ver.description)）", systemImage: "checkmark.seal.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.green)
        case .updateAvailable(let release):
            VStack(alignment: .leading, spacing: 8) {
                Label("发现新版本：\(release.title) (\(release.tagName))", systemImage: "arrow.down.circle.fill")
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(.cyan)
                if !release.notes.isEmpty {
                    Text(release.notes)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(6)
                }
                Button("一键下载安装并自动重启") {
                    Task { await updater.downloadAndInstall(release) }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        case .downloading:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("正在下载新版本安装包 StarIsland-arm64.zip...")
                    .font(.system(size: 12.5))
            }
        case .installing:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("正在校验签名、替换应用并准备重启...")
                    .font(.system(size: 12.5))
            }
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 12.5))
                .foregroundStyle(.orange)
        }
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        if enabled {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
    }

    private func exportSettingsFile() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "StarIsland-Settings.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try settingsStore.exportJSON()
            try data.write(to: url, options: .atomic)
            configBannerMessage = "配置已导出至 \(url.lastPathComponent)"
        } catch {
            configBannerMessage = "导出失败：\(error.localizedDescription)"
        }
    }

    private func importSettingsFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            try settingsStore.importJSON(data)
            configBannerMessage = "配置导入成功并已立即生效"
        } catch {
            configBannerMessage = "导入失败：\(error.localizedDescription)"
        }
    }
}
