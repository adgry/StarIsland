//
//  SubscriptionCore.swift
//  Sapphire
//

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
    public static let ultra = SubscriptionEntitlements(
        tier: .ultra,
        features: Set(AppFeature.allCases),
        expiresAt: nil
    )
}

public enum SubscriptionFeatureCatalog {
    public static func features(for tier: SubscriptionTier) -> Set<AppFeature> {
        Set(AppFeature.allCases)
    }

    public static func minimumTier(for feature: AppFeature) -> SubscriptionTier {
        .free
    }

    public static func tierDisplayName(_ tier: SubscriptionTier) -> String {
        switch tier {
        case .free: return "免费版"
        case .basic: return "基础版"
        case .pro: return "专业版"
        case .ultra: return "旗舰版"
        case .core: return "核心版"
        }
    }

    public static func marketingSubtitle(for tier: SubscriptionTier) -> String {
        "星岛旗舰版已永久解锁全部 46 项高级特性，无任何内购或订阅限制。"
    }

    public static func marketingTierHighlights() -> [(tier: SubscriptionTier, features: [String])] {
        [
            (tier: .ultra, features: [
                "全部灵动岛小组件、实时活动与视觉形变引擎",
                "体育实时比分、全球财经行情与多模型 AI 助手",
                "跨端局域网双向快传、Touch ID 应用锁与系统增强套件"
            ])
        ]
    }
}

public enum SubscriptionAccess {
    public static func hasAccess(to feature: AppFeature) -> Bool { true }
    public static func resolvedTier() -> SubscriptionTier { .ultra }
    public static func intelligenceDailyRunLimit() -> Int { Int.max }
}

public final class SubscriptionManager: ObservableObject {
    public static let shared = SubscriptionManager()

    public var tierGradientColors: [Color] {
        [Color(red: 0.30, green: 0.56, blue: 1.00), Color(red: 0.62, green: 0.36, blue: 0.98)]
    }
    public var userInitials: String { "星" }
    public var tierLabel: String { "全功能永久解锁" }

    @Published public private(set) var entitlements: SubscriptionEntitlements = .ultra
    @Published public private(set) var accessibleFeatures: Set<AppFeature> = Set(AppFeature.allCases)

    public init() {}

    public var activeTier: SubscriptionTier { .ultra }
    public var hasCorePlan: Bool { true }
    public var isSignedIn: Bool { true }
    public var userDisplayName: String { "星岛旗舰版" }
    public var hasBetaSoftwareAccess: Bool { true }

    public func hasAccess(to feature: AppFeature) -> Bool { true }
    public func isFeatureEnabled(_ feature: AppFeature) -> Bool { true }
    public func applyLicensedTier(_ tier: SubscriptionTier) {
        entitlements = .ultra
        accessibleFeatures = Set(AppFeature.allCases)
    }
    public func intelligenceDailyRunLimit() -> Int { Int.max }
    public func bootstrap(onCachedAccessReady: (@MainActor () -> Void)? = nil) async {
        await onCachedAccessReady?()
    }
    public func validateSubscriptionStatus() async {}
}

public final class FeatureGate {
    public static let shared = FeatureGate()

    private init() {}

    @discardableResult
    public func require(_ feature: AppFeature, message: String) -> Bool {
        true
    }
}

extension Notification.Name {
    public static let subscriptionPaywallRequested = Notification.Name("subscriptionPaywallRequested")
    public static let sapphireOpenAccountPane = Notification.Name("sapphireOpenAccountPane")
    public static let subscriptionSessionRevoked = Notification.Name("subscriptionSessionRevoked")
    public static let subscriptionEntitlementsDidChange = Notification.Name("subscriptionEntitlementsDidChange")
}
#endif
