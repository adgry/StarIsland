import AppKit
import SwiftUI
import UniformTypeIdentifiers
import IslandCore

/// 硬件电池风扇管家、空间监控、DMG 一键安装与应用深度卸载综合设置页
public struct HardwareCleanSettingsPaneView: View {
    @ObservedObject private var settingsStore: SettingsStore
    @ObservedObject private var helperCoordinator: HelperCoordinator
    @ObservedObject private var batteryFanManager: BatteryFanManager
    @ObservedObject private var dmgInstaller: DMGAutoInstaller

    @State private var storageSnapshot: DiskAndMemorySnapshot = StorageAnalyzerService.currentSnapshot()
    @State private var installedApps: [InstalledAppInfo] = []
    @State private var selectedApp: InstalledAppInfo?
    @State private var residueItems: [AppResidueItem] = []
    @State private var includeAppBundleInTrash: Bool = true
    @State private var isScanningApps: Bool = false
    @State private var cleanSummaryBanner: String?
    @State private var isDropTargeted: Bool = false

    public init(
        settingsStore: SettingsStore? = nil,
        helperCoordinator: HelperCoordinator? = nil,
        batteryFanManager: BatteryFanManager? = nil,
        dmgInstaller: DMGAutoInstaller? = nil
    ) {
        self.settingsStore = settingsStore ?? .shared
        self.helperCoordinator = helperCoordinator ?? .shared
        self.batteryFanManager = batteryFanManager ?? .shared
        self.dmgInstaller = dmgInstaller ?? .shared
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                helperStatusSection
                batteryControlSection
                fanControlSection
                storageAndDMGSection
                appDeepCleanerSection
            }
            .padding(20)
        }
        .task {
            storageSnapshot = StorageAnalyzerService.currentSnapshot()
            await helperCoordinator.reconcileConnection()
            await batteryFanManager.evaluateAndApply()
        }
    }

    // MARK: - 1. 特权辅助服务状态横幅（握手中绝不闪红叉）

    private var helperStatusSection: some View {
        GroupBox {
            HStack(spacing: 12) {
                if helperCoordinator.isReconciling {
                    ProgressView().controlSize(.small)
                    statusLabels(
                        title: "正在同步星岛特权辅助服务状态…",
                        subtitle: "正在执行安全签名校验与 XPC 通道握手，请稍候"
                    )
                    Spacer()
                } else if helperCoordinator.isConnected {
                    Image(systemName: "checkmark.shield.fill").font(.title2).foregroundStyle(.green)
                    statusLabels(
                        title: "特权辅助服务已连通",
                        subtitle: "SMC 充电上限、温控停充与自定义风扇控制已就绪"
                    )
                    Spacer()
                    Button("重新校准") { Task { await helperCoordinator.reconcileConnection() } }
                } else if let issue = helperCoordinator.visibleIssue {
                    Image(systemName: "exclamationmark.triangle.fill").font(.title2).foregroundStyle(.orange)
                    statusLabels(title: "需要修复或授权特权辅助服务", subtitle: issue)
                    Spacer()
                    if helperCoordinator.status == .requiresApproval {
                        Button("打开登录项设置") { helperCoordinator.openSystemLoginItemsSettings() }
                    }
                    Button("重装修复") { Task { await helperCoordinator.reinstallHelper() } }
                        .buttonStyle(.borderedProminent)
                } else {
                    Image(systemName: "bolt.shield").font(.title2).foregroundStyle(.blue)
                    statusLabels(
                        title: "特权辅助服务（可选启用）",
                        subtitle: "启用后可解锁 Apple Silicon 底层充电上限锁定与风扇转速控制；未启用时仍可实时监测电池与清理空间"
                    )
                    Spacer()
                    Button("启用特权服务") { Task { await helperCoordinator.registerHelper() } }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(6)
        } label: {
            Label("底层硬件特权通道", systemImage: "cpu.fill")
        }
    }

    // MARK: - 2. 电池充电上限与高温保护

    private var batteryControlSection: some View {
        let snap = batteryFanManager.snapshot
        return GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 18) {
                    metricPill(
                        title: "当前电量",
                        value: "\(snap.percentage)%",
                        symbol: snap.isCharging ? "battery.100percent.bolt" : "battery.75percent"
                    )
                    metricPill(
                        title: "电源状态",
                        value: batteryFanManager.isChargeInhibited ? "保护停充中" : (snap.isCharging ? "正在充电" : (snap.isPluggedIn ? "外接电源" : "使用电池")),
                        symbol: "powerplug.fill"
                    )
                    metricPill(
                        title: "电池温度",
                        value: String(format: "%.1f℃", snap.temperatureCelsius),
                        symbol: "thermometer.medium"
                    )
                    metricPill(
                        title: "循环次数",
                        value: "\(snap.cycleCount) 次",
                        symbol: "arrow.triangle.2.circlepath"
                    )
                }

                Divider()

                Toggle("启用自定义充电上限保护（延长锂电池寿命）", isOn: $settingsStore.settings.enableBatteryChargeLimit)
                    .onChange(of: settingsStore.settings.enableBatteryChargeLimit) { _, _ in
                        Task { await batteryFanManager.evaluateAndApply() }
                    }

                HStack {
                    Text("最高充电上限：\(settingsStore.settings.batteryChargeLimit)%")
                        .frame(width: 150, alignment: .leading)
                    Slider(
                        value: Binding(
                            get: { Double(settingsStore.settings.batteryChargeLimit) },
                            set: { settingsStore.settings.batteryChargeLimit = Int($0.rounded()) }
                        ),
                        in: 60...100,
                        step: 5
                    )
                    .disabled(!settingsStore.settings.enableBatteryChargeLimit)
                    Button("推荐 80%") {
                        settingsStore.settings.batteryChargeLimit = 80
                        Task { await batteryFanManager.evaluateAndApply() }
                    }
                    .controlSize(.small)
                }

                HStack {
                    Text("巡航补电回落差值：\(settingsStore.settings.batterySailingDropPercent)%")
                        .frame(width: 180, alignment: .leading)
                    Stepper(
                        value: $settingsStore.settings.batterySailingDropPercent,
                        in: 3...12
                    ) {
                        Text("回落至 \(max(50, settingsStore.settings.batteryChargeLimit - settingsStore.settings.batterySailingDropPercent))% 以下再恢复补电")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                Toggle("启用电池高温停充保护（超温灵动岛自动告警）", isOn: $settingsStore.settings.enableThermalChargeProtection)
                    .onChange(of: settingsStore.settings.enableThermalChargeProtection) { _, _ in
                        Task { await batteryFanManager.evaluateAndApply() }
                    }

                HStack {
                    Text(String(format: "停充温度阈值：%.0f℃", settingsStore.settings.maxChargeTemperatureCelsius))
                        .frame(width: 150, alignment: .leading)
                    Slider(
                        value: $settingsStore.settings.maxChargeTemperatureCelsius,
                        in: 38...48,
                        step: 1
                    )
                    .disabled(!settingsStore.settings.enableThermalChargeProtection)
                }
            }
            .padding(6)
        } label: {
            Label("智能电池与充电保护", systemImage: "bolt.batteryblock.fill")
        }
    }

    // MARK: - 3. 风扇预设与温控曲线

    private var fanControlSection: some View {
        let snap = batteryFanManager.snapshot
        return GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("当前转速：\(snap.currentFanRPM > 0 ? "\(snap.currentFanRPM) RPM" : "系统静音停转 / 自动")")
                        .font(.subheadline)
                    Spacer()
                    Text("硬件量程：\(snap.minFanRPM) ～ \(snap.maxFanRPM) RPM")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Picker("风扇散热模式", selection: $settingsStore.settings.fanControlMode) {
                    ForEach(FanControlPreset.allCases) { preset in
                        Text(preset.title).tag(preset.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: settingsStore.settings.fanControlMode) { _, _ in
                    Task { await batteryFanManager.evaluateAndApply() }
                }

                Text("提示：星岛退出或重启时将通过安全变更日志自动恢复为 macOS 系统自动风扇策略。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(6)
        } label: {
            Label("风扇散热与温控曲线", systemImage: "fanblades.fill")
        }
    }

    // MARK: - 4. 磁盘空间条与 DMG 拖入一键安装区

    private var storageAndDMGSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("系统盘空间：可用 \(formatBytes(storageSnapshot.availableDiskBytes)) / 总计 \(formatBytes(storageSnapshot.totalDiskBytes))")
                            .font(.subheadline.weight(.medium))
                        ProgressView(value: storageSnapshot.diskUsageRatio)
                            .tint(storageSnapshot.diskUsageRatio > 0.88 ? .orange : .accentColor)
                    }
                    Spacer(minLength: 20)
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("内存压力：\(storageSnapshot.memoryPressure.localizedTitle)（已用 \(formatBytes(Int64(storageSnapshot.usedMemoryBytes)))）")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("刷新统计") {
                            storageSnapshot = StorageAnalyzerService.currentSnapshot()
                        }
                        .controlSize(.small)
                    }
                }

                Divider()

                Toggle("启用 DMG 一键安装助手", isOn: $settingsStore.settings.enableDMGAutoInstallHelper)
                Toggle("安装成功后自动将源 .dmg 安装包移入废纸篓", isOn: $dmgInstaller.moveSourceDMGToTrash)
                    .font(.caption)

                VStack(spacing: 8) {
                    Image(systemName: "opticaldiscdrive.fill")
                        .font(.title2)
                        .foregroundStyle(isDropTargeted ? Color.accentColor : .secondary)
                    Text(dmgInstaller.statusMessage)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                    Button("选择本地 .dmg 安装包…") {
                        pickAndInstallDMG()
                    }
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.35),
                            style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                        )
                )
                .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                    handleDroppedDMG(providers: providers)
                }
            }
            .padding(6)
        } label: {
            Label("存储空间与 DMG 一键安装器", systemImage: "internaldrive.fill")
        }
    }

    // MARK: - 5. 应用深度卸载器可视化列表

    private var appDeepCleanerSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("扫描「应用程序」目录并精准检索 ~/Library 7 大目录关联残留文件")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(isScanningApps ? "正在扫描…" : "扫描已安装应用") {
                        scanApplications()
                    }
                    .disabled(isScanningApps)
                }

                if let banner = cleanSummaryBanner {
                    Text(banner)
                        .font(.caption)
                        .foregroundStyle(.green)
                }

                if !installedApps.isEmpty {
                    HStack(alignment: .top, spacing: 12) {
                        List(installedApps, selection: Binding(
                            get: { selectedApp?.id },
                            set: { newID in
                                let matched = installedApps.first { $0.id == newID }
                                selectApplication(matched)
                            }
                        )) { app in
                            HStack(spacing: 8) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: app.appURL.path))
                                    .resizable()
                                    .frame(width: 24, height: 24)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(app.name)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    Text(formatBytes(app.bundleSizeBytes))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .tag(app.id)
                        }
                        .frame(width: 220, height: 210)

                        VStack(alignment: .leading, spacing: 8) {
                            if let app = selectedApp {
                                Text("\(app.name)（\(app.bundleID.isEmpty ? "无标识符" : app.bundleID)）")
                                    .font(.subheadline.weight(.semibold))
                                Toggle("同时将主程序包（\(formatBytes(app.bundleSizeBytes))）移入废纸篓", isOn: $includeAppBundleInTrash)
                                    .font(.caption)

                                if residueItems.isEmpty {
                                    Text("未发现关联残留文件")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 12)
                                } else {
                                    List($residueItems) { $item in
                                        Toggle(isOn: $item.isSelected) {
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text("[\(item.category)] \(item.url.lastPathComponent)")
                                                    .font(.caption)
                                                    .lineLimit(1)
                                                Text(formatBytes(item.sizeBytes))
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                    .frame(height: 120)
                                }

                                HStack {
                                    Spacer()
                                    Button("安全移入废纸篓", role: .destructive) {
                                        performTrashSelectedApp(app)
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            } else {
                                Text("请从左侧列表选择需要检查残留的应用")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 210)
                    }
                }
            }
            .padding(6)
        } label: {
            Label("应用深度卸载器", systemImage: "trash.slash.fill")
        }
    }

    // MARK: - 交互动作辅助

    private func statusLabels(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline)
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func metricPill(title: String, value: String, symbol: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.callout.weight(.semibold))
            }
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: max(0, bytes), countStyle: .file)
    }

    private func scanApplications() {
        isScanningApps = true
        cleanSummaryBanner = nil
        Task.detached(priority: .userInitiated) {
            let apps = AppCleanerService.scanInstalledApps()
            await MainActor.run {
                installedApps = apps
                selectedApp = apps.first
                if let first = apps.first {
                    selectApplication(first)
                }
                isScanningApps = false
            }
        }
    }

    private func selectApplication(_ app: InstalledAppInfo?) {
        selectedApp = app
        guard let app else {
            residueItems = []
            return
        }
        let roots = AppCleanerService.defaultSearchRoots()
        residueItems = AppCleanerService.findResidueURLs(
            bundleID: app.bundleID,
            appName: app.name,
            searchRoots: roots
        )
    }

    private func performTrashSelectedApp(_ app: InstalledAppInfo) {
        let chosenURLs = residueItems.filter(\.isSelected).map(\.url)
        let report = AppCleanerService.moveItemsToTrash(
            chosenURLs,
            includeAppBundleURL: includeAppBundleInTrash ? app.appURL : nil
        )
        cleanSummaryBanner = "已安全移入废纸篓 \(report.trashedURLs.count) 项，释放空间 \(formatBytes(report.reclaimedBytes))"
        storageSnapshot = StorageAnalyzerService.currentSnapshot()
        if includeAppBundleInTrash && report.trashedURLs.contains(app.appURL) {
            installedApps.removeAll { $0.id == app.id }
            selectApplication(installedApps.first)
        } else {
            selectApplication(app)
        }
    }

    private func pickAndInstallDMG() {
        let panel = NSOpenPanel()
        panel.title = "选择要安装的 DMG 镜像文件"
        panel.allowedContentTypes = [UTType(filenameExtension: "dmg") ?? .data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            Task { try? await dmgInstaller.installDMG(at: url) }
        }
    }

    private func handleDroppedDMG(providers: [NSItemProvider]) -> Bool {
        guard settingsStore.settings.enableDMGAutoInstallHelper,
              let provider = providers.first else {
            return false
        }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let resolvedURL: URL?
            if let data = item as? Data {
                resolvedURL = URL(dataRepresentation: data, relativeTo: nil)
            } else if let url = item as? URL {
                resolvedURL = url
            } else {
                resolvedURL = nil
            }
            guard let dmgURL = resolvedURL, dmgURL.pathExtension.lowercased() == "dmg" else { return }
            Task { @MainActor in
                _ = try? await dmgInstaller.installDMG(at: dmgURL)
            }
        }
        return true
    }
}
