//
//  PrivateViews.swift
//  Sapphire
//

#if !SAPPHIRE_FULL_BUILD
import SwiftUI
import AppKit

struct SportsSettingsView: View {
    @EditingSettings var settings: SettingsEditingSession
    @ObservedObject private var service = SportsAPIService.shared
    @State private var newTeamInput = ""

    private let quickPresets = ["NBA", "Lakers", "Warriors", "英超", "Arsenal", "欧冠", "Real Madrid", "NFL", "F1"]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                Text("体育").font(.largeTitle.bold()).padding(.bottom, 6)

                SettingsCard(title: "灵动岛小组件与实时活动", description: "通过 ESPN 公共免 Key 接口自动同步全球联赛实时比分。") {
                    ToggleRow(title: "启用体育小组件", description: "在展开的灵动岛主栏中显示关注球队或联赛比分卡片。", isOn: $settings.settings.sportsWidgetEnabled)
                    Divider().padding(.leading, 20)
                    ToggleRow(title: "启用体育实时活动", description: "在刘海左右翼实时展示关注球队的当前比分。", isOn: $settings.settings.sportsLiveActivityEnabled)
                    Divider().padding(.leading, 20)
                    ToggleRow(title: "仅在比赛直播中显示", description: "未开赛或已终场时自动隐藏体育实时活动。", isOn: $settings.settings.sportsLiveActivityWhenLiveOnly)
                    Divider().padding(.leading, 20)
                    ToggleRow(title: "实时战报滚动字幕", description: "比赛进行中在灵动岛下方展示最新得分播报。", isOn: $settings.settings.sportsCommentaryInLiveActivity)
                    Divider().padding(.leading, 20)
                    ToggleRow(title: "优先显示球队队徽", description: "在实时活动左侧展示高清球队标志。", isOn: $settings.settings.sportsPreferLogo)
                }

                SettingsCard(title: "关注的球队与联赛", description: "输入英文队名或联赛简称（如 Lakers、Arsenal、NBA、英超、F1）。") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            TextField("输入球队或联赛名称…", text: $newTeamInput)
                                .textFieldStyle(.roundedBorder)
                            Button("添加") {
                                addTeam(newTeamInput)
                                newTeamInput = ""
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(newTeamInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            Button("立即刷新") {
                                Task { await service.prefetchLiveScoreboards(for: settings.settings.sportsFavoriteTeams) }
                            }
                            .buttonStyle(.bordered)
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(quickPresets, id: \.self) { preset in
                                    Button("+ \(preset)") { addTeam(preset) }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                }
                            }
                        }

                        ForEach(settings.settings.sportsFavoriteTeams, id: \.self) { team in
                            HStack {
                                Image(systemName: "sportscourt.fill").foregroundStyle(.orange)
                                Text(team).font(.system(size: 13, weight: .medium))
                                Spacer()
                                if let ev = service.cachedLiveEvent(for: team) {
                                    Text("\(ev.awayTeam) \(ev.awayScore):\(ev.homeScore) \(ev.homeTeam)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Button(role: .destructive) {
                                    settings.settings.sportsFavoriteTeams.removeAll { $0 == team }
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(20)
                }
            }
            .padding(25)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func addTeam(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !settings.settings.sportsFavoriteTeams.contains(trimmed) else { return }
        settings.settings.sportsFavoriteTeams.append(trimmed)
        Task { _ = await service.fetchLiveEvent(for: trimmed, forceRefresh: true) }
    }
}

struct FinanceSettingsView: View {
    @EditingSettings var settings: SettingsEditingSession
    @ObservedObject private var service = FinanceAPIService.shared
    @State private var newSymbolInput = ""

    private let quickSymbols = ["AAPL", "NVDA", "MSFT", "TSLA", "GOOGL", "BTCUSDT", "ETHUSDT", "SOLUSDT"]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                Text("财经").font(.largeTitle.bold()).padding(.bottom, 6)

                SettingsCard(title: "灵动岛行情组件与实时活动", description: "内置 Yahoo Finance 与 Binance 免 Key 双引擎，支持美股/指数与加密货币实时折线。") {
                    ToggleRow(title: "启用财经小组件", description: "在灵动岛展示自选标的实时报价与分时走势线。", isOn: $settings.settings.financeWidgetEnabled)
                    Divider().padding(.leading, 20)
                    ToggleRow(title: "启用财经实时活动", description: "在刘海左右翼常驻显示当前首选证券或代币涨跌。", isOn: $settings.settings.financeLiveActivityEnabled)
                    Divider().padding(.leading, 20)
                    ToggleRow(title: "仅在交易时段显示", description: "盘后或休市期间自动隐藏股票实时活动。", isOn: $settings.settings.financeLiveActivityActiveHoursOnly)
                }

                SettingsCard(title: "自选标的列表", description: "股票输入代码（如 AAPL、NVDA、0700.HK），加密货币输入交易对（如 BTCUSDT）。") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            TextField("例如 AAPL 或 BTCUSDT…", text: $newSymbolInput)
                                .textFieldStyle(.roundedBorder)
                            Button("添加") {
                                addSymbol(newSymbolInput)
                                newSymbolInput = ""
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(newSymbolInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            Button("刷新行情") {
                                Task { await service.refreshWatchlist(settings.settings.financeFavoriteSymbols) }
                            }
                            .buttonStyle(.bordered)
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(quickSymbols, id: \.self) { sym in
                                    Button("+ \(sym)") { addSymbol(sym) }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                }
                            }
                        }

                        ForEach(Array(settings.settings.financeFavoriteSymbols.enumerated()), id: \.element) { idx, sym in
                            let quote = service.quotesBySymbol[sym.uppercased()] ?? service.cachedQuote(symbol: sym)
                            let payload = service.makePayload(symbol: sym, index: idx, quote: quote)
                            HStack {
                                Image(systemName: idx == settings.settings.financeFavoriteSymbolIndex ? "star.fill" : "star")
                                    .foregroundStyle(idx == settings.settings.financeFavoriteSymbolIndex ? .yellow : .secondary)
                                    .onTapGesture { settings.settings.financeFavoriteSymbolIndex = idx }
                                Text(sym).font(.system(size: 13, weight: .bold, design: .rounded))
                                Text(payload.name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                Spacer()
                                Text(payload.price).font(.system(size: 13, weight: .semibold, design: .rounded))
                                Text(payload.changePercent)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(payload.isPositive ? .green : .red)
                                Button(role: .destructive) {
                                    settings.settings.financeFavoriteSymbols.removeAll { $0 == sym }
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(20)
                }
            }
            .padding(25)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .task {
            await service.refreshWatchlist(settings.settings.financeFavoriteSymbols)
        }
    }

    private func addSymbol(_ raw: String) {
        let upper = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !upper.isEmpty, !settings.settings.financeFavoriteSymbols.contains(upper) else { return }
        settings.settings.financeFavoriteSymbols.append(upper)
        Task { _ = await service.fetchQuote(symbol: upper, forceRefresh: true) }
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
