import Combine
import Foundation
import IslandCore

/// 充电抑制触发原因
public enum ChargeInhibitReason: String, Codable, Equatable, Sendable {
    case reachedLimit
    case overheat

    public var localizedDescription: String {
        switch self {
        case .reachedLimit: return "已达设定充电上限"
        case .overheat: return "电池温度过高保护停充"
        }
    }
}

/// 充电控制决策动作
public enum ChargeControlAction: Equatable, Sendable {
    case allowCharging
    case maintainInhibit
    case inhibitCharging(reason: ChargeInhibitReason)
}

/// 纯函数式电池充电保护策略（充电上限 + 巡航防微充 + 高温停充）
public enum BatteryChargePolicy {
    public static func decideAction(
        level: Int,
        isCharging: Bool,
        limit: Int,
        sailingDrop: Int,
        temperatureC: Double,
        maxTempC: Double
    ) -> ChargeControlAction {
        if temperatureC >= maxTempC {
            return .inhibitCharging(reason: .overheat)
        }

        let clampedLimit = min(max(limit, 50), 100)
        guard clampedLimit < 100 else {
            return .allowCharging
        }

        if level >= clampedLimit {
            return .inhibitCharging(reason: .reachedLimit)
        }

        let clampedDrop = max(1, min(sailingDrop, 30))
        let resumeThreshold = max(20, clampedLimit - clampedDrop)
        if level <= resumeThreshold {
            return .allowCharging
        }

        // 处于 (resumeThreshold, clampedLimit) 巡航回落区间：
        // 若当前未在充电（已处于抑制停充状态），维持停充避免频繁补电；若正处于充电爬升阶段，继续充至上限
        return isCharging ? .allowCharging : .maintainInhibit
    }
}

/// 风扇预设模式
public enum FanControlPreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case auto
    case quiet
    case balanced
    case turbo
    case curve

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .auto: return "系统自动"
        case .quiet: return "静音优先"
        case .balanced: return "均衡散热"
        case .turbo: return "全速降温"
        case .curve: return "温控曲线"
        }
    }
}

/// 自定义风扇温控曲线模型
public struct FanCurveProfile: Codable, Equatable, Sendable {
    public struct Point: Codable, Equatable, Sendable {
        public var temperatureC: Double
        /// 归一化转速比例（0.0 对应最低转速，1.0 对应最高转速）
        public var speedRatio: Double

        public init(temperatureC: Double, speedRatio: Double) {
            self.temperatureC = temperatureC
            self.speedRatio = min(max(speedRatio, 0.0), 1.0)
        }
    }

    public static let defaultPoints: [Point] = [
        Point(temperatureC: 42.0, speedRatio: 0.0),
        Point(temperatureC: 60.0, speedRatio: 0.45),
        Point(temperatureC: 75.0, speedRatio: 0.80),
        Point(temperatureC: 85.0, speedRatio: 1.0),
    ]

    public var points: [Point]

    public init(points: [Point] = FanCurveProfile.defaultPoints) {
        self.points = points.sorted { $0.temperatureC < $1.temperatureC }
    }

    /// 根据当前温度与硬件风扇转速区间计算目标转速（分段线性插值并严格钳制在 `[minRPM, maxRPM]`）
    public func targetRPM(forTemperatureC temperatureC: Double, minRPM: Int, maxRPM: Int) -> Int {
        let lowerBound = max(0, min(minRPM, maxRPM))
        let upperBound = max(lowerBound, max(minRPM, maxRPM))
        let sorted = points.sorted { $0.temperatureC < $1.temperatureC }

        guard let first = sorted.first, let last = sorted.last else {
            return lowerBound
        }

        let ratio: Double
        if temperatureC <= first.temperatureC {
            ratio = first.speedRatio
        } else if temperatureC >= last.temperatureC {
            ratio = last.speedRatio
        } else {
            var interpolated = first.speedRatio
            for idx in 0..<(sorted.count - 1) {
                let p0 = sorted[idx]
                let p1 = sorted[idx + 1]
                if temperatureC >= p0.temperatureC && temperatureC <= p1.temperatureC {
                    let span = p1.temperatureC - p0.temperatureC
                    if span <= 0.0001 {
                        interpolated = p1.speedRatio
                    } else {
                        let t = (temperatureC - p0.temperatureC) / span
                        interpolated = p0.speedRatio + t * (p1.speedRatio - p0.speedRatio)
                    }
                    break
                }
            }
            ratio = interpolated
        }

        let clampedRatio = min(max(ratio, 0.0), 1.0)
        let rawRPM = Double(lowerBound) + clampedRatio * Double(upperBound - lowerBound)
        return min(max(Int(rawRPM.rounded()), lowerBound), upperBound)
    }
}

/// 智能电池充电保护与风扇温控管家（全流程对接 `MutationJournal` 保障崩溃自愈与退出还原）
@MainActor
public final class BatteryFanManager: ObservableObject {
    public static let shared = BatteryFanManager()

    private static let thermalAlertActivityID = "hardware.battery.thermal-alert"

    @Published public private(set) var snapshot: BatteryHardwareSnapshot
    @Published public private(set) var lastChargeAction: ChargeControlAction = .allowCharging
    @Published public private(set) var isChargeInhibited: Bool = false
    @Published public private(set) var isThermalWarningActive: Bool = false
    @Published public var customCurve: FanCurveProfile = FanCurveProfile()

    private let helperProvider: () -> PrivilegedHelperProtocol
    private let settingsStore: SettingsStore
    private let journal: MutationJournal
    private let stateMachine: IslandStateMachine
    private var monitorTask: Task<Void, Never>?

    public init(
        helper: PrivilegedHelperProtocol? = nil,
        settingsStore: SettingsStore? = nil,
        journal: MutationJournal? = nil,
        stateMachine: IslandStateMachine? = nil
    ) {
        let resolvedSettings = settingsStore ?? .shared
        let resolvedJournal = journal ?? .shared
        let resolvedStateMachine = stateMachine ?? .shared
        self.settingsStore = resolvedSettings
        self.journal = resolvedJournal
        self.stateMachine = resolvedStateMachine
        self.snapshot = HelperCoordinator.readLocalBatterySnapshot()
        self.helperProvider = {
            if let helper { return helper }
            if let registered = ServiceRegistry.shared.helperService { return registered }
            return HelperCoordinator.shared
        }
    }

    // MARK: - 崩溃残留恢复与退出安全还原

    /// 启动时检查 `MutationJournal`：若上次会话异常退出遗留了充电抑制或手动风扇状态，先恢复系统自动策略并清理记录
    public func recoverPendingMutationsIfNeeded() async {
        let pending = journal.pendingRecords()
        guard !pending.isEmpty else { return }

        let helper = helperProvider()
        let kinds = Set(pending.map(\.kind))

        if kinds.contains(.batteryChargeInhibit) || kinds.contains(.batteryChargeLimit) {
            if await helper.setChargeInhibit(false, chargeLimit: 100) {
                journal.clear(.batteryChargeInhibit)
                journal.clear(.batteryChargeLimit)
                isChargeInhibited = false
            }
        }

        if kinds.contains(.fanManualControl) {
            if await helper.setFanControl(manual: false, targetRPM: 0) {
                journal.clear(.fanManualControl)
            }
        }
    }

    /// 应用退出时按 `MutationJournal` 恢复默认自动充电与系统自动风扇控制
    public func restoreSystemDefaultsOnTermination() async {
        stopMonitoring()
        let pending = journal.pendingRecords()
        let helper = helperProvider()
        let kinds = Set(pending.map(\.kind))

        if isChargeInhibited || kinds.contains(.batteryChargeInhibit) || kinds.contains(.batteryChargeLimit) {
            if await helper.setChargeInhibit(false, chargeLimit: 100) {
                journal.clear(.batteryChargeInhibit)
                journal.clear(.batteryChargeLimit)
            }
            isChargeInhibited = false
        }

        if kinds.contains(.fanManualControl) || settingsStore.settings.fanControlMode != FanControlPreset.auto.rawValue {
            if await helper.setFanControl(manual: false, targetRPM: 0) {
                journal.clear(.fanManualControl)
            }
        }

        isThermalWarningActive = false
        stateMachine.dismiss(id: Self.thermalAlertActivityID)
    }

    // MARK: - 周期巡检与即时策略评估

    public func startMonitoring(intervalSeconds: TimeInterval = 15) {
        stopMonitoring()
        let safeInterval = max(3, intervalSeconds)
        monitorTask = Task { [weak self] in
            guard let self else { return }
            await self.recoverPendingMutationsIfNeeded()
            while !Task.isCancelled {
                await self.evaluateAndApply()
                try? await Task.sleep(nanoseconds: UInt64(safeInterval * 1_000_000_000))
            }
        }
    }

    public func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
    }

    /// 读取最新电池/风扇硬件快照并应用充电上限、巡航、高温保护与风扇模式
    public func evaluateAndApply(using overrideSnapshot: BatteryHardwareSnapshot? = nil) async {
        let helper = helperProvider()
        let current: BatteryHardwareSnapshot
        if let overrideSnapshot {
            current = overrideSnapshot
        } else if let fetched = await helper.readHardwareSnapshot() {
            current = fetched
        } else {
            current = HelperCoordinator.readLocalBatterySnapshot()
        }
        snapshot = current

        await applyChargePolicy(for: current, helper: helper)
        await applyFanPolicy(for: current, helper: helper)
    }

    // MARK: - 内部执行逻辑

    private func applyChargePolicy(for current: BatteryHardwareSnapshot, helper: PrivilegedHelperProtocol) async {
        let cfg = settingsStore.settings
        let effectiveLimit = cfg.enableBatteryChargeLimit ? cfg.batteryChargeLimit : 100
        let effectiveMaxTemp = cfg.enableThermalChargeProtection ? cfg.maxChargeTemperatureCelsius : 999.0
        let effectiveCharging = current.isCharging && !isChargeInhibited

        let action = BatteryChargePolicy.decideAction(
            level: current.percentage,
            isCharging: effectiveCharging,
            limit: effectiveLimit,
            sailingDrop: cfg.batterySailingDropPercent,
            temperatureC: current.temperatureCelsius,
            maxTempC: effectiveMaxTemp
        )
        lastChargeAction = action

        switch action {
        case .inhibitCharging(let reason):
            journal.record(
                MutationRecord(
                    kind: .batteryChargeInhibit,
                    previousValue: "allow:100",
                    appliedValue: "inhibit:\(effectiveLimit):\(reason.rawValue)"
                )
            )
            if await helper.setChargeInhibit(true, chargeLimit: effectiveLimit) {
                isChargeInhibited = true
            }
            if reason == .overheat {
                isThermalWarningActive = true
                presentThermalWarningActivity(temperatureC: current.temperatureCelsius)
            } else if isThermalWarningActive {
                isThermalWarningActive = false
                stateMachine.dismiss(id: Self.thermalAlertActivityID)
            }

        case .maintainInhibit:
            isChargeInhibited = true
            if isThermalWarningActive && current.temperatureCelsius < effectiveMaxTemp {
                isThermalWarningActive = false
                stateMachine.dismiss(id: Self.thermalAlertActivityID)
            }

        case .allowCharging:
            let hasPending = journal.pendingRecords().contains {
                $0.kind == .batteryChargeInhibit || $0.kind == .batteryChargeLimit
            }
            if isChargeInhibited || hasPending {
                if await helper.setChargeInhibit(false, chargeLimit: 100) {
                    journal.clear(.batteryChargeInhibit)
                    journal.clear(.batteryChargeLimit)
                    isChargeInhibited = false
                }
            }
            if isThermalWarningActive {
                isThermalWarningActive = false
                stateMachine.dismiss(id: Self.thermalAlertActivityID)
            }
        }
    }

    private func applyFanPolicy(for current: BatteryHardwareSnapshot, helper: PrivilegedHelperProtocol) async {
        let preset = FanControlPreset(rawValue: settingsStore.settings.fanControlMode) ?? .auto
        let minRPM = max(800, current.minFanRPM)
        let maxRPM = max(minRPM, current.maxFanRPM)

        switch preset {
        case .auto:
            let hasFanRecord = journal.pendingRecords().contains { $0.kind == .fanManualControl }
            if hasFanRecord {
                if await helper.setFanControl(manual: false, targetRPM: 0) {
                    journal.clear(.fanManualControl)
                }
            }

        case .quiet:
            await setManualFan(targetRPM: minRPM, helper: helper)

        case .balanced:
            let midRPM = minRPM + Int((Double(maxRPM - minRPM) * 0.42).rounded())
            await setManualFan(targetRPM: midRPM, helper: helper)

        case .turbo:
            await setManualFan(targetRPM: maxRPM, helper: helper)

        case .curve:
            let rpm = customCurve.targetRPM(
                forTemperatureC: current.temperatureCelsius,
                minRPM: minRPM,
                maxRPM: maxRPM
            )
            await setManualFan(targetRPM: rpm, helper: helper)
        }
    }

    private func setManualFan(targetRPM: Int, helper: PrivilegedHelperProtocol) async {
        journal.record(
            MutationRecord(
                kind: .fanManualControl,
                previousValue: "auto",
                appliedValue: "manual:\(targetRPM)"
            )
        )
        _ = await helper.setFanControl(manual: true, targetRPM: targetRPM)
    }

    private func presentThermalWarningActivity(temperatureC: Double) {
        let tempText = String(format: "%.1f℃", temperatureC)
        let item = IslandActivityItem(
            id: Self.thermalAlertActivityID,
            category: .battery,
            title: "电池高温保护已启动",
            subtitle: "当前电池温度 \(tempText)，已自动暂停充电",
            iconSymbol: "thermometer.sun.fill",
            trailingBadge: tempText,
            priority: .critical,
            isAlertHUD: true,
            allowsOnLockScreen: true,
            autoDismissAfter: 8.0
        )
        stateMachine.submit(item)
    }
}
