import AppKit
import Foundation
import IslandCore
import SwiftUI
import UniformTypeIdentifiers

private extension View {
    func islandGlassCard(padding: CGFloat = 9, cornerRadius: CGFloat = 12, opacity: Double = 0.08) -> some View {
        self.padding(padding).background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(Color.white.opacity(opacity))
        )
    }
}

// MARK: - 灵动岛「全景看板」主标签页视图

public struct WidgetsIslandTabView: View {
    public enum Submode: String, CaseIterable, Identifiable {
        case dashboard = "全景总览", timersFocus = "计时与专注", mirror = "高清随身镜"
        public var id: String { rawValue }
    }

    @ObservedObject private var settingsStore: SettingsStore
    @ObservedObject private var weatherService: WeatherService
    @ObservedObject private var sportsService: SportsLiveService
    @ObservedObject private var financeService: FinanceLiveService
    @ObservedObject private var calendarBTService: CalendarBluetoothService
    @ObservedObject private var timersManager: TimersEyeBreakManager
    @ObservedObject private var mirrorController: PocketMirrorController
    @ObservedObject private var terminalService: TerminalActivityService
    @ObservedObject private var focusService: FocusBlockerService

    @State private var submode: Submode = .dashboard

    @MainActor
    public init(
        settingsStore: SettingsStore? = nil, weatherService: WeatherService? = nil,
        sportsService: SportsLiveService? = nil, financeService: FinanceLiveService? = nil,
        calendarBTService: CalendarBluetoothService? = nil, timersManager: TimersEyeBreakManager? = nil,
        mirrorController: PocketMirrorController? = nil, terminalService: TerminalActivityService? = nil,
        focusService: FocusBlockerService? = nil
    ) {
        self.settingsStore = settingsStore ?? .shared; self.weatherService = weatherService ?? .shared
        self.sportsService = sportsService ?? .shared; self.financeService = financeService ?? .shared
        self.calendarBTService = calendarBTService ?? .shared; self.timersManager = timersManager ?? .shared
        self.mirrorController = mirrorController ?? .shared; self.terminalService = terminalService ?? .shared
        self.focusService = focusService ?? .shared
    }

    public var body: some View {
        VStack(spacing: 10) {
            headerBar
            switch submode {
            case .dashboard: dashboardGrid
            case .timersFocus: timersAndFocusPane
            case .mirror: pocketMirrorPane
            }
        }
        .padding(12)
        .onAppear {
            terminalService.startListening()
            if weatherService.snapshot == nil { Task { await weatherService.refresh() } }
            if sportsService.matches.isEmpty { Task { await sportsService.refresh() } }
            if financeService.quotes.isEmpty { Task { await financeService.refresh() } }
            Task { await calendarBTService.refreshAll() }
        }
        .onChange(of: submode) { _, newValue in if newValue != .mirror { mirrorController.stopMirror() } }
    }

    private var headerBar: some View {
        HStack(spacing: 8) {
            ForEach(Submode.allCases) { item in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) { submode = item }
                } label: {
                    Text(item.rawValue)
                        .font(.system(size: 11.5, weight: submode == item ? .semibold : .regular))
                        .foregroundStyle(submode == item ? Color.white : Color.white.opacity(0.68))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(submode == item ? Color.accentColor.opacity(0.85) : Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Button {
                Task {
                    await weatherService.refresh(); await sportsService.refresh()
                    await financeService.refresh(); await calendarBTService.refreshAll()
                }
            } label: {
                Image(systemName: "arrow.clockwise").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.75))
            }
            .buttonStyle(.plain).help("立即刷新全部看板数据")
        }
    }

    private var dashboardGrid: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 8) {
                HStack(alignment: .top, spacing: 8) { weatherCard; scheduleAndBluetoothColumn }
                if settingsStore.settings.enableSportsLiveActivity { sportsStripCard }
                if settingsStore.settings.enableFinanceWidget { financeGridCard }
            }
        }
    }

    private var weatherCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let snap = weatherService.snapshot {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(snap.cityName).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.9))
                        Text(weatherService.formattedTemperature(snap.temperatureC))
                            .font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Image(systemName: snap.symbolName).symbolRenderingMode(.multicolor).font(.system(size: 22))
                        Text(snap.conditionText).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.85))
                    }
                }
                Text("体感 \(weatherService.formattedTemperature(snap.apparentTemperatureC)) · 最高 \(weatherService.formattedTemperature(snap.highTempC)) 最低 \(weatherService.formattedTemperature(snap.lowTempC))")
                    .font(.system(size: 10.5)).foregroundStyle(.white.opacity(0.68)).lineLimit(1)
                if !snap.daily.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(snap.daily.prefix(4)) { day in
                            VStack(spacing: 2) {
                                Text(String(day.date.suffix(5))).font(.system(size: 9.5)).foregroundStyle(.white.opacity(0.6))
                                Image(systemName: day.symbolName).font(.system(size: 10.5)).foregroundStyle(.cyan)
                                Text("\(Int(day.maxTempC.rounded()))°").font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.88))
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.top, 2)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Label(settingsStore.settings.weatherCityName, systemImage: "cloud.sun.fill")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                    Text(weatherService.isLoading ? "正在同步实时气象…" : (weatherService.errorMessage ?? "点击右上角刷新天气"))
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.65))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .islandGlassCard(padding: 10)
    }

    private var scheduleAndBluetoothColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Label("今日日程与待办", systemImage: "calendar")
                        .font(.system(size: 11.5, weight: .semibold)).foregroundStyle(.white.opacity(0.9))
                    Spacer()
                    if !calendarBTService.hasCalendarAccess {
                        Button("授权") { Task { await calendarBTService.requestCalendarAndRemindersAccess() } }
                            .font(.system(size: 10, weight: .medium)).buttonStyle(.borderedProminent).controlSize(.mini)
                    }
                }
                if let nextEvent = calendarBTService.todayEvents.first {
                    HStack(spacing: 6) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(nextEvent.title).font(.system(size: 11, weight: .medium)).foregroundStyle(.white).lineLimit(1)
                            Text(nextEvent.startDate, style: .time).font(.system(size: 10)).foregroundStyle(.white.opacity(0.6))
                        }
                        Spacer()
                        if nextEvent.joinURL != nil {
                            Button("一键入会") { calendarBTService.joinMeeting(nextEvent) }
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(Capsule().fill(Color.blue)).foregroundStyle(.white).buttonStyle(.plain)
                        }
                    }
                } else {
                    Text("近期暂无待开会议").font(.system(size: 10.5)).foregroundStyle(.white.opacity(0.55))
                }
                ForEach(calendarBTService.reminders.prefix(2)) { todo in
                    Button {
                        Task { await calendarBTService.toggleReminderCompletion(todo) }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 11)).foregroundStyle(.mint)
                            Text(todo.title).font(.system(size: 10.5)).foregroundStyle(.white.opacity(0.85)).lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .islandGlassCard()

            if settingsStore.settings.enableBluetoothBatteryWidget {
                HStack(spacing: 8) {
                    Image(systemName: "airpodspro").font(.system(size: 12)).foregroundStyle(.cyan)
                    if calendarBTService.bluetoothDevices.isEmpty {
                        Text("未检测到蓝牙电量外设").font(.system(size: 10.5)).foregroundStyle(.white.opacity(0.6))
                    } else {
                        ForEach(calendarBTService.bluetoothDevices.prefix(2)) { dev in
                            HStack(spacing: 4) {
                                Image(systemName: dev.symbolName).font(.system(size: 10.5))
                                Text("\(dev.primaryPercent)%").font(.system(size: 10.5, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                    Spacer()
                }
                .islandGlassCard(padding: 7, cornerRadius: 10, opacity: 0.07)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var sportsStripCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(
                    SportsLeague(rawValue: settingsStore.settings.favoriteSportsLeague)?.displayName ?? "体育实况",
                    systemImage: SportsLeague.iconSymbol(for: settingsStore.settings.favoriteSportsLeague)
                )
                .font(.system(size: 11.5, weight: .semibold)).foregroundStyle(.white.opacity(0.9))
                Spacer()
                Text(sportsService.matches.contains(where: \.isLive) ? "LIVE 实况上岛中" : "最新赛果")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(sportsService.matches.contains(where: \.isLive) ? .green : .white.opacity(0.55))
            }
            if sportsService.matches.isEmpty {
                Text(sportsService.isLoading ? "正在拉取实时记分牌…" : "当前联赛今日暂无排期")
                    .font(.system(size: 10.5)).foregroundStyle(.white.opacity(0.58))
            } else {
                HStack(spacing: 8) {
                    ForEach(sportsService.matches.prefix(2)) { match in
                        HStack {
                            Text("\(match.awayTeamAbbr) \(match.awayScore) - \(match.homeScore) \(match.homeTeamAbbr)")
                                .font(.system(size: 11.5, weight: .bold, design: .rounded)).foregroundStyle(.white)
                            Spacer()
                            Text(match.periodText)
                                .font(.system(size: 10))
                                .foregroundStyle(match.isLive ? .orange : .white.opacity(0.6))
                                .lineLimit(1)
                        }
                        .islandGlassCard(padding: 6, cornerRadius: 8, opacity: 0.06)
                    }
                }
            }
        }
        .islandGlassCard()
    }

    private var financeGridCard: some View {
        let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(financeService.quotes.prefix(4)) { quote in
                HStack(spacing: 6) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(quote.symbol).font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                        Text(quote.formattedPrice).font(.system(size: 10.5, design: .monospaced)).foregroundStyle(.white.opacity(0.8))
                    }
                    MarketSparklineView(points: quote.sparkline, isPositive: quote.isPositive).frame(height: 22)
                    Text(quote.formattedChangePercent)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 5).fill((quote.isPositive ? Color.green : Color.red).opacity(0.22)))
                        .foregroundStyle(quote.isPositive ? .green : .red)
                }
                .islandGlassCard(padding: 8, cornerRadius: 10, opacity: 0.07)
            }
        }
    }

    private var timersAndFocusPane: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Button("番茄钟 25m") { timersManager.startPomodoro(minutes: 25) }
                Button("小憩 5m") { timersManager.startCountdown(title: "轻度休息", seconds: 300) }
                Button(timersManager.isStopwatchRunning ? "暂停秒表 \(timersManager.formattedStopwatch)" : "启动秒表") {
                    timersManager.toggleStopwatch()
                }
                if timersManager.stopwatchSeconds > 0 { Button("清零") { timersManager.resetStopwatch() } }
                Button("20-20-20 护眼") { timersManager.triggerEyeBreakNow() }
            }
            .buttonStyle(.bordered).controlSize(.small)

            ForEach(timersManager.timers.prefix(2)) { timer in
                HStack {
                    Label(timer.title, systemImage: "timer").font(.system(size: 11.5, weight: .medium)).foregroundStyle(.white)
                    Spacer()
                    Text(timer.formattedRemaining).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(.cyan)
                    Button(timer.isRunning ? "暂停" : "继续") { timersManager.toggleTimer(id: timer.id) }.controlSize(.mini)
                    Button("取消") { timersManager.removeTimer(id: timer.id) }.controlSize(.mini)
                }
                .islandGlassCard(padding: 7, cornerRadius: 9)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(focusService.isFocusing ? "深度专注进行中 · \(focusService.formattedRemaining)" : "专注防分心护航")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                    Text(focusService.isFocusing ? "已自动拦截分心应用 \(focusService.interceptedCount) 次" : "一键静音干扰、隐藏黑名单娱乐应用并屏蔽分心网站")
                        .font(.system(size: 10.5)).foregroundStyle(.white.opacity(0.65))
                }
                Spacer()
                Button(focusService.isFocusing ? "结束专注" : "开启 25 分钟专注") {
                    Task {
                        if focusService.isFocusing { await focusService.stopFocus() }
                        else { await focusService.startFocus(minutes: 25) }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(focusService.isFocusing ? .orange : .indigo)
                .controlSize(.small)
            }
            .islandGlassCard(padding: 9, cornerRadius: 11)

            if !terminalService.runningCommands.isEmpty {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("终端执行中：\(terminalService.runningCommands[0].command)")
                        .font(.system(size: 10.5, design: .monospaced)).foregroundStyle(.green).lineLimit(1)
                }
            }
        }
    }

    private var pocketMirrorPane: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.black.opacity(0.65))
                if mirrorController.isActive {
                    CameraMirrorPreviewRepresentable(
                        session: mirrorController.captureSession,
                        isMirrored: mirrorController.isMirrored
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(mirrorController.isRingLightEnabled ? 8 : 0)
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "web.camera.fill").font(.system(size: 24)).foregroundStyle(.white.opacity(0.75))
                        Text(mirrorController.errorMessage ?? "随时整理仪容，离开面板自动关闭摄像头")
                            .font(.system(size: 11)).foregroundStyle(.white.opacity(0.68))
                    }
                }
            }
            .frame(height: 150)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        mirrorController.isRingLightEnabled
                            ? (mirrorController.useWarmLight ? Color(red: 1.0, green: 0.92, blue: 0.78) : Color.white)
                            : Color.white.opacity(0.14),
                        lineWidth: mirrorController.isRingLightEnabled ? 8 : 1
                    )
            )

            HStack(spacing: 8) {
                Button(mirrorController.isActive ? "关闭镜头" : "开启随身镜") {
                    if mirrorController.isActive { mirrorController.stopMirror() }
                    else { Task { await mirrorController.startMirror() } }
                }
                .buttonStyle(.borderedProminent)
                Toggle("镜像翻转", isOn: $mirrorController.isMirrored)
                Toggle("环形补光", isOn: $mirrorController.isRingLightEnabled)
                if mirrorController.isRingLightEnabled { Toggle("暖柔光", isOn: $mirrorController.useWarmLight) }
            }
            .font(.system(size: 11)).controlSize(.small)
        }
        .onAppear { Task { await mirrorController.startMirror() } }
        .onDisappear { mirrorController.stopMirror() }
    }
}

// MARK: - 「小组件与实时活动」全中文设置面板

public struct LiveWidgetsSettingsPaneView: View {
    @ObservedObject private var settingsStore: SettingsStore
    @ObservedObject private var weatherService: WeatherService
    @ObservedObject private var sportsService: SportsLiveService
    @ObservedObject private var financeService: FinanceLiveService
    @ObservedObject private var calendarBTService: CalendarBluetoothService
    @ObservedObject private var focusService: FocusBlockerService

    @State private var cityQuery = ""
    @State private var newSymbolInput = ""
    @State private var newDomainInput = ""
    @State private var newBundleIDInput = ""
    @State private var hookCopied = false

    @MainActor
    public init(
        settingsStore: SettingsStore? = nil, weatherService: WeatherService? = nil,
        sportsService: SportsLiveService? = nil, financeService: FinanceLiveService? = nil,
        calendarBTService: CalendarBluetoothService? = nil, focusService: FocusBlockerService? = nil
    ) {
        self.settingsStore = settingsStore ?? .shared; self.weatherService = weatherService ?? .shared
        self.sportsService = sportsService ?? .shared; self.financeService = financeService ?? .shared
        self.calendarBTService = calendarBTService ?? .shared; self.focusService = focusService ?? .shared
    }

    public var body: some View {
        Form {
            Section("实时天气与城市定位（Open-Meteo 免密钥源）") {
                Toggle("启用灵动岛实时天气组件", isOn: $settingsStore.settings.enableWeatherWidget)
                Toggle("使用摄氏度 (°C) 显示温度", isOn: $settingsStore.settings.weatherUseCelsius)
                HStack {
                    Text("当前城市：\(settingsStore.settings.weatherCityName)").fontWeight(.medium)
                    Spacer()
                    Button("使用当前定位") { weatherService.requestCurrentLocation() }
                    Button("立即刷新") { Task { await weatherService.refresh() } }
                }
                HStack {
                    TextField("输入城市中文或拼音搜索（如：深圳、杭州、Tokyo）", text: $cityQuery)
                        .onSubmit { Task { await weatherService.searchCities(query: cityQuery) } }
                    Button("搜索城市") { Task { await weatherService.searchCities(query: cityQuery) } }
                }
                ForEach(weatherService.searchResults) { city in
                    HStack {
                        Text(city.displayTitle)
                        Spacer()
                        Button("设为当前城市") {
                            cityQuery = ""
                            Task { await weatherService.selectCity(city) }
                        }
                    }
                }
            }

            Section("体育赛事实时比分（ESPN 实况胶囊）") {
                Toggle("比赛进行中自动常驻灵动岛实况胶囊", isOn: $settingsStore.settings.enableSportsLiveActivity)
                Picker("关注联赛", selection: $settingsStore.settings.favoriteSportsLeague) {
                    ForEach(SportsLeague.allCases) { league in
                        Text(league.displayName).tag(league.rawValue)
                    }
                }
                .onChange(of: settingsStore.settings.favoriteSportsLeague) { _, updated in
                    Task { await sportsService.selectLeague(updated) }
                }
                Button("刷新当前联赛记分牌") { Task { await sportsService.refresh() } }
            }

            Section("股票与加密货币自选看板（Yahoo Finance & Binance）") {
                Toggle("启用自选行情与异动火花线", isOn: $settingsStore.settings.enableFinanceWidget)
                HStack {
                    TextField("输入代码（如 AAPL、NVDA、0700.HK、BTCUSDT）", text: $newSymbolInput)
                        .onSubmit { submitNewSymbol() }
                    Button("添加自选") { submitNewSymbol() }
                }
                ForEach(settingsStore.settings.watchlistSymbols, id: \.self) { sym in
                    HStack {
                        Text(sym).font(.system(.body, design: .monospaced))
                        Spacer()
                        Button("移除", role: .destructive) { financeService.removeSymbol(sym) }
                    }
                }
            }

            Section("日历会议、待办提醒与蓝牙外设电量") {
                Toggle("显示今日日程与 Zoom / 腾讯会议 / 飞书一键入会", isOn: $settingsStore.settings.enableCalendarWidget)
                Toggle("显示未完成提醒事项并支持直接勾选", isOn: $settingsStore.settings.enableRemindersWidget)
                Toggle("显示已连接蓝牙耳机与键盘鼠标电量", isOn: $settingsStore.settings.enableBluetoothBatteryWidget)
                Button("请求日历与提醒事项系统访问授权") {
                    Task { await calendarBTService.requestCalendarAndRemindersAccess() }
                }
            }

            Section("20-20-20 护眼提醒与终端耗时命令上岛") {
                Toggle("启用 20-20-20 定时护眼远眺提醒", isOn: $settingsStore.settings.enableEyeBreakReminder)
                Stepper(
                    "护眼提醒间隔：每 \(settingsStore.settings.eyeBreakIntervalMinutes) 分钟",
                    value: $settingsStore.settings.eyeBreakIntervalMinutes,
                    in: 10...60,
                    step: 5
                )
                Toggle("接收耗时超过 5 秒的终端命令运行与完成通知", isOn: $settingsStore.settings.enableTerminalLiveActivity)
                VStack(alignment: .leading, spacing: 6) {
                    Text("将以下 Hook 添加到 ~/.zshrc 即可启用终端任务实时上岛：")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(TerminalShellHook.zshSnippet)
                        .font(.system(size: 10.5, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.12)))
                    Button(hookCopied ? "已复制到剪贴板" : "一键复制 Zsh Hook 脚本") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(TerminalShellHook.zshSnippet, forType: .string)
                        hookCopied = true
                    }
                }
            }

            Section("专注模式防分心名单（娱乐应用拦截与受管 Hosts 网站屏蔽）") {
                HStack {
                    TextField("添加屏蔽域名（如 weibo.com、bilibili.com）", text: $newDomainInput)
                        .onSubmit { focusService.addBlockedDomain(newDomainInput); newDomainInput = "" }
                    Button("添加域名") { focusService.addBlockedDomain(newDomainInput); newDomainInput = "" }
                }
                HStack(spacing: 6) {
                    ForEach(FocusBlockerService.presetDomains.prefix(5)) { preset in
                        Button("+ \(preset.title)") { focusService.addBlockedDomain(preset.value) }.controlSize(.small)
                    }
                }
                ForEach(settingsStore.settings.focusBlockedDomains, id: \.self) { domain in
                    HStack {
                        Text(domain)
                        Spacer()
                        Button("移除", role: .destructive) { focusService.removeBlockedDomain(domain) }
                    }
                }

                Divider()
                HStack {
                    TextField("添加娱乐应用 Bundle ID（如 com.valvesoftware.steam）", text: $newBundleIDInput)
                    Button("添加应用") { focusService.addBlockedAppBundleID(newBundleIDInput); newBundleIDInput = "" }
                    Button("从应用程序选择…") { pickApplicationForFocusBlock() }
                }
                ForEach(settingsStore.settings.focusBlockedAppBundleIDs, id: \.self) { bundleID in
                    HStack {
                        Text(bundleID).font(.system(.caption, design: .monospaced))
                        Spacer()
                        Button("移除", role: .destructive) { focusService.removeBlockedAppBundleID(bundleID) }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func submitNewSymbol() {
        let symbol = newSymbolInput; newSymbolInput = ""
        Task { await financeService.addSymbol(symbol) }
    }

    private func pickApplicationForFocusBlock() {
        let panel = NSOpenPanel()
        panel.title = "选择专注期间需要自动隐藏拦截的应用"
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let bid = Bundle(url: url)?.bundleIdentifier { focusService.addBlockedAppBundleID(bid) }
        }
    }
}
