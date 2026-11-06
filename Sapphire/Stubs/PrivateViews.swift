//
//  PrivateViews.swift
//  Sapphire
//

#if !SAPPHIRE_FULL_BUILD
import SwiftUI
import AppKit

struct SportsSettingsView: View {
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                Text("体育").font(.largeTitle.bold()).padding(.bottom)
            }
            .padding(25)
        }
    }
}

struct FinanceSettingsView: View {
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                Text("财经").font(.largeTitle.bold()).padding(.bottom)
            }
            .padding(25)
        }
    }
}

struct AccountSettingsView: View {
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @ObservedObject private var updateChecker = UpdateChecker.shared

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                Text("旗舰版授权与关于")
                    .font(.largeTitle.bold())
                    .padding(.bottom, 6)

                HStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: subscriptionManager.tierGradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                        Image(systemName: "sparkles")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 58, height: 58)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(subscriptionManager.userDisplayName)
                                .font(.title2.bold())
                            Text("永久解锁")
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.green.opacity(0.22)))
                                .foregroundStyle(.green)
                        }
                        Text("版本 \(currentAppVersion) · 全部 \(AppFeature.allCases.count) 项高级特性已就绪，无需登录或订阅")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(20)
                .modifier(SettingsContainerModifier())

                SettingsCard(title: "已解锁核心能力", description: "本机已开启全部专业版与旗舰版模块，零付费墙拦截。") {
                    VStack(alignment: .leading, spacing: 12) {
                        unlockedRow(icon: "sportscourt.fill", color: .orange, title: "体育实时比分与全球财经行情", subtitle: "内置 ESPN、Yahoo Finance 与 Binance 免 Key 实时数据源")
                        Divider()
                        unlockedRow(icon: "sparkles.rectangle.stack.fill", color: .purple, title: "多通道 AI 灵动岛助手与画圈搜屏 OCR", subtitle: "支持 Gemini、DeepSeek、通义千问、OpenRouter 与本地 Ollama，附带离线中英视觉识别")
                        Divider()
                        unlockedRow(icon: "qrcode.viewfinder", color: .blue, title: "局域网扫码双向快传与 Touch ID 应用锁", subtitle: "手机浏览器扫码即连，6 位动态配对码加密鉴权；敏感应用窗口实时加锁保护")
                        Divider()
                        unlockedRow(icon: "slider.horizontal.below.square.and.square.filled", color: .teal, title: "全套系统、键鼠、音频与空间增强", subtitle: "8D 环绕音效、剪贴板防追踪净化、窗口边缘磁吸、鼠标防抖与磁盘可视化分析")
                    }
                    .padding(20)
                }

                SettingsCard(title: "开源仓库与软件更新", description: "星岛通过 GitHub Releases 自动校验 SHA-256 并执行安全热更新。") {
                    HStack(spacing: 12) {
                        Button {
                            updateChecker.checkForUpdatesMatchingCurrentChannel()
                        } label: {
                            Label("检查 GitHub 更新", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(.borderedProminent)

                        Link(destination: UpdateChecker.repositoryWebURL) {
                            Label("访问 GitHub 仓库 (adgry/StarIsland)", systemImage: "arrow.up.right.square")
                        }
                        .buttonStyle(.bordered)

                        Spacer()
                    }
                    .padding(20)
                }
            }
            .padding(25)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func unlockedRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            SettingsIconBadge(systemImage: icon, color: color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
        }
    }
}

struct BetaBlockerView: View {
    var onValidationComplete: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.largeTitle)
                .foregroundStyle(.green)
            Text("星岛测试通道权限已自动激活")
                .font(.headline)
            Button("继续", action: onValidationComplete)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: onValidationComplete)
    }
}

struct NativePaymentSheetView: View {
    var tier: SubscriptionTier
    var deviceCount: Int
    var isAddingOnly: Bool
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.largeTitle)
                .foregroundStyle(.purple)
            Text("星岛旗舰版全部功能已免费永久解锁")
                .font(.headline)
            Button("完成", action: onDismiss)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

enum SubscriptionRevocationReason: String {
    case sessionExpired

    var alertMessage: String { "本地授权状态正常。" }
}

final class ScreenPerception {
    func captureAnnotatedScreen() async -> (NSImage?, [String]) { (nil, []) }
}
#endif
