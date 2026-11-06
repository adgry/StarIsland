//
//  PrivateViews.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2026-08-30

#if !SAPPHIRE_FULL_BUILD
import SwiftUI

private struct UnavailableFeatureView: View {
    let name: String

    var body: some View {
        Text("当前构建版本未包含「\(name)」功能。")
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SportsSettingsView: View {
    var body: some View { UnavailableFeatureView(name: "体育") }
}

struct FinanceSettingsView: View {
    var body: some View { UnavailableFeatureView(name: "财经") }
}

struct AccountSettingsView: View {
    var body: some View { UnavailableFeatureView(name: "账户管理") }
}

struct BetaBlockerView: View {
    var onValidationComplete: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("当前构建版本未包含测试版验证。")
                .foregroundColor(.secondary)
            Button("继续", action: onValidationComplete)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct NativePaymentSheetView: View {
    var tier: SubscriptionTier
    var deviceCount: Int
    var isAddingOnly: Bool
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("当前构建版本未包含购买功能。")
                .foregroundColor(.secondary)
            Button("关闭", action: onDismiss)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

enum SubscriptionRevocationReason: String {
    case sessionExpired

    var alertMessage: String { "登录会话已过期，请重新登录。" }
}

final class ScreenPerception {
    func captureAnnotatedScreen() async -> (NSImage?, [String]) { (nil, []) }
}
#endif