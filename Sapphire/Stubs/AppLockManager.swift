//
//  AppLockManager.swift
//  Sapphire
//

#if !SAPPHIRE_FULL_BUILD
import AppKit
import Combine
import CryptoKit
import Foundation
import LocalAuthentication
import SwiftUI

@MainActor
final class AppLockManager: ObservableObject {
    static let shared = AppLockManager()

    @Published private(set) var isLocked = false
    @Published private(set) var isAuthenticating = false
    @Published private(set) var failedAttempts: [AppLockFailedAttempt] = []

    private static let passwordHashKey = "StarIsland.AppLock.PasswordHash"
    private static let passwordSaltKey = "StarIsland.AppLock.PasswordSalt"
    private static let failedAttemptsKey = "StarIsland.AppLock.FailedAttempts"

    private let blocker = AppBlocker()
    private var unlockedUntilByBundleID: [String: Date] = [:]
    private var sleepObserver: NSObjectProtocol?

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.failedAttemptsKey),
           let saved = try? JSONDecoder().decode([AppLockFailedAttempt].self, from: data) {
            failedAttempts = saved
        }
        configureBlocker()
        installSleepObserver()
        refresh()
    }

    private func configureBlocker() {
        blocker.shieldsAreKeyable = true
        blocker.shieldsOnlyWhenFrontmost = true
        blocker.isBlocked = { [weak self] bundleID in
            self?.shouldShield(bundleID: bundleID) ?? false
        }
        blocker.makeShieldContent = { [weak self] appName, bundleID in
            guard let self else { return AnyView(EmptyView()) }
            return AnyView(
                AppLockOverlayView(
                    appName: appName,
                    lockManager: self,
                    hasFaceID: false,
                    hasTouchID: SettingsModel.shared.settings.appLockTouchIDEnabled,
                    hasPassword: SettingsModel.shared.settings.appLockPasswordFallbackEnabled && self.hasPasswordFallback,
                    onFaceID: {},
                    onTouchID: {
                        Task { @MainActor in
                            _ = await self.authenticateAndUnlock(bundleID: bundleID, method: .touchID)
                        }
                    },
                    onSubmitPassword: { candidate in
                        self.verifyPassword(candidate, for: bundleID)
                    },
                    onQuit: {
                        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
                            running.hide()
                        }
                        self.blocker.unshield(bundleID: bundleID)
                    },
                    quitButtonTitle: "隐藏应用"
                )
            )
        }
        blocker.onAppActivated = { [weak self] _, bundleID, _ in
            guard let self, self.shouldShield(bundleID: bundleID), SettingsModel.shared.settings.appLockTouchIDEnabled else { return }
            Task { @MainActor in
                _ = await self.authenticateAndUnlock(bundleID: bundleID, method: .touchID)
            }
        }
    }

    private func installSleepObserver() {
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if SettingsModel.shared.settings.appLockLockOnSleep {
                    self.unlockedUntilByBundleID.removeAll()
                    self.refresh()
                }
            }
        }
    }

    func refresh() {
        let s = SettingsModel.shared.settings
        let active = s.appLockEnabled && !s.appLockProtectedApps.isEmpty
        isLocked = active
        blocker.setBlocking(active)
    }

    private func shouldShield(bundleID: String) -> Bool {
        let s = SettingsModel.shared.settings
        guard s.appLockEnabled, s.appLockProtectedApps.contains(bundleID) else { return false }
        if let expiry = unlockedUntilByBundleID[bundleID], expiry > Date() {
            return false
        }
        unlockedUntilByBundleID.removeValue(forKey: bundleID)
        return true
    }

    func authenticateAndUnlock() async -> Bool {
        await runBiometricAuth(reason: "验证身份以解锁受保护应用")
    }

    func authenticateAndUnlock(bundleID: String, method: AppLockAuthMethod = .auto) async -> Bool {
        guard !isAuthenticating else { return false }
        isAuthenticating = true
        defer { isAuthenticating = false }

        let appName = AppShieldManager.displayName(for: bundleID)
        let ok = await runBiometricAuth(reason: "验证身份以解锁「\(appName)」")
        if ok {
            markUnlocked(bundleID: bundleID)
            return true
        } else {
            recordFailedAttempt(bundleID: bundleID, method: "Touch ID")
            return false
        }
    }

    func authenticateSettingsAccess(method: AppLockAuthMethod = .auto) async -> Bool {
        await runBiometricAuth(reason: "验证身份以修改星岛应用隐私锁设置")
    }

    private func runBiometricAuth(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        let policy: LAPolicy = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
            ? .deviceOwnerAuthenticationWithBiometrics
            : .deviceOwnerAuthentication
        guard context.canEvaluatePolicy(policy, error: &error) else { return false }
        return await withCheckedContinuation { cont in
            context.evaluatePolicy(policy, localizedReason: reason) { success, _ in
                cont.resume(returning: success)
            }
        }
    }

    func setFallbackPassword(_ rawPassword: String) {
        let trimmed = rawPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let salt = UUID().uuidString
        let digest = Self.sha256Hex("\(salt):\(trimmed)")
        StarIslandKeychainVault.setString(salt, forAccount: "applock.salt", legacyDefaultsKey: Self.passwordSaltKey)
        StarIslandKeychainVault.setString(digest, forAccount: "applock.hash", legacyDefaultsKey: Self.passwordHashKey)
        objectWillChange.send()
    }

    func clearFallbackPassword() {
        StarIslandKeychainVault.setString("", forAccount: "applock.salt", legacyDefaultsKey: Self.passwordSaltKey)
        StarIslandKeychainVault.setString("", forAccount: "applock.hash", legacyDefaultsKey: Self.passwordHashKey)
        objectWillChange.send()
    }

    var hasPasswordFallback: Bool {
        let hash = StarIslandKeychainVault.string(forAccount: "applock.hash", legacyDefaultsKey: Self.passwordHashKey)
        let salt = StarIslandKeychainVault.string(forAccount: "applock.salt", legacyDefaultsKey: Self.passwordSaltKey)
        return !hash.isEmpty && !salt.isEmpty
    }

    func verifyPassword(_ password: String, for bundleID: String) -> Bool {
        let expected = StarIslandKeychainVault.string(forAccount: "applock.hash", legacyDefaultsKey: Self.passwordHashKey)
        let salt = StarIslandKeychainVault.string(forAccount: "applock.salt", legacyDefaultsKey: Self.passwordSaltKey)
        guard !expected.isEmpty, !salt.isEmpty else {
            return false
        }
        let candidate = Self.sha256Hex("\(salt):\(password.trimmingCharacters(in: .whitespacesAndNewlines))")
        if StarIslandPairingTokenManager.constantTimeEquals(candidate, expected) {
            markUnlocked(bundleID: bundleID)
            return true
        } else {
            recordFailedAttempt(bundleID: bundleID, method: "密码")
            return false
        }
    }

    private func markUnlocked(bundleID: String) {
        let s = SettingsModel.shared.settings
        let minutes = s.appLockAutoLockIdleEnabled ? max(1, s.appLockAutoLockIdleMinutes) : 15
        unlockedUntilByBundleID[bundleID] = Date().addingTimeInterval(Double(minutes * 60))
        blocker.unshield(bundleID: bundleID)
    }

    private func recordFailedAttempt(bundleID: String, method: String) {
        let entry = AppLockFailedAttempt(
            id: UUID(),
            bundleID: bundleID,
            appName: AppShieldManager.displayName(for: bundleID),
            timestamp: Date(),
            method: method
        )
        failedAttempts.insert(entry, at: 0)
        if failedAttempts.count > 30 { failedAttempts.removeLast(failedAttempts.count - 30) }
        if let data = try? JSONEncoder().encode(failedAttempts) {
            UserDefaults.standard.set(data, forKey: Self.failedAttemptsKey)
        }
    }

    func clearFailedAttempts() {
        failedAttempts.removeAll()
        UserDefaults.standard.removeObject(forKey: Self.failedAttemptsKey)
    }

    private static func sha256Hex(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

enum AppLockAuthMethod {
    case auto
    case faceID
    case touchID
}

struct AppLockFailedAttempt: Codable, Identifiable {
    let id: UUID
    let bundleID: String
    let appName: String
    let timestamp: Date
    let method: String
}
#endif
