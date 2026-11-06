//
//  OnboardingView.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2025-07-09.
//

import SwiftUI
import AVKit
import ServiceManagement

// MARK: - Main Onboarding View
struct OnboardingView: View {
    enum OnboardingStep {
        case welcome, permissions, helperInstallation, privacyPolicy, musicChoice, spotifySetup, batterySetup, corePreferences, lockScreenSetup, subscriptionOverview, finish
    }

    @State private var currentStep: OnboardingStep = .welcome
    var onComplete: () -> Void

    @ObservedSettings var settings: SettingsObserver
    var musicManager: MusicManager { .shared }

    @State private var isPrivateApiLoading = false
    @State private var privateApiError: String?

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.indigo.opacity(0.3), Color.black]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            CustomWindowControls()
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .zIndex(2)

            ScrollView(.vertical, showsIndicators: true) {
                Group {
                    switch currentStep {
                    case .welcome:
                        WelcomeStepView(onGetStarted: { currentStep = .permissions })
                    case .permissions:
                        PermissionsStepView(onContinue: { currentStep = .helperInstallation })
                    case .helperInstallation:
                        HelperInstallationStepView(onContinue: { currentStep = .privacyPolicy })
                    case .privacyPolicy:
                        PrivacyStepView(onContinue: { currentStep = .musicChoice })
                    case .musicChoice:
                        MusicChoiceStepView(onNext: {
                            if settings.settings.defaultMusicPlayer == .spotify {
                                currentStep = .spotifySetup
                            } else {
                                currentStep = .batterySetup
                            }
                        })
                    case .spotifySetup:
                        SpotifySetupStepView(
                            onNext: { currentStep = .batterySetup },
                            isLoading: $isPrivateApiLoading,
                            error: $privateApiError
                        )
                    case .batterySetup:
                        BatterySetupStepView(onNext: { currentStep = .corePreferences })
                    case .corePreferences:
                        CorePreferencesStepView(onNext: { currentStep = .lockScreenSetup })
                    case .lockScreenSetup:
                        LockScreenSetupStepView(onNext: { currentStep = .finish })
                    case .subscriptionOverview:
                        FinishStepView(onComplete: onComplete)
                    case .finish:
                        FinishStepView(onComplete: onComplete)
                    }
                }
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.4), value: currentStep)
                .frame(maxWidth: .infinity, minHeight: UtilityWindowMetrics.maxUserWindowHeight() - 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(.dark)
    }
}

private struct WelcomeStepView: View {
    var onGetStarted: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Text("欢迎使用星岛")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)

            Text("焕新体验 Mac 灵动岛的全新方式。\n让我们开始完成初始设置。")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Spacer()

            OnboardingButton(title: "开始使用", action: onGetStarted)
        }
    }
}

private struct PermissionsStepView: View {
    @StateObject private var permissionsManager = PermissionsManager.shared
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("系统权限")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .padding(.top, 40).padding(.bottom, 10)

            Text("星岛 需要获取以下几项权限以运行核心功能。")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 50)
                .padding(.bottom, 30)

            ScrollView {
                VStack(spacing: 25) {
                    PermissionSectionView(title: "必需权限", permissions: permissionsManager.requiredPermissions, manager: permissionsManager)
                    PermissionSectionView(title: "推荐权限", permissions: permissionsManager.recommendedPermissions, description: "这些权限用于启用小组件与实时活动等主要功能。", manager: permissionsManager)
                    PermissionSectionView(title: "可选权限", permissions: permissionsManager.optionalPermissions, description: "这些权限用于启用次要或外观增强功能。", manager: permissionsManager)
                }.padding(.horizontal, 50)
            }

            Spacer()

            OnboardingButton(title: "继续", action: onContinue)
                .disabled(!permissionsManager.areAllRequiredPermissionsGranted)
                .animation(.easeInOut, value: permissionsManager.areAllRequiredPermissionsGranted)
        }
        .onAppear { permissionsManager.checkAllPermissions() }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.5))
                guard !Task.isCancelled else { return }
                permissionsManager.refreshLightweightStatuses()
            }
        }
    }
}

private struct HelperInstallationStepView: View {
    @StateObject private var helperManager = HelperManager.shared
    var onContinue: () -> Void

    @State private var didStartInstall = false

    private var helperReady: Bool {
        helperManager.isRunning
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("安装辅助服务")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .padding(.top, 40).padding(.bottom, 10)

            Text("星岛 需要特权辅助工具来实现电池管理与系统集成。macOS 会提示你在“登录项 → 允许在后台”中授予许可。")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 50)
                .padding(.bottom, 8)

            Text(stepGuidance)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 50)
                .padding(.bottom, 24)

            HelperStatusBanner(helperManager: helperManager)
                .padding()
                .roundedCard(fill: Color.black.opacity(0.15), cornerRadius: 20, stroke: Color.white.opacity(0.1))
                .padding(.horizontal, 50)

            if !helperReady && !helperManager.isReconcilingHelper {
                Button {
                    if helperManager.status == .requiresApproval {
                        SMAppService.openSystemSettingsLoginItems()
                    }
                    if helperManager.status == .enabled && !helperManager.isRunning {
                        helperManager.resetOwnBackgroundActivity()
                    } else if helperManager.status == .notFound {
                        helperManager.resetOwnBackgroundActivity()
                    } else {
                        helperManager.beginInstallation()
                    }
                } label: {
                    Text(helperManager.isResettingHelper ? "正在重置…" : primaryActionTitle)
                        .font(.headline)
                        .frame(maxWidth: 280)
                        .padding(.vertical, 12)
                }
                .disabled(helperManager.isResettingHelper)
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
                .padding(.top, 20)
            }

            Spacer()

            OnboardingButton(title: helperReady ? "继续" : "等待辅助工具（也可下方跳过）", action: onContinue)
                .disabled(!helperReady)
                .animation(.easeInOut, value: helperManager.status)
                .animation(.easeInOut, value: helperManager.isRunning)

            Button(action: onContinue) {
                Text("暂时跳过，直接继续（台式 Mac 无需电池限制）")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white.opacity(0.88))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
        }
        .onAppear {
            if !didStartInstall {
                didStartInstall = true
                if !helperManager.isRunning {
                    helperManager.beginInstallation()
                }
            }
        }
        .onChange(of: helperManager.status) { _, newStatus in
            if newStatus == .requiresApproval {
                SMAppService.openSystemSettingsLoginItems()
            }
        }
    }

    private var primaryActionTitle: String {
        switch helperManager.status {
        case .requiresApproval:
            return "打开登录项"
        case .enabled, .notFound:
            return "重置辅助工具"
        default:
            return "安装辅助工具"
        }
    }

    private var stepGuidance: String {
        if helperManager.isReconcilingHelper && !helperManager.isRunning {
            return "正在连接并验证特权辅助工具，请稍候…"
        }
        switch helperManager.status {
        case .requiresApproval:
            return "系统设置已打开。请在“允许在后台”下同时开启 星岛 与 StarIsland Helper，然后返回此处。"
        case .enabled where !helperManager.isRunning:
            return "辅助工具已获批但未响应。请点击“重置辅助工具”，以便 星岛 重新注册后台项目并重装辅助工具。"
        case .enabled:
            return "辅助工具已就绪，可以继续。"
        case .notFound:
            return "macOS 丢失了辅助工具注册信息（SAP-H3）。请点击“重置辅助工具”重建注册；若辅助工具仍卡住，星岛 将自动重新启动。"
        default:
            return "点击“安装辅助工具”，批准 macOS 弹窗提示，并在“系统设置 → 通用 → 登录项 → 允许在后台”中启用 星岛。"
        }
    }

}

private struct PrivacyStepView: View {
    @ObservedSettings var settings: SettingsObserver
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 15) {
            Spacer(minLength: 20)

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.indigo)

            Text("我们重视你的隐私")
                .font(.system(size: 32, weight: .bold, design: .rounded))

            Text("我们坚持透明原则。请在下方了解我们的数据处理方式。")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 50)
                .padding(.bottom, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PrivacySection(
                        title: "我们收集的数据（统计分析）",
                        content: "为了改进 星岛，我们会收集完全匿名且汇总的使用统计数据。这有助于我们了解常用功能、排查问题，并为所有用户持续打磨体验。"
                    )

                    PrivacySection(
                        title: "包含内容：",
                        content: "• 功能使用频率（例如小组件的使用频次）\n• 应用版本与 macOS 系统版本\n• 匿名崩溃报告"
                    )

                    PrivacySection(
                        title: "我们绝不收集的数据",
                        content: "我们严格保护你的隐私，绝不会自动收集、存储或传输任何个人或敏感信息，包括但不限于：\n• 你的姓名、邮箱或其他个人身份标识\n• 屏幕画面内容或键盘输入内容\n• 来自其他应用的数据"
                    )

                    PrivacySection(
                        title: "数据存储与第三方服务",
                        content: "匿名数据由 Google 处理用于统计分析。此类数据始终以汇总形式存储，无法用于识别你的个人身份。"
                    )
                }
                .padding(20)
                .padding(.vertical, 20)
                .background(.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(Color.white.opacity(0.1)))
            }
            .frame(maxHeight: .infinity)
            .padding(.horizontal, 60)
            .padding(.top, 20)

            Toggle(isOn: $settings.settings.googleAnalyticsEnabled) {
                Text("与 Google Analytics 共享匿名使用数据以帮助改进 星岛。你可以随时在“设置 > 通用”中更改此选项。")
                    .font(.callout)
            }
            .padding(.horizontal, 50)
            .padding(.top, 10)

            Spacer(minLength: 20)

            OnboardingButton(title: "继续", action: onContinue)
        }
    }

    private struct PrivacySection: View {
        let title: String, content: String
        var body: some View { VStack(alignment: .leading, spacing: 4) { Text(title).font(.headline).foregroundStyle(.primary); Text(content).font(.callout).foregroundStyle(.secondary).lineSpacing(4) } }
    }
}

private struct MusicChoiceStepView: View {
    @ObservedSettings var settings: SettingsObserver
    @State private var selection: DefaultMusicPlayer?
    var onNext: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("选择你的音乐服务")
                .font(.system(size: 32, weight: .bold, design: .rounded))

            Text("选择你的主力音乐播放器以获得最佳集成体验。")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            VStack(spacing: 15) {
                MusicServiceButton(title: "Apple Music", icon: "apple_logo", isSelected: selection == .appleMusic) {
                    selection = .appleMusic
                }
                MusicServiceButton(title: "Spotify", icon: "spotify_logo", isSelected: selection == .spotify) {
                    selection = .spotify
                }
                MusicServiceButton(title: "TIDAL", icon: "sf:waveform", isSelected: selection == .tidal) {
                    selection = .tidal
                }
                MusicServiceButton(title: "YouTube Music", icon: "sf:play.rectangle.fill", isSelected: selection == .youtubeMusic) {
                    selection = .youtubeMusic
                }
            }
            .padding(50)

            Spacer()

            OnboardingButton(title: "下一步", action: {
                if let finalSelection = selection {
                    settings.settings.defaultMusicPlayer = finalSelection
                    onNext()
                }
            })
            .disabled(selection == nil)
            .animation(.easeInOut, value: selection)
        }
        .onAppear {
            selection = settings.settings.defaultMusicPlayer
        }
    }
}

private struct SpotifySetupStepView: View {
    var musicManager: MusicManager { .shared }
    private var spotifyPrivateAPI: SpotifyPrivateAPIManager { .shared }
    var onNext: () -> Void
    @Binding var isLoading: Bool
    @Binding var error: String?
    private func handlePrivateApiLogin() { error = nil; isLoading = true; musicManager.spotifyPrivateAPI.login() }
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Spotify 设置").font(.system(size: 32, weight: .bold, design: .rounded))
            Text("登录以启用增强功能，例如直接在灵动岛中收藏曲目与跳过广告。").font(.title3).multilineTextAlignment(.center).foregroundColor(.secondary).padding(.horizontal)
            VStack(alignment: .center, spacing: 15) {
                if musicManager.isPrivateAPIAuthenticated {
                    HStack(spacing: 10) { Image(systemName: "checkmark.circle.fill").font(.title).foregroundColor(.green); Text("登录成功！").font(.headline) }
                } else {
                    Text("私有 API 登录").font(.headline)
                    Text("此方式同时支持免费版与会员用户，请自行承担使用风险。").font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
                    if isLoading {
                        VStack(spacing: 8) { ProgressView(); Text("正在登录…").font(.caption).foregroundColor(.secondary) }.frame(height: 40)
                    } else {
                        Button("使用 Spotify 登录", action: handlePrivateApiLogin).buttonStyle(.borderedProminent).tint(.green).controlSize(.large).frame(height: 40)
                    }
                    if let error = error { Text(error).font(.caption).foregroundColor(.red).padding(.top, 4) }
                }
            }.padding(25).background(.black.opacity(0.15)).clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1)).padding(50)
            Spacer()
            if musicManager.isPrivateAPIAuthenticated { OnboardingButton(title: "继续", action: onNext) } else if !isLoading { Button("暂时跳过", action: onNext).buttonStyle(.plain).foregroundColor(.secondary).padding(.bottom, 50) } else { OnboardingButton(title: "继续", action: {}).hidden().padding(.bottom, 50) }
        }
        .sheet(item: Bindable(spotifyPrivateAPI).loginChallenge) { _ in
            SpotifyLoginWebView(
                onComplete: { cookieProperties in
                    spotifyPrivateAPI.completeLoginAfterWebViewSuccess(with: cookieProperties)
                    spotifyPrivateAPI.loginChallenge = nil
                    isLoading = false
                },
                onCancel: {
                    error = "已取消登录。"
                    spotifyPrivateAPI.loginChallenge = nil
                    isLoading = false
                }
            )
        }
    }
}

private struct BatterySetupStepView: View {
    @ObservedSettings var settings: SettingsObserver
    var onNext: () -> Void

    private var chargeLimitBinding: Binding<Int> {
        Binding<Int>(
            get: { settings.settings.batteryChargeLimit },
            set: { settings.settings.batteryChargeLimit = $0 }
        )
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("智能电池管理")
                .fontWeight(.bold)
                .font(.system(size: 32, weight: .bold, design: .rounded))

            Text("通过以下功能保护电池健康并延长使用寿命。")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 50)

            VStack(spacing: 15) {
                ModernOnboardingRow(iconName: "battery.100.bolt", iconColor: .green, title: "设置充电上限", description: "在较低电量停止充电以减缓电池损耗，推荐设为 80%。") {
                    Picker("", selection: chargeLimitBinding) {
                        Text("80%").tag(80)
                        Text("90%").tag(90)
                        Text("100%").tag(100)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 150)
                }

                ModernOnboardingRow(iconName: "sailboat.fill", iconColor: .blue, title: "启用巡航模式", description: "达到充电上限后减少反复微充循环。") {
                    SettingsSwitch(isOn: $settings.settings.sailingModeEnabled)
                }

                ModernOnboardingRow(iconName: "thermometer.medium", iconColor: .red, title: "启用高温保护", description: "当电池温度过高时暂停充电。") {
                    SettingsSwitch(isOn: $settings.settings.heatProtectionEnabled)
                }
            }
            .padding(50)

            Spacer()
            OnboardingButton(title: "继续", action: onNext)
        }
    }
}

private struct CorePreferencesStepView: View {
    @ObservedSettings var settings: SettingsObserver
    var onNext: () -> Void
    private var showHudsBinding: Binding<Bool> { Binding(get: { settings.settings.enableVolumeHUD && settings.settings.enableBrightnessHUD }, set: { settings.settings.enableVolumeHUD = $0; settings.settings.enableBrightnessHUD = $0 }) }
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("快速设置").font(.system(size: 32, weight: .bold, design: .rounded))
            Text("打造你的专属体验，这些选项随时可在“设置”中修改。").font(.title3).multilineTextAlignment(.center).foregroundColor(.secondary).padding(.horizontal, 50)
            VStack(spacing: 15) {
                ModernOnboardingRow(iconName: "sparkles.tv", iconColor: .cyan, title: "显示自定义 HUD", description: "替换系统默认的音量与亮度指示浮层。") { SettingsSwitch(isOn: showHudsBinding) }
                ModernOnboardingRow(iconName: "eye.fill", iconColor: .cyan, title: "启用护眼休息提醒", description: "定时提醒你移开视线放松双眼。") {
                    SettingsSwitch(isOn: $settings.settings.eyeBreakLiveActivityEnabled)
                }
                ModernOnboardingRow(iconName: "thermometer.sun.fill", iconColor: .orange, title: "温度单位", description: "天气预报默认使用的温度单位。") { Picker("", selection: $settings.settings.weatherUseCelsius) { Text("°C").tag(true); Text("°F").tag(false) }.pickerStyle(.segmented).labelsHidden().frame(width: 100) }
                ModernOnboardingRow(iconName: "bolt.horizontal.circle.fill", iconColor: .purple, title: "登录时启动", description: "开机登录 Mac 时自动启动 星岛。") { SettingsSwitch(isOn: $settings.settings.launchAtLogin) }
            }.padding(50)
            Spacer()
            OnboardingButton(title: "继续", action: onNext)
        }
    }
}

private struct LockScreenSetupStepView: View {
    @ObservedSettings var settings: SettingsObserver
    var onNext: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("锁定屏幕功能")
                .font(.system(size: 32, weight: .bold, design: .rounded))

            Text("在锁定屏幕的灵动岛区域直接展示实时活动与小组件，全面增强锁屏体验。")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 50)

            VStack(spacing: 15) {
                ModernOnboardingRow(iconName: "lock.display", iconColor: .red, title: "在锁定屏幕上启用", description: "Mac 锁屏时继续显示 星岛 灵动岛及相关功能。") {
                    SettingsSwitch(isOn: $settings.settings.lockScreenShowNotch)
                }

                VStack(spacing: 15) {
                    ModernOnboardingRow(iconName: "timer", iconColor: .cyan, title: "显示实时活动", description: "展示计时器、音乐播放等动态信息。") {
                        SettingsSwitch(isOn: $settings.settings.lockScreenLiveActivityEnabled)
                    }

                    ModernOnboardingRow(iconName: "info.circle.fill", iconColor: .blue, title: "显示信息小组件", description: "展示天气、电池电量等常驻信息。") {
                        SettingsSwitch(isOn: $settings.settings.lockScreenShowInfoWidget)
                    }
                }
                .disabled(!settings.settings.lockScreenShowNotch)
                .opacity(settings.settings.lockScreenShowNotch ? 1.0 : 0.5)
                .animation(.easeInOut, value: settings.settings.lockScreenShowNotch)
            }
            .padding(50)

            Spacer()
            OnboardingButton(title: "继续", action: onNext)
        }
    }
}

private struct SubscriptionOverviewStepView: View {
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    var onNext: () -> Void

    private var currentTier: SubscriptionTier {
        subscriptionManager.activeTier
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("你的 星岛 方案")
                .font(.system(size: 32, weight: .bold, design: .rounded))

            Text("可随时在“设置”中关联账户，跨设备同步你的订阅权益。")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 50)

            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.purple.opacity(0.35), .indigo.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    Image(systemName: subscriptionManager.isSignedIn ? "person.crop.circle.badge.checkmark" : "person.crop.circle")
                        .font(.system(size: 22))
                        .foregroundStyle(.white.opacity(0.9))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(subscriptionManager.isSignedIn ? subscriptionManager.userDisplayName : "访客模式")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Text("当前方案：\(SubscriptionFeatureCatalog.tierDisplayName(currentTier))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.18), Color.white.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .padding(.horizontal, 50)

            HStack(alignment: .top, spacing: 14) {
                ForEach(SubscriptionFeatureCatalog.marketingTierHighlights(), id: \.tier) { highlight in
                    OnboardingPlanCard(
                        tier: highlight.tier,
                        perks: highlight.features,
                        isCurrent: highlight.tier == currentTier,
                        onUpgrade: onboardingTierRank(highlight.tier) > onboardingTierRank(currentTier)
                            ? { beginCheckout(for: highlight.tier) }
                            : nil
                    )
                }
            }
            .padding(.horizontal, 50)
            .frame(height: 390)

            if currentTier == .free {
                Text("升级至基础版或更高方案，即可体验测试版更新、Gemini Live 等更多功能。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 50)

                Link("前往官网升级", destination: URL(string: "https://sapphire-app.tech/")!)
                    .font(.caption)
                    .foregroundStyle(.purple)
            }

            Spacer()

            OnboardingButton(title: "跳过", action: onNext)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            Task { await subscriptionManager.bootstrap() }
        }
    }

    private func beginCheckout(for tier: SubscriptionTier) {
        let plan = tier == .free ? "basic" : tier.rawValue
        guard var components = URLComponents(string: "https://sapphire-app.tech/checkout.html") else { return }
        components.queryItems = [
            URLQueryItem(name: "plan", value: plan),
            URLQueryItem(name: "qty", value: "1")
        ]
        guard let url = components.url else { return }
        NSWorkspace.shared.open(url)
    }

    private func onboardingTierRank(_ tier: SubscriptionTier) -> Int {
        switch tier {
        case .free: return 0
        case .basic: return 1
        case .pro: return 2
        case .ultra: return 3
        case .core: return 0
        }
    }
}

private struct OnboardingPlanCard: View {
    let tier: SubscriptionTier
    let perks: [String]
    let isCurrent: Bool
    var onUpgrade: (() -> Void)? = nil

    private var accent: Color {
        switch tier {
        case .basic: return Color(red: 0.35, green: 0.62, blue: 1.0)
        case .pro: return Color(red: 0.82, green: 0.45, blue: 0.98)
        case .ultra: return Color(red: 1.0, green: 0.58, blue: 0.22)
        default: return .gray
        }
    }

    private var tierIcon: String {
        switch tier {
        case .basic: return "sparkles"
        case .pro: return "bolt.fill"
        case .ultra: return "crown.fill"
        default: return "seal"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(accent.opacity(0.16))
                        .frame(width: 40, height: 40)
                    Image(systemName: tierIcon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(SubscriptionFeatureCatalog.tierDisplayName(tier))
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        if isCurrent {
                            Text("当前")
                                .font(.system(size: 8, weight: .black))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(accent.opacity(0.22), in: Capsule())
                                .foregroundStyle(accent)
                        }
                    }

                    Text(SubscriptionFeatureCatalog.marketingSubtitle(for: tier))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.45), accent.opacity(0.05)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 9) {
                ForEach(perks, id: \.self) { perk in
                    HStack(alignment: .top, spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(accent.opacity(0.14))
                                .frame(width: 18, height: 18)
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .black))
                                .foregroundStyle(accent)
                        }
                        .padding(.top, 1)

                        Text(perk)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.78))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Spacer(minLength: 0)

            if let onUpgrade {
                Button(action: onUpgrade) {
                    Text("获取\(SubscriptionFeatureCatalog.tierDisplayName(tier))")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            LinearGradient(
                                colors: [accent, accent.opacity(0.72)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                        .shadow(color: accent.opacity(0.35), radius: 10, y: 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    accent.opacity(isCurrent ? 0.14 : 0.06),
                                    Color.black.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            accent.opacity(isCurrent ? 0.75 : 0.28),
                            Color.white.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isCurrent ? 1.5 : 1
                )
        }
        .shadow(color: isCurrent ? accent.opacity(0.22) : Color.black.opacity(0.18), radius: isCurrent ? 16 : 8, y: 6)
    }
}

private struct FinishStepView: View {
    var onComplete: () -> Void
    @StateObject private var updateChecker = UpdateChecker.shared

    private var currentAppVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "未知"
    }

    var body: some View {
        VStack(spacing: 15) {
            Spacer()
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            Text("一切就绪！")
                .font(.system(size: 32, weight: .bold, design: .rounded))

            Text("版本 \(currentAppVersion)")
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Link(destination: URL(string: "https://sapphire-app.tech/")!) {
                    Image(systemName: "link").resizable().aspectRatio(contentMode: .fit).frame(width: 18, height: 18).foregroundColor(.white).padding(6).background(Color.blue).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }.buttonStyle(PlainButtonStyle())

                Link(destination: UpdateChecker.repositoryWebURL) {
                    Image("github_logo").resizable().renderingMode(.template).aspectRatio(contentMode: .fit).frame(width: 18, height: 18).foregroundColor(.white).padding(6).background(Color.black).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }.buttonStyle(PlainButtonStyle())

                Link(destination: URL(string: "https://discord.gg/TdRjC2kNnU")!) {
                    Image("discord_logo").resizable().aspectRatio(contentMode: .fit).frame(width: 18, height: 18).padding(6).background(Color(red: 0.35, green: 0.40, blue: 0.95)).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }.buttonStyle(PlainButtonStyle())
            }

            OnboardingUpdateStatusView(updateChecker: updateChecker)
                .padding(.top)

            Spacer()
            OnboardingButton(title: "开始探索 星岛", action: onComplete)

            Text("© 2026 星岛 StarIsland · 全功能旗舰开源版")
                .font(.caption).foregroundStyle(.tertiary).padding(.bottom, 20)
        }
        .onAppear {
            updateChecker.checkForUpdates()
        }
    }
}

private struct OnboardingUpdateStatusView: View {
    @ObservedObject var updateChecker: UpdateChecker
    var body: some View {
        Group {
            switch updateChecker.status {
            case .checking: HStack(spacing: 8) { ProgressView().controlSize(.small); Text("正在检查更新…").foregroundStyle(.secondary) }
            case .upToDate: HStack(spacing: 8) { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green); Text("当前已是最新版本！").foregroundStyle(.secondary) }
            case .available(let version, _): VStack(spacing: 8) { Text("新版本 \(version) 现已推出！").font(.headline); Link(destination: UpdateChecker.releasesWebURL) { Text("前往 GitHub 下载") }.buttonStyle(.bordered).tint(.accentColor) }
            case .error(let message): HStack(spacing: 8) { Image(systemName: "xmark.octagon.fill").foregroundColor(.red); Text(message).foregroundStyle(.secondary).lineLimit(1) }
            default: EmptyView()
            }
        }.animation(.easeInOut, value: updateChecker.status).frame(minHeight: 40)
    }
}

private struct ModernOnboardingRow<Content: View>: View {
    let iconName: String, iconColor: Color, title: String, description: String
    let content: Content
    init(iconName: String, iconColor: Color, title: String, description: String, @ViewBuilder content: () -> Content) { self.iconName = iconName; self.iconColor = iconColor; self.title = title; self.description = description; self.content = content() }
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: iconName).font(.title.weight(.semibold)).foregroundColor(iconColor).frame(width: 44, height: 44).background(iconColor.opacity(0.15)).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) { Text(title).font(.headline.weight(.bold)); Text(description).font(.callout).foregroundColor(.secondary) }
            Spacer()
            content
        }.padding(16).background(.black.opacity(0.15)).clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}

private struct OnboardingButton: View {
    let title: String
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled
    var body: some View {
        Button(action: action) {
            Text(title).font(.headline.weight(.bold)).foregroundColor(isEnabled ? .black.opacity(0.8) : .gray).padding(.horizontal, 60).frame(height: 50)
                .background(LinearGradient(gradient: Gradient(colors: isEnabled ? [Color(red: 154/255, green: 249/255, blue: 165/255), Color(red: 174/255, green: 255/255, blue: 247/255)] : [.gray.opacity(0.5)]), startPoint: .leading, endPoint: .trailing))
                .clipShape(Capsule()).shadow(color: .white.opacity(isEnabled ? 0.3 : 0), radius: 10, y: 5)
        }.buttonStyle(.plain).scaleEffect(isEnabled ? 1.0 : 0.98).padding(.bottom, 50)
    }
}

private struct MusicServiceButton: View {
    let title: String, icon: String, isSelected: Bool
    let action: () -> Void
    @State private var isPressed = false
    @ViewBuilder private var iconView: some View {
        if icon.hasPrefix("sf:") {
            Image(systemName: String(icon.dropFirst(3))).resizable().renderingMode(.template).foregroundColor(.white)
        } else if icon == "music.note" {
            Image(systemName: icon).resizable().renderingMode(.template).foregroundColor(.white)
        } else {
            Image(icon).resizable().renderingMode(.original)
        }
    }
    var body: some View {
        HStack {
            iconView.aspectRatio(contentMode: .fit).frame(width: 28, height: 28)
            Text(title).font(.system(size: 18, weight: .bold, design: .rounded)); Spacer()
            Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(.white).opacity(isSelected ? 1.0 : 0.0).scaleEffect(isSelected ? 1.0 : 0.5)
        }.padding(.horizontal, 20).frame(height: 65).background(ZStack { RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.black.opacity(0.2)); RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1); if isSelected { RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.indigo, lineWidth: 3).shadow(color: .indigo.opacity(0.5), radius: 8) } })
        .scaleEffect(isPressed ? 0.97 : 1.0).contentShape(Rectangle()).onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { action() } }
        .gesture(DragGesture(minimumDistance: 0).onChanged { _ in if !isPressed { withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { isPressed = true } } }.onEnded { _ in withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { isPressed = false } }).animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

private struct PermissionSectionView: View {
    let title: String, permissions: [PermissionItem]
    var description: String? = nil
    @ObservedObject var manager: PermissionsManager
    var body: some View { if !permissions.isEmpty { VStack(alignment: .leading, spacing: 4) { Text(title).font(.title2.weight(.semibold)); if let description = description { Text(description).font(.caption).foregroundColor(.secondary).padding(.bottom, 8) }; VStack(spacing: 15) { ForEach(permissions) { permission in PermissionRowView(permission: permission, manager: manager) } } } } }
}

private struct PermissionRowView: View {
    let permission: PermissionItem
    @ObservedObject var manager: PermissionsManager
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: permission.iconName).font(.title2).frame(width: 40, height: 40).background(permission.iconColor.opacity(0.2)).clipShape(Circle()).foregroundColor(permission.iconColor)
            VStack(alignment: .leading, spacing: 2) { Text(permission.title).font(.headline); Text(permission.description).font(.subheadline).foregroundColor(.secondary) }
            Spacer()
            PermissionFeatureInfoButton(permission: permission)
                .padding(.trailing, 4)
            let status = manager.status(for: permission.type)
            let isBusy = (permission.type == .localNetwork && manager.isProbingLocalNetwork)
                || (permission.type == .automation && manager.isRequestingAutomation)
            switch status {
            case .granted:
                Image(systemName: "checkmark.circle.fill").font(.title2).foregroundColor(.green)
            case .denied:
                HStack(spacing: 10) {
                    Image(systemName: "xmark.circle.fill").font(.title2).foregroundColor(.red)
                    if permission.type == .localNetwork {
                        Button(action: { manager.retryLocalNetworkPermission() }) {
                            Text(isBusy ? "检测中…" : "重新检测")
                                .fontWeight(.semibold)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        .disabled(isBusy)
                        .background(Color.accentColor.opacity(0.35))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                    }
                    Button(action: { manager.openSystemSettings(for: permission.type) }) {
                        Text("去设置")
                            .fontWeight(.semibold)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .background(Color.white.opacity(0.14))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }
            case .notRequested:
                Button(action: { manager.requestPermission(permission.type) }) {
                    HStack(spacing: 6) {
                        if isBusy {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        }
                        Text(isBusy ? "授权中…" : "授权")
                            .fontWeight(.bold)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .disabled(isBusy)
                .background(Color.accentColor.gradient)
                .foregroundColor(.white)
                .clipShape(Capsule())
                .shadow(color: .accentColor.opacity(0.4), radius: 5, y: 2)
            }
        }.padding().background(.black.opacity(0.15)).clipShape(RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}

private struct CustomWindowControls: View {
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            Button(action: { NSApp.terminate(nil) }) {
                Image(systemName: "xmark").font(.system(size: 9, weight: .bold, design: .rounded))
            }
            .buttonStyle(TrafficLightButtonStyle(color: .red, isHovering: isHovering))

            Button(action: {}) {
                Image(systemName: "minus").font(.system(size: 9, weight: .bold, design: .rounded))
            }
            .buttonStyle(TrafficLightButtonStyle(color: .yellow, isHovering: isHovering))

            Button(action: {}) {
                Image(systemName: "plus").font(.system(size: 9, weight: .bold, design: .rounded))
            }
            .buttonStyle(TrafficLightButtonStyle(color: .green, isHovering: isHovering))
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) { isHovering = hovering }
        }
    }
}