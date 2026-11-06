//
//  HelperManager.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2025-11-08.
//

import Foundation
import ServiceManagement
import AppKit
import SwiftUI
import OSLog

private let helperLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "StarIsland", category: "HelperManager")
private let sapphireHelperPlistName = "com.adgry.starisland.helper.plist"

// MARK: - Error codes

enum HelperIssue: Equatable {
    case spawnFailed
    case needsApproval
    case notFound

    var code: String {
        switch self {
        case .spawnFailed: return "SAP-H1"
        case .needsApproval: return "SAP-H2"
        case .notFound: return "SAP-H3"
        }
    }

    var title: String {
        switch self {
        case .spawnFailed: return "辅助工具无法启动"
        case .needsApproval: return "需要“登录项”批准"
        case .notFound: return "辅助工具注册缺失"
        }
    }

    var shortSummary: String {
        switch self {
        case .spawnFailed:
            return "权限已授予，但 macOS 仍无法启动辅助工具。"
        case .needsApproval:
            return "请在“登录项”中开启 星岛 与 StarIsland Helper。"
        case .notFound:
            return "macOS 丢失了辅助工具（状态 3）。请重置辅助工具；若仍卡住，星岛 将自动重新启动。"
        }
    }

    var instructions: String {
        switch self {
        case .notFound:
            return """
            错误代码：SAP-H3

            macOS 找不到辅助工具。

            解决步骤：
            1. 点击下方“重置辅助工具”。星岛 将通过 SMAppService 注销并重新注册辅助工具。
            2. 若辅助工具仍未启动，Sapphire 将自动重新启动——或点击“重新启动 星岛”。
            3. 星岛 打开后，如出现提示请点击“安装”。
            4. 前往“系统设置 → 通用 → 登录项”，在“允许在后台”下启用 StarIsland Helper。

            请先尝试“重置辅助工具”，仅当辅助工具随后仍然卡住时再重新启动应用。
            """
        case .needsApproval:
            return """
            错误代码：SAP-H2

            macOS 已注册辅助工具，但正在等待你的批准（SMAppService 状态 2）。

            解决步骤：
            1. 点击下方“打开登录项”。
            2. 在“允许在后台”下开启 星岛。
            3. 如 macOS 提示输入密码，请完成验证。
            4. 返回 星岛 并点击“安装 / 激活”。
            """
        case .spawnFailed:
            return """
            错误代码：SAP-H1

            “登录项”权限已授予（状态 1），但 macOS 仍无法启动辅助工具。这通常意味着 星岛 自身的辅助工具注册状态已卡住。

            请点击下方“重置辅助工具”。星岛 将注销并重新注册辅助工具，若问题依旧则自动重新启动。
            """
        }
    }
}

struct HelperStatusBanner: View {
    @ObservedObject var helperManager: HelperManager

    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: helperManager.bannerSymbol)
                .font(.title2)
                .foregroundColor(helperManager.bannerColor)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(helperManager.bannerTitle)
                        .font(.headline)
                    if let issue = helperManager.lastIssue {
                        Text(issue.code)
                            .font(.caption.weight(.semibold).monospaced())
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(helperManager.bannerColor.opacity(0.18))
                            .clipShape(Capsule())
                    }
                }
                Text(helperManager.bannerSubtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                if helperManager.isReconcilingHelper && !helperManager.isRunning {
                    ProgressView()
                        .controlSize(.small)
                } else if let issue = helperManager.lastIssue {
                    Button("操作说明") {
                        HelperAlertPresenter.present(issue)
                    }
                    .buttonStyle(.bordered)
                }

                if !helperManager.isRunning && !helperManager.isReconcilingHelper {
                    if helperManager.status == .enabled {
                        Button(helperManager.isResettingHelper ? "正在重置…" : "重置辅助工具") {
                            helperManager.resetOwnBackgroundActivity()
                        }
                        .disabled(helperManager.isResettingHelper)
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    } else if helperManager.status == .notFound {
                        Button(helperManager.isResettingHelper ? "正在重置…" : "重置辅助工具") {
                            helperManager.resetOwnBackgroundActivity()
                        }
                        .disabled(helperManager.isResettingHelper)
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        Button("重新启动") {
                            HelperManager.relaunchApp()
                        }
                        .buttonStyle(.bordered)
                    } else if helperManager.status == .requiresApproval {
                        Button("打开登录项") {
                            SMAppService.openSystemSettingsLoginItems()
                            helperManager.beginInstallation()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    } else if helperManager.status != .enabled {
                        Button("安装") {
                            helperManager.beginInstallation()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.accentColor)
                    }
                }
            }
        }
    }
}

@MainActor
class HelperManager: ObservableObject {
    static let shared = HelperManager()

    let helperToolIdentifier = "com.adgry.starisland.helper"

    @Published var status: SMAppService.Status = .notRegistered
    @Published var isRunning: Bool = false
    @Published var lastIssue: HelperIssue?
    @Published var isResettingHelper = false
    @Published private(set) var isReconcilingHelper = false

    private var isRegistering = false
    private var healthCheckInFlight = false
    private var installIfNeededInFlight = false
    private var hasCompletedInitialHealthCheck = false
    private var connectionObservers: [NSObjectProtocol] = []
    private var lastHealthCheck = Date.distantPast
    private let healthCheckMinimumInterval: TimeInterval = 5
    private var lastRegisterAttempt: Date?
    private var consecutiveMissedPings = 0
    private var presentedIssuesThisSession = Set<String>()
    private let registerCooldown: TimeInterval = 8

    private static var bundledPlistURL: URL {
        Bundle.main.bundleURL
            .appendingPathComponent("Contents/Library/LaunchDaemons", isDirectory: true)
            .appendingPathComponent(sapphireHelperPlistName, isDirectory: false)
    }

    var bannerTitle: String {
        if isRunning { return "辅助工具已启用" }
        if isReconcilingHelper { return "正在连接辅助工具…" }
        return lastIssue?.title ?? "辅助工具未安装"
    }

    var bannerSubtitle: String {
        if isRunning {
            return "特权辅助工具正在运行。"
        }
        if isReconcilingHelper {
            return "正在验证并启动特权辅助服务…"
        }
        return lastIssue?.shortSummary ?? "安装辅助工具以启用电池管理与系统集成。"
    }

    var bannerSymbol: String {
        if isRunning { return "checkmark.circle.fill" }
        if isReconcilingHelper { return "arrow.triangle.2.circlepath.circle.fill" }
        switch lastIssue {
        case .spawnFailed: return "exclamationmark.octagon.fill"
        case .needsApproval: return "exclamationmark.triangle.fill"
        case .notFound: return "arrow.triangle.2.circlepath.circle.fill"
        case nil: return "xmark.circle.fill"
        }
    }

    var bannerColor: Color {
        if isRunning { return .green }
        if isReconcilingHelper { return .secondary }
        switch lastIssue {
        case .spawnFailed: return .red
        case .needsApproval: return .yellow
        case .notFound: return .orange
        case nil: return .red
        }
    }

    private init() {
        let plistURL = Self.bundledPlistURL
        let plistExists = FileManager.default.fileExists(atPath: plistURL.path)
        helperLogger.info("[HelperManager] Initialized bundle=\(Bundle.main.bundlePath, privacy: .public) plist=\(plistURL.path, privacy: .public) exists=\(plistExists)")

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateStatus),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )

        let center = NotificationCenter.default
        connectionObservers = [
            center.addObserver(forName: .sapphireHelperConnectionLost, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.helperConnectionDidFail() }
            },
            center.addObserver(forName: .sapphireHelperConnectionRestored, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.helperConnectionDidRecover() }
            }
        ]

        Task {
            let current = await refreshStatus()
            if current == .enabled {
                if OnboardingLaunchPolicy.shouldShowOnboarding {
                    _ = await registerHelper(userInitiated: false, forceReinstall: false, presentsUI: false)
                } else {
                    installIfNeeded()
                }
            } else {
                hasCompletedInitialHealthCheck = true
                refreshIssue()
            }
        }
    }

    deinit {
        connectionObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    private func helperConnectionDidFail() {
        consecutiveMissedPings = 3
        isRunning = false
        refreshIssue()
    }

    private func helperConnectionDidRecover() {
        consecutiveMissedPings = 0
        isRunning = true
        refreshIssue()
    }

    nonisolated static func relaunchApp() {
        let path = Bundle.main.bundlePath.replacingOccurrences(of: "\"", with: "\\\"")
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-c", "sleep 0.7; /usr/bin/open -n \"\(path)\""]
        try? task.run()
        DispatchQueue.main.async {
            NSApplication.shared.terminate(nil)
        }
    }

    @objc func updateStatus() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            _ = await self.refreshStatus()
            if self.status == .enabled {
                self.checkIfRunning(force: false)
            }
        }
    }

    private func bundledPlistIsReadable() -> Bool {
        let url = Self.bundledPlistURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            helperLogger.error("[HelperManager] Bundled LaunchDaemon plist is missing at \(url.path, privacy: .public)")
            return false
        }
        guard let data = try? Data(contentsOf: url),
              (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) != nil else {
            helperLogger.error("[HelperManager] Bundled LaunchDaemon plist is not a readable property list at \(url.path, privacy: .public)")
            return false
        }
        return true
    }

    private func refreshStatus() async -> SMAppService.Status {
        guard bundledPlistIsReadable() else {
            applyStatus(.notFound)
            return .notFound
        }
        let newStatus = await Self.fetchDaemonStatus()
        applyStatus(newStatus)
        return newStatus
    }

    private func applyStatus(_ newStatus: SMAppService.Status) {
        if status != newStatus {
            helperLogger.info("[HelperManager] Status changed: \(String(describing: self.status)) -> \(String(describing: newStatus))")
            status = newStatus
        }
        refreshIssue()
    }

    nonisolated private static func fetchDaemonStatus() async -> SMAppService.Status {
        await Task.detached(priority: .utility) {
            SMAppService.daemon(plistName: sapphireHelperPlistName).status
        }.value
    }

    nonisolated private static func registerDaemon() async -> String? {
        await Task.detached(priority: .utility) {
            let service = SMAppService.daemon(plistName: sapphireHelperPlistName)
            do {
                try service.register()
                return nil
            } catch {
                let status = service.status
                if status == .enabled || status == .requiresApproval {
                    return nil
                }
                return error.localizedDescription
            }
        }.value
    }

    nonisolated private static func unregisterDaemon() async -> String? {
        await Task.detached(priority: .utility) {
            let service = SMAppService.daemon(plistName: sapphireHelperPlistName)
            do {
                try service.unregister()
                return nil
            } catch {
                let status = service.status
                if status == .notRegistered || status == .notFound {
                    return nil
                }
                return error.localizedDescription
            }
        }.value
    }

    func checkIfRunning(force: Bool = false) {
        guard !isRegistering, !installIfNeededInFlight, !healthCheckInFlight else { return }
        let now = Date()
        guard force || now.timeIntervalSince(lastHealthCheck) >= healthCheckMinimumInterval else { return }
        healthCheckInFlight = true
        lastHealthCheck = now
        refreshIssue()

        Task { @MainActor [weak self] in
            guard let self else { return }
            let running = await XPCClient.shared.ping(timeout: 2)
            self.healthCheckInFlight = false
            self.hasCompletedInitialHealthCheck = true
            helperLogger.info("[HelperManager] Ping result: \(running ? "running" : "NOT running"), current status: \(String(describing: self.status))")
            self.applyPingResult(running)
        }
    }

    func reactivateHelper() {
        Task { await registerHelper(userInitiated: true, forceReinstall: true) }
    }

    func resetOwnBackgroundActivity() {
        guard !isResettingHelper else { return }
        Task { await performOwnBackgroundActivityReset() }
    }

    func beginInstallation() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let currentStatus = await self.refreshStatus()
            helperLogger.info("[HelperManager] beginInstallation status=\(String(describing: currentStatus))")
            if currentStatus == .enabled, await self.helperIsRunningAndCurrent() {
                self.hasCompletedInitialHealthCheck = true
                self.applyPingResult(true)
                return
            }
            _ = await self.registerHelper(userInitiated: true, forceReinstall: false)
        }
    }

    func installIfNeeded() {
        guard !OnboardingLaunchPolicy.shouldShowOnboarding else { return }
        guard !installIfNeededInFlight else { return }
        installIfNeededInFlight = true
        refreshIssue()
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.installIfNeededInFlight = false
                self.hasCompletedInitialHealthCheck = true
                self.refreshIssue()
            }
            let currentStatus = await self.refreshStatus()
            helperLogger.info("[HelperManager] installIfNeeded daemon=\(String(describing: currentStatus)) issue=\(self.lastIssue?.code ?? "none")")

            switch currentStatus {
            case .notFound:
                _ = await self.registerHelper(userInitiated: false, forceReinstall: true, presentsUI: false)
            case .notRegistered:
                _ = await self.registerHelper(userInitiated: false, forceReinstall: false, presentsUI: false)
            case .enabled:
                if await self.helperIsRunningAndCurrent() {
                    self.applyPingResult(true)
                    return
                }
                helperLogger.info("[HelperManager] Helper enabled but down or stale; rebuilding registration")
                _ = await self.registerHelper(userInitiated: false, forceReinstall: true, presentsUI: false)
            case .requiresApproval:
                break
            @unknown default:
                break
            }
        }
    }

    private func helperIsRunningAndCurrent() async -> Bool {
        XPCClient.shared.start(force: false)
        for attempt in 1...4 {
            if await XPCClient.shared.ping(timeout: 2) {
                let current = await helperProtocolVersionMatches()
                helperLogger.info("[HelperManager] Helper ping ok on attempt \(attempt), current=\(current)")
                return current
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
        helperLogger.info("[HelperManager] Helper did not respond during startup reconciliation")
        return false
    }

    private func helperProtocolVersionMatches() async -> Bool {
        guard let running = await XPCClient.shared.helperProtocolVersion(timeout: 2) else {
            helperLogger.info("[HelperManager] Helper protocol version query failed")
            return false
        }
        helperLogger.info("[HelperManager] Helper protocol version: running=\(running) expected=\(SapphireHelperProtocolVersion)")
        return running == SapphireHelperProtocolVersion
    }

    func uninstall() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            XPCClient.shared.stop()
            if let errorDescription = await Self.unregisterDaemon() {
                helperLogger.error("[HelperManager] Helper unregistration failed: \(errorDescription)")
            } else {
                helperLogger.info("[HelperManager] Helper unregistration successful")
            }
            _ = await self.refreshStatus()
        }
    }

    private func performOwnBackgroundActivityReset() async {
        isResettingHelper = true
        isRegistering = true
        refreshIssue()
        defer {
            isRegistering = false
            isResettingHelper = false
            hasCompletedInitialHealthCheck = true
            refreshIssue()
        }

        helperLogger.info("[HelperManager] Resetting helper via SMAppService unregister/register")
        XPCClient.shared.stop()
        try? await Task.sleep(for: .milliseconds(400))

        if let errorDescription = await Self.unregisterDaemon() {
            helperLogger.error("[HelperManager] Helper unregister failed: \(errorDescription)")
        } else {
            helperLogger.info("[HelperManager] Unregistered privileged helper")
        }

        try? await Task.sleep(for: .milliseconds(1200))
        _ = await submitRegistration()
        _ = await refreshStatus()

        if await pingUntilRunning() {
            helperLogger.info("[HelperManager] Helper recovered after SMAppService reset")
            return
        }

        helperLogger.info("[HelperManager] Helper still not running; relaunching Sapphire to rebuild BTM")
        HelperManager.relaunchApp()
    }

    @discardableResult
    private func registerHelper(userInitiated: Bool, forceReinstall: Bool, presentsUI: Bool = true) async -> Bool {
        if isRegistering { return false }
        if let last = lastRegisterAttempt, Date().timeIntervalSince(last) < registerCooldown, !userInitiated, !forceReinstall {
            return false
        }

        isRegistering = true
        lastRegisterAttempt = Date()
        refreshIssue()
        defer {
            isRegistering = false
            hasCompletedInitialHealthCheck = true
            refreshIssue()
        }

        guard bundledPlistIsReadable() else {
            isRegistering = false
            hasCompletedInitialHealthCheck = true
            refreshIssue()
            if presentsUI { presentIssue(.notFound, force: userInitiated) }
            return false
        }

        helperLogger.info("[HelperManager] register() status=\(String(describing: self.status)), bundle=\(Bundle.main.bundlePath, privacy: .public), forceReinstall=\(forceReinstall)")

        if forceReinstall {
            _ = await reinstallHelper()
        } else {
            _ = await submitRegistration()
        }

        _ = await refreshStatus()

        if status == .requiresApproval {
            isRegistering = false
            hasCompletedInitialHealthCheck = true
            refreshIssue()
            if presentsUI {
                SMAppService.openSystemSettingsLoginItems()
                presentIssue(.needsApproval, force: true)
            }
            return false
        }

        if status == .notFound {
            if await pingUntilRunning() {
                return true
            }
            isRegistering = false
            hasCompletedInitialHealthCheck = true
            refreshIssue()
            if presentsUI { presentIssue(.notFound, force: userInitiated) }
            return false
        }

        if await pingUntilRunning() {
            if await helperProtocolVersionMatches() {
                return true
            }
            helperLogger.info("[HelperManager] Running helper is an old build; reinstalling")
            _ = await reinstallHelper()
            if await pingUntilRunning(), await helperProtocolVersionMatches() {
                return true
            }
        } else if !forceReinstall && status == .enabled {
            helperLogger.info("[HelperManager] Enabled helper did not respond to ping; automatically rebuilding SMAppService registration")
            _ = await reinstallHelper()
            _ = await refreshStatus()
            if await pingUntilRunning(), await helperProtocolVersionMatches() {
                return true
            }
        }

        isRegistering = false
        hasCompletedInitialHealthCheck = true
        refreshIssue()
        if presentsUI, let issue = lastIssue {
            presentIssue(issue, force: userInitiated || issue == .notFound)
        }
        return isRunning
    }

    private func submitRegistration() async -> Bool {
        if let errorDescription = await Self.registerDaemon() {
            helperLogger.error("[HelperManager] register() failed: \(errorDescription)")
            _ = await refreshStatus()
            return false
        }
        helperLogger.info("[HelperManager] register() returned success")
        return true
    }

    @discardableResult
    private func reinstallHelper() async -> Bool {
        helperLogger.info("[HelperManager] Stopping XPC then unregister/register to rebuild the SMAppService job")
        XPCClient.shared.stop()
        try? await Task.sleep(for: .milliseconds(400))
        if let errorDescription = await Self.unregisterDaemon() {
            helperLogger.error("[HelperManager] unregister() failed: \(errorDescription)")
        } else {
            helperLogger.info("[HelperManager] unregister() succeeded")
        }

        try? await Task.sleep(for: .milliseconds(1200))
        return await submitRegistration()
    }

    private func pingUntilRunning() async -> Bool {
        XPCClient.shared.start(force: true)
        try? await Task.sleep(for: .milliseconds(600))

        for attempt in 1...5 {
            let running = await XPCClient.shared.ping(timeout: 2)
            helperLogger.info("[HelperManager] Post-register ping \(attempt)/5: \(running ? "running" : "not running")")
            if running {
                applyPingResult(true)
                BatteryManager.shared.helperDidBecomeReachable()
                return true
            }
            XPCClient.shared.start(force: true)
            try? await Task.sleep(for: .milliseconds(700))
        }
        applyPingResult(false)
        return false
    }

    private func applyPingResult(_ running: Bool) {
        if running {
            consecutiveMissedPings = 0
            isRunning = true
        } else if isRunning {
            consecutiveMissedPings += 1
            if consecutiveMissedPings >= 3 {
                isRunning = false
            }
        } else {
            consecutiveMissedPings += 1
            isRunning = false
        }
        refreshIssue()
    }

    private func syncReconcilingState() {
        let reconciling = !isRunning && (
            isRegistering
                || isResettingHelper
                || installIfNeededInFlight
                || healthCheckInFlight
                || (!hasCompletedInitialHealthCheck && status == .enabled)
        )
        if isReconcilingHelper != reconciling {
            isReconcilingHelper = reconciling
        }
    }

    private func refreshIssue() {
        syncReconcilingState()
        if isRunning {
            lastIssue = nil
            return
        }
        if isReconcilingHelper {
            lastIssue = nil
            return
        }
        switch status {
        case .notFound:
            lastIssue = .notFound
        case .requiresApproval:
            lastIssue = .needsApproval
        case .enabled:
            lastIssue = .spawnFailed
        case .notRegistered:
            lastIssue = nil
        @unknown default:
            lastIssue = .notFound
        }
    }

    private func presentIssue(_ issue: HelperIssue, force: Bool) {
        if !force, presentedIssuesThisSession.contains(issue.code) { return }
        presentedIssuesThisSession.insert(issue.code)
        HelperAlertPresenter.present(issue)
    }
}

extension SMAppService.Status: CustomStringConvertible {
    public var description: String {
        switch self {
        case .notRegistered: return "未注册"
        case .enabled: return "已启用"
        case .requiresApproval: return "需要批准"
        case .notFound: return "未找到"
        @unknown default: return "未知"
        }
    }
}