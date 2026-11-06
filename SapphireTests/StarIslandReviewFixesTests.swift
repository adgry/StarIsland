import Foundation
import XCTest
@testable import Sapphire

final class StarIslandReviewFixesTests: XCTestCase {
    func testAnthropicBackendUsesAnthropicMessagesEndpointAndNeverOpenAI() throws {
        let req = try LLMBackend.buildChatRequest(
            prompt: "你好 Claude",
            backend: .anthropic,
            apiKey: "sk-ant-secret",
            geminiSpeedMode: .fast
        )
        XCTAssertEqual(req.url?.host, "api.anthropic.com")
        XCTAssertEqual(req.url?.path, "/v1/messages")
        XCTAssertEqual(req.value(forHTTPHeaderField: "x-api-key"), "sk-ant-secret")
        XCTAssertNil(req.value(forHTTPHeaderField: "Authorization"))
        XCTAssertNotNil(req.value(forHTTPHeaderField: "anthropic-version"))

        let sample = Data("""
        {"id":"msg_01","type":"message","content":[{"type":"text","text":"你好！我是 Claude。"}]}
        """.utf8)
        XCTAssertEqual(try LLMBackend.parseChatResponse(data: sample, backend: .anthropic), "你好！我是 Claude。")
    }

    @MainActor
    func testSmartInboxDismissOTPConsumesCodeImmediately() {
        let code = String(format: "%06d", Int.random(in: 100_000...999_999))
        SmartInboxMonitor.shared.presentOTP(code: code, source: "信息", title: "验证码", body: "您的验证码为 \(code)")
        XCTAssertEqual(SmartInboxMonitor.shared.latestOTP?.code, code)

        SmartInboxMonitor.shared.dismissOTP()
        XCTAssertNil(SmartInboxMonitor.shared.latestOTP)
        XCTAssertTrue(SmartInboxMonitor.shared.hasConsumedOTP(code))
    }

    func testLANPortalEarlyHeaderGateRejectsUnauthenticatedUploadAndOverflowLength() {
        let tokenMgr = StarIslandPairingTokenManager(sessionTTL: 600)
        let unauth = StarIslandLANPortalServer.earlyHeaderRejection(
            method: "POST",
            path: "/api/upload",
            headers: ["Content-Length": "52428800"],
            tokenManager: tokenMgr
        )
        XCTAssertEqual(unauth?.statusCode, 401)

        let validToken = tokenMgr.issueSessionToken(forPIN: tokenMgr.currentPIN, deviceName: "iPhone") ?? ""
        let allowed = StarIslandLANPortalServer.earlyHeaderRejection(
            method: "POST",
            path: "/api/upload",
            headers: ["Authorization": "Bearer \(validToken)", "Content-Length": "1024"],
            tokenManager: tokenMgr
        )
        XCTAssertNil(allowed)

        let overflow = StarIslandLANPortalServer.earlyHeaderRejection(
            method: "POST",
            path: "/api/upload",
            headers: ["Authorization": "Bearer \(validToken)", "Content-Length": "999999999999999999999"],
            tokenManager: tokenMgr
        )
        XCTAssertEqual(overflow?.statusCode, 413)
    }

    func testAIKeyStoreDoesNotPersistPlaintextInUserDefaults() {
        UserDefaults.standard.removeObject(forKey: "starisland.ai.deepseekKey")
        StarIslandAIKeyStore.deepseekAPIKey = "sk-deepseek-test-vault"
        XCTAssertEqual(StarIslandAIKeyStore.deepseekAPIKey, "sk-deepseek-test-vault")
        XCTAssertNil(UserDefaults.standard.string(forKey: "starisland.ai.deepseekKey"))
        StarIslandAIKeyStore.deepseekAPIKey = ""
    }
}
