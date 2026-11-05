import Combine
import Foundation
import IOKit
import IOKit.ps
import ServiceManagement
import IslandCore

/// 特权守护进程生命周期状态
public enum HelperDaemonStatus: String, Equatable, Sendable {
    case notRegistered
    case enabled
    case requiresApproval
    case notFound

    public var localizedTitle: String {
        switch self {
        case .notRegistered: return "未启用"
        case .enabled: return "已启用"
        case .requiresApproval: return "等待系统授权"
        case .notFound: return "未检测到辅助组件"
        }
    }
}

/// 特权辅助服务协调器：负责 `SMAppService.daemon` 注册重装、`NSXPCConnection` 握手与本地 IOKit 电池回退读取
@MainActor
public final class HelperCoordinator: ObservableObject, PrivilegedHelperProtocol {
    public static let shared = HelperCoordinator()

    @Published public private(set) var status: HelperDaemonStatus
    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var isReconciling: Bool
    @Published public private(set) var lastErrorMessage: String?

    /// 面向 UI 展示的问题提示：对账握手期间（`isReconciling == true`）严禁提前闪现错误横幅
    public var visibleIssue: String? {
        if isReconciling {
            return nil
        }
        switch status {
        case .notRegistered:
            return nil
        case .requiresApproval:
            return "请在「系统设置 → 通用 → 登录项与扩展」中允许星岛后台辅助服务"
        case .notFound:
            return lastErrorMessage ?? "未找到内嵌特权辅助服务，请将星岛移动至「应用程序」目录后重试"
        case .enabled:
            if isConnected {
                return nil
            }
            return lastErrorMessage ?? "特权辅助服务尚未连通，可点击「重装修复」自动恢复连接"
        }
    }

    private var xpcConnection: NSXPCConnection?
    private let statusProvider: () -> HelperDaemonStatus
    private let registerHandler: () throws -> Void
    private let unregisterHandler: () async throws -> Void
    private let disconnectHandler: (() -> Void)?
    private let pingHandler: (() async -> Bool)?
    private let sleepMilliseconds: (UInt64) async -> Void

    public init(
        initialStatus: HelperDaemonStatus? = nil,
        initialReconciling: Bool = false,
        statusProvider: (() -> HelperDaemonStatus)? = nil,
        registerHandler: (() throws -> Void)? = nil,
        unregisterHandler: (() async throws -> Void)? = nil,
        disconnectHandler: (() -> Void)? = nil,
        pingHandler: (() async -> Bool)? = nil,
        sleepMilliseconds: ((UInt64) async -> Void)? = nil
    ) {
        let resolvedProvider: () -> HelperDaemonStatus = statusProvider ?? {
            Self.readSystemDaemonStatus()
        }
        self.statusProvider = resolvedProvider
        self.status = initialStatus ?? resolvedProvider()
        self.isReconciling = initialReconciling
        self.registerHandler = registerHandler ?? {
            let service = SMAppService.daemon(plistName: StarIslandHelperConstants.plistName)
            try service.register()
        }
        self.unregisterHandler = unregisterHandler ?? {
            let service = SMAppService.daemon(plistName: StarIslandHelperConstants.plistName)
            try await service.unregister()
        }
        self.disconnectHandler = disconnectHandler
        self.pingHandler = pingHandler
        self.sleepMilliseconds = sleepMilliseconds ?? { ms in
            try? await Task.sleep(nanoseconds: ms * 1_000_000)
        }
    }

    // MARK: - 生命周期与无感对账

    /// 启动或回到前台时对账连接状态（握手完成前保持 `isReconciling == true`，绝不误报红叉）
    public func reconcileConnection() async {
        isReconciling = true
        let currentStatus = statusProvider()
        status = currentStatus

        guard currentStatus == .enabled else {
            isConnected = false
            isReconciling = false
            return
        }

        let reachable = await performPing()
        isConnected = reachable
        if reachable {
            lastErrorMessage = nil
        } else if lastErrorMessage == nil {
            lastErrorMessage = "特权辅助服务未响应握手，您可以点击「重装修复」重新激活"
        }
        isReconciling = false
    }

    /// 首次注册启用特权守护服务
    public func registerHelper() async {
        isReconciling = true
        lastErrorMessage = nil
        do {
            try registerHandler()
        } catch {
            lastErrorMessage = "启用特权辅助服务失败：\(error.localizedDescription)"
        }
        status = statusProvider()
        if status == .enabled {
            await sleepMilliseconds(300)
            isConnected = await performPing()
            if isConnected {
                lastErrorMessage = nil
            }
        } else {
            isConnected = false
        }
        isReconciling = false
    }

    /// 安全重装修复：严格执行 断开 XPC -> 等待 400ms -> unregister -> 等待 1200ms -> register -> 重新握手
    public func reinstallHelper() async {
        isReconciling = true
        lastErrorMessage = nil
        isConnected = false

        disconnectXPC()
        await sleepMilliseconds(400)

        try? await unregisterHandler()
        await sleepMilliseconds(1200)

        do {
            try registerHandler()
        } catch {
            lastErrorMessage = "重装特权辅助服务失败：\(error.localizedDescription)"
        }

        status = statusProvider()
        if status == .enabled {
            let reachable = await performPing()
            isConnected = reachable
            if !reachable && lastErrorMessage == nil {
                lastErrorMessage = "特权辅助服务重装后暂未连通，请检查系统设置中的登录项开关"
            }
        } else {
            isConnected = false
        }
        isReconciling = false
    }

    /// 主动断开当前 XPC 会话并释放客户端引用
    public func disconnectXPC() {
        disconnectHandler?()
        if let conn = xpcConnection {
            conn.invalidationHandler = nil
            conn.interruptionHandler = nil
            conn.invalidate()
            xpcConnection = nil
        }
    }

    /// 跳转系统设置「登录项与扩展」面板
    public func openSystemLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    // MARK: - PrivilegedHelperProtocol 实现

    public func ping() async -> Bool {
        let ok = await performPing()
        isConnected = ok
        return ok
    }

    public func readHardwareSnapshot() async -> BatteryHardwareSnapshot? {
        if status == .enabled {
            if let remoteData: Data = await invokeXPC({ proxy, resume in
                proxy.fetchHardwareSnapshotJSON { data in
                    resume(data)
                }
            }), let snapshot = try? JSONDecoder().decode(BatteryHardwareSnapshot.self, from: remoteData) {
                isConnected = true
                return snapshot
            }
        }
        // 未启用或未连通特权 Helper 时，回退读取本机 IOKit 真实电池容量与充电状态
        return Self.readLocalBatterySnapshot()
    }

    public func setChargeInhibit(_ inhibit: Bool, chargeLimit: Int) async -> Bool {
        let result: (Bool, String?)? = await invokeXPC { proxy, resume in
            proxy.setChargeControl(inhibit: inhibit, limit: chargeLimit) { ok, err in
                resume((ok, err))
            }
        }
        if let (ok, errMsg) = result {
            if !ok, let errMsg { lastErrorMessage = errMsg }
            return ok
        }
        return false
    }

    public func setFanControl(manual: Bool, targetRPM: Int) async -> Bool {
        let result: (Bool, String?)? = await invokeXPC { proxy, resume in
            proxy.setFanTarget(manual: manual, rpm: targetRPM) { ok, err in
                resume((ok, err))
            }
        }
        if let (ok, errMsg) = result {
            if !ok, let errMsg { lastErrorMessage = errMsg }
            return ok
        }
        return false
    }

    public func applyManagedBlockedDomains(_ domains: [String]) async -> Bool {
        let result: (Bool, String?)? = await invokeXPC { proxy, resume in
            proxy.updateManagedHosts(domains: domains) { ok, err in
                resume((ok, err))
            }
        }
        return result?.0 ?? false
    }

    public func installStagedUpdate(from stagedAppPath: String, to targetAppPath: String) async throws -> Bool {
        let result: (Bool, String?)? = await invokeXPC { proxy, resume in
            proxy.installAppBundle(stagedPath: stagedAppPath, destinationPath: targetAppPath) { ok, err in
                resume((ok, err))
            }
        }
        if let (ok, errMessage) = result {
            if !ok {
                throw NSError(
                    domain: "StarIslandHelper",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: errMessage ?? "特权安装更新包失败"]
                )
            }
            return true
        }
        return false
    }

    // MARK: - 本机 IOKit 电池信息回退（无需特权即可展示精准电量与充电状态）

    public nonisolated static func readLocalBatterySnapshot() -> BatteryHardwareSnapshot {
        var percentage = 100
        var isCharging = false
        var isPluggedIn = true

        if let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] {
            for source in sources {
                guard let desc = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any] else {
                    continue
                }
                if let current = desc[kIOPSCurrentCapacityKey as String] as? Int,
                   let maxCap = desc[kIOPSMaxCapacityKey as String] as? Int,
                   maxCap > 0 {
                    percentage = min(max(Int((Double(current) / Double(maxCap) * 100.0).rounded()), 0), 100)
                }
                if let charging = desc[kIOPSIsChargingKey as String] as? Bool {
                    isCharging = charging
                }
                if let powerState = desc[kIOPSPowerSourceStateKey as String] as? String {
                    isPluggedIn = (powerState == (kIOPSACPowerValue as String))
                }
                break
            }
        }

        var temperatureC = 32.0
        var cycleCount = 0
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        if service != IO_OBJECT_NULL {
            defer { IOObjectRelease(service) }
            var propsRef: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &propsRef, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let props = propsRef?.takeRetainedValue() as? [String: Any] {
                if let cycles = props["CycleCount"] as? Int {
                    cycleCount = max(0, cycles)
                }
                if let rawTemp = props["Temperature"] as? Int {
                    let scaled = Double(rawTemp) / 100.0
                    if scaled >= 5.0 && scaled <= 85.0 {
                        temperatureC = scaled
                    }
                }
            }
        }

        return BatteryHardwareSnapshot(
            percentage: percentage,
            isCharging: isCharging,
            isPluggedIn: isPluggedIn,
            temperatureCelsius: temperatureC,
            cycleCount: cycleCount,
            currentFanRPM: 0,
            minFanRPM: 1200,
            maxFanRPM: 5500
        )
    }

    // MARK: - 内部 XPC 通信

    private func performPing() async -> Bool {
        if let pingHandler {
            return await pingHandler()
        }
        let version: Int? = await invokeXPC { proxy, resume in
            proxy.pingProtocolVersion { ver in
                resume(ver)
            }
        }
        return version == StarIslandHelperConstants.protocolVersion
    }

    private func activeConnection() -> NSXPCConnection {
        if let existing = xpcConnection {
            return existing
        }
        let conn = NSXPCConnection(
            machServiceName: StarIslandHelperConstants.machServiceName,
            options: .privileged
        )
        conn.remoteObjectInterface = NSXPCInterface(with: StarIslandHelperXPCProtocol.self)
        conn.invalidationHandler = { [weak self] in
            Task { @MainActor in
                self?.xpcConnection = nil
                self?.isConnected = false
            }
        }
        conn.interruptionHandler = { [weak self] in
            Task { @MainActor in
                self?.isConnected = false
            }
        }
        conn.resume()
        xpcConnection = conn
        return conn
    }

    private func invokeXPC<T: Sendable>(
        _ body: (StarIslandHelperXPCProtocol, @escaping @Sendable (T?) -> Void) -> Void
    ) async -> T? {
        let conn = activeConnection()
        return await withCheckedContinuation { continuation in
            let box = ContinuationOnceBox(continuation)
            let finish: @Sendable (T?) -> Void = { value in
                box.finish(value)
            }

            guard let proxy = conn.remoteObjectProxyWithErrorHandler({ _ in
                finish(nil)
            }) as? StarIslandHelperXPCProtocol else {
                finish(nil)
                return
            }

            body(proxy, finish)
        }
    }

    private nonisolated static func readSystemDaemonStatus() -> HelperDaemonStatus {
        let service = SMAppService.daemon(plistName: StarIslandHelperConstants.plistName)
        switch service.status {
        case .notRegistered:
            return .notRegistered
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .notFound
        @unknown default:
            return .notFound
        }
    }
}

private final class ContinuationOnceBox<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T?, Never>?

    init(_ continuation: CheckedContinuation<T?, Never>) {
        self.continuation = continuation
    }

    func finish(_ value: T?) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(returning: value)
    }
}
