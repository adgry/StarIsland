import XCTest
@testable import Sapphire

final class StarIslandUnlockAndOTPTests: XCTestCase {

    func testAll46FeaturesPermanentlyUnlockedWithoutPaywallNotification() {
        XCTAssertGreaterThanOrEqual(AppFeature.allCases.count, 46)
        for feature in AppFeature.allCases {
            XCTAssertTrue(SubscriptionAccess.hasAccess(to: feature), "未解锁特性: \(feature.rawValue)")
            XCTAssertTrue(SubscriptionManager.shared.hasAccess(to: feature))
            XCTAssertTrue(SubscriptionManager.shared.isFeatureEnabled(feature))
            XCTAssertTrue(PremiumGate.hasAccess(feature))
        }

        XCTAssertEqual(SubscriptionAccess.resolvedTier(), .ultra)
        XCTAssertEqual(SubscriptionManager.shared.activeTier, .ultra)
        XCTAssertTrue(SubscriptionManager.shared.isSignedIn)
        XCTAssertTrue(SubscriptionManager.shared.hasBetaSoftwareAccess)
        XCTAssertEqual(SubscriptionManager.shared.intelligenceDailyRunLimit(), Int.max)

        var paywallPosted = false
        let token = NotificationCenter.default.addObserver(
            forName: .subscriptionPaywallRequested,
            object: nil,
            queue: nil
        ) { _ in
            paywallPosted = true
        }
        defer { NotificationCenter.default.removeObserver(token) }

        XCTAssertTrue(FeatureGate.shared.require(.liveSports, message: "测试门控"))
        XCTAssertTrue(PremiumGate.require(.circleToSearch))
        XCTAssertFalse(paywallPosted, "全解锁版本严禁广播付费墙通知")

        for widget in WidgetType.allCases {
            XCTAssertFalse(widget.isPremiumLocked, "小组件不应被锁定: \(widget)")
        }
        for activity in LiveActivityType.allCases {
            XCTAssertFalse(activity.isPremiumLocked, "实时活动不应被锁定: \(activity)")
        }
    }

    func testTwoFactorVerificationCodeDetectorRejectsFalsePositivesAndExtractsRealOTPs() {
        // 用户真实截图误报复现：Discord/频道通知中的纯数字绝不能误判为验证码
        XCTAssertNil(VerificationCodeDetector.find(in: "yetone (#general, Text Channels) 3068"))
        XCTAssertNil(VerificationCodeDetector.find(in: "在 #dev-ops 频道提到了 PR 4096"))
        XCTAssertNil(VerificationCodeDetector.find(in: "会议定于 2026 年 14:30 在 3020 室举行，预算 ¥5000"))
        XCTAssertNil(VerificationCodeDetector.find(in: "Order #894210 shipped for $1299"))
        XCTAssertNil(VerificationCodeDetector.find(in: "验证码年份 2026 不应提取年份本身"))

        // 真实中英文验证码提取
        XCTAssertEqual(
            VerificationCodeDetector.find(in: "[阿里云] 您的验证码为 482910，5分钟内有效。"),
            "482910"
        )
        XCTAssertEqual(
            VerificationCodeDetector.find(in: "Your GitHub verification code is 739182."),
            "739182"
        )
        XCTAssertEqual(
            VerificationCodeDetector.find(in: "【美团】登录动态码：9048，请勿向他人泄露（2026年11月）"),
            "9048"
        )
        XCTAssertEqual(
            VerificationCodeDetector.find(in: "G-518204 is your Google authentication code."),
            "518204"
        )
    }

    func testSmartInboxMonitorSHA256PersistenceAndDeduplication() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("StarIslandOTPTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storeURL = tempDir.appendingPathComponent("consumed_otp_hashes.json")
        let monitor = SmartInboxMonitor(storageURL: storeURL)

        XCTAssertFalse(monitor.hasConsumedOTP("482910"))
        monitor.presentOTP(code: "482910", source: "信息", title: "阿里云", body: "验证码 482910")
        XCTAssertEqual(monitor.latestOTP?.code, "482910")

        monitor.consumeOTP("482910")
        XCTAssertTrue(monitor.hasConsumedOTP("482910"))

        let rawJSON = try String(contentsOf: storeURL, encoding: .utf8)
        XCTAssertFalse(rawJSON.contains("482910"), "落盘文件严禁明文保存验证码，必须使用 SHA-256 摘要")

        // 模拟冷启动重建实例：已消费验证码仍被拦截，不再重复弹窗
        let reloaded = SmartInboxMonitor(storageURL: storeURL)
        XCTAssertTrue(reloaded.hasConsumedOTP("482910"))
        reloaded.presentOTP(code: "482910", source: "信息", title: "阿里云", body: "验证码 482910")
        XCTAssertNil(reloaded.latestOTP)

        XCTAssertNotNil(ParcelCarrier.ups.trackingURL("1Z999AA10123456784"))
    }
}
