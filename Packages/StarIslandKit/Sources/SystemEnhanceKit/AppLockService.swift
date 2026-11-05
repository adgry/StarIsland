import AppKit
import Combine
import Foundation
import IslandCore
import LocalAuthentication
import SwiftUI

/// 已安装应用候选项（供设置页勾选受保护应用）
public struct InstalledAppCandidate: Identifiable, Equatable, Sendable {
    public var id: String { bundleIdentifier }
    public let bundleIdentifier: String
    public let displayName: String
    public let bundlePath: String

    public init(bundleIdentifier: String, displayName: String, bundlePath: String) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.bundlePath = bundlePath
    }
}

/// Touch ID 指纹与系统密码生物识别应用锁服务
@MainActor
public final class AppLockService: ObservableObject {
    public static let shared = AppLockService(observeWorkspace: false)

    @Published public var isEnabled: Bool
    @Published public var relockInterval: TimeInterval
    @Published public var lockedBundleIDs: Set<String> {
        didSet {
            guard shouldPersistToSettings, !isSyncingFromStore else { return }
            let sorted = lockedBundleIDs.sorted()
            if settingsStore.settings.lockedAppBundleIDs != sorted {
                settingsStore.settings.lockedAppBundleIDs = sorted
            }
        }
    }

    @Published public private(set) var activeChallengeBundleID: String?
    @Published public private(set) var activeChallengeAppName: String = ""
    @Published public private(set) var isAuthenticating: Bool = false
    @Published public private(set) var authErrorMessage: String?

    private let settingsStore: SettingsStore
    private let stateMachine: IslandStateMachine
    private var shouldPersistToSettings: Bool
    private var isSyncingFromStore: Bool = false

    private var unlockedTimestamps: [String: Date] = [:]
    private var workspaceObservers: [NSObjectProtocol] = []
    private var settingsCancellable: AnyCancellable?
    private var shieldPanels: [NSPanel] = []
    private weak var pendingTargetApp: NSRunningApplication?

    private let hudActivityID = "systemenhance.applock"

    public init(
        settingsStore: SettingsStore? = nil,
        stateMachine: IslandStateMachine? = nil,
        relockInterval: TimeInterval? = nil,
        observeWorkspace: Bool = false
    ) {
        let resolvedStore = settingsStore ?? .shared
        let resolvedState = stateMachine ?? .shared
        self.settingsStore = resolvedStore
        self.stateMachine = resolvedState
        self.shouldPersistToSettings = (settingsStore != nil || observeWorkspace)

        if observeWorkspace {
            self.isEnabled = resolvedStore.settings.enableAppLock
            self.lockedBundleIDs = Set(resolvedStore.settings.lockedAppBundleIDs)
            self.relockInterval = relockInterval ?? TimeInterval(resolvedStore.settings.appLockRelockIntervalSeconds)
            start()
        } else {
            self.isEnabled = true
            self.lockedBundleIDs = settingsStore != nil ? Set(resolvedStore.settings.lockedAppBundleIDs) : []
            self.relockInterval = relockInterval ?? TimeInterval(resolvedStore.settings.appLockRelockIntervalSeconds)
        }
    }

    public func start() {
        shouldPersistToSettings = true
        syncFromSettings(settingsStore.settings)

        if settingsCancellable == nil {
            settingsCancellable = settingsStore.$settings
                .receive(on: RunLoop.main)
                .sink { [weak self] updated in
                    self?.syncFromSettings(updated)
                }
        }

        guard workspaceObservers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter

        let activateObs = center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            Task { @MainActor [weak self] in
                guard let self, let app else { return }
                self.handleDidActivateApplication(app)
            }
        }

        let deactivateObs = center.addObserver(
            forName: NSWorkspace.didDeactivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            Task { @MainActor [weak self] in
                guard let self, let bid = app?.bundleIdentifier else { return }
                if self.unlockedTimestamps[bid] != nil {
                    // 从切入后台起重新刷新倒计时起点，离开满 relockInterval 后自动重锁
                    self.unlockedTimestamps[bid] = Date()
                }
            }
        }

        workspaceObservers = [activateObs, deactivateObs]
    }

    public func stop() {
        let center = NSWorkspace.shared.notificationCenter
        for obs in workspaceObservers {
            center.removeObserver(obs)
        }
        workspaceObservers.removeAll()
        settingsCancellable?.cancel()
        settingsCancellable = nil
        dismissShieldOverlay()
    }

    // MARK: - 核心锁定判定与生命周期接口

    /// 判断当前激活指定 Bundle ID 应用时是否需要拦截并弹出生物识别遮罩
    public func shouldBlockActivation(bundleID: String, now: Date = Date()) -> Bool {
        guard isEnabled,
              !bundleID.isEmpty,
              bundleID != StarIslandHelperConstants.appBundleIdentifier,
              lockedBundleIDs.contains(bundleID) else {
            return false
        }

        guard let unlockedAt = unlockedTimestamps[bundleID] else {
            return true
        }

        if relockInterval <= 0 {
            return true
        }

        let elapsed = now.timeIntervalSince(unlockedAt)
        if elapsed >= relockInterval {
            unlockedTimestamps.removeValue(forKey: bundleID)
            return true
        }
        return false
    }

    /// 记录指定应用已完成生物识别验证解锁
    public func recordUnlock(bundleID: String, now: Date = Date()) {
        guard !bundleID.isEmpty else { return }
        unlockedTimestamps[bundleID] = now
    }

    /// 立即将指定应用恢复为锁定状态
    public func lockImmediately(bundleID: String) {
        unlockedTimestamps.removeValue(forKey: bundleID)
    }

    /// 立即锁定所有受保护应用
    public func lockAllImmediately() {
        unlockedTimestamps.removeAll()
    }

    public func toggleProtectedApp(bundleID: String) {
        guard !bundleID.isEmpty, bundleID != StarIslandHelperConstants.appBundleIdentifier else { return }
        if lockedBundleIDs.contains(bundleID) {
            lockedBundleIDs.remove(bundleID)
            unlockedTimestamps.removeValue(forKey: bundleID)
        } else {
            lockedBundleIDs.insert(bundleID)
        }
    }

    /// 扫描系统中已安装的常规应用列表供用户在设置页勾选加锁
    public static func discoverInstalledApps() -> [InstalledAppCandidate] {
        let roots = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Applications")
        ]

        var seen = Set<String>()
        var results: [InstalledAppCandidate] = []
        let fm = FileManager.default

        for root in roots {
            guard let urls = try? fm.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for appURL in urls where appURL.pathExtension == "app" {
                guard let bundle = Bundle(url: appURL),
                      let bundleID = bundle.bundleIdentifier,
                      bundleID != StarIslandHelperConstants.appBundleIdentifier,
                      seen.insert(bundleID).inserted else {
                    continue
                }
                let displayName = fm.displayName(atPath: appURL.path)
                    .replacingOccurrences(of: ".app", with: "")
                results.append(
                    InstalledAppCandidate(
                        bundleIdentifier: bundleID,
                        displayName: displayName,
                        bundlePath: appURL.path
                    )
                )
            }
        }

        return results.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    // MARK: - 全屏毛玻璃遮罩与 LAContext 认证闭环

    private func syncFromSettings(_ s: StarIslandSettings) {
        isSyncingFromStore = true
        defer { isSyncingFromStore = false }
        isEnabled = s.enableAppLock
        relockInterval = TimeInterval(s.appLockRelockIntervalSeconds)
        let incoming = Set(s.lockedAppBundleIDs)
        if lockedBundleIDs != incoming {
            lockedBundleIDs = incoming
        }
        if !isEnabled && activeChallengeBundleID != nil {
            dismissShieldOverlay()
        }
    }

    private func handleDidActivateApplication(_ app: NSRunningApplication) {
        guard let bundleID = app.bundleIdentifier,
              shouldBlockActivation(bundleID: bundleID, now: Date()) else {
            return
        }

        let appName = app.localizedName ?? bundleID
        pendingTargetApp = app
        activeChallengeBundleID = bundleID
        activeChallengeAppName = appName
        authErrorMessage = nil

        // 先隐藏目标应用窗口，再铺满全屏磨砂遮罩，杜绝敏感内容一闪而过
        _ = app.hide()
        presentShieldOverlay()

        stateMachine.submit(
            IslandActivityItem(
                id: hudActivityID,
                category: .appLock,
                title: "「\(appName)」已受隐私锁保护",
                subtitle: "请验证 Touch ID 指纹或系统密码解锁",
                iconSymbol: "lock.shield.fill",
                priority: .critical,
                isAlertHUD: true,
                autoDismissAfter: 6.0
            )
        )

        triggerBiometricAuthentication()
    }

    public func triggerBiometricAuthentication() {
        guard !isAuthenticating, let bundleID = activeChallengeBundleID else { return }
        isAuthenticating = true
        authErrorMessage = nil

        let appName = activeChallengeAppName
        let context = LAContext()
        context.localizedCancelTitle = "暂不打开"
        context.localizedFallbackTitle = "输入系统密码"

        var policyError: NSError?
        let policy: LAPolicy = .deviceOwnerAuthentication
        guard context.canEvaluatePolicy(policy, error: &policyError) else {
            isAuthenticating = false
            authErrorMessage = policyError?.localizedDescription ?? "当前设备无法发起系统身份验证"
            return
        }

        let reason = "解锁受星岛保护的应用「\(appName)」"
        context.evaluatePolicy(policy, localizedReason: reason) { [weak self] success, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isAuthenticating = false
                if success {
                    self.recordUnlock(bundleID: bundleID, now: Date())
                    let target = self.pendingTargetApp
                    self.dismissShieldOverlay()
                    self.stateMachine.submit(
                        IslandActivityItem(
                            id: self.hudActivityID,
                            category: .appLock,
                            title: "已解锁「\(appName)」",
                            subtitle: "身份验证通过",
                            iconSymbol: "lock.open.fill",
                            priority: .urgent,
                            isAlertHUD: true,
                            autoDismissAfter: 1.6
                        )
                    )
                    target?.unhide()
                    _ = target?.activate()
                } else if let laError = error as? LAError, laError.code == .userCancel {
                    self.cancelChallengeAndReturnToDesktop()
                } else {
                    self.authErrorMessage = error?.localizedDescription ?? "验证未通过，请重试"
                }
            }
        }
    }

    public func cancelChallengeAndReturnToDesktop() {
        dismissShieldOverlay()
        stateMachine.dismiss(id: hudActivityID)
        if let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first {
            _ = finder.activate()
        }
    }

    private func presentShieldOverlay() {
        dismissShieldPanelsOnly()
        for screen in NSScreen.screens {
            let panel = NSPanel(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            panel.level = .screenSaver
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.contentView = NSHostingView(rootView: AppLockShieldView(service: self))
            panel.setFrame(screen.frame, display: true)
            panel.makeKeyAndOrderFront(nil)
            shieldPanels.append(panel)
        }
        NSApp.activate()
    }

    private func dismissShieldOverlay() {
        dismissShieldPanelsOnly()
        activeChallengeBundleID = nil
        activeChallengeAppName = ""
        authErrorMessage = nil
        pendingTargetApp = nil
    }

    private func dismissShieldPanelsOnly() {
        for panel in shieldPanels {
            panel.orderOut(nil)
        }
        shieldPanels.removeAll()
    }
}

private struct AppLockShieldView: View {
    @ObservedObject var service: AppLockService

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "touchid")
                    .font(.system(size: 54, weight: .light))
                    .foregroundStyle(.cyan)

                Text("「\(service.activeChallengeAppName)」已加锁")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)

                Text("此应用受星岛生物识别隐私锁保护，请验证 Touch ID 指纹或系统登录密码以继续访问。")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)

                if let errorMsg = service.authErrorMessage {
                    Text(errorMsg)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.orange)
                }

                HStack(spacing: 14) {
                    Button("返回桌面") {
                        service.cancelChallengeAndReturnToDesktop()
                    }
                    .buttonStyle(.bordered)

                    Button {
                        service.triggerBiometricAuthentication()
                    } label: {
                        Label(service.isAuthenticating ? "正在验证…" : "使用 Touch ID 解锁", systemImage: "lock.open.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(service.isAuthenticating)
                }
                .padding(.top, 6)
            }
            .padding(36)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
        }
    }
}
