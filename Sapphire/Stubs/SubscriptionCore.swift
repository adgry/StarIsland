//
//  SubscriptionCore.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2026-08-30

#if !SAPPHIRE_FULL_BUILD
import Foundation
import Combine
import SwiftUI

public enum SubscriptionTier: String, Codable, CaseIterable {
    case free, basic, pro, ultra

    case core
}

public enum AppFeature: String, Codable, CaseIterable {
    case unlimitedLyricsFetch, translation, geminiLive, advancedFileConversion,
         priorityAutomation, betaSoftwareUpdates, circleToSearch, liveSports,
         financeWidget, sportsWidget, financeLiveActivity, prioritizedFeedback,
         appLock, focusProductiveAccess,
         menuBarProfiles, androidContinuitySyncMedia, androidContinuityWidgets,
         androidContinuityPhotoDisk, mediaTools, basicMouseSettings,
         dockPresets,
         continuityUniversalKeyboard, continuityEarbudHandoff,
         continuityHandoff, continuityDocumentScanning,
         continuityCameraAndMic, continuityMacTabsOnPhone,
         androidNotificationsOnMac, continuityCloudflareRelay, windowsPreview, dockPreview, allMouseSettings,
         surroundSound, snapZonesKeyboardShortcuts, emojiSuggestAsYouType,
         basicStorageFeatures, clipboardPicker, clipboardAdvancedTools, dmgInstaller,
         macScreenMirroringOnAndroid, macScreenExtensionOnMac, androidInstantHotspot,
         androidRemoteConnection, advancedStorageFeatures, batteryWidget, audio8D,
         storageWidgets, ocrFeature
}

public struct SubscriptionEntitlements: Codable, Equatable {
    public var tier: SubscriptionTier
    public var features: Set<AppFeature>
    public var expiresAt: Date?

    public static let free = SubscriptionEntitlements(tier: .free, features: [], expiresAt: nil)
}

public enum SubscriptionFeatureCatalog {
    public static func features(for tier: SubscriptionTier) -> Set<AppFeature> { [] }
    public static func minimumTier(for feature: AppFeature) -> SubscriptionTier { .free }
    public static func tierDisplayName(_ tier: SubscriptionTier) -> String {
        switch tier {
        case .free: return "免费版"
        case .basic: return "基础版"
        case .pro: return "Pro"
        case .ultra: return "Ultra"
        case .core: return "核心版"
        }
    }
    public static func marketingSubtitle(for tier: SubscriptionTier) -> String { "包含 Sapphire 核心灵动岛体验。" }
    public static func marketingTierHighlights() -> [(tier: SubscriptionTier, features: [String])] {
        [
            (tier: .free, features: ["核心灵动岛体验"]),
            (tier: .basic, features: ["无限制实时活动"]),
            (tier: .pro, features: ["全部小组件与自动化"]),
            (tier: .ultra, features: ["全部功能，外加测试版更新"])
        ]
    }
}

public enum SubscriptionAccess {
    public static func hasAccess(to feature: AppFeature) -> Bool { false }
    public static func resolvedTier() -> SubscriptionTier { .free }
    public static func intelligenceDailyRunLimit() -> Int { 8 }
}

public final class SubscriptionManager: ObservableObject {
    public static let shared = SubscriptionManager()

    public var tierGradientColors: [Color] { [.gray, .gray.opacity(0.6)] }
    public var userInitials: String { "访" }
    public var tierLabel: String { "免费版" }

    @Published public private(set) var entitlements: SubscriptionEntitlements = .free
    @Published public private(set) var accessibleFeatures: Set<AppFeature> = []

    public init() {}

    public var activeTier: SubscriptionTier { entitlements.tier }
    public var hasCorePlan: Bool { activeTier == .core }
    public var isSignedIn: Bool { false }
    public var userDisplayName: String { "访客" }
    public var hasBetaSoftwareAccess: Bool { false }

    public func hasAccess(to feature: AppFeature) -> Bool { SubscriptionAccess.hasAccess(to: feature) }
    public func isFeatureEnabled(_ feature: AppFeature) -> Bool { SubscriptionAccess.hasAccess(to: feature) }
    public func applyLicensedTier(_ tier: SubscriptionTier) {}
    public func intelligenceDailyRunLimit() -> Int { 8 }
    public func bootstrap(onCachedAccessReady: (@MainActor () -> Void)? = nil) async { await onCachedAccessReady?() }
    public func validateSubscriptionStatus() async {}
}

public final class FeatureGate {
    public static let shared = FeatureGate()

    private init() {}

    @discardableResult
    public func require(_ feature: AppFeature, message: String) -> Bool {
        let post = {
            NotificationCenter.default.post(
                name: .subscriptionPaywallRequested,
                object: nil,
                userInfo: ["message": message, "feature": feature.rawValue]
            )
        }
        if Thread.isMainThread { post() } else { DispatchQueue.main.async(execute: post) }
        return false
    }
}

extension Notification.Name {
    public static let subscriptionPaywallRequested = Notification.Name("subscriptionPaywallRequested")
    public static let sapphireOpenAccountPane = Notification.Name("sapphireOpenAccountPane")
    public static let subscriptionSessionRevoked = Notification.Name("subscriptionSessionRevoked")
    public static let subscriptionEntitlementsDidChange = Notification.Name("subscriptionEntitlementsDidChange")
}
#endif