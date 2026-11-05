import AppKit
import IslandCore
import SwiftUI

public struct OnboardingWindowView: View {
    @ObservedObject private var settingsStore: SettingsStore
    @ObservedObject private var permissionsCenter: PermissionsCenter
    @State private var currentStep: Int = 0
    private let onComplete: () -> Void

    private let recommendedPermissions: [PermissionKind] = [
        .accessibility,
        .screenRecording,
        .localNetwork,
        .automation,
        .notifications,
        .calendar,
    ]

    public init(
        settingsStore: SettingsStore? = nil,
        permissionsCenter: PermissionsCenter? = nil,
        onComplete: @escaping () -> Void
    ) {
        self._settingsStore = ObservedObject(wrappedValue: settingsStore ?? .shared)
        self._permissionsCenter = ObservedObject(wrappedValue: permissionsCenter ?? .shared)
        self.onComplete = onComplete
    }

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.08, blue: 0.16),
                    Color(red: 0.03, green: 0.04, blue: 0.09),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 22) {
                headerBar

                Group {
                    switch currentStep {
                    case 0:
                        welcomeStepView
                    case 1:
                        permissionsStepView
                    default:
                        readyStepView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                footerBar
            }
            .padding(28)
        }
        .frame(width: 680, height: 520)
        .preferredColorScheme(.dark)
        .onAppear {
            permissionsCenter.refreshAll()
        }
    }

    private var headerBar: some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.cyan)
                Text("星岛 StarIsland")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
            Spacer()
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(index <= currentStep ? Color.cyan : Color.white.opacity(0.18))
                        .frame(width: index == currentStep ? 26 : 10, height: 6)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentStep)
                }
            }
            Spacer()
            Button("跳过引导，直接体验") {
                finishOnboarding()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white.opacity(0.65))
        }
    }

    private var welcomeStepView: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 8)
            ZStack {
                Capsule()
                    .fill(.black)
                    .frame(width: 240, height: 48)
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                LinearGradient(colors: [.cyan.opacity(0.8), .purple.opacity(0.6)], startPoint: .leading, endPoint: .trailing),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: .cyan.opacity(0.32), radius: 18, y: 4)

                HStack(spacing: 16) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.cyan)
                    Text("欢迎来到星岛灵动工作台")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Image(systemName: "waveform")
                        .foregroundStyle(.purple)
                }
            }

            Text("100% 原生中文 · 零付费墙 · 全功能内置")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)

            Text("星岛将 MacBook 顶部刘海化身为丝滑的超级交互中心：集成同步歌词与 8D 音效、双因子防误报验证码识别、剪贴板净化、离线 OCR 圈选、窗口磁吸与 Dock 实时预览、SMC 电池管家、NBA/股票实况、多引擎 AI 助手及手机扫码快传。")
                .font(.system(size: 13.5))
                .foregroundStyle(.white.opacity(0.76))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 24)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                featureHighlight(icon: "music.quarternote.3", title: "同步歌词 & 8D 音效", subtitle: "频谱律动与自定义音量 HUD")
                featureHighlight(icon: "key.viewfinder", title: "精准验证码 & OCR", subtitle: "零群聊误报、永久去重与圈选识图")
                featureHighlight(icon: "macwindow.on.rectangle", title: "磁吸分屏 & Dock 预览", subtitle: "键鼠调校、长按 ⌘Q 与指纹应用锁")
                featureHighlight(icon: "bolt.batteryblock.fill", title: "80% 电池保护 & 清理", subtitle: "SMC 温控风扇与深度残留卸载")
                featureHighlight(icon: "sportscourt.fill", title: "天气 / 体育 / 财经看板", subtitle: "免 Key 实况比分、美股加密与随身镜")
                featureHighlight(icon: "qrcode.viewfinder", title: "星岛 AI & 手机互联", subtitle: "Gemini / DeepSeek / Ollama 与扫码快传")
            }
            .padding(.top, 4)
            Spacer(minLength: 8)
        }
    }

    private var permissionsStepView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("按需授予推荐系统权限（可随时跳过或稍后开启）")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                    Text("星岛绝不强制阻断使用——未授权的功能会自动优雅降级，您也可以随时在「设置 → 系统权限」中配置。")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.68))
                }
                Spacer()
                Button("刷新状态") {
                    permissionsCenter.refreshAll()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(recommendedPermissions) { kind in
                        let state = permissionsCenter.status(for: kind)
                        HStack(spacing: 12) {
                            Image(systemName: kind.iconSymbol)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.cyan)
                                .frame(width: 30, height: 30)
                                .background(Color.cyan.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(kind.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text(kind.summary)
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(.white.opacity(0.65))
                            }

                            Spacer()

                            if state == .granted {
                                Label("已授权", systemImage: "checkmark.circle.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.green)
                            } else {
                                Button(state == .denied ? "去设置" : "授权") {
                                    if state == .denied {
                                        permissionsCenter.openSystemSettings(for: kind)
                                    } else {
                                        permissionsCenter.request(kind)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.cyan)
                                .controlSize(.small)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }

    private var readyStepView: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 52))
                .foregroundStyle(.cyan)

            Text("一切就绪，即刻探索星岛")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 10) {
                shortcutTip(keys: "鼠标移至屏幕顶部刘海", desc: "丝滑展开五大工作台标签页（正在播放 / 暂存与效率 / 全景看板 / 星岛 AI / 手机互联）")
                shortcutTip(keys: "⌥ ⌘ V", desc: "随时呼出可视化剪贴板历史选择器（回车直接粘贴）")
                shortcutTip(keys: "⇧ ⌘ 2  /  ⇧ ⌘ S", desc: "离线极速框选 OCR 提取文字  /  圈选屏幕区域 AI 识图解答")
                shortcutTip(keys: "菜单栏「星岛」图标", desc: "随时打开全中文全局搜索设置中心或检查 GitHub 版本更新")
            }
            .padding(18)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))

            Toggle("开机登录 macOS 时自动启动星岛", isOn: $settingsStore.settings.launchAtLogin)
                .toggleStyle(.switch)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .padding(.top, 4)

            Spacer()
        }
    }

    private var footerBar: some View {
        HStack {
            if currentStep > 0 {
                Button("上一步") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        currentStep -= 1
                    }
                }
                .buttonStyle(.bordered)
            }
            Spacer()
            if currentStep < 2 {
                Button("下一步") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        currentStep += 1
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
            } else {
                Button("开始使用星岛") {
                    finishOnboarding()
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
                .controlSize(.large)
            }
        }
    }

    private func featureHighlight(icon: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.cyan)
            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }

    private func shortcutTip(keys: String, desc: String) -> some View {
        HStack(spacing: 12) {
            Text(keys)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.cyan)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.cyan.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                .frame(minWidth: 145, alignment: .center)
            Text(desc)
                .font(.system(size: 12.5))
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    private func finishOnboarding() {
        settingsStore.settings.hasCompletedOnboarding = true
        onComplete()
    }
}
