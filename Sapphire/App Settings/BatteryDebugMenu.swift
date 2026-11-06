//
//  BatteryDebugMenu.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2026-08-20.
//

import SwiftUI
import ServiceManagement

@MainActor
struct BatteryDebugMenu: View {
    @ObservedObject private var helperManager = HelperManager.shared
    @ObservedObject private var debugMode = DebugMode.shared
    @ObservedObject private var batteryStatus = BatteryStatusManager.shared
    @ObservedObject private var powerModeManager = PowerModeManager.shared
    @ObservedObject private var fanManager = FanManager.shared

    @State private var log: [String] = []
    @State private var protocolVersion: Int?
    @State private var chargeControlMode: ChargeControlMode?
    @State private var nativeLimitSummary: String?
    @State private var batteryTemp: Double?
    @State private var hardwarePercent: Int?
    @State private var adapter: PowerAdapterInfo?
    @State private var smcKeys: [String] = []
    @State private var fanCount: Int?
    @State private var limitInput = 80
    @State private var isBusy = false

    private static let integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.allowsFloats = false
        return formatter
    }()

    private static let logTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private var battery: BatteryState? { BatteryMonitor.shared.currentState }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            helperCard
            batteryStateCard
            chargingTestCard
            onDemandDataCard
            logCard
        }
        .padding(.bottom, 8)
        .task { await refreshEverything() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "hammer.fill")
                .foregroundStyle(.orange)
            Text("调试菜单")
                .font(.title3.bold())
            Spacer()
            Button("全部刷新") {
                Task { await refreshEverything() }
            }
            .buttonStyle(.bordered)
            Button(debugMode.isEnabled ? "关闭调试模式" : "开启调试模式") {
                debugMode.isEnabled.toggle()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding(.top, 8)
    }

    // MARK: - Helper

    private var helperCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("辅助程序", systemImage: "gearshape.2.fill", color: .blue)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                gridRow("SMAppService 状态", helperManager.status.description)
                gridRow("运行中", helperManager.isRunning ? "是" : "否")
                gridRow("问题", helperManager.lastIssue?.code ?? "无")
                gridRow("协议版本", protocolVersion.map(String.init) ?? "—")
                gridRow("充电控制模式", chargeControlMode.map { String(describing: $0) } ?? "—")
                gridRow("原生充电上限", nativeLimitSummary ?? "—")
            }
            .font(.caption.monospaced())

            HStack(spacing: 8) {
                Button("刷新状态") {
                    helperManager.updateStatus()
                    helperManager.checkIfRunning()
                }
                Button("连接测试") {
                    Task { await pingHelper() }
                }
                Button("安装 / 激活") {
                    helperManager.beginInstallation()
                }
                Button("重新安装") {
                    helperManager.reactivateHelper()
                }
                Button("重置后台活动") {
                    helperManager.resetOwnBackgroundActivity()
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .debugCard()
    }

    // MARK: - Battery state

    private var batteryStateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("电池状态", systemImage: "battery.100percent", color: .green)

            let state = battery
            let management = batteryStatus.currentState.managementState.rawValue
            let derived = derivedBatteryState

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                gridRow("电量", state.map { "\($0.level)%" } ?? "—")
                gridRow("正在充电", state.map { $0.isCharging ? "是" : "否" } ?? "—")
                gridRow("已接电源", state.map { $0.isPluggedIn ? "是" : "否" } ?? "—")
                gridRow("管理状态", management)
                gridRow("推导状态", derived)
                gridRow("指示灯颜色", "\(batteryStatus.currentState.ledColor)")
                gridRow("睡眠中", batteryStatus.currentState.isSleeping ? "是" : "否")
                gridRow("低电量模式", powerModeManager.isLowPowerModeActive ? "开启" : "关闭")
                gridRow("温度", batteryTemp.map { String(format: "%.1f °C", $0) } ?? "—")
                gridRow("硬件电量 %", hardwarePercent.map(String.init) ?? "—")
            }
            .font(.caption.monospaced())

            if let adapter {
                Text("电源适配器：\(adapter.name) · \(adapter.power)W · \(adapter.voltage)mV · \(adapter.current)mA")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .debugCard()
    }

    private var derivedBatteryState: String {
        guard let state = battery else { return "未知" }
        let management = batteryStatus.currentState.managementState
        switch management {
        case .inhibited, .sailing, .heatProtection, .discharging, .calibrating:
            return management.rawValue
        default:
            if state.isCharging { return "正在充电" }
            if state.isPluggedIn { return "已接电源（未充电）" }
            return "使用电池供电"
        }
    }

    // MARK: - Charging tests

    private var chargingTestCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("充电控制", systemImage: "bolt.fill", color: .yellow)

            HStack(spacing: 8) {
                Button("暂停充电") {
                    Task { await pauseCharging() }
                }
                Button("恢复充电") {
                    BatteryManager.shared.enableCharging(true)
                    BatteryManager.shared.setChargeLimit(100)
                    appendLog("enableCharging(true) + setChargeLimit(100)")
                }
                Button("开始放电") {
                    BatteryManager.shared.setDischarge(discharging: true, safetyFloor: 5, rechargeOnFloor: true, bypassSafetyFloor: false)
                    appendLog("setDischarge(true, safetyFloor: 5, rechargeOnFloor: true, bypassSafetyFloor: false)")
                }
                Button("停止放电") {
                    BatteryManager.shared.setDischarge(discharging: false)
                    appendLog("setDischarge(false)")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            HStack(spacing: 8) {
                Text("上限：")
                TextField("80", value: $limitInput, formatter: Self.integerFormatter)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                Button("设置充电上限") {
                    BatteryManager.shared.setChargeLimit(limitInput)
                    appendLog("setChargeLimit(\(limitInput))")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            HStack(spacing: 8) {
                Button("MagSafe 绿灯") {
                    BatteryManager.shared.setMagSafeLED(color: 3)
                    appendLog("setMagSafeLED(green)")
                }
                Button("MagSafe 橙灯") {
                    BatteryManager.shared.setMagSafeLED(color: 4)
                    appendLog("setMagSafeLED(amber)")
                }
                Button("MagSafe 关闭") {
                    BatteryManager.shared.setMagSafeLED(color: 1)
                    appendLog("setMagSafeLED(off)")
                }
                Button(powerModeManager.isLowPowerModeActive ? "低电量模式：关" : "低电量模式：开") {
                    if powerModeManager.isLowPowerModeActive {
                        powerModeManager.disableLowPowerMode()
                    } else {
                        powerModeManager.enableLowPowerMode()
                    }
                    appendLog("已切换低电量模式")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .debugCard()
    }

    // MARK: - On-demand data

    private var onDemandDataCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("按需读取数据", systemImage: "list.bullet.rectangle", color: .purple)

            HStack(spacing: 8) {
                Button("读取 SMC 键值") {
                    Task { await loadSMCKeys() }
                }
                Button("读取风扇信息") {
                    Task { await loadFanInfo() }
                }
                Button("读取适配器信息") {
                    Task { await loadAdapter() }
                }
                Button("读取温度") {
                    Task { await loadTemperature() }
                }
                Button("读取硬件电量 %") {
                    Task { await loadHardwarePercent() }
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            if !smcKeys.isEmpty {
                Text("SMC 键值（\(smcKeys.count) 个）：\(smcKeys.joined(separator: ", "))")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if let fanCount {
                VStack(alignment: .leading, spacing: 4) {
                    Text("风扇数量：\(fanCount)")
                    ForEach(fanManager.fans, id: \.id) { fan in
                        Text("风扇 \(fan.id) · \(fan.name) · \(fan.currentRPM) RPM · 最低 \(fan.minRPM) · 最高 \(fan.maxRPM)")
                    }
                }
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            }
        }
        .debugCard()
    }

    // MARK: - Log

    private var logCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("操作日志", systemImage: "terminal.fill", color: .gray)
            if log.isEmpty {
                Text("暂无操作记录。")
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
            } else {
                Text(log.joined(separator: "\n"))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button("清空日志") { log.removeAll() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .debugCard()
    }

    // MARK: - Helpers

    private func sectionTitle(_ title: String, systemImage: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage).foregroundStyle(color)
            Text(title).font(.headline)
        }
    }

    private func gridRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value).textSelection(.enabled)
        }
    }

    private func appendLog(_ message: String) {
        log.append("[\(Self.logTimeFormatter.string(from: Date()))] \(message)")
        if log.count > 200 { log.removeFirst(log.count - 200) }
    }

    // MARK: - Actions

    private func refreshEverything() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }

        helperManager.updateStatus()
        helperManager.checkIfRunning()
        await pingHelper()
        await loadTemperature()
        await loadHardwarePercent()
        await loadAdapter()
        appendLog("已刷新辅助程序与电池快照")
    }

    private func pingHelper() async {
        let running = await XPCClient.shared.ping(timeout: 3)
        protocolVersion = await XPCClient.shared.helperProtocolVersion(timeout: 3)
        chargeControlMode = await BatteryManager.shared.currentChargeControlMode()
        if await NativeChargeLimit.isSupported {
            let enabled = await NativeChargeLimit.isEnabled
            let limit = await NativeChargeLimit.currentLimit
            nativeLimitSummary = "\(enabled.map { $0 ? "开启" : "关闭" } ?? "?") @ \(limit.map { "\($0)%" } ?? "?")\(NativeChargeLimit.sapphireOwnsLimit ? " (Sapphire)" : "")"
        } else {
            nativeLimitSummary = "不支持"
        }
        appendLog("连接测试：\(running ? "可达" : "不可达")，协议 v\(protocolVersion.map(String.init) ?? "?")，模式 \(String(describing: chargeControlMode ?? .legacy))")
    }

    private func pauseCharging() async {
        let mode = await BatteryManager.shared.currentChargeControlMode()
        switch mode {
        case .firmware:
            BatteryManager.shared.setChargeLimit(limitInput)
            appendLog("固件暂停充电：setChargeLimit(\(limitInput))")
        case .adapter:
            BatteryManager.shared.enableCharging(false)
            appendLog("适配器暂停充电：enableCharging(false) [切断外接供电]")
        case .legacy, .unsupported:
            BatteryManager.shared.enableCharging(false)
            appendLog("\(mode) 暂停充电：enableCharging(false)")
        }
    }

    private func loadSMCKeys() async {
        guard let helper = BatteryManager.shared.getHelper() else {
            appendLog("读取 SMC 键值失败：无辅助程序代理")
            return
        }
        smcKeys = (await helper.getAllSMCKeys()).sorted()
        appendLog("已加载 \(smcKeys.count) 个 SMC 键值")
    }

    private func loadFanInfo() async {
        guard let helper = BatteryManager.shared.getHelper() else {
            appendLog("读取风扇信息失败：无辅助程序代理")
            return
        }
        fanCount = await helper.getFanCount()
        await fanManager.refreshHardwareState(forceRediscovery: true)
        appendLog("风扇数量：\(fanCount ?? 0)")
    }

    private func loadAdapter() async {
        adapter = await BatteryManager.shared.getPowerAdapterInfo()
        appendLog("适配器：\(adapter?.name ?? "不可用") \(adapter?.power ?? 0)W")
    }

    private func loadTemperature() async {
        batteryTemp = await BatteryManager.shared.getBatteryTemperature()
        appendLog("电池温度：\(batteryTemp.map { String(format: "%.1f", $0) } ?? "—") °C")
    }

    private func loadHardwarePercent() async {
        hardwarePercent = await BatteryManager.shared.getHardwareBatteryPercentage()
        appendLog("硬件电量：\(hardwarePercent.map(String.init) ?? "—")")
    }
}

private struct BatteryDebugCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .roundedCard(fill: Color.orange.opacity(0.06), cornerRadius: 18, stroke: Color.orange.opacity(0.25))
    }
}

private extension View {
    func debugCard() -> some View {
        modifier(BatteryDebugCardModifier())
    }
}