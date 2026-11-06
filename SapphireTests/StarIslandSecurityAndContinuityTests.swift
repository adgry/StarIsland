import AppKit
import XCTest
@testable import Sapphire

final class StarIslandSecurityAndContinuityTests: XCTestCase {
    func testPairingTokenConstantTimeVerificationAndOneTimeRotation() {
        let manager = StarIslandPairingTokenManager(sessionTTL: 3600)
        let initialPIN = manager.currentPIN
        XCTAssertEqual(initialPIN.count, 6)

        XCTAssertNil(manager.issueSessionToken(forPIN: "wrong!", deviceName: "iPhone"))
        XCTAssertEqual(manager.currentPIN, initialPIN)

        guard let token = manager.issueSessionToken(forPIN: initialPIN, deviceName: "iPhone 17 Pro") else {
            return XCTFail("Expected valid 6-digit PIN to issue session token")
        }
        XCTAssertTrue(manager.isValidSession(token))
        XCTAssertNotEqual(manager.currentPIN, initialPIN, "PIN must rotate immediately after pairing")
        XCTAssertNil(manager.issueSessionToken(forPIN: initialPIN, deviceName: "Replay"), "Old PIN must not be reusable")
    }

    func testSafeFilenameSanitizerBlocksPathTraversal() {
        XCTAssertEqual(StarIslandSafeFilename.sanitize("../../etc/passwd"), "passwd")
        XCTAssertEqual(StarIslandSafeFilename.sanitize("..\\..\\Windows\\System32\\cmd.exe"), "cmd.exe")
        XCTAssertEqual(StarIslandSafeFilename.sanitize("..."), StarIslandSafeFilename.fallbackFilename)
        XCTAssertEqual(StarIslandSafeFilename.sanitize("简历 2026.pdf"), "简历 2026.pdf")
    }

    @MainActor
    func testLANPortalServerEndToEndAuthClipboardAndUpload() throws {
        let tempUploadDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempUploadDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempUploadDir) }

        let server = StarIslandLANPortalServer(uploadDirectoryURL: tempUploadDir)
        let homeResp = server.handleHTTPRequest(StarIslandHTTPRequest(method: "GET", path: "/"))
        XCTAssertEqual(homeResp.statusCode, 200)
        let html = String(data: homeResp.body, encoding: .utf8) ?? ""
        XCTAssertTrue(html.contains("星岛跨端互联"))

        let unauthResp = server.handleHTTPRequest(StarIslandHTTPRequest(method: "GET", path: "/api/files"))
        XCTAssertEqual(unauthResp.statusCode, 401)

        let pairPayload = try JSONSerialization.data(withJSONObject: ["pin": server.currentPIN, "deviceName": "测试手机"])
        let pairResp = server.handleHTTPRequest(StarIslandHTTPRequest(
            method: "POST",
            path: "/api/pair",
            headers: ["Content-Type": "application/json"],
            body: pairPayload
        ))
        XCTAssertEqual(pairResp.statusCode, 200)
        let pairJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: pairResp.body) as? [String: Any])
        let token = try XCTUnwrap(pairJSON["token"] as? String)

        let uploadResp = server.handleHTTPRequest(StarIslandHTTPRequest(
            method: "POST",
            path: "/api/upload",
            headers: [
                "Authorization": "Bearer \(token)",
                "X-File-Name": "../../secret_note.txt"
            ],
            body: Data("Hello StarIsland".utf8)
        ))
        XCTAssertEqual(uploadResp.statusCode, 200)
        let savedPath = tempUploadDir.appendingPathComponent("secret_note.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: savedPath.path))
    }

    @MainActor
    func testAppLockFallbackPasswordVerificationAndFailedAttemptTracking() {
        let lock = AppLockManager.shared
        lock.clearFailedAttempts()
        lock.setFallbackPassword("Star2026!")
        XCTAssertTrue(lock.hasPasswordFallback)

        XCTAssertFalse(lock.verifyPassword("WrongPass", for: "com.apple.Notes"))
        XCTAssertEqual(lock.failedAttempts.count, 1)

        XCTAssertTrue(lock.verifyPassword("Star2026!", for: "com.apple.Notes"))
        lock.clearFailedAttempts()
        XCTAssertTrue(lock.failedAttempts.isEmpty)
        lock.clearFallbackPassword()
    }
}
