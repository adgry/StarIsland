//
//  PremiumFeatureKit.swift
//  Sapphire
//

#if !SAPPHIRE_FULL_BUILD
import Combine
import SwiftUI

enum PremiumGate {
    static func hasAccess(_ feature: AppFeature) -> Bool { true }

    static func isActive(_ feature: AppFeature?, enabled: Bool) -> Bool {
        enabled
    }

    static var accessChanges: AnyPublisher<Void, Never> {
        NotificationCenter.default.publisher(for: .subscriptionEntitlementsDidChange)
            .map { _ in () }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    @discardableResult
    static func require(_ feature: AppFeature, message: String? = nil) -> Bool {
        true
    }
}

struct PremiumFeatureView<Content: View>: View {
    let feature: AppFeature
    let content: Content

    init(feature: AppFeature, message: String? = nil, @ViewBuilder content: () -> Content) {
        self.feature = feature
        self.content = content()
    }

    var body: some View {
        content
    }
}

extension View {
    func premiumFeature(_ feature: AppFeature, message: String? = nil) -> some View {
        self
    }
}

func premiumDefaultMessage(for feature: AppFeature) -> String {
    "星岛旗舰版已解锁此功能。"
}

extension SettingsModel {
    func premiumChanges(_ feature: AppFeature, _ enabled: @escaping (Settings) -> Bool) -> AnyPublisher<Bool, Never> {
        $settings
            .map(enabled)
            .removeDuplicates()
            .dropFirst()
            .eraseToAnyPublisher()
    }

    func isPremiumActive(_ feature: AppFeature, _ enabled: (Settings) -> Bool) -> Bool {
        enabled(settings)
    }
}

extension WidgetType {
    var requiredPremiumFeature: AppFeature? {
        switch self {
        case .sports: .sportsWidget
        case .finance: .financeWidget
        case .battery: .batteryWidget
        case .storage: .storageWidgets
        default: nil
        }
    }

    var isPremiumLocked: Bool { false }
}

extension LiveActivityType {
    var requiredPremiumFeature: AppFeature? {
        switch self {
        case .sports: .liveSports
        case .finance: .financeLiveActivity
        default: nil
        }
    }

    var isPremiumLocked: Bool { false }
}
#endif
