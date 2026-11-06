//
//  SettingsPanes.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2025-07-10.
//

import SwiftUI
import Combine
import Charts
import CoreBluetooth
import UniformTypeIdentifiers

struct SettingsDetailView: View {
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    var selectedSection: SettingsSection?

    private var isSelectedSectionLocked: Bool {
        selectedSection?.isPremiumLocked ?? false
    }

    var body: some View {
        VStack {
            if let selectedSection, isSelectedSectionLocked {
                LockedSettingsSectionView(section: selectedSection)
            } else {
                settingsPane(for: selectedSection)
            }
        }
        .animation(.easeOut(duration: 0.15), value: selectedSection)
        .animation(.easeOut(duration: 0.15), value: subscriptionManager.activeTier)
    }

    @ViewBuilder
    private func settingsPane(for selectedSection: SettingsSection?) -> some View {
        switch selectedSection {
        case .overview: OverviewSettingsView()
        case .general: GeneralSettingsView()
        case .systemEnhance: SystemEnhanceSettingsView()
        case .apps: AppsSettingsView()
        case .storage: StorageSettingsView()
        case .widgets: WidgetsSettingsView()
        case .liveActivities: LiveActivitiesSettingsView()
        case .appActivities: AppActivitiesSettingsView()
        case .fileProgress: FileProgressSettingsView()
        case .appearance: AppearanceSettingsView()
        case .lockScreen: LockScreenSettingsView()
        case .bluetoothUnlock: ProximityUnlockSettingsView()
        case .shortcuts: ShortcutsSettingsView()
        case .keyboardShortcuts: KeyboardShortcutsSettingsView()
        case .snapZones: SnapZonesSettingsView()
        case .audio: AudioSettingsView()
        case .battery: BatterySettingsView()
        case .bluetooth: BluetoothSettingsView()
        case .hud: HUDSettingsView()
        case .notifications: NotificationsSettingsView()
        case .nearbyShare: NearbyShareSettingsView()
        case .continuity: ContinuitySettingsView()
        case .fileShelf: FileShelfSettingsView()
        case .notes: NotesSettingsView()
        case .clipboard: ClipboardSettingsView()
        case .emoji: EmojiSettingsView()
        case .mouse: MouseSettingsView()
        case .monitoring: MonitoringSettingsView()
        case .archives: ArchivesAndDMGInstallerSettingsView()
        case .mirror: MirrorSettingsView()
        case .caffeine: CaffeineSettingsView()
        case .devActivity: DevActivitySettingsView()
        case .music: MusicSettingsView()
        case .weather: WeatherSettingsView()
        case .calendar: CalendarSettingsView()
        case .eyeBreak: EyeBreakSettingsView()
        case .focusSession: FocusSessionSettingsView()
        case .appLock: AppLockSettingsView()
        case .intelligence: IntelligenceSettingsView()
        case .sports: SportsSettingsView()
        case .finance: FinanceSettingsView()
        case .dockLayouts: DockLayoutsSettingsView()
        case .mediaOptimizer: MediaOptimizerSettingsView()
        case .about: AboutSettingsView()
        case nil:
            VStack {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 50))
                        .foregroundStyle(.tertiary)
                    Text("请选择一个分类")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct LockedSettingsSectionView: View {
    let section: SettingsSection

    private var requiredTierName: String {
        guard let tier = section.minimumRequiredTier else { return "高级版" }
        return SubscriptionFeatureCatalog.tierDisplayName(tier)
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("「\(section.label)」需要 Sapphire \(requiredTierName)")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text("前往「账户」升级以解锁此模块。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)

            Button("打开账户设置") {
                NotificationCenter.default.post(name: .sapphireOpenAccountPane, object: nil)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct RequiredPermissionsView: View {
    @ObservedObject private var permissionsManager = PermissionsManager.shared
    let section: SettingsSection
    private var requiredPermissions: [PermissionItem] { permissionsManager.allPermissions.filter { section.requiredPermissions.contains($0.type) } }
    private var missingPermissions: [PermissionItem] { requiredPermissions.filter { permissionsManager.status(for: $0.type) != .granted } }
    var body: some View {
        if !requiredPermissions.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                if !missingPermissions.isEmpty {
                    missingPermissionsWarning
                }
                Text("所需权限").font(.headline).padding([.horizontal, .top])
                ForEach(requiredPermissions) { permission in
                    PermissionStatusRowView(permission: permission)
                    if permission.id != requiredPermissions.last?.id { Divider().padding(.leading, 60) }
                }
            }.modifier(SettingsContainerModifier()).onAppear(perform: permissionsManager.checkAllPermissions)
        }
    }

    private var missingPermissionsWarning: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)
                Text(missingPermissionsMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding()
            .background(Color.orange.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange.opacity(0.5), lineWidth: 1)
            )
        }
        .padding([.horizontal, .top])
    }

    private var missingPermissionsMessage: String {
        let names = missingPermissions.map(\.title)
        if names.isEmpty { return "" }
        if names.count == 1 {
            return "尚未授予「\(names[0])」权限。启用该权限前，部分功能可能无法正常使用。"
        }
        let list = names.dropLast().joined(separator: "、") + " 和 " + names.last!
        return "尚未授予\(list)权限。启用这些权限前，部分功能可能无法正常使用。"
    }
}

struct PermissionStatusRowView: View {
    let permission: PermissionItem
    @ObservedObject private var permissionsManager = PermissionsManager.shared
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: permission.iconName).font(.system(size: 18, weight: .medium)).foregroundColor(permission.iconColor).frame(width: 36, height: 36).background(permission.iconColor.opacity(0.15)).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(permission.title).font(.system(size: 14, weight: .medium))
                Text(permission.description).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            let status = permissionsManager.status(for: permission.type)
            let isBusy = (permission.type == .localNetwork && permissionsManager.isProbingLocalNetwork)
                || (permission.type == .automation && permissionsManager.isRequestingAutomation)
            switch status {
            case .granted:
                Image(systemName: "checkmark.circle.fill").font(.title2).foregroundColor(.green)
            case .denied:
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill").font(.title2).foregroundColor(.red)
                    if permission.type == .localNetwork {
                        Button(isBusy ? "检测中…" : "重新检测") {
                            permissionsManager.retryLocalNetworkPermission()
                        }
                        .buttonStyle(.bordered)
                        .disabled(isBusy)
                    }
                    Button("去设置") { permissionsManager.openSystemSettings(for: permission.type) }
                        .buttonStyle(.bordered)
                }
            case .notRequested:
                Button(isBusy ? "授权中…" : "请求权限") {
                    permissionsManager.requestPermission(permission.type)
                }
                .buttonStyle(.bordered)
                .tint(.accentColor)
                .disabled(isBusy)
            }
            PermissionFeatureInfoButton(permission: permission)
                .padding(.trailing, 4)
        }.padding(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
    }
}

struct PermissionFeatureInfoButton: View {
    let permission: PermissionItem
    @State private var isShowingInfo = false

    var body: some View {
        Button {
            isShowingInfo.toggle()
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("查看需要此权限的功能")
        .popover(isPresented: $isShowingInfo, arrowEdge: .trailing) {
            PermissionFeatureInfoPopover(permission: permission)
        }
    }
}

struct PermissionFeatureInfoPopover: View {
    let permission: PermissionItem

    private var features: [SettingsSection] { SettingsSection.features(requiring: permission.type) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(permission.title)
            } icon: {
                Image(systemName: permission.iconName)
                    .foregroundStyle(permission.iconColor)
            }
            .font(.headline)

            Divider()

            if features.isEmpty {
                Text(permission.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("用于以下功能")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(features, id: \.self) { section in
                    HStack(spacing: 8) {
                        Image(systemName: section.systemImage)
                            .font(.system(size: 12))
                            .foregroundStyle(section.iconBackgroundColor)
                            .frame(width: 16)
                        Text(section.label)
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 240)
    }
}

struct NotchAppearanceEditorView: View {
    @Binding var appearance: NotchAppearanceSettings
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !title.isEmpty {
                Text(title).font(.headline).padding([.top, .horizontal])
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Text("样式")
                Spacer()
                Picker("", selection: $appearance.mode) {
                    ForEach(NotchAppearanceMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .fixedSize()
            }
            .padding()

            if appearance.mode == .liquidGlass || (appearance.mode == .custom && appearance.liquidGlassLook) {
                Divider().padding(.leading, 20)
                LiquidGlassOptionsEditor(
                    options: $appearance.liquidGlassOptions,
                    defaults: .notchDefault,
                    showsCornerRadius: false
                )
            }

            if appearance.mode == .default {
                Divider().padding(.leading, 20)
                ToggleRow(
                    title: "底部边缘渐隐",
                    description: "将灵动岛下边缘从黑色平滑过渡至透明。",
                    isOn: $appearance.bottomFadeEnabled
                )
            }

            if appearance.mode == .custom {
                Divider().padding(.leading, 20)
                ToggleRow(
                    title: "液态玻璃",
                    description: "为自定义灵动岛背景使用液态玻璃材质。",
                    isOn: $appearance.liquidGlassLook
                )

                Divider().padding(.leading, 20)
                HStack {
                    Text("背景样式")
                    Spacer()
                    Picker("", selection: $appearance.backgroundStyle) {
                        ForEach(NotchBackgroundStyle.allCases) { style in
                            Text(style.displayName).tag(style)
                        }
                    }.labelsHidden().frame(width: 150)
                }.padding()

                if appearance.backgroundStyle == .solid {
                    solidColorPicker
                } else {
                    gradientColorEditor
                }

                Divider().padding(.leading, 20)
                let opacityBinding = Binding<Double>(
                    get: { appearance.opacity * 100 },
                    set: { appearance.opacity = min(max($0 / 100, 0), 1) }
                )
                CustomSliderRowView(label: "主不透明度", value: opacityBinding, range: 0...100, specifier: "%.0f%%")
            }

            if appearance.mode == .blur || (appearance.mode == .custom && !appearance.liquidGlassLook) {
                Divider().padding(.leading, 20)
                ToggleRow(title: "启用透明模糊", description: "为灵动岛背景应用磨砂玻璃效果。", isOn: $appearance.enableTransparencyBlur)
            }
        }
        .modifier(SettingsContainerModifier())
        .animation(.default, value: appearance.backgroundStyle)
        .animation(.default, value: appearance.mode)
        .animation(.default, value: appearance.enableTransparencyBlur)
    }

    @ViewBuilder
    private var solidColorPicker: some View {
        ColorPicker("颜色", selection: $appearance.solidColor.color, supportsOpacity: true)
        .padding()
        .transition(.opacity)
    }

    @ViewBuilder
    private var gradientColorEditor: some View {
        VStack(alignment: .leading) {
            if appearance.backgroundStyle == .gradient {
                CustomSliderRowView(label: "角度", value: $appearance.gradientAngle, range: 0...360, specifier: "%.0f°")
                    .padding(.horizontal)
            }

            Text("渐变颜色").font(.subheadline).padding(.horizontal)

            ForEach($appearance.gradientColors) { $color in
                VStack(spacing: 8) {
                    HStack {
                        ColorPicker("色标", selection: $color.color, supportsOpacity: true)
                        Spacer()
                        Button(action: {
                            guard appearance.gradientColors.count > 1 else { return }
                            let doomed = color.id
                            DispatchQueue.main.async {
                                appearance.gradientColors.removeAll { $0.id == doomed }
                            }
                        }) {
                            Image(systemName: "minus.circle.fill").foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                        .disabled(appearance.gradientColors.count <= 1)
                    }
                    DeferredValueEditor(value: $color.location.asDouble) { draft, onEditingChanged in
                        Slider(
                            value: draft,
                            in: 0...1,
                            label: { Text("位置") },
                            minimumValueLabel: { Text("0%") },
                            maximumValueLabel: { Text("100%") },
                            onEditingChanged: onEditingChanged
                        )
                    }
                }.padding(.horizontal)
            }

            Button(action: {
                var updatedColors = appearance.gradientColors
                if let lastColor = updatedColors.last {
                    let newLocation = min(1.0, lastColor.location + 0.2)
                    let newColorStop = CodableColor(color: lastColor.color, location: newLocation)
                    updatedColors.append(newColorStop)
                } else {
                    let newColorStop = CodableColor(color: .black, location: 0.0)
                    updatedColors.append(newColorStop)
                }
                appearance.gradientColors = updatedColors.sorted { $0.location < $1.location }
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("添加色标")
                }
            }
            .buttonStyle(.plain)
            .tint(.accentColor)
            .padding(.top, 5)
            .padding(.horizontal)
        }
        .padding(.vertical)
        .transition(.opacity)
    }
}

struct SystemEnhanceSettingsView: View {
    @EditingSettings var settings: SettingsEditingSession

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                Text("系统").font(.largeTitle.bold())
                Text("不打扰日常操作的桌面动效、输入体验与窗口增强功能。")
                    .font(.subheadline).foregroundStyle(.secondary)

                SystemEnhanceHingeAnimationSettingsCard()

                VStack(alignment: .leading, spacing: 0) {
                    PremiumFeatureView(feature: .windowsPreview) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("应用切换").font(.headline).padding([.top, .horizontal])
                            ToggleRow(title: "窗口切换器", description: "以键盘驱动、支持多窗口识别的切换浮层替代系统切换器。按住快捷键并按 Tab 循环切换，方向键移动选择，按 Q 退出应用，按 W 关闭窗口。", isOn: $settings.settings.systemEnhanceWindowSwitcherEnabled)
                            if settings.settings.systemEnhanceWindowSwitcherEnabled {
                                Divider().padding(.leading, 20)
                                HStack { Text("触发快捷键"); Spacer(); Picker("", selection: Binding(
                                    get: { settings.settings.systemEnhanceSwitcherActivation.rawValue },
                                    set: { settings.settings.systemEnhanceSwitcherActivation = SESwitcherActivation(rawValue: $0) ?? .both }
                                )) {
                                    Text("⌘ Tab").tag(SESwitcherActivation.command.rawValue)
                                    Text("⌥ Tab").tag(SESwitcherActivation.option.rawValue)
                                    Text("两者皆可").tag(SESwitcherActivation.both.rawValue)
                                }.labelsHidden().frame(width: 160) }.padding()
                                Divider().padding(.leading, 20)
                                ToggleRow(title: "包含其他桌面空间的窗口", description: "同时列出其他桌面空间及全屏应用的窗口，选中后将自动切换至对应空间。", isOn: $settings.settings.systemEnhanceSwitcherIncludeOtherSpaces)
                                Divider().padding(.leading, 20)
                                HStack { Text("窗口切换器布局"); Spacer(); Picker("", selection: Binding(
                                    get: { settings.settings.systemEnhanceWindowSwitcherLayout.rawValue },
                                    set: { settings.settings.systemEnhanceWindowSwitcherLayout = SEPreviewLayout(rawValue: $0) ?? .grid }
                                )) { Text("网格").tag(SEPreviewLayout.grid.rawValue); Text("列表").tag(SEPreviewLayout.list.rawValue); Text("轮播").tag(SEPreviewLayout.carousel.rawValue) }.labelsHidden().frame(width: 150) }.padding()
                            }
                        }
                    }
                }.modifier(SettingsContainerModifier())

                VStack(alignment: .leading, spacing: 0) {
                    Text("输入行为").font(.headline).padding([.top, .horizontal])
                    ToggleRow(title: "粘贴为纯文本", description: "使用独立快捷键粘贴去除格式后的纯文本。", isOn: $settings.settings.systemEnhancePasteAsPlainTextEnabled)
                    if settings.settings.systemEnhancePasteAsPlainTextEnabled {
                        Divider().padding(.leading, 20)
                        PlainTextPasteShortcutRow()
                        Divider().padding(.leading, 20)
                        ToggleRow(title: "移除链接", description: "从粘贴的文本中剔除网页链接地址。", isOn: $settings.settings.systemEnhancePasteAsPlainStripLinks)
                        Divider().padding(.leading, 20)
                        ToggleRow(title: "移除表情符号", description: "从粘贴的文本中剔除 Emoji 表情字符。", isOn: $settings.settings.systemEnhancePasteAsPlainStripEmojis)
                        Divider().padding(.leading, 20)
                        ToggleRow(title: "移除列表标记", description: "移除列表项前的项目符号和编号标记（如 •、-、1. 等）。", isOn: $settings.settings.systemEnhancePasteAsPlainStripListMarkers)
                    }
                }.modifier(SettingsContainerModifier())

                VStack(alignment: .leading, spacing: 0) {
                    Text("日历集成").font(.headline).padding([.top, .horizontal])
                    ToggleRow(title: "日历集成", description: "在增强窗口预览和程序坞预览中显示日历日程信息。", isOn: $settings.settings.systemEnhanceCalendarIntegrationEnabled)
                }.modifier(SettingsContainerModifier())

                VStack(alignment: .leading, spacing: 0) {
                    Text("关闭即退出").font(.headline).padding([.top, .horizontal])
                    ToggleRow(title: "关闭最后一个窗口时退出应用", description: "当应用没有任何打开的窗口时，在短暂缓冲期后自动退出。默认对所有应用启用。", isOn: $settings.settings.systemEnhanceAutoQuitEnabled)
                    if settings.settings.systemEnhanceAutoQuitEnabled {
                        Divider().padding(.leading, 20)
                        Text("无窗口时自动退出的应用：")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        AppTogglesListView(
                            isEnabled: { app in $settings.settings.systemEnhanceAutoQuitExcludedApps.membership(of: app.id).negated },
                            showSearch: true
                        )
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                    }
                }.modifier(SettingsContainerModifier())

                VStack(alignment: .leading, spacing: 0) {
                    Text("退出与关闭防误触").font(.headline).padding([.top, .horizontal])
                    ToggleRow(title: "保护退出与关闭快捷键", description: "要求长按、连按两次或搭配额外修饰键才能触发 ⌘Q 和 ⌘W。默认对所有应用启用。", isOn: $settings.settings.systemEnhanceQuitProtectionEnabled)
                    if settings.settings.systemEnhanceQuitProtectionEnabled {
                        SEQuitProtectionRulesView()
                        Divider().padding(.leading, 20)
                        Text("启用 ⌘Q/⌘W 防误触保护的应用：")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        AppTogglesListView(
                            isEnabled: { app in $settings.settings.systemEnhanceQuitProtectionExcludedApps.membership(of: app.id).negated },
                            showSearch: true
                        )
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                    }
                }.modifier(SettingsContainerModifier())

                VStack(alignment: .leading, spacing: 0) {
                    Text("绿色按钮最大化").font(.headline).padding([.top, .horizontal])
                    ToggleRow(title: "在当前桌面空间最大化", description: "点击窗口左上角绿色按钮时铺满当前屏幕而不新建全屏空间；再次点击可恢复原窗口大小。", isOn: $settings.settings.systemEnhanceGreenMaximizeEnabled)
                    if settings.settings.systemEnhanceGreenMaximizeEnabled {
                        Divider().padding(.leading, 20)
                        Text("点击绿色按钮执行最大化的应用（按住 ⌥ 点击始终保留系统默认行为）：")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        AppTogglesListView(
                            isEnabled: { app in $settings.settings.systemEnhanceGreenMaximizeExcludedApps.membership(of: app.id).negated },
                            showSearch: true
                        )
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                    }
                }.modifier(SettingsContainerModifier())
            }.padding(25)
        }
    }
}

private struct SystemEnhanceHingeAnimationSettingsCard: View {
    @EditingSettings private var settings: SettingsEditingSession
    @ObservedObject private var lidAngleSensor = LidAngleSensor.shared
    @ObservedObject private var permissionsManager = PermissionsManager.shared

    private var currentLidAngleText: String {
        guard lidAngleSensor.isAvailable else { return "不可用" }
        guard lidAngleSensor.isReporting else { return "连接中…" }
        return "\(Int(lidAngleSensor.angle.rounded()))°"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("合盖转轴动画").font(.headline).padding([.top, .horizontal])
            ToggleRow(
                title: "合盖时播放过渡动画",
                description: "当屏幕合盖角度小于触发角度时，随转轴角度平滑调暗并模糊画面。",
                isOn: $settings.settings.systemEnhanceHingeAnimationEnabled
            )
            if settings.settings.systemEnhanceHingeAnimationEnabled {
                Divider().padding(.leading, 20)
                SettingsDetailRow(title: "当前开合角度") {
                    Text(currentLidAngleText).monospacedDigit()
                }
                Divider().padding(.leading, 20)
                CustomSliderRowView(
                    label: "触发角度",
                    value: $settings.settings.systemEnhanceHingeAnimationActivationAngle,
                    range: 45...140,
                    specifier: "%.0f°"
                )
                Divider().padding(.leading, 20)
                CustomSliderRowView(
                    label: "动画强度",
                    value: $settings.settings.systemEnhanceHingeAnimationIntensity,
                    range: 0.5...1.5,
                    specifier: "%.2f×"
                )
                Divider().padding(.leading, 20)
                CustomSliderRowView(
                    label: "最大模糊度",
                    value: $settings.settings.systemEnhanceHingeAnimationBlur,
                    range: 0...180,
                    specifier: "%.0f pt"
                )
            }
        }
        .modifier(SettingsContainerModifier())
        .onAppear {
            lidAngleSensor.acquire(.systemEnhanceSettingsPreview)
        }
        .onDisappear {
            lidAngleSensor.release(.systemEnhanceSettingsPreview)
        }
    }
}

struct AppsSettingsView: View {
    @EditingSettings private var settingsModel: SettingsEditingSession
    @ObservedObject private var installedUpdates = InstalledAppUpdatesChecker.shared
    @StateObject private var appModel = InstalledAppsViewModel()
    @State private var selectedTab: AppsTab = .updates
    @State private var updatesQuery = ""
    @State private var uninstallQuery = ""
    @State private var updateFilter: AppUpdateFilter = .updates
    @State private var showSystemApps = false
    @State private var reviewApp: InstalledApp?

    private enum AppsTab: String, CaseIterable, Identifiable {
        case updates = "Updates"
        case uninstall = "Uninstall"
        var id: String { rawValue }
        var icon: String { self == .updates ? "arrow.triangle.2.circlepath" : "trash" }
        var title: String {
            switch self {
            case .updates: return "应用更新"
            case .uninstall: return "应用卸载"
            }
        }
    }

    private enum AppUpdateFilter: String, CaseIterable, Identifiable {
        case updates = "Updates"
        case current = "Current"
        case attention = "Needs attention"
        case ignored = "Ignored"
        case all = "All"
        var id: String { rawValue }
        var title: String {
            switch self {
            case .updates: return "可更新"
            case .current: return "已是最新"
            case .attention: return "需关注"
            case .ignored: return "已忽略"
            case .all: return "全部"
            }
        }
    }

    private struct UpdateSnapshot {
        var filteredEntries: [InstalledAppUpdateEntry] = []
        var availableCount = 0
        var currentCount = 0
        var unsupportedCount = 0
        var checkingCount = 0
    }

    private var updateSnapshot: UpdateSnapshot {
        let query = updatesQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let ignoredIDs = installedUpdates.ignoredBundleIDs
        var snapshot = UpdateSnapshot()

        for entry in installedUpdates.entries {
            let isIgnored = ignoredIDs.contains(entry.id)
            if entry.status.isUpdateAvailable && !isIgnored { snapshot.availableCount += 1 }
            if entry.status.isUpToDate && !isIgnored { snapshot.currentCount += 1 }
            if entry.status.isUnsupported && !isIgnored { snapshot.unsupportedCount += 1 }
            if entry.status == .checking { snapshot.checkingCount += 1 }

            let matchesQuery = query.isEmpty
                || entry.name.localizedCaseInsensitiveContains(query)
                || entry.bundleIdentifier.localizedCaseInsensitiveContains(query)
            guard matchesQuery else { continue }

            let matchesFilter: Bool
            switch updateFilter {
            case .updates: matchesFilter = entry.status.isUpdateAvailable && !isIgnored
            case .current: matchesFilter = entry.status.isUpToDate && !isIgnored
            case .attention: matchesFilter = (entry.status.isUnsupported || entry.status.isError) && !isIgnored
            case .ignored: matchesFilter = isIgnored
            case .all: matchesFilter = true
            }
            if matchesFilter {
                snapshot.filteredEntries.append(entry)
            }
        }
        return snapshot
    }

    var body: some View {
        let snapshot = updateSnapshot

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                header(availableCount: snapshot.availableCount)

                switch selectedTab {
                case .updates:
                    updatesPane(snapshot: snapshot)
                case .uninstall:
                    uninstallPane
                }
            }
            .padding(25)
        }
        .onAppear {
            if settingsModel.settings.installedAppUpdatesEnabled,
               installedUpdates.entries.isEmpty {
                installedUpdates.checkInBackgroundIfNeeded(force: true, announce: false)
            }
        }
        .onChange(of: selectedTab) { _, tab in
            if tab == .uninstall { loadInstalledAppInventoryIfNeeded() }
        }
        .onChange(of: settingsModel.settings.installedAppUpdatesEnabled) { _, _ in syncInstalledUpdateSettings() }
        .onChange(of: settingsModel.settings.installedAppUpdateNotificationsEnabled) { _, enabled in
            syncInstalledUpdateSettings()
            if enabled { installedUpdates.requestNotificationAuthorization() }
        }
        .sheet(item: $reviewApp) { app in
            AppUninstallReviewSheet(app: app, model: appModel)
        }
        .sheet(item: $installedUpdates.releaseNotesEntry) { item in
            InstalledAppReleaseNotesSheet(entry: item)
        }
        .onDisappear {
            appModel.cancelScan()
            appModel.cancelArtifactScan()
        }
    }

    private func header(availableCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("应用")
                        .font(.largeTitle.bold())
                    Text("保持已安装应用处于最新版本，并在卸载清理前审阅关联数据。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if availableCount > 0 {
                    Label("\(availableCount) 项可更新", systemImage: "arrow.down.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.13), in: Capsule())
                }
            }

            Picker("应用分区", selection: $selectedTab) {
                ForEach(AppsTab.allCases) { tab in
                    Label(tab.title, systemImage: tab.icon).tag(tab)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
        }
    }

    private func updatesPane(snapshot: UpdateSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    updateMetricCards(snapshot: snapshot)
                        .frame(minWidth: 170)
                }
                VStack(spacing: 10) {
                    updateMetricCards(snapshot: snapshot)
                }
            }

            installedAppsUpdateCard(snapshot: snapshot)
        }
    }

    @ViewBuilder
    private func updateMetricCards(snapshot: UpdateSnapshot) -> some View {
        AppsMetricCard(
            title: "可更新",
            value: "\(snapshot.availableCount)",
            detail: "个应用可更新",
            systemImage: "arrow.down.circle.fill",
            tint: .blue
        )
        AppsMetricCard(
            title: "已是最新",
            value: "\(snapshot.currentCount)",
            detail: "个应用已是最新",
            systemImage: "checkmark.circle.fill",
            tint: .green
        )
        AppsMetricCard(
            title: "需关注",
            value: "\(snapshot.unsupportedCount)",
            detail: "个应用暂不支持",
            systemImage: "exclamationmark.triangle.fill",
            tint: .orange
        )
    }

    private func installedAppsUpdateCard(snapshot: UpdateSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("已安装应用更新", systemImage: "square.stack.3d.up.fill")
                    .font(.headline)
                Spacer()
                Text("上次检查：\(installedUpdates.lastCheckedDescription)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    installedUpdates.checkNow()
                } label: {
                    Label("立即检查", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(
                    installedUpdates.isChecking
                        || !settingsModel.settings.installedAppUpdatesEnabled
                )
            }

            VStack(spacing: 0) {
                ToggleRow(
                    title: "监测已安装应用",
                    description: "通过各应用的 App Store、Homebrew、Sparkle、Electron、Google 或 Mozilla 更新渠道检查新版本。",
                    isOn: $settingsModel.settings.installedAppUpdatesEnabled
                )
                Divider().padding(.leading)
                ToggleRow(
                    title: "应用更新通知",
                    description: "后台扫描发现可用新版本时向您发送通知。",
                    isOn: $settingsModel.settings.installedAppUpdateNotificationsEnabled
                )
                .disabled(!settingsModel.settings.installedAppUpdatesEnabled)
                .opacity(settingsModel.settings.installedAppUpdatesEnabled ? 1 : 0.5)
            }
            .modifier(SettingsContainerModifier())

            AppsSearchField(placeholder: "搜索更新结果", text: $updatesQuery)

            Picker("更新筛选", selection: $updateFilter) {
                ForEach(AppUpdateFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)

            if installedUpdates.isChecking {
                HStack(spacing: 10) {
                    ProgressView(value: installedUpdates.checkProgress)
                        .progressViewStyle(.linear)
                    Text("剩余 \(snapshot.checkingCount) 项")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            InstalledAppUpdatesBatchBar(checker: installedUpdates)

            LazyVStack(spacing: 0) {
                if snapshot.filteredEntries.isEmpty {
                    ContentUnavailableView(
                        "无匹配应用",
                        systemImage: updateFilter == .updates ? "checkmark.circle" : "magnifyingglass",
                        description: Text(updateFilter == .updates ? "当前没有可用的已安装应用更新。" : "请尝试切换筛选条件或更换搜索关键词。")
                    )
                    .frame(minHeight: 150)
                } else {
                    let lastEntryID = snapshot.filteredEntries.last?.id
                    ForEach(snapshot.filteredEntries) { entry in
                        InstalledAppUpdateRowView(entry: entry, checker: installedUpdates)
                        if entry.id != lastEntryID { Divider().padding(.leading, 60) }
                    }
                }
            }
            .modifier(SettingsContainerModifier())
        }
    }

    private var uninstallPane: some View {
        let query = uninstallQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let apps = appModel.apps.filter { app in
            (showSystemApps || !app.isSystem)
                && (query.isEmpty
                    || app.name.localizedCaseInsensitiveContains(query)
                    || app.bundleIdentifier.localizedCaseInsensitiveContains(query))
        }

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "trash.slash.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 3) {
                    Text("安全审阅式卸载清理")
                        .font(.headline)
                    Text("应用本体默认勾选。凡无法确证归属唯一性的关联文件均保持未勾选状态，以防误删。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    appModel.rescan()
                } label: {
                    Label("重新扫描", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(appModel.isLoading)
            }
            .padding(14)
            .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.orange.opacity(0.2)))

            HStack(spacing: 12) {
                AppsSearchField(placeholder: "搜索已安装应用", text: $uninstallQuery)
                Toggle("显示系统应用", isOn: $showSystemApps)
                    .toggleStyle(.checkbox)
                    .fixedSize()
            }

            if appModel.isLoading {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("正在扫描应用程序…")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("取消扫描") { appModel.cancelScan() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                .padding(.vertical, 12)
            }

            if let scanError = appModel.scanError, !scanError.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("部分应用程序无法扫描")
                            .font(.subheadline.weight(.semibold))
                        Text(scanError)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .help(scanError)
                    }
                    Spacer()
                    Button("重新扫描") { appModel.rescan() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(appModel.isLoading)
                }
                .padding(12)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }

            LazyVStack(spacing: 0) {
                if !appModel.isLoading && apps.isEmpty {
                    ContentUnavailableView(
                        query.isEmpty ? "未找到应用程序" : "未找到「\(query)」的相关结果",
                        systemImage: "magnifyingglass",
                        description: Text(query.isEmpty ? "请点击「重新扫描」刷新已安装应用列表。" : "请检查拼写或尝试其他搜索关键词。")
                    )
                        .frame(minHeight: 180)
                } else {
                    let lastAppID = apps.last?.id
                    ForEach(apps) { app in
                        HStack(spacing: 12) {
                            CachedAppIconView(url: app.url, size: 40, cornerRadius: 9)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(app.name).font(.headline)
                                Text(app.isSystem
                                    ? "版本 \(app.version) · 受保护应用"
                                    : "版本 \(app.version) · \(app.formattedSize)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(app.bundleIdentifier)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if installedUpdates.isBusy(app.bundleIdentifier) {
                                HStack(spacing: 6) {
                                    ProgressView().controlSize(.small)
                                    Text("正在更新…")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            } else if app.isSystem {
                                Label("受保护", systemImage: "lock.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Button("审阅并卸载…") {
                                    appModel.select(app)
                                    reviewApp = app
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        if app.id != lastAppID { Divider().padding(.leading, 66) }
                    }
                }
            }
            .modifier(SettingsContainerModifier())
        }
    }

    private func syncInstalledUpdateSettings() {
        installedUpdates.applySettings(
            installedAppUpdatesEnabled: settingsModel.settings.installedAppUpdatesEnabled,
            notificationsEnabled: settingsModel.settings.installedAppUpdateNotificationsEnabled
        )
    }

    private func loadInstalledAppInventoryIfNeeded() {
        guard appModel.apps.isEmpty, !appModel.isLoading else { return }
        appModel.scan()
    }

}

private struct AppsMetricCard: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(detail).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.white.opacity(0.1)))
    }
}

private struct AppsSearchField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        ClearableSearchField(placeholder: LocalizedStringKey(placeholder), text: $text)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct AppUninstallReviewSheet: View {
    let app: InstalledApp
    @ObservedObject var model: InstalledAppsViewModel
    @Environment(\.dismiss) private var dismiss

    private var groupedArtifacts: [(AppArtifactCategory, [AppUninstallArtifact])] {
        Dictionary(grouping: model.artifacts, by: \.category)
            .map { ($0.key, $0.value) }
            .sorted { $0.0.rawValue < $1.0.rawValue }
    }

    private func localizedCategoryTitle(_ raw: String) -> String {
        switch raw {
        case "Application", "Applications": return "应用程序"
        case "Application Support": return "应用支持文件"
        case "Caches", "Cache": return "缓存"
        case "Preferences": return "偏好设置"
        case "Saved State", "Saved Application State": return "已保存的应用状态"
        case "Containers", "Sandboxed Containers": return "容器数据"
        case "Group Containers": return "共享容器"
        case "Logs": return "日志"
        case "Launch Agents", "Launch Daemons", "Background Items": return "启动项与后台服务"
        case "WebKit", "WebKit Data": return "WebKit 数据"
        case "HTTP Storages": return "HTTP 存储"
        case "Crash Reports": return "崩溃报告"
        case "Receipts": return "安装凭据"
        case "Scripts", "Application Scripts": return "应用脚本"
        default: return raw
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                CachedAppIconView(url: app.url, size: 48, cornerRadius: 10)
                VStack(alignment: .leading, spacing: 3) {
                    Text("卸载 \(app.name)").font(.title2.bold())
                    Text("已选中应用本体。标识符关联、共享及按名称匹配的数据除非已确证归属，否则需手动审阅勾选。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("取消") { dismiss() }
                    .disabled(model.isRemoving)
            }
            .padding(20)

            Divider()

            if model.isScanningArtifacts {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("正在查找关联文件…").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let result = model.uninstallResult, result.appName == app.name {
                uninstallResultView(result)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        if model.artifacts.contains(where: { $0.confidence != .exact }) {
                            Label("未验证、共享、嵌套组件、重复标识符及按应用名称匹配的条目默认不勾选，请审阅后再选择。", systemImage: "exclamationmark.shield.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                        }

                        ForEach(groupedArtifacts, id: \.0.id) { category, artifacts in
                            VStack(alignment: .leading, spacing: 0) {
                                Label(localizedCategoryTitle(category.rawValue), systemImage: category.systemImage)
                                    .font(.headline)
                                    .padding(.bottom, 7)
                                ForEach(artifacts) { artifact in
                                    Toggle(isOn: Binding(
                                        get: { model.selectedArtifactIDs.contains(artifact.id) },
                                        set: { model.setArtifact(artifact, selected: $0) }
                                    )) {
                                        HStack(spacing: 10) {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(artifact.url.lastPathComponent)
                                                    .font(.subheadline.weight(.medium))
                                                    .lineLimit(1)
                                                Text(artifact.url.path)
                                                    .font(.caption2.monospaced())
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                                    .truncationMode(.middle)
                                                if artifact.requiresAuthorization, !artifact.isApplication {
                                                    Text("需要管理员权限，请手动移除")
                                                        .font(.caption2)
                                                        .foregroundStyle(.secondary)
                                                } else if artifact.confidence != .exact {
                                                    Text(artifact.confidence.explanation)
                                                        .font(.caption2)
                                                        .foregroundStyle(.orange)
                                                }
                                            }
                                            Spacer()
                                            if artifact.requiresAuthorization {
                                                Image(systemName: "lock.fill")
                                                    .foregroundStyle(.secondary)
                                                    .help("需要管理员权限，Sapphire 无法自动移除此项目")
                                            }
                                            Text(artifact.formattedSize)
                                                .font(.caption.monospacedDigit())
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .toggleStyle(.checkbox)
                                    .disabled(
                                        artifact.isApplication
                                            || model.isRemoving
                                            || artifact.requiresAuthorization
                                    )
                                    .padding(.vertical, 7)
                                    if artifact.id != artifacts.last?.id { Divider().padding(.leading, 24) }
                                }
                            }
                            .padding(14)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.1)))
                        }
                    }
                    .padding(20)
                }

                Divider()
                HStack {
                    Menu("选择") {
                        Button("推荐项") { model.selectRecommendedArtifacts() }
                        Button("全选关联文件") { model.selectAllArtifacts() }
                    }
                    .disabled(model.isRemoving)
                    Text("已选 \(model.selectedArtifacts.count) 项 · \(model.selectedSize.formatted(.byteCount(style: .file)))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(role: .destructive) {
                        model.requestRemoval(app)
                    } label: {
                        if model.isRemoving {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("卸载 \(app.name)")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(model.isRemoving || model.selectedArtifacts.isEmpty)
                }
                .padding(16)
            }
        }
        .frame(minWidth: 680, idealWidth: 760, minHeight: 560, idealHeight: 700)
        .interactiveDismissDisabled(model.isRemoving)
        .onDisappear {
            if !model.isRemoving { model.cancelArtifactScan() }
        }
        .alert("将应用及所选关联文件移至废纸篓？", isPresented: $model.confirmingRemoval) {
            Button("卸载", role: .destructive) { model.removeConfirmed() }
            Button("取消", role: .cancel) {}
        } message: {
            Text(model.removalMessage)
        }
    }

    @ViewBuilder
    private func uninstallResultView(_ result: AppUninstallResult) -> some View {
        VStack(spacing: 14) {
            Image(systemName: result.succeeded ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(result.succeeded ? .green : .orange)
            Text(result.applicationRemoved
                ? (result.succeeded ? "已移除应用及所选数据" : "应用已移除，但部分残留文件未能清理")
                : "无法移除该应用")
                .font(.title3.bold())
            Text("已将 \(result.removed.count) 个项目移至废纸篓。")
                .foregroundStyle(.secondary)
            if !result.failures.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(result.failures) { failure in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(failure.url.path).font(.caption.monospaced()).lineLimit(1)
                            Text(failure.message).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }
            Button("完成") { dismiss() }.keyboardShortcut(.defaultAction)
        }
        .padding(30)
    }
}

private struct InstalledAppUpdateRowView: View {
    let entry: InstalledAppUpdateEntry
    let checker: InstalledAppUpdatesChecker

    private func localizedActionLabel(_ label: String) -> String {
        switch label {
        case "Open App": return "打开应用"
        case "Update": return "更新"
        case "Upgrade": return "升级"
        case "Download": return "下载"
        case "Open in App Store": return "在 App Store 中打开"
        default: return label
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            InstalledAppUpdateSelectionToggle(checker: checker, entry: entry)

            CachedAppIconView(url: entry.url, size: 36, cornerRadius: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)

                switch entry.status {
                case .checking:
                    Text("正在检查…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .upToDate(let latest):
                    Text("版本 \(entry.currentVersion) · 已是最新")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if AppVersionOrdering.isNewer(latest, than: entry.currentVersion) {
                        Text("最新可用版本：\(latest)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                case .updateAvailable(let latest, _, _, let releaseNotes, _):
                    HStack(spacing: 6) {
                        Text("\(entry.currentVersion) → \(latest)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.blue)
                        if let releaseNotes, !releaseNotes.isEmpty {
                            Button("更新日志") {
                                checker.releaseNotesEntry = InstalledAppUpdatesChecker.ReleaseNotesEntry(entry: entry)
                            }
                            .buttonStyle(.link)
                            .font(.caption)
                        }
                    }
                    let actionLabel = checker.buttonLabel(for: entry)
                    if actionLabel == "Open App" || actionLabel == "打开应用" {
                        Text("使用应用内置签名更新器 — Sapphire 将打开该应用。")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                case .unsupported:
                    Text(checker.canOpenManagedUpdater(for: entry)
                        ? "更新由该应用内部管理"
                        : "未找到更新源")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                case .ignored:
                    Text("已忽略")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                case .error(let message):
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                }
            }

            Spacer()

            statusActions
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var statusActions: some View {
        switch entry.status {
        case .updateAvailable:
            HStack(spacing: 8) {
                if checker.isBusy(entry.id) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在升级…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Button(localizedActionLabel(checker.buttonLabel(for: entry))) {
                        checker.updateAction(for: entry.id)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                Menu {
                    InstalledAppUpdateSkipMenuItems(checker: checker, entry: entry)
                    Button("忽略此应用") { checker.setIgnored(true, for: entry.id) }
                    if case .updateAvailable(_, _, let pageURL, _, _) = entry.status, let pageURL {
                        Button(checker.isAppStoreEntry(entry) ? "在 App Store 中打开" : "打开更新页面") {
                            checker.openUpdatePage(for: entry, pageURL: pageURL)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        case .checking, .upToDate:
            Menu {
                InstalledAppUpdateSkipMenuItems(checker: checker, entry: entry)
                Button("重新检查") { checker.checkAgain(entryID: entry.id) }
                Button("忽略此应用") { checker.setIgnored(true, for: entry.id) }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        case .ignored, .unsupported, .error:
            Menu {
                if checker.canOpenManagedUpdater(for: entry) {
                    Button("打开应用更新器") { checker.openManagedUpdater(entryID: entry.id) }
                }
                Button("重新检查") { checker.checkAgain(entryID: entry.id) }
                Button(checker.isIgnored(entry) ? "取消忽略" : "忽略此应用") {
                    checker.setIgnored(!checker.isIgnored(entry), for: entry.id)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }
}

private struct InstalledAppReleaseNotesSheet: View {
    let entry: InstalledAppUpdatesChecker.ReleaseNotesEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                CachedAppIconView(url: entry.url, size: 40, cornerRadius: 9)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(entry.name) \(entry.latestVersion)")
                        .font(.headline)
                    Text("更新日志")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("完成") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            Divider()
            ScrollView {
                if let notes = entry.releaseNotes, !notes.isEmpty {
                    Text(notes)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if let url = entry.releaseNotesURL {
                    VStack(spacing: 12) {
                        Text("更新日志已在线发布。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("在浏览器中打开") {
                            NSWorkspace.shared.open(url)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    Text("此次更新未发布更新日志。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                }
            }
        }
        .padding(20)
        .frame(width: 460, height: 380)
    }
}

struct StorageSettingsView: View {
    @StateObject private var model = StorageViewModel()

    var body: some View {
        ScrollView {
            PremiumFeatureView(feature: .basicStorageFeatures) {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("存储空间")
                            .font(.largeTitle.bold())
                        Text("直观查看空间占用情况，追踪占用变化，并安全释放磁盘空间。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if model.currentURL.path != "/" {
                        StorageBreadcrumbBar(model: model)
                    }

                    StorageWorkspaceView(model: model)

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundStyle(MaterialChartPalette.tertiary)
                        Text("受保护的系统目录仅供查看。每次清理均经过审阅并先移至废纸篓，随后再释放空间。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 4)
                }
                .padding(25)
            }
        }
        .onAppear { model.refreshFromCache() }
        .onDisappear { model.cancelScan() }
        .alert("将所选项目移至废纸篓？", isPresented: $model.confirmingRemoval) {
            Button("移至废纸篓", role: .destructive) { model.removeConfirmed() }
            Button("取消", role: .cancel) { model.cancelRemovalRequest() }
        } message: { Text(model.removalMessage) }
    }
}

private struct StorageBreadcrumbBar: View {
    @ObservedObject var model: StorageViewModel

    private var pathComponents: [(String, URL)] {
        let path = model.currentURL.standardizedFileURL.path
        let parts = path.split(separator: "/").map(String.init)
        var result: [(String, URL)] = [("Macintosh HD", URL(fileURLWithPath: "/"))]
        var url = URL(fileURLWithPath: "/")
        for part in parts where part != "" {
            url.appendPathComponent(part)
            result.append((part, url))
        }
        return result
    }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: model.goUp) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .background(.thinMaterial, in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.12)))
            .disabled(model.currentURL.path == "/")
            .help("返回上级文件夹")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(pathComponents.enumerated()), id: \.offset) { index, component in
                        if index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.tertiary)
                        }
                        Button {
                            model.open(StorageEntry(url: component.1, size: 0, isDirectory: true))
                        } label: {
                            Label(component.0, systemImage: index == 0 ? "internaldrive.fill" : "folder.fill")
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(index == pathComponents.count - 1 ? Color.accentColor.opacity(0.22) : Color.white.opacity(0.07), in: Capsule())
                        .overlay(Capsule().stroke(index == pathComponents.count - 1 ? Color.accentColor.opacity(0.55) : Color.white.opacity(0.10)))
                    }
                }
                .padding(.vertical, 2)
            }

            Button("刷新", systemImage: "arrow.clockwise") { model.refresh() }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .frame(width: 30, height: 30)
                .background(.thinMaterial, in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.12)))
                .help("刷新文件夹内容")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.14)))
    }
}

private struct IndexingPill: View {
    let progress: Double
    let label: String

    var body: some View {
        HStack(spacing: 10) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .frame(width: 130)
            Text(label).font(.caption.weight(.medium)).lineLimit(1)
            Text("\(Int(progress * 100))%")
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.thinMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.12)))
    }
}

private struct StoragePieSlice: View {
    let start: Double
    let end: Double
    let color: Color
    let label: String
    let fraction: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                PieSlicePath(start: start, end: end)
                    .fill(color)
                    .overlay(PieSlicePath(start: start, end: end).stroke(Color.black.opacity(0.35), lineWidth: 1))
                let angle = (start + end) / 2 * 2 * .pi - .pi / 2
                let radius = min(geometry.size.width, geometry.size.height) * 0.36
                if fraction >= 0.035 {
                    Text(label)
                        .font(.system(size: fraction < 0.06 ? 8 : 10, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(width: fraction < 0.06 ? 48 : 82)
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                        .clipped()
                        .rotationEffect(.radians(angle + .pi / 2))
                        .position(x: geometry.size.width / 2 + cos(angle) * radius, y: geometry.size.height / 2 + sin(angle) * radius)
                }
            }
        }
    }
}

private struct PieSlicePath: Shape {
    let start: Double
    let end: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: .degrees(start * 360 - 90), endAngle: .degrees(end * 360 - 90), clockwise: false)
        path.closeSubpath()
        return path
    }
}

struct GeneralSettingsView: View {
    @EditingSettings var settings: SettingsEditingSession
    @State private var showingCustomConfig = false
    @ObservedObject private var appFetcher = SystemAppFetcher.shared

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                Text("通用")
                    .font(.largeTitle.bold())
                    .padding(.bottom)

                VStack(alignment: .leading, spacing: 0) {
                    SettingsSectionHeader(title: "交互行为")
                ForEach(GeneralSettingType.allCases) { setting in
                    IconToggleRow(systemImage: setting.systemImage, color: setting.iconColor, title: setting.displayName, isOn: binding(for: setting))
                    if setting == .expandOnHover, settings.settings.expandOnHover {
                        CustomSliderRowView(
                            label: "悬停延迟",
                            value: $settings.settings.expandOnHoverDelay,
                            range: 0.0...1.0,
                            specifier: "%.2f 秒"
                        )
                        .padding(.horizontal, 60)
                        .padding(.bottom, 8)
                    }
                    if setting != GeneralSettingType.allCases.last {
                        Divider().padding(.leading, 60)
                    }
                }
                if settings.settings.capsLockHorizontalLockEnabled {
                    Divider().padding(.leading, 60)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("允许在以下应用中使用")
                            .font(.headline)
                            .padding([.horizontal])
                        AppTogglesListView(
                            isEnabled: { app in capsLockAppBinding(for: app, isBrowser: app.isBrowser) },
                            maxHeight: 360,
                            browsersSectionTitle: "浏览器（默认禁用）",
                            onSelectAll: setAllApps
                        )
                    }
                    .padding()
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }.modifier(SettingsContainerModifier())

                SettingsCard(title: "系统") {

                    ToggleRow(title: "登录时启动", description: "登录 Mac 时自动启动 Sapphire。", isOn: $settings.settings.launchAtLogin)
                    Divider().padding(.leading, 20)

                    ToggleRow(title: "启用触感反馈", description: "在执行特定交互操作时提供触控板触感反馈。", isOn: $settings.settings.hapticFeedbackEnabled)
                    Divider().padding(.leading, 20)

                    ToggleRow(title: "在屏幕共享中隐藏", description: "在屏幕共享、截屏及屏幕录制中始终隐藏 Sapphire。", isOn: $settings.settings.hideFromScreenSharing)
                    Divider().padding(.leading, 20)

                    ToggleRow(title: "Google Analytics 统计", description: "向 Google 发送匿名使用事件以帮助改进 Sapphire。关闭此项即可退出统计数据收集。", isOn: $settings.settings.googleAnalyticsEnabled)
                    Divider().padding(.leading, 20)

                    ToggleRow(
                        title: "上滑隐藏灵动岛",
                        description: "灵动岛收起时，在其上方上滑即可完全隐藏；在灵动岛区域附近下滑可重新唤出。",
                        isOn: $settings.settings.swipeToHideNotch
                    )
                    Divider().padding(.leading, 20)

                    ToggleRow(
                        title: "锁屏时禁止展开",
                        description: "当 Mac 处于锁定屏幕状态时，阻止通过悬停、点击或滑动展开灵动岛。",
                        isOn: $settings.settings.preventNotchExpandWhenLocked
                    )
                }

                SettingsCard(title: "小组件切换过渡", description: "控制在展开的灵动岛内切换小组件时的视觉过渡效果。") {

                    Toggle("启用淡入淡出效果", isOn: $settings.settings.enableWidgetSwitchFade)
                        .padding()
                    Divider().padding(.leading, 20)
                    Toggle("启用滑动效果", isOn: $settings.settings.enableWidgetSwitchSlide)
                        .padding()
                    Divider().padding(.leading, 20)
                    Toggle("启用回弹效果", isOn: $settings.settings.enableWidgetSwitchBounce)
                        .padding()
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("动画预设")
                        .font(.headline)
                        .padding([.horizontal, .top])

                    Text(descriptionForCurrentProfile())
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 5)

                    Picker("动画预设", selection: $settings.settings.animationProfile) {
                        ForEach(AnimationProfile.allCases) { profile in
                            Text(profile.displayName).tag(profile)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.bottom)

                    if settings.settings.animationProfile == .custom {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("自定义动画参数")
                                    .font(.subheadline.bold())
                                Spacer()
                                Button("恢复默认") {
                                    withAnimation {
                                        settings.settings.customAnimationConfiguration = .init()
                                    }
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.accentColor)
                                .help("将所有自定义动画参数重置为「灵动干脆」默认值。")
                            }

                            Text("响应时间：动画持续时长（数值越小越快）。\n阻尼系数：回弹幅度（1.0 表示无回弹）。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.bottom, 5)

                            Group {
                                Text("主要过渡").font(.caption.bold()).foregroundColor(.secondary)
                                AnimationSliderRow(title: "展开响应时间", description: "打开主小组件视图时的动画响应速度。", value: $settings.settings.customAnimationConfiguration.expandResponse, range: 0.1...1.0)
                                AnimationSliderRow(title: "展开阻尼系数", description: "", value: $settings.settings.customAnimationConfiguration.expandDamping, range: 0.4...1.0)
                                Divider()
                                AnimationSliderRow(title: "收起响应时间", description: "关闭主小组件视图时的动画响应速度。", value: $settings.settings.customAnimationConfiguration.collapseResponse, range: 0.1...1.0)
                                AnimationSliderRow(title: "收起阻尼系数", description: "", value: $settings.settings.customAnimationConfiguration.collapseDamping, range: 0.4...1.0)
                                Divider()
                                AnimationSliderRow(title: "滑动展开响应时间", description: "使用触控板滑动打开小组件时的动画响应速度。", value: $settings.settings.customAnimationConfiguration.swipeOpenResponse, range: 0.1...1.0)
                                AnimationSliderRow(title: "滑动展开阻尼系数", description: "", value: $settings.settings.customAnimationConfiguration.swipeOpenDamping, range: 0.4...1.0)
                            }

                            Group {
                                Text("动态状态").font(.caption.bold()).foregroundColor(.secondary).padding(.top)
                                AnimationSliderRow(title: "悬停响应时间", description: "鼠标悬停在灵动岛上时微幅展开的动画速度。", value: $settings.settings.customAnimationConfiguration.hoverResponse, range: 0.1...1.0)
                                AnimationSliderRow(title: "悬停阻尼系数", description: "", value: $settings.settings.customAnimationConfiguration.hoverDamping, range: 0.4...1.0)
                                Divider()
                                AnimationSliderRow(title: "自动展开响应时间", description: "实时活动自动弹出时的动画响应速度。", value: $settings.settings.customAnimationConfiguration.autoExpandResponse, range: 0.1...1.0)
                                AnimationSliderRow(title: "自动展开阻尼系数", description: "", value: $settings.settings.customAnimationConfiguration.autoExpandDamping, range: 0.4...1.0)
                            }

                            Group {
                                Text("内容与实时活动").font(.caption.bold()).foregroundColor(.secondary).padding(.top)
                                AnimationSliderRow(title: "内容过渡响应时间", description: "小组件在展开视图内显现的动画速度。", value: $settings.settings.customAnimationConfiguration.contentTransitionResponse, range: 0.1...1.0)
                                AnimationSliderRow(title: "内容过渡阻尼系数", description: "", value: $settings.settings.customAnimationConfiguration.contentTransitionDamping, range: 0.4...1.0)
                                Divider()
                                AnimationSliderRow(title: "活动切换响应时间", description: "在不同实时活动之间切换的动画速度。", value: $settings.settings.customAnimationConfiguration.activityToActivityResponse, range: 0.1...1.0)
                                AnimationSliderRow(title: "活动切换阻尼系数", description: "", value: $settings.settings.customAnimationConfiguration.activityToActivityDamping, range: 0.4...1.0)
                                Divider()
                                AnimationSliderRow(title: "活动形变响应时间", description: "平滑改变实时活动外形的动画速度。", value: $settings.settings.customAnimationConfiguration.activityMorphResponse, range: 0.1...1.0)
                                AnimationSliderRow(title: "活动形变阻尼系数", description: "", value: $settings.settings.customAnimationConfiguration.activityMorphDamping, range: 0.4...1.0)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .modifier(SettingsContainerModifier())
                .animation(.default, value: settings.settings.animationProfile)

                VStack(alignment: .leading, spacing: 0) {
                    Text("高级自定义").font(.headline).padding([.top, .horizontal])
                    ToggleRow(title: "启用自定义灵动岛配置", description: "覆盖默认外观尺寸与动画参数。调整不当可能导致显示或交互异常。", isOn: $settings.settings.useCustomNotchConfiguration)

                    if settings.settings.useCustomNotchConfiguration {
                        Button("编辑自定义配置") {
                            showingCustomConfig = true
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                    }
                }
                .modifier(SettingsContainerModifier())
                .animation(.default, value: settings.settings.useCustomNotchConfiguration)

                VStack(alignment: .leading, spacing: 10) {
                    Text("灵动岛栏项目").font(.headline).padding([.horizontal, .top])
                    Text("启用、停用并拖动排序展开灵动岛时显示的顶栏图标。").font(.caption).foregroundColor(.secondary).padding(.horizontal).padding(.bottom, 5)
                    ReorderableVStack(items: $settings.settings.notchButtonOrder) { buttonType in
                        NotchButtonRowView(buttonType: buttonType)
                    }

                    if settings.settings.notchButtonOrder.contains(.spacer) {
                        Divider().padding(.horizontal)
                        NotchBarSpacerWidthRow()
                    }
                }
                .modifier(SettingsContainerModifier())

            }
        .padding(25)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .onAppear {
        if settings.settings.capsLockHorizontalLockEnabled {
            appFetcher.fetchApps()
        }
    }
    .onChange(of: settings.settings.capsLockHorizontalLockEnabled) { _, enabled in
        if enabled {
            appFetcher.fetchApps()
        } else {
            SystemAppFetcher.shared.releaseCachedApps()
            AppIconLoader.releaseCache()
        }
    }
    .sheet(isPresented: $showingCustomConfig) {
            CustomNotchConfigView(config: $settings.settings.customNotchConfiguration)
        }
    }

    private func binding(for setting: GeneralSettingType) -> Binding<Bool> {
        switch setting {
        case .expandOnHover: return $settings.settings.expandOnHover
        case .swipeToSwitchWidgets: return $settings.settings.swipeToSwitchWidgets
        case .enableOpeningBounce: return $settings.settings.enableOpeningBounce
        case .capsLockHorizontalLock: return $settings.settings.capsLockHorizontalLockEnabled
        }
    }

    private func capsLockAppBinding(for app: SystemApp, isBrowser: Bool) -> Binding<Bool> {
        Binding(
            get: { settings.settings.capsLockHorizontalLockAppStates[app.id, default: true] },
            set: { settings.settings.capsLockHorizontalLockAppStates[app.id] = $0 }
        )
    }

    private func setAllApps(to enabled: Bool) {
        var appStates = settings.settings.capsLockHorizontalLockAppStates
        appStates.reserveCapacity(appFetcher.apps.count)
        for app in appFetcher.apps {
            appStates[app.id] = enabled
        }
        settings.settings.capsLockHorizontalLockAppStates = appStates
    }

    private func descriptionForCurrentProfile() -> String {
        switch settings.settings.animationProfile {
        case .snappy:
            return "干脆利落、响应迅速，回弹极小。"
        case .fluid:
            return "默认推荐。内容随灵动岛轮廓自然舒展，落定瞬间由虚化清晰对焦。"
        case .bouncy:
            return "灵动活泼、富有张力，带有明显的弹性回弹效果。"
        case .calm:
            return "舒缓优雅，过渡柔和克制。"
        case .custom:
            return "精细微调每一项动画参数，契合您的专属手感。"
        }
    }
}

fileprivate struct AnimationSliderRow: View {
    let title: String
    let description: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        DeferredValueEditor(value: $value) { draft, onEditingChanged in
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(title)
                        if !description.isEmpty {
                            Text(description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Text(String(format: "%.2f", draft.wrappedValue))
                        .font(.body.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                Slider(value: draft, in: range, onEditingChanged: onEditingChanged)
            }
        }
        .padding(.vertical, 8)
    }
}

struct CustomNotchConfigView: View {
    @Binding var config: CustomizableNotchConfiguration
    @Environment(\.dismiss) var dismiss

    @State private var initialCornerRadius: Double
    @State private var topBuffer: Double
    @State private var scaleFactor: Double
    @State private var hoverExpandedCornerRadius: Double
    @State private var autoExpandedCornerRadius: Double
    @State private var autoExpandedTallHeight: Double
    @State private var autoExpandedContentVerticalPadding: Double
    @State private var clickExpandedCornerRadius: Double
    @State private var liveActivityBottomCornerRadius: Double
    @State private var collapseAnimationDelay: Double
    @State private var dragActivationCollapseDelay: Double
    @State private var expandAnimationResponse: Double
    @State private var expandAnimationDamping: Double
    @State private var swipeOpenAnimationResponse: Double
    @State private var swipeOpenAnimationDamping: Double
    @State private var collapseAnimationResponse: Double
    @State private var collapseAnimationDamping: Double
    @State private var widgetBlurRadiusMax: Double
    @State private var activityBlurRadiusMax: Double
    @State private var expandedShadowRadius: Double
    @State private var expandedShadowOffsetY: Double
    @State private var contentTopPadding: Double
    @State private var contentBottomPadding: Double
    @State private var contentHorizontalPadding: Double

    init(config: Binding<CustomizableNotchConfiguration>) {
        self._config = config
        let wrapped = config.wrappedValue

        _initialCornerRadius = State(initialValue: Double(wrapped.initialCornerRadius))
        _topBuffer = State(initialValue: Double(wrapped.topBuffer))
        _scaleFactor = State(initialValue: Double(wrapped.scaleFactor))
        _hoverExpandedCornerRadius = State(initialValue: Double(wrapped.hoverExpandedCornerRadius))
        _autoExpandedCornerRadius = State(initialValue: Double(wrapped.autoExpandedCornerRadius))
        _autoExpandedTallHeight = State(initialValue: Double(wrapped.autoExpandedTallHeight))
        _autoExpandedContentVerticalPadding = State(initialValue: Double(wrapped.autoExpandedContentVerticalPadding))
        _clickExpandedCornerRadius = State(initialValue: Double(wrapped.clickExpandedCornerRadius))
        _liveActivityBottomCornerRadius = State(initialValue: Double(wrapped.liveActivityBottomCornerRadius))
        _collapseAnimationDelay = State(initialValue: wrapped.collapseAnimationDelay)
        _dragActivationCollapseDelay = State(initialValue: wrapped.dragActivationCollapseDelay)
        _expandAnimationResponse = State(initialValue: wrapped.expandAnimationResponse)
        _expandAnimationDamping = State(initialValue: wrapped.expandAnimationDamping)
        _swipeOpenAnimationResponse = State(initialValue: wrapped.swipeOpenAnimationResponse)
        _swipeOpenAnimationDamping = State(initialValue: wrapped.swipeOpenAnimationDamping)
        _collapseAnimationResponse = State(initialValue: wrapped.collapseAnimationResponse)
        _collapseAnimationDamping = State(initialValue: wrapped.collapseAnimationDamping)
        _widgetBlurRadiusMax = State(initialValue: Double(wrapped.widgetBlurRadiusMax))
        _activityBlurRadiusMax = State(initialValue: Double(wrapped.activityBlurRadiusMax))
        _expandedShadowRadius = State(initialValue: Double(wrapped.expandedShadowRadius))
        _expandedShadowOffsetY = State(initialValue: Double(wrapped.expandedShadowOffsetY))
        _contentTopPadding = State(initialValue: Double(wrapped.contentTopPadding))
        _contentBottomPadding = State(initialValue: Double(wrapped.contentBottomPadding))
        _contentHorizontalPadding = State(initialValue: Double(wrapped.contentHorizontalPadding))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("自定义灵动岛配置")
                    .font(.title2.bold())
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            ScrollView {
                LazyVStack(spacing: 25) {
                    Section(header: Text("尺寸与位置").font(.headline)) {
                        CustomSliderRowView(label: "自动展开高度", value: $autoExpandedTallHeight, range: 50...150, specifier: "%.1f")
                        CustomSliderRowView(label: "顶部缓冲间距", value: $topBuffer, range: 0...20, specifier: "%.1f")
                    }

                    Section(header: Text("悬停状态").font(.headline)) {
                        CustomSliderRowView(label: "悬停缩放倍率", value: $scaleFactor, range: 1.0...1.5, specifier: "%.2f x")
                    }

                    Section(header: Text("圆角半径").font(.headline)) {
                        CustomSliderRowView(label: "初始状态", value: $initialCornerRadius, range: 5...50, specifier: "%.1f")
                        CustomSliderRowView(label: "悬停展开", value: $hoverExpandedCornerRadius, range: 10...60, specifier: "%.1f")
                        CustomSliderRowView(label: "自动展开", value: $autoExpandedCornerRadius, range: 10...60, specifier: "%.1f")
                        CustomSliderRowView(label: "点击展开", value: $clickExpandedCornerRadius, range: 10...60, specifier: "%.1f")
                        CustomSliderRowView(label: "实时活动底部", value: $liveActivityBottomCornerRadius, range: 10...60, specifier: "%.1f")
                    }

                    Section(header: Text("弹簧动画").font(.headline)) {
                        CustomSliderRowView(label: "展开响应时间", value: $expandAnimationResponse, range: 0.1...1.0, specifier: "%.2f")
                        CustomSliderRowView(label: "展开阻尼系数", value: $expandAnimationDamping, range: 0.1...1.0, specifier: "%.2f")
                        CustomSliderRowView(label: "滑动展开响应时间", value: $swipeOpenAnimationResponse, range: 0.1...1.0, specifier: "%.2f")
                        CustomSliderRowView(label: "滑动展开阻尼系数", value: $swipeOpenAnimationDamping, range: 0.1...1.0, specifier: "%.2f")
                        CustomSliderRowView(label: "收起响应时间", value: $collapseAnimationResponse, range: 0.1...1.0, specifier: "%.2f")
                        CustomSliderRowView(label: "收起阻尼系数", value: $collapseAnimationDamping, range: 0.1...1.0, specifier: "%.2f")
                    }

                    Section(header: Text("延迟时间").font(.headline)) {
                        CustomSliderRowView(label: "收起动画延迟", value: $collapseAnimationDelay, range: 0.0...1.0, specifier: "%.2f 秒")
                        CustomSliderRowView(label: "拖拽激活后收起延迟", value: $dragActivationCollapseDelay, range: 0.0...1.0, specifier: "%.2f 秒")
                    }

                    Section(header: Text("内边距").font(.headline)) {
                        CustomSliderRowView(label: "内容顶部内边距", value: $contentTopPadding, range: 0...50, specifier: "%.1f")
                        CustomSliderRowView(label: "内容底部内边距", value: $contentBottomPadding, range: 0...50, specifier: "%.1f")
                        CustomSliderRowView(label: "内容水平内边距", value: $contentHorizontalPadding, range: 0...100, specifier: "%.1f")
                        CustomSliderRowView(label: "自动展开垂直内边距", value: $autoExpandedContentVerticalPadding, range: 0...50, specifier: "%.1f")
                    }

                    Section(header: Text("模糊与阴影").font(.headline)) {
                        CustomSliderRowView(label: "小组件最大模糊半径", value: $widgetBlurRadiusMax, range: 0...100, specifier: "%.1f")
                        CustomSliderRowView(label: "实时活动最大模糊半径", value: $activityBlurRadiusMax, range: 0...100, specifier: "%.1f")
                        CustomSliderRowView(label: "展开阴影半径", value: $expandedShadowRadius, range: 0...50, specifier: "%.1f")
                        CustomSliderRowView(label: "展开阴影垂直偏移", value: $expandedShadowOffsetY, range: 0...30, specifier: "%.1f")
                    }
                }
                .padding()
            }

            Divider()

            HStack {
                Button("恢复默认") {
                    let defaultConfig = CustomizableNotchConfiguration()
                    syncState(from: defaultConfig)
                }
                Spacer()
                Button("完成") {
                    syncConfig()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(minWidth: 550, idealWidth: 600, minHeight: 400, idealHeight: 750)
    }

    private func syncState(from sourceConfig: CustomizableNotchConfiguration) {
        initialCornerRadius = Double(sourceConfig.initialCornerRadius)
        topBuffer = Double(sourceConfig.topBuffer)
        scaleFactor = Double(sourceConfig.scaleFactor)
        hoverExpandedCornerRadius = Double(sourceConfig.hoverExpandedCornerRadius)
        autoExpandedCornerRadius = Double(sourceConfig.autoExpandedCornerRadius)
        autoExpandedTallHeight = Double(sourceConfig.autoExpandedTallHeight)
        autoExpandedContentVerticalPadding = Double(sourceConfig.autoExpandedContentVerticalPadding)
        clickExpandedCornerRadius = Double(sourceConfig.clickExpandedCornerRadius)
        liveActivityBottomCornerRadius = Double(sourceConfig.liveActivityBottomCornerRadius)
        collapseAnimationDelay = sourceConfig.collapseAnimationDelay
        dragActivationCollapseDelay = sourceConfig.dragActivationCollapseDelay
        expandAnimationResponse = sourceConfig.expandAnimationResponse
        expandAnimationDamping = sourceConfig.expandAnimationDamping
        swipeOpenAnimationResponse = sourceConfig.swipeOpenAnimationResponse
        swipeOpenAnimationDamping = sourceConfig.swipeOpenAnimationDamping
        collapseAnimationResponse = sourceConfig.collapseAnimationResponse
        collapseAnimationDamping = sourceConfig.collapseAnimationDamping
        widgetBlurRadiusMax = Double(sourceConfig.widgetBlurRadiusMax)
        activityBlurRadiusMax = Double(sourceConfig.activityBlurRadiusMax)
        expandedShadowRadius = Double(sourceConfig.expandedShadowRadius)
        expandedShadowOffsetY = Double(sourceConfig.expandedShadowOffsetY)
        contentTopPadding = Double(sourceConfig.contentTopPadding)
        contentBottomPadding = Double(sourceConfig.contentBottomPadding)
        contentHorizontalPadding = Double(sourceConfig.contentHorizontalPadding)
    }

    private func syncConfig() {
        config.initialCornerRadius = CGFloat(initialCornerRadius)
        config.topBuffer = CGFloat(topBuffer)
        config.scaleFactor = CGFloat(scaleFactor)
        config.hoverExpandedCornerRadius = CGFloat(hoverExpandedCornerRadius)
        config.autoExpandedCornerRadius = CGFloat(autoExpandedCornerRadius)
        config.autoExpandedTallHeight = CGFloat(autoExpandedTallHeight)
        config.autoExpandedContentVerticalPadding = CGFloat(autoExpandedContentVerticalPadding)
        config.clickExpandedCornerRadius = CGFloat(clickExpandedCornerRadius)
        config.liveActivityBottomCornerRadius = CGFloat(liveActivityBottomCornerRadius)
        config.collapseAnimationDelay = collapseAnimationDelay
        config.dragActivationCollapseDelay = dragActivationCollapseDelay
        config.expandAnimationResponse = expandAnimationResponse
        config.expandAnimationDamping = expandAnimationDamping
        config.swipeOpenAnimationResponse = swipeOpenAnimationResponse
        config.swipeOpenAnimationDamping = swipeOpenAnimationDamping
        config.collapseAnimationResponse = collapseAnimationResponse
        config.collapseAnimationDamping = collapseAnimationDamping
        config.widgetBlurRadiusMax = CGFloat(widgetBlurRadiusMax)
        config.activityBlurRadiusMax = CGFloat(activityBlurRadiusMax)
        config.expandedShadowRadius = CGFloat(expandedShadowRadius)
        config.expandedShadowOffsetY = CGFloat(expandedShadowOffsetY)
        config.contentTopPadding = CGFloat(contentTopPadding)
        config.contentBottomPadding = CGFloat(contentBottomPadding)
        config.contentHorizontalPadding = CGFloat(contentHorizontalPadding)
    }
}

struct FileShelfSettingsView: View {
    @EditingSettings var settings: SettingsEditingSession
    private var continuity: ContinuityManager { .shared }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                Text("文件暂存架")
                    .font(.largeTitle.bold())
                    .padding(.bottom)

                VStack(alignment: .leading, spacing: 0) {
                    ToggleRow(
                        title: "悬停展开暂存架",
                        description: "将鼠标悬停在文件暂存架的实时活动上时自动展开完整视图。",
                        isOn: $settings.settings.hoverToOpenFileShelf
                    )

                    Divider().padding(.leading, 20)

                    ToggleRow(
                        title: "点击实时活动打开暂存架",
                        description: "点击文件暂存架的实时活动时直接打开暂存架，而非默认小组件。",
                        isOn: $settings.settings.clickToOpenFileShelf
                    )

                    Divider().padding(.leading, 20)

                    ToggleRow(
                        title: "拖出后自动移除文件",
                        description: "将文件从暂存架拖出后，自动从暂存架中将其移除。",
                        isOn: $settings.settings.removeFileFromShelfAfterDrag
                    )
                }
                .modifier(SettingsContainerModifier())

                SettingsCard(
                    title: "拖放目标",
                    description: "选择将文件拖入灵动岛时显示的投放目标。"
                ) {
                    ToggleRow(
                        title: "AirDrop",
                        description: "在文件暂存架投放视图中显示 AirDrop 区域。",
                        isOn: $settings.settings.fileShelfAirDropDestinationEnabled
                    )

                    Divider().padding(.leading, 20)

                    ToggleRow(
                        title: "发送到设备",
                        description: deviceDestinationDescription,
                        isOn: $settings.settings.fileShelfDeviceDestinationsEnabled
                    )
                }
            }
            .padding(25)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private var deviceDestinationDescription: String {
        let count = continuity.peers.count
        if count == 0 {
            return "从文件暂存架将文件直接拖放到已配对的跨端互通手机上。请先在「跨端互通」设置中配对设备。"
        }
        return "从文件暂存架将文件直接拖放到任意一台已配对的跨端互通设备（共 \(count) 台）。离线设备仍会保留显示。"
    }
}

struct NotesSettingsView: View {
    @EditingSettings var settings: SettingsEditingSession

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                Text("备忘录")
                    .font(.largeTitle.bold())
                    .padding(.bottom)

                VStack(alignment: .leading, spacing: 0) {
                    ToggleRow(
                        title: "启用备忘录小组件",
                        description: "在灵动岛小组件栏中显示快捷备忘录小组件。",
                        isOn: $settings.settings.notesWidgetEnabled
                    )

                    Divider().padding(.leading, 20)

                    ToggleRow(
                        title: "点击打开备忘录",
                        description: "点击备忘录小组件时展开完整的备忘录编辑器。",
                        isOn: $settings.settings.notesOpenOnClick
                    )

                    Divider().padding(.leading, 20)

                    ToggleRow(
                        title: "在灵动岛栏显示备忘录",
                        description: "在展开的灵动岛顶栏添加备忘录图标以便快速访问。",
                        isOn: $settings.settings.notesIconEnabled
                    )
                }
                .modifier(SettingsContainerModifier())

                SettingsCard(title: "滑动操作", description: "自定义在完整备忘录视图中向左或向右滑动备忘录条目时触发的操作。") {

                    SwipeActionPickerRow(
                        title: "向右滑动",
                        description: "从备忘录条目左侧向右滑动。",
                        selection: $settings.settings.swipeActionSettings.notesLeading,
                        options: NotesSwipeAction.allCases,
                        label: { $0.displayName }
                    )

                    Divider().padding(.leading, 20)

                    SwipeActionPickerRow(
                        title: "向左滑动",
                        description: "从备忘录条目右侧向左滑动。",
                        selection: $settings.settings.swipeActionSettings.notesTrailing,
                        options: NotesSwipeAction.allCases,
                        label: { $0.displayName }
                    )
                }
            }
            .padding(25)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

struct ClipboardSettingsView: View {
    @EditingSettings var settings: SettingsEditingSession
    @State private var historyCount = 0
    @ObservedObject private var shortcutRecorder = GlobalShortcutRecorder.shared
    @ObservedObject private var clipboardPickerManager = ClipboardPickerManager.shared

    private var isRecordingPickerShortcut: Bool {
        shortcutRecorder.isRecording && shortcutRecorder.recordingIdentifier == "clipboardPickerShortcut"
    }

    private var pickerShortcutLabel: String {
        let shortcut = settings.settings.clipboardPickerShortcut
        return "\(KeyboardShortcutHelper.description(for: shortcut.modifiers))\(shortcut.key)"
    }

    private var quickPickerSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            PremiumFeatureView(feature: .clipboardPicker) {
                VStack(alignment: .leading, spacing: 0) {
                    SettingsSectionHeader(title: "快捷选择器", description: "使用全局快捷键在当前输入位置旁唤出统一的 Sapphire 选择面板。选中剪贴板条目后会自动复制并粘贴到光标处；在表情符号标签页中可直接输入表情。（表情快捷键会打开同一面板并定位到表情标签页。）")

                    ToggleRow(
                        title: "启用快捷选择器",
                        description: "允许在任意位置通过全局快捷键打开剪贴板面板。",
                        isOn: $settings.settings.clipboardPickerEnabled
                    )

                    Divider().padding(.leading, 20)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("选择器快捷键")
                                .font(.system(size: 14, weight: .medium))
                            Text("替代系统默认的「粘贴并匹配样式」快捷键。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()

                        if !isRecordingPickerShortcut {
                            Text(pickerShortcutLabel)
                                .font(.caption.monospaced())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.07))
                                .clipShape(Capsule())
                        }

                        Button(isRecordingPickerShortcut ? "取消" : "录制…") {
                            if isRecordingPickerShortcut {
                                shortcutRecorder.stopRecording()
                            } else {
                                shortcutRecorder.startRecording(identifier: "clipboardPickerShortcut") { key, modifiers in
                                    settings.settings.clipboardPickerShortcut = KeyboardShortcut(key: key, modifiers: modifiers)
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(!settings.settings.clipboardPickerEnabled)
                    }
                    .padding()

                    Divider().padding(.leading, 20)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("打开选择器")
                                .font(.system(size: 14, weight: .medium))
                            Text("立即体验快捷选择器 — 将默认打开「剪贴板」标签页。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button {
                            clipboardPickerManager.presentPicker()
                        } label: {
                            Label("打开选择器", systemImage: "list.clipboard")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.mint)
                        .disabled(!settings.settings.clipboardPickerEnabled)
                    }
                    .padding()
                }
            }
        }
        .modifier(SettingsContainerModifier())
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                Text("剪贴板")
                    .font(.largeTitle.bold())
                    .padding(.bottom)

                RequiredPermissionsView(section: .clipboard)

                VStack(alignment: .leading, spacing: 0) {
                    ToggleRow(
                        title: "启用剪贴板小组件",
                        description: "在灵动岛小组件栏中显示最近的剪贴板记录。",
                        isOn: $settings.settings.clipboardWidgetEnabled
                    )

                    Divider().padding(.leading, 20)

                    ToggleRow(
                        title: "点击打开剪贴板",
                        description: "点击剪贴板小组件时展开完整的剪贴板历史记录。",
                        isOn: $settings.settings.clipboardOpenOnClick
                    )

                    Divider().padding(.leading, 20)

                    ToggleRow(
                        title: "在灵动岛栏显示剪贴板",
                        description: "在展开的灵动岛顶栏添加剪贴板图标以便快速访问。",
                        isOn: $settings.settings.clipboardIconEnabled
                    )

                    Divider().padding(.leading, 20)

                    ToggleRow(
                        title: "监听剪贴板",
                        description: "持续记录新复制的文本和图片至 Sapphire 剪贴板历史中。",
                        isOn: $settings.settings.clipboardMonitoringEnabled
                    )
                    .onChange(of: settings.settings.clipboardMonitoringEnabled) { _, enabled in
                        settings.commitNow()
                        if enabled {
                            ClipboardManager.shared.startMonitoring()
                        } else {
                            ClipboardManager.shared.stopMonitoring()
                        }
                    }
                }
                .modifier(SettingsContainerModifier())

                quickPickerSection

                VStack(alignment: .leading, spacing: 0) {
                    ToggleRow(
                        title: "无限制历史记录",
                        description: "保留所有剪贴板记录，不设条数与存储容量上限。",
                        isOn: $settings.settings.clipboardHistoryUnlimited
                    )
                    .onChange(of: settings.settings.clipboardHistoryUnlimited) { _, unlimited in
                        if unlimited {
                            settings.settings.clipboardHistoryLimit = 0
                        } else if settings.settings.clipboardHistoryLimit <= 0 {
                            settings.settings.clipboardHistoryLimit = ClipboardHistoryBudget.defaultItemLimit
                        }
                    }

                    if !settings.settings.clipboardHistoryUnlimited {
                        Divider().padding(.leading, 20)

                        CustomSliderRowView(
                            label: "历史记录上限",
                            value: Binding(
                                get: { Double(max(4, settings.settings.clipboardHistoryLimit)) },
                                set: { settings.settings.clipboardHistoryLimit = Int($0.rounded()) }
                            ),
                            range: 4...Double(ClipboardHistoryBudget.itemLimitRange.upperBound),
                            specifier: "%.0f 条"
                        )

                        Divider().padding(.leading, 20)

                        ClipboardStorageLimitRow()
                    }

                    Divider().padding(.leading, 20)

                    ClipboardIgnoredAppsRow()

                    Divider().padding(.leading, 20)

                    ToggleRow(
                        title: "忽略隐私敏感内容",
                        description: "跳过密码及其他受保护的剪贴板内容（例如来自 1Password、Bitwarden 的复制项）。",
                        isOn: $settings.settings.clipboardIgnoreConcealedItems
                    )

                    Divider().padding(.leading, 20)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("清空历史记录")
                            Text("移除已存储的 \(historyCount) 条剪贴板记录。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("清空") {
                            ClipboardManager.shared.clearHistory()
                            historyCount = 0
                        }
                        .buttonStyle(.bordered)
                        .disabled(historyCount == 0)
                    }
                    .padding()
                }
                .modifier(SettingsContainerModifier())

                SettingsCard(title: "滑动操作", description: "自定义在完整剪贴板视图中向左或向右滑动剪贴板条目时触发的操作。") {

                    SwipeActionPickerRow(
                        title: "向右滑动",
                        description: "从剪贴板条目左侧向右滑动。",
                        selection: $settings.settings.swipeActionSettings.clipboardLeading,
                        options: ClipboardSwipeAction.allCases,
                        label: { $0.displayName }
                    )

                    Divider().padding(.leading, 20)

                    SwipeActionPickerRow(
                        title: "向左滑动",
                        description: "从剪贴板条目右侧向左滑动。",
                        selection: $settings.settings.swipeActionSettings.clipboardTrailing,
                        options: ClipboardSwipeAction.allCases,
                        label: { $0.displayName }
                    )
                }

                VStack(alignment: .leading, spacing: 0) {
                    PremiumFeatureView(feature: .clipboardAdvancedTools) {
                        VStack(alignment: .leading, spacing: 0) {
                            SettingsSectionHeader(title: "自动清空剪贴板", description: "在复制满指定时长后，或在 Mac 休眠、锁定屏幕时自动清空系统剪贴板。已保存的历史记录不受影响。")

                            ToggleRow(
                                title: "启用自动清空",
                                description: "无论是否开启剪贴板历史记录均可独立生效。",
                                isOn: $settings.settings.clipboardAutoClearEnabled
                            )

                            if settings.settings.clipboardAutoClearEnabled {
                                Divider().padding(.leading, 20)

                                ToggleRow(
                                    title: "延迟自动清空",
                                    description: "复制内容经过指定时长后自动清空系统剪贴板。",
                                    isOn: Binding(
                                        get: { settings.settings.clipboardAutoClearInterval > 0 },
                                        set: { on in
                                            if on, settings.settings.clipboardAutoClearInterval <= 0 {
                                                settings.settings.clipboardAutoClearInterval = 30
                                            } else if !on {
                                                settings.settings.clipboardAutoClearInterval = 0
                                            }
                                        }
                                    )
                                )

                                if settings.settings.clipboardAutoClearInterval > 0 {
                                    Divider().padding(.leading, 20)
                                    CustomSliderRowView(
                                        label: "清空延迟",
                                        value: $settings.settings.clipboardAutoClearInterval,
                                        range: 5...300,
                                        specifier: "%.0f 秒"
                                    )
                                    .padding(.horizontal)
                                }

                                Divider().padding(.leading, 20)
                                ToggleRow(
                                    title: "Mac 休眠时清空",
                                    description: "当 Mac（或显示器）进入休眠时清空剪贴板。",
                                    isOn: $settings.settings.clipboardAutoClearOnSleep
                                )

                                Divider().padding(.leading, 20)
                                ToggleRow(
                                    title: "锁定屏幕时清空",
                                    description: "当屏幕锁定时清空剪贴板。",
                                    isOn: $settings.settings.clipboardAutoClearOnLock
                                )
                            }
                        }
                    }
                }
                .modifier(SettingsContainerModifier())

                VStack(alignment: .leading, spacing: 0) {
                    PremiumFeatureView(feature: .clipboardAdvancedTools) {
                        VStack(alignment: .leading, spacing: 0) {
                            SettingsSectionHeader(title: "净化链接", description: "自动剔除所复制链接中的追踪参数（如 utm_*、fbclid、gclid 等）。图片、文件与富文本内容保持原样不受影响。")

                            ToggleRow(
                                title: "净化复制的链接",
                                description: "去除复制链接中的追踪参数并重写为纯净网址。",
                                isOn: $settings.settings.clipboardCleanURLEnabled
                            )

                            if settings.settings.clipboardCleanURLEnabled {
                                Divider().padding(.leading, 20)
                                ToggleRow(
                                    title: "复制时自动净化",
                                    description: "复制链接时立即自动净化；关闭后仅在选择器中手动触发净化。",
                                    isOn: $settings.settings.clipboardCleanURLAutoClean
                                )

                                Divider().padding(.leading, 20)
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("净化当前剪贴板链接")
                                        Text("立即剔除您最近一次复制的链接中的追踪参数。")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Button("立即净化") { CleanURLManager.shared.cleanClipboardLinkNow() }
                                        .buttonStyle(.bordered)
                                }
                                .padding()
                            }
                        }
                    }
                }
                .modifier(SettingsContainerModifier())

                VStack(alignment: .leading, spacing: 0) {
                    PremiumFeatureView(feature: .clipboardAdvancedTools) {
                        VStack(alignment: .leading, spacing: 0) {
                            SettingsSectionHeader(title: "访达剪切与粘贴", description: "先按 ⌘X 再按 ⌘V 可移动文件而非复制；按 ⌘V 可将已复制的图片直接粘贴为 PNG 文件至当前访达文件夹；按 F2 可重命名所选项目。")

                            ToggleRow(
                                title: "启用访达增强快捷键",
                                description: "仅在访达处于最前台时生效。",
                                isOn: $settings.settings.clipboardFinderCutPasteEnabled
                            )

                            if settings.settings.clipboardFinderCutPasteEnabled {
                                Divider().padding(.leading, 20)
                                ToggleRow(
                                    title: "将图片粘贴为 PNG 文件",
                                    description: "在访达中按 ⌘V 可将剪贴板中的图片保存为当前文件夹下的 PNG 文件。",
                                    isOn: $settings.settings.clipboardFinderPasteImagesAsPNG
                                )

                                Divider().padding(.leading, 20)
                                ToggleRow(
                                    title: "按 F2 重命名所选项",
                                    description: "在访达中按 F2 键即可直接重命名选中项目。",
                                    isOn: $settings.settings.clipboardFinderF2RenameEnabled
                                )
                            }
                        }
                    }
                }
                .modifier(SettingsContainerModifier())

                VStack(alignment: .leading, spacing: 0) {
                    PremiumFeatureView(feature: .clipboardAdvancedTools) {
                        VStack(alignment: .leading, spacing: 0) {
                            SettingsSectionHeader(title: "文本片段", description: "在任意位置输入简短触发词即可自动替换为完整文本。替换内容中可使用 \"{{date}}\"、\"{{time}}\"、\"{{date:MMMM d}}\" 或 \"{{clipboard}}\" 动态变量。在 Sapphire 自身窗口内输入时不会触发展开。")

                            ToggleRow(
                                title: "启用文本片段",
                                description: "在任意应用中输入触发词时自动展开为预设文本。",
                                isOn: $settings.settings.snippetsEnabled
                            )

                            if settings.settings.snippetsEnabled {
                                Divider().padding(.leading, 20)
                                ToggleRow(
                                    title: "输入空格或标点后展开",
                                    description: "关闭后将在输完触发词的瞬间立即展开。",
                                    isOn: $settings.settings.snippetsExpandAfterSpace
                                )

                                Divider().padding(.leading, 20)
                                HStack {
                                    Text("片段列表").font(.subheadline).foregroundStyle(.secondary)
                                    Spacer()
                                    Button {
                                        settings.settings.snippetsList.append(SnippetEntry())
                                    } label: {
                                        Label("添加片段", systemImage: "plus.circle")
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .padding(.horizontal)

                                ForEach($settings.settings.snippetsList) { $snippet in
                                    Divider().padding(.leading, 20)
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(spacing: 8) {
                                            Toggle("", isOn: $snippet.isEnabled)
                                                .toggleStyle(.switch)
                                                .controlSize(.small)
                                            TextField("触发词", text: $snippet.trigger)
                                                .textFieldStyle(.roundedBorder)
                                                .frame(width: 150)
                                            Spacer()
                                            Button {
                                                let doomed = snippet.id
                                                DispatchQueue.main.async {
                                                    settings.settings.snippetsList.removeAll { $0.id == doomed }
                                                }
                                            } label: {
                                                Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                                            }
                                            .buttonStyle(.borderless)
                                        }
                                        TextField("替换文本…", text: $snippet.replacement, axis: .vertical)
                                            .textFieldStyle(.roundedBorder)
                                            .lineLimit(1...4)
                                    }
                                    .padding(.horizontal)
                                }

                                if settings.settings.snippetsList.isEmpty {
                                    Text("暂无文本片段 — 添加一条后，在任意应用中输入其触发词即可快速展开。")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                        .padding(.horizontal)
                                        .padding(.bottom, 6)
                                }
                            }
                        }
                    }
                }
                .modifier(SettingsContainerModifier())
            }
            .padding(25)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onAppear { historyCount = ClipboardManager.shared.recentItems.count }
    }
}

struct MirrorSettingsView: View {
    @EditingSettings var settings: SettingsEditingSession

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                Text("随身镜")
                    .font(.largeTitle.bold())
                    .padding(.bottom)

                VStack(alignment: .leading, spacing: 0) {
                    ToggleRow(
                        title: "启用随身镜小组件",
                        description: "在灵动岛小组件栏中显示实时摄像头画面小组件。",
                        isOn: $settings.settings.mirrorWidgetEnabled
                    )

                    Divider().padding(.leading, 20)

                    ToggleRow(
                        title: "点击打开随身镜",
                        description: "点击随身镜小组件时展开完整的摄像头预览画面。",
                        isOn: $settings.settings.mirrorOpenOnClick
                    )

                    Divider().padding(.leading, 20)

                    ToggleRow(
                        title: "水平镜像翻转",
                        description: "将摄像头画面水平翻转，呈现自然的自拍镜像视角。",
                        isOn: $settings.settings.mirrorFlipHorizontally
                    )

                    Divider().padding(.leading, 20)

                    HStack {
                        Text("画面旋转角度")
                        Spacer()
                        Picker("", selection: $settings.settings.mirrorRotationMode) {
                            ForEach(MirrorRotationMode.allCases) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 130)
                    }
                    .padding()

                    Text("默认自动匹配摄像头报告的朝向。若外接摄像头画面方向有误，可选择固定旋转角度以正立显示。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 5)
                }
                .modifier(SettingsContainerModifier())
            }
            .padding(25)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

struct CaffeineSettingsView: View {
    @EditingSettings var settings: SettingsEditingSession

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                Text("保持唤醒")
                    .font(.largeTitle.bold())
                    .padding(.bottom)

                VStack(alignment: .leading, spacing: 0) {
                    ToggleRow(
                        title: "在灵动岛栏显示保持唤醒",
                        description: "在展开的灵动岛顶栏添加保持唤醒开关。关闭此项后，也将不再因后台任务、特定应用、电源连接或外接显示器而自动开启保持唤醒。",
                        isOn: $settings.settings.caffeinateEnabled
                    )

                    Divider().padding(.leading, 20)

                    ToggleRow(
                        title: "合盖模式下阻止休眠",
                        description: "当 Sapphire 的保持唤醒模式处于开启状态时，即使合上屏幕盖也保持 Mac 唤醒。",
                        isOn: $settings.settings.sleepInClamshell
                    )

                    Divider().padding(.leading, 20)

                    ToggleRow(
                        title: "退出合盖模式后维持唤醒",
                        description: "退出合盖模式后继续保持阻止休眠，而非自动关闭保持唤醒。",
                        isOn: $settings.settings.persistentCaffeinateAfterClamshell
                    )

                    Divider().padding(.leading, 20)

                    HStack {
                        Text("自动关闭倒计时")
                        Spacer()
                        Picker("", selection: $settings.settings.caffeinateTimeoutMinutes) {
                            Text("从不").tag(0.0)
                            Text("15 分钟").tag(15.0)
                            Text("30 分钟").tag(30.0)
                            Text("1 小时").tag(60.0)
                            Text("2 小时").tag(120.0)
                            Text("4 小时").tag(240.0)
                        }
                        .labelsHidden()
                        .frame(width: 140)
                    }
                    .padding()

                    Text("达到所选时长后自动关闭保持唤醒。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 10)
                }
                .modifier(SettingsContainerModifier())

                CaffeineAutoTaskSettingsView()

                KeepAwakeTriggerSettingsView()

                LidAngleCaffeineSettingsView()
            }
            .padding(25)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

struct WidgetsSettingsView: View {
    @EditingSettings var settings: SettingsEditingSession
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    private var enabledWidgetCount: Int {
        settings.settings.enabledWidgetTypes.count
    }

    var body: some View {
        let lockedWidgetTypes = Set(WidgetType.allCases.filter { type in
            type.requiredPremiumFeature
                .map { !subscriptionManager.hasAccess(to: $0) } ?? false
        })

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                Text("小组件").font(.largeTitle.bold()).padding(.bottom)

                VStack(alignment: .leading, spacing: 0) {
                    Text("交互行为").font(.headline).padding([.top, .horizontal])
                    ToggleRow(
                        title: "记住上次打开的页面",
                        description: "重新展开灵动岛时，自动回到您上次打开的菜单页面。",
                        isOn: $settings.settings.rememberLastMenu
                    )
                    Divider().padding(.leading, 20)
                    ToggleRow(title: "未播放时隐藏音乐小组件", description: "当前没有媒体正在播放时隐藏音乐小组件。", isOn: $settings.settings.hideMusicWidgetWhenNotPlaying)
                    ToggleRow(title: "隐藏已暂停的 Spotify 曲目", description: "当 Spotify 处于暂停状态且无其他系统媒体播放时隐藏音乐小组件。", isOn: $settings.settings.hideMusicWidgetWhenSpotifyPausedAndIdle)
                    ToggleRow(title: "Spotify 关闭时隐藏小组件", description: "对于已登录的 Spotify 账号，当此 Mac 未运行 Spotify 且无其他媒体播放源时隐藏音乐小组件。", isOn: $settings.settings.hideSpotifyWidgetWhenAppClosed)
                    ToggleRow(title: "常驻显示音乐小组件", description: "即使播放已暂停或停止，仍保留音乐小组件并显示上一首曲目。", isOn: $settings.settings.persistMusicWidgetWhenPaused)
                }
                .modifier(SettingsContainerModifier())

                VStack(alignment: .leading, spacing: 0) {
                    Text("外观显示").font(.headline).padding([.top, .horizontal])
                    ToggleRow(title: "在小组件之间显示分隔线", description: "在各个小组件之间显示柔和的细分隔线。", isOn: $settings.settings.showDividersBetweenWidgets)
                    ToggleRow(
                        title: "忽略小组件空间限制",
                        description: "即使 Sapphire 估算灵动岛横向空间不足，也允许强行启用任意小组件。",
                        isOn: $settings.settings.bypassWidgetSpaceLimit
                    )
                }
                .modifier(SettingsContainerModifier())

                if settings.settings.shopifyWidgetEnabled {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Shopify 订单").font(.headline).padding([.horizontal, .top])
                        Text("连接具备 read_orders 权限的 Shopify 自定义应用。Admin API 访问令牌将安全存储在 macOS 钥匙串中。").font(.caption).foregroundColor(.secondary).padding(.horizontal)
                        TextField("店铺域名（如 example.myshopify.com）", text: Binding(get: { APIKeyManager.shared.shopifyStoreDomain }, set: { APIKeyManager.shared.shopifyStoreDomain = $0 })).textFieldStyle(.roundedBorder).padding(.horizontal)
                        SecureField("Admin API 访问令牌", text: Binding(get: { APIKeyManager.shared.shopifyAdminToken }, set: { APIKeyManager.shared.shopifyAdminToken = $0 })).textFieldStyle(.roundedBorder).padding(.horizontal)
                        Text("请前往 Shopify 后台 → 设置 → 应用和销售渠道 → 开发应用 创建，并勾选 read_orders 权限。").font(.caption2).foregroundColor(.secondary).padding(.horizontal).padding(.bottom)
                    }
                    .modifier(SettingsContainerModifier())
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("小组件显示与排序").font(.headline).padding([.horizontal, .top])
                    Text("启用、停用并拖动排序在灵动岛中显示的小组件。可同时显示的数量受显示器宽度限制。")
                        .font(.caption).foregroundColor(.secondary).padding(.horizontal).padding(.bottom, 5)
                    ReorderableVStack(items: $settings.settings.widgetOrder) { widget in
                        if widget != .agent {
                            WidgetRowView(
                                widgetType: widget,
                                enabledWidgetCount: enabledWidgetCount,
                                isPremiumLocked: lockedWidgetTypes.contains(widget)
                            )
                        }
                    }
                    .modifier(SettingsContainerModifier())
                }
            }
            .padding(25)
        }
    }
}

struct LiveActivitiesSettingsView: View {
    @EditingSettings var settings: SettingsEditingSession
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @State private var availableSensors: [any Sensor_p] = []

    private enum PersistentActivitySelection: String, CaseIterable, Identifiable {
        case none = "None"
        case stats = "Stats"
        case battery = "Battery"
        case weather = "Weather"
        var id: String { self.rawValue }
        var title: String {
            switch self {
            case .none: return "无"
            case .stats: return "系统监控"
            case .battery: return "电池"
            case .weather: return "天气"
            }
        }
    }

    private var currentPersistentActivity: PersistentActivitySelection {
        if settings.settings.showPersistentStatsLiveActivity {
            return .stats
        } else if settings.settings.showPersistentBatteryLiveActivity {
            return .battery
        } else if settings.settings.showPersistentWeatherLiveActivity {
            return .weather
        } else {
            return .none
        }
    }

    private var persistentActivityBinding: Binding<PersistentActivitySelection> {
        Binding(
            get: { currentPersistentActivity },
            set: { newValue in
                guard currentPersistentActivity != newValue else { return }
                var updated = settings.settings.value
                updated.showPersistentStatsLiveActivity = (newValue == .stats)
                updated.showPersistentBatteryLiveActivity = (newValue == .battery)
                updated.showPersistentWeatherLiveActivity = (newValue == .weather)
                settings.settings.value = updated
            }
        )
    }

    private func binding(for statType: StatType) -> Binding<StatThreshold> {
        return Binding(
            get: { settings.settings.statThresholds[statType, default: StatThreshold()] },
            set: { settings.settings.statThresholds[statType] = $0 }
        )
    }

    var body: some View {
        let lockedActivityTypes = Set(LiveActivityType.allCases.filter { type in
            type.requiredPremiumFeature
                .map { !subscriptionManager.hasAccess(to: $0) } ?? false
        })

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                Text("实时活动").font(.largeTitle.bold()).padding(.bottom)
                VStack(alignment: .leading, spacing: 0) {
                    Text("常规行为").font(.headline).padding([.top, .horizontal])
                    ToggleRow(
                          title: "显示紧凑专注模式文本",
                          description: "在专注模式实时活动中仅显示开启/关闭状态，而非完整的专注模式名称。",
                          isOn: Binding(
                              get: { settings.settings.focusDisplayMode == .compact },
                              set: { settings.settings.focusDisplayMode = $0 ? .compact : .full }
                          )
                      )

                    ToggleRow(
                          title: "显示紧凑电池实时活动",
                          description: "仅显示电池图标，不展开完整电量状态文本。",
                          isOn: Binding(
                            get: { settings.settings.batteryNotificationStyle == .compact },
                            set: { settings.settings.batteryNotificationStyle = $0 ? .compact : .default }
                          )
                      )
                    ToggleRow(title: "下滑关闭实时活动", description: "在实时活动上下滑即可将其关闭。", isOn: $settings.settings.swipeToDismissLiveActivity)
                    Divider().padding(.leading, 20)
                    ToggleRow(
                        title: "来源应用处于前台时隐藏",
                        description: "当 Spotify 或 Apple Music 处于最前台时，自动隐藏音乐实时活动。",
                        isOn: $settings.settings.hideLiveActivityWhenSourceActive
                    )
                    Divider().padding(.leading, 20)
                    ToggleRow(
                        title: "悬停时保持临时实时活动紧凑",
                        description: "显示临时实时活动期间，鼠标悬停不自动展开灵动岛。常驻活动、音乐、天气、系统监控及开发者活动不受此限。",
                        isOn: $settings.settings.suppressHoverExpansionForTransientLiveActivities
                    )
                    Divider().padding(.leading, 20)
                    ToggleRow(
                        title: "在灵动岛旁显示伴随挂件",
                        description: "当有多个实时活动同时运行时，排在首位之后的活动会像灵动岛伴随挂件一样以小气泡形式悬浮在灵动岛两侧，点击气泡即可打开。",
                        isOn: $settings.settings.showLiveActivitySatellites
                    )
                    if settings.settings.showLiveActivitySatellites {
                        Divider().padding(.leading, 20)
                        HStack {
                            SettingsRowLabel(
                                title: "伴随挂件数量上限",
                                description: "最多同时显示的伴随挂件气泡数量。前两个分别位于灵动岛左右两侧，更多气泡将依次向外排列。"
                            )
                            Spacer()
                            Stepper(value: $settings.settings.liveActivitySatelliteLimit, in: 1...5) {
                                Text("\(settings.settings.liveActivitySatelliteLimit)")
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            }
                        }
                        .padding()
                    }

                }
                .modifier(SettingsContainerModifier())

                VStack(alignment: .leading, spacing: 0) {
                    Text("常驻实时活动").font(.headline).padding([.top, .horizontal])

                    InfoContainer(
                        text: "选择一项实时活动，在没有其他更高优先级活动运行时常驻显示。",
                        iconName: "pin.circle.fill",
                        color: .blue
                    ).padding()

                    HStack {
                        Text("常驻实时活动")
                        Spacer()
                        Picker("常驻实时活动", selection: persistentActivityBinding) {
                            ForEach(PersistentActivitySelection.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                        .labelsHidden()
                    }
                    .padding()

                    if currentPersistentActivity == .stats && !settings.settings.statsLiveActivityEnabled {
                        InfoContainer(text: "请先在下方启用「系统监控」实时活动，才能将其设为常驻显示。", iconName: "info.circle", color: .yellow)
                            .padding([.horizontal, .bottom])
                    } else if currentPersistentActivity == .weather && !settings.settings.weatherLiveActivityEnabled {
                        InfoContainer(text: "请先在下方启用「天气」实时活动，才能将其设为常驻显示。", iconName: "info.circle", color: .yellow)
                            .padding([.horizontal, .bottom])
                    } else if currentPersistentActivity == .battery && !settings.settings.batteryLiveActivityEnabled {
                        InfoContainer(text: "请先在下方启用「电池」实时活动，才能将其设为常驻显示。", iconName: "info.circle", color: .yellow)
                            .padding([.horizontal, .bottom])
                    }

                    Divider().padding(.leading, 20)

                    HStack {
                        Text("天气实时活动弹出间隔")
                        Spacer()
                        Picker("", selection: $settings.settings.weatherLiveActivityInterval) {
                            Text("5 分钟").tag(5); Text("10 分钟").tag(10); Text("15 分钟").tag(15); Text("30 分钟").tag(30)
                        }.labelsHidden()
                    }
                    .padding()
                    .disabled(currentPersistentActivity == .weather)
                    .opacity(currentPersistentActivity == .weather ? 0.5 : 1.0)
                }
                .modifier(SettingsContainerModifier())
                .animation(.default, value: currentPersistentActivity)

                if settings.settings.statsLiveActivityEnabled {
                    SensorSelectionView(
                        selectedStats: $settings.settings.selectedStats,
                        selectedSensorKeys: $settings.settings.selectedSensorKeys,
                        allSensors: availableSensors
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))

                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $settings.settings.statsLiveActivityThresholdEnabled) {
                            Text("仅在高负载时显示")
                                .font(.headline)
                        }
                        .padding()
                        .toggleStyle(.switch)

                        if settings.settings.statsLiveActivityThresholdEnabled {
                            VStack(alignment: .leading, spacing: 15) {
                                StatThresholdRow(label: "CPU", threshold: binding(for: .cpu))
                                StatThresholdRow(label: "内存", threshold: binding(for: .ram))
                                StatThresholdRow(label: "GPU", threshold: binding(for: .gpu))
                            }
                            .padding()
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding()
                    .modifier(SettingsContainerModifier())
                    .animation(.easeInOut, value: settings.settings.statsLiveActivityThresholdEnabled)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("实时活动显示与排序").font(.headline).padding([.horizontal, .top])
                    Text("启用、停用并拖动排序所有可用的实时活动。").font(.caption).foregroundColor(.secondary).padding(.horizontal).padding(.bottom, 5)
                    if settings.settings.statsLiveActivityEnabled {
                        InfoContainer(text: "启用系统监控实时活动会增加应用的 CPU 占用与电量消耗。", iconName: "info.circle", color: .yellow)
                    }
                    ReorderableVStack(items: $settings.settings.liveActivityOrder) { activity in
                        LiveActivityRowView(
                            activityType: activity,
                            isPremiumLocked: lockedActivityTypes.contains(activity)
                        )
                    }
                    .modifier(SettingsContainerModifier())
                }
                .onChange(of: settings.settings.eyeBreakLiveActivityEnabled) {
                    EyeBreakManager.shared.dismissBreak()
                }

                RequiredPermissionsView(section: .liveActivities)
            }
            .padding(25)
            .animation(.default, value: settings.settings.statsLiveActivityEnabled)
        }
        .onAppear {
            availableSensors = StatsManager.shared.allSensors
            StatsManager.shared.requestSensorCatalog()
        }
        .onReceive(StatsManager.shared.$allSensors.dropFirst()) { catalog in
            availableSensors = catalog
        }
        .onDisappear {
            availableSensors = []
        }
    }
}

struct StatThresholdRow: View {
    let label: String
    @Binding var threshold: StatThreshold

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $threshold.isEnabled) {
                Text(label)
            }
            .toggleStyle(.switch)

            if threshold.isEnabled {
                HStack {
                    Text("触发阈值")
                        .foregroundColor(.secondary)
                    Spacer()
                    Stepper(
                        "\(threshold.value)%",
                        value: $threshold.value,
                        in: 1...100,
                        step: 5
                    )
                }
                .padding(.leading, 20)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: threshold.isEnabled)
    }
}

fileprivate struct SensorSelectionView: View {
    @Binding var selectedStats: [StatType]
    @Binding var selectedSensorKeys: [String]
    let allSensors: [any Sensor_p]

    private var groupedSensors: [SensorGroup: [any Sensor_p]] {
        Dictionary(grouping: allSensors, by: { $0.group })
    }

    private func localizedSensorGroupTitle(_ raw: String) -> String {
        switch raw {
        case "CPU": return "CPU"
        case "GPU": return "GPU"
        case "Memory", "RAM": return "内存"
        case "Battery": return "电池"
        case "Power": return "功耗与电源"
        case "Thermal", "Temperature", "Temperatures": return "温度"
        case "Voltage", "Voltages": return "电压"
        case "Current", "Currents": return "电流"
        case "Fan", "Fans": return "风扇"
        case "Disk", "Storage": return "磁盘存储"
        case "Network": return "网络"
        case "System": return "系统"
        case "Other": return "其他"
        case "Sensors": return "传感器"
        default: return raw
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("系统监控配置").font(.headline).padding([.top, .horizontal])

            DisclosureGroup("选择概览指标") {
                VStack(spacing: 0) {
                    ForEach(StatType.allCases) { statType in
                        Toggle(statType.displayName, isOn: Binding<Bool>(
                            get: { selectedStats.contains(statType) },
                            set: { isSelected in
                                if isSelected {
                                    if !selectedStats.contains(statType) {
                                        selectedStats.append(statType)
                                    }
                                } else {
                                    selectedStats.removeAll { $0 == statType }
                                }
                            }
                        ))
                        .padding(.vertical, 8)
                    }
                }
                .padding(.top, 10)
            }
            .padding()

            Divider().padding(.horizontal)

            DisclosureGroup("选择单项硬件传感器") {
                if allSensors.isEmpty {
                    VStack {
                        ProgressView()
                        Text("正在加载传感器…")
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                    .frame(height: 300)
                    .frame(maxWidth: .infinity)
                } else {
                    List {
                        ForEach(SensorGroup.allCases, id: \.self) { group in
                            if let groupSensors = groupedSensors[group], !groupSensors.isEmpty {
                                Section(header: Text(localizedSensorGroupTitle(group.rawValue)).font(.headline)) {
                                    ForEach(groupSensors, id: \.key) { sensor in
                                        Toggle(sensor.name, isOn: Binding<Bool>(
                                            get: { selectedSensorKeys.contains(sensor.key) },
                                            set: { isSelected in
                                                if isSelected {
                                                    if !selectedSensorKeys.contains(sensor.key) {
                                                        selectedSensorKeys.append(sensor.key)
                                                    }
                                                } else {
                                                    selectedSensorKeys.removeAll { $0 == sensor.key }
                                                }
                                            }
                                        ))
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.sidebar)
                    .frame(height: 300)
                }
            }
            .padding()
        }
        .modifier(SettingsContainerModifier())
    }
}

struct ShortcutsSettingsView: View {
    @EditingSettings var settings: SettingsEditingSession
    @StateObject private var fetcher = ShortcutsFetcher()
    @State private var searchText: String = ""

    private var filteredAvailableShortcuts: [ShortcutInfo] {
        let selectedIDs = Set(settings.settings.selectedShortcuts.map { $0.id })
        let available = fetcher.allShortcuts.filter { !selectedIDs.contains($0.id) }

        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return available
        }

        return available.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                Text("快捷指令小组件")
                    .font(.largeTitle.bold())
                    .padding(.bottom)

                VStack(alignment: .leading, spacing: 10) {
                    Text("已添加至小组件")
                        .font(.headline)
                        .padding(.horizontal)

                    VStack {
                        if settings.settings.selectedShortcuts.isEmpty {
                            Text("暂未添加快捷指令。")
                                .font(.caption).foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
                        } else {
                            let rowHeight: CGFloat = 44
                            List {
                                ForEach($settings.settings.selectedShortcuts) { $shortcut in
                                    AddedShortcutRow(shortcut: $shortcut, onRemove: {
                                        removeShortcut(shortcut)
                                    })
                                }
                                .listRowBackground(Color.clear)
                            }
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                            .frame(height: CGFloat(settings.settings.selectedShortcuts.count) * rowHeight)
                        }
                    }
                }
                .padding(.vertical)
                .modifier(SettingsContainerModifier())

                VStack(alignment: .leading, spacing: 10) {
                    Text("可用快捷指令")
                        .font(.headline).padding(.horizontal)

                    TextField("搜索快捷指令", text: $searchText)
                        .textFieldStyle(.plain).padding(8)
                        .background(Color.black.opacity(0.2)).clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal)

                    if fetcher.isLoading {
                        ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                    } else if let error = fetcher.accessError {
                         InfoContainer(text: error, iconName: "exclamationmark.triangle.fill", color: .yellow)
                            .padding(.horizontal)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                if filteredAvailableShortcuts.isEmpty {
                                    Text(searchText.isEmpty ? "未找到任何快捷指令。" : "没有匹配的快捷指令。")
                                        .font(.caption).foregroundColor(.secondary).padding()
                                } else {
                                    ForEach(filteredAvailableShortcuts) { shortcut in
                                        AvailableShortcutRow(shortcut: shortcut, onAdd: { addShortcut(shortcut) })
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 350)
                    }
                }
                .padding(.vertical)
                .modifier(SettingsContainerModifier())
            }
            .padding(25)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onAppear(perform: fetcher.fetchAllShortcuts)
            .onDisappear {
                fetcher.releaseLoadedShortcuts()
            }
        }
    }

    private func addShortcut(_ shortcut: ShortcutInfo) {
        if !settings.settings.selectedShortcuts.contains(where: { $0.id == shortcut.id }) {
            settings.settings.selectedShortcuts.append(shortcut)
        }
    }

    private func removeShortcut(_ shortcutToRemove: ShortcutInfo) {
        settings.settings.selectedShortcuts.removeAll { $0.id == shortcutToRemove.id }
    }
}

fileprivate struct AddedShortcutRow: View {
    @Binding var shortcut: ShortcutInfo
    let onRemove: () -> Void
    @State private var isShowingEditor = false

    var body: some View {
        HStack(spacing: 12) {
            Button(action: { isShowingEditor = true }) {
                Image(nsImage: ShortcutsManager.shared.getIcon(for: shortcut))
                    .resizable().frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .id(shortcut)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isShowingEditor, arrowEdge: .leading) {
                ShortcutEditorView(shortcut: $shortcut)
            }

            Text(shortcut.name)
            Spacer()

            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.red.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
    }
}

fileprivate struct AvailableShortcutRow: View {
    let shortcut: ShortcutInfo
    let onAdd: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: onAdd) {
            HStack(spacing: 12) {
                Image(nsImage: ShortcutsManager.shared.getIcon(for: shortcut))
                    .resizable().frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Text(shortcut.name)
                    .foregroundColor(isEnabled ? .primary : .secondary)
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(isEnabled ? .green.opacity(0.8) : .secondary)
            }
        }
        .buttonStyle(.plain)
        .padding(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
    }
}

fileprivate struct ShortcutEditorView: View {
    @Binding var shortcut: ShortcutInfo
    @State private var isShowingIconPicker = false

    private var backgroundColorBinding: Binding<Color> {
        Binding(
            get: { shortcut.backgroundColor?.color ?? .gray },
            set: { shortcut.backgroundColor = CodableColor(color: $0) }
        )
    }

    private var iconColorBinding: Binding<Color> {
        Binding(
            get: { shortcut.iconColor?.color ?? .white },
            set: { shortcut.iconColor = CodableColor(color: $0) }
        )
    }

    var body: some View {
        VStack(spacing: 15) {
            Text("编辑快捷指令外观")
                .font(.headline)

            Image(nsImage: ShortcutsManager.shared.getIcon(for: shortcut))
                .resizable()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 18))

            VStack(spacing: 10) {
                ColorPicker("背景颜色", selection: backgroundColorBinding, supportsOpacity: false)
                ColorPicker("图标颜色", selection: iconColorBinding, supportsOpacity: false)

                Button("更换图标") {
                    isShowingIconPicker = true
                }
            }
        }
        .padding()
        .frame(width: 250)
        .background(.ultraThinMaterial)
        .sheet(isPresented: $isShowingIconPicker) {
            IconPickerView { selectedSymbol in
                shortcut.systemImageName = selectedSymbol
            }
        }
    }
}

fileprivate struct IconPickerView: View {
    let onSelect: (String) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var searchText = ""
    @State private var isSearchVisible = false

    struct IconSection: Identifiable {
        let id = UUID()
        let title: String
        let symbols: [String]
    }

    static let iconSections: [IconSection] = [
        IconSection(title: "界面与常规", symbols: [
            "house.fill", "house", "gearshape.fill", "gearshape", "gearshape.2.fill", "gearshape.2",
            "slider.horizontal.3", "slider.vertical.3", "ellipsis", "ellipsis.circle.fill", "ellipsis.circle",
            "plus", "plus.circle.fill", "plus.circle", "minus", "minus.circle.fill", "minus.circle",
            "xmark", "xmark.circle.fill", "xmark.circle", "checkmark", "checkmark.circle.fill", "checkmark.circle",
            "questionmark.circle.fill", "questionmark.circle", "info.circle.fill", "info.circle",
            "magnifyingglass", "link", "link.circle.fill", "link.circle", "lock.fill", "lock.open.fill",
            "key.fill", "key", "bell.fill", "bell", "bell.slash.fill", "bell.slash",
            "lightbulb.fill", "lightbulb", "flag.fill", "flag", "bookmark.fill", "bookmark",
            "tag.fill", "tag", "pin.fill", "pin", "archivebox.fill", "archivebox",
            "square.and.arrow.up", "square.and.arrow.down", "arrow.clockwise", "arrow.counterclockwise",
            "gobackward", "goforward", "eject.fill", "eject", "power", "power.circle.fill", "power.circle",
            "app.fill", "app", "window.vertical.closed", "macwindow", "sidebar.left", "sidebar.right",
            "dock.rectangle", "ruler.fill", "ruler", "screwdriver.fill", "screwdriver", "hammer.fill", "hammer",
            "wrench.and.screwdriver.fill", "wrench.and.screwdriver", "eyedropper", "eyedropper.halffull",
            "paintpalette.fill", "paintpalette", "crop", "rotate.right.fill", "rotate.left.fill",
            "sparkle", "sparkles", "star.fill", "star", "heart.fill", "heart",
            "eye.fill", "eye", "eye.slash.fill", "eye.slash", "viewfinder",
            "camera.macro.circle.fill", "camera.macro.circle", "camera.macro",
            "trash.fill", "trash", "square.grid.2x2.fill", "square.grid.2x2", "list.bullet", "list.number",
            "list.dash", "list.clipboard.fill", "list.clipboard"
        ]),

        IconSection(title: "文件与文档", symbols: [
            "folder.fill", "folder", "folder.circle.fill", "folder.circle", "folder.badge.plus",
            "folder.badge.minus", "folder.badge.person.crop", "folder.badge.questionmark",
            "doc.fill", "doc", "doc.text.fill", "doc.text", "doc.plaintext.fill", "doc.plaintext",
            "doc.richtext.fill", "doc.richtext", "doc.on.doc.fill", "doc.on.doc",
            "doc.on.clipboard.fill", "doc.on.clipboard", "doc.badge.plus", "doc.badge.gearshape.fill",
            "doc.badge.gearshape", "doc.badge.clock.fill", "doc.badge.clock",
            "doc.badge.ellipsis",
            "archivebox.fill", "archivebox", "paperclip", "note.text",
            "note.text.badge.plus", "newspaper.fill", "newspaper", "book.fill", "book", "books.vertical.fill",
            "books.vertical", "scroll.fill", "scroll", "receipt.fill", "receipt",
            "list.bullet.rectangle.portrait.fill", "list.bullet.rectangle.portrait", "text.magnifyingglass",
            "signature", "square.and.pencil", "square.and.pencil.circle.fill", "square.and.pencil.circle",
            "photo.stack.fill", "photo.stack", "square.stack.3d.up.fill", "square.stack.3d.up",
            "square.stack.3d.down.right.fill", "square.stack.3d.down.right",
            "square.stack.3d.up.slash.fill", "square.stack.3d.up.slash",
            "doc.questionmark", "doc.questionmark.fill", "doc.append", "doc.fill.badge.plus",
            "doc.text.image.fill", "doc.text.image", "doc.badge.arrow.up.fill", "doc.badge.arrow.up"
        ]),

        IconSection(title: "文本与编辑", symbols: [
            "pencil", "pencil.circle", "pencil.circle.fill", "eraser.fill", "eraser", "highlighter", "scissors",
            "textformat", "textformat.size", "textformat.abc", "textformat.123",
            "bold", "italic", "underline", "strikethrough", "paragraphsign",
            "text.alignleft", "text.aligncenter", "text.alignright", "text.justify",
            "increase.indent", "decrease.indent", "list.bullet.indent", "quotelevel", "text.bubble.fill",
            "text.bubble", "return", "line.diagonal", "curlybraces",
            "point.topleft.down.curvedto.point.bottomright.up.fill",
            "a.circle.fill", "a.circle", "b.circle.fill", "b.circle", "c.circle.fill", "c.circle",
            "d.circle.fill", "d.circle", "e.circle.fill", "e.circle", "f.circle.fill", "f.circle",
            "g.circle.fill", "g.circle", "h.circle.fill", "h.circle", "i.circle.fill", "i.circle",
            "j.circle.fill", "j.circle", "k.circle.fill", "k.circle", "l.circle.fill", "l.circle",
            "m.circle.fill", "m.circle", "n.circle.fill", "n.circle", "o.circle.fill", "o.circle",
            "p.circle.fill", "p.circle", "q.circle.fill", "q.circle", "r.circle.fill", "r.circle",
            "s.circle.fill", "s.circle", "t.circle.fill", "t.circle", "u.circle.fill", "u.circle",
            "v.circle.fill", "v.circle", "w.circle.fill", "w.circle", "x.circle.fill", "x.circle",
            "y.circle.fill", "y.circle", "z.circle.fill", "z.circle",
            "0.circle.fill", "0.circle", "1.circle.fill", "1.circle", "2.circle.fill", "2.circle",
            "3.circle.fill", "3.circle", "4.circle.fill", "4.circle", "5.circle.fill", "5.circle",
            "6.circle.fill", "6.circle", "7.circle.fill", "7.circle", "8.circle.fill", "8.circle",
            "9.circle.fill", "9.circle",
            "number", "at", "textformat.alt",
            "asterisk", "questionmark", "exclamationmark", "percent",
            "plusminus", "divide", "equal", "dollarsign", "eurosign", "yensign", "coloncurrencysign",
            "bitcoinsign", "point.3.connected.trianglepath.dotted"
        ]),

        IconSection(title: "媒体与音频", symbols: [
            "play.fill", "play", "pause.fill", "pause", "stop.fill", "stop", "record.circle.fill", "record.circle",
            "forward.fill", "forward", "backward.fill", "backward",
            "gobackward.10", "goforward.10", "gobackward.15", "goforward.15", "gobackward.30", "goforward.30",
            "gobackward.45", "goforward.45", "gobackward.60", "goforward.60", "gobackward.75", "goforward.75",
            "gobackward.90", "goforward.90",
            "shuffle", "repeat", "repeat.1", "music.note", "music.note.list", "mic.fill", "mic",
            "mic.slash.fill", "mic.slash", "speaker.wave.3.fill", "speaker.wave.3", "speaker.slash.fill",
            "speaker.slash", "hifispeaker.fill", "hifispeaker", "waveform", "waveform.path", "waveform.path.ecg",
            "waveform.path.ecg.rectangle.fill", "waveform.path.ecg.rectangle", "earpods", "headphones",
            "airpods.chargingcase",
            "airpods", "airpodsmax", "hifispeaker.and.homepodmini.fill",
            "photo.fill", "photo", "camera.fill", "camera", "video.fill", "video", "film.fill", "film",
            "photo.on.rectangle.angled.fill", "photo.on.rectangle.angled",
            "video.badge.plus", "video.badge.waveform.fill", "video.badge.waveform", "airplayvideo", "airplayaudio",
            "captions.bubble.fill", "captions.bubble", "tv.fill", "tv", "tv.and.hifispeaker.fill",
            "opticaldisc.fill", "opticaldisc", "amplifier",
            "metronome.fill", "metronome", "guitars.fill", "guitars", "tuningfork", "square.and.arrow.up.trianglebadge.exclamationmark",
            "music.mic",
            "play.rectangle.fill", "play.rectangle"
        ]),

        IconSection(title: "时间与日期", symbols: [
            "clock.fill", "clock", "alarm.fill", "alarm", "timer", "stopwatch.fill", "stopwatch",
            "calendar", "calendar.circle.fill", "calendar.circle", "calendar.badge.plus",
            "calendar.badge.clock", "hourglass", "hourglass.tophalf.fill", "hourglass.bottomhalf.fill",
            "sunrise.fill", "sunrise", "sunset.fill", "sunset", "moon.stars.fill", "moon.stars",
            "moon.fill", "moon", "timelapse", "rays", "deskclock.fill", "deskclock"
        ]),

        IconSection(title: "连接与设备", symbols: [
            "wifi", "wifi.slash", "dot.radiowaves.left.and.right", "network", "globe", "globe.americas.fill",
            "globe.europe.africa.fill", "personalhotspot", "antenna.radiowaves.left.and.right",
            "wave.3.right.circle.fill",
            "bolt.fill", "bolt", "bolt.slash.fill", "bolt.slash", "battery.100",
            "battery.25", "battery.0", "battery.100.bolt",
            "bolt.batteryblock.fill", "bolt.batteryblock",
            "iphone", "iphone.landscape", "ipad", "ipad.landscape",
            "applewatch", "applewatch.radiowaves.left.and.right", "applewatch.slash",
            "applewatch.side.right", "macbook", "macbook.gen1", "desktopcomputer",
            "display", "tv.fill", "tv", "keyboard.fill", "keyboard", "magicmouse.fill", "computermouse.fill",
            "computermouse", "printer.fill", "printer", "externaldrive.fill", "externaldrive",
            "externaldrive.fill.badge.plus", "externaldrive.fill.badge.minus",
            "externaldrive.fill.badge.checkmark", "externaldrive.connected.to.line.below",
            "airtag.fill", "airtag", "ipodtouch.landscape", "ipodtouch", "ipod",
            "applepencil", "homepod.fill", "homepod", "homepodmini.fill", "homepodmini", "appletv.fill",
            "airpods.chargingcase.fill", "airpods.chargingcase", "airpods.chargingcase.wireless.fill",
            "airpods.chargingcase.wireless", "bonjour",
            "apple.terminal.fill", "apple.terminal", "laptopcomputer.and.arrow.down",
            "laptopcomputer"
        ]),

        IconSection(title: "通讯交流", symbols: [
            "envelope.fill", "envelope", "envelope.open.fill", "envelope.open", "tray.fill", "tray",
            "tray.and.arrow.up.fill", "tray.and.arrow.up", "tray.and.arrow.down.fill", "tray.and.arrow.down",
            "paperplane.fill", "paperplane", "message.fill", "message", "bubble.left.fill", "bubble.left",
            "bubble.right.fill", "bubble.right", "bubble.left.and.bubble.right.fill",
            "bubble.left.and.bubble.right", "phone.fill", "phone", "phone.fill.badge.plus", "phone.badge.plus",
            "phone.down.fill", "phone.down.circle.fill",
            "video.fill", "video", "video.badge.plus", "video.badge.waveform.fill", "video.badge.waveform",
            "airplayvideo", "airplayaudio", "mic.circle.fill", "mic.circle",
            "arrowshape.turn.up.left.fill", "arrowshape.turn.up.left",
            "arrowshape.turn.up.left.2.fill", "arrowshape.turn.up.left.2",
            "arrowshape.turn.up.right.fill", "arrowshape.turn.up.right",
            "bell.badge.fill", "bell.badge", "hand.raised.square.fill", "hand.raised.square",
            "phone.arrow.up.right.fill", "phone.arrow.up.right", "phone.arrow.down.left.fill", "phone.arrow.down.left"
        ]),

        IconSection(title: "人物与账户", symbols: [
            "person.fill", "person", "person.circle.fill", "person.circle", "person.badge.plus.fill",
            "person.badge.plus", "person.badge.minus.fill", "person.badge.minus",
            "person.crop.circle.fill", "person.crop.circle", "person.crop.circle.badge.plus.fill",
            "person.crop.circle.badge.plus", "person.crop.circle.badge.minus.fill",
            "person.crop.circle.badge.minus", "person.2.fill", "person.2", "person.3.fill", "person.3",
            "figure.walk", "figure.run", "figure.dance", "hand.raised.fill", "hand.raised",
            "hand.thumbsup.fill", "hand.thumbsup", "hand.thumbsdown.fill", "hand.thumbsdown",
            "face.smiling.fill", "face.smiling", "face.dashed.fill", "face.dashed",
            "person.fill.checkmark", "person.crop.circle.badge.checkmark",
            "person.fill.xmark", "person.crop.circle.badge.xmark",
            "person.text.rectangle.fill", "person.text.rectangle", "person.badge.key.fill", "person.badge.key",
            "person.crop.square.fill", "person.crop.square", "person.crop.rectangle.fill", "person.crop.rectangle",
            "figure.seated.side", "figure.stairs", "figure.disc.sports", "figure.baseball", "figure.tennis",
            "figure.basketball", "figure.soccer", "figure.pool.swim", "figure.golf", "figure.climbing",
            "person.and.background.dotted", "person.wave.2.fill", "person.wave.2"
        ]),

        IconSection(title: "健康与运动", symbols: [
            "heart.fill", "heart", "heart.circle.fill", "heart.circle", "heart.text.square.fill",
            "staroflife.fill", "staroflife", "cross.case.fill", "cross.case", "pills.fill", "pills",
            "bandage.fill", "bandage", "lungs.fill", "lungs", "brain.head.profile", "brain",
            "waveform.path.ecg.rectangle.fill", "waveform.path.ecg.rectangle", "drop.fill", "drop",
            "thermometer",
            "stethoscope",
            "bed.double.fill", "bed.double", "figure.walk.circle.fill", "figure.walk.circle",
            "figure.strengthtraining.traditional", "figure.yoga", "figure.cooldown",
            "figure.highintensity.intervaltraining", "figure.socialdance",
            "figure.flexibility", "figure.mind.and.body", "figure.cross.training", "figure.barre",
            "figure.stairs", "allergens.fill", "allergens", "thermometer.snowflake",
            "syringe.fill", "syringe", "medical.thermometer.fill", "medical.thermometer"
        ]),

        IconSection(title: "天气与环境", symbols: [
            "sun.max.fill", "sun.max", "moon.fill", "moon", "cloud.fill", "cloud", "cloud.sun.fill",
            "cloud.sun", "cloud.rain.fill", "cloud.rain", "cloud.bolt.fill", "cloud.bolt",
            "cloud.bolt.rain.fill", "cloud.bolt.rain", "cloud.snow.fill", "cloud.snow", "cloud.fog.fill",
            "cloud.fog", "tornado", "hurricane", "wind", "wind.circle.fill", "wind.circle",
            "snowflake", "thermometer.sun.fill", "thermometer.sun", "thermometer.snowflake",
            "tree.fill", "tree", "leaf.fill", "leaf", "flame.fill", "flame",
            "drop.fill", "drop", "water.waves",
            "mountain.2.fill", "mountain.2", "sun.haze.fill", "sun.haze", "moon.haze.fill", "moon.haze",
            "smoke.fill", "smoke", "sparkle", "star.leadinghalf.filled"
        ]),

        IconSection(title: "位置与导航", symbols: [
            "map.fill", "map", "mappin", "mappin.and.ellipse",
            "location.fill", "location", "location.circle.fill", "location.circle", "location.north.fill",
            "location.north", "location.north.line.fill", "location.north.line", "road.lanes",
            "road.lanes.curved.right", "road.lanes.curved.left", "car.fill", "car", "car.side",
            "bus.fill", "bus", "tram.fill", "tram", "train.side.front.car", "train.side.middle.car",
            "train.side.rear.car", "airplane", "airplane.departure", "airplane.arrival", "bicycle",
            "figure.walk", "ferry.fill", "ferry", "scooter", "truck.box.fill", "truck.box",
            "shippingbox.fill", "shippingbox", "fuelpump.fill", "fuelpump", "bus.doubledecker.fill",
            "bicycle.circle.fill", "bicycle.circle", "figure.walk.circle.fill", "figure.walk.circle",
            "car.front.waves.up.fill", "car.rear.waves.up.fill", "bolt.car.fill", "bus.doubledecker",
            "point.fill.topleft.down.curvedto.point.fill.bottomright.up",
            "compass.drawing", "parkingsign"
        ]),

        IconSection(title: "体育与游戏", symbols: [
            "gamecontroller.fill", "gamecontroller", "dpad.fill", "dpad", "dice.fill", "dice",
            "sportscourt.fill", "sportscourt", "trophy.fill", "trophy", "medal.fill", "medal",
            "figure.tennis", "figure.baseball", "figure.basketball", "figure.soccer", "figure.pool.swim",
            "figure.disc.sports", "figure.golf", "flag.checkered.2.crossed", "target", "scope",
            "circles.hexagongrid.fill", "circles.hexagongrid", "bell.badge.fill", "bell.badge"
        ]),

        IconSection(title: "辅助功能", symbols: [
            "figure.walk.circle.fill", "figure.walk.circle", "figure.roll", "ear.and.waveform", "ear.fill",
            "hand.raised.fingers.spread.fill", "hand.raised.fingers.spread",
            "character.cursor.ibeam",
            "eye.fill", "eye.slash.fill", "mic.fill", "speaker.wave.3.fill", "square.text.square.fill",
            "square.text.square", "waveform.and.magnifyingglass", "questionmark.bubble.fill",
            "accessibility", "accessibility.fill"
        ]),

        IconSection(title: "形状与几何", symbols: [
            "circle.fill", "circle", "square.fill", "square", "triangle.fill", "triangle",
            "diamond.fill", "diamond", "octagon.fill", "octagon", "hexagon.fill", "hexagon",
            "capsule.fill", "capsule", "oval.fill", "oval", "cube.fill", "cube", "cylinder.fill", "cylinder",
            "cone.fill", "cone", "pyramid.fill", "pyramid", "gearshape.fill", "gearshape",
            "bell.fill", "bell", "lightbulb.fill", "lightbulb", "star.fill", "star", "heart.fill", "heart",
            "bolt.fill", "bolt", "drop.fill", "drop", "water.waves", "sparkle", "sparkles",
            "circle.grid.2x2.fill", "circle.grid.2x2", "rectangle.grid.2x2.fill", "rectangle.grid.2x2",
            "rectangle.grid.3x2.fill", "rectangle.grid.3x2", "square.on.square.dashed",
            "flowchart.fill", "flowchart", "circle.square.fill", "circle.square"
        ])
    ]

    private var filteredIconSections: [IconSection] {
        if searchText.isEmpty {
            return Self.iconSections
        }
        var filteredSections: [IconSection] = []
        let lowercasedSearchText = searchText.lowercased()
        for section in Self.iconSections {
            let matchingSymbols = section.symbols.filter { $0.lowercased().contains(lowercasedSearchText) }
            if !matchingSymbols.isEmpty {
                filteredSections.append(IconSection(title: section.title, symbols: matchingSymbols))
            }
        }
        return filteredSections
    }

    private let columns = [GridItem(.adaptive(minimum: 50))]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("选择图标")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()

                Button(action: {
                    withAnimation(.spring()) {
                        isSearchVisible.toggle()
                    }
                }) {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                        .foregroundColor(isSearchVisible ? .accentColor : .white)
                        .padding(5)
                }
                .buttonStyle(.plain)

                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                        .padding(5)
                }
                .buttonStyle(.plain)
            }
            .padding([.horizontal, .top])
            .padding(.bottom, 8)

            if isSearchVisible {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("搜索图标…", text: $searchText)
                        .foregroundColor(.white)
                }
                .padding(8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom, 10)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                    if filteredIconSections.isEmpty {
                        Text("未找到与“\(searchText)”匹配的图标")
                            .foregroundColor(.gray)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        ForEach(filteredIconSections) { section in
                            Text(section.title)
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.leading, 5)

                            LazyVGrid(columns: columns, spacing: 15) {
                                ForEach(section.symbols, id: \.self) { symbolName in
                                    Button(action: {
                                        onSelect(symbolName)
                                        dismiss()
                                    }) {
                                        Image(systemName: symbolName)
                                            .font(.system(size: 24, weight: .bold))
                                            .frame(width: 50, height: 50)
                                            .background(Color.white.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                            .foregroundColor(.white)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding()
            }

        }
        .frame(width: 350, height: 700)
        .background(Color(red: 0.18, green: 0.18, blue: 0.28))
    }
}

struct WeatherInfoSettingsView: View {
    @Binding var selectedInfo: [WeatherInfoType]

    var body: some View {
        SettingsMultiSelectList(
            title: "可见天气信息",
            options: WeatherInfoType.selectableCases,
            selection: $selectedInfo,
            label: \.displayName
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

struct BatteryInfoSettingsView: View {
    @Binding var selectedInfo: [BatteryInfoType]

    var body: some View {
        SettingsMultiSelectList(
            title: "可见电池信息",
            options: BatteryInfoType.allCases,
            selection: $selectedInfo,
            label: \.displayName
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

struct LockScreenSettingsView: View {
    @EditingSettings var settings: SettingsEditingSession
    @State private var notchsettingsHaveChanged: Bool = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                Text("锁屏")
                    .font(.largeTitle.bold())
                    .padding(.bottom)

                VStack(alignment: .leading, spacing: 0) {
                    Text("壁纸").font(.headline).padding([.top, .horizontal])

                    ToggleRow(
                        title: "自定义锁屏壁纸",
                        description: "在锁屏的时钟、登录控件及 Sapphire 小组件后方显示自定义图片或视频。",
                        isOn: $settings.settings.lockScreenCustomWallpaperEnabled
                    )

                    if settings.settings.lockScreenCustomWallpaperEnabled {
                        Divider().padding(.leading, 20)

                        WallpaperFileRow(
                            path: $settings.settings.lockScreenCustomWallpaperPath,
                            panelTitle: "选择锁屏壁纸",
                            panelMessage: "选择要在锁屏上显示的图片或视频。"
                        )

                        Divider().padding(.leading, 20)

                        ToggleRow(
                            title: "同时用于桌面",
                            description: "在桌面上同步显示锁屏壁纸（包含动态视频），除非下方单独设置了桌面壁纸。",
                            isOn: $settings.settings.lockScreenKeepWallpaperAfterUnlock
                        )
                    }

                    Divider().padding(.leading, 20)

                    ToggleRow(
                        title: "自定义桌面壁纸",
                        description: "在桌面上使用自定义图片或视频。视频会在桌面图标后方播放，并在桌面被遮挡时自动暂停；若未单独设置锁屏壁纸，锁屏也会显示该壁纸。",
                        isOn: $settings.settings.desktopWallpaperEnabled
                    )

                    if settings.settings.desktopWallpaperEnabled {
                        Divider().padding(.leading, 20)

                        WallpaperFileRow(
                            path: $settings.settings.desktopWallpaperPath,
                            panelTitle: "选择桌面壁纸",
                            panelMessage: "选择要用作桌面壁纸的图片或视频。"
                        )
                    }

                    if wallpaperConfiguration.desktopPath != nil || wallpaperConfiguration.lockScreenPath != nil {
                        Divider().padding(.leading, 20)

                        HStack {
                            SettingsRowLabel(
                                title: "缩放方式",
                                description: "壁纸如何适配不同比例的屏幕。",
                                titleFont: .system(size: 14, weight: .medium)
                            )
                            Spacer()
                            Picker("缩放方式", selection: $settings.settings.liveWallpaperScaling) {
                                ForEach(WallpaperScaling.allCases) { scaling in
                                    Text(scaling.displayName).tag(scaling)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 160)
                        }
                        .padding()
                    }

                    if hasVideoWallpaper {
                        Divider().padding(.leading, 20)

                        HStack {
                            SettingsRowLabel(
                                title: "视频播放",
                                description: settings.settings.liveWallpaperPlaybackMode.description,
                                titleFont: .system(size: 14, weight: .medium)
                            )
                            Spacer()
                            Picker("视频播放", selection: $settings.settings.liveWallpaperPlaybackMode) {
                                ForEach(LiveWallpaperPlaybackMode.allCases) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 165)
                        }
                        .padding()

                        if settings.settings.liveWallpaperPlaybackMode == .adaptive {
                            Divider().padding(.leading, 20)

                            ToggleRow(
                                title: "低电量模式下暂停",
                                description: "开启低电量模式时显示首帧画面，暂停视频播放。",
                                isOn: $settings.settings.liveWallpaperPauseOnLowPower
                            )

                            Divider().padding(.leading, 20)

                            ToggleRow(
                                title: "使用电池供电时暂停",
                                description: "仅在 Mac 连接电源时播放视频壁纸。",
                                isOn: $settings.settings.liveWallpaperPauseOnBattery
                            )
                        }
                    }

                }
                .modifier(SettingsContainerModifier())
                .animation(.default, value: settings.settings.lockScreenCustomWallpaperEnabled)
                .animation(.default, value: settings.settings.desktopWallpaperEnabled)
                .animation(.default, value: hasVideoWallpaper)
                .animation(.default, value: settings.settings.liveWallpaperPlaybackMode)

                ToggleRow(
                    title: "暂停时仍显示音乐",
                    description: "即使播放已暂停，也在锁屏小组件中继续显示当前曲目。",
                    isOn: $settings.settings.lockScreenShowMusicWhenPaused
                )
                .modifier(SettingsContainerModifier())

                VStack(alignment: .leading, spacing: 0) {
                    Text("顶部信息小组件").font(.headline).padding([.top, .horizontal])

                    ToggleRow(
                        title: "显示信息小组件",
                        description: "在时钟下方显示小型信息小组件。",
                        isOn: $settings.settings.lockScreenShowInfoWidget
                    )

                    if settings.settings.lockScreenShowInfoWidget {
                        Divider().padding(.leading, 20)

                        ToggleRow(
                            title: "不活跃时隐藏",
                            description: "仅在音乐、日历或专注模式处于活动状态时显示对应小组件。",
                            isOn: $settings.settings.lockScreenHideInactiveInfoWidgets
                        )

                        Divider().padding(.leading, 20)

                        SettingsMultiSelectList(
                            title: "可见小组件",
                            options: LockScreenWidgetType.selectableCases,
                            selection: $settings.settings.lockScreenWidgets,
                            label: \.displayName
                        )

                        if settings.settings.lockScreenWidgets.contains(.weather) {
                            Divider().padding(.horizontal)
                            WeatherInfoSettingsView(selectedInfo: $settings.settings.lockScreenWeatherInfo)
                        }

                        if settings.settings.lockScreenWidgets.contains(.battery) {
                            Divider().padding(.horizontal)
                            BatteryInfoSettingsView(selectedInfo: $settings.settings.lockScreenBatteryInfo)
                        }
                    }
                }
                .modifier(SettingsContainerModifier())
                .animation(.default, value: settings.settings.lockScreenShowInfoWidget)
                .animation(.default, value: settings.settings.lockScreenWidgets.contains(.weather))
                .animation(.default, value: settings.settings.lockScreenWidgets.contains(.battery))

                VStack(alignment: .leading, spacing: 0) {
                    Text("主小组件").font(.headline).padding([.top, .horizontal])

                    ToggleRow(
                        title: "显示主小组件",
                        description: "在屏幕中央显示尺寸更大、可交互的小组件。",
                        isOn: $settings.settings.lockScreenShowMainWidget
                    )

                    if settings.settings.lockScreenShowMainWidget {
                        Divider().padding(.leading, 20)

                        SettingsMultiSelectList(
                            title: "可见主小组件",
                            options: LockScreenMainWidgetType.selectableCases,
                            selection: $settings.settings.lockScreenMainWidgets,
                            label: \.displayName
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .modifier(SettingsContainerModifier())
                .animation(.default, value: settings.settings.lockScreenShowMainWidget)

                VStack(alignment: .leading, spacing: 0) {
                    Text("迷你小组件").font(.headline).padding([.top, .horizontal])

                    ToggleRow(
                        title: "显示迷你小组件",
                        description: "在主小组件区域下方显示紧凑型小组件。",
                        isOn: $settings.settings.lockScreenShowMiniWidgets
                    )

                    if settings.settings.lockScreenShowMiniWidgets {
                        Divider().padding(.leading, 20)

                        SettingsMultiSelectList(
                            title: "可见迷你小组件",
                            options: LockScreenMiniWidgetType.selectableCases,
                            selection: $settings.settings.lockScreenMiniWidgets,
                            label: \.displayName
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .modifier(SettingsContainerModifier())
                .animation(.default, value: settings.settings.lockScreenShowMiniWidgets)

                VStack(alignment: .leading, spacing: 0) {
                    Text("外观").font(.headline).padding([.top, .horizontal])

                    ToggleRow(
                        title: "液态玻璃效果",
                        description: "为锁屏小组件应用原生液态玻璃材质效果。",
                        isOn: $settings.settings.lockScreenLiquidGlassLook
                    )

                    if settings.settings.lockScreenLiquidGlassLook {
                        Divider().padding(.leading, 20)
                        LiquidGlassOptionsEditor(options: $settings.settings.lockScreenGlass)
                    }
                }
                .modifier(SettingsContainerModifier())
                .animation(.default, value: settings.settings.lockScreenLiquidGlassLook)

                VStack(alignment: .leading, spacing: 0) {
                    Text("灵动岛栏").font(.headline).padding([.top, .horizontal])

                    ToggleRow(
                        title: "在锁屏上显示灵动岛",
                        description: "在锁屏顶部保持显示 Sapphire 灵动岛栏。",
                        isOn: $settings.settings.lockScreenShowNotch
                    )

                    Divider().padding(.leading, 20)

                    ToggleRow(
                        title: "显示锁屏实时活动",
                        description: "在锁屏灵动岛中显示身份验证状态实时活动。",
                        isOn: $settings.settings.lockScreenLiveActivityEnabled
                    )
                }
                .modifier(SettingsContainerModifier())
            }
            .padding(25)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onChange(of: settings.settings.lockScreenShowNotch) {notchsettingsHaveChanged = true}
        }
    }

    private var wallpaperConfiguration: LiveWallpaperConfiguration {
        LiveWallpaperConfiguration(settings: settings.settings.value)
    }

    private var hasVideoWallpaper: Bool {
        let configuration = wallpaperConfiguration
        return WallpaperMedia.isVideo(path: configuration.desktopPath)
            || WallpaperMedia.isVideo(path: configuration.lockScreenPath)
    }

}

private struct WallpaperFileRow: View {
    @Binding var path: String?
    let panelTitle: String
    let panelMessage: String

    @State private var thumbnail: CGImage?

    private var media: WallpaperMedia? { WallpaperMedia(path: path) }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(0.08))
                if let thumbnail {
                    Image(decorative: thumbnail, scale: 2)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: media?.isVideo == true ? "film" : "photo")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 64, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                if media?.isVideo == true, thumbnail != nil {
                    Image(systemName: "play.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(3)
                        .background(.black.opacity(0.45), in: Circle())
                        .padding(3)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                if let media {
                    Text(media.url.lastPathComponent)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                    Text(media.isVideo ? "动态视频" : "图片")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if let path, !path.isEmpty {
                    Text((path as NSString).lastPathComponent)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                    Text("文件未找到")
                        .font(.caption2)
                        .foregroundStyle(.red)
                } else {
                    Text("未选择壁纸")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button("选择…") { choose() }
            if path != nil {
                Button("移除") { path = nil }
            }
        }
        .padding()
        .task(id: path) {
            thumbnail = nil
            guard let media else { return }
            let image = await Task.detached(priority: .utility) {
                await WallpaperAssetStore.thumbnail(for: media, maxPixelSize: 160)
            }.value
            guard !Task.isCancelled else { return }
            thumbnail = image
        }
    }

    private func choose() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.title = panelTitle
        panel.message = panelMessage
        panel.prompt = "选择"
        panel.allowedContentTypes = WallpaperMedia.allowedContentTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if let path, !path.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: path).deletingLastPathComponent()
        }
        let binding = $path
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            binding.wrappedValue = url.path
        }
    }
}

struct SnapZonesSettingsView: View {
    @EditingSettings var settings: SettingsEditingSession
    @ObservedObject private var appFetcher = SystemAppFetcher.shared

    @State private var layoutToEdit: SnapLayout?
    @State private var planeToEdit: Plane?
    @State private var isShowingAppPicker = false

    @State private var appToConfigureMultiLayout: String?
    @State private var multiLayoutIDsForSheet: [UUID] = []
    @State private var snapShortcutsExpanded = false

    private var allLayouts: [SnapLayout] {
        LayoutTemplate.allTemplates + settings.settings.customSnapLayouts
    }

    private var viewModeDescription: String {
        switch settings.settings.snapZoneViewMode {
        case .single:
            return "每次仅显示一个布局，由全局默认设置或应用专属设置决定。"
        case .multi:
            return "在小组件中并排显示自定义布局列表，方便快速选择。"
        }
    }

    private var isShowingMultiLayoutPicker: Binding<Bool> {
        Binding(
            get: { appToConfigureMultiLayout != nil },
            set: { isShowing in
                if !isShowing {
                    appToConfigureMultiLayout = nil
                }
            }
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 25) {
                Text("窗口磁吸分区与工作平面")
                    .font(.system(size: 32, weight: .bold))
                    .padding(.bottom, 5)

                VStack(alignment: .leading, spacing: 0) {
                    ToggleRow(
                        title: "拖拽时激活",
                        description: "拖拽至灵动岛附近时显示窗口磁吸分区。",
                        isOn: $settings.settings.snapDragEnabled
                    )
                    ToggleRow(
                        title: "拖拽窗口时激活",
                        description: "拖拽窗口时显示窗口磁吸分区。按住 Command 键可暂时隐藏。",
                        isOn: $settings.settings.snapOnWindowDragEnabled
                    )

                    Divider().padding(.leading, 20)

                    DeferredValueEditor(value: $settings.settings.snapActivationDelay) { draft, onEditingChanged in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("激活延迟")
                                    .font(.system(size: 14, weight: .medium))
                                Spacer()
                                Text(String(format: "%.2f 秒", draft.wrappedValue))
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: draft, in: 0.1...1.0, step: 0.05, onEditingChanged: onEditingChanged)
                            Text("在触发区域停留达到该时长后才打开窗口磁吸分区，有助于防止误触。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()

                    Divider().padding(.leading, 20)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("移动与调整大小")
                                .font(.system(size: 14, weight: .medium))
                            Spacer()
                            Picker("移动与调整大小", selection: $settings.settings.snapWindowAnimation) {
                                ForEach(SnapWindowAnimation.allCases) { animation in
                                    Text(animation.displayName).tag(animation)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 150)
                        }
                        Text(settings.settings.snapWindowAnimation.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }
                .modifier(SettingsContainerModifier())

                snapShortcutsManagementSection

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("全局小组件样式").font(.headline)
                        Spacer()
                        Picker("小组件视图样式", selection: $settings.settings.snapZoneViewMode) {
                            ForEach(SnapZoneViewMode.allCases) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 150)
                    }.padding()

                    Text(viewModeDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom)

                }.modifier(SettingsContainerModifier())

                if settings.settings.snapZoneViewMode == .single {
                    singleLayoutsManagementSection
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                } else {
                    multiLayoutsManagementSection
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }

                appSpecificLayoutsSection
                customLayoutsSection
                planesManagementSection
                RequiredPermissionsView(section: .snapZones)
            }
            .padding(25)
            .animation(.easeInOut(duration: 0.2), value: settings.settings.snapZoneViewMode)
        }
        .onAppear(perform: appFetcher.fetchApps)
        .sheet(item: $layoutToEdit) { layout in
            LayoutEditorView(layout: Binding(
                get: { layout },
                set: { updatedLayout in layoutToEdit = updatedLayout }
            ), onSave: saveLayout)
        }
        .sheet(isPresented: isShowingMultiLayoutPicker) {
            if let bundleId = appToConfigureMultiLayout {
                MultiLayoutPickerView(
                    appName: appName(for: bundleId),
                    allLayouts: allLayouts,
                    initialLayoutIDs: multiLayoutIDsForSheet,
                    onSave: { newIDs in
                        modifySettings { $0.appSpecificLayoutConfigurations[bundleId] = .multi(layoutIDs: newIDs) }
                    }
                )
            }
        }
        .sheet(item: $planeToEdit) { plane in
            PlaneEditorView(plane: Binding(
                get: { plane },
                set: { updatedPlane in planeToEdit = updatedPlane }
            ), allLayouts: allLayouts, allApps: appFetcher.apps, onSave: savePlane)
        }
        .popover(isPresented: $isShowingAppPicker, arrowEdge: .bottom) {
            AppPickerView(apps: appFetcher.apps, onSelect: addAppSpecificLayout)
        }
    }

    @ViewBuilder
    private var snapShortcutsManagementSection: some View {
        DisclosureGroup(isExpanded: $snapShortcutsExpanded) {
            VStack(alignment: .leading, spacing: 0) {
                PremiumFeatureView(feature: .snapZonesKeyboardShortcuts) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("为分区指定快捷键，即可将当前焦点窗口快速磁吸至该位置。若录制的快捷键已被其他分区占用，将自动转移至当前分区。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal)
                            .padding(.top, 12)
                            .padding(.bottom, 8)

                        ForEach(allLayouts) { layout in
                            SnapZoneShortcutLayoutView(
                                layout: layout,
                                shortcuts: settings.settings.snapZoneShortcuts,
                                onChange: { zoneID, shortcut in
                                    modifySettings { $0.setSnapZoneShortcut(shortcut, for: layout.id, zoneID: zoneID) }
                                }
                            )
                            if layout.id != allLayouts.last?.id {
                                Divider().padding(.leading, 20)
                            }
                        }
                    }
                }
            }
        } label: {
            Label("窗口磁吸分区快捷键", systemImage: "keyboard")
                .font(.headline)
                .padding([.top, .horizontal])
                .padding(.bottom, 6)
        }
        .modifier(SettingsContainerModifier())
    }

    @ViewBuilder
    private var singleLayoutsManagementSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("全局默认布局").font(.headline)
                Spacer()
                ModernMenuPicker(selection: $settings.settings.defaultSnapLayout, options: allLayouts, titleKeyPath: \.name)
            }.padding(.horizontal, 20).padding(.vertical, 12)
        }.modifier(SettingsContainerModifier())
    }

    @ViewBuilder
    private var multiLayoutsManagementSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("全局多视图布局").font(.headline)
                Spacer()
                Menu {
                    let alreadyAddedIDs = Set(settings.settings.snapZoneLayoutOptions)
                    let availableLayouts = allLayouts.filter { !alreadyAddedIDs.contains($0.id) }

                    if availableLayouts.isEmpty { Text("已添加全部布局") }
                    else {
                        ForEach(availableLayouts) { layout in
                            Button(layout.name) { addLayoutOption(layout.id) }
                        }
                    }
                } label: {
                    HStack { Image(systemName: "plus"); Text("添加布局") }
                }
                .buttonStyle(.borderless).tint(.accentColor)
                .disabled(allLayouts.count == settings.settings.snapZoneLayoutOptions.count)

            }.padding([.horizontal, .top]).padding(.bottom, 8)

            Text("添加并调整默认显示在多视图小组件中的布局顺序。").font(.caption).foregroundColor(.secondary).padding(.horizontal).padding(.bottom)
            Divider()

            if settings.settings.snapZoneLayoutOptions.isEmpty {
                 Text("点击“添加布局”以构建你的全局多视图小组件。")
                     .foregroundColor(.secondary).frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
            } else {
                List {
                    ForEach(settings.settings.snapZoneLayoutOptions.indices, id: \.self) { index in
                        let layoutID = settings.settings.snapZoneLayoutOptions[index]
                        if let layout = allLayouts.first(where: { $0.id == layoutID }) {
                            HStack {
                                Image(systemName: "line.3.horizontal").foregroundStyle(.secondary)
                                Text(layout.name)
                                Spacer()
                                Button {
                                    deleteLayoutOption(at: IndexSet(integer: index))
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .onMove(perform: moveLayoutOption)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain).scrollContentBackground(.hidden)
                .frame(height: CGFloat(settings.settings.snapZoneLayoutOptions.count) * 28)
            }
        }.modifier(SettingsContainerModifier())
    }

    @ViewBuilder
    private var appSpecificLayoutsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("应用专属覆盖规则").font(.headline)
                Spacer()
                Button("添加应用") { isShowingAppPicker = true }.buttonStyle(.borderless).tint(.accentColor)
            }.padding([.horizontal, .top]).padding(.bottom, 8)
            Text("拖拽特定应用时强制使用指定的布局模式（单视图或多视图）。").font(.caption).foregroundColor(.secondary).padding(.horizontal).padding(.bottom)
            Divider()
            if settings.settings.appSpecificLayoutConfigurations.isEmpty {
                 Text("暂未配置应用专属覆盖规则。").foregroundColor(.secondary).frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
            } else {
                ForEach(settings.settings.appSpecificLayoutConfigurations.keys.sorted(), id: \.self) { bundleId in
                    AppSpecificLayoutConfigRow(
                        app: app(for: bundleId),
                        appName: appName(for: bundleId),
                        allLayouts: allLayouts,
                        configuration: bindingForAppConfig(bundleId),
                        onEditMulti: {
                            if case .multi(let layoutIDs) = settings.settings.appSpecificLayoutConfigurations[bundleId] {
                                self.multiLayoutIDsForSheet = layoutIDs
                            } else {
                                self.multiLayoutIDsForSheet = []
                            }
                            self.appToConfigureMultiLayout = bundleId
                        },
                        onDelete: {
                            modifySettings { $0.appSpecificLayoutConfigurations.removeValue(forKey: bundleId) }
                        }
                    )
                    Divider().padding(.leading, 60)
                }
            }
        }.modifier(SettingsContainerModifier())
    }

    @ViewBuilder
    private var customLayoutsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("我的自定义布局").font(.headline)
                Spacer()
                Button("新建布局") { layoutToEdit = SnapLayout(name: "新建自定义布局", zones: []) }.buttonStyle(.borderless).tint(.accentColor)
            }.padding()
            Divider()
            if settings.settings.customSnapLayouts.isEmpty {
                Text("暂未创建自定义布局。").foregroundColor(.secondary).frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
            } else {
                ForEach(settings.settings.customSnapLayouts) { layout in
                    CustomLayoutRow(layout: layout, onEdit: { layoutToEdit = layout }, onDelete: { deleteLayout(layout) })
                    Divider().padding(.leading, 20)
                }
            }
        }.modifier(SettingsContainerModifier())
    }

    @ViewBuilder
    private var planesManagementSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("工作平面").font(.title2.bold())
                Spacer()
                Button("新建工作平面") {
                    guard let firstLayout = allLayouts.first else { return }
                    planeToEdit = Plane(name: "新建工作平面", layoutID: firstLayout.id)
                }.buttonStyle(.borderless).tint(.accentColor)
            }.padding([.horizontal, .top]).padding(.bottom, 8)
            Text("通过键盘快捷键触发布局，瞬间排列窗口。").font(.caption).foregroundColor(.secondary).padding(.horizontal).padding(.bottom)
            Divider()
            if settings.settings.planes.isEmpty {
                Text("暂未创建工作平面。").foregroundColor(.secondary).frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
            } else {
                ForEach($settings.settings.planes) { $plane in
                    PlaneRow(plane: $plane, onEdit: { planeToEdit = $plane.wrappedValue }, onDelete: { deletePlane(withId: $plane.id) })
                    Divider().padding(.leading, 20)
                }
            }
        }.modifier(SettingsContainerModifier())
    }

    // MARK: - Helper Functions
    private func modifySettings(_ modification: (inout Settings) -> Void) {
        var newSettings = settings.settings.value
        modification(&newSettings)
        settings.settings.value = newSettings
    }

    private func saveLayout(_ savedLayout: SnapLayout) { modifySettings { settings in if let index = settings.customSnapLayouts.firstIndex(where: { $0.id == savedLayout.id }) { settings.customSnapLayouts[index] = savedLayout } else { settings.customSnapLayouts.append(savedLayout) } } }
    private func savePlane(_ savedPlane: Plane) { modifySettings { settings in if let index = settings.planes.firstIndex(where: { $0.id == savedPlane.id }) { settings.planes[index] = savedPlane } else { settings.planes.append(savedPlane) } } }

    private func deleteLayout(_ layoutToDelete: SnapLayout) {
        modifySettings { settings in
            settings.customSnapLayouts.removeAll { $0.id == layoutToDelete.id }
            if settings.defaultSnapLayout.id == layoutToDelete.id {
                settings.defaultSnapLayout = LayoutTemplate.columns
            }
            for (bundleID, config) in settings.appSpecificLayoutConfigurations {
                switch config {
                case .single(let layoutID) where layoutID == layoutToDelete.id:
                    settings.appSpecificLayoutConfigurations.removeValue(forKey: bundleID)
                case .multi(var layoutIDs):
                    layoutIDs.removeAll { $0 == layoutToDelete.id }
                    settings.appSpecificLayoutConfigurations[bundleID] = .multi(layoutIDs: layoutIDs)
                default:
                    break
                }
            }
            settings.snapZoneShortcuts.removeAll { $0.layoutID == layoutToDelete.id }
            settings.planes.removeAll { $0.layoutID == layoutToDelete.id }
        }
    }

    private func deletePlane(withId planeId: UUID) { modifySettings { settings in settings.planes.removeAll { $0.id == planeId } } }

    private func addAppSpecificLayout(_ appBundleId: String) {
        modifySettings { settings in
            if settings.appSpecificLayoutConfigurations[appBundleId] == nil {
                let firstLayoutID = allLayouts.first?.id ?? LayoutTemplate.columns.id
                settings.appSpecificLayoutConfigurations[appBundleId] = .single(layoutID: firstLayoutID)
            }
        }
        isShowingAppPicker = false
    }

    private func app(for bundleId: String) -> SystemApp? { appFetcher.apps.first { $0.id == bundleId } }
    private func appName(for bundleId: String) -> String { app(for: bundleId)?.name ?? bundleId }

    private func bindingForAppConfig(_ bundleId: String) -> Binding<AppSnapLayoutConfiguration> {
        Binding(
            get: { settings.settings.appSpecificLayoutConfigurations[bundleId] ?? .useGlobalDefault },
            set: { newConfig in modifySettings { $0.appSpecificLayoutConfigurations[bundleId] = newConfig } }
        )
    }

    private func addLayoutOption(_ layoutID: UUID) { modifySettings { $0.snapZoneLayoutOptions.append(layoutID) } }
    private func moveLayoutOption(from source: IndexSet, to destination: Int) { modifySettings { $0.snapZoneLayoutOptions.move(fromOffsets: source, toOffset: destination) } }
    private func deleteLayoutOption(at offsets: IndexSet) { modifySettings { $0.snapZoneLayoutOptions.remove(atOffsets: offsets) } }
}

fileprivate struct SnapZoneShortcutLayoutView: View {
    let layout: SnapLayout
    let shortcuts: [SnapZoneShortcut]
    let onChange: (UUID, KeyboardShortcut?) -> Void

    @ObservedObject private var shortcutRecorder = GlobalShortcutRecorder.shared

    private func shortcut(for zoneID: UUID) -> KeyboardShortcut? {
        shortcuts.first { $0.layoutID == layout.id && $0.zoneID == zoneID }?.shortcut
    }

    private func recordingIdentifier(for zoneID: UUID) -> String {
        "snap-zone-\(layout.id.uuidString)-\(zoneID.uuidString)"
    }

    private func toggleRecording(for zoneID: UUID) {
        let identifier = recordingIdentifier(for: zoneID)
        if shortcutRecorder.isRecording {
            if shortcutRecorder.recordingIdentifier == identifier {
                shortcutRecorder.stopRecording()
            }
            return
        }

        shortcutRecorder.startRecording(identifier: identifier) { key, flags in
            onChange(zoneID, KeyboardShortcut(key: key, modifiers: flags))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "rectangle.3.group")
                    .foregroundStyle(Color.accentColor)
                Text(layout.name)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("\(layout.zones.count) 个分区")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 4)

            ForEach(Array(layout.zones.enumerated()), id: \.element.id) { index, zone in
                let zoneShortcut = shortcut(for: zone.id)
                let identifier = recordingIdentifier(for: zone.id)
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("分区 \(index + 1)")
                            .font(.system(size: 13, weight: .medium))
                        Text("\(Int(zone.width * 100))% x \(Int(zone.height * 100))%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()

                    Button(action: { toggleRecording(for: zone.id) }) {
                        HStack(spacing: 6) {
                            if shortcutRecorder.isRecording && shortcutRecorder.recordingIdentifier == identifier {
                                ProgressView()
                                    .controlSize(.small)
                                Text("正在录制…")
                            } else if let zoneShortcut {
                                Image(systemName: "keyboard")
                                Text("\(KeyboardShortcutHelper.description(for: zoneShortcut.modifiers))\(zoneShortcut.key)")
                            } else {
                                Image(systemName: "keyboard")
                                Text("录制")
                            }
                        }
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .frame(minWidth: 125)
                    }
                    .buttonStyle(.bordered)
                    .disabled(shortcutRecorder.isRecording && shortcutRecorder.recordingIdentifier != identifier)
                    .help(zoneShortcut == nil ? "为分区 \(index + 1) 录制快捷键" : "修改分区 \(index + 1) 的快捷键")

                    if zoneShortcut != nil {
                        Button {
                            onChange(zone.id, nil)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("清除快捷键")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
        }
    }
}

fileprivate struct AppSpecificLayoutConfigRow: View {
    let app: SystemApp?
    let appName: String
    let allLayouts: [SnapLayout]
    @Binding var configuration: AppSnapLayoutConfiguration
    let onEditMulti: () -> Void
    let onDelete: () -> Void

    private enum ConfigType: Int, Identifiable {
        case useDefault = 0, single, multi
        var id: Int { self.rawValue }
    }

    private var configTypeBinding: Binding<ConfigType> {
        Binding(
            get: {
                switch configuration {
                case .useGlobalDefault: return .single
                case .single: return .single
                case .multi: return .multi
                }
            },
            set: { newType in
                switch newType {
                case .single:
                    if case .single = configuration { return }
                    let firstLayoutID = allLayouts.first?.id ?? LayoutTemplate.columns.id
                    configuration = .single(layoutID: firstLayoutID)
                case .multi:
                    if case .multi = configuration { return }
                    configuration = .multi(layoutIDs: [])
                case .useDefault:
                    break
                }
            }
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            if let app {
                SystemAppIconView(app: app, size: 28, cornerRadius: 6)
            } else {
                Image(systemName: "app.dashed").font(.title2).frame(width: 28)
            }

            Text(appName).lineLimit(1)
            Spacer()

            Picker("模式", selection: configTypeBinding) {
                Text("单视图").tag(ConfigType.single)
                Text("多视图").tag(ConfigType.multi)
            }
            .labelsHidden().frame(width: 180)

            switch configuration {
            case .single(let layoutID):
                let binding = Binding(
                    get: { layoutID },
                    set: { newID in configuration = .single(layoutID: newID) }
                )
                ModernMenuPickerWithID(selection: binding, options: allLayouts, titleKeyPath: \.name)
                    .frame(width: 150)
            case .multi:
                Button("编辑", action: onEditMulti).buttonStyle(.borderless).tint(.accentColor)
            case .useGlobalDefault:
                EmptyView().frame(width: 150, height: 1)
            }

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill").font(.body).foregroundColor(.secondary.opacity(0.7))
            }
            .buttonStyle(.plain).padding(.leading, 8)
        }
        .padding(.vertical, 8).padding(.horizontal, 20)
    }
}

fileprivate struct MultiLayoutPickerView: View {
    @Environment(\.dismiss) var dismiss
    let appName: String
    let allLayouts: [SnapLayout]
    let onSave: ([UUID]) -> Void

    @State private var editedLayoutIDs: [UUID]

    init(appName: String, allLayouts: [SnapLayout], initialLayoutIDs: [UUID], onSave: @escaping ([UUID]) -> Void) {
        self.appName = appName
        self.allLayouts = allLayouts
        self.onSave = onSave
        self._editedLayoutIDs = State(initialValue: initialLayoutIDs)
    }

    private var availableLayouts: [SnapLayout] {
        allLayouts.filter { !editedLayoutIDs.contains($0.id) }
    }

    private func layout(for id: UUID) -> SnapLayout? {
        allLayouts.first { $0.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("编辑“\(appName)”的多视图布局").font(.title2.bold()).padding()
            Divider()

            HSplitView {
                VStack(alignment: .leading) {
                    Text("可用布局").font(.headline).padding([.top, .horizontal])
                    List(availableLayouts) { layout in
                        Button(action: { editedLayoutIDs.append(layout.id) }) {
                            HStack { Text(layout.name); Spacer(); Image(systemName: "plus.circle.fill").foregroundColor(.green) }
                        }.buttonStyle(.plain)
                    }.listStyle(.sidebar)
                }
                .frame(minWidth: 220)

                VStack(alignment: .leading) {
                    Text("已选布局（拖拽以排序）").font(.headline).padding([.top, .horizontal])
                    List {
                        ForEach(editedLayoutIDs.indices, id: \.self) { index in
                            if let layout = layout(for: editedLayoutIDs[index]) {
                                HStack {
                                    Text(layout.name)
                                    Spacer()
                                    Button {
                                        delete(at: IndexSet(integer: index))
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .onMove(perform: move)
                    }.listStyle(.sidebar)
                }
                .frame(minWidth: 220)
            }

            Divider()
            HStack {
                Button("取消", role: .cancel) { dismiss() }
                Spacer()
                Button("保存") {
                    onSave(editedLayoutIDs)
                    dismiss()
                }.buttonStyle(.borderedProminent)
            }.padding()
        }
        .frame(width: 550, height: 450)
    }

    private func move(from source: IndexSet, to destination: Int) {
        editedLayoutIDs.move(fromOffsets: source, toOffset: destination)
    }

    private func delete(at offsets: IndexSet) {
        editedLayoutIDs.remove(atOffsets: offsets)
    }
}

fileprivate struct ModernMenuPicker<T: Identifiable & Hashable>: View {
    @Binding var selection: T
    let options: [T]
    let titleKeyPath: KeyPath<T, String>

    private var selectedOptionName: String {
        return options.first { $0.id == selection.id }?[keyPath: titleKeyPath] ?? "选择"
    }

    var body: some View {
        Menu {
            ForEach(options) { option in
                Button(option[keyPath: titleKeyPath]) {
                    selection = option
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selectedOptionName)
                Image(systemName: "chevron.down").font(.caption.bold())
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .foregroundColor(.primary)
        }
        .buttonStyle(.plain)
    }
}

fileprivate struct CustomLayoutRow: View {
    let layout: SnapLayout
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "rectangle.3.group")
                .font(.title2)
                .frame(width: 30)
                .foregroundColor(.accentColor)
            Text(layout.name).font(.headline)
            Spacer()
            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.plain)
            .tint(.secondary)

            Button(action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .tint(.red)
            .padding(.leading, 8)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

fileprivate struct ModernMenuPickerWithID<T: Identifiable & Hashable>: View where T.ID == UUID {
    @Binding var selection: T.ID
    let options: [T]
    let titleKeyPath: KeyPath<T, String>
    var defaultID: T.ID? = nil
    var defaultTitle: String = "默认"

    private var selectedOptionName: String {
        if let defaultID = defaultID, selection == defaultID {
            return defaultTitle
        }
        return options.first { $0.id == selection }?[keyPath: titleKeyPath] ?? "选择"
    }

    var body: some View {
        Menu {
            if let defaultID = defaultID {
                Button(defaultTitle) { selection = defaultID }
                Divider()
            }
            ForEach(options) { option in
                Button(option[keyPath: titleKeyPath]) { selection = option.id }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selectedOptionName)
                Image(systemName: "chevron.down").font(.caption.bold())
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .foregroundColor(.primary)
        }
        .buttonStyle(.plain)
    }
}

fileprivate struct PlaneRow: View {
    @Binding var plane: Plane
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var shortcutDescription: String {
        guard let shortcut = plane.shortcut else { return "未设置快捷键" }
        return "\(KeyboardShortcutHelper.description(for: shortcut.modifiers)) \(shortcut.key)"
    }

    var body: some View {
        HStack {
            Image(systemName: "keyboard")
                .font(.title2)
                .frame(width: 30)
                .foregroundColor(.accentColor)
                .onTapGesture(perform: onEdit)

            VStack(alignment: .leading) {
                Text(plane.name).font(.headline)
                Text(shortcutDescription)
                    .font(.caption).foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onEdit)

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .tint(.red)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

fileprivate struct AppPickerView: View {
    let apps: [SystemApp]
    let onSelect: (String) -> Void
    @State private var searchText = ""

    private var filteredApps: [SystemApp] {
        if searchText.isEmpty {
            return apps
        }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField("搜索应用", text: $searchText)
                .textFieldStyle(.plain)
                .padding()
                .background(Color.black.opacity(0.1))

            List(filteredApps) { app in
                Button(action: { onSelect(app.id) }) {
                    HStack {
                        SystemAppIconView(app: app, size: 24, cornerRadius: 4)
                        Text(app.name)
                    }
                }
                .buttonStyle(.plain)
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
        }
        .frame(width: 300, height: 400)
        .background(.ultraThinMaterial)
    }
}

struct NotificationsSettingsView: View {
    @EditingSettings var settings: SettingsEditingSession

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                Text("通知")
                    .font(.largeTitle.bold())
                    .padding(.bottom)

                InfoContainer(text: "所有通知与专注模式功能目前仍在开发中。", iconName: "info.circle.fill", color: .yellow)

                VStack(spacing: 0) {
                    HStack {
                        Text("启用通知")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        SettingsSwitch(isOn: $settings.settings.masterNotificationsEnabled)
                            .animation(.default, value: settings.settings.masterNotificationsEnabled)
                    }
                    .padding(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
                }
                .modifier(SettingsContainerModifier())

                VStack(spacing: 20) {

                    VStack(alignment: .leading, spacing: 0) {
                        Text("验证码")
                            .font(.headline)
                            .padding([.top, .horizontal])

                        ToggleRow(
                            title: "仅显示包含验证码的通知",
                            description: "过滤通知，仅在检测到一次性验证码（OTP）时显示。",
                            isOn: $settings.settings.onlyShowVerificationCodeNotifications
                        )

                        Divider().padding(.leading, 20)

                        ToggleRow(
                            title: "为检测到的验证码显示复制按钮",
                            description: "在受支持的通知中添加一键复制验证码的快捷操作。",
                            isOn: $settings.settings.showCopyButtonForVerificationCodes
                        )

                        Divider().padding(.leading, 20)

                        ToggleRow(
                            title: "自动复制验证码",
                            description: "检测到一次性验证码（OTP）时自动复制到剪贴板。",
                            isOn: $settings.settings.autoCopyVerificationCodes
                        )

                        Divider().padding(.leading, 20)

                        ToggleRow(
                            title: "灵动岛验证码弹窗",
                            description: "在灵动岛中显示专属的验证码弹窗。",
                            isOn: $settings.settings.otpLiveActivityEnabled
                        )

                        Divider().padding(.leading, 20)

                        ToggleRow(
                            title: "扫描“邮件”中的验证码",
                            description: "监听“邮件”应用中的未读邮件以提取验证码（无需 AI）。",
                            isOn: $settings.settings.mailOTPDetectionEnabled
                        )
                    }
                    .modifier(SettingsContainerModifier())
                    .disabled(!settings.settings.masterNotificationsEnabled)
                    .opacity(settings.settings.masterNotificationsEnabled ? 1.0 : 0.5)
                    .animation(.easeInOut, value: settings.settings.masterNotificationsEnabled)

                    VStack(alignment: .leading, spacing: 0) {
                        Text("智能收件箱")
                            .font(.headline)
                            .padding([.top, .horizontal])

                        ToggleRow(
                            title: "启用智能收件箱",
                            description: "无需 AI 的邮件增强功能：验证码识别与快递包裹追踪。",
                            isOn: $settings.settings.smartInboxEnabled
                        )

                        Divider().padding(.leading, 20)

                        ToggleRow(
                            title: "从邮件追踪包裹",
                            description: "识别“邮件”中的 UPS、FedEx、USPS、DHL 及 Amazon 快递单号。",
                            isOn: $settings.settings.parcelTrackingEnabled
                        )

                        Divider().padding(.leading, 20)

                        ToggleRow(
                            title: "灵动岛包裹状态弹窗",
                            description: "有运输中的快递时，在灵动岛中实时显示包裹状态。",
                            isOn: $settings.settings.parcelLiveActivityEnabled
                        )
                    }
                    .modifier(SettingsContainerModifier())

                    VStack(spacing: 0) {
                        ForEach(NotificationSource.allCases) { source in
                            NotificationToggleRowView(source: source)
                            if source != NotificationSource.allCases.last {
                                Rectangle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 1)
                                    .padding(.leading, 60)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("系统通知")
                                .font(.system(size: 14, weight: .medium))
                            Spacer()
                            SettingsSwitch(isOn: $settings.settings.systemNotificationsEnabled)
                                .animation(.default, value: settings.settings.systemNotificationsEnabled)
                        }
                        .padding(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))

                        Rectangle().fill(Color.white.opacity(0.2)).frame(height: 1).padding(.leading, 60)

                        Text("允许以下应用的通知：")
                            .font(.headline)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .disabled(!settings.settings.systemNotificationsEnabled)
                            .opacity(settings.settings.systemNotificationsEnabled ? 1.0 : 0.5)

                        AppTogglesListView(isEnabled: { app in binding(for: app) }, maxHeight: 360)
                            .disabled(!settings.settings.systemNotificationsEnabled)
                            .opacity(settings.settings.systemNotificationsEnabled ? 1.0 : 0.5)
                    }
                }
                .modifier(SettingsContainerModifier())
                .disabled(!settings.settings.masterNotificationsEnabled)
                .opacity(settings.settings.masterNotificationsEnabled ? 1.0 : 0.5)
                .animation(.easeInOut, value: settings.settings.masterNotificationsEnabled)

                RequiredPermissionsView(section: .notifications)
            }
            .padding(25)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func binding(for app: SystemApp) -> Binding<Bool> {
        return .init(
            get: { settings.settings.appNotificationStates[app.id, default: true] },
            set: { settings.settings.appNotificationStates[app.id] = $0 }
        )
    }
}

struct ProximityUnlockSettingsView: View {
    @EditingSettings var settings: SettingsEditingSession
    @ObservedObject private var authManager = AuthenticationManager.shared

    @State private var showPasswordPrompt = false
    @State private var showUnnamedDevices = false
    @State private var isFindingByDistance = false
    @State private var isCalibratingRSSI = false
    @State private var pendingFaceProfileAction: FaceProfileAction?
    @State private var newFaceIDWiFiNetworkName = ""
    @ObservedObject private var wifiMonitor = WiFiStatusMonitor.shared

    private let deviceRowHeight: CGFloat = 38
    private let maxDeviceListHeight: CGFloat = 228

    private struct FaceProfileAction: Identifiable {
        enum Kind {
            case register
            case append
            case delete
        }

        let id = UUID()
        let kind: Kind
        let profileName: String

        static func displayProfileName(_ name: String) -> String {
            switch name {
            case "Primary Face": return "主面容"
            case "Secondary Face": return "替用面容"
            default: return name
            }
        }

        var message: String {
            let displayName = Self.displayProfileName(profileName)
            switch kind {
            case .register: return "注册“\(displayName)”面容配置"
            case .append: return "向“\(displayName)”面容配置补充采集数据"
            case .delete: return "删除“\(displayName)”面容配置"
            }
        }
    }

    private func performFaceProfileAction(_ action: FaceProfileAction) {
        switch action.kind {
        case .register, .append:
            authManager.beginFaceRegistration(profileName: action.profileName)
        case .delete:
            authManager.deleteFaceProfile(name: action.profileName)
        }
    }

    private var isBluetoothEnabled: Binding<Bool> {
        Binding<Bool>(
            get: { settings.settings.bluetoothUnlockEnabled },
            set: { newValue in
                if newValue {
                    if !authManager.isPasswordSet {
                        showPasswordPrompt = true
                    } else {
                        settings.settings.bluetoothUnlockEnabled = true
                    }
                } else {
                    settings.settings.bluetoothUnlockEnabled = false
                }
            }
        )
    }

    private var isFaceIDEnabled: Binding<Bool> {
        Binding<Bool>(
            get: { settings.settings.faceIDUnlockEnabled },
            set: { newValue in
                if newValue {
                    if !authManager.isPasswordSet {
                        showPasswordPrompt = true
                    } else {
                        settings.settings.faceIDUnlockEnabled = true
                    }
                } else {
                    settings.settings.faceIDUnlockEnabled = false
                }
            }
        )
    }

    private var selectedDevice: Device? {
        guard let selectedIDString = authManager.selectedDeviceID,
              let selectedID = UUID(uuidString: selectedIDString) else { return nil }
        return authManager.scannedDevices.first { $0.id == selectedID } ?? authManager.ble.devices[selectedID]
    }

    private var filteredScannedDevices: [Device] {
        return showUnnamedDevices ? authManager.scannedDevices : authManager.scannedDevices.filter { $0.displayName != "Unnamed Device" }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                header
                InfoContainer(text: "警告：以下功能均处于开发阶段，可能无法按预期工作，并可能导致你的 Mac 发生意外解锁。请自行承担使用风险。", iconName: "exclamationmark.triangle.fill", color: .red)
                if settings.settings.faceIDUnlockEnabled {
                    InfoContainer(text: "启用 Face ID 会增加应用的内存占用。", iconName: "info.circle", color: .yellow)
                }
                authenticationSection
                faceIDSection
                bluetoothUnlockSection
                actionsSection
                RequiredPermissionsView(section: .bluetoothUnlock)
            }
            .padding(25)
        }
        .sheet(isPresented: $showPasswordPrompt) {
            PasswordPromptView(
                isPresented: $showPasswordPrompt,
                validate: { authManager.verifyMacLoginPassword($0) }
            ) { password in
                if authManager.verifyAndSavePassword(password) {
                    showPasswordPrompt = false
                }
            }
        }
        .sheet(item: $pendingFaceProfileAction) { action in
            PasswordPromptView(
                isPresented: Binding(
                    get: { pendingFaceProfileAction != nil },
                    set: { if !$0 { pendingFaceProfileAction = nil } }
                ),
                validate: { authManager.verifyPassword($0) },
                title: "需要 Face ID 身份验证",
                message: "请输入你的 Mac 登录密码以\(action.message)。"
            ) { _ in
                pendingFaceProfileAction = nil
                performFaceProfileAction(action)
            }
        }
        .sheet(item: $authManager.faceRegistrationController, onDismiss: {
            authManager.completeFaceRegistration()
        }) { controller in
            FaceIDRegistrationView(
                cameraController: controller,
                profileName: authManager.profileNameToRegister
            )
        }
        .sheet(isPresented: $isFindingByDistance) {
            FindDeviceByDistanceWizard()
        }
        .sheet(isPresented: $isCalibratingRSSI) {
            CalibrateRSSIView().environment(settings)
        }
        .onAppear {
            authManager.fetchRegisteredFaces()
            authManager.refreshFaceIDLocation()
        }
        .onDisappear {
            if authManager.isScanning {
                authManager.stopScan()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading) {
            Text("蓝牙靠近解锁与 Face ID").font(.largeTitle.bold())
            HStack {
                Button("立即锁定屏幕") { authManager.manualLock() }
                    .disabled(!settings.settings.bluetoothUnlockEnabled && !settings.settings.faceIDUnlockEnabled)
                Spacer()
                Text(authManager.status).font(.caption).foregroundColor(.secondary)
            }.padding(.top, 2)
        }
    }

    @ViewBuilder
    private var authenticationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("身份验证").font(.headline).padding([.horizontal, .top])
            if authManager.isPasswordSet {
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    Text("你的 Mac 密码已安全存储在钥匙串中。")
                    Spacer()
                    Button("更改") { showPasswordPrompt = true }
                    Button("移除", role: .destructive) {
                        authManager.removePassword()
                        var updated = settings.settings.value
                        updated.bluetoothUnlockEnabled = false
                        updated.faceIDUnlockEnabled = false
                        settings.settings.value = updated
                    }
                }.padding([.horizontal, .bottom])
            } else {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.yellow)
                    Text("要启用 Face ID 或蓝牙靠近解锁，请先提供你的 Mac 登录密码。")
                    Spacer()
                    Button("设置密码") { showPasswordPrompt = true }
                }.padding([.horizontal, .bottom])
            }
        }.modifier(SettingsContainerModifier())
    }

    @ViewBuilder
    private var faceIDSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ToggleRow(title: "启用 Face ID 解锁", description: "唤醒屏幕时通过面容识别解锁你的 Mac。", isOn: isFaceIDEnabled)
                .disabled(!authManager.isPasswordSet)

            if settings.settings.faceIDUnlockEnabled {
                Divider().padding(.leading, 20)

                let registeredFaces = authManager.registeredFaceProfiles
                if registeredFaces.isEmpty {
                    Text("尚未注册面容。请添加面容以开始使用 Face ID。")
                        .font(.caption).foregroundColor(.secondary).padding()
                } else {
                    ForEach(registeredFaces, id: \.self) { profileName in
                        HStack {
                            Image(systemName: "faceid").font(.title2).foregroundColor(.accentColor)
                            Text(FaceProfileAction.displayProfileName(profileName))
                            Spacer()
                            Button("重新录入") {
                                pendingFaceProfileAction = FaceProfileAction(kind: .register, profileName: profileName)
                            }
                            Button("删除", role: .destructive) {
                                pendingFaceProfileAction = FaceProfileAction(kind: .delete, profileName: profileName)
                            }
                        }.padding()
                    }
                }

                if registeredFaces.count < 2 {
                    HStack {
                        Spacer()
                        Button(action: {
                            let profileName = registeredFaces.isEmpty ? "Primary Face" : "Secondary Face"
                            pendingFaceProfileAction = FaceProfileAction(kind: .register, profileName: profileName)
                        }) { Label("添加面容", systemImage: "plus.circle.fill") }
                        .buttonStyle(.borderedProminent)
                        Spacer()
                    }.padding(.bottom)
                }

                Divider().padding(.leading, 20)
                faceIDLocationSection
                Divider().padding(.leading, 20)
                faceIDSecuritySection

                Divider().padding(.horizontal)
            }
        }
        .modifier(SettingsContainerModifier())
        .opacity(authManager.isPasswordSet ? 1.0 : 0.6)
    }

    @ViewBuilder
    private var faceIDLocationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("可用地点").font(.subheadline).bold().padding([.horizontal, .top])

            Picker("Face ID 生效范围", selection: $settings.settings.faceIDLocationPolicy) {
                ForEach(FaceIDLocationPolicy.allCases) { policy in
                    Text(policy.displayName).tag(policy)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if settings.settings.faceIDLocationPolicy == .selectedWiFiNetworks {
                Text("将受信任的 Wi-Fi 网络作为可用地点。连接其他网络或无法获取网络名称时，Face ID 将不会启动。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                HStack(spacing: 8) {
                    if let currentNetwork = wifiMonitor.state.networkName {
                        Button {
                            addFaceIDWiFiNetwork(currentNetwork)
                        } label: {
                            Label("使用“\(currentNetwork)”", systemImage: "wifi")
                        }
                        .disabled(settings.settings.faceIDAllowedWiFiNetworks.contains(currentNetwork))
                    } else {
                        Text("未检测到 Wi-Fi 网络")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button {
                        authManager.refreshFaceIDLocation()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("刷新当前 Wi-Fi 网络")
                }
                .padding(.horizontal)

                HStack(spacing: 8) {
                    TextField("Wi-Fi 网络名称", text: $newFaceIDWiFiNetworkName)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        addFaceIDWiFiNetwork(newFaceIDWiFiNetworkName)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(newFaceIDWiFiNetworkName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .help("添加 Wi-Fi 网络")
                }
                .padding(.horizontal)

                if settings.settings.faceIDAllowedWiFiNetworks.isEmpty {
                    Text("尚未添加受信任的地点。添加前 Face ID 将保持不可用状态。")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal)
                } else {
                    ForEach(settings.settings.faceIDAllowedWiFiNetworks, id: \.self) { networkName in
                        HStack {
                            Image(systemName: "wifi")
                                .foregroundStyle(.secondary)
                            Text(networkName)
                            Spacer()
                            Button {
                                settings.settings.faceIDAllowedWiFiNetworks.removeAll { $0 == networkName }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.red)
                            .help("移除“\(networkName)”")
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .padding(.bottom, 8)
    }

    private func addFaceIDWiFiNetwork(_ name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              !settings.settings.faceIDAllowedWiFiNetworks.contains(trimmedName) else { return }
        settings.settings.faceIDAllowedWiFiNetworks.append(trimmedName)
        newFaceIDWiFiNetworkName = ""
    }

    @ViewBuilder
    private var faceIDSecuritySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("安全性").font(.subheadline).bold().padding([.horizontal, .top])
            ToggleRow(
                title: "防伪活体检测",
                description: "防止他人使用照片、视频或屏幕翻拍解锁 Face ID。",
                isOn: $settings.settings.faceIDAntiSpoofEnabled
            )
            Divider().padding(.leading, 20)
            CustomSliderRowView(
                label: "防伪锁定触发时长",
                value: $settings.settings.faceIDSpoofLockDuration,
                range: 1...15,
                specifier: "%.0f 秒"
            )
            Text("持续检测到明显的伪造攻击达到该时长后（不含临界帧），将锁定 Face ID 并要求输入密码。")
                .font(.caption).foregroundColor(.secondary).padding(.horizontal).padding(.bottom, 4)
            Divider().padding(.leading, 20)
            CustomSliderRowView(
                label: "未匹配超时",
                value: $settings.settings.faceIDMismatchTimeout,
                range: 5...120,
                specifier: "%.0f 秒"
            )
            Text("在达到该时长仍未识别出你的面容时停止 Face ID 扫描。")
                .font(.caption).foregroundColor(.secondary).padding(.horizontal).padding(.bottom, 8)
            Divider().padding(.horizontal)
            Text("性能").font(.subheadline).bold().padding([.horizontal, .top])
            ToggleRow(
                title: "将模型常驻内存",
                description: "在两次解锁之间保持加载面容识别与活体检测模型，使 Face ID 从摄像头首帧起即可完成识别。",
                isOn: $settings.settings.faceIDKeepModelsInMemory
            )
            Text(settings.settings.faceIDKeepModelsInMemory
                 ? "约多占用 150–180 MB 内存。每次解锁可提前约 0.3 秒开始识别；当 macOS 清除了模型缓存后（如重启、系统更新或内存紧张后），最多可提速 2 秒。系统内存极度不足时会自动释放。"
                 : "模型仅在 Face ID 启动时加载，结束后立即释放，可节省约 150–180 MB 内存。每次解锁需等待约 0.3 秒加载模型；当 macOS 清除了模型缓存后，最多需等待 2 秒。")
                .font(.caption).foregroundColor(.secondary).padding(.horizontal).padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private var bluetoothUnlockSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ToggleRow(
                title: "启用蓝牙靠近解锁",
                description: "使用受信任的蓝牙设备自动锁定与解锁你的 Mac。",
                isOn: isBluetoothEnabled
            )
            .disabled(!authManager.isPasswordSet)

            Group {
                if settings.settings.bluetoothUnlockEnabled {
                    Divider().padding(.leading, 20)
                    deviceSelectionSection
                    Divider().padding(.horizontal)
                    sensitivitySection
                    Divider().padding(.horizontal)
                    advancedSection
                }
            }.transition(.opacity.combined(with: .move(edge: .top)))
        }
        .modifier(SettingsContainerModifier())
        .opacity(authManager.isPasswordSet ? 1.0 : 0.6)
        .animation(.default, value: settings.settings.bluetoothUnlockEnabled)
    }

    @ViewBuilder
    private var deviceSelectionSection: some View {
        let listHeight = min(maxDeviceListHeight, CGFloat(filteredScannedDevices.count) * deviceRowHeight)
        VStack(alignment: .leading, spacing: 10) {
            Text("受信任设备").font(.subheadline).bold().padding(.horizontal)
            if let device = selectedDevice {
                DeviceRowView(device: device, isSelected: true) {}.padding(.horizontal)
                HStack {
                    pairingStatusView
                    Spacer()
                    Button("校准距离") { isCalibratingRSSI = true }
                    Button("忽略此设备", role: .destructive) { authManager.forgetDevice() }
                }.padding(.horizontal)
            } else {
                VStack(spacing: 12) {
                    HStack {
                        Button(authManager.isScanning ? "停止扫描" : "扫描设备") {
                            if authManager.isScanning { authManager.stopScan() } else { authManager.startScan(includeUnnamed: showUnnamedDevices) }
                        }
                        if authManager.isScanning { ProgressView().scaleEffect(0.8).padding(.leading) }
                    }
                    Toggle(isOn: $showUnnamedDevices) { Text("显示未命名设备") }
                        .onChange(of: showUnnamedDevices) { _, newValue in authManager.updateScanFilter(includeUnnamed: newValue) }
                    if showUnnamedDevices && authManager.isScanning {
                        Button("按距离查找…") { isFindingByDistance = true }.font(.caption).padding(.top, 5).transition(.opacity)
                    }
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if authManager.scannedDevices.isEmpty && authManager.isScanning {
                                Text("正在扫描…").font(.caption).foregroundColor(.secondary).frame(minHeight: 80)
                            } else if filteredScannedDevices.isEmpty {
                                 Text(showUnnamedDevices ? "未找到设备。请确保设备在附近且处于可被发现状态。" : "未找到已命名设备。请尝试勾选“显示未命名设备”。")
                                     .font(.caption).foregroundColor(.secondary).frame(minHeight: 80).padding(.horizontal).multilineTextAlignment(.center)
                            } else {
                                ForEach(filteredScannedDevices) { device in
                                    DeviceRowView(device: device) { authManager.selectDevice(uuid: device.id) }
                                    if device.id != filteredScannedDevices.last?.id { Divider().padding(.leading, 50) }
                                }
                            }
                        }
                    }
                    .frame(height: listHeight)
                    .background(Color.black.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .animation(.spring(), value: listHeight)
                }.padding(.horizontal).animation(.default, value: showUnnamedDevices)
            }
        }.padding(.vertical)
    }

    @ViewBuilder
    private var sensitivitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("灵敏度").font(.subheadline).bold()
                if authManager.selectedDeviceID != nil {
                    Spacer()
                    let rssiString = authManager.lastRSSI.map { "\($0) dBm" } ?? "无信号"
                    Text("当前信号：\(rssiString)").font(.caption).foregroundColor(.secondary)
                }
            }.padding(.horizontal)
            VStack(spacing: 0) {
                CustomSliderRowView(label: "解锁信号阈值 (RSSI)", value: Binding(get: { Double(settings.settings.bluetoothUnlockUnlockRSSI) }, set: { settings.settings.bluetoothUnlockUnlockRSSI = Int($0) }), range: -100...0, specifier: "%.0f dBm")
                Divider().padding(.leading, 20)
                CustomSliderRowView(label: "锁定信号阈值 (RSSI)", value: Binding(get: { Double(settings.settings.bluetoothUnlockLockRSSI) }, set: { settings.settings.bluetoothUnlockLockRSSI = Int($0) }), range: -100...0, specifier: "%.0f dBm")
            }.padding(.top, 5)
        }.padding(.vertical)
    }

    @ViewBuilder
    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("高级").font(.subheadline).bold().padding(.horizontal)
            CustomSliderRowView(label: "锁定延迟", value: $settings.settings.bluetoothUnlockTimeout, range: 1...60, specifier: "%.0f 秒")
            Divider().padding(.leading, 20)
            CustomSliderRowView(label: "无信号超时", value: $settings.settings.bluetoothUnlockNoSignalTimeout, range: 10...300, specifier: "%.0f 秒")
            Divider().padding(.leading, 20)
            ToggleRow(title: "被动模式", description: "功耗更低，但响应速度可能略微变慢。", isOn: $settings.settings.bluetoothUnlockPassiveMode)
            Divider().padding(.leading, 20)
            CustomSliderRowView(label: "最低扫描信号阈值 (RSSI)", value: Binding(get: { Double(settings.settings.bluetoothUnlockMinScanRSSI) }, set: { settings.settings.bluetoothUnlockMinScanRSSI = Int($0) }), range: -100 ... -30, specifier: "%.0f dBm")
        }.padding(.vertical)
    }

    @ViewBuilder
    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("锁定与解锁动作").font(.headline).padding([.top, .horizontal])
            ToggleRow(title: "靠近时唤醒屏幕", description: "当你的设备进入感应范围时自动唤醒屏幕。", isOn: $settings.settings.bluetoothUnlockWakeOnProximity)
            Divider().padding(.leading, 20)
            ToggleRow(title: "仅唤醒不解锁", description: "仅点亮屏幕，不自动输入密码解锁。", isOn: $settings.settings.bluetoothUnlockWakeWithoutUnlocking)
            Divider().padding(.leading, 20)
            ToggleRow(title: "锁定时暂停“正在播放”", description: "屏幕锁定时自动暂停正在播放的音乐或视频。", isOn: $settings.settings.bluetoothUnlockPauseMusicOnLock)
            Divider().padding(.leading, 20)
            ToggleRow(title: "使用屏幕保护程序锁定", description: "启动屏幕保护程序，而非直接显示锁屏界面。", isOn: $settings.settings.bluetoothUnlockUseScreensaver)
            Divider().padding(.leading, 20)
            ToggleRow(title: "锁定时关闭屏幕", description: "锁定时让显示器进入睡眠状态。", isOn: $settings.settings.bluetoothUnlockTurnOffScreenOnLock)
        }.modifier(SettingsContainerModifier())
    }

    @ViewBuilder
    private var pairingStatusView: some View {
        HStack(spacing: 4) {
            switch authManager.monitoredPeripheralState {
            case .connected: Image(systemName: "checkmark.shield.fill").foregroundColor(.green); Text("已配对并监控中")
            case .connecting: ProgressView().scaleEffect(0.5); Text("正在连接…")
            case .disconnecting: Image(systemName: "xmark.shield.fill").foregroundColor(.gray); Text("正在断开连接…")
            case .disconnected: Image(systemName: "xmark.shield.fill").foregroundColor(.red); Text("超出范围")
            @unknown default: Image(systemName: "questionmark.circle.fill").foregroundColor(.gray); Text("未知状态")
            }
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }
}

fileprivate struct DeviceRowView: View {
    let device: Device
    var isSelected: Bool = false
    let action: () -> Void

    private var truncatedUUID: String {
        let fullUUID = device.id.uuidString
        return "\(fullUUID.prefix(8))...\(fullUUID.suffix(4))"
    }

    private func iconForDevice() -> String {
        if let name = device.peripheral?.name, let icon = IconMapper.icon(forName: name) {
            return icon
        }
        return "wave.3.right.circle"
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: iconForDevice())
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 1) {
                    Text(device.displayName)
                        .fontWeight(isSelected ? .semibold : .medium)
                        .foregroundColor(isSelected ? .accentColor : .primary)
                        .lineLimit(1)

                    Text(truncatedUUID)
                        .font(.caption2.monospaced())
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text("\(device.rssi) dBm")
                    .font(.caption.monospaced())
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

fileprivate struct FindDeviceByDistanceWizard: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var authManager = AuthenticationManager.shared

    @State private var wizardStep = 1
    @State private var closeReadings: [UUID: Int] = [:]
    @State private var countdown = 30
    @State private var timer: Timer?
    @State private var results: [DetectionResult] = []

    struct DetectionResult: Identifiable {
        let id: UUID
        let device: Device
        let score: Double
        let label: String
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("按距离查找设备").font(.largeTitle.bold())

            switch wizardStep {
            case 1: step1
            case 2: step2
            case 3: step3
            default: Text("发生错误。")
            }
        }
        .frame(width: 450, height: 400)
        .padding()
        .onAppear { authManager.startScan(includeUnnamed: true) }
        .onDisappear {
            timer?.invalidate()
            authManager.stopScan()
        }
    }

    @ViewBuilder
    private var step1: some View {
        Image(systemName: "arrow.down.to.line.compact").font(.system(size: 40)).foregroundColor(.accentColor)
        Text("第 1 步：将设备靠近").font(.title2)
        Text("请将目标设备尽可能靠近你的 Mac，然后点击“下一步”。").multilineTextAlignment(.center).foregroundColor(.secondary)

        let strongestDevice = authManager.scannedDevices.max(by: { $0.rssi < $1.rssi })
        Text("最强信号：\(strongestDevice?.displayName ?? "无")（\(strongestDevice?.rssi ?? -100) dBm）")
            .font(.body.bold()).padding()

        Button("下一步") {
            self.closeReadings = Dictionary(uniqueKeysWithValues: authManager.scannedDevices.map { ($0.id, $0.rssi) })
            self.wizardStep = 2
            startCountdown()
        }.buttonStyle(.borderedProminent)
    }

    @ViewBuilder
    private var step2: some View {
        Image(systemName: "arrow.up.right.and.arrow.down.left.rectangle").font(.system(size: 40)).foregroundColor(.accentColor)
        Text("第 2 步：将设备移远").font(.title2)
        Text("现在请将设备移至约 3 米（10 英尺）外，扫描将自动完成。").multilineTextAlignment(.center).foregroundColor(.secondary)

        Text("剩余时间：\(countdown) 秒")
            .font(.title3.bold().monospacedDigit()).padding()
        ProgressView(value: Double(30 - countdown), total: 30).frame(width: 200)
    }

    @ViewBuilder
    private var step3: some View {
        Image(systemName: "checkmark.shield.fill").font(.system(size: 40)).foregroundColor(.green)
        Text("第 3 步：选择你的设备").font(.title2)
        Text("根据信号强度的变化，以下是最匹配的候选设备。").multilineTextAlignment(.center).foregroundColor(.secondary)

        if results.isEmpty {
            Text("未检测到距离发生明显变化的设备。").foregroundColor(.secondary).padding()
        } else {
            List(results) { result in
                Button(action: {
                    authManager.selectDevice(uuid: result.id)
                    dismiss()
                }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(result.device.displayName)
                            Text(result.label)
                                .font(.caption)
                                .foregroundColor(labelColor(for: result.label))
                        }
                        Spacer()
                        Text(String(format: "%.0f", result.score))
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                    }
                }.buttonStyle(.plain)
            }
        }

        Button("完成") { dismiss() }.padding(.top)
    }

    private func startCountdown() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] _ in
            if countdown > 0 {
                countdown -= 1
            } else {
                timer?.invalidate()
                calculateResults()
                wizardStep = 3
            }
        }
    }

    private func calculateResults() {
        let farReadings = Dictionary(uniqueKeysWithValues: authManager.scannedDevices.map { ($0.id, $0.rssi) })
        var calculatedResults: [DetectionResult] = []

        for (id, closeRSSI) in closeReadings {
            guard let farRSSI = farReadings[id], let device = authManager.scannedDevices.first(where: { $0.id == id }) else { continue }

            let delta = Double(closeRSSI - farRSSI)
            let closeQuality = max(0, min(1, Double(closeRSSI + 85) / 30.0))

            if delta > 5 && closeQuality > 0.2 {
                let score = (delta * 0.7) + (closeQuality * 30 * 0.3)

                let label: String
                if score > 40 { label = "可能性极高" }
                else if score > 25 { label = "可能性较高" }
                else { label = "可能性较低" }

                calculatedResults.append(DetectionResult(id: id, device: device, score: score, label: label))
            }
        }

        self.results = calculatedResults.sorted { $0.score > $1.score }
    }

    private func labelColor(for label: String) -> Color {
        switch label {
        case "可能性极高": return .green
        case "可能性较高": return .orange
        default: return .secondary
        }
    }
}

fileprivate struct CalibrateRSSIView: View {
    @Environment(\.dismiss) var dismiss
    @EditingSettings var settings: SettingsEditingSession
    @ObservedObject private var authManager = AuthenticationManager.shared

    @State private var wizardStep = 1
    @State private var countdown = 5
    @State private var timer: Timer?
    @State private var rssiReadings: [Int] = []

    @State private var nearRSSI: Int?
    @State private var farRSSI: Int?

    @State private var isMeasuring = false

    @State private var calibratingDevice: Device?

    private var currentDeviceRSSI: Int? {
        if let device = calibratingDevice,
           let updatedDevice = authManager.scannedDevices.first(where: { $0.id == device.id }) {
            return updatedDevice.rssi
        }
        return calibratingDevice?.rssi
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("校准信号范围 (RSSI)").font(.largeTitle.bold())

            switch wizardStep {
            case 1: step1Near
            case 2: step2Far
            case 3: step3Results
            default: Text("发生错误。")
            }
        }
        .frame(width: 450, height: 400)
        .padding()
        .onAppear {
            if let selectedIDString = authManager.selectedDeviceID,
               let selectedID = UUID(uuidString: selectedIDString) {
                self.calibratingDevice = authManager.scannedDevices.first { $0.id == selectedID }
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    @ViewBuilder
    private var step1Near: some View {
        Image(systemName: "arrow.down.to.line.compact").font(.system(size: 40)).foregroundColor(.accentColor)
        Text("第 1 步：校准“近处”距离").font(.title2)
        Text("请将设备放在解锁使用 Mac 时的常规位置（例如触控板旁）。").multilineTextAlignment(.center).foregroundColor(.secondary)

        let rssiString = currentDeviceRSSI.map { "\($0) dBm" } ?? "正在等待信号…"

        if isMeasuring {
            VStack {
                ProgressView("正在测量…", value: Double(5 - countdown), total: 5)
                Text("当前信号：\(rssiString)")
                    .font(.body.bold().monospacedDigit()).padding()
            }
        } else {
             Text("当前信号：\(rssiString)")
                .font(.body.bold().monospacedDigit()).padding()
        }

        Button(isMeasuring ? "正在测量…" : "开始近处校准") {
            startMeasurement { avgRSSI in
                self.nearRSSI = avgRSSI
                self.wizardStep = 2
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(isMeasuring || calibratingDevice == nil)
    }

    @ViewBuilder
    private var step2Far: some View {
        Image(systemName: "arrow.up.right.and.arrow.down.left.rectangle").font(.system(size: 40)).foregroundColor(.accentColor)
        Text("第 2 步：校准“远处”距离").font(.title2)
        Text("现在请将设备移至你希望 Mac 自动锁定的距离。").multilineTextAlignment(.center).foregroundColor(.secondary)

        let rssiString = currentDeviceRSSI.map { "\($0) dBm" } ?? "正在等待信号…"

        if isMeasuring {
            VStack {
                ProgressView("正在测量…", value: Double(5 - countdown), total: 5)
                Text("当前信号：\(rssiString)")
                    .font(.body.bold().monospacedDigit()).padding()
            }
        } else {
             Text("当前信号：\(rssiString)")
                .font(.body.bold().monospacedDigit()).padding()
        }

        Button(isMeasuring ? "正在测量…" : "开始远处校准") {
            startMeasurement { avgRSSI in
                self.farRSSI = avgRSSI
                self.wizardStep = 3
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(isMeasuring || calibratingDevice == nil)
    }

    @ViewBuilder
    private var step3Results: some View {
        Image(systemName: "checkmark.shield.fill").font(.system(size: 40)).foregroundColor(.green)
        Text("校准完成").font(.title2)
        Text("以下是根据测量结果为你推荐的设置。").multilineTextAlignment(.center).foregroundColor(.secondary)

        if let near = nearRSSI, let far = farRSSI {
            let suggestedUnlock = min(-10, near + 5)
            let suggestedLock = max(-100, far - 5)

            VStack(alignment: .leading, spacing: 15) {
                Text("实测“近处”平均信号：**\(near) dBm**")
                Text("实测“远处”平均信号：**\(far) dBm**")
                Divider()
                Text("建议解锁信号阈值 (RSSI)：**\(suggestedUnlock) dBm**")
                    .foregroundColor(.green)
                Text("建议锁定信号阈值 (RSSI)：**\(suggestedLock) dBm**")
                    .foregroundColor(.red)
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)

            HStack {
                Button("完成") { dismiss() }

                Spacer()

                Button("应用设置") {
                    var updated = settings.settings.value
                    updated.bluetoothUnlockUnlockRSSI = suggestedUnlock
                    updated.bluetoothUnlockLockRSSI = suggestedLock
                    settings.settings.value = updated
                    dismiss()
                }.buttonStyle(.borderedProminent)
            }
            .padding(.top)

        } else {
            Text("测量数据缺失，请重试。")
                .foregroundColor(.red)
            Button("重新开始") {
                wizardStep = 1
            }
        }
    }

    private func startMeasurement(completion: @escaping (Int) -> Void) {
        isMeasuring = true
        rssiReadings.removeAll()
        countdown = 5

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] _ in
            if let rssi = currentDeviceRSSI {
                rssiReadings.append(rssi)
            }

            if countdown > 1 {
                countdown -= 1
            } else {
                timer?.invalidate()
                isMeasuring = false

                if !rssiReadings.isEmpty {
                    let average = rssiReadings.reduce(0, +) / rssiReadings.count
                    completion(average)
                } else {
                    completion(currentDeviceRSSI ?? -75)
                }
            }
        }
    }
}

struct FanControlSectionView: View {
    @ObservedObject private var fanManager = FanManager.shared
    @State private var fanToEditID: Int?

    private var isSheetPresented: Binding<Bool> {
        Binding<Bool>(
            get: { self.fanToEditID != nil },
            set: { isShowing in
                if !isShowing {
                    self.fanToEditID = nil
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("风扇控制").font(.headline).padding([.top, .horizontal])

            InfoContainer(text: "风扇控制功能目前处于测试阶段。空闲时风扇转速为 0 RPM 属于正常现象。", iconName: "fanblades.fill", color: .orange)
                .padding()

            if fanManager.fans.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("未在此系统上检测到风扇。")
                        .foregroundColor(.secondary)
                    Text("无风扇设计的 Mac（如部分 MacBook Air 机型）会始终显示此提示。否则，请确保已安装 Sapphire 辅助工具后重试。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("重新检测") {
                        Task { await fanManager.refreshHardwareState(forceRediscovery: true) }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            } else {
                ForEach($fanManager.fans) { $fan in
                    FanRowView(fan: $fan, onCustomize: { fanToEditID = fan.id })
                    if fan.id != fanManager.fans.last?.id {
                        Divider().padding(.leading, 20)
                    }
                }
                if fanManager.hasNonAutomaticFans {
                    HStack {
                        Text("退出 Sapphire 后，风扇将自动恢复为系统自动控制。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("全部恢复为自动") { fanManager.resetAllFansToAutomatic() }
                            .buttonStyle(.bordered)
                    }
                    .padding()
                }
            }
        }
        .modifier(SettingsContainerModifier())
        .sheet(isPresented: isSheetPresented) {
            if let id = fanToEditID, let fanIndex = fanManager.fans.firstIndex(where: { $0.id == id }) {
                FanControlSheetView(fan: $fanManager.fans[fanIndex], availableSensors: fanManager.sensors)
                    .environmentObject(fanManager)
            }
        }
        .environmentObject(fanManager)
        .onAppear { fanManager.beginPolling() }
        .onDisappear { fanManager.endPolling() }
    }
}

struct FanRowView: View {
    @Binding var fan: FanInfo
    let onCustomize: () -> Void
    @EnvironmentObject var fanManager: FanManager

    private var modeString: String {
        switch fanManager.fanModes[fan.id] {
        case .auto: return "自动"
        case .constant(let rpm): return "恒定 \(rpm) RPM"
        case .sensor(let key, _, _):
            return "传感器：\(SensorNameMap.name(for: key))"
        case .customCurve(let key, let points):
            return "自定义曲线（\(points.count) 个点）：\(SensorNameMap.name(for: key))"
        case nil: return "自动"
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(fan.name.contains("Fan") ? "风扇 \(fan.id + 1)" : fan.name)
                    .font(.headline)

                Text("最低：\(fan.minRPM) | 当前：\(fan.currentRPM) | 最高：\(fan.maxRPM) RPM")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)

                Text(modeString)
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }
            Spacer()
            Button("自定义…") { onCustomize() }
        }
        .padding()
    }
}

struct FanControlSheetView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var fanManager: FanManager
    @Binding var fan: FanInfo
    let availableSensors: [TemperatureSensor]

    @State private var selectedMode: Int
    @State private var constantRPM: Double
    @State private var sensorKey: String
    @State private var minTemp: Double
    @State private var maxTemp: Double
    @State private var curvePoints: [FanCurvePoint]

    init(fan: Binding<FanInfo>, availableSensors: [TemperatureSensor]) {
        self._fan = fan
        self.availableSensors = availableSensors

        let initialMode = FanManager.shared.fanModes[fan.wrappedValue.id] ?? .auto

        switch initialMode {
        case .auto:
            _selectedMode = State(initialValue: 0)
            _constantRPM = State(initialValue: Double(fan.wrappedValue.minRPM))
            _sensorKey = State(initialValue: availableSensors.first?.key ?? "")
            _minTemp = State(initialValue: 40)
            _maxTemp = State(initialValue: 75)
            _curvePoints = State(initialValue: FanManager.defaultCurvePoints(for: fan.wrappedValue))
        case .constant(let rpm):
            _selectedMode = State(initialValue: 1)
            _constantRPM = State(initialValue: Double(rpm))
            _sensorKey = State(initialValue: availableSensors.first?.key ?? "")
            _minTemp = State(initialValue: 40)
            _maxTemp = State(initialValue: 75)
            _curvePoints = State(initialValue: FanManager.defaultCurvePoints(for: fan.wrappedValue))
        case .sensor(let key, let minT, let maxT):
            _selectedMode = State(initialValue: 2)
            _constantRPM = State(initialValue: Double(fan.wrappedValue.minRPM))
            _sensorKey = State(initialValue: key)
            _minTemp = State(initialValue: Double(minT))
            _maxTemp = State(initialValue: Double(maxT))
            _curvePoints = State(initialValue: FanManager.defaultCurvePoints(for: fan.wrappedValue))
        case .customCurve(let key, let points):
            _selectedMode = State(initialValue: 3)
            _constantRPM = State(initialValue: Double(fan.wrappedValue.minRPM))
            _sensorKey = State(initialValue: key)
            _minTemp = State(initialValue: 40)
            _maxTemp = State(initialValue: 75)
            _curvePoints = State(initialValue: points.isEmpty ? FanManager.defaultCurvePoints(for: fan.wrappedValue) : points)
        }
    }

    private var selectedSensorValueString: String {
        if let sensor = availableSensors.first(where: { $0.key == sensorKey }) {
            return String(format: "%.1f°C", sensor.value)
        }
        return "不可用"
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("更改“\(fan.name.contains("Fan") ? "风扇 \(fan.id + 1)" : fan.name)”的风扇控制")
                .font(.title2.bold())

            Picker("控制模式", selection: $selectedMode) {
                Text("自动").tag(0)
                Text("恒定转速").tag(1)
                Text("基于传感器").tag(2)
                Text("自定义曲线").tag(3)
            }
            .pickerStyle(.segmented)
            .padding(.bottom)

            if selectedMode == 1 {
                VStack {
                    CustomSliderRowView(label: "风扇转速", value: $constantRPM, range: Double(fan.minRPM)...Double(fan.maxRPM), specifier: "%.0f RPM")
                }
            } else if selectedMode == 2 {
                sensorPickerSection
                CustomSliderRowView(label: "起始提速温度：", value: $minTemp, range: 20...100, specifier: "%.0f °C")
                    .onChange(of: minTemp) {
                        if minTemp > maxTemp { maxTemp = minTemp }
                    }
                CustomSliderRowView(label: "最高温度：", value: $maxTemp, range: 20...100, specifier: "%.0f °C")
                    .onChange(of: maxTemp) {
                        if maxTemp < minTemp { minTemp = maxTemp }
                    }
            } else if selectedMode == 3 {
                sensorPickerSection
                FanCurveEditorView(fan: fan, points: $curvePoints)
            } else {
                Text("风扇将由 macOS 自动控制。")
                    .foregroundColor(.secondary)
                    .frame(minHeight: 150, alignment: .center)
            }

            Spacer()

            HStack {
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("确定") { saveAndDismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(30)
        .frame(width: 580)
        .frame(minHeight: selectedMode == 3 ? 520 : 350)
    }

    @ViewBuilder
    private var sensorPickerSection: some View {
        VStack(spacing: 15) {
            HStack {
                Text("依据传感器：")
                Spacer()
                Picker("传感器", selection: $sensorKey) {
                    ForEach(availableSensors) { sensor in
                        HStack {
                            Text(sensor.name)
                            Spacer()
                            Text(String(format: "%.1f°C", sensor.value))
                                .foregroundColor(.secondary)
                        }.tag(sensor.key)
                    }
                }
                Text(selectedSensorValueString)
                    .font(.body.monospacedDigit())
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .trailing)
            }
        }
    }

    private func saveAndDismiss() {
        let newMode: FanControlMode
        switch selectedMode {
        case 1:
            newMode = .constant(rpm: Int(constantRPM))
        case 2:
            newMode = .sensor(sensorKey: sensorKey, minTemp: Int(minTemp), maxTemp: Int(maxTemp))
        case 3:
            let sortedPoints = curvePoints.sorted { $0.temperature < $1.temperature }
            newMode = .customCurve(sensorKey: sensorKey, points: sortedPoints)
        default:
            newMode = .auto
        }
        fanManager.setFanMode(for: fan.id, to: newMode)
        dismiss()
    }
}

private struct FanCurveEditorView: View {
    let fan: FanInfo
    @Binding var points: [FanCurvePoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("自定义风扇曲线").font(.headline)
                Spacer()
                Button("重置") {
                    points = FanManager.defaultCurvePoints(for: fan)
                }
                .buttonStyle(.borderless)
            }

            Text("设置各温度节点对应的转速，Sapphire 会在节点之间平滑插值。")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                VStack(spacing: 8) {
                    CustomSliderRowView(
                        label: "节点 \(index + 1) 温度",
                        value: Binding(
                            get: { Double(points[index].temperature) },
                            set: { points[index].temperature = Int($0) }
                        ),
                        range: 20...100,
                        specifier: "%.0f °C"
                    )
                    CustomSliderRowView(
                        label: "节点 \(index + 1) 转速",
                        value: Binding(
                            get: { Double(points[index].rpm) },
                            set: { points[index].rpm = Int($0) }
                        ),
                        range: Double(fan.minRPM)...Double(fan.maxRPM),
                        specifier: "%.0f RPM"
                    )
                    if points.count > 2 {
                        Button("移除节点", role: .destructive) {
                            points.remove(at: index)
                        }
                        .font(.caption)
                    }
                }
                if index < points.count - 1 {
                    Divider()
                }
            }

            if points.count < 6 {
                Button {
                    let lastTemp = points.last?.temperature ?? 60
                    let lastRPM = points.last?.rpm ?? fan.minRPM
                    points.append(FanCurvePoint(temperature: min(lastTemp + 10, 95), rpm: min(lastRPM + 500, fan.maxRPM)))
                } label: {
                    Label("添加节点", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

struct CalibrationView: View {
    @StateObject private var calibrationManager = CalibrationManager.shared
    @StateObject private var batteryMonitor = BatteryMonitor.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("电池校准").font(.headline).padding([.top, .horizontal])
            InfoContainer(
                text: "校准电池有助于 macOS 更准确地读取电池健康度与剩余续航时间。该过程可能需要数小时，包含一次完整的充放电循环。校准期间将阻止系统进入睡眠。",
                iconName: "gauge.high",
                color: .purple
            ).padding()

            VStack(spacing: 15) {
                if calibrationManager.isActive {
                    VStack(spacing: 8) {
                        Text(calibrationManager.state.description)
                            .font(.headline)
                            .foregroundColor(.secondary)

                        ProgressView(value: calibrationManager.progress)
                            .progressViewStyle(.linear)

                        Text(String(format: "已完成 %.1f%%", calibrationManager.progress * 100))
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button("取消校准", role: .destructive) {
                            calibrationManager.cancel()
                        }
                        .padding(.top, 5)
                    }

                } else {
                    VStack(spacing: 12) {
                        if calibrationManager.state == .done {
                             Text("电池校准已成功完成。")
                                .foregroundColor(.green)
                        } else if case .error(let message) = calibrationManager.state {
                            Text(message)
                                .foregroundColor(.red)
                        }

                        Text("开始前请确保你的 Mac 已连接电源。校准过程中请勿拔下电源或让 Mac 进入睡眠。")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button(action: {
                            calibrationManager.start()
                        }) {
                            Text("开始校准")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                        .disabled(batteryMonitor.currentState?.isPluggedIn == false)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .modifier(SettingsContainerModifier())
    }
}

struct LidAngleCaffeineSettingsView: View {
    @EditingSettings var settings: SettingsEditingSession
    @ObservedObject private var lidAngleSensor = LidAngleSensor.shared

    private var caffeineTriggerAngleBinding: Binding<Double> {
        $settings.settings.caffeinateLidAngleTrigger
    }

    private var currentAngleText: String {
        guard lidAngleSensor.isAvailable else { return "不可用" }
        return "\(Int(lidAngleSensor.angle.rounded()))°"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ToggleRow(
                title: "按屏幕开合角度黑屏",
                description: "处于保持唤醒状态时，当屏幕合至触发角度会将亮度降为零，但不会使显示器进入睡眠。",
                isOn: $settings.settings.caffeinateTurnOffScreenUsingLidAngle
            )

            Divider().padding(.leading, 20)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("当前屏幕开合角度")
                    Text(lidAngleSensor.statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(currentAngleText)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundColor(lidAngleSensor.isAvailable ? .primary : .secondary)
            }
            .padding()

            if settings.settings.caffeinateTurnOffScreenUsingLidAngle {
                Divider().padding(.leading, 20)
                CustomSliderRowView(
                    label: "触发角度",
                    value: caffeineTriggerAngleBinding,
                    range: 0...140,
                    specifier: "%.0f°"
                )
            }

            Divider().padding(.leading, 20)
            ToggleRow(
                title: "接近合盖时暂停媒体播放",
                description: "合盖接近闭合时自动暂停正在播放的媒体，重新掀开屏幕后恢复播放。",
                isOn: $settings.settings.lidAnglePauseMediaEnabled
            )

            if settings.settings.lidAnglePauseMediaEnabled {
                Divider().padding(.leading, 20)
                CustomSliderRowView(
                    label: "暂停媒体触发角度",
                    value: $settings.settings.lidAnglePauseMediaTrigger,
                    range: 0...140,
                    specifier: "%.0f°"
                )
            }

            Divider().padding(.leading, 20)
            ToggleRow(
                title: "接近合盖时静音系统音频",
                description: "合盖时静音所有系统音频输出，重新掀开超过阈值角度后取消静音。",
                isOn: $settings.settings.lidAngleMuteAudioEnabled
            )

            if settings.settings.lidAngleMuteAudioEnabled {
                Divider().padding(.leading, 20)
                CustomSliderRowView(
                    label: "静音触发角度",
                    value: $settings.settings.lidAngleMuteAudioTrigger,
                    range: 0...140,
                    specifier: "%.0f°"
                )
            }

            Divider().padding(.leading, 20)
            ToggleRow(
                title: "接近合盖时使显示器睡眠",
                description: "当屏幕角度低于设定角度时使显示器进入真正的 macOS 显示器睡眠，重新掀开时唤醒，并在显示器睡眠期间尽可能维持保持唤醒状态。",
                isOn: $settings.settings.lidAngleSleepDisplayEnabled
            )

            if settings.settings.lidAngleSleepDisplayEnabled {
                Divider().padding(.leading, 20)
                CustomSliderRowView(
                    label: "显示器睡眠触发角度",
                    value: $settings.settings.lidAngleSleepDisplayTrigger,
                    range: 0...140,
                    specifier: "%.0f°"
                )
            }

            Divider().padding(.leading, 20)
            ToggleRow(
                title: "合盖过程中启用低电量模式",
                description: "当屏幕半合时强制开启低电量模式，重新掀开后恢复原有状态。",
                isOn: $settings.settings.lidAngleLowPowerModeEnabled
            )

            if settings.settings.lidAngleLowPowerModeEnabled {
                Divider().padding(.leading, 20)
                CustomSliderRowView(
                    label: "低电量模式触发角度",
                    value: $settings.settings.lidAngleLowPowerModeTrigger,
                    range: 0...140,
                    specifier: "%.0f°"
                )
            }

        }
        .modifier(SettingsContainerModifier())
        .onAppear {
            lidAngleSensor.acquire(.caffeineSettingsPreview)
        }
        .onDisappear {
            lidAngleSensor.release(.caffeineSettingsPreview)
        }
    }

}

struct BatterySettingsView: View {
    @State private var selectedTab: String = "数据统计"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading) {
                Text("电池").font(.largeTitle.bold()).padding(.bottom, 10)
                ModernSegmentedPicker(
                    selection: $selectedTab,
                    options: ["数据统计", "电池配置"]
                )
                .padding(.bottom, 5)

            }
            .padding(.horizontal, 25).padding(.top, 25)

            Spacer()

            if selectedTab == "数据统计" {
                ModernBatteryStatsView()
            } else {
                BatteryConfigurationView()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedTab)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onReceive(NotificationCenter.default.publisher(for: .sapphireSettingsWillClose)) { _ in
            selectedTab = "电池配置"
        }
    }
}

struct DateRangePickerView: View {
    @Binding var selection: TimeRange

    @State private var showCustomPicker = false

    @State private var customStartDate: Date
    @State private var customEndDate: Date

    @Namespace private var datePickerNamespace

    init(selection: Binding<TimeRange>) {
        self._selection = selection

        if case .custom(let start, let end) = selection.wrappedValue {
            _customStartDate = State(initialValue: start)
            _customEndDate = State(initialValue: end)
        } else {
            _customStartDate = State(initialValue: Date())
            _customEndDate = State(initialValue: Date())
        }
    }

    private var isCustomSelected: Bool {
        if case .custom = selection {
            return true
        }
        return false
    }

    var body: some View {
        HStack(spacing: 8) {

            PickerButton(label: "24 小时", isSelected: selection == .last24Hours, namespace: datePickerNamespace) {
                updateSelection(.last24Hours)
            }
            PickerButton(label: "7 天", isSelected: selection == .last7Days, namespace: datePickerNamespace) {
                updateSelection(.last7Days)
            }
            PickerButton(label: "近一月", isSelected: selection == .lastMonth, namespace: datePickerNamespace) {
                updateSelection(.lastMonth)
            }
            PickerButton(label: "近一年", isSelected: selection == .lastYear, namespace: datePickerNamespace) {
                updateSelection(.lastYear)
            }

            PickerButton(label: "自定义", isSelected: isCustomSelected, namespace: datePickerNamespace) {
                showCustomPicker = true
            }
            .popover(isPresented: $showCustomPicker, attachmentAnchor: .point(.bottom)) {
                customDatePickerView
            }
        }
        .padding(5)
        .background(Color.black.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func updateSelection(_ newSelection: TimeRange) {
        withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.7)) {
            selection = newSelection
        }
    }

    private var customDatePickerView: some View {
        VStack(spacing: 15) {
            Text("选择自定义时间范围")
                .font(.headline)

            DatePicker("开始日期", selection: $customStartDate, in: ...customEndDate, displayedComponents: .date)
            DatePicker("结束日期", selection: $customEndDate, in: ...Date(), displayedComponents: .date)

            Button("应用") {
                withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.7)) {
                    selection = .custom(customStartDate, customEndDate)
                }
                showCustomPicker = false
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
        .padding()
        .frame(minWidth: 250)
    }
}

fileprivate struct PickerButton: View {
    let label: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Text(label)
            .font(.subheadline.weight(.bold))
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                            .matchedGeometryEffect(id: "datePickerPill", in: namespace)
                    }
                }
            )
            .foregroundColor(isSelected ? .primary : .secondary)
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
    }
}

struct HeroMetricsView: View {
    @ObservedObject var viewModel: BatteryStatsViewModel
    private var statusColor: Color {
        if viewModel.isCharging { return MaterialChartPalette.tertiary }
        if viewModel.batteryLevel < 20 { return MaterialChartPalette.error }
        if viewModel.batteryLevel < 50 { return MaterialChartPalette.warning }
        return MaterialChartPalette.primary
    }

    private var metricColumns: [GridItem] {
        [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    }

    private var chargingStatusValue: String {
        if viewModel.isCharging {
            let watts = abs(viewModel.powerConsumption)
            return watts > 0 ? String(format: "%.1f W", watts) : "充电中"
        }
        return viewModel.timeRemaining
    }

    private var batteryLevelLabel: Text {
        Text("\(viewModel.batteryLevel)")
            .font(.system(size: 64, weight: .bold, design: .rounded))
            .foregroundStyle(statusColor)
        + Text("%")
            .font(.system(size: 28, weight: .semibold, design: .rounded))
            .foregroundStyle(statusColor.opacity(0.7))
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("电池")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(MaterialChartPalette.onSurfaceVariant)
                batteryLevelLabel
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                MaterialStatChip(
                    label: viewModel.isCharging ? "正在充电" : "使用电池",
                    value: chargingStatusValue,
                    color: statusColor,
                    icon: viewModel.isCharging ? "bolt.fill" : "battery.100"
                )
            }
            .fixedSize(horizontal: true, vertical: false)

            LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 10) {
                MaterialStatChip(label: "剩余时间", value: viewModel.timeRemaining, color: MaterialChartPalette.primary, icon: "clock.fill")
                MaterialStatChip(label: "电池健康", value: "\(viewModel.maxCapacityPercentage)%", color: Color.pink, icon: "heart.fill")
                MaterialStatChip(label: "循环次数", value: "\(viewModel.cycleCount)", color: MaterialChartPalette.secondary, icon: "arrow.triangle.2.circlepath")
                MaterialStatChip(label: "温度", value: String(format: "%.1f°C", viewModel.temperature), color: MaterialChartPalette.error, icon: "thermometer.medium")
                MaterialStatChip(label: "功率", value: String(format: "%.1f W", abs(viewModel.powerConsumption)), color: MaterialChartPalette.warning, icon: "bolt.fill")
                MaterialStatChip(label: "电压", value: String(format: "%.2f V", viewModel.voltage / 1000.0), color: MaterialChartPalette.tertiary, icon: "wave.3.right")
                MaterialStatChip(label: "电流", value: String(format: "%.2f A", Double(abs(viewModel.amperage)) / 1000.0), color: MaterialChartPalette.primary, icon: "arrow.left.arrow.right")
                MaterialStatChip(label: "电池状况", value: viewModel.health, color: .pink, icon: "heart.text.square")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(22)
        .materialChartCard(accent: statusColor)
    }
}

struct SpecRow: View {
    let label: String, value: String, percentage: String?
    init(label: String, value: String, percentage: String? = nil) {
        self.label = label; self.value = value; self.percentage = percentage
    }
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(value)
                .fontWeight(.medium)
                .monospacedDigit()
                .lineLimit(1)
                .truncationMode(.middle)
                .multilineTextAlignment(.trailing)
                .frame(minWidth: 72, alignment: .trailing)
            Text(percentage ?? "")
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(percentage == nil ? .clear : .primary)
                .frame(width: 44, alignment: .trailing)
        }
        .font(.system(size: 12, design: .rounded))
    }
}

struct ComponentPowerBreakdownView: View {
    @ObservedObject var viewModel: BatteryStatsViewModel
    @ObservedObject private var statsManager = StatsManager.shared

    private static func finite(_ v: Double) -> Double {
        guard v.isFinite else { return 0 }
        return max(0, v)
    }

    private var systemLoad: Double { Self.finite(statsManager.currentStats?.systemPower ?? viewModel.powerConsumption) }
    private var batteryPower: Double { Self.finite(statsManager.currentStats?.batteryPower ?? viewModel.powerConsumption) }
    private var chargingPower: Double { (viewModel.isCharging && batteryPower < 0) ? abs(batteryPower) : 0 }
    private var adapterPower: Double { Self.finite(statsManager.currentStats?.sensors?.sensors.first { ["PDTR"].contains($0.key) }?.value ?? 0) }
    private var cpuPower: Double { Self.finite(statsManager.currentStats?.sensors?.sensors.first { ["PCPC", "PCTR", "PC0C"].contains($0.key) }?.value ?? 0) }
    private var gpuPower: Double { Self.finite(statsManager.currentStats?.sensors?.sensors.first { ["PGTR", "PG0C", "PCGC"].contains($0.key) }?.value ?? 0) }
    private var displayPower: Double { max(0, systemLoad - (cpuPower + gpuPower)) * 0.4 }
    private var otherPower: Double { max(0, systemLoad - (cpuPower + gpuPower + displayPower)) }
    private var isCharging: Bool { viewModel.isCharging }
    private var adapterConnected: Bool { (viewModel.powerAdapterInfo?.maxPower ?? 0) > 0 }

    private var heroWatts: Double { adapterConnected ? max(adapterPower, systemLoad) : systemLoad }

    private var statusLabel: String {
        if isCharging { return "正在充电" }
        if adapterConnected { return "电源适配器" }
        return "电池供电"
    }

    private var statusColor: Color {
        if isCharging { return MaterialChartPalette.tertiary }
        if adapterConnected { return MaterialChartPalette.primary }
        return MaterialChartPalette.warning
    }

    private var components: [(id: String, icon: String, title: String, power: Double, color: Color)] {
        var rows: [(id: String, icon: String, title: String, power: Double, color: Color)] = []
        if isCharging && chargingPower > 0.15 {
            rows.append(("charging", "battery.100.bolt", "电池充电", chargingPower, MaterialChartPalette.tertiary))
        }
        if cpuPower > 0.35 {
            rows.append(("cpu", "cpu", "CPU", cpuPower, Color.cyan))
        }
        if gpuPower > 0.35 {
            rows.append(("gpu", "cube.fill", "GPU", gpuPower, MaterialChartPalette.secondary))
        }
        if displayPower > 0.35 {
            rows.append(("display", "display", "显示器", displayPower, MaterialChartPalette.warning))
        }
        if otherPower > 0.35 {
            rows.append(("other", "ellipsis.circle", "其他", otherPower, MaterialChartPalette.onSurfaceVariant))
        }
        return rows
    }

    private var totalComponentPower: Double {
        max(components.reduce(0) { $0 + $1.power }, 0.001)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            powerHeroHeader
            if !components.isEmpty {
                shareStrip
                componentRows
            } else {
                Text("正在等待功耗传感器数据…")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(MaterialChartPalette.onSurfaceVariant)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .materialChartCard(accent: statusColor)
        .onAppear {
            statsManager.setPolling(for: "ComponentBreakdown", requiredStats: [.systemPower, .batteryPower, .cpu, .gpu])
        }
        .onDisappear {
            statsManager.setPolling(for: "ComponentBreakdown", requiredStats: [])
        }
    }

    private var powerHeroHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("系统功耗")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(MaterialChartPalette.onSurfaceVariant)
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 7, height: 7)
                    Text(statusLabel)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(statusColor)
                }
            }

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(String(format: "%.2f", heroWatts))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                Text("W")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(MaterialChartPalette.onSurfaceVariant)
                    .padding(.bottom, 4)
                Spacer(minLength: 0)
                Image(systemName: adapterConnected ? "powerplug.fill" : "battery.100")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(statusColor.opacity(0.85))
            }

            Capsule()
                .fill(statusColor)
                .frame(height: 3)
                .frame(maxWidth: 120, alignment: .leading)

            if adapterConnected || isCharging {
                HStack(spacing: 12) {
                    if adapterConnected {
                        metaChip(icon: "bolt.horizontal.fill", text: String(format: "适配器 %.0f W", adapterPower > 0 ? adapterPower : heroWatts))
                    }
                    metaChip(icon: "laptopcomputer", text: String(format: "功耗 %.2f W", systemLoad))
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func metaChip(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(MaterialChartPalette.onSurfaceVariant)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var shareStrip: some View {
        GeometryReader { geo in
            HStack(spacing: 3) {
                ForEach(components, id: \.id) { row in
                    Capsule()
                        .fill(row.color)
                        .frame(width: max(4, geo.size.width * CGFloat(row.power / totalComponentPower)))
                }
            }
        }
        .frame(height: 6)
    }

    private var componentRows: some View {
        VStack(spacing: 12) {
            ForEach(components, id: \.id) { row in
                PowerShareRow(
                    icon: row.icon,
                    title: row.title,
                    power: row.power,
                    fraction: row.power / totalComponentPower,
                    color: row.color
                )
            }
        }
    }
}

struct PowerShareRow: View {
    let icon: String
    let title: String
    let power: Double
    let fraction: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                Text(String(format: "%.2f W", power))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                Text(String(format: "%.0f%%", fraction * 100))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(MaterialChartPalette.onSurfaceVariant)
                    .frame(width: 36, alignment: .trailing)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(MaterialChartPalette.outline.opacity(0.55))
                        .frame(height: 3)
                    Capsule()
                        .fill(color)
                        .frame(width: max(3, geo.size.width * CGFloat(fraction)), height: 3)
                }
            }
            .frame(height: 3)
        }
    }
}

struct ModernBatteryStatsView: View {
    @StateObject private var viewModel = BatteryStatsViewModel()
    @StateObject private var historyViewModel = BatteryHistoryViewModel()
    @StateObject private var energyViewModel = EnergyViewModel()
    @StateObject private var helperManager = HelperManager.shared
    @ObservedObject private var debugMode = DebugMode.shared
    @State private var selectedTimeRange: TimeRange = .last24Hours

    private let mainGridLayout = [GridItem(.flexible(), spacing: 20), GridItem(.flexible(), spacing: 20)]

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 20) {
                if debugMode.isEnabled {
                    BatteryDebugMenu()
                }
                DateRangePickerView(selection: $selectedTimeRange)
                HStack(spacing: 15) {
                    HelperStatusBanner(helperManager: helperManager)
                }
                .padding()
                .materialChartCard(accent: helperManager.status == .enabled ? MaterialChartPalette.tertiary : MaterialChartPalette.warning)

                HeroMetricsView(viewModel: viewModel)

                ComponentPowerBreakdownView(viewModel: viewModel)

                BatteryHistoryView(historyViewModel: historyViewModel)

                LazyVGrid(columns: mainGridLayout, spacing: 20) {
                    MaxCapacityGraphCard(viewModel: viewModel, historyViewModel: historyViewModel, selectedTimeRange: $selectedTimeRange)
                    CycleCountGraphCard(viewModel: viewModel, historyViewModel: historyViewModel, selectedTimeRange: $selectedTimeRange)
                    TemperatureGraphCard(viewModel: viewModel, historyViewModel: historyViewModel, selectedTimeRange: $selectedTimeRange)
                    PowerTimeHistoryGraphView(historyViewModel: historyViewModel, selectedTimeRange: $selectedTimeRange)
                    BatteryHealthCard(viewModel: viewModel)
                    BatterySpecsCard(viewModel: viewModel)
                    PowerAdapterSpecsCard(viewModel: viewModel)
                    SignificantEnergyUsersView(viewModel: energyViewModel)
                }
            }
            .padding(.horizontal, 25)
            .padding(.bottom, 25)
        }
        .onAppear {
            viewModel.start(highFrequency: true)
            StatsManager.shared.setPolling(for: "BatterySettingsView", requiredStats: [.batteryPower], interval: .seconds(1))
            historyViewModel.fetchHistory(filtering: selectedTimeRange)
            energyViewModel.start()
        }
        .onDisappear {
            tearDownBatteryStats()
        }
        .onReceive(NotificationCenter.default.publisher(for: .sapphireSettingsWillClose)) { _ in
            tearDownBatteryStats()
        }
        .onReceive(BatteryDataLogger.shared.entriesDidChange) { _ in
            historyViewModel.fetchHistory(filtering: selectedTimeRange)
        }
        .onChange(of: selectedTimeRange) { _, newRange in
            historyViewModel.filterData(for: newRange)
        }
    }

    private func tearDownBatteryStats() {
        energyViewModel.stop()
        viewModel.stop()
        historyViewModel.releaseMemory()
        StatsManager.shared.setPolling(for: "BatterySettingsView", requiredStats: [])
    }
}

struct BatterySpecsCard: View {
    @ObservedObject var viewModel: BatteryStatsViewModel
    @ObservedObject private var statsManager = StatsManager.shared
    @ObservedObject private var powerModeManager = PowerModeManager.shared

    private var systemLoad: Double {
        statsManager.currentStats?.systemPower ?? abs(viewModel.powerConsumption)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "bolt.fill").foregroundStyle(MaterialChartPalette.warning)
                Text("电池参数").font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            Spacer()
            SpecRow(label: "电流", value: String(format: "%.1f A", Double(abs(viewModel.amperage)) / 1000.0))
            SpecRow(label: "电压", value: String(format: "%.1f V", viewModel.voltage / 1000.0))
            SpecRow(label: "功率", value: String(format: "%.0f W", abs(viewModel.powerConsumption)))
            SpecRow(label: "系统负载", value: String(format: "%.2f W", systemLoad))

            HStack {
                Text("低电量模式").font(.system(size: 12)).foregroundColor(.secondary)
                Spacer()
                Button(action: {
                    if powerModeManager.isLowPowerModeActive {
                        powerModeManager.disableLowPowerMode()
                    } else {
                        powerModeManager.enableLowPowerMode()
                    }
                }) {
                    Text(powerModeManager.isLowPowerModeActive ? "已开启" : "已关闭")
                        .font(.system(size: 12)).fontWeight(.medium)
                        .foregroundColor(powerModeManager.isLowPowerModeActive ? .green : .primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            (powerModeManager.isLowPowerModeActive ? Color.green.opacity(0.15) : Color.white.opacity(0.08)),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(16)
        .materialChartCard(height: 180, accent: MaterialChartPalette.warning)
        .onAppear {
            statsManager.setPolling(for: "BatterySettings", requiredStats: [.systemPower, .batteryPower])
            _ = powerModeManager.isLowPowerModeEnabled()
        }
        .onDisappear {
            statsManager.setPolling(for: "BatterySettings", requiredStats: [])
        }
    }
}

private extension Array where Element == BatteryLogEntry {
    func closest(to date: Date) -> BatteryLogEntry? {
        self.min {
            abs($0.timestamp.timeIntervalSince(date)) < abs($1.timestamp.timeIntervalSince(date))
        }
    }
}

private struct BatteryMetricGraphCard<Value: Plottable & Comparable>: View {
    let title: String
    let currentValue: String
    let color: Color
    let chartData: [BatteryLogEntry]
    @Binding var selectedTimeRange: TimeRange
    let yDomain: ClosedRange<Value>
    let yAxisMarkCount: Int
    let metricLabel: String
    let metricValue: (BatteryLogEntry) -> Value
    let annotationText: (BatteryLogEntry) -> String

    @State private var selectedDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title).font(.system(size: 15, weight: .semibold, design: .rounded))
                Spacer()
                Text(currentValue)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.14))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)

            Spacer()

            if chartData.isEmpty {
                EmptyStatsView(height: 150)
                    .padding(.horizontal, 16)
            } else {
                Chart {
                    ForEach(chartData) { entry in
                        LineMark(
                            x: .value("时间", entry.timestamp),
                            y: .value(metricLabel, metricValue(entry))
                        )
                        .foregroundStyle(MaterialChartPalette.lineGradient(for: color))
                        .interpolationMethod(.linear)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))

                        AreaMark(
                            x: .value("时间", entry.timestamp),
                            y: .value(metricLabel, metricValue(entry))
                        )
                        .foregroundStyle(MaterialChartPalette.tonalGradient(for: color))
                        .interpolationMethod(.linear)
                    }

                    if let selectedDate, let entry = chartData.closest(to: selectedDate) {
                        PointMark(
                            x: .value("时间", entry.timestamp),
                            y: .value(metricLabel, metricValue(entry))
                        )
                        .foregroundStyle(color)
                        .symbolSize(80)

                        RuleMark(x: .value("已选", selectedDate))
                            .foregroundStyle(MaterialChartPalette.outline)
                            .annotation(position: .top, alignment: .center) {
                                MaterialSelectionPill(text: annotationText(entry), color: color)
                            }
                    }
                }
                .materialChartPlotStyle()
                .chartYScale(domain: yDomain)
                .dynamicXAxis(for: selectedTimeRange, isVisible: true)
                .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: yAxisMarkCount)) }
                .chartXSelection(value: $selectedDate)
                .frame(height: 150)
                .padding(.horizontal, 12)
            }

            Spacer()
        }
        .materialChartCard(height: 220)
    }
}

struct MaxCapacityGraphCard: View {
    @ObservedObject var viewModel: BatteryStatsViewModel
    @ObservedObject var historyViewModel: BatteryHistoryViewModel
    @Binding var selectedTimeRange: TimeRange

    var body: some View {
        let chartData = historyViewModel.chartData.filter { $0.maxCapacity > 0 }
        let capacities = chartData.map(\.maxCapacity)

        BatteryMetricGraphCard(
            title: "最大容量",
            currentValue: "\(viewModel.maxCapacityPercentage)%",
            color: MaterialChartPalette.primary,
            chartData: chartData,
            selectedTimeRange: $selectedTimeRange,
            yDomain: ((capacities.min() ?? 0) - 50)...((capacities.max() ?? 8000) + 50),
            yAxisMarkCount: 3,
            metricLabel: "容量",
            metricValue: { $0.maxCapacity },
            annotationText: { "\($0.maxCapacity) mAh" }
        )
    }
}

struct CycleCountGraphCard: View {
    @ObservedObject var viewModel: BatteryStatsViewModel
    @ObservedObject var historyViewModel: BatteryHistoryViewModel
    @Binding var selectedTimeRange: TimeRange

    var body: some View {
        let chartData = historyViewModel.chartData.filter { $0.cycleCount > 0 }
        let cycles = chartData.map(\.cycleCount)

        BatteryMetricGraphCard(
            title: "循环次数",
            currentValue: "\(viewModel.cycleCount)",
            color: MaterialChartPalette.secondary,
            chartData: chartData,
            selectedTimeRange: $selectedTimeRange,
            yDomain: ((cycles.min() ?? 0) - 10)...((cycles.max() ?? 1000) + 10),
            yAxisMarkCount: 3,
            metricLabel: "循环次数",
            metricValue: { $0.cycleCount },
            annotationText: { "\($0.cycleCount) 次循环" }
        )
    }
}

struct TemperatureGraphCard: View {
    @ObservedObject var viewModel: BatteryStatsViewModel
    @ObservedObject var historyViewModel: BatteryHistoryViewModel
    @Binding var selectedTimeRange: TimeRange

    var body: some View {
        BatteryMetricGraphCard(
            title: "温度",
            currentValue: String(format: "%.1f °C", viewModel.temperature),
            color: MaterialChartPalette.error,
            chartData: historyViewModel.chartData.filter { $0.temperature > 0 },
            selectedTimeRange: $selectedTimeRange,
            yDomain: 20...55,
            yAxisMarkCount: 4,
            metricLabel: "温度",
            metricValue: { $0.temperature },
            annotationText: { String(format: "%.1f °C", $0.temperature) }
        )
    }
}

struct PowerTimeHistoryGraphView: View {
    @ObservedObject var historyViewModel: BatteryHistoryViewModel
    @Binding var selectedTimeRange: TimeRange
    @State private var selectedDate: Date?

    var body: some View {
        let powerData = historyViewModel.chartData.filter { $0.powerConsumption > 0 }
        let timeData = historyViewModel.chartData.filter { $0.timeRemainingMinutes > 0 }

        VStack(alignment: .leading, spacing: 0) {
            Text("功耗与剩余时间")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .padding(.horizontal, 18)
                .padding(.top, 16)

            Spacer()

            if powerData.isEmpty && timeData.isEmpty {
                EmptyStatsView(height: 150)
                    .padding(.horizontal, 16)
            } else {
                Chart {
                    ForEach(powerData) { entry in
                        LineMark(x: .value("时间", entry.timestamp), y: .value("功率", entry.powerConsumption))
                            .foregroundStyle(by: .value("指标", "功率 (W)"))
                            .interpolationMethod(.linear)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    }
                    ForEach(timeData) { entry in
                        LineMark(x: .value("时间", entry.timestamp), y: .value("时长", Double(entry.timeRemainingMinutes) / 60.0))
                            .foregroundStyle(by: .value("指标", "时长 (h)"))
                            .interpolationMethod(.linear)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    }

                    if let selectedDate {
                        if let powerEntry = powerData.closest(to: selectedDate) {
                            PointMark(x: .value("时间", powerEntry.timestamp), y: .value("功率", powerEntry.powerConsumption))
                                .foregroundStyle(MaterialChartPalette.primary)
                                .symbolSize(80)
                        }
                        if let timeEntry = timeData.closest(to: selectedDate) {
                            PointMark(x: .value("时间", timeEntry.timestamp), y: .value("时长", Double(timeEntry.timeRemainingMinutes) / 60.0))
                                .foregroundStyle(MaterialChartPalette.tertiary)
                                .symbolSize(80)
                        }

                        RuleMark(x: .value("已选", selectedDate))
                            .foregroundStyle(MaterialChartPalette.outline)
                            .annotation(position: .top, alignment: .center) {
                                annotationView(for: selectedDate, powerData: powerData, timeData: timeData)
                            }
                    }
                }
                .materialChartPlotStyle()
                .chartForegroundStyleScale([
                    "功率 (W)": MaterialChartPalette.primary,
                    "时长 (h)": MaterialChartPalette.tertiary
                ])
                .dynamicXAxis(for: selectedTimeRange, isVisible: true)
                .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) }
                .chartXSelection(value: $selectedDate)
                .frame(height: 150)
                .padding(.horizontal, 12)
            }

            Spacer()
        }
        .materialChartCard(height: 220)
    }

    @ViewBuilder
    private func annotationView(for date: Date, powerData: [BatteryLogEntry], timeData: [BatteryLogEntry]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let powerEntry = powerData.closest(to: date) {
                Text(String(format: "%.2f W", powerEntry.powerConsumption))
                    .font(.caption)
                    .foregroundColor(.yellow)
            }
            if let timeEntry = timeData.closest(to: date) {
                Text(String(format: "%.1f 小时", Double(timeEntry.timeRemainingMinutes) / 60.0))
                    .font(.caption)
                    .foregroundColor(.mint)
            }
        }
        .padding(4)
        .background(.background)
        .cornerRadius(4)
    }

}

struct BatteryHistoryView: View {
    @ObservedObject var historyViewModel: BatteryHistoryViewModel
    @State private var selectedEntry: BatteryLogEntry?
    @State private var hoveredDate: Date?

    private var hoveredEntry: BatteryLogEntry? {
        guard let hoveredDate else { return nil }
        return historyViewModel.chartData.closest(to: hoveredDate)
    }

    private var summaryStats: (min: Int, max: Int, avg: Int, avgTemp: Double, avgPower: Double)? {
        let data = historyViewModel.chartData
        guard !data.isEmpty else { return nil }
        let charges = data.map(\.charge)
        let temps = data.map(\.temperature).filter { $0 > 0 }
        let powers = data.map(\.powerConsumption).filter { $0 > 0 }
        return (
            min: charges.min() ?? 0,
            max: charges.max() ?? 0,
            avg: Int((Double(charges.reduce(0, +)) / Double(charges.count)).rounded()),
            avgTemp: temps.isEmpty ? 0 : temps.reduce(0, +) / Double(temps.count),
            avgPower: powers.isEmpty ? 0 : powers.reduce(0, +) / Double(powers.count)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("电池使用历史")
                        .font(.system(size: 24, weight: .bold, design: .rounded))

                    if !historyViewModel.chartData.isEmpty {
                        Text("\(historyViewModel.chartData.count) 个数据点")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let stats = summaryStats {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            StatPill(label: "最低", value: "\(stats.min)%", color: MaterialChartPalette.warning)
                            StatPill(label: "平均", value: "\(stats.avg)%", color: MaterialChartPalette.primary)
                            StatPill(label: "最高", value: "\(stats.max)%", color: MaterialChartPalette.tertiary)
                            if stats.avgTemp > 0 {
                                StatPill(label: "温度", value: String(format: "%.0f°", stats.avgTemp), color: MaterialChartPalette.error)
                            }
                            if stats.avgPower > 0 {
                                StatPill(label: "功耗", value: String(format: "%.1fW", stats.avgPower), color: MaterialChartPalette.warning)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 10)

            historyLegend
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            if historyViewModel.isLoading {
                ProgressView()
                    .frame(height: 320, alignment: .center)
                    .frame(maxWidth: .infinity)
            } else if historyViewModel.chartData.isEmpty {
                EmptyHistoryView()
            } else {
                chartView
                    .frame(height: 320)
                    .padding(.horizontal, 20)

                if let entry = selectedEntry {
                    BatteryDataPointCard(entry: entry, onDismiss: {
                        withAnimation(.easeOut(duration: 0.18)) {
                            selectedEntry = nil
                        }
                    })
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .padding(.bottom, 20)
        .materialChartCard()
        .animation(.easeOut(duration: 0.2), value: selectedEntry?.id)
    }

    private var historyLegend: some View {
        HStack(spacing: 10) {
            legendChip(label: "正在充电", color: MaterialChartPalette.tertiary)
            legendChip(label: "暂停充电", color: MaterialChartPalette.primary)
            legendChip(label: "电池供电", color: MaterialChartPalette.warning)
            legendChip(label: "低电量", color: MaterialChartPalette.error)
            Spacer(minLength: 0)
            Text("线条颜色代表电源状态")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(MaterialChartPalette.onSurfaceVariant.opacity(0.75))
        }
    }

    private func legendChip(label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Capsule()
                .fill(color)
                .frame(width: 14, height: 3)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(MaterialChartPalette.onSurfaceVariant)
                .lineLimit(1)
        }
        .frame(width: 100)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(MaterialChartPalette.surfaceContainer, in: Capsule())
    }

    private var chargeLineSegments: [(id: String, color: Color, a: BatteryLogEntry, b: BatteryLogEntry)] {
        let data = historyViewModel.chartData
        guard data.count >= 2 else { return [] }

        var segments: [(id: String, color: Color, a: BatteryLogEntry, b: BatteryLogEntry)] = []
        segments.reserveCapacity(data.count - 1)
        for i in 0..<(data.count - 1) {
            let a = data[i]
            let b = data[i + 1]
            segments.append((
                id: "\(a.id.uuidString)-\(b.id.uuidString)",
                color: statusColor(for: a),
                a: a,
                b: b
            ))
        }
        return segments
    }

    private var chartView: some View {
        Chart {
            ForEach(historyViewModel.chartData) { entry in
                AreaMark(
                    x: .value("时间", entry.timestamp),
                    y: .value("电量", entry.charge)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.white.opacity(0.10), Color.white.opacity(0.02), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.linear)
            }

            ForEach(chargeLineSegments, id: \.id) { segment in
                LineMark(
                    x: .value("时间", segment.a.timestamp),
                    y: .value("电量", segment.a.charge),
                    series: .value("分段", segment.id)
                )
                .foregroundStyle(segment.color)
                .interpolationMethod(.linear)
                .lineStyle(StrokeStyle(lineWidth: 2.75, lineCap: .round, lineJoin: .round))

                LineMark(
                    x: .value("时间", segment.b.timestamp),
                    y: .value("电量", segment.b.charge),
                    series: .value("分段", segment.id)
                )
                .foregroundStyle(segment.color)
                .interpolationMethod(.linear)
                .lineStyle(StrokeStyle(lineWidth: 2.75, lineCap: .round, lineJoin: .round))
            }

            if let entry = hoveredEntry ?? selectedEntry {
                RuleMark(x: .value("已选", entry.timestamp))
                    .foregroundStyle(MaterialChartPalette.outlineStrong)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))

                PointMark(
                    x: .value("时间", entry.timestamp),
                    y: .value("电量", entry.charge)
                )
                .foregroundStyle(statusColor(for: entry))
                .symbolSize(selectedEntry?.id == entry.id ? 120 : 90)
                .annotation(position: .top, spacing: 6) {
                    if selectedEntry == nil {
                        MaterialSelectionPill(
                            text: "\(entry.charge)% · \(entry.timestamp.formatted(date: .omitted, time: .shortened))",
                            color: statusColor(for: entry)
                        )
                    }
                }
            }
        }
        .materialChartPlotStyle()
        .chartYScale(domain: 0...108)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                    .foregroundStyle(MaterialChartPalette.outline.opacity(0.7))
                AxisValueLabel {
                    if let intValue = value.as(Int.self) {
                        Text("\(intValue)%")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(MaterialChartPalette.onSurfaceVariant)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(position: .bottom, values: .automatic(desiredCount: 6)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(MaterialChartPalette.outline)
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, style: .time)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(MaterialChartPalette.onSurfaceVariant)
                    }
                }
            }
        }
        .chartXSelection(value: $hoveredDate)
        .simultaneousGesture(TapGesture().onEnded {
            if let entry = hoveredEntry {
                withAnimation(.easeOut(duration: 0.18)) {
                    if selectedEntry?.id == entry.id {
                        selectedEntry = nil
                    } else {
                        selectedEntry = entry
                    }
                }
            }
        })
        .padding(.bottom, 8)
    }

    private func statusColor(for entry: BatteryLogEntry) -> Color {
        if entry.isCharging && entry.isPluggedIn { return MaterialChartPalette.tertiary }
        if entry.isPluggedIn && !entry.isCharging { return MaterialChartPalette.primary }
        if entry.charge <= 20 && !entry.isPluggedIn { return MaterialChartPalette.error }
        if !entry.isPluggedIn { return MaterialChartPalette.warning }
        return MaterialChartPalette.primary
    }
}
struct StatPill: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)

            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .cornerRadius(12)
        .fixedSize(horizontal: true, vertical: false)
    }
}

struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.downtrend.xyaxis")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))

            Text("暂无历史数据")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("采集到电池使用数据后将在此显示")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(height: 320)
        .frame(maxWidth: .infinity)
    }
}

struct BatteryDataPointCard: View {
    let entry: BatteryLogEntry
    let onDismiss: () -> Void

    private var statusLabel: String {
        if entry.isCharging && entry.isPluggedIn { return "正在充电" }
        if entry.isPluggedIn && !entry.isCharging { return "暂停充电" }
        if entry.charge <= 20 { return "低电量" }
        if !entry.isPluggedIn { return "电池供电" }
        return "正常"
    }

    private var statusColor: Color {
        if entry.isCharging && entry.isPluggedIn { return MaterialChartPalette.tertiary }
        if entry.isPluggedIn && !entry.isCharging { return MaterialChartPalette.primary }
        if entry.charge <= 20 { return MaterialChartPalette.error }
        if !entry.isPluggedIn { return MaterialChartPalette.warning }
        return MaterialChartPalette.onSurfaceVariant
    }

    private var timeRemainingText: String {
        guard entry.timeRemainingMinutes > 0 else { return "—" }
        let hours = entry.timeRemainingMinutes / 60
        let minutes = entry.timeRemainingMinutes % 60
        if hours > 0 { return "\(hours)小时 \(minutes)分" }
        return "\(minutes)分钟"
    }

    private var ledLabel: String {
        switch entry.ledColor {
        case 1: return "绿色"
        case 2: return "琥珀色"
        case 3: return "红色"
        case 0: return "熄灭"
        default: return "\(entry.ledColor)"
        }
    }

    private var detailRows: [(section: String, rows: [(icon: String, label: String, value: String, color: Color)])] {
        [
            ("电量", [
                ("battery.100", "电量", "\(entry.charge)%", statusColor),
                ("cpu", "硬件电量", "\(entry.hardwareCharge)%", MaterialChartPalette.primary),
                ("heart.fill", "最大容量", "\(entry.maxCapacity) mAh", .pink),
                ("arrow.clockwise", "循环次数", "\(entry.cycleCount)", MaterialChartPalette.secondary),
            ]),
            ("功耗", [
                ("bolt.fill", "功率消耗", entry.powerConsumption > 0 ? String(format: "%.2f W", entry.powerConsumption) : "—", MaterialChartPalette.warning),
                ("clock.fill", entry.isCharging ? "充满所需时间" : "剩余使用时间", timeRemainingText, MaterialChartPalette.primary),
                ("thermometer.medium", "温度", String(format: "%.1f °C", entry.temperature), entry.temperature > 40 ? MaterialChartPalette.error : MaterialChartPalette.tertiary),
            ]),
            ("状态", [
                ("powerplug.fill", "电源适配器", entry.isPluggedIn ? "已连接" : "未连接", entry.isPluggedIn ? MaterialChartPalette.tertiary : .gray),
                ("bolt.circle", "充电中", entry.isCharging ? "是" : "否", entry.isCharging ? MaterialChartPalette.tertiary : .gray),
                ("slider.horizontal.3", "充电管理", entry.managementState.rawValue, MaterialChartPalette.secondary),
                ("leaf.fill", "低电量模式", entry.isLowPowerMode ? "开启" : "关闭", entry.isLowPowerMode ? MaterialChartPalette.warning : .gray),
            ]),
            ("系统", [
                ("display", "屏幕", entry.isScreenOn ? "亮屏" : "息屏", entry.isScreenOn ? MaterialChartPalette.primary : .gray),
                ("moon.fill", "睡眠状态", entry.isSleeping ? "是" : "否", entry.isSleeping ? MaterialChartPalette.secondary : .gray),
                ("light.max", "指示灯", ledLabel, MaterialChartPalette.onSurfaceVariant),
                ("calendar", "记录时间", entry.timestamp.formatted(date: .abbreviated, time: .standard), MaterialChartPalette.onSurfaceVariant),
            ]),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(entry.charge)%")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(statusColor)
                        .monospacedDigit()
                    Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(MaterialChartPalette.onSurfaceVariant)
                }

                Spacer()

                Text(statusLabel)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(statusColor.opacity(0.16), in: Capsule())

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(MaterialChartPalette.onSurfaceVariant)
                        .frame(width: 28, height: 28)
                        .background(MaterialChartPalette.surfaceContainer, in: Circle())
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)],
                alignment: .leading,
                spacing: 16
            ) {
                ForEach(detailRows, id: \.section) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.section.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(MaterialChartPalette.onSurfaceVariant)
                            .tracking(0.6)

                        VStack(spacing: 0) {
                            ForEach(Array(section.rows.enumerated()), id: \.offset) { index, row in
                                BatteryAlignedDetailRow(
                                    icon: row.icon,
                                    label: row.label,
                                    value: row.value,
                                    color: row.color
                                )
                                if index < section.rows.count - 1 {
                                    Divider().opacity(0.35)
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            MaterialChartPalette.surfaceContainer,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(MaterialChartPalette.surfaceContainer.opacity(0.55), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(MaterialChartPalette.outline, lineWidth: 1)
        )
    }
}

private struct BatteryAlignedDetailRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 18, alignment: .center)
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(MaterialChartPalette.onSurfaceVariant)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .frame(minWidth: 84, alignment: .trailing)
        }
        .padding(.vertical, 7)
    }
}

struct BatteryHealthCard: View {
    @ObservedObject var viewModel: BatteryStatsViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "heart.fill").foregroundStyle(.pink)
                Text("电池健康").font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            Spacer()
            SpecRow(label: "设计容量", value: "\(viewModel.designCapacity) mAh", percentage: "100%")
            SpecRow(label: "最大容量", value: "\(viewModel.maxCapacity) mAh", percentage: "\(viewModel.maxCapacityPercentage)%")
            SpecRow(label: "macOS 容量", value: "\(viewModel.appleMaxCapacity) mAh", percentage: "\(viewModel.appleMaxCapacityPercentage)%")
            SpecRow(label: "macOS 电池状况", value: viewModel.health)
            SpecRow(label: "循环次数", value: "\(viewModel.cycleCount)")
            Spacer()
        }
        .padding(16)
        .materialChartCard(height: 180, accent: .pink)
    }
}

struct PowerAdapterSpecsCard: View {
    @ObservedObject var viewModel: BatteryStatsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "powerplug.fill")
                    .foregroundStyle(MaterialChartPalette.onSurfaceVariant)
                Text("电源适配器参数")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }

            if let info = viewModel.powerAdapterInfo, info.maxPower > 0 {
                if info.current > 0 || info.maxCurrent > 0 {
                    PowerAdapterSpecRow(
                        label: "电流",
                        currentValue: info.current > 0 ? "\(Double(info.current) / 1000.0, default: "%.2f") A" : "0.0 A",
                        maxValue: info.maxCurrent > 0 ? "\(Double(info.maxCurrent) / 1000.0, default: "%.1f") A" : "—"
                    )
                }

                if info.voltage > 0 || info.maxVoltage > 0 {
                    PowerAdapterSpecRow(
                        label: "电压",
                        currentValue: info.voltage > 0 ? "\(Double(info.voltage) / 1000.0, default: "%.1f") V" : "0.0 V",
                        maxValue: info.maxVoltage > 0 ? "\(Double(info.maxVoltage) / 1000.0, default: "%.1f") V" : "—"
                    )
                }

                PowerAdapterSpecRow(
                    label: "功率",
                    currentValue: "\(Double(info.power), default: "%.1f") W",
                    maxValue: "\(info.maxPower) W"
                )

                if !info.name.isEmpty && info.name != "N/A" {
                    SpecRow(label: "名称", value: info.name)
                }

                if !info.manufacturer.isEmpty && info.manufacturer != "N/A" {
                    SpecRow(label: "制造商", value: info.manufacturer)
                }

                if !info.serialNumber.isEmpty && info.serialNumber != "N/A" {
                    SpecRow(label: "序列号", value: info.serialNumber)
                }
            } else {
                Text("未连接")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .materialChartCard(minHeight: 180, accent: .gray)
    }
}

fileprivate struct PowerAdapterSpecRow: View {
    let label: String
    let currentValue: String
    let maxValue: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(currentValue)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .monospacedDigit()
                .frame(minWidth: 56, alignment: .trailing)
            Text("/")
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.secondary)
            Text(maxValue)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .monospacedDigit()
                .frame(minWidth: 48, alignment: .trailing)
        }
    }
}

struct SignificantEnergyUsersView: View {
    @ObservedObject var viewModel: EnergyViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("高能耗应用")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
            Spacer()
            if viewModel.topProcesses.isEmpty {
                Text("没有高能耗应用")
                    .font(.caption).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                ForEach(viewModel.topProcesses) { process in
                    HStack {
                        Text(process.name).font(.caption)
                        Spacer()
                        Text(String(format: "%.2f%%", process.usage))
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(MaterialChartPalette.primary.opacity(0.14), in: Capsule())
                    }
                }
            }
            Spacer()
        }
        .padding(16)
        .materialChartCard(height: 180, accent: MaterialChartPalette.primary)
    }
}
struct EmptyStatsView: View {
    var height: CGFloat
    var body: some View {
        VStack {
            Image(systemName: "chart.bar.xaxis").font(.largeTitle).foregroundColor(.secondary.opacity(0.3))
            Text("暂无历史记录").font(.caption).foregroundColor(.secondary)
        }
        .frame(height: height).frame(maxWidth: .infinity)
    }
}

struct HealthStatRow: View {
    let label: String, value: String, percentage: Int
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(.caption).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.caption.weight(.semibold)).multilineTextAlignment(.trailing)
            Text("\(percentage)%").font(.caption.weight(.semibold)).frame(width: 35, alignment: .trailing)
        }
    }
}
struct SimpleHealthStatRow: View {
    let label: String, value: String
    var body: some View {
        HStack {
            Text(label).font(.caption).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.caption.weight(.semibold))
        }
    }
}

struct PowerRow: View {
    let label: String, value: String, color: Color?
    var body: some View {
        HStack {
            Text(label).font(.caption).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.caption.weight(.semibold)).foregroundColor(color ?? .primary)
        }
    }
}

struct BatteryConfigurationView: View {
    @EditingSettings var settings: SettingsEditingSession
    @EnvironmentObject var powerStateController: PowerStateController
    @StateObject private var helperManager = HelperManager.shared
    @ObservedObject private var calibrationManager = CalibrationManager.shared
    @State private var showingScheduleSheet = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 15) {
                    HelperStatusBanner(helperManager: helperManager)
                }
                .padding()
                .roundedCard(fill: Color.black.opacity(0.15), cornerRadius: 20, stroke: Color.white.opacity(0.1))
                .onAppear { helperManager.checkIfRunning() }

                notificationsSection
                coreFeaturesSection
                chargingAndSleepSection
                automaticDischargeSection
                OneTimeDischargeView()
                schedulingSection
                CalibrationView()
                advancedSection
                FanControlSectionView()
            }
            .padding(.horizontal, 25).padding(.bottom, 25)
        }
        .sheet(isPresented: $showingScheduleSheet) {
            ScheduleView().environment(settings)
        }
    }

    @ViewBuilder private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("通知与实时活动").font(.headline).padding([.top, .horizontal])
            CustomSliderRowView(label: "电量低于此值时通知", value: Binding(get: { Double(settings.settings.lowBatteryNotificationPercentage) }, set: { settings.settings.lowBatteryNotificationPercentage = Int($0) }), range: 10...50, specifier: "%.0f %%")
            Divider().padding(.leading, 20)
            ToggleRow(title: "低电量提醒时播放提示音", description: "当电池电量过低时播放声音提醒。", isOn: $settings.settings.lowBatteryNotificationSoundEnabled)
            Divider().padding(.leading, 20)
            ToggleRow(title: "提示开启低电量模式", description: "电量偏低时显示快捷按钮，方便一键开启低电量模式。", isOn: $settings.settings.promptForLowPowerMode)
            Divider().padding(.leading, 20)
            ToggleRow(title: "显示预计剩余时间", description: "在实时活动中显示预计充满时间（充电时）或预计可用时间（电池供电时）。", isOn: $settings.settings.showEstimatedBatteryTime)
        }.modifier(SettingsContainerModifier())
    }

    @ViewBuilder private var coreFeaturesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("电池管理功能").font(.headline).padding([.top, .horizontal])
            if ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27 {
                InfoContainer(
                    text: "由于 macOS 27 的系统变更，部分设备上的充电上限可能无法直接生效。设置上限后，Sapphire 会在达到上限时回退至适配器断电模式（切断适配器供电）以强制执行限制。该方式目前处于测试阶段，可能并非始终生效，尤其是在设备睡眠期间。",
                    iconName: "exclamationmark.triangle.fill",
                    color: .orange
                )
                .padding([.horizontal, .top])
            }
            CustomSliderRowView(label: "充电上限", value: Binding(get: { Double(settings.settings.batteryChargeLimit) }, set: { settings.settings.batteryChargeLimit = Int($0) }), range: 50...100, specifier: "%.0f %%")
            Divider().padding(.leading, 20)
            ToggleRow(
                title: "暂停充电",
                description: "连接电源时手动停止充电。关闭此项即可恢复正常的充电规则（充电上限、巡航模式等）。",
                isOn: Binding(
                    get: { settings.settings.manualChargePaused },
                    set: { paused in
                        settings.settings.manualChargePaused = paused
                        BatteryManager.shared.enableCharging(!paused)
                    }
                )
            )
            Divider().padding(.leading, 20)
            ToggleRow(title: "巡航模式", description: "避免长期插电时频繁微充造成电池损耗。达到充电上限后将暂停充电，仅当电量回落指定幅度后才恢复充电。", isOn: $settings.settings.sailingModeEnabled)
            if settings.settings.sailingModeEnabled {
                 CustomSliderRowView(label: "恢复充电回落幅度", value: Binding(get: { Double(settings.settings.sailingModeLowerLimit) }, set: { settings.settings.sailingModeLowerLimit = Int($0) }), range: 5...20, specifier: "低于上限 %.0f%%")
            }
            Divider().padding(.leading, 20)
            ToggleRow(title: "高温保护", description: "当电池温度过高时自动暂停充电，防止高温损伤并延长电池寿命。", isOn: $settings.settings.heatProtectionEnabled)
            if settings.settings.heatProtectionEnabled {
                 CustomSliderRowView(label: "温度高于此值时暂停充电", value: $settings.settings.heatProtectionThreshold, range: 35...50, specifier: "%.0f °C")
            }
        }
        .modifier(SettingsContainerModifier()).animation(.default, value: settings.settings.sailingModeEnabled || settings.settings.heatProtectionEnabled)
    }

    @ViewBuilder private var automaticDischargeSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("自动放电").font(.headline).padding([.top, .horizontal])
            ToggleRow(
                title: "启用自动放电",
                description: "开启后，Mac 将暂停使用外接电源并改用电池供电，直至电量降至设定的充电上限。",
                isOn: $settings.settings.dischargeToLimitEnabled
            )
        }.modifier(SettingsContainerModifier())
    }

    @ViewBuilder private var chargingAndSleepSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("充电与睡眠").font(.headline).padding([.top, .horizontal])
            InfoContainer(text: "尽管系统已内置睡眠期间维持电池管理的机制，但并非在所有情况下都能生效。如果你希望确保设备睡眠期间的充电行为可控，请配置以下选项。", iconName: "info.circle", color: .yellow).padding()
            ToggleRow(title: "睡眠时停止充电", description: "避免 Mac 整夜维持 100% 满电状态而加速电池老化，唤醒后将自动恢复充电。", isOn: $settings.settings.stopChargingWhenSleeping)
            Divider().padding(.leading, 20)
            ToggleRow(title: "睡眠期间记录电池状态", description: "按设定间隔短暂唤醒 Mac（屏幕保持关闭），在夜间记录电池数据并重新应用充电上限，不会阻止系统睡眠。", isOn: $settings.settings.logBatteryDuringSleep)
            if settings.settings.logBatteryDuringSleep {
                CustomSliderRowView(label: "记录间隔", value: Binding(get: { Double(settings.settings.sleepLoggingIntervalMinutes) }, set: { settings.settings.sleepLoggingIntervalMinutes = Int($0) }), range: 15...120, specifier: "%.0f 分钟")
            }
            Divider().padding(.leading, 20)
            ToggleRow(title: "应用关闭后仍保持充电限制", description: "即使 Sapphire 未在运行，后台辅助工具仍会确保你的充电规则持续生效。", isOn: .constant(true)).disabled(true)
            Divider().padding(.leading, 20)
            ToggleRow(title: "达到充电上限前阻止睡眠", description: "保持 Mac 唤醒以确保充至目标上限，适合出门前补电计划。", isOn: $settings.settings.disableSleepUntilChargeLimit)
        }.modifier(SettingsContainerModifier())
    }

    @ViewBuilder private var schedulingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("定时计划").font(.headline).padding([.top, .horizontal])
            InfoContainer(text: "自动执行充电策略，并支持手动或定时电池校准，保持电量读数精准。", iconName: "calendar.badge.clock", color: .cyan).padding()
            Divider().padding(.horizontal)
            HStack {
                Text("管理计划").font(.subheadline.bold())
                Spacer()
                Button("打开计划管理") { showingScheduleSheet = true }.buttonStyle(.bordered)
            }.padding()
        }.modifier(SettingsContainerModifier())
    }

    @ViewBuilder private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("高级").font(.headline).padding([.top, .horizontal])
            ToggleRow(title: "使用硬件原始电量百分比", description: "直接从电池控制器读取真实电量，数值更精确，但可能与 macOS 系统显示的百分比略有差异。", isOn: $settings.settings.useHardwareBatteryPercentage)
        }.modifier(SettingsContainerModifier())
    }
}

struct OneTimeDischargeView: View {
    @EditingSettings private var settings: SettingsEditingSession
    @StateObject private var batteryMonitor = BatteryMonitor.shared

    private var dischargeProgress: Double {
        guard let currentCharge = batteryMonitor.currentState?.level else { return 0 }

        let targetCharge = Double(settings.settings.oneTimeDischargeTarget)
        let initialCharge = 100.0

        let totalRange = initialCharge - targetCharge
        guard totalRange > 0 else { return 1.0 }

        let dischargedAmount = initialCharge - Double(currentCharge)
        let progress = dischargedAmount / totalRange

        return max(0.0, min(1.0, progress))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("单次放电").font(.headline).padding([.top, .horizontal])
            InfoContainer(
                text: "临时放电至指定百分比，不会影响你的主充电上限或自动放电设置。",
                iconName: "target",
                color: .blue
            ).padding()

            if settings.settings.oneTimeDischargeEnabled {
                VStack(spacing: 12) {
                    Text("正在放电至 \(settings.settings.oneTimeDischargeTarget)%…")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    ProgressView(value: dischargeProgress)
                        .progressViewStyle(.linear)
                        .tint(.blue)

                    if let currentCharge = batteryMonitor.currentState?.level {
                        Text("当前电量：\(currentCharge)%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Button("停止", role: .destructive) {
                        settings.settings.oneTimeDischargeEnabled = false
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 5)
                }
                .padding(.horizontal)
                .padding(.bottom)
                .frame(minHeight: 120)

            } else {
                VStack(spacing: 15) {
                    Stepper(
                        "放电目标：\(settings.settings.oneTimeDischargeTarget)%",
                        value: $settings.settings.oneTimeDischargeTarget,
                        in: 1...95,
                        step: 5
                    )

                    Button(action: {
                        settings.settings.oneTimeDischargeEnabled = true
                    }) {
                        Text("开始单次放电")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
                .padding(.horizontal)
                .padding(.bottom)
                .frame(minHeight: 120)
            }
        }
        .modifier(SettingsContainerModifier())
    }
}

fileprivate extension TimeInterval {
    func formatted() -> String {
        SettingsDurationFormatter.hourMinute.string(from: self) ?? "0分钟"
    }
}

private enum SettingsDurationFormatter {
    static let hourMinute: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
}

struct ScheduleView: View {
    @Environment(\.dismiss) var dismiss
    @EditingSettings var settings: SettingsEditingSession
    @ObservedObject private var scheduleManager = ScheduleManager.shared
    @State private var showingAddTask = false

    var body: some View {
        VStack(spacing: 20) {
            Text("自动化计划").font(.largeTitle.bold())

            VStack {
                HStack {
                    Text("计划任务").font(.headline)
                    Spacer()
                    Button(action: { showingAddTask = true }) { Image(systemName: "plus") }
                }.padding([.horizontal, .top])

                if settings.settings.scheduledTasks.isEmpty {
                    Text("暂无计划任务。").foregroundColor(.secondary).padding()
                } else {
                    List {
                        ForEach($settings.settings.scheduledTasks) { $task in
                            TaskRowView(task: $task).listRowBackground(Color.clear)
                        }.onDelete { indexSet in settings.settings.scheduledTasks.remove(atOffsets: indexSet) }
                    }.listStyle(.plain).background(Color.clear)
                }
            }.modifier(SettingsContainerModifier())

            VStack(alignment: .leading) {
                 Text("任务执行记录").font(.headline).padding([.horizontal, .top])
                 List(scheduleManager.taskHistory) { event in
                     HStack {
                         Text(event.taskDescription); Spacer(); Text(event.timestamp, style: .time)
                     }.listRowBackground(Color.clear)
                 }.listStyle(.plain).background(Color.clear)
            }.modifier(SettingsContainerModifier())

            Button("完成") { dismiss() }.keyboardShortcut(.defaultAction)
        }
        .padding(30).frame(minWidth: 500, minHeight: 600)
        .sheet(isPresented: $showingAddTask) {
            AddTaskView().environment(settings)
        }
    }
}

struct TaskRowView: View {
    @Binding var task: ScheduledTask

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(task.action.displayName).font(.headline)

                switch task.action {
                case .setChargeLimit, .dischargeTo:
                    Text("目标：\(task.chargeLimit)% | 重复：\(task.repeatInterval.displayName) \(task.startTime, style: .time)")
                        .font(.caption).foregroundColor(.secondary)
                case .setFanConstant:
                    Text("转速：\(task.fanSpeed) RPM | 重复：\(task.repeatInterval.displayName) \(task.startTime, style: .time)")
                        .font(.caption).foregroundColor(.secondary)
                case .setFanSensorBased:
                    Text("传感器：\(SensorNameMap.name(for: task.sensorKey))（\(task.minTemp)°C–\(task.maxTemp)°C） | 重复：\(task.repeatInterval.displayName) \(task.startTime, style: .time)")
                        .font(.caption).foregroundColor(.secondary)
                default:
                    Text("重复：\(task.repeatInterval.displayName) \(task.startTime, style: .time)")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
            Toggle("", isOn: $task.isActive).labelsHidden()
        }
    }
}

struct AddTaskView: View {
    @Environment(\.dismiss) var dismiss
    @EditingSettings var settings: SettingsEditingSession
    @ObservedObject private var fanManager = FanManager.shared
    @State private var newTask = ScheduledTask()

    private var firstFan: FanInfo? { fanManager.fans.first }

    var body: some View {
        VStack(spacing: 20) {
            Text("新建计划任务").font(.title.bold())

            VStack(spacing: 15) {
                Picker("执行操作：", selection: $newTask.action) {
                    ForEach(TaskAction.allCases) { Text($0.displayName).tag($0) }
                }
                .onChange(of: newTask.action) {
                    if newTask.action == .setFanSensorBased, newTask.sensorKey.isEmpty {
                        newTask.sensorKey = fanManager.sensors.first?.key ?? ""
                    }
                }

                if [.setChargeLimit, .dischargeTo].contains(newTask.action) {
                    CustomSliderRowView(label: "目标电量", value: Binding(get: { Double(newTask.chargeLimit) }, set: { newTask.chargeLimit = Int($0) }), range: 20...100, specifier: "%.0f%%")
                        .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .move(edge: .trailing).combined(with: .opacity)))
                }

                if newTask.action == .setFanConstant {
                    if let fan = firstFan {
                        CustomSliderRowView(label: "目标转速", value: Binding(get: { Double(newTask.fanSpeed) }, set: { newTask.fanSpeed = Int($0) }), range: Double(fan.minRPM)...Double(fan.maxRPM), specifier: "%.0f RPM")
                            .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .move(edge: .trailing).combined(with: .opacity)))
                    }
                }

                if newTask.action == .setFanSensorBased {
                    VStack(spacing: 15) {
                        Picker("依据传感器：", selection: $newTask.sensorKey) {
                            ForEach(fanManager.sensors) { sensor in
                                Text(sensor.name).tag(sensor.key)
                            }
                        }

                        CustomSliderRowView(label: "起始加速温度：", value: Binding(get: { Double(newTask.minTemp) }, set: { newTask.minTemp = Int($0) }), range: 20...90, specifier: "%.0f °C")

                        CustomSliderRowView(label: "最高满速温度：", value: Binding(get: { Double(newTask.maxTemp) }, set: { newTask.maxTemp = Int($0) }), range: Double(newTask.minTemp)...100, specifier: "%.0f °C")
                    }
                    .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .move(edge: .trailing).combined(with: .opacity)))
                }

                Picker("重复周期：", selection: $newTask.repeatInterval) {
                    ForEach(RepeatInterval.allCases) { Text($0.displayName).tag($0) }
                }

                DatePicker("执行时间：", selection: $newTask.startTime, displayedComponents: .hourAndMinute)
            }
            .padding().modifier(SettingsContainerModifier())
            .animation(.default, value: newTask.action)

            HStack {
                Button("取消", role: .cancel) { dismiss() }
                Spacer()
                Button("添加任务") {
                    settings.settings.scheduledTasks.append(newTask)
                    dismiss()
                }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(30).frame(width: 450)
    }
}

struct HUDSettingsView: View {
    @EditingSettings var settings: SettingsEditingSession

    private var hudCustomColorBinding: Binding<Color> {
        Binding(
            get: { settings.settings.hudCustomColor?.color ?? .accentColor },
            set: { settings.settings.hudCustomColor = CodableColor(color: $0) }
        )
    }

    private var pillStyleEnabled: Bool {
        settings.settings.effectiveVolumeHUDStyle == .pill || settings.settings.effectiveBrightnessHUDStyle == .pill
    }

    private var xdrBrightnessLevelBinding: Binding<Double> {
        Binding(
            get: { Double(settings.settings.xdrBrightnessLevel * 100) },
            set: { settings.settings.xdrBrightnessLevel = Float($0 / 100) }
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                Text("HUD 浮层")
                    .font(.largeTitle.bold())
                    .padding(.bottom)

                // MARK: HUD Appearance
                VStack(alignment: .leading, spacing: 0) {
                    Text("HUD 外观")
                        .font(.headline)
                        .padding([.horizontal, .top])

                    Divider().padding(.top, 10).padding(.leading, 20)

                    HStack {
                        Text("视觉样式")
                        Spacer()
                        Picker("", selection: $settings.settings.hudVisualStyle) {
                            ForEach(HUDVisualStyle.allCases) { style in
                                Text(localizedHUDOption(style.id)).tag(style)
                            }
                        }
                        .labelsHidden().frame(width: 150)
                    }.padding()

                    if settings.settings.hudVisualStyle == .color {
                        ColorPicker("自定义 HUD 颜色", selection: hudCustomColorBinding)
                            .padding()
                            .transition(.opacity)
                    }

                    Divider().padding(.leading, 20)

                    CustomSliderRowView(label: "HUD 显示时长", value: $settings.settings.hudDuration, range: 1...10, specifier: "%.1f 秒")
                    Divider().padding(.leading, 20)
                    ToggleRow(title: "显示百分比", description: "", isOn: $settings.settings.hudShowPercentage)
                    Divider().padding(.leading, 20)
                    ToggleRow(title: "显示功能名称", description: "启用纤细样式时显示 HUD 名称（如音量、亮度、Spotify）。", isOn: $settings.settings.hudShowFunctionName)

                    if pillStyleEnabled {
                        Divider().padding(.leading, 20)
                        HStack {
                            Text("胶囊位置")
                            Spacer()
                            Picker("", selection: $settings.settings.hudPillPosition) {
                                ForEach(PillHUDPosition.allCases) { position in
                                    Text(localizedHUDOption(position.id)).tag(position)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 120)
                        }
                        .padding()
                        HStack {
                            Text("胶囊样式")
                            Spacer()
                            Picker("", selection: $settings.settings.hudPillStyle) {
                                ForEach(PillHUDStyle.allCases) { style in
                                    Text(localizedHUDOption(style.id)).tag(style)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 120)
                        }
                        .padding()
                        Divider().padding(.leading, 20)
                        CustomSliderRowView(label: "胶囊长度", value: $settings.settings.hudPillLength, range: 160...460, specifier: "%.0f pt")
                        Divider().padding(.leading, 20)
                        CustomSliderRowView(label: "胶囊厚度", value: $settings.settings.hudPillThickness, range: 44...92, specifier: "%.0f pt")
                    }
                }
                .modifier(SettingsContainerModifier())
                .animation(.default, value: pillStyleEnabled)
                .animation(.default, value: settings.settings.hudVisualStyle)

                // MARK: Spotify, App & Device Icons (essential)
                VStack(alignment: .leading, spacing: 0) {
                    Text("显示 Spotify、应用与设备图标")
                        .font(.headline)
                        .padding([.horizontal, .top])

                    Divider().padding(.top, 10).padding(.leading, 20)

                    ToggleRow(
                        title: "在 HUD 中显示 Spotify 播放设备",
                        description: "当 Spotify 处于活动状态并调节音量时，显示带有当前播放设备名称的专属 HUD。",
                        isOn: $settings.settings.showSpotifyVolumeHUD
                    )
                    Divider().padding(.leading, 20)
                    ToggleRow(
                        title: "在 HUD 中显示应用独立音量",
                        description: "按下 Option + 音量键可调节当前前台应用的音量（不含 Spotify 与 Apple Music）。",
                        isOn: $settings.settings.showAppVolumeHUD
                    )

                    if settings.settings.showAppVolumeHUD {
                        ToggleRow(
                            title: "在常规音量 HUD 中显示",
                            description: "在常规音量 HUD 中直接显示应用音量（类似 Spotify）。关闭后仅在按下 Option + 音量键时显示。",
                            isOn: $settings.settings.showAppVolumeInNormalHUD
                        )
                        .padding(.leading, 20)
                    }

                    Divider().padding(.leading, 20)
                    ToggleRow(
                        title: "以设备图标替代扬声器图标",
                        description: "连接 HomePod 等音频设备时，在音量 HUD 中显示对应的设备专属图标。",
                        isOn: $settings.settings.volumeHUDShowDeviceIcon
                    )

                    if settings.settings.volumeHUDShowDeviceIcon {
                        ToggleRow(
                            title: "排除内置扬声器",
                            description: "仅为 AirPods 或 HomePod 等外接音频设备显示设备图标。",
                            isOn: $settings.settings.excludeBuiltInSpeakersFromHUDIcon
                        )
                        .padding(.leading, 20)
                        .transition(.opacity)
                    }
                }
                .modifier(SettingsContainerModifier())
                .animation(.default, value: settings.settings.volumeHUDShowDeviceIcon)

                // MARK: Volume HUD
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("音量 HUD")
                            .font(.headline)
                        Spacer()
                        Toggle("", isOn: $settings.settings.enableVolumeHUD)
                            .labelsHidden().toggleStyle(.switch)
                    }
                    .padding()

                    Divider().padding(.leading, 20)

                    HStack {
                        Text("显示样式")
                        Spacer()
                        Picker("", selection: $settings.settings.volumeHUDStyle) {
                            ForEach(HUDStyle.allCases.filter { $0 != .dots }) { style in
                                Text(localizedHUDOption(style.id)).tag(style)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 120)
                    }
                    .padding()
                    .disabled(!settings.settings.enableVolumeHUD || settings.settings.volumeHUDShowDots)
                    .opacity(settings.settings.enableVolumeHUD && !settings.settings.volumeHUDShowDots ? 1.0 : 0.5)

                    Divider().padding(.leading, 20)

                    ToggleRow(
                        title: "显示圆点刻度",
                        description: "以一排圆点替代进度条来显示音量。",
                        isOn: $settings.settings.volumeHUDShowDots
                    )
                    .disabled(!settings.settings.enableVolumeHUD)
                    .opacity(settings.settings.enableVolumeHUD ? 1.0 : 0.5)

                    Divider().padding(.leading, 20)

                    HStack {
                        Text("调节时播放提示音")
                        Spacer()
                        Toggle("", isOn: $settings.settings.volumeHUDSoundEnabled)
                            .labelsHidden().toggleStyle(.switch)
                    }
                    .padding()
                    .disabled(!settings.settings.enableVolumeHUD)
                    .opacity(settings.settings.enableVolumeHUD ? 1.0 : 0.5)

                    Divider().padding(.leading, 20)

                    ToggleRow(
                        title: "应用独立音量受系统总音量上限限制",
                        description: "开启后，应用的 100% 音量不会超过当前的系统输出总音量。",
                        isOn: $settings.settings.perAppVolumeSystemDependent
                    )
                    .disabled(!settings.settings.enableVolumeHUD)
                    .opacity(settings.settings.enableVolumeHUD ? 1.0 : 0.5)

                    Divider().padding(.leading, 20)

                    CustomSliderRowView(label: "调节步进档位", value: Binding(get: { Double(settings.settings.volumesliderstep) }, set: { settings.settings.volumesliderstep = Int($0) }), range: 1...20, specifier: "%.0f")
                        .disabled(!settings.settings.enableVolumeHUD)
                        .opacity(settings.settings.enableVolumeHUD ? 1.0 : 0.5)

                    Divider().padding(.leading, 20)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("按设备自定义调节步进")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        ForEach(MultiAudioManager.shared.availableOutputDevices, id: \.uid) { device in
                            HStack {
                                Text(device.name)
                                    .font(.system(size: 13))
                                Spacer()

                                Picker("", selection: Binding(get: {
                                    Double(settings.settings.volumesliderstepByDevice[device.uid] ?? settings.settings.volumesliderstep)
                                }, set: { newVal in
                                    settings.settings.volumesliderstepByDevice[device.uid] = Int(newVal)
                                })) {
                                    ForEach(1...20, id: \.self) { val in
                                        Text("\(val)").tag(Double(val))
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 120)

                                Button(action: {
                                    settings.settings.volumesliderstepByDevice.removeValue(forKey: device.uid)
                                }) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("重置为全局步进设置")
                            }
                            .padding(.vertical, 2)
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 10)
                    .disabled(!settings.settings.enableVolumeHUD)
                    .opacity(settings.settings.enableVolumeHUD ? 1.0 : 0.5)
                }
                .modifier(SettingsContainerModifier())

                // MARK: Brightness HUD
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("亮度 HUD")
                            .font(.headline)
                        Spacer()
                        Toggle("", isOn: $settings.settings.enableBrightnessHUD)
                            .labelsHidden().toggleStyle(.switch)
                    }
                    .padding()

                    Divider().padding(.leading, 20)

                    HStack {
                        Text("显示样式")
                        Spacer()
                        Picker("", selection: $settings.settings.brightnessHUDStyle) {
                            ForEach(HUDStyle.allCases.filter { $0 != .dots }) { style in
                                Text(localizedHUDOption(style.id)).tag(style)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 120)
                    }
                    .padding()
                    .disabled(!settings.settings.enableBrightnessHUD || settings.settings.brightnessHUDShowDots)
                    .opacity(settings.settings.enableBrightnessHUD && !settings.settings.brightnessHUDShowDots ? 1.0 : 0.5)

                    Divider().padding(.leading, 20)

                    ToggleRow(
                        title: "显示圆点刻度",
                        description: "以一排圆点替代进度条来显示亮度。",
                        isOn: $settings.settings.brightnessHUDShowDots
                    )
                    .disabled(!settings.settings.enableBrightnessHUD)
                    .opacity(settings.settings.enableBrightnessHUD ? 1.0 : 0.5)

                    Divider().padding(.leading, 20)

                    CustomSliderRowView(label: "调节步进档位", value: Binding(get: { Double(settings.settings.brightnessliderstep) }, set: { settings.settings.brightnessliderstep = Int($0) }), range: 1...10, specifier: "%.0f")
                        .disabled(!settings.settings.enableBrightnessHUD)
                        .opacity(settings.settings.enableBrightnessHUD ? 1.0 : 0.5)

                    Divider().padding(.leading, 20)

                    HStack(spacing: 12) {
                        SettingsRowLabel(
                            title: "亮度按键步幅",
                            description: "每次按下亮度键的调节幅度，步幅越小控制越精细。"
                        )
                        Spacer(minLength: 8)
                        Picker("亮度按键步幅", selection: $settings.settings.brightnessKeyStep) {
                            ForEach(BrightnessKeyStep.allCases) { step in
                                Text(step.displayName).tag(step)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .fixedSize()
                    }
                    .padding()

                    Divider().padding(.leading, 20)

                    ToggleRow(
                        title: "极暗压低亮度",
                        description: "允许外接显示器降至比硬件最低背光更暗的水平，亮度范围最底部的四分之一将通过软件压暗画面。",
                        isOn: $settings.settings.displayExtraDimming
                    )

                    SoftwareDimmingRows()
                }
                .modifier(SettingsContainerModifier())

                // MARK: XDR Brightness (essential)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("XDR 超高亮度")
                            .font(.headline)
                        Spacer()
                        Toggle("", isOn: $settings.settings.enableXDRBrightness)
                            .labelsHidden().toggleStyle(.switch)
                    }

                    Divider()

                    VStack {
                        ToggleRow(
                            title: "XDR 亮度锁定",
                            description: "需要按住 Command (⌘) 键才能在 XDR 激发亮度区间内继续调高亮度。",
                            isOn: $settings.settings.xdrBrightnessLock
                        )

                        Divider()

                        CustomSliderRowView(
                            label: "最高 XDR 亮度",
                            value: xdrBrightnessLevelBinding,
                            range: 100...Double(getDeviceMaxBrightness() * 100),
                            specifier: "%.0f%%"
                        )

                        HStack(alignment: .top) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.yellow)
                                .padding(.top, 4)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Apple 默认限制峰值亮度以节省电量。尽管此功能调用系统底层控制且暂无已知副作用，仍请自行承担使用风险。")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("此功能在配备 XDR 显示屏的设备（14 英寸与 16 英寸 MacBook Pro 及 Pro Display XDR）上效果最佳。M4 款 MacBook Pro 已支持在阳光直射等强光环境下激发高亮度，开启此项后即可在任意环境光下手动启用。")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 5)
                    }
                    .disabled(!settings.settings.enableXDRBrightness)
                    .opacity(settings.settings.enableXDRBrightness ? 1.0 : 0.5)

                }
                .padding()
                .modifier(SettingsContainerModifier())
                .disabled(!settings.settings.enableBrightnessHUD)
                .opacity(settings.settings.enableBrightnessHUD ? 1.0 : 0.5)
                .animation(.easeInOut, value: settings.settings.enableBrightnessHUD)
                .animation(.easeInOut, value: settings.settings.enableXDRBrightness)

                RequiredPermissionsView(section: .hud)
            }
            .padding(25)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func localizedHUDOption(_ raw: String) -> String {
        switch raw.lowercased() {
        case "default": return "默认"
        case "system": return "系统"
        case "blur", "frosted": return "磨砂"
        case "glass", "liquid glass", "liquidglass": return "液态玻璃"
        case "solid", "dark": return "深色纯底"
        case "light": return "浅色"
        case "color", "custom", "custom color": return "自定义颜色"
        case "accent": return "强调色"
        case "top": return "顶部"
        case "bottom": return "底部"
        case "left": return "左侧"
        case "right": return "右侧"
        case "center": return "居中"
        case "classic": return "经典"
        case "thin", "minimal", "slim": return "纤细"
        case "compact": return "紧凑"
        case "pill": return "胶囊"
        case "notch": return "灵动岛"
        case "bar": return "条形"
        case "modern": return "现代"
        case "expanded", "large": return "展开"
        default: return raw
        }
    }
}

struct MusicSettingsView: View {
    @EditingSettings var settings: SettingsEditingSession

    @State private var isPrivateApiLoading = false
    @State private var privateApiError: String?
    @State private var isPrivateAuth = false
    @State private var isOfficialAuth = false
    @State private var officialDisplayName: String?
    @State private var isTidalAuth = false
    @State private var tidalDisplayName: String?
    @State private var tidalLoginError: String?
    @State private var isShowingTidalLogin = false
    @State private var loginChallenge: LoginChallengeDetails?
    @AppStorage("musicSettingsSelectedTab") private var selectedTab: MusicSettingsTab = .general

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                Text("音乐").font(.largeTitle.bold())

                Picker("音乐分区", selection: $selectedTab) {
                    ForEach(MusicSettingsTab.allCases) { tab in
                        Label(tabTitle(for: tab), systemImage: tab.icon).tag(tab)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .padding(.bottom, 4)

                switch selectedTab {
                case .general:
                VStack(spacing: 0) {
                    HStack {
                        Text("媒体来源")
                        Spacer()
                        Picker("", selection: $settings.settings.mediaSource) {
                            ForEach(MediaSource.allCases) { source in Text(source.displayName).tag(source) }
                        }
                        .labelsHidden().frame(width: 180)
                    }.padding()
                    if settings.settings.mediaSource != .system {
                        Divider().padding(.leading, 20)
                        ToggleRow(title: "优先显示所选媒体来源", description: "仅显示来自所选媒体来源的播放内容，忽略浏览器及其他应用。", isOn: $settings.settings.prioritizeMediaSource)
                    }
                }
                .modifier(SettingsContainerModifier())
                .animation(.default, value: settings.settings.mediaSource)

                if settings.settings.mediaSource == .system {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("显示以下应用的正在播放").font(.headline).padding([.horizontal, .top])
                        Text("选择可显示在音乐小组件与媒体切换器中的应用。默认开启所有应用（含浏览器）。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        AppTogglesListView(isEnabled: { app in mediaVisibilityBinding(for: app, isBrowser: app.isBrowser) })
                    }
                    .modifier(SettingsContainerModifier())
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("默认音乐应用")
                        Spacer()
                        Picker("", selection: $settings.settings.defaultMusicPlayer) {
                            ForEach(DefaultMusicPlayer.allCases) { player in
                                Text(player.displayName)
                                    .tag(player)
                                    .disabled(!player.isAppInstalled && player.webURL == nil)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 150)
                    }
                    .padding()
                    Divider().padding(.leading, 20)
                    HStack { Text("点击实时活动时展开详细音乐小组件"); Spacer(); SettingsSwitch(isOn: $settings.settings.musicOpenOnClick) }.padding()
                }
                .modifier(SettingsContainerModifier())

                VStack(alignment: .leading, spacing: 0) {
                    Text("手势操作").font(.headline).padding([.top, .horizontal])
                    ToggleRow(title: "左滑切至下一首", description: "在音乐实时活动中，向左滑动专辑封面即可切换下一首。", isOn: $settings.settings.swipeToSkipMusic)
                    Divider().padding(.leading, 20)
                    ToggleRow(title: "右滑回到上一首", description: "向右滑动专辑封面即可返回上一首。", isOn: $settings.settings.swipeToRewindMusic)
                    Divider().padding(.leading, 20)
                    ToggleRow(title: "反转滑动方向", description: "改为向右滑动切至下一首，向左滑动返回上一首。", isOn: $settings.settings.invertMusicGestures)
                    Divider().padding(.leading, 20)
                    ToggleRow(title: "双指轻点播放/暂停", description: "使用双指轻点专辑封面以切换播放或暂停状态。", isOn: $settings.settings.twoFingerTapToPauseMusic)
                }
                .modifier(SettingsContainerModifier())

                VStack(alignment: .leading, spacing: 0) {
                    Text("长按操作").font(.headline).padding([.top, .horizontal])
                    ToggleRow(
                        title: "启用长按操作",
                        description: "长按辅助播放按钮（播放列表、播放设备、喜欢、随机播放、循环播放）以触发备选操作。上一首 / 下一首 / 播放按钮仅在下方指定了长按操作时才响应长按；关闭此项时，长按上一首 / 下一首仍可快进或快退。",
                        isOn: $settings.settings.musicLongPressActionsEnabled
                    )
                    if settings.settings.musicLongPressActionsEnabled {
                        Divider().padding(.leading, 20)
                        Text("辅助按钮")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 8)
                        ForEach(settings.settings.musicPlayerButtonOrder.compactMap { MusicLongPressTarget.from(buttonType: $0) }) { target in
                            MusicLongPressActionPickerRow(target: target)
                            Divider().padding(.leading, 20)
                        }
                        Text("播放控制按钮（可选）")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 4)
                        ForEach([MusicLongPressTarget.previous, .next, .playPause]) { target in
                            MusicLongPressActionPickerRow(target: target)
                            if target != .playPause {
                                Divider().padding(.leading, 20)
                            }
                        }
                    }
                }
                .modifier(SettingsContainerModifier())

                RequiredPermissionsView(section: .music)
                case .player:
                VStack(alignment: .leading, spacing: 0) {
                    HStack { Text("音频波形随音量动态变化"); Spacer(); SettingsSwitch(isOn: $settings.settings.musicWaveformIsVolumeSensitive) }.padding()
                    Divider().padding(.leading, 20)
                    Text("波形外观").font(.headline).padding([.top, .horizontal])
                    ToggleRow(title: "启用封面渐变色", description: "根据当前专辑封面配色为波形应用渐变色彩。", isOn: $settings.settings.waveformUseGradient)
                    Divider().padding(.leading, 20)
                    ToggleRow(title: "使用静态波形", description: "播放音乐时显示静止无动画的波形图标。", isOn: $settings.settings.useStaticWaveform)
                    Divider().padding(.leading, 20)
                    CustomSliderRowView(label: "波形柱数量", value: Binding(get: { Double(settings.settings.waveformBarCount) }, set: { settings.settings.waveformBarCount = Int($0) }), range: 3...6, specifier: "%.0f")
                    Divider().padding(.leading, 20)
                    CustomSliderRowView(label: "波形柱粗细", value: $settings.settings.waveformBarThickness, range: 1...5, specifier: "%.0f pt")
                    Divider().padding(.leading, 20)
                    Text("实时活动").font(.headline).padding([.top, .horizontal])
                    VStack(alignment: .leading, spacing: 6) {
                        Text("右侧曲目信息")
                        Text("在封面旁显示歌曲标题与艺人。默认为仅手机端显示——Mac 本地播放保持紧凑波形样式。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("", selection: $settings.settings.musicLiveActivityRightTextMode) {
                            ForEach(MusicLiveActivityRightTextMode.allCases) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                    }
                    .padding()
                    .onAppear {
                        if settings.settings.musicLiveActivityRightTextMode != .always,
                           settings.settings.musicLiveActivityWaveformMode == .off {
                            settings.settings.musicLiveActivityWaveformMode = .continuityOff
                        }
                    }
                    .onChange(of: settings.settings.musicLiveActivityRightTextMode) { _, mode in
                        if mode != .always, settings.settings.musicLiveActivityWaveformMode == .off {
                            settings.settings.musicLiveActivityWaveformMode = .continuityOff
                        }
                    }
                    Divider().padding(.leading, 20)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("音频波形")
                        Text("默认为手机端隐藏。当右侧曲目信息设为始终显示时，可完全关闭音频波形。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker(
                            "",
                            selection: Binding(
                                get: { settings.settings.musicLiveActivityWaveformMode },
                                set: { newValue in
                                    if newValue == .off && settings.settings.musicLiveActivityRightTextMode != .always {
                                        settings.settings.musicLiveActivityWaveformMode = .continuityOff
                                    } else {
                                        settings.settings.musicLiveActivityWaveformMode = newValue
                                    }
                                }
                            )
                        ) {
                            ForEach(
                                MusicLiveActivityWaveformMode.allCases.filter {
                                    $0 != .off || settings.settings.musicLiveActivityRightTextMode == .always
                                }
                            ) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                    }
                    .padding()
                    Divider().padding(.leading, 20)
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("波形样式")
                            Text("经典样式为跳动柱状波形；跨端互通样式为旧版手机媒体活动所使用的系统图标。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Picker("", selection: $settings.settings.musicLiveActivityWaveformStyle) {
                            ForEach(MusicLiveActivityWaveformStyle.allCases) { style in
                                Text(style.displayName).tag(style)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 140)
                    }
                    .padding()
                }
                .modifier(SettingsContainerModifier())

                VStack(alignment: .leading, spacing: 10) {
                    Text("自定义播放器按钮").font(.headline).padding([.horizontal, .top])
                    Text("启用并拖拽排序音乐播放器中显示的按钮，前两个启用的按钮将直接显示在主控制栏中。").font(.caption).foregroundColor(.secondary).padding(.horizontal).padding(.bottom, 5)
                    ReorderableVStack(items: $settings.settings.musicPlayerButtonOrder) { buttonType in PlayerButtonSettingsRow(buttonType: buttonType) }
                }
                .modifier(SettingsContainerModifier())

                VStack(spacing: 0) {
                    ToggleRow(title: "悬停时预览曲目信息", description: "将鼠标悬停在实时活动的专辑封面上即可查看歌曲名称。", isOn: $settings.settings.enableQuickPeekOnHover)
                    Divider().padding(.leading, 20)
                    ToggleRow(title: "切歌时短暂显示曲目信息", description: "开始播放新曲目时短暂弹出显示歌曲名称。", isOn: $settings.settings.showQuickPeekOnTrackChange)
                }.modifier(SettingsContainerModifier())
                case .features:
                MusicPlayerFeaturesCard(isSpotifyAvailable: isPrivateAuth)
                case .accounts:
                AppleMusicAccountCard()

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Spotify").font(.headline)
                        Spacer()
                        Picker("", selection: $settings.settings.spotifyAPIMode) {
                            ForEach(SpotifyAPIMode.allCases) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 220)
                    }
                    .padding([.horizontal, .top])

                    switch settings.settings.spotifyAPIMode {
                    case .privateAPI:
                        InfoContainer(text: "警告：此方式通过调用 Spotify 内部接口为 Premium 及非 Premium 用户解锁标准与扩展功能。请自行承担使用风险，相关使用可能受 Spotify 服务条款约束。", iconName: "exclamationmark.triangle.fill", color: .yellow).padding(.horizontal)
                        InfoContainer(text: "Sapphire 仅作为 Connect 控制器使用，音频始终在 Spotify 桌面客户端或其他扬声器设备上播放。", iconName: "hifispeaker", color: .blue).padding(.horizontal)
                        if isOfficialAuth {
                            Text("你同时已通过官方 API 登录。").font(.caption).foregroundColor(.secondary).padding(.horizontal)
                        }
                        Divider().padding(.horizontal, 20)
                        if isPrivateAuth {
                            VStack(spacing: 0) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                    Text("已通过私有 API 登录")
                                    Spacer()
                                    Button("退出登录", role: .destructive) { MusicManager.shared.spotifyPrivateAPI.logout() }
                                }.padding()
                                Divider().padding(.leading, 20)
                                ToggleRow(title: "自动跳过广告", description: "当此 Mac 上的 Spotify 桌面端播放广告时，在后台自动重启并通过 Spotify Connect 恢复播放。", isOn: $settings.settings.skipSpotifyAd)
                                ToggleRow(title: "显示 Spotify 音源标签页", description: "其他应用正在播放时显示 Spotify 音源标签以便快捷切换；当 Spotify 本身为主音源时自动隐藏。", isOn: $settings.settings.showSpotifySourceTab)
                                    .disabled(!isPrivateAuth)
                                ToggleRow(title: "动态 Canvas 视频背景", description: "可用时在封面背景循环播放 Spotify Canvas 动态视频，关闭则始终显示静态专辑封面。", isOn: $settings.settings.spotifyCanvasLiveVideo)
                                    .disabled(!isPrivateAuth)
                            }
                        } else {
                            VStack(spacing: 12) {
                                if let error = privateApiError {
                                    Text(error).font(.caption).foregroundColor(.red)
                                }
                                if isPrivateApiLoading {
                                    ProgressView().frame(maxWidth: .infinity, alignment: .center)
                                } else {
                                    Button("通过私有 API 登录") { handlePrivateApiLogin() }
                                        .buttonStyle(.borderedProminent).tint(.accentColor)
                                }
                            }.padding()
                        }
                    case .officialAPI:
                        InfoContainer(text: "私有 API 提供更丰富的功能与更完善的支持；官方 API 仅支持基础播放控制与设备切换，且需要自行创建开发者应用。", iconName: "exclamationmark.triangle.fill", color: .yellow).padding(.horizontal)
                        if isPrivateAuth {
                            Text("你同时已通过私有 API 登录。").font(.caption).foregroundColor(.secondary).padding(.horizontal)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Spotify API 凭据").font(.system(size: 14, weight: .medium))
                            Text("请前往 developer.spotify.com 注册应用并将凭据粘贴至此处。回调地址（Redirect URI）请填写：sapphire://callback").font(.caption).foregroundColor(.secondary).padding(.bottom, 4)
                            Text("客户端 ID (Client ID)").font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.8))
                            SecureField("输入你的 Client ID", text: Binding(
                                get: { APIKeyManager.shared.spotifyClientId },
                                set: { APIKeyManager.shared.spotifyClientId = $0 }
                            )).textFieldStyle(.plain).padding(8).background(Color.black.opacity(0.2)).clipShape(RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.2)))
                            Text("客户端密钥 (Client Secret)").font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.8)).padding(.top, 5)
                            SecureField("输入你的 Client Secret", text: Binding(
                                get: { APIKeyManager.shared.spotifyClientSecret },
                                set: { APIKeyManager.shared.spotifyClientSecret = $0 }
                            )).textFieldStyle(.plain).padding(8).background(Color.black.opacity(0.2)).clipShape(RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.2)))
                        }.padding().padding(.top, 5)
                        Text("在此登录以启用面向 Premium 用户的设备切换等官方功能。").font(.caption).foregroundColor(.secondary).padding(.horizontal)
                        Divider().padding(.horizontal, 20)
                        HStack {
                            if isOfficialAuth {
                                HStack { Image(systemName: "checkmark.circle.fill").foregroundColor(.green); Text(officialDisplayName.map { "已登录为 \($0)" } ?? "已登录") }
                                Spacer()
                                Button("退出登录", role: .destructive) { MusicManager.shared.spotifyOfficialAPI.logout() }
                            } else {
                                Text("未登录。").foregroundColor(.secondary)
                                Spacer()
                                Button("登录") { MusicManager.shared.spotifyOfficialAPI.login() }
                            }
                        }.padding()
                    }
                }
                .modifier(SettingsContainerModifier())
                .animation(.default, value: isPrivateAuth)
                .animation(.default, value: isOfficialAuth)
                .animation(.default, value: settings.settings.spotifyAPIMode)

                VStack(alignment: .leading, spacing: 10) {
                    Text("TIDAL").font(.headline).padding([.horizontal, .top])
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TIDAL API 凭据").font(.system(size: 14, weight: .medium))
                        Text("请前往 developer.tidal.com 创建应用，勾选 user.read、search.read、collection.read/write 与 playlists.read/write 权限范围，并将回调地址（Redirect URI）准确设为 sapphire://callback。").font(.caption).foregroundColor(.secondary).padding(.bottom, 4)
                        Text("客户端 ID (Client ID)").font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.8))
                        SecureField("输入你的 Client ID", text: Binding(
                            get: { APIKeyManager.shared.tidalClientId },
                            set: { APIKeyManager.shared.tidalClientId = $0 }
                        )).textFieldStyle(.plain).padding(8).background(Color.black.opacity(0.2)).clipShape(RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.2)))
                        Text("客户端密钥 (Client Secret)").font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.8)).padding(.top, 5)
                        SecureField("输入你的 Client Secret", text: Binding(
                            get: { APIKeyManager.shared.tidalClientSecret },
                            set: { APIKeyManager.shared.tidalClientSecret = $0 }
                        )).textFieldStyle(.plain).padding(8).background(Color.black.opacity(0.2)).clipShape(RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.2)))
                    }.padding().padding(.top, 5)
                    Text("在此登录以启用 TIDAL 曲库搜索及红心歌曲与歌单同步等功能。需要具备第三方访问权限的 TIDAL 开发者账号。").font(.caption).foregroundColor(.secondary).padding(.horizontal)
                    Divider().padding(.horizontal, 20)
                    HStack {
                        if isTidalAuth {
                            HStack { Image(systemName: "checkmark.circle.fill").foregroundColor(.green); Text(tidalDisplayName.map { "已登录为 \($0)" } ?? "已登录") }
                            Spacer()
                            Button("退出登录", role: .destructive) { MusicManager.shared.tidalAPI.logout() }
                        } else {
                            Text("未登录。").foregroundColor(.secondary)
                            Spacer()
                            Button("登录") { isShowingTidalLogin = true }
                        }
                    }.padding()
                    if !isTidalAuth, let tidalLoginError {
                        Text(tidalLoginError).font(.caption).foregroundColor(.red).padding([.horizontal, .bottom])
                    }
                }
                .modifier(SettingsContainerModifier())
                .animation(.default, value: isTidalAuth)

                VStack(spacing: 0) {
                    ToggleRow(title: "优先使用隔空播放而非 Spotify 设备", description: "已登录 Spotify 但客户端未运行时，默认使用隔空播放（AirPlay）音频设备。", isOn: $settings.settings.preferAirPlayOverSpotify)
                }.modifier(SettingsContainerModifier())
                case .lyrics:
                VStack(alignment: .leading, spacing: 0) {
                    Text("歌词").font(.headline).padding([.top, .horizontal])
                    ToggleRow(title: "在实时活动中显示歌词", description: "存在同步歌词时实时滚动显示歌词。", isOn: $settings.settings.showLyricsInLiveActivity)
                    if settings.settings.showLyricsInLiveActivity {
                        Divider().padding(.leading, 20)
                        ToggleRow(
                            title: "全屏应用下隐藏歌词",
                            description: "当任意显示器上有应用处于全屏状态时隐藏歌词行。也可前往“外观 → 显示器”按屏幕单独设置。",
                            isOn: Binding(
                                get: { settings.settings.hideLyricsInFullScreen },
                                set: { settings.settings.value.setHideLyricsInFullScreenOnAllDisplays($0) }
                            )
                        )
                        Divider().padding(.leading, 20)
                        ToggleRow(title: "启用歌词翻译", description: "自动翻译外语歌词。", isOn: $settings.settings.enableLyricTranslation)
                        HStack {
                            Text("翻译目标语言"); Spacer()
                            Picker("", selection: $settings.settings.lyricTranslationLanguage) { Text("英语").tag("en"); Text("西班牙语").tag("es"); Text("法语").tag("fr") }.labelsHidden().frame(width: 150)
                        }.padding().disabled(!settings.settings.enableLyricTranslation).opacity(settings.settings.enableLyricTranslation ? 1.0 : 0.5)
                        Divider().padding(.leading, 20)
                        HStack {
                            Text("歌词时间偏移"); Spacer()
                            let offset = settings.settings.lyricOffset
                            let label = offset == 0 ? "无偏移" : String(format: "%+.1f 秒", offset)
                            Text(label).font(.caption).foregroundColor(.secondary)
                            Stepper("", value: $settings.settings.lyricOffset, in: -5.0...5.0, step: 0.1)
                                .labelsHidden()
                        }.padding()
                        if #available(macOS 26.0, *) {
                            Divider().padding(.leading, 20)
                            ToggleRow(
                                title: "生成逐字时间轴",
                                description: "当歌曲仅有逐行时间轴时，通过监听本机音乐应用的音频自动对齐逐字时间轴并共享优质结果。首次启用需授权音频访问并下载一次 Apple 语音模型。",
                                isOn: $settings.settings.generateWordTimedLyrics
                            )
                        }
                    }
                }
                .modifier(SettingsContainerModifier())
                .animation(.default, value: settings.settings.showLyricsInLiveActivity)

                if settings.settings.showLyricsInLiveActivity {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("允许获取歌词的应用：").font(.headline).padding([.horizontal, .top])
                        AppTogglesListView(
                            isEnabled: { app in binding(for: app, isBrowser: app.isBrowser) },
                            maxHeight: 360,
                            browsersSectionTitle: "浏览器（默认关闭）"
                        )
                    }.modifier(SettingsContainerModifier()).transition(.opacity.combined(with: .move(edge: .top)))
                }
                }
            }
            .padding(25)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onAppear {
                syncMusicAuthState()
            }
            .onReceive(MusicManager.shared.valuePublisher(\.isPrivateAPIAuthenticated)) { isPrivateAuth = $0 }
            .onReceive(MusicManager.shared.valuePublisher(\.isOfficialAPIAuthenticated)) { isOfficialAuth = $0 }
            .onReceive(MusicManager.shared.valuePublisher(\.isTidalAPIAuthenticated)) { isTidalAuth = $0 }
            .onReceive(MusicManager.shared.tidalAPI.valuePublisher(\.userProfile)) { profile in
                tidalDisplayName = profile?.username
            }
            .onReceive(MusicManager.shared.tidalAPI.valuePublisher(\.loginError)) { tidalLoginError = $0 }
            .onReceive(MusicManager.shared.spotifyOfficialAPI.valuePublisher(\.userProfile)) { profile in
                officialDisplayName = profile?.displayName
            }
            .onReceive(SpotifyPrivateAPIManager.shared.valuePublisher(\.loginChallenge)) { loginChallenge = $0 }
        }
        .sheet(isPresented: $isShowingTidalLogin) {
            TidalLoginWebView(
                onComplete: { isShowingTidalLogin = false },
                onCancel: { isShowingTidalLogin = false }
            )
        }
        .sheet(item: $loginChallenge) { _ in
            SpotifyLoginWebView(
                onComplete: { cookieProperties in
                    MusicManager.shared.spotifyPrivateAPI.completeLoginAfterWebViewSuccess(with: cookieProperties)
                    MusicManager.shared.spotifyPrivateAPI.loginChallenge = nil
                    isPrivateApiLoading = false
                },
                onCancel: {
                    privateApiError = "已取消登录。"
                    MusicManager.shared.spotifyPrivateAPI.loginChallenge = nil
                    isPrivateApiLoading = false
                }
            )
        }
    }

    private func tabTitle(for tab: MusicSettingsTab) -> String {
        switch tab {
        case .general: return "通用"
        case .player: return "播放器"
        case .features: return "功能"
        case .accounts: return "账户"
        case .lyrics: return "歌词"
        }
    }

    private func syncMusicAuthState() {
        let music = MusicManager.shared
        music.spotifyPrivateAPI.bootstrapIfNeeded(policy: .onDemand)
        isPrivateAuth = music.isPrivateAPIAuthenticated
        isOfficialAuth = music.isOfficialAPIAuthenticated
        isTidalAuth = music.isTidalAPIAuthenticated
        tidalDisplayName = music.tidalAPI.userProfile?.username
        officialDisplayName = music.spotifyOfficialAPI.userProfile?.displayName
        tidalLoginError = music.tidalAPI.loginError
        loginChallenge = music.spotifyPrivateAPI.loginChallenge
        if isOfficialAuth, !isPrivateAuth, settings.settings.spotifyAPIMode == .privateAPI {
            settings.settings.spotifyAPIMode = .officialAPI
        }
    }

    private func handlePrivateApiLogin() {
        isPrivateApiLoading = true
        privateApiError = nil
        MusicManager.shared.spotifyPrivateAPI.login()
    }

    private func binding(for app: SystemApp, isBrowser: Bool) -> Binding<Bool> {
        .init(
            get: { settings.settings.musicAppStates[app.id, default: !isBrowser] },
            set: { settings.settings.musicAppStates[app.id] = $0 }
        )
    }

    private func mediaVisibilityBinding(for app: SystemApp, isBrowser: Bool) -> Binding<Bool> {
        .init(
            get: {
                settings.settings.mediaAppVisibility[app.id]
                    ?? true
            },
            set: { settings.settings.mediaAppVisibility[app.id] = $0 }
        )
    }
}

fileprivate struct MusicLongPressActionPickerRow: View {
    let target: MusicLongPressTarget
    @EditingSettings var settings: SettingsEditingSession

    private var selection: Binding<MusicLongPressAction> {
        Binding(
            get: { target.defaultAction(in: settings.settings.value) },
            set: { settings.settings.value.setLongPressAction($0, for: target) }
        )
    }

    var body: some View {
        HStack {
            Text("长按 \(target.displayName)")
                .font(.system(size: 13, weight: .medium))
            Spacer()
            Picker("", selection: selection) {
                ForEach(target.pickerOptions) { action in
                    Text(action.displayName).tag(action)
                }
            }
            .labelsHidden()
            .frame(width: 190)
        }
        .padding()
    }
}

fileprivate struct PlayerButtonSettingsRow: View {
    let buttonType: MusicPlayerButtonType
    @EditingSettings var settings: SettingsEditingSession

    private var isEnabledBinding: Binding<Bool> {
        switch buttonType {
        case .like: return $settings.settings.musicLikeButtonEnabled
        case .shuffle: return $settings.settings.musicShuffleButtonEnabled
        case .repeat: return $settings.settings.musicRepeatButtonEnabled
        case .playlists: return $settings.settings.musicPlaylistsButtonEnabled
        case .devices: return $settings.settings.musicDevicesButtonEnabled
        }
    }

    var body: some View {
        HStack {
            Image(systemName: buttonType.systemImage)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 30)

            Text(buttonType.displayName)
                .font(.system(size: 14, weight: .medium))

            Spacer()

            SettingsSwitch(isOn: isEnabledBinding)

            ReorderHandle()
        }
        .padding(EdgeInsets(top: 18, leading: 20, bottom: 18, trailing: 20))
    }
}

struct WeatherSettingsView: View {
    @EditingSettings var settings: SettingsEditingSession

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                Text("天气")
                    .font(.largeTitle.bold())
                    .padding(.bottom)

                VStack(spacing: 0) {
                    HStack {
                        Text("使用摄氏度 (°C)")
                        Spacer()
                        Toggle("", isOn: $settings.settings.weatherUseCelsius)
                            .labelsHidden().toggleStyle(.switch)
                    }
                    .padding()

                    Rectangle().fill(Color.white.opacity(0.2)).frame(height: 1).padding(.leading, 20)

                    HStack {
                        Text("使用公制单位")
                        Spacer()
                        Toggle("", isOn: $settings.settings.weatherUseMetricSystem)
                            .labelsHidden().toggleStyle(.switch)
                    }
                    .padding()

                    Rectangle().fill(Color.white.opacity(0.2)).frame(height: 1).padding(.leading, 20)

                    HStack {
                        Text("点击实时活动时展开详细天气小组件")
                        Spacer()
                        Toggle("", isOn: $settings.settings.weatherOpenOnClick)
                            .labelsHidden().toggleStyle(.switch)
                    }
                    .padding()
                }
                .modifier(SettingsContainerModifier())

                RequiredPermissionsView(section: .weather)
            }
            .padding(25)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

struct CalendarSettingsView: View {
    @EditingSettings var settings: SettingsEditingSession

    private var isLastEnabledWidget: Bool {
        settings.settings.calendarWidgetEnabled && settings.settings.enabledWidgetTypes.count <= 1
    }

    private var isAtCapacity: Bool {
        !settings.settings.calendarWidgetEnabled && !WidgetLayoutPolicy.canFit(
            .calendar,
            in: settings.settings.enabledWidgetTypes,
            availableWidth: WidgetLayoutPolicy.availableBarWidthForSettings(settings: settings.settings.value),
            showDividers: settings.settings.showDividersBetweenWidgets,
            bypassSpaceLimit: settings.settings.bypassWidgetSpaceLimit
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                Text("日历与提醒事项")
                    .font(.largeTitle.bold())
                    .padding(.bottom)

                VStack(alignment: .leading, spacing: 0) {
                    ToggleRow(
                        title: "启用日历小组件",
                        description: isAtCapacity
                            ? "当前显示器上的灵动岛空间不足。"
                            : "在灵动岛小组件栏中显示日历小组件。",
                        isOn: $settings.settings.calendarWidgetEnabled
                    )
                    .disabled(isLastEnabledWidget || isAtCapacity)

                    Divider().padding(.leading, 20)

                    ToggleRow(
                        title: "启用日历实时活动",
                        description: "在灵动岛中以实时活动展示即将开始的日程。",
                        isOn: $settings.settings.calendarLiveActivityEnabled
                    )
                }
                .modifier(SettingsContainerModifier())

                VStack(spacing: 0) {
                    HStack {
                        Text("显示全天日程")
                        Spacer()
                        Toggle("", isOn: $settings.settings.calendarShowAllDayEvents)
                            .labelsHidden().toggleStyle(.switch)
                    }
                    .padding()

                    Rectangle().fill(Color.white.opacity(0.2)).frame(height: 1).padding(.leading, 20)

                    HStack {
                        Text("每周起始日")
                        Spacer()
                        Picker("", selection: $settings.settings.calendarStartOfWeek) {
                            ForEach(Day.allCases) { day in
                                Text(localizedDayName(day.id)).tag(day)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 120)
                    }
                    .padding()

                    Rectangle().fill(Color.white.opacity(0.2)).frame(height: 1).padding(.leading, 20)

                    ToggleRow(
                        title: "点击时展开日历",
                        description: "点击日历实时活动时展开完整的日历面板。",
                        isOn: $settings.settings.calendarOpenOnClick
                    )
                }
                .modifier(SettingsContainerModifier())

                RequiredPermissionsView(section: .calendar)
            }
            .padding(25)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func localizedDayName(_ raw: String) -> String {
        switch raw.lowercased() {
        case "sunday", "sun": return "周日"
        case "monday", "mon": return "周一"
        case "tuesday", "tue": return "周二"
        case "wednesday", "wed": return "周三"
        case "thursday", "thu": return "周四"
        case "friday", "fri": return "周五"
        case "saturday", "sat": return "周六"
        default: return raw
        }
    }
}
struct EyeBreakRecommendationsView: View {
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("科学护眼建议")
                    .font(.title2.bold())
                Spacer()
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            ScrollView {
                LazyVStack(alignment: .center, spacing: 20) {
                    recommendationCard(
                        title: "20-20-20 护眼法则",
                        description: "每用眼 20 分钟，向 20 英尺（约 6 米）外远眺至少 20 秒，有助于放松眼部肌肉、缓解视觉疲劳。",
                        icon: "eyes",
                        color: .blue
                    )

                    recommendationCard(
                        title: "调整屏幕距离与角度",
                        description: "将显示器放置在约一臂远的位置，并调整倾角使屏幕顶端与视线平齐或略低于视线，减轻颈部与眼部负担。",
                        icon: "display",
                        color: .green
                    )

                    recommendationCard(
                        title: "减少蓝光刺激",
                        description: "在 Mac 上开启“夜览”模式以减少蓝光辐射，尤其在暗光环境或夜间使用时可避免影响睡眠质量。",
                        icon: "moon.stars.fill",
                        color: .orange
                    )

                    recommendationCard(
                        title: "优化环境照明",
                        description: "保持工作区域光线充足柔和且避免屏幕反光眩光，切勿在关灯全黑的房间内仅靠屏幕亮光工作。",
                        icon: "lightbulb.fill",
                        color: .yellow
                    )

                    recommendationCard(
                        title: "保持身体水分充足",
                        description: "全天注意适量饮水，缺水容易加剧眼睛干涩与用眼疲劳。",
                        icon: "drop.fill",
                        color: .cyan
                    )
                }
            }

            Button("知道了") {
                presentationMode.wrappedValue.dismiss()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
        .padding()
        .frame(width: 500, height: 600)
    }

    private func recommendationCard(title: String, description: String, icon: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .frame(minWidth: 400)
        .cornerRadius(12)
    }
}

struct EyeBreakSettingsView: View {
    @EditingSettings var settings: SettingsEditingSession
    @ObservedObject private var eyeBreakManager = EyeBreakManager.shared
    @State private var showingRecommendationsSheet = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                Text("护眼休息")
                    .font(.largeTitle.bold())
                    .padding(.bottom)

                VStack(alignment: .leading, spacing: 0) {
                    ToggleRow(
                        title: "启用护眼休息提醒",
                        description: "通过实时活动定时提醒你远眺休息。",
                        isOn: $settings.settings.eyeBreakLiveActivityEnabled
                    )
                    .onChange(of: settings.settings.eyeBreakLiveActivityEnabled) {
                        eyeBreakManager.dismissBreak()
                    }
                }
                .modifier(SettingsContainerModifier())

                Group {
                    currentStatusSection
                    configurationSection
                    statisticsSection
                    resetSection
                }
                .disabled(!settings.settings.eyeBreakLiveActivityEnabled)
                .opacity(settings.settings.eyeBreakLiveActivityEnabled ? 1.0 : 0.6)
                .animation(.easeInOut(duration: 0.2), value: settings.settings.eyeBreakLiveActivityEnabled)
            }
            .padding(25)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .sheet(isPresented: $showingRecommendationsSheet) {
                EyeBreakRecommendationsView()
            }
        }
    }

    private var currentStatusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("护眼休息状态")
                    .font(.headline)
                Spacer()

                if eyeBreakManager.isPausedForGameMode {
                    Text("游戏模式下已暂停")
                        .foregroundColor(.orange)
                        .padding(6)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(6)
                } else if eyeBreakManager.isBreakTime {
                    Text("正在护眼休息")
                        .foregroundColor(.blue)
                        .padding(6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                } else {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Text("距下次护眼休息还有 \(eyeBreakManager.secondsUntilNextBreak.asMinuteSecondClock)")
                            .foregroundColor(.secondary)
                    }
                }
            }.padding(15)

            if eyeBreakManager.isBreakTime {
                VStack(alignment: .leading, spacing: 4) {
                    Text("请移开视线，暂时离开屏幕")
                        .font(.subheadline)
                        .foregroundColor(.primary)

                    Text("注视至少 20 英尺（约 6 米）外的物体")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ProgressView(value: 1 - (eyeBreakManager.timeRemainingInBreak / TimeInterval(settings.settings.eyeBreakBreakDuration)))
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .padding(.vertical, 4)

                    HStack {
                        Spacer()

                        Button("跳过") {
                            eyeBreakManager.dismissBreak()
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)

                        Button("完成休息") {
                            eyeBreakManager.completeBreak()
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.blue)
                        .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )
            } else {
                HStack(spacing: 20) {
                    VStack(alignment: .center) {
                        Text("\(eyeBreakManager.breaksTakenToday)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.blue)
                        Text("今日已休息")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    Divider()

                    VStack(alignment: .center) {
                        Text("\(eyeBreakManager.currentStreak)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.orange)
                        Text("连续达标天数")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    Divider()

                    VStack(alignment: .center) {
                        Text("\(eyeBreakManager.eyeStrainScore)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(healthColor)
                        Text("眼部健康度")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(12)
            }
        }
        .modifier(SettingsContainerModifier())
    }

    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("参数设置").font(.headline).padding([.top, .horizontal])

            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("20-20-20 护眼法则")
                        .font(.subheadline)
                    Text("每用眼 20 分钟，向 20 英尺（约 6 米）外远眺至少 20 秒。")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button("了解更多") {
                        showingRecommendationsSheet = true
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.top, 4)
                }
                Spacer()
                Image(systemName: "eyes")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())
            }
            .padding([.horizontal, .top])

            Divider()
                .padding(.horizontal)
                .padding(.vertical, 10)

            CustomSliderRowView(
                label: "用眼间隔",
                value: $settings.settings.eyeBreakWorkInterval,
                range: 5...60,
                specifier: "%.0f 分钟",
                onEditingChanged: { isEditing in
                    if !isEditing {
                        eyeBreakManager.dismissBreak()
                    }
                }
            )

            Divider().padding(.leading, 20)

            CustomSliderRowView(
                label: "休息时长",
                value: $settings.settings.eyeBreakBreakDuration,
                range: 10...60,
                specifier: "%.0f 秒",
                onEditingChanged: { isEditing in
                    if !isEditing {
                        eyeBreakManager.dismissBreak()
                    }
                }
            )

            Divider().padding(.leading, 20)

            ToggleRow(
                title: "播放提示音",
                description: "护眼休息开始与结束时播放提示音效。",
                isOn: $settings.settings.eyeBreakSoundAlerts
            )

            Divider().padding(.leading, 20)

            ToggleRow(
                title: "游戏模式期间暂停",
                description: "当 macOS 游戏模式开启时自动暂停护眼提醒与提示音。",
                isOn: $settings.settings.eyeBreakPauseDuringGameMode
            )

            Divider().padding(.leading, 20)

            ToggleRow(
                title: "显示活动统计图表",
                description: "以可视化图表展示你的用眼与休息统计情况。",
                isOn: $settings.settings.showEyeBreakGraph
            )
        }
        .modifier(SettingsContainerModifier())
        .animation(.default, value: settings.settings.showEyeBreakGraph)
    }

    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("护眼活动统计").font(.headline).padding([.top, .horizontal])
            if settings.settings.showEyeBreakGraph {
                EyeBreakGraphView(summaries: eyeBreakManager.dailySummaries)
                    .environment(settings)
                    .padding([.horizontal, .bottom])
                    .transition(.opacity)
            } else {
                Text("请在上方开启“显示活动统计图表”以查看护眼休息统计数据。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .modifier(SettingsContainerModifier())
        .animation(.default, value: settings.settings.showEyeBreakGraph)
    }

    private var resetSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("重置与数据").font(.headline).padding([.top, .horizontal])
            Button(action: {
                eyeBreakManager.dismissBreak()
            }) {
                HStack {
                    Text("重置倒计时")
                    Spacer()
                    Image(systemName: "arrow.clockwise")
                }
                .padding()
            }
            .buttonStyle(.plain)

            Divider().padding(.horizontal)

            Button(action: {
                UserDefaults.standard.removeObject(forKey: "EyeBreakHistory")
                eyeBreakManager.dismissBreak()
            }) {
                HStack {
                    Text("清空全部历史记录")
                        .foregroundColor(.red)
                    Spacer()
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .padding()
            }
            .buttonStyle(.plain)
        }
        .modifier(SettingsContainerModifier())
    }

    private var healthColor: Color {
        let score = eyeBreakManager.eyeStrainScore
        if score > 75 { return .green }
        if score > 50 { return .yellow }
        return .red
    }

}

struct EyeBreakGraphView: View {
    let summaries: [EyeBreakDailySummary]
    @EditingSettings var settings: SettingsEditingSession
    @State private var selectedDayName: String?

    private var selectedSummary: EyeBreakDailySummary? {
        chartData.first { $0.dayName == selectedDayName }?.originalSummary
    }

    private struct ChartableBreakData: Identifiable {
        var id: String { dayName }
        let dayName: String
        let completedBreaks: Int
        let missedBreaks: Int
        let originalSummary: EyeBreakDailySummary
    }

    private var chartData: [ChartableBreakData] {
        summaries.map { summary in
            let workIntervalInSeconds = settings.settings.eyeBreakWorkInterval * 60
            let totalIntervals = workIntervalInSeconds > 0 ? Int(summary.workDuration / workIntervalInSeconds) : 0
            let missed = max(0, totalIntervals - summary.completedBreaks)

            return ChartableBreakData(
                dayName: summary.dayName,
                completedBreaks: summary.completedBreaks,
                missedBreaks: missed,
                originalSummary: summary
            )
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            keyMetricsView

            HStack {
                Text("本周护眼休息动态")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 5)

            barChart
                .frame(height: 180)

            dailySummariesView
        }
    }

    private var keyMetricsView: some View {
        HStack(spacing: 12) {
            MetricCardView(
                title: "今日休息次数",
                value: "\(summaries.first?.completedBreaks ?? 0)",
                icon: "eyes",
                color: .blue,
                trend: "今日 +\(summaries.first?.completedBreaks ?? 0) 次"
            )

            MetricCardView(
                title: "达标率",
                value: "\(Int((summaries.first?.complianceRate ?? 0) * 100))%",
                icon: "checkmark.circle",
                color: complianceColor,
                trend: complianceTrend
            )

            MetricCardView(
                title: "连续坚持",
                value: "\(EyeBreakManager.shared.currentStreak)",
                icon: "bolt",
                color: .orange,
                trend: "连续天数"
            )

            MetricCardView(
                title: "眼部健康度",
                value: "\(summaries.first?.eyeStrainScore ?? 100)",
                icon: "heart.text.square",
                color: eyeHealthColor,
                trend: "/100"
            )
        }
    }

    private var barChart: some View {
        Chart(chartData) { dataPoint in
            BarMark(
                x: .value("日期", dataPoint.dayName),
                y: .value("休息次数", dataPoint.completedBreaks)
            )
            .foregroundStyle(by: .value("类型", "已完成"))
            .cornerRadius(6)

            BarMark(
                x: .value("日期", dataPoint.dayName),
                y: .value("休息次数", dataPoint.missedBreaks)
            )
            .foregroundStyle(by: .value("类型", "已错过"))
            .cornerRadius(6)
        }
        .materialChartPlotStyle()
        .chartForegroundStyleScale([
            "已完成": MaterialChartPalette.primary,
            "已错过": MaterialChartPalette.error.opacity(0.65)
        ])
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(MaterialChartPalette.outline)
                AxisValueLabel("\(value.as(Int.self) ?? 0)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
            }
        }
        .chartXAxis {
            AxisMarks {
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(MaterialChartPalette.outline)
                AxisValueLabel()
                    .font(.system(size: 10, weight: .medium, design: .rounded))
            }
        }
        .chartLegend(position: .top, alignment: .trailing)
        .chartXSelection(value: $selectedDayName)
    }

    private var dailySummariesView: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("每日记录")
                .font(.headline)
                .padding(.horizontal, 5)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(summaries) { summary in
                        DailySummaryCard(summary: summary, isSelected: selectedSummary?.id == summary.id)
                            .onTapGesture {
                                selectedDayName = summary.dayName
                            }
                    }
                }
                .padding(10)
                .padding(.horizontal, 0)
            }
        }
    }

    private var complianceColor: Color {
        let rate = summaries.first?.complianceRate ?? 0
        if rate > 0.8 { return .green }
        if rate > 0.5 { return .yellow }
        return .red
    }

    private var complianceTrend: String {
        let current = summaries.first?.complianceRate ?? 0
        let previous = summaries.dropFirst().first?.complianceRate ?? 0

        if current > previous {
            return "↑ 持续提升"
        } else if current < previous {
            return "↓ 有所下降"
        }
        return "→ 保持平稳"
    }

    private var eyeHealthColor: Color {
        let score = summaries.first?.eyeStrainScore ?? 100
        if score > 75 { return .green }
        if score > 50 { return .yellow }
        return .red
    }
}

struct MetricCardView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let trend: String

    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 10))
            }
            .foregroundColor(.secondary)

            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)

            Text(trend)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
}

struct DailySummaryCard: View {
    let summary: EyeBreakDailySummary
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(summary.dayName)
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(healthStatusColor)
                    .frame(width: 10, height: 10)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("用眼时长")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text(summary.formattedWorkTime)
                        .font(.system(size: 12, weight: .medium))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("休息次数")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("\(summary.completedBreaks)")
                        .font(.system(size: 12, weight: .medium))
                }
            }

            HStack {
                Text("达标率：")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                ProgressView(value: summary.complianceRate)
                    .progressViewStyle(LinearProgressViewStyle(tint: healthStatusColor))
                    .frame(width: 60)

                Text("\(Int(summary.complianceRate * 100))%")
                    .font(.system(size: 10, weight: .medium))
            }
        }
        .padding(10)
        .frame(width: 200)
        .background(isSelected ? Color.secondary.opacity(0.2) : Color.secondary.opacity(0.05))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
    }

    private var healthStatusColor: Color {
        let score = summary.eyeStrainScore
        if score > 75 { return .green }
        if score > 50 { return .yellow }
        return .red
    }
}

struct BluetoothSettingsView: View {
    @EditingSettings var settings: SettingsEditingSession

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                Text("蓝牙")
                    .font(.largeTitle.bold())
                    .padding(.bottom)

                VStack(spacing: 0) {
                    Text("通知").font(.headline).padding([.top, .horizontal])
                    ToggleRow(title: "低电量通知", description: "当已连接设备电量过低时显示提醒。", isOn: $settings.settings.bluetoothNotifyLowBattery)
                    Divider().padding(.leading, 20)
                    ToggleRow(title: "播放连接提示音", description: "当设备连接或断开连接时播放提示音。", isOn: $settings.settings.bluetoothNotifySound)
                }
                .modifier(SettingsContainerModifier())

                VStack(spacing: 0) {
                    Text("实时活动").font(.headline).padding([.top, .horizontal])
                    ToggleRow(title: "显示蓝牙实时活动", description: "显示蓝牙设备的连接、断开及电量事件。", isOn: $settings.settings.bluetoothLiveActivityEnabled)
                    Divider().padding(.leading, 20)
                    ToggleRow(title: "显示跨端互通设备", description: "显示 iPhone、iPad、Mac 和 Apple Watch 等 Apple 设备的实时活动事件。", isOn: $settings.settings.showBluetoothContinuityDevices)
                    Divider().padding(.leading, 20)
                    ToggleRow(title: "显示设备名称", description: "在连接和电量事件的实时活动中显示设备名称。", isOn: $settings.settings.showBluetoothDeviceName)
                }
                .modifier(SettingsContainerModifier())

                RequiredPermissionsView(section: .bluetooth)
            }
            .padding(25)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

struct NearbyShareSettingsView: View {
    @EditingSettings var settings: SettingsEditingSession

    @State private var downloadPath: String = ""
    @State private var isPathValid: Bool = true
    @State private var settingsHaveChanged: Bool = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 40) {
                // MARK: - Nearby Share Section
                VStack(alignment: .leading, spacing: 20) {
                    Text("附近分享")
                        .font(.largeTitle.bold())
                        .padding(.bottom)

                    VStack(spacing: 0) {
                        HStack {
                            Text("启用附近分享")
                                .font(.system(size: 14, weight: .medium))
                            Spacer()
                            SettingsSwitch(isOn: $settings.settings.nearbyShareEnabled)
                        }
                        .padding(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))

                        Rectangle().fill(Color.white.opacity(0.2)).frame(height: 1).padding(.horizontal, 20)

                        InfoContainer(
                            text: "附近分享允许您通过 Android 原生文件分享功能（附近分享 / 快速分享）将文件从 Android 手机发送到 Mac。建议保持启用此功能，以便家人和朋友随时便捷分享。",
                            iconName: "info.circle.fill",
                            color: .blue
                        )
                        .padding()

                        VStack(alignment: .leading, spacing: 15) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("设备显示名称")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white)

                                TextField("我的 Mac", text: $settings.settings.nearbyShareDeviceDisplayName)
                                    .textFieldStyle(.plain)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(Color.black.opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.2), lineWidth: 1))
                                    .foregroundStyle(.white)
                                    .font(.system(size: 13))
                                    .disabled(!settings.settings.nearbyShareEnabled)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("下载位置")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white)

                                HStack {
                                    TextField("路径", text: $downloadPath, onCommit: validateAndSavePath)
                                        .textFieldStyle(.plain)
                                        .foregroundStyle(.white)
                                        .font(.system(size: 13))
                                        .disabled(!settings.settings.nearbyShareEnabled)

                                    Image(systemName: isPathValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(isPathValid ? .green : .red)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color.black.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(isPathValid ? Color.white.opacity(0.2) : Color.red, lineWidth: 1))

                                if !isPathValid {
                                    Text("请输入有效的文件夹路径。")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        .padding([.horizontal, .bottom], 20)
                        .opacity(settings.settings.nearbyShareEnabled ? 1.0 : 0.5)

                        Rectangle().fill(Color.white.opacity(0.2)).frame(height: 1).padding(.horizontal, 20)

                        HStack {
                            Text("点击实时活动时打开详细的 AirDrop 小组件")
                            Spacer()
                            Toggle("", isOn: $settings.settings.nearbyShareOpenOnClick)
                                .labelsHidden().toggleStyle(.switch)
                        }
                        .padding()
                        .disabled(!settings.settings.nearbyShareEnabled)
                        .opacity(settings.settings.nearbyShareEnabled ? 1.0 : 0.5)

                    }
                    .modifier(SettingsContainerModifier())
                    .animation(.easeInOut, value: settings.settings.nearbyShareEnabled)

                    SettingsCard(title: "滑动操作", description: "自定义向左或向右滑动文件拖放行时执行的操作。“分享”仅适用于文件暂存架项目。") {

                        SwipeActionPickerRow(
                            title: "向右滑动",
                            description: "在文件拖放行上从前缘向右滑动。",
                            selection: $settings.settings.swipeActionSettings.fileDropLeading,
                            options: FileDropSwipeAction.allCases,
                            label: { $0.displayName }
                        )

                        Divider().padding(.leading, 20)

                        SwipeActionPickerRow(
                            title: "向左滑动",
                            description: "在文件拖放行上从后缘向左滑动。",
                            selection: $settings.settings.swipeActionSettings.fileDropTrailing,
                            options: FileDropSwipeAction.allCases,
                            label: { $0.displayName }
                        )
                    }
                }
            }
            .padding(25)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onAppear {
                self.downloadPath = settings.settings.nearbyShareDownloadLocationPath
            }
            .onChange(of: downloadPath) { _, newValue in
                self.isPathValid = validate(path: newValue)
            }
            .onChange(of: settings.settings.nearbyShareEnabled) {
                settingsHaveChanged = true
            }
            .onChange(of: settings.settings.nearbyShareDeviceDisplayName) {
                settingsHaveChanged = true
            }
            .animation(.spring(), value: settingsHaveChanged)

            RequiredPermissionsView(section: .nearbyShare)
        }
    }

    private func validateAndSavePath() {
        if validate(path: downloadPath) {
            settings.settings.nearbyShareDownloadLocationPath = downloadPath
        }
    }

    private func validate(path: String) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }
}

struct AboutSettingsView: View {
    private static let backupDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter
    }()

    @EditingSettings var settingsModel: SettingsEditingSession
    @ObservedObject private var updateChecker = UpdateChecker.shared
    @ObservedObject private var permissionsManager = PermissionsManager.shared
    @ObservedObject private var debugMode = DebugMode.shared
    @State private var isExportingSettings = false
    @State private var isImportingSettings = false
    @State private var backupDocument = SettingsBackupDocument(settings: Settings())
    @State private var backupStatusMessage: BackupStatusMessage?
    @State private var showingResetConfirmation = false
    @State private var debugTapCount = 0
    @State private var debugTapResetTask: Task<Void, Never>?

    private var displayedReleaseChannel: ReleaseChannel {
        ReleaseChannelPolicy.displayedChannel(for: settingsModel.settings.value)
    }

    private var releaseChannelBinding: Binding<ReleaseChannel> {
        Binding(
            get: { displayedReleaseChannel },
            set: { newValue in
                guard SubscriptionAccess.hasAccess(to: .betaSoftwareUpdates) || newValue == .stable else { return }
                settingsModel.settings.releaseChannel = newValue
            }
        )
    }

    private var versionLabel: String {
        if BetaEntitlementRuntime.isBetaBuild {
            return "版本 \(currentAppVersion) Beta"
        }
        return "版本 \(currentAppVersion)"
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                Text("关于").font(.largeTitle.bold()).padding(.bottom)

                HStack {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(alignment: .bottomTrailing) {
                            if debugMode.isEnabled {
                                Image(systemName: "hammer.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(6)
                                    .background(Circle().fill(Color.orange))
                                    .offset(x: 6, y: 6)
                            }
                        }
                        .padding(.trailing, 10)
                        .contentShape(Rectangle())
                        .onTapGesture { handleDebugIconTap() }
                        .help(debugMode.isEnabled ? "调试模式已开启 — 快速连点 5 次以关闭" : "快速连点 5 次以开启调试模式")
                    VStack(alignment: .leading, spacing: 4) {
                        Text("星岛 StarIsland").font(.largeTitle.weight(.bold))
                        Text(versionLabel).foregroundStyle(.secondary).textSelection(.enabled)

                        if debugMode.isEnabled {
                            Label("调试模式已启用", systemImage: "hammer.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.orange)
                        }

                        HStack(spacing: 10) {
                            Link(destination: URL(string: "https://sapphire-app.tech/")!) {
                                Image(systemName: "link")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 18, height: 18)
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(Color.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(PlainButtonStyle())

                            Link(destination: UpdateChecker.repositoryWebURL) {
                                Image("github_logo")
                                    .resizable()
                                    .renderingMode(.template)
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 18, height: 18)
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(Color.black)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(PlainButtonStyle())

                            Link(destination: URL(string: "https://discord.gg/TdRjC2kNnU")!) {
                                Image("discord_logo")
                                    .resizable()
                                        .aspectRatio(contentMode: .fit)
                                    .frame(width: 18, height: 18)
                                    .padding(6)
                                    .background(Color(red: 0.35, green: 0.40, blue: 0.95))
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.top, 6)
                    }
                    Spacer()
                }

                sapphireUpdatesPane

                settingsBackupPane

                VStack(alignment: .leading, spacing: 0) {
                    Text("权限概览").font(.headline).padding([.horizontal, .top])
                    ForEach(permissionsManager.allPermissions) { permission in
                        PermissionStatusRowView(permission: permission)
                        if permission.id != permissionsManager.allPermissions.last?.id { Divider().padding(.leading, 60) }
                    }
                }.modifier(SettingsContainerModifier()).onAppear(perform: permissionsManager.checkAllPermissions)

                Text("星岛 StarIsland · 基于 GNU AGPLv3 开源协议构建（致敬上游 Sapphire 架构）").font(.caption).foregroundStyle(.tertiary).frame(maxWidth: .infinity, alignment: .center).padding(.top, 20)
            }.padding(25).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onAppear {
                ReleaseChannelPolicy.reconcileStoredPreference(&settingsModel.settings.value)
                settingsModel.commitNow()
                updateChecker.checkForUpdatesMatchingCurrentChannel()
            }
        }
        .onChange(of: settingsModel.settings.releaseChannel) { _, _ in
            settingsModel.commitNow()
            updateChecker.checkForUpdatesMatchingCurrentChannel()
        }
        .onChange(of: settingsModel.settings.automaticUpdateChecksEnabled) { _, enabled in
            settingsModel.commitNow()
            updateChecker.setAutomaticChecksEnabled(enabled)
        }
        .onChange(of: settingsModel.settings.updateAvailableNotificationsEnabled) { _, enabled in
            if enabled { updateChecker.requestNotificationAuthorization() }
        }
        .onChange(of: settingsModel.settings.automaticallyDownloadSapphireUpdates) { _, enabled in
            guard enabled,
                  settingsModel.settings.automaticUpdateChecksEnabled,
                  case .available(_, let asset) = updateChecker.status else { return }
            updateChecker.downloadUpdate(asset: asset)
        }
        .fileExporter(
            isPresented: $isExportingSettings,
            document: backupDocument,
            contentType: .sapphireSettingsBackup,
            defaultFilename: backupFilename
        ) { result in
            switch result {
            case .success:
                backupStatusMessage = BackupStatusMessage(
                    icon: "checkmark.circle.fill",
                    color: .green,
                    message: "设置备份已成功导出。"
                )
            case .failure(let error):
                backupStatusMessage = BackupStatusMessage(
                    icon: "xmark.octagon.fill",
                    color: .red,
                    message: "导出失败：\(error.localizedDescription)"
                )
            }
        }
        .fileImporter(
            isPresented: $isImportingSettings,
            allowedContentTypes: [.sapphireSettingsBackup, .json]
        ) { result in
            switch result {
            case .success(let url):
                do {
                    try settingsModel.importSettings(from: url)
                    backupStatusMessage = BackupStatusMessage(
                        icon: "arrow.down.doc.fill",
                        color: .green,
                        message: "已从 \(url.lastPathComponent) 导入设置。"
                    )
                } catch {
                    backupStatusMessage = BackupStatusMessage(
                        icon: "xmark.octagon.fill",
                        color: .red,
                        message: "导入失败：\(error.localizedDescription)"
                    )
                }
            case .failure(let error):
                backupStatusMessage = BackupStatusMessage(
                    icon: "xmark.octagon.fill",
                    color: .red,
                    message: "导入失败：\(error.localizedDescription)"
                )
            }
        }
        .confirmationDialog(
            "重置所有设置？",
            isPresented: $showingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("重置设置", role: .destructive) {
                settingsModel.resetAllSettings()
                backupStatusMessage = BackupStatusMessage(
                    icon: "arrow.counterclockwise.circle.fill",
                    color: .orange,
                    message: "所有 Sapphire 设置已恢复为默认值。"
                )
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作将替换您在整个应用中的当前偏好设置。")
        }
    }

    private var settingsBackupPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                SettingsIconBadge(systemImage: "externaldrive.badge.timemachine", color: .blue)

                VStack(alignment: .leading, spacing: 3) {
                    Text("设置备份")
                        .font(.headline)
                    Text("保存一份可迁移的 Sapphire 偏好设置副本，或恢复您之前导出的备份。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding()

            HStack(spacing: 10) {
                Button {
                    backupDocument = settingsModel.makeBackupDocument()
                    isExportingSettings = true
                } label: {
                    Label("导出备份", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    isImportingSettings = true
                } label: {
                    Label("恢复备份", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal)
            .padding(.bottom)

            if let backupStatusMessage {
                HStack(spacing: 8) {
                    Image(systemName: backupStatusMessage.icon)
                        .foregroundStyle(backupStatusMessage.color)
                    Text(backupStatusMessage.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(backupStatusMessage.color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.horizontal)
                .padding(.bottom)
            }

            Divider()

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("恢复初始状态")
                        .font(.subheadline.weight(.medium))
                    Text("将所有 Sapphire 偏好设置恢复为默认值。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(role: .destructive) {
                    showingResetConfirmation = true
                } label: {
                    Label("重置设置", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
            .padding()
        }
        .modifier(SettingsContainerModifier())
    }

    private var sapphireUpdatesPane: some View {
        VStack(alignment: .leading, spacing: 18) {
            ModernUpdateStatusView(updateChecker: updateChecker)

            if let error = updateChecker.lastCheckError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text("发布渠道")
                    .font(.headline)
                    .padding([.horizontal, .top])
                Text("选择接收版本更新的发布渠道。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 10)

                ModernChannelSwitcher(
                    selection: releaseChannelBinding,
                    hasBetaAccess: SubscriptionAccess.hasAccess(to: .betaSoftwareUpdates),
                    isLockedToRunningBuild: false
                )
                .padding(.horizontal)
                .padding(.bottom)

                if BetaEntitlementRuntime.isBetaBuild && settingsModel.settings.releaseChannel == .stable {
                    Text("您当前使用的是测试版。切换到稳定版可安装最新的稳定版本。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                } else if !SubscriptionAccess.hasAccess(to: .betaSoftwareUpdates) {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill").font(.caption2)
                        Text("体验测试版需要 Plus 或更高等级的订阅。")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                }
            }
            .modifier(SettingsContainerModifier())

            VStack(alignment: .leading, spacing: 0) {
                Text("更新偏好设置")
                    .font(.headline)
                    .padding([.horizontal, .top])
                ToggleRow(
                    title: "自动检查更新",
                    description: "在启动、唤醒、网络恢复后以及按固定周期自动检查更新。",
                    isOn: $settingsModel.settings.automaticUpdateChecksEnabled
                )
                Divider().padding(.leading)
                ToggleRow(
                    title: "自动下载已验证的更新",
                    description: "在后台静默下载，安装操作始终由您手动确认。",
                    isOn: $settingsModel.settings.automaticallyDownloadSapphireUpdates
                )
                .disabled(!settingsModel.settings.automaticUpdateChecksEnabled)
                .opacity(settingsModel.settings.automaticUpdateChecksEnabled ? 1 : 0.5)
                Divider().padding(.leading)
                ToggleRow(
                    title: "更新通知",
                    description: "当已验证的 Sapphire 新版本就绪时通知您。",
                    isOn: $settingsModel.settings.updateAvailableNotificationsEnabled
                )
                .disabled(!settingsModel.settings.automaticUpdateChecksEnabled)
                .opacity(settingsModel.settings.automaticUpdateChecksEnabled ? 1 : 0.5)
                Divider().padding(.leading)
                ToggleRow(
                    title: "显示更新实时活动",
                    description: "当有新的 Sapphire 版本可用时，在灵动岛中显示提醒。",
                    isOn: $settingsModel.settings.showUpdateAvailableLiveActivity
                )
            }
            .modifier(SettingsContainerModifier())
        }
    }

    var currentAppVersion: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "未知"
    }

    private func handleDebugIconTap() {
        debugTapCount += 1
        debugTapResetTask?.cancel()
        debugTapResetTask = Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            if !Task.isCancelled {
                await MainActor.run { debugTapCount = 0 }
            }
        }

        if debugTapCount >= DebugMode.requiredTapCount {
            debugTapCount = 0
            debugTapResetTask?.cancel()
            debugTapResetTask = nil
            debugMode.isEnabled.toggle()
        }
    }

    private var backupFilename: String {
        "Sapphire-Settings-\(Self.backupDateFormatter.string(from: .now))"
    }
}

private struct BackupStatusMessage: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
    let message: String
}

struct ModernUpdateStatusView: View {
    @ObservedObject var updateChecker: UpdateChecker
    @State private var upToDateAnimationTrigger = false
    @State private var showingReleaseNotes = false

    private var canShowReleaseNotes: Bool {
        switch updateChecker.status {
        case .upToDate, .available, .downloading, .downloaded:
            return updateChecker.releaseNotes != nil || updateChecker.releaseNotesURL != nil
        default:
            return false
        }
    }

    var body: some View {
        ZStack {
            switch updateChecker.status {
            case .checking:
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("正在检查更新...").foregroundStyle(.secondary)
                }
            case .upToDate:
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.green)
                        .symbolEffect(.bounce, value: upToDateAnimationTrigger)
                    Text("当前已是最新版本！")
                        .foregroundStyle(.secondary)
                    if canShowReleaseNotes {
                        releaseNotesButton
                    }
                    checkForUpdatesButton
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .onAppear {
                    upToDateAnimationTrigger.toggle()
                }
            case .available(let version, let asset):
                VStack(spacing: 12) {
                    Text("新版本 \(version) 现已可用！")
                        .font(.system(size: 16, weight: .bold))

                    Button(action: { updateChecker.downloadUpdate(asset: asset) }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("下载更新")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.accentColor.gradient)
                        .clipShape(Capsule())
                        .shadow(color: .accentColor.opacity(0.4), radius: 8, y: 4)
                    }
                    .buttonStyle(.plain)

                    if canShowReleaseNotes {
                        releaseNotesButton
                    }
                    Button("重新检查") {
                        updateChecker.checkForUpdatesMatchingCurrentChannel()
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            case .downloading(let progress):
                VStack(spacing: 12) {
                    DownloadingView(progress: progress, onCancel: {
                        updateChecker.cancelDownload()
                    })
                    if canShowReleaseNotes {
                        releaseNotesButton
                    }
                }
                .transition(.opacity)
            case .downloaded:
                VStack(spacing: 12) {
                    Text("下载完成！")
                        .font(.system(size: 16, weight: .bold))
                    Button(action: { updateChecker.installAndRelaunch() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                            Text("安装并重启应用")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.green.gradient)
                        .clipShape(Capsule())
                        .shadow(color: .green.opacity(0.4), radius: 8, y: 4)
                    }
                    .buttonStyle(.plain)

                    if canShowReleaseNotes {
                        releaseNotesButton
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            case .installing:
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("正在安装... 应用即将重启。").foregroundStyle(.secondary)
                }
            case .error(let message):
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.octagon.fill").foregroundColor(.red)
                        Text(message).foregroundStyle(.secondary).lineLimit(1)
                    }
                    checkForUpdatesButton
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .modifier(SettingsContainerModifier())
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: updateChecker.status)
        .sheet(isPresented: $showingReleaseNotes) {
            ReleaseNotesSheet(
                version: updateChecker.releaseNotesVersion ?? currentAppVersion,
                notes: updateChecker.releaseNotes,
                url: updateChecker.releaseNotesURL
            )
        }
    }

    private var checkForUpdatesButton: some View {
        Button("检查更新") {
            updateChecker.checkForUpdatesMatchingCurrentChannel()
        }
    }

    private var releaseNotesButton: some View {
        Button {
            showingReleaseNotes = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "doc.text")
                Text("更新日志")
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }
}

private struct ReleaseNotesSheet: View {
    let version: String
    let notes: String?
    let url: URL?
    @Environment(\.dismiss) private var dismiss

    private var attributedNotes: AttributedString? {
        guard let notes else { return nil }
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        return try? AttributedString(markdown: notes, options: options)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("更新日志")
                        .font(.headline)
                    Text("版本 \(version)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let url {
                    Link(destination: url) {
                        Label("GitHub", systemImage: "arrow.up.right.square")
                            .font(.subheadline.weight(.medium))
                    }
                }
                Button("完成") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            ScrollView {
                Group {
                    if let attributedNotes {
                        Text(attributedNotes)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    } else if let notes, !notes.isEmpty {
                        Text(notes)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    } else {
                        VStack(spacing: 10) {
                            Text("此版本未附带更新日志。")
                                .foregroundStyle(.secondary)
                            if let url {
                                Link("在 GitHub 上查看", destination: url)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 480, idealWidth: 560, minHeight: 360, idealHeight: 480)
    }
}

struct DownloadingView: View {
    let progress: Double
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("正在下载更新...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.0f%%", progress * 100))
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
            }

            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.1)).frame(height: 12)
                Capsule()
                    .fill(Color.accentColor.gradient)
                    .frame(width: (300 * progress), height: 12)
                    .animation(.easeOut, value: progress)
            }
            .frame(width: 300)

            Button("取消", action: onCancel)
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct ModernChannelSwitcher: View {
    @Binding var selection: ReleaseChannel
    let hasBetaAccess: Bool
    var isLockedToRunningBuild: Bool = false
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ReleaseChannel.allCases, id: \.self) { channel in
                Text(channel == .stable ? "稳定版" : "测试版")
                    .font(.subheadline.weight(selection == channel ? .semibold : .regular))
                    .foregroundStyle(selection == channel ? .white : .secondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(
                        ZStack {
                            if selection == channel {
                                Capsule()
                                    .fill(Color.accentColor)
                                    .matchedGeometryEffect(id: "channelPill", in: namespace)
                            }
                        }
                    )
                    .contentShape(Capsule())
                    .onTapGesture {
                        guard !isLockedToRunningBuild else { return }
                        guard hasBetaAccess || channel == .stable else { return }
                        withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.85)) {
                            selection = channel
                        }
                    }
                    .opacity(isLockedToRunningBuild && channel != selection ? 0.35 : ((channel == .beta && !hasBetaAccess) ? 0.4 : 1))
            }
        }
        .background(Color.white.opacity(0.08))
        .clipShape(Capsule())
        .opacity(isLockedToRunningBuild ? 0.85 : 1)
    }
}

fileprivate struct NotchButtonRowView: View {
    let buttonType: NotchButtonType

    @EditingSettings var settings: SettingsEditingSession
    @ObservedObject private var permissionsManager = PermissionsManager.shared

    private var isEnabledBinding: Binding<Bool> {
        switch buttonType {
        case .settings, .spacer:
            return .constant(true)
        case .fileShelf: return $settings.settings.fileShelfIconEnabled
        case .notes: return $settings.settings.notesIconEnabled
        case .clipboard: return $settings.settings.clipboardIconEnabled
        case .intelligenceLive, .intelligence:
            return Binding(
                get: {
                    settings.settings.intelligenceEnabled
                        && permissionsManager.areIntelligencePermissionsGranted
                },
                set: { newValue in
                    guard permissionsManager.areIntelligencePermissionsGranted else {
                        settings.settings.intelligenceEnabled = false
                        return
                    }
                    settings.settings.intelligenceEnabled = newValue
                }
            )
        case .focusSession: return $settings.settings.focusSessionIconEnabled
        case .caffeine: return $settings.settings.caffeinateEnabled
        case .battery: return $settings.settings.batteryEstimatorEnabled
        case .continuity: return $settings.settings.continuityShowPhoneBattery
        case .multiAudio: return $settings.settings.showMultiAudioIcon
        case .pin: return $settings.settings.pinEnabled
        }
    }

    private var isToggleDisabled: Bool {
        switch buttonType {
        case .settings, .spacer:
            return true
        case .intelligenceLive, .intelligence:
            return !permissionsManager.areIntelligencePermissionsGranted
        case .focusSession:
            return false
        default:
            return false
        }
    }

    var body: some View {
        HStack {
            if buttonType == .spacer {
                HStack {
                    Rectangle().fill(.secondary).frame(height: 1)
                    Text("居中弹性间距")
                        .font(.caption.bold()).foregroundStyle(.secondary)
                    Rectangle().fill(.secondary).frame(height: 1)
                }
            } else {
                Image(systemName: buttonType.systemImage)
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 30)

                Text(buttonType.displayName)
                    .font(.system(size: 14, weight: .medium))
            }

            Spacer()

            SettingsSwitch(isOn: isEnabledBinding)
                .disabled(isToggleDisabled)
                .opacity(isToggleDisabled ? 0 : 1)

            ReorderHandle()
        }
        .padding(EdgeInsets(top: 18, leading: 20, bottom: 18, trailing: 20))
    }
}

fileprivate struct NotchBarSpacerWidthRow: View {
    @EditingSettings var settings: SettingsEditingSession

    private var widthBinding: Binding<Double> {
        Binding<Double>(
            get: { Double(settings.settings.notchBarSpacerWidth) },
            set: { newValue in
                settings.settings.notchBarSpacerWidth = NotchBarSpacerPolicy.sanitizedWidth(CGFloat(newValue))
            }
        )
    }

    private var isAutomatic: Bool {
        !NotchBarSpacerPolicy.hasFixedWidth(settings.settings.notchBarSpacerWidth)
    }

    var body: some View {
        HStack(spacing: 18) {
            HStack {
                Image(systemName: "space")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 30)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("居中弹性间距宽度")
                        .font(.system(size: 14, weight: .medium))
                    Text(isAutomatic
                         ? "自动：间距随灵动岛栏自动伸展，且始终不窄于灵动岛本身。"
                         : "左右两侧灵动岛栏项目之间的固定间距，且始终不窄于灵动岛本身。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 6) {
                Slider(value: widthBinding, in: Double(NotchBarSpacerPolicy.widthRange.lowerBound)...Double(NotchBarSpacerPolicy.widthRange.upperBound))
                    .frame(width: 180)

                TextField("宽度", value: widthBinding, format: .number.precision(.fractionLength(0)))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 62)
                    .multilineTextAlignment(.trailing)

                Text("pt")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button {
                settings.settings.notchBarSpacerWidth = NotchBarSpacerPolicy.automaticWidth
            } label: {
                Label("重置", systemImage: "arrow.counterclockwise")
                    .font(.callout)
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
            .disabled(isAutomatic)
            .help("恢复为自动弹性间距宽度")
        }
        .padding(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
    }
}

struct AppearanceSettingsView: View {
    @EditingSettings var settings: SettingsEditingSession

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 40) {
                Text("外观")
                    .font(.largeTitle.bold())
                DisplaySettingsView()
                NotchAppearanceDisplaySection()
                MenuBarHidingSettingsView()
                MenuBarProfilesSettingsView()
                MenuBarAppearanceSettingsView()
                MenuBarSpacingSettingsView()
                RequiredPermissionsView(section: .appearance)
            }
            .padding(25)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

struct MenuBarHidingSettingsView: View {
    @EditingSettings var settings: SettingsEditingSession

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("图标隐藏").font(.title2.bold())
                Text("通过可展开的分区隐藏或显示菜单栏图标。").font(.caption).foregroundColor(.secondary)
            }

            VStack(spacing: 0) {
                ToggleRow(title: "启用菜单栏图标隐藏", description: "", isOn: $settings.settings.menuBarEnabled)
            }.modifier(SettingsContainerModifier())

            if settings.settings.menuBarEnabled {
                if ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26 {
                    HStack(alignment: .center, spacing: 12) {
                        InfoContainer(text: "Sapphire 的菜单栏图标需要在“系统设置 → 菜单栏 → 允许在菜单栏中显示”下允许 Sapphire。如果控制图标始终未出现，请检查该开关。", iconName: "menubar.rectangle", color: .blue)
                        Button("打开菜单栏设置…") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.ControlCenter-Settings.extension") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.bordered).controlSize(.small)
                    }
                    .padding()
                    .modifier(SettingsContainerModifier())
                }

                VStack(alignment: .leading, spacing: 0) {

                    Text("控制项图标").font(.headline).padding([.top, .horizontal])
                    Text("为主控制图标选择样式。").font(.caption).foregroundColor(.secondary).padding(.horizontal).padding(.bottom, 10)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(ControlItemIconStyle.allCases) { iconStyle in
                                ControlItemIconPreview(iconStyle: iconStyle, isSelected: settings.settings.controlItemIconStyle == iconStyle) {
                                    withAnimation { settings.settings.controlItemIconStyle = iconStyle }
                                }
                            }
                        }.padding(.horizontal).padding(.bottom, 12)
                    }
                }.modifier(SettingsContainerModifier())

                if MenuBarAgentHost.isActive && MenuBarVisibilityRestrictor.isUsable {
                    MenuBarLayoutEditorView()
                } else if MenuBarAgentHost.isActive && MenuBarVisibilityRestrictor.isAvailable {
                    InfoContainer(text: "仅当安装于“应用程序”文件夹中时，Sapphire 才能通过 macOS 原生菜单栏控制隐藏图标。当前副本从其他位置运行，因此会回退为将分隔符延伸至应用菜单处。", iconName: "exclamationmark.triangle", color: .orange)
                        .padding()
                        .modifier(SettingsContainerModifier())
                }

                VStack(alignment: .leading, spacing: 0) {
                    if !(MenuBarAgentHost.isActive && MenuBarVisibilityRestrictor.isUsable) {
                        InfoContainer(text: "若要自定义显示的图标，请右键点击菜单栏并选择“编辑菜单栏图标”。放置在圆点与展开图标之间的图标将始终显示，放置在两个圆点之间的图标将在收起时隐藏，而放置在最左侧圆点之后的图标将始终隐藏。", iconName: "info.circle", color: Color.mint).padding()

                        Image("MenubarDemo")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 480)
                            .cornerRadius(10)
                            .padding(.horizontal)
                            .padding(.top, 8)
                    }

                    Text("显示隐藏项").font(.headline).padding([.top, .horizontal])
                    ToggleRow(title: "点击时显示", description: "点击菜单栏空白区域时显示隐藏图标", isOn: $settings.settings.showOnClick)
                    Divider().padding(.leading, 20)
                    ToggleRow(title: "悬停时显示", description: "鼠标悬停在菜单栏上时显示隐藏图标", isOn: $settings.settings.showOnHover)
                    if settings.settings.showOnHover {
                        CustomSliderRowView(
                            label: "悬停延迟",
                            value: $settings.settings.showOnHoverDelay,
                            range: 0.1...1.0,
                            specifier: "%.2f 秒"
                        )
                        .padding(.horizontal, 60)
                        .padding(.bottom, 8)
                    }
                    Divider().padding(.leading, 20)
                    ToggleRow(title: "滚动或滑动时显示", description: "在菜单栏空白区域向上滚动或滑动以显示隐藏图标，向下滚动以隐藏", isOn: $settings.settings.showOnScroll)
                    if settings.settings.showOnClick && settings.settings.enableAlwaysHiddenSection {
                        Divider().padding(.leading, 20)
                        ToggleRow(title: "双击显示始终隐藏项", description: "在菜单栏空白区域再次点击即可同时显示“始终隐藏”分区；首次点击仍会立即显示普通隐藏项", isOn: $settings.settings.showAlwaysHiddenOnDoubleClick)
                    }
                    Divider().padding(.leading, 20)
                    ToggleRow(title: "空间不足时隐藏应用菜单", description: "当展开的图标即将与当前应用菜单或灵动岛重叠时，临时收起应用菜单，直到图标重新隐藏", isOn: $settings.settings.hideAppMenusWhenShowingItems)
                }.modifier(SettingsContainerModifier())

                MenuBarHotkeysSettingsSection()

                VStack(alignment: .leading, spacing: 0) {
                    Text("自动重新隐藏").font(.headline).padding([.top, .horizontal])
                    ToggleRow(title: "自动重新隐藏图标", description: "图标展开显示后自动重新隐藏", isOn: $settings.settings.autoRehide)
                    if settings.settings.autoRehide {
                        Divider().padding(.leading, 20)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("重新隐藏策略").font(.subheadline).foregroundColor(.secondary)
                            Picker("", selection: $settings.settings.rehideStrategy) {
                                Text("智能（鼠标移开时）").tag("smart"); Text("定时").tag("timed"); Text("切换应用时").tag("focusedApp")
                            }.pickerStyle(.segmented).padding(.horizontal)
                        }.padding()
                        if settings.settings.rehideStrategy == "timed" {
                            CustomSliderRowView(label: "隐藏延迟", value: $settings.settings.tempShowInterval, range: 1.0...30.0, specifier: "%.1f 秒")
                        }
                        if settings.settings.rehideStrategy != "focusedApp" {
                            Divider().padding(.leading, 20)
                            CustomSliderRowView(label: "已打开菜单保留时长", value: $settings.settings.menuBarKeepOpenedItemsDelay, range: 0...30, specifier: "%.0f 秒")
                            Text("当展开图标的弹出菜单关闭后，在重新隐藏前继续保持图标显示该时长，防止误点导致图标立即收起。设为 0 则立即重新隐藏。")
                                .font(.caption).foregroundColor(.secondary)
                                .padding(.horizontal).padding(.bottom, 10)
                        }
                    }
                }.modifier(SettingsContainerModifier()).animation(.default, value: settings.settings.autoRehide || settings.settings.rehideStrategy == "timed")

                VStack(alignment: .leading, spacing: 0) {
                    Text("隐藏栏外观").font(.headline).padding([.top, .horizontal])
                    ToggleRow(title: "显示分区分隔符", description: "", isOn: $settings.settings.showSectionDividers)
                    Divider().padding(.leading, 20)
                    ToggleRow(title: "启用“始终隐藏”分区", description: "", isOn: $settings.settings.enableAlwaysHiddenSection)
                    Divider().padding(.leading, 20)
                    ToggleRow(title: "隐藏主控制图标", description: "", isOn: $settings.settings.hideMenuBarIcon)
                }.modifier(SettingsContainerModifier())
            }
        }
        .animation(.easeInOut, value: settings.settings.menuBarEnabled)
    }
}

// MARK: - Menu Bar Hotkeys

private struct MenuBarHotkeysSettingsSection: View {
    @EditingSettings var settings: SettingsEditingSession
    @ObservedObject private var shortcutRecorder = GlobalShortcutRecorder.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("快捷键与禅定模式").font(.headline).padding([.top, .horizontal])
            Text("禅定模式会隐藏所有分区，并暂停悬停、点击、滚动及情景模式触发的展开，直到您将其关闭。点击主控制图标也可退出禅定模式。")
                .font(.caption).foregroundColor(.secondary).padding(.horizontal).padding(.bottom, 8)
            recorderRow(title: "切换隐藏图标显示", identifier: "menuBarToggleHiddenShortcut", shortcut: $settings.settings.menuBarToggleHiddenShortcut)
            Divider().padding(.leading, 20)
            recorderRow(title: "切换始终隐藏图标显示", identifier: "menuBarToggleAlwaysHiddenShortcut", shortcut: $settings.settings.menuBarToggleAlwaysHiddenShortcut)
            Divider().padding(.leading, 20)
            recorderRow(title: "搜索菜单栏图标", identifier: "menuBarSearchShortcut", shortcut: $settings.settings.menuBarSearchShortcut)
            Divider().padding(.leading, 20)
            recorderRow(title: "切换禅定模式", identifier: "menuBarZenModeShortcut", shortcut: $settings.settings.menuBarZenModeShortcut)
            Divider().padding(.leading, 20)
            ToggleRow(title: "演示时自动开启禅定模式", description: "当显示器处于镜像状态或通过屏幕共享分享屏幕时自动开启禅定模式，结束后自动关闭。手动开启的禅定模式不受影响", isOn: $settings.settings.menuBarAutoZenWhilePresenting)
            Divider().padding(.leading, 20)
            ToggleRow(title: "摄像头启用时自动开启禅定模式", description: "视频通话期间或任意应用正在使用摄像头时自动开启禅定模式", isOn: $settings.settings.menuBarAutoZenWhileCameraInUse)
            Divider().padding(.leading, 20)
            HStack {
                Text("搜索并打开任意菜单栏项（包括已隐藏项）")
                    .font(.caption).foregroundColor(.secondary)
                Spacer()
                Button("搜索图标…") { MenuBarSearchPanelController.shared.open() }
                    .buttonStyle(.bordered).controlSize(.small)
            }
            .padding()
        }
        .modifier(SettingsContainerModifier())
    }

    private func recorderRow(title: String, identifier: String, shortcut: Binding<KeyboardShortcut>) -> some View {
        let isRecording = shortcutRecorder.isRecording && shortcutRecorder.recordingIdentifier == identifier
        let label = shortcut.wrappedValue.key.isEmpty
            ? "未设置"
            : "\(KeyboardShortcutHelper.description(for: shortcut.wrappedValue.modifiers))\(shortcut.wrappedValue.key)"
        return HStack {
            Text(title).font(.system(size: 14, weight: .medium))
            Spacer()
            if !isRecording {
                Text(label)
                    .font(.caption.monospaced())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.07))
                    .clipShape(Capsule())
            }
            Button(isRecording ? "取消" : "录制…") {
                if isRecording {
                    shortcutRecorder.stopRecording()
                } else {
                    shortcutRecorder.startRecording(identifier: identifier) { key, flags in
                        shortcut.wrappedValue = KeyboardShortcut(key: key, modifiers: flags)
                    }
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            if !shortcut.wrappedValue.key.isEmpty && !isRecording {
                Button {
                    shortcut.wrappedValue = KeyboardShortcut(key: "", modifiers: [])
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("清除快捷键")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}

// MARK: - Menu Bar Profiles (Conditional Reveal + Display/Space/Focus Bindings)

struct MenuBarProfilesSettingsView: View {
    @EditingSettings var settings: SettingsEditingSession

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("菜单栏情景模式").font(.title2.bold())
                Text("当满足特定条件（电量水平、当前专注模式、Wi-Fi 网络或脚本退出码）时自动展开隐藏的菜单栏图标，并可将情景模式绑定到指定显示器、桌面空间或专注模式过滤条件。").font(.caption).foregroundColor(.secondary)
            }

            VStack(spacing: 0) {
                PremiumFeatureView(feature: .menuBarProfiles) {
                    ToggleRow(
                        title: "启用菜单栏情景模式",
                        description: "在后台评估情景模式条件，满足条件时自动展开隐藏图标",
                        isOn: $settings.settings.menuBarProfilesEnabled
                    )
                }
            }.modifier(SettingsContainerModifier())

            if settings.settings.menuBarProfilesEnabled {
                MenuBarProfileEditorView()
                    .premiumFeature(.menuBarProfiles)
            }
        }
        .animation(.easeInOut, value: settings.settings.menuBarProfilesEnabled)
    }
}

private struct MenuBarProfileEditorView: View {
    @EditingSettings var settings: SettingsEditingSession
    @State private var expandedProfileIDs: Set<UUID> = []

    private var profilesBinding: Binding<[MenuBarProfile]> {
        $settings.settings.menuBarProfiles
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("情景模式列表").font(.headline)
                Spacer()
                Button {
                    let newProfile = MenuBarProfile(name: "情景模式 \(settings.settings.menuBarProfiles.count + 1)")
                    _ = withAnimation(.easeInOut(duration: 0.2)) { expandedProfileIDs.insert(newProfile.id) }
                    settings.settings.menuBarProfiles.append(newProfile)
                } label: {
                    Label("添加情景模式", systemImage: "plus")
                        .font(.callout)
                }
                .buttonStyle(.plain)
            }

            if settings.settings.menuBarProfiles.isEmpty {
                InfoContainer(
                    text: "创建情景模式并添加展开条件，还可选择将其绑定到特定显示器、桌面空间或专注模式。当所绑定的场景处于活动状态且满足任一条件时，隐藏图标将自动展开。",
                    iconName: "info.circle",
                    color: .mint
                ).padding()
                .modifier(SettingsContainerModifier())
            } else {
                VStack(spacing: 12) {
                    ForEach(profilesBinding) { $profile in
                        MenuBarProfileCardView(profile: $profile, isExpanded: expandedProfileIDs.contains(profile.id)) { changed in
                            if changed {
                                expandedProfileIDs.insert(profile.id)
                            } else {
                                expandedProfileIDs.remove(profile.id)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct MenuBarProfileCardView: View {
    @Binding var profile: MenuBarProfile
    let isExpanded: Bool
    var onExpandedChange: (Bool) -> Void = { _ in }
    @EditingSettings var settings: SettingsEditingSession

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: profile.symbolName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)

                TextField("情景模式名称", text: $profile.name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                Text(profile.summaryText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                SettingsSwitch(isOn: $profile.isEnabled)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { onExpandedChange(!isExpanded) }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button {
                    settings.settings.menuBarProfiles.removeAll { $0.id == profile.id }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                Divider()

                MenuBarRevealConditionsSection(profile: $profile)

                Divider()

                MenuBarProfileBindingsSection(profile: $profile)
            }
        }
        .padding()
        .modifier(SettingsContainerModifier())
    }
}

// MARK: - Reveal Conditions

private struct MenuBarRevealConditionsSection: View {
    @Binding var profile: MenuBarProfile
    @State private var focusOptions: [MenuBarProfileEngine.FocusModeOption] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("展开触发条件").font(.subheadline.weight(.semibold))
                Spacer()
                Menu {
                    ForEach(MenuBarRevealConditionKind.allCases) { kind in
                        Button {
                            profile.revealConditions.append(MenuBarRevealCondition(kind: kind))
                        } label: {
                            Label(kind.displayName, systemImage: kind.systemImage)
                        }
                    }
                } label: {
                    Label("添加条件", systemImage: "plus.circle")
                        .font(.callout)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            if profile.revealConditions.isEmpty {
                Text("暂无条件 — 此情景模式不会自动展开任何图标。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach($profile.revealConditions) { $condition in
                    HStack(spacing: 10) {
                        Image(systemName: condition.kind.systemImage)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(width: 18)

                        MenuBarRevealConditionEditor(condition: $condition, focusOptions: focusOptions)

                        Button {
                            let doomed = condition.id
                            DispatchQueue.main.async {
                                profile.revealConditions.removeAll { $0.id == doomed }
                            }
                        } label: {
                            Image(systemName: "minus.circle")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .onAppear { refreshFocusOptions() }
    }

    private func refreshFocusOptions() {
        Task.detached(priority: .utility) {
            let options = MenuBarProfileEngine.fetchAvailableFocusModes()
            await MainActor.run { self.focusOptions = options }
        }
    }
}

private struct MenuBarRevealConditionEditor: View {
    @Binding var condition: MenuBarRevealCondition
    let focusOptions: [MenuBarProfileEngine.FocusModeOption]

    var body: some View {
        HStack(spacing: 8) {
            Picker("", selection: $condition.kind) {
                ForEach(MenuBarRevealConditionKind.allCases) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 210)

            switch condition.kind {
            case .batteryBelow, .batteryAbove:
                HStack(spacing: 4) {
                    TextField("电量", value: $condition.batteryThreshold, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 50)
                    Text("%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

            case .charging:
                Text("连接电源时")
                    .font(.caption)
                    .foregroundColor(.secondary)

            case .onBatteryPower:
                Text("使用电池供电时")
                    .font(.caption)
                    .foregroundColor(.secondary)

            case .focusActive:
                Text("任意专注模式")
                    .font(.caption)
                    .foregroundColor(.secondary)

            case .focusIdentifier:
                Picker("", selection: $condition.focusIdentifier) {
                    Text("选择专注模式…").tag("")
                    ForEach(focusOptions) { option in
                        Label(option.name, systemImage: option.symbolName).tag(option.identifier)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 190)

            case .wifiEquals:
                TextField("Wi-Fi 网络名称", text: $condition.wifiNetworkName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 170)

            case .wifiConnected:
                Text("任意网络")
                    .font(.caption)
                    .foregroundColor(.secondary)

            case .scriptSucceeds, .scriptFails, .scriptExitCode:
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        TextField("脚本路径", text: $condition.scriptPath)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 220)
                        if condition.kind == .scriptExitCode {
                            Text("退出码 =")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("0", value: $condition.scriptExitCode, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 44)
                        }
                    }
                    HStack(spacing: 6) {
                        TextField("可选参数", text: $condition.scriptArgument)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 140)
                        Text("检查间隔")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("30", value: $condition.scriptPollInterval, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 44)
                        Text("秒")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Profile Bindings

private struct MenuBarProfileBindingsSection: View {
    @Binding var profile: MenuBarProfile
    @EditingSettings var settings: SettingsEditingSession

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("绑定场景").font(.subheadline.weight(.semibold))

            ToggleRow(
                title: "显示器",
                description: "仅在所选显示器上应用此情景模式",
                isOn: $profile.bindsToDisplays
            )
            if profile.bindsToDisplays {
                MenuBarDisplayBindingsEditor(profile: $profile)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }

            ToggleRow(
                title: "桌面空间",
                description: "仅在所选桌面空间上应用此情景模式（编号与空间切换器一致）",
                isOn: $profile.bindsToSpaces
            )
            if profile.bindsToSpaces {
                MenuBarSpaceBindingsEditor(profile: $profile)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }

            ToggleRow(
                title: "专注模式",
                description: "仅在所选专注模式处于活动状态时应用此情景模式",
                isOn: $profile.bindsToFocus
            )
            if profile.bindsToFocus {
                MenuBarFocusBindingsEditor(profile: $profile)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
        }
    }
}

private struct MenuBarDisplayBindingsEditor: View {
    @Binding var profile: MenuBarProfile

    private var connectedScreens: [NSScreen] { NSScreen.screens }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("", selection: $profile.displayScope) {
                Text("所有显示器").tag(MenuBarProfileDisplayScope.allDisplays)
                Text("指定显示器").tag(MenuBarProfileDisplayScope.selectedDisplays)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if profile.displayScope == .selectedDisplays {
                if connectedScreens.isEmpty {
                    Text("未检测到显示器。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    VStack(spacing: 4) {
                        ForEach(connectedScreens, id: \.displayIdentifier) { screen in
                            let id = screen.displayIdentifier
                            let ids = screen.displayIdentifierCandidates
                            let isBound = profile.displayBindings.contains { ids.contains($0.displayIdentifier) }
                            Button {
                                if isBound {
                                    profile.displayBindings.removeAll { ids.contains($0.displayIdentifier) }
                                } else {
                                    profile.displayBindings.append(MenuBarDisplayBinding(displayIdentifier: id, displayLabel: screen.displayLabel))
                                }
                            } label: {
                                HStack {
                                    Image(systemName: isBound ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(isBound ? Color.accentColor : Color.secondary)
                                    Image(systemName: CGDisplayIsBuiltin(screen.displayID) != 0 ? "laptopcomputer" : "display")
                                    Text(screen.displayLabel)
                                        .font(.callout)
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

private struct MenuBarSpaceBindingsEditor: View {
    @Binding var profile: MenuBarProfile
    @State private var availableSpaces: Int = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("启用此情景模式的桌面空间：")
                .font(.caption)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(1...max(1, availableSpaces), id: \.self) { number in
                        let isBound = profile.spaceNumbers.contains(number)
                        Button {
                            if isBound {
                                profile.spaceNumbers.removeAll { $0 == number }
                            } else {
                                profile.spaceNumbers.append(number)
                                profile.spaceNumbers.sort()
                            }
                        } label: {
                            Text("\(number)")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .frame(width: 32, height: 28)
                                .background(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(isBound ? Color.accentColor.opacity(0.25) : Color.white.opacity(0.06))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .stroke(isBound ? Color.accentColor : Color.white.opacity(0.12), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }

            HStack {
                Text("检测到的空间数：\(availableSpaces)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Stepper("增减空间数量", onIncrement: { availableSpaces += 1 }, onDecrement: { availableSpaces = max(1, availableSpaces - 1) })
                    .font(.caption)
            }
        }
    }
}

private struct MenuBarFocusBindingsEditor: View {
    @Binding var profile: MenuBarProfile
    @State private var focusOptions: [MenuBarProfileEngine.FocusModeOption] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if focusOptions.isEmpty {
                Text("未找到专注模式（或因缺少专注模式权限而无法读取）。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 4) {
                    ForEach(focusOptions) { option in
                        let isBound = profile.focusIdentifiers.contains(option.identifier)
                        Button {
                            if isBound {
                                profile.focusIdentifiers.removeAll { $0 == option.identifier }
                            } else {
                                profile.focusIdentifiers.append(option.identifier)
                            }
                        } label: {
                            HStack {
                                Image(systemName: isBound ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isBound ? Color.accentColor : Color.secondary)
                                Image(systemName: option.symbolName)
                                    .font(.callout)
                                Text(option.name)
                                    .font(.callout)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Text("若不勾选任何具体项目，仅开启“专注模式”开关即可绑定到任意专注模式。")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .onAppear { refreshFocusOptions() }
    }

    private func refreshFocusOptions() {
        Task.detached(priority: .utility) {
            let options = MenuBarProfileEngine.fetchAvailableFocusModes()
            await MainActor.run { self.focusOptions = options }
        }
    }
}

struct MenuBarAppearanceEditor: View {
    @EditingSettings var settings: SettingsEditingSession

    private var opacityBinding: Binding<Double> {
        Binding(
            get: { settings.settings.menuBarOpacity * 100 },
            set: { settings.settings.menuBarOpacity = $0 / 100 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("菜单栏色调").font(.headline)
                Spacer()
                Button("重置", action: resetTintSettings)
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
            }
            .padding([.top, .horizontal])

            ToggleRow(title: "液态玻璃质感", description: "为菜单栏背景应用通透亮泽的玻璃光感效果。", isOn: $settings.settings.menuBarLiquidGlass)

            if settings.settings.menuBarLiquidGlass {
                Divider().padding(.leading, 20)
                LiquidGlassStylePickerRow(selection: $settings.settings.menuBarLiquidGlassStyle)

                Divider().padding(.leading, 20)
                ToggleRow(
                    title: "磨砂叠加层",
                    description: "在基础玻璃层之上叠加磨砂液态玻璃质感，与锁屏界面风格保持一致。",
                    isOn: $settings.settings.menuBarBlur
                )
            }

            Divider().padding(.leading, 20)

            HStack {
                Text("背景样式")
                Spacer()
                Picker("", selection: $settings.settings.menuBarTintStyle) {
                    Text("无").tag("none"); Text("纯色").tag("solid"); Text("渐变").tag("gradient"); Text("自适应").tag("adaptive")
                }.labelsHidden().frame(width: 200)
            }.padding()

            if settings.settings.menuBarTintStyle == "solid" {
                solidColorPicker
            } else if settings.settings.menuBarTintStyle == "gradient" {
                gradientColorEditor
            } else if settings.settings.menuBarTintStyle == "adaptive" {
                Divider().padding(.leading, 20)
                ToggleRow(
                    title: "双色渐变",
                    description: "自适应色调会跟随菜单栏后方的壁纸色彩变化。开启后将自然融合左右两侧的色彩，而非使用单一平均色。",
                    isOn: $settings.settings.menuBarAdaptiveTintGradient
                )
            }

            Divider().padding(.leading, 20)

                    CustomSliderRowView(label: "整体不透明度", value: opacityBinding, range: 0...100, specifier: "%.0f%%")

            if !settings.settings.menuBarLiquidGlass {
                Divider().padding(.leading, 20)
                ToggleRow(title: "启用透明模糊", description: "为菜单栏背景应用毛玻璃模糊效果。", isOn: $settings.settings.menuBarBlur)
            }
        }
        .modifier(SettingsContainerModifier())
        .animation(.default, value: settings.settings.menuBarLiquidGlass)
        .animation(.default, value: settings.settings.menuBarBlur)
        .animation(.default, value: settings.settings.menuBarTintStyle)
    }

    @ViewBuilder
    private var solidColorPicker: some View {
        ColorPicker("颜色", selection: $settings.settings.menuBarSolidColor.color, supportsOpacity: true)
            .padding()
            .transition(.opacity)
    }

    @ViewBuilder
    private var gradientColorEditor: some View {
        VStack(alignment: .leading) {
            CustomSliderRowView(label: "渐变角度", value: $settings.settings.menuBarGradientAngle, range: 0...360, specifier: "%.0f°")
                .padding(.horizontal)

            Text("渐变色标").font(.subheadline).padding(.horizontal)

            ForEach($settings.settings.menuBarGradientColors) { $color in
                VStack(spacing: 8) {
                    HStack {
                        ColorPicker("色标颜色", selection: $color.color, supportsOpacity: true)
                        Spacer()
                        Button(action: {
                            guard settings.settings.menuBarGradientColors.count > 1 else { return }
                            let doomed = color.id
                            DispatchQueue.main.async {
                                settings.settings.menuBarGradientColors.removeAll { $0.id == doomed }
                            }
                        }) {
                            Image(systemName: "minus.circle.fill").foregroundColor(.red)
                        }.buttonStyle(.plain).disabled(settings.settings.menuBarGradientColors.count <= 1)
                    }
                    DeferredValueEditor(value: $color.location.asDouble) { draft, onEditingChanged in
                        Slider(
                            value: draft,
                            in: 0...1,
                            label: { Text("位置") },
                            onEditingChanged: onEditingChanged
                        )
                    }
                }.padding(.horizontal)
            }

            Button(action: {
                var colors = settings.settings.menuBarGradientColors
                let newStop = CodableColor(color: colors.last?.color ?? .black, location: 1.0)
                colors.append(newStop)
                settings.settings.menuBarGradientColors = colors
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("添加色标")
                }
            }.buttonStyle(.plain).tint(.accentColor).padding([.top, .horizontal])
        }
        .padding(.vertical)
        .transition(.opacity)
    }

    private func resetTintSettings() {
        var updated = settings.settings.value
        updated.menuBarLiquidGlass = false
        updated.menuBarLiquidGlassStyle = .frosted
        updated.menuBarTintStyle = "none"
        updated.menuBarSolidColor = CodableColor(color: .clear)
        updated.menuBarGradientAngle = 0.0
        updated.menuBarGradientColors = [
            CodableColor(color: .white, location: 0),
            CodableColor(color: .black, location: 1)
        ]
        updated.menuBarOpacity = 1.0
        updated.menuBarBlur = false
        settings.settings.value = updated
    }
}

struct MenuBarAppearanceSettingsView: View {
    @EditingSettings var settings: SettingsEditingSession

    private var verticalPaddingBinding: Binding<Double> {
        Binding<Double>(
            get: { Double(settings.settings.menuBarVerticalPadding) },
            set: { settings.settings.menuBarVerticalPadding = CGFloat($0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("菜单栏样式（测试版）").font(.title2.bold())
                    Text("自定义 Mac 菜单栏的视觉外观与质感。").font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Button("全部重置", action: resetAllAppearanceSettings)
                    .buttonStyle(.plain)
            }

            MenuBarAppearanceEditor()

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("边框粗细"); Spacer()
                    Picker("边框", selection: $settings.settings.menuBarBorderWidth) {
                        Text("无边框").tag(CGFloat(0)); Text("1px").tag(CGFloat(1)); Text("2px").tag(CGFloat(2)); Text("3px").tag(CGFloat(3))
                    }.labelsHidden().frame(width: 120)
                }.padding()
                Divider().padding(.horizontal)
                ColorPicker("边框颜色", selection: $settings.settings.menuBarBorderColor.color, supportsOpacity: true).padding()
            }.modifier(SettingsContainerModifier())

            VStack(alignment: .leading, spacing: 0) {
                Toggle(isOn: Binding(
                    get: { settings.settings.menuBarShapeStyle == "rounded" },
                    set: { if $0 { settings.settings.menuBarShapeStyle = "rounded" } else if settings.settings.menuBarShapeStyle == "rounded" { settings.settings.menuBarShapeStyle = "none" } }
                )) {
                    Text("圆角菜单栏")
                }.padding()

                Divider().padding(.horizontal)

                Toggle(isOn: Binding(
                    get: { settings.settings.menuBarShapeStyle == "roundedSplit" },
                    set: { if $0 { settings.settings.menuBarShapeStyle = "roundedSplit" } else if settings.settings.menuBarShapeStyle == "roundedSplit" { settings.settings.menuBarShapeStyle = "none" } }
                )) {
                    Text("左右分段圆角")
                }.padding()

                Divider().padding(.horizontal)
                CustomSliderRowView(label: "垂直内边距", value: verticalPaddingBinding, range: 0...10, specifier: "%.0fpx")

            }.modifier(SettingsContainerModifier()).animation(.default, value: settings.settings.menuBarShapeStyle)
        }
    }

    private func resetAllAppearanceSettings() {
        var updated = settings.settings.value
        updated.menuBarLiquidGlass = false
        updated.menuBarLiquidGlassStyle = .frosted
        updated.menuBarTintStyle = "none"
        updated.menuBarSolidColor = CodableColor(color: .clear)
        updated.menuBarGradientAngle = 0.0
        updated.menuBarGradientColors = [
            CodableColor(color: .white, location: 0),
            CodableColor(color: .black, location: 1)
        ]
        updated.menuBarOpacity = 1.0
        updated.menuBarBlur = false

        updated.menuBarBorderWidth = 0
        updated.menuBarBorderColor = CodableColor(color: .black)

        updated.menuBarShapeStyle = "none"
        updated.menuBarVerticalPadding = 0
        settings.settings.value = updated
    }
}

struct MenuBarSpacingSettingsView: View {
    @EditingSettings var settings: SettingsEditingSession
    @State private var spacingManager: MenuBarSpacingManager?

    private var spacingBinding: Binding<Double> {
        Binding<Double>(
            get: { Double(settings.settings.menuBarSpacing) },
            set: { settings.settings.menuBarSpacing = Int($0) }
        )
    }

    private var paddingBinding: Binding<Double> {
        Binding<Double>(
            get: { Double(settings.settings.menuBarSelectionPadding) },
            set: { settings.settings.menuBarSelectionPadding = Int($0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("菜单栏间距（测试版）").font(.title2.bold())
                Text("微调所有菜单栏图标之间的间距与内边距。更改需刷新菜单栏后方可生效。").font(.caption).foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 0) {
                CustomSliderRowView(label: "图标间距", value: spacingBinding, range: 1...50, specifier: "%.0f")
                Divider().padding(.leading, 20)
                CustomSliderRowView(label: "内边距", value: paddingBinding, range: 1...50, specifier: "%.0f")

                HStack {
                    Button("恢复系统默认值") {
                        spacingManager?.restoreDefaults()
                    }
                    .disabled(spacingManager == nil)

                    Spacer()

                    Button("应用并刷新菜单栏") {
                        spacingManager?.applyChanges()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(spacingManager == nil)
                }
                .padding()

            }.modifier(SettingsContainerModifier())
        }
        .onAppear {
            if spacingManager == nil {
                spacingManager = MenuBarSpacingManager()
            }
        }
    }
}

struct ControlItemIconPreview: View {
    let iconStyle: ControlItemIconStyle
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: iconStyle.previewSymbol)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(isSelected ? .white : .secondary)
                .frame(width: 60, height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.accentColor : Color.secondary.opacity(isHovered ? 0.15 : 0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isSelected ? Color.accentColor : Color.clear,
                            lineWidth: 2
                        )
                )

            Text(iconStyle.displayName)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .primary : .secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 70)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .scaleEffect(isHovered && !isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

extension View {
    @ViewBuilder
    func dynamicXAxis(for range: TimeRange, isVisible: Bool) -> some View {
        if isVisible {
            switch range {
            case .last24Hours:
                self.chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisValueLabel(format: .dateTime.hour()) } }
            case .last7Days:
                self.chartXAxis { AxisMarks(values: .automatic(desiredCount: 7)) { _ in AxisValueLabel(format: .dateTime.weekday()) } }
            case .lastMonth, .custom:
                self.chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) { _ in AxisValueLabel(format: .dateTime.day()) } }
            case .lastYear:
                self.chartXAxis { AxisMarks(values: .automatic(desiredCount: 6)) { _ in AxisValueLabel(format: .dateTime.month(.abbreviated)) } }
            }
        } else {
            self.chartXAxis(.hidden)
        }
    }
}

extension View {
    func chartInteractionOverlay<T: Identifiable>(
        proxy: ChartProxy,
        data: [T],
        keyPath: KeyPath<T, Date>,
        selectedItem: Binding<T?>
    ) -> some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(.clear)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if let date: Date = proxy.value(atX: value.location.x) {
                                let closest = data.min {
                                    abs($0[keyPath: keyPath].timeIntervalSince(date)) <
                                    abs($1[keyPath: keyPath].timeIntervalSince(date))
                                }
                                selectedItem.wrappedValue = closest
                            }
                        }
                        .onEnded { _ in
                            selectedItem.wrappedValue = nil
                        }
                )
        }
    }
}

struct ModernSegmentedPicker: View {
    @Binding var selection: String
    let options: [String]

    @Namespace private var pickerNamespace

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.self) { option in
                Text(option)
                    .font(.headline.weight(.bold))
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity)
                    .background(
                        ZStack {
                            if selection == option {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .shadow(color: .black.opacity(0.15), radius: 5, y: 3)
                                    .matchedGeometryEffect(id: "pickerPill", in: pickerNamespace)
                            }
                        }
                    )
                    .foregroundColor(selection == option ? .primary : .secondary)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.7, blendDuration: 0.7)) {
                            selection = option
                        }
                    }
            }
        }
        .padding(6)
        .background(Color.black.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

typealias GeminiSettingsView = IntelligenceSettingsView

// MARK: - Legacy Settings View Shims

// MARK: - Task Runner Interface

struct IntelligenceRunnerView: View {
    let apiKey: String
    var backend: LLMBackend = .auto
    var geminiSpeedMode: GeminiSpeedMode = .fast
    @ObservedObject private var vm: IntelligenceNotchViewModel
    @State private var isRunningScreenshotDebug = false

    init(
        apiKey: String,
        backend: LLMBackend = .gemini,
        geminiSpeedMode: GeminiSpeedMode = .fast,
        vm: IntelligenceNotchViewModel? = nil
    ) {
        self.apiKey = apiKey
        self.backend = backend
        self.geminiSpeedMode = geminiSpeedMode
        let resolvedVM = vm ?? (NSApp.delegate as? AppDelegate)?.intelligenceViewModel ?? IntelligenceNotchViewModel()
        self._vm = ObservedObject(wrappedValue: resolvedVM)
    }

    private var isLaunchDisabled: Bool {
        if vm.taskInput.trimmingCharacters(in: .whitespaces).isEmpty {
            return true
        }
        return !backend.isKeyConfigured && backend.resolveAPIKey(fallbackGeminiKey: apiKey).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                TextField("描述要执行的任务...", text: $vm.taskInput)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(Color.black.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.15)))
                    .onSubmit {
                        if !vm.isRunning && !isLaunchDisabled {
                            let activeKey = backend.resolveAPIKey(fallbackGeminiKey: apiKey)
                            vm.run(
                                apiKey: activeKey,
                                backend: backend,
                                geminiSpeedMode: geminiSpeedMode
                            )
                        }
                    }

                if vm.isRunning {
                    Button(action: vm.stop) {
                        Image(systemName: "stop.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 32, height: 32)
                    .background(Color.red.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Button {
                        let activeKey = backend.resolveAPIKey(fallbackGeminiKey: apiKey)
                        vm.run(
                            apiKey: activeKey,
                            backend: backend,
                            geminiSpeedMode: geminiSpeedMode
                        )
                    } label: {
                        Image(systemName: "play.fill")
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 32, height: 32)
                    .background(isLaunchDisabled ? Color.gray.opacity(0.3) : Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .disabled(isLaunchDisabled)
                }

                Button {
                    runScreenshotDebug()
                } label: {
                    Image(systemName: isRunningScreenshotDebug ? "camera.fill" : "camera")
                        .foregroundStyle(isRunningScreenshotDebug ? .yellow : .white)
                }
                .buttonStyle(.plain)
                .frame(width: 32, height: 32)
                .background(Color.orange.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .help("每隔 1.5 秒捕获一张截图，共 10 张")
                .disabled(isRunningScreenshotDebug)
            }

            if backend == .hackclub {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Hack Club AI 集成")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        SecureField("Hack Club API 密钥", text: Binding(
                            get: { APIKeyManager.shared.hackClubAPIKey },
                            set: { APIKeyManager.shared.hackClubAPIKey = $0 }
                        ))
                        .textFieldStyle(.plain)
                        .padding(6)
                        .background(Color.black.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.12)))

                        TextField("模型名称", text: Binding(
                            get: { UserDefaults.standard.string(forKey: "hackClubModel") ?? "qwen/qwen3-32b" },
                            set: { UserDefaults.standard.set($0, forKey: "hackClubModel") }
                        ))
                        .textFieldStyle(.plain)
                        .padding(6)
                        .background(Color.black.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.12)))
                    }
                }
                .padding(.top, 4)
            }

            if vm.isRunning && vm.subtaskProgress.total > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("子任务 \(vm.subtaskProgress.current) / \(vm.subtaskProgress.total)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        ProgressView().scaleEffect(0.6)
                    }
                    ProgressView(value: Double(vm.subtaskProgress.current),
                                 total: Double(vm.subtaskProgress.total))
                        .tint(.blue)
                }
            }

            if let result = vm.lastResult {
                HStack(spacing: 6) {
                    Image(systemName: result.success ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundStyle(result.success ? .green : .orange)
                    Text(result.success ? "已完成" : "部分完成")
                        .font(.caption.bold())
                    Text("· 子任务 \(result.subtasksCompleted)/\(result.subtasksTotal) · 操作 \(result.actionsTaken) 次 · \(String(format: "%.1f 秒", result.duration))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !vm.logEntries.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 3) {
                        ForEach(vm.logEntries.reversed()) { line in
                            Text(line.text)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(
                                    line.isError ? Color.red :
                                    line.isSubtask ? Color.orange :
                                    Color.secondary
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: 140)
                .background(Color.black.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func runScreenshotDebug() {
        guard !isRunningScreenshotDebug else { return }
        isRunningScreenshotDebug = true

        Task { @MainActor in
            defer { isRunningScreenshotDebug = false }

            let perception = ScreenPerception()
            vm.logEntries.append(.init(text: " 截图调试已启动（10 张 / 间隔 1.5 秒）", isError: false, isSubtask: true))

            for index in 1...10 {
                let (image, elements) = await perception.captureAnnotatedScreen()
                let imageNote = image == nil ? "无图像" : "图像正常"
                vm.logEntries.append(.init(text: " [\(index)/10] \(imageNote) · \(elements.count) 个元素", isError: false, isSubtask: true))
                if index < 10 {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                }
            }

            vm.logEntries.append(.init(text: " 截图调试已完成", isError: false, isSubtask: true))
        }
    }
}

// MARK: - Focus Session Settings

struct FocusSessionSettingsView: View {
    private struct AppCandidate: Identifiable, Sendable {
        let name: String
        let bundleID: String
        var id: String { bundleID }
    }

    @EditingSettings var settings: SettingsEditingSession
    @StateObject private var shortcutRecorder = GlobalShortcutRecorder.shared
    @StateObject private var ambient = FocusAmbientSoundManager.shared
    @StateObject private var shortcutsCatalog = ShortcutsCatalog.shared
    @StateObject private var profileStore = FocusProfileStore.shared
    @State private var newBlockedApp: String = ""
    @State private var newBlockedSite: String = ""
    @State private var showingAddSchedule = false
    @State private var appCandidates: [AppCandidate] = []
    @State private var availableFocusModes: [(id: String, name: String)] = []

    nonisolated private static func loadInstalledApps() -> [AppCandidate] {
        InstalledApplications.namesAndBundleIDs().map { AppCandidate(name: $0.name, bundleID: $0.bundleID) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                Text("专注时段")
                    .font(.largeTitle.bold())
                    .padding(.bottom)

                FocusInsightsPanel(manager: FocusSessionManager.shared)
                    .environmentObject(FocusSessionManager.shared)

                profilesSection
                durationSection
                blockingSection
                socialSection
                triggersSection
                schedulingSection
                liveActivityToggleSection
                environmentSection
                automationSection
            }
            .padding(25)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .task {
            guard appCandidates.isEmpty else { return }
            let candidates = await Task.detached(priority: .utility) {
                Self.loadInstalledApps()
            }.value
            guard !Task.isCancelled else { return }
            appCandidates = candidates
            availableFocusModes = MenuBarProfileEngine.fetchAvailableFocusModes()
                .map { (id: $0.identifier, name: $0.name) }
        }
    }

    private var profilesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("情景模式")
            Text("每个情景模式都拥有独立的计时器、屏蔽名单和社交信息流过滤规则。您可以分别设置是否同步开启状态和配置项。")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 6)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(profileStore.profiles) { profile in
                        Button {
                            profileStore.select(profile.id)
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: profile.symbolName)
                                    .font(.system(size: 18, weight: .semibold))
                                Text(profile.name)
                                    .font(.system(size: 11, weight: .semibold))
                                    .lineLimit(1)
                            }
                            .frame(width: 88, height: 72)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(profile.id == profileStore.activeProfileID
                                          ? profile.accentColor.opacity(0.28)
                                          : Color.primary.opacity(0.06))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(profile.id == profileStore.activeProfileID
                                                  ? profile.accentColor.opacity(0.8)
                                                  : Color.clear, lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("复制副本") {
                                var copy = profile
                                copy.id = UUID()
                                copy.name = profile.name + " 副本"
                                profileStore.upsert(copy)
                            }
                            if profileStore.profiles.count > 1 {
                                Button("删除", role: .destructive) {
                                    profileStore.delete(id: profile.id)
                                }
                            }
                        }
                    }
                    Button {
                        let p = FocusProfile.makeDefault(name: "新建情景模式", symbol: "sparkles")
                        profileStore.upsert(p)
                        profileStore.select(p.id)
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 44, height: 72)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }

            Divider().opacity(0.3).padding(.horizontal, 16)

            HStack {
                Text("名称")
                    .font(.system(size: 13))
                Spacer()
                TextField("名称", text: Binding(
                    get: { profileStore.activeProfile.name },
                    set: { name in profileStore.updateActive { $0.name = name } }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 160)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)

            Divider().opacity(0.3).padding(.horizontal, 16)
            ToggleRow(
                title: "与手机同步开始与结束",
                description: "在此设备启动或结束该情景模式时，在 Android 手机上同步执行。",
                isOn: Binding(
                    get: { profileStore.activeProfile.syncActivation },
                    set: { v in profileStore.updateActive { $0.syncActivation = v } }
                )
            )
            Divider().opacity(0.3).padding(.horizontal, 16)
            ToggleRow(
                title: "同步此情景模式的设置",
                description: "镜像同步屏蔽名单和社媒过滤规则；关闭后可在各设备上单独自定义。",
                isOn: Binding(
                    get: { profileStore.activeProfile.syncSettings },
                    set: { v in profileStore.updateActive { $0.syncSettings = v } }
                )
            )
            Divider().opacity(0.3).padding(.horizontal, 16)
            ToggleRow(
                title: "同时同步系统专注模式 / 勿扰模式",
                description: "双向同步 macOS 专注模式与 Android 勿扰模式。",
                isOn: $settings.settings.continuitySyncNotificationMode
            )
        }
        .modifier(SettingsContainerModifier())
    }

    private var socialSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("社媒信息流过滤")
            Text("精准屏蔽短视频信息流，无需默认封禁整个应用。")
                .font(.caption).foregroundColor(.secondary)
                .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 4)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 0) {
                socialChip("Instagram Reels", \.blockInstagramReels)
                socialChip("Instagram 发现页", \.blockInstagramExplore)
                socialChip("仅看已关注", \.instagramFollowingOnly)
                socialChip("YouTube Shorts", \.blockYouTubeShorts)
                socialChip("Facebook Reels", \.blockFacebookReels)
                socialChip("TikTok", \.blockTikTok)
                socialChip("Snapchat 聚光灯", \.blockSnapchatSpotlight)
                socialChip("网页端短视频", \.blockShortFormWeb)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .modifier(SettingsContainerModifier())
    }

    private func socialChip(_ title: String, _ keyPath: WritableKeyPath<FocusSocialFilters, Bool>) -> some View {
        let on = profileStore.activeProfile.social[keyPath: keyPath]
        return Button {
            profileStore.updateActive { $0.social[keyPath: keyPath].toggle() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(on ? Color.purple : Color.secondary)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(on ? Color.purple.opacity(0.12) : Color.primary.opacity(0.04))
            )
            .padding(6)
        }
        .buttonStyle(.plain)
    }

    private func socialToggle(_ title: String, _ keyPath: WritableKeyPath<FocusSocialFilters, Bool>) -> some View {
        socialChip(title, keyPath)
    }

    private var triggersSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("自动启动触发条件")
            Text("当指定的 macOS 专注模式开启或手机进入勿扰模式时，自动启动此情景模式。")
                .font(.caption).foregroundColor(.secondary)
                .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 6)

            if availableFocusModes.isEmpty {
                Text("未找到 macOS 专注模式。请开启专注状态权限，并在“系统设置”中创建专注模式。")
                    .font(.caption).foregroundColor(.secondary)
                    .padding(.horizontal, 16).padding(.vertical, 10)
            } else {
                ForEach(availableFocusModes, id: \.id) { mode in
                    let selected = profileStore.activeProfile.triggers.macOSFocusModeIDs.contains(mode.id)
                    ToggleRow(
                        title: mode.name,
                        description: "当“\(mode.name)”开启时自动启动此情景模式",
                        isOn: Binding(
                            get: { selected },
                            set: { on in
                                profileStore.updateActive { p in
                                    if on {
                                        if !p.triggers.macOSFocusModeIDs.contains(mode.id) {
                                            p.triggers.macOSFocusModeIDs.append(mode.id)
                                        }
                                        if !p.triggers.macOSFocusModeNames.contains(mode.name) {
                                            p.triggers.macOSFocusModeNames.append(mode.name)
                                        }
                                    } else {
                                        p.triggers.macOSFocusModeIDs.removeAll { $0 == mode.id }
                                        p.triggers.macOSFocusModeNames.removeAll { $0 == mode.name }
                                    }
                                }
                            }
                        )
                    )
                    Divider().opacity(0.3).padding(.horizontal, 16)
                }
            }

            ToggleRow(
                title: "Android 勿扰模式",
                description: "当手机进入勿扰模式时自动启动（需启用跨端互通）。",
                isOn: Binding(
                    get: { profileStore.activeProfile.triggers.androidDND || profileStore.activeProfile.triggers.syncPeerSystemFocus },
                    set: { v in
                        profileStore.updateActive {
                            $0.triggers.androidDND = v
                            $0.triggers.syncPeerSystemFocus = v
                        }
                    }
                )
            )
        }
        .modifier(SettingsContainerModifier())
    }

    private var schedulingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("定时计划")
            Text("在每天的指定时间自动开始专注时段 — 支持每天、每周指定星期、每周、每月或单次运行。")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 6)

            if settings.settings.scheduledFocusSessions.isEmpty {
                Text("暂无定时专注计划。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            } else {
                ForEach($settings.settings.scheduledFocusSessions) { $schedule in
                    FocusScheduleRowView(schedule: $schedule)
                    Divider().opacity(0.3).padding(.horizontal, 16)
                }
            }

            Divider().opacity(0.3).padding(.horizontal, 16)
            Button {
                showingAddSchedule = true
            } label: {
                Label("添加定时计划", systemImage: "plus.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.green)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .modifier(SettingsContainerModifier())
        .sheet(isPresented: $showingAddSchedule) {
            AddFocusScheduleView().environment(settings)
        }
    }

    private var liveActivityToggleSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("小组件与实时活动")
            ToggleRow(
                title: "在灵动岛中显示",
                description: "专注时段进行期间，在灵动岛中作为实时活动显示。",
                isOn: $settings.settings.focusSessionLiveActivityEnabled
            )
            Divider().opacity(0.3).padding(.horizontal, 16)
            ToggleRow(
                title: "显示剩余时间而非进度环",
                description: "在右侧显示剩余时间数字，而非闭合进度圆环。",
                isOn: $settings.settings.focusSessionLiveActivityShowTime
            )
            Divider().opacity(0.3).padding(.horizontal, 16)
            ToggleRow(
                title: "休息与专注通知",
                description: "在专注阶段结束开始休息、休息结束以及整个专注时段完成时发送通知。",
                isOn: $settings.settings.focusNotificationsEnabled
            )
            Divider().opacity(0.3).padding(.horizontal, 16)
            ToggleRow(
                title: "点击打开详情视图",
                description: "点击专注时段实时活动时打开完整详情视图。",
                isOn: $settings.settings.clickToShowFocusSessionView
            )
        }
        .modifier(SettingsContainerModifier())
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("时长设置")
            HStack {
                Text("专注时长：")
                    .font(.system(size: 13))
                Spacer()
                TextField("分钟", value: Binding(
                    get: { settings.settings.focusSessionDuration / 60 },
                    set: { settings.settings.focusSessionDuration = max(1, $0) * 60 }
                ), format: .number.precision(.fractionLength(0)))
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1)
                    .frame(width: 62)
                    .multilineTextAlignment(.trailing)
                    .help("无上限 — 可输入任意分钟数")
                Text("分钟")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)

            Divider().opacity(0.3).padding(.horizontal, 16)

            ToggleRow(title: "启用中途休息", description: "每个专注阶段结束后自动进入休息时间。", isOn: $settings.settings.focusBreakEnabled)
            if settings.settings.focusBreakEnabled {
                Divider().opacity(0.3).padding(.horizontal, 16)
                HStack {
                    Text("休息时长：")
                        .font(.system(size: 13))
                    Spacer()
                    TextField("分钟", value: Binding(
                        get: { settings.settings.focusBreakDuration / 60 },
                        set: { settings.settings.focusBreakDuration = max(0, $0) * 60 }
                    ), format: .number.precision(.fractionLength(0)))
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1)
                        .frame(width: 62)
                        .multilineTextAlignment(.trailing)
                        .help("无上限 — 可输入任意分钟数（设为 0 则禁用休息）")
                    Text("分钟")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
            }
        }
        .modifier(SettingsContainerModifier())
    }

    private var blockingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("应用与网站屏蔽")
            ToggleRow(title: "启用屏蔽", description: "在专注时段期间屏蔽容易分心的应用和网站。", isOn: $settings.settings.focusBlockingEnabled)
            if settings.settings.focusBlockingEnabled {
                Divider().opacity(0.3).padding(.horizontal, 16)
                Picker("屏蔽模式", selection: $settings.settings.focusBlockingMode) {
                    ForEach(FocusBlockingMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                Text(settings.settings.focusBlockingMode.blurb)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16).padding(.bottom, 8)

                Divider().opacity(0.3).padding(.horizontal, 16)
                HStack(spacing: 8) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 5))
                    Text("屏蔽强度")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.top, 10).padding(.horizontal, 16).padding(.bottom, 6)
                Text("设置专注时段期间对被屏蔽应用（及网站）的拦截严格程度。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                if FocusSessionManager.shared.isSessionActive {
                    Label("专注时段进行期间无法更改屏蔽强度", systemImage: "lock.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 6)
                }

                ForEach(FocusIntensity.allCases) { level in
                    Button {
                        guard !FocusSessionManager.shared.isSessionActive else { return }
                        settings.settings.focusIntensity = level
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: level.systemImage)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(settings.settings.focusIntensity == level ? .green : .secondary)
                                .frame(width: 22)
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(level.displayName)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.primary)
                                    if settings.settings.focusIntensity == level {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.green)
                                    }
                                }
                                Text(level.blurb)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(settings.settings.focusIntensity == level ? Color.green.opacity(0.12) : Color.white.opacity(0.05))
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
                    .opacity(FocusSessionManager.shared.isSessionActive ? 0.45 : 1.0)
                }
                .padding(.bottom, 6)

                Divider().opacity(0.3).padding(.horizontal, 16)

                if settings.settings.focusBlockingMode == .allowlist {
                    Divider().opacity(0.3).padding(.horizontal, 16)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("允许使用的应用")
                            .font(.caption.bold()).padding(.horizontal, 16).padding(.top, 10)
                        Picker("添加应用", selection: $newBlockedApp) {
                            Text("选择应用…").tag("")
                            ForEach(appCandidates, id: \.bundleID) { candidate in
                                Text(candidate.name).tag(candidate.bundleID)
                            }
                        }
                        .padding(.horizontal, 16)
                        HStack {
                            Spacer()
                            Button("添加") {
                                guard !newBlockedApp.isEmpty else { return }
                                settings.settings.focusAllowedApps.insert(newBlockedApp)
                                newBlockedApp = ""
                            }
                            .disabled(newBlockedApp.isEmpty)
                            .padding(.trailing, 16)
                        }
                        if !settings.settings.focusAllowedApps.isEmpty {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], alignment: .leading, spacing: 4) {
                                ForEach(Array(settings.settings.focusAllowedApps), id: \.self) { bundleID in
                                    let name = appCandidates.first(where: { $0.bundleID == bundleID })?.name ?? bundleID
                                    chipView(name) { settings.settings.focusAllowedApps.remove(bundleID) }
                                }
                            }
                            .padding(.horizontal, 16).padding(.bottom, 8)
                        }
                    }
                } else {
                    Divider().opacity(0.3).padding(.horizontal, 16)
                    ToggleRow(title: "休息期间继续屏蔽", description: "在中途休息期间保持屏蔽规则生效。", isOn: $settings.settings.focusBlockingDuringBreaks)

                    Divider().opacity(0.3).padding(.horizontal, 16)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("已屏蔽的应用")
                            .font(.caption.bold()).padding(.horizontal, 16).padding(.top, 10)
                    Picker("添加应用", selection: $newBlockedApp) {
                        Text("选择应用…").tag("")
                        ForEach(appCandidates, id: \.bundleID) { candidate in
                            Text(candidate.name).tag(candidate.bundleID)
                        }
                    }
                    .padding(.horizontal, 16)
                    HStack {
                        Spacer()
                        Button("添加") {
                            guard !newBlockedApp.isEmpty else { return }
                            settings.settings.focusBlockedApps.insert(newBlockedApp)
                            newBlockedApp = ""
                        }
                        .disabled(newBlockedApp.isEmpty)
                        .padding(.trailing, 16)
                    }
                    if !settings.settings.focusBlockedApps.isEmpty {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], alignment: .leading, spacing: 4) {
                            ForEach(Array(settings.settings.focusBlockedApps), id: \.self) { bundleID in
                                let name = appCandidates.first(where: { $0.bundleID == bundleID })?.name ?? bundleID
                                chipView(name) { settings.settings.focusBlockedApps.remove(bundleID) }
                            }
                        }
                        .padding(.horizontal, 16).padding(.bottom, 8)
                    }

                    Divider().opacity(0.3).padding(.horizontal, 16)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("已屏蔽的网站")
                            .font(.caption.bold()).padding(.horizontal, 16).padding(.top, 10)
                        HStack {
                            TextField("例如：twitter.com", text: $newBlockedSite)
                                .textFieldStyle(.roundedBorder)
                                .padding(.leading, 16)
                            Button("添加") {
                                let trimmed = newBlockedSite
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
                                    .replacingOccurrences(of: "https://", with: "")
                                    .replacingOccurrences(of: "http://", with: "")
                                    .replacingOccurrences(of: "www.", with: "")
                                guard !trimmed.isEmpty else { return }
                                settings.settings.focusBlockedWebsites.insert(trimmed)
                                newBlockedSite = ""
                            }
                            .disabled(newBlockedSite.trimmingCharacters(in: .whitespaces).isEmpty)
                            .padding(.trailing, 16)
                        }
                        if !settings.settings.focusBlockedWebsites.isEmpty {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], alignment: .leading, spacing: 4) {
                                ForEach(Array(settings.settings.focusBlockedWebsites), id: \.self) { site in
                                    chipView(" \(site)") { settings.settings.focusBlockedWebsites.remove(site) }
                                }
                            }
                            .padding(.horizontal, 16).padding(.bottom, 8)
                        }
                    }
                    .padding(.bottom, 8)
                    }
                }
            }
        }
        .modifier(SettingsContainerModifier())
    }

    private var environmentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("专注环境")
            Text("在专注时段运行期间对整台 Mac 应用沉浸式环境调节。")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 8)

            ToggleRow(title: "压暗非活动应用", description: "压暗当前未在使用的窗口，突出前台应用并减少视觉干扰。", isOn: $settings.settings.focusDimInactiveApps)
            if settings.settings.focusDimInactiveApps {
                Divider().opacity(0.3).padding(.horizontal, 16)
                HStack {
                    Text("压暗程度：")
                        .font(.system(size: 13))
                    Spacer()
                    DeferredSlider(value: $settings.settings.focusDimInactiveOpacity, in: 0.2...1.0)
                        .frame(width: 160)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)

                Divider().opacity(0.3).padding(.horizontal, 16)
                ToggleRow(title: "在调度中心中暂停", description: "打开调度中心时临时移除压暗遮罩，以便清晰查看所有窗口缩略图。", isOn: $settings.settings.focusDisableDimInMissionControl)
            }

            Divider().opacity(0.3).padding(.horizontal, 16)
            ToggleRow(title: "隐藏桌面壁纸", description: "在专注时段期间以纯黑背景遮盖桌面壁纸与桌面图标。", isOn: $settings.settings.focusHideWallpaper)

            Divider().opacity(0.3).padding(.horizontal, 16)
            ToggleRow(title: "限制可见应用数量", description: "屏幕上仅保留少量可见应用；切换到新应用时会自动隐藏最早打开的应用（专注时段结束后自动恢复）。", isOn: $settings.settings.focusAppLimitEnabled)
            if settings.settings.focusAppLimitEnabled {
                Divider().opacity(0.3).padding(.horizontal, 16)
                HStack {
                    Text("最多可见应用数：")
                        .font(.system(size: 13))
                    Spacer()
                    Stepper(value: $settings.settings.focusAppLimit, in: 1...6) {
                        Text("\(settings.settings.focusAppLimit)")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
            }

            Divider().opacity(0.3).padding(.horizontal, 16)
            ToggleRow(title: "环境白噪音", description: "播放合成的白噪音、粉红噪音、棕噪音或雨声以隔绝周围嘈杂声，每次专注时段启动时自动播放。", isOn: $settings.settings.focusAmbientSoundEnabled)
            if settings.settings.focusAmbientSoundEnabled {
                Divider().opacity(0.3).padding(.horizontal, 16)
                Picker("音效", selection: $settings.settings.focusAmbientSoundType) {
                    ForEach(FocusAmbientSoundType.allCases) { type in
                        Label(type.displayName, systemImage: type.systemImage).tag(type)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                Divider().opacity(0.3).padding(.horizontal, 16)
                HStack(spacing: 12) {
                    Button(action: { ambient.toggle() }) {
                        Label(ambient.isPlaying ? "停止" : "试听", systemImage: ambient.isPlaying ? "stop.fill" : "play.fill")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    Text("音量")
                        .font(.system(size: 13))
                    DeferredSlider(
                        value: Binding(
                            get: { settings.settings.focusAmbientSoundVolume },
                            set: {
                                ambient.volume = $0
                                settings.settings.focusAmbientSoundVolume = $0
                            }
                        ),
                        in: 0...1,
                        onDraftChange: { ambient.volume = $0 }
                    )
                    .frame(width: 110)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
            }
        }
        .modifier(SettingsContainerModifier())
        .onChange(of: settings.settings.focusAmbientSoundType) { _, newType in
            if ambient.isPlaying { ambient.setType(newType) }
        }
        .onChange(of: settings.settings.focusAmbientSoundEnabled) { _, enabled in
            if !enabled, ambient.isPlaying { ambient.stop() }
        }
    }

    private var automationSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("自动化与快捷指令")

            Text("在任意位置按下此全局快捷键即可开始或暂停专注时段。")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 8)
            Button(action: {
                if shortcutRecorder.isRecording {
                    shortcutRecorder.stopRecording()
                } else {
                    shortcutRecorder.startRecording { key, flags in
                        settings.settings.focusStartShortcut = KeyboardShortcut(key: key, modifiers: flags)
                    }
                }
            }) {
                HStack {
                    if shortcutRecorder.isRecording {
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.7)
                            Text("正在录制...（按 Esc 取消）")
                                .foregroundColor(.accentColor)
                        }
                    } else {
                        Image(systemName: "keyboard")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Text("\(KeyboardShortcutHelper.description(for: settings.settings.focusStartShortcut.modifiers)) \(settings.settings.focusStartShortcut.key)")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16).padding(.bottom, 12)

            Divider().opacity(0.3).padding(.horizontal, 16)

            HStack(spacing: 8) {
                Image(systemName: "link.icloud")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 20, height: 20)
                    .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 5))
                Text("系统时钟与快捷指令")
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.top, 10).padding(.horizontal, 16).padding(.bottom, 6)
            Text("Sapphire 会自动调用 Apple 标准时钟快捷指令名称（如“Start Timer”、“Start Stopwatch”等）。如果已开启 iCloud 同步且当前 Mac 上存在这些时钟快捷指令，专注时段期间将自动运行它们。")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16).padding(.top, 2).padding(.bottom, 8)
            ToggleRow(title: "与系统时钟同步", description: "通过“快捷指令”将专注时段同步到系统“时钟”应用。", isOn: $settings.settings.focusShortcutsEnabled)
            if settings.settings.focusShortcutsEnabled {
                Divider().opacity(0.3).padding(.horizontal, 16)
                Picker("同步模式", selection: $settings.settings.focusShortcutSyncMode) {
                    ForEach(FocusShortcutSyncMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
            }

            Divider().opacity(0.3).padding(.horizontal, 16)
            Text("在专注时段开始或结束时运行指定的快捷指令 — 例如自动开启勿扰模式。")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 6)
            Picker("开始时运行", selection: $settings.settings.focusStartShortcutName) {
                Text("无").tag("")
                ForEach(shortcutsCatalog.installedNames, id: \.self) { name in
                    Text(name).tag(name)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 4)
            Picker("结束时运行", selection: $settings.settings.focusEndShortcutName) {
                Text("无").tag("")
                ForEach(shortcutsCatalog.installedNames, id: \.self) { name in
                    Text(name).tag(name)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 4)
            .padding(.bottom, 8)
        }
        .modifier(SettingsContainerModifier())
        .onAppear {
            FocusSessionManager.refreshInstalledShortcuts()
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .padding(.top, 12).padding(.horizontal, 16).padding(.bottom, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func chipView(_ text: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 3) {
            Text(text).font(.caption).lineLimit(1)
            Button(action: onRemove) { Image(systemName: "xmark.circle.fill").font(.caption) }.buttonStyle(.plain)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Color.white.opacity(0.08), in: Capsule())
    }
}

// MARK: - Scheduled Focus Sessions

private struct FocusScheduleRowView: View {
    @EditingSettings private var settings: SettingsEditingSession
    @Binding var schedule: ScheduledFocusSession

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.fill")
                .font(.system(size: 12))
                .foregroundColor(schedule.isActive ? .green : .secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(schedule.startTime, style: .time)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(schedule.isActive ? .primary : .secondary)
                    Text(schedule.repeatDescription)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            SettingsSwitch(isOn: $schedule.isActive)
                .controlSize(.mini)

            Button {
                settings.settings.scheduledFocusSessions.removeAll { $0.id == schedule.id }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
            .help("删除定时计划")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var subtitle: String {
        var text = "\(Int(schedule.duration / 60)) 分钟专注时段"
        if schedule.isActive,
           let next = FocusScheduleManager.shared.nextFireDate(for: schedule) {
            let day = Calendar.current.isDateInToday(next)
                ? "今天" : (Calendar.current.isDateInTomorrow(next) ? "明天" : next.formatted(date: .abbreviated, time: .omitted))
            text += " · 下次运行：\(day) \(next.formatted(date: .omitted, time: .shortened))"
        }
        return text
    }
}

private struct AddFocusScheduleView: View {
    @Environment(\.dismiss) private var dismiss
    @EditingSettings private var settings: SettingsEditingSession
    private struct WeekdayToken: Identifiable {
        let number: Int
        let label: String
        var id: Int { number }
    }

    private static let weekdayChoices: [WeekdayToken] = [
        WeekdayToken(number: 2, label: "周一"),
        WeekdayToken(number: 3, label: "周二"),
        WeekdayToken(number: 4, label: "周三"),
        WeekdayToken(number: 5, label: "周四"),
        WeekdayToken(number: 6, label: "周五"),
        WeekdayToken(number: 7, label: "周六"),
        WeekdayToken(number: 1, label: "周日"),
    ]

    @State private var startTime = Date().addingTimeInterval(60 * 60)
    @State private var repeatInterval: FocusScheduleRepeat = .daily
    @State private var repeatWeekdays: [Int] = []
    @State private var durationMinutes: Double = 90

    var body: some View {
        VStack(spacing: 20) {
            Text("新建定时专注计划")
                .font(.title.bold())

            VStack(spacing: 16) {
                DatePicker("开始时间：", selection: $startTime, displayedComponents: .hourAndMinute)

                Picker("重复：", selection: $repeatInterval) {
                    ForEach(FocusScheduleRepeat.allCases) { interval in
                        Text(interval.displayName).tag(interval)
                    }
                }

                if repeatInterval == .custom {
                    Divider().opacity(0.2)
                    weekdayPicker
                }

                HStack {
                    Text("专注时长：")
                    Spacer()
                    TextField("分钟", value: Binding(
                        get: { durationMinutes },
                        set: { durationMinutes = max(1, $0) }
                    ), format: .number.precision(.fractionLength(0)))
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1)
                        .frame(width: 62)
                        .multilineTextAlignment(.trailing)
                        .help("无上限 — 可输入任意分钟数")
                    Text("分钟")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Text("定时专注时段会自动遵循您的屏蔽名单、专注环境及环境白噪音设置，效果与手动启动完全一致。")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .modifier(SettingsContainerModifier())

            HStack {
                Button("取消", role: .cancel) { dismiss() }
                Spacer()
                Button("添加计划") {
                    var schedule = ScheduledFocusSession()
                    schedule.startTime = startTime
                    schedule.repeatInterval = repeatInterval
                    schedule.duration = durationMinutes * 60
                    if repeatInterval == .custom {
                        schedule.repeatWeekdays = repeatWeekdays
                    }
                    settings.settings.scheduledFocusSessions.append(schedule)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(30)
        .frame(width: 420)
        .onAppear {
            durationMinutes = settings.settings.focusSessionDuration / 60
        }
    }

    private var weekdayPicker: some View {
        VStack(spacing: 8) {
            HStack {
                Text("重复星期")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Button(repeatWeekdays.isEmpty ? "每天" : "清空所选") {
                    repeatWeekdays = []
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundColor(.green)
            }

            HStack(spacing: 6) {
                ForEach(Self.weekdayChoices) { token in
                    weekdayPill(token)
                }
            }
        }
    }

    private func weekdayPill(_ token: WeekdayToken) -> some View {
        let isOn = repeatWeekdays.contains(token.number)
        return Button {
            if isOn {
                repeatWeekdays.removeAll { $0 == token.number }
            } else {
                repeatWeekdays.append(token.number)
            }
        } label: {
            Text(token.label)
                .font(.system(size: 11, weight: isOn ? .bold : .medium))
                .foregroundColor(isOn ? .white : .secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .background(
                    isOn ? Color.green : Color.white.opacity(0.08),
                    in: Capsule()
                )
        }        .buttonStyle(.plain)
        .help(token.label)
    }
}
