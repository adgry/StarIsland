import AppKit
import Foundation
import XCTest
@testable import AIConnectKit
import IslandCore

final class AIConnectKitTests: XCTestCase {

    // MARK: - 1. AIRequestBuilder: Gemini / OpenAI 兼容 / Ollama 请求与响应单测

    func testGeminiRequestBuilderIncludesHeadersTextAndInlineBase64Image() throws {
        let fakePNG = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let expectedBase64 = fakePNG.base64EncodedString()

        let history = [
            AIChatMessage(role: .user, content: "你好"),
            AIChatMessage(role: .assistant, content: "你好！请问有什么可以帮你？")
        ]

        let request = try AIRequestBuilder.buildGeminiRequest(
            model: "gemini-2.5-flash",
            apiKey: "gm-test-secret-123",
            prompt: "请识别这张截图里的报错",
            imagePNGData: fakePNG,
            history: history,
            systemInstruction: "你是星岛 macOS 助手"
        )

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(
            request.url?.absoluteString,
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
        )
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-goog-api-key"), "gm-test-secret-123")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let bodyData = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])

        let sysInst = try XCTUnwrap(json["systemInstruction"] as? [String: Any])
        let sysParts = try XCTUnwrap(sysInst["parts"] as? [[String: Any]])
        XCTAssertEqual(sysParts.first?["text"] as? String, "你是星岛 macOS 助手")

        let contents = try XCTUnwrap(json["contents"] as? [[String: Any]])
        XCTAssertEqual(contents.count, 3)
        XCTAssertEqual(contents[0]["role"] as? String, "user")
        XCTAssertEqual(contents[1]["role"] as? String, "model")
        XCTAssertEqual(contents[2]["role"] as? String, "user")

        let lastParts = try XCTUnwrap(contents[2]["parts"] as? [[String: Any]])
        XCTAssertEqual(lastParts.count, 2)
        XCTAssertEqual(lastParts[0]["text"] as? String, "请识别这张截图里的报错")

        let inlineData = try XCTUnwrap(lastParts[1]["inlineData"] as? [String: Any])
        XCTAssertEqual(inlineData["mimeType"] as? String, "image/png")
        XCTAssertEqual(inlineData["data"] as? String, expectedBase64)

        let responseJSON = """
        {
          "candidates": [
            {
              "content": {
                "role": "model",
                "parts": [
                  { "text": "这是一条空指针异常提示。" }
                ]
              }
            }
          ]
        }
        """.data(using: .utf8)!
        let parsed = try AIRequestBuilder.parseGeminiResponse(responseJSON)
        XCTAssertEqual(parsed, "这是一条空指针异常提示。")
    }

    func testOpenAICompatibleRequestBuilderFormatsBearerAndImageDataURI() throws {
        let fakePNG = Data([0x01, 0x02, 0x03, 0x04])
        let expectedURI = "data:image/png;base64,\(fakePNG.base64EncodedString())"

        let request = try AIRequestBuilder.buildOpenAIRequest(
            baseURL: "https://api.deepseek.com/v1/",
            apiKey: "sk-open-test-999",
            model: "gpt-4o-mini",
            prompt: "总结图中内容",
            imagePNGData: fakePNG,
            history: [AIChatMessage(role: .user, content: "上文")],
            systemInstruction: "请用简体中文回答"
        )

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "https://api.deepseek.com/v1/chat/completions")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer sk-open-test-999")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let bodyData = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, "gpt-4o-mini")
        XCTAssertEqual(json["stream"] as? Bool, false)

        let messages = try XCTUnwrap(json["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.count, 3)
        XCTAssertEqual(messages[0]["role"] as? String, "system")
        XCTAssertEqual(messages[1]["role"] as? String, "user")
        XCTAssertEqual(messages[2]["role"] as? String, "user")

        let contentItems = try XCTUnwrap(messages[2]["content"] as? [[String: Any]])
        XCTAssertEqual(contentItems.count, 2)
        XCTAssertEqual(contentItems[0]["type"] as? String, "text")
        XCTAssertEqual(contentItems[0]["text"] as? String, "总结图中内容")
        XCTAssertEqual(contentItems[1]["type"] as? String, "image_url")
        let imageURLObj = try XCTUnwrap(contentItems[1]["image_url"] as? [String: Any])
        XCTAssertEqual(imageURLObj["url"] as? String, expectedURI)

        let responseJSON = """
        {
          "choices": [
            {
              "index": 0,
              "message": {
                "role": "assistant",
                "content": "图中展示了系统架构拓扑。"
              }
            }
          ]
        }
        """.data(using: .utf8)!
        let parsed = try AIRequestBuilder.parseOpenAIResponse(responseJSON)
        XCTAssertEqual(parsed, "图中展示了系统架构拓扑。")
    }

    func testOllamaRequestBuilderBuildsLocalChatEndpointAndExtractsReply() throws {
        let fakePNG = Data([0xAA, 0xBB, 0xCC])
        let request = try AIRequestBuilder.buildOllamaRequest(
            baseURL: "http://127.0.0.1:11434/",
            model: "qwen2.5:7b",
            prompt: "翻译为英文：星岛灵动岛",
            imagePNGData: fakePNG
        )

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "http://127.0.0.1:11434/api/chat")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let bodyData = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, "qwen2.5:7b")
        XCTAssertEqual(json["stream"] as? Bool, false)

        let messages = try XCTUnwrap(json["messages"] as? [[String: Any]])
        let last = try XCTUnwrap(messages.last)
        XCTAssertEqual(last["role"] as? String, "user")
        XCTAssertEqual(last["content"] as? String, "翻译为英文：星岛灵动岛")
        XCTAssertEqual(last["images"] as? [String], [fakePNG.base64EncodedString()])

        let responseJSON = """
        {
          "model": "qwen2.5:7b",
          "message": {
            "role": "assistant",
            "content": "StarIsland Dynamic Island"
          },
          "done": true
        }
        """.data(using: .utf8)!
        let parsed = try AIRequestBuilder.parseOllamaResponse(responseJSON)
        XCTAssertEqual(parsed, "StarIsland Dynamic Island")
    }

    // MARK: - 2. KeychainVault: Security.framework 密钥安全存取更新删除单测

    func testKeychainVaultSaveUpdateReadAndDelete() throws {
        let testService = "com.adgry.starisland.ai-keys.tests.\(UUID().uuidString)"
        let vault = KeychainVault(service: testService)
        defer {
            try? vault.deleteAPIKey(for: .gemini)
            try? vault.deleteAPIKey(for: .openAICompatible)
        }

        XCTAssertEqual(KeychainVault.serviceName, "com.adgry.starisland.ai-keys")
        XCTAssertNil(vault.readAPIKey(for: .gemini))
        XCTAssertFalse(vault.hasAPIKey(for: .gemini))

        try vault.saveAPIKey("gm-first-key", for: .gemini)
        XCTAssertEqual(vault.readAPIKey(for: .gemini), "gm-first-key")
        XCTAssertTrue(vault.hasAPIKey(for: .gemini))

        // 更新覆盖旧密钥
        try vault.saveAPIKey("gm-updated-key", for: .gemini)
        XCTAssertEqual(vault.readAPIKey(for: .gemini), "gm-updated-key")

        // 删除后不可读
        try vault.deleteAPIKey(for: .gemini)
        XCTAssertNil(vault.readAPIKey(for: .gemini))
        XCTAssertFalse(vault.hasAPIKey(for: .gemini))
    }

    // MARK: - 3. PairingTokenManager: 6 位数字配对码与会话失效安全单测 (Review Focus #5)

    func testPairingTokenManagerGeneratesSixDigitPINIssuesTokenAndInvalidatesOnRefresh() {
        let manager = PairingTokenManager()
        let pin = manager.generateNewPIN()

        XCTAssertEqual(pin.count, 6)
        XCTAssertTrue(pin.allSatisfy(\.isNumber), "配对码必须为 6 位纯数字，实际为: \(pin)")

        // 错误配对码必须拒绝签发
        XCTAssertNil(manager.issueSessionToken(forPIN: "000000" == pin ? "999999" : "000000"))
        XCTAssertNil(manager.issueSessionToken(forPIN: ""))
        XCTAssertNil(manager.issueSessionToken(forPIN: "12ab56"))
        XCTAssertFalse(manager.isValidSession("forged-session-token"))
        XCTAssertFalse(manager.isValidSession(""))

        // 正确配对码签发非空会话令牌
        let sessionToken = manager.issueSessionToken(forPIN: pin)
        XCTAssertNotNil(sessionToken)
        if let sessionToken {
            XCTAssertFalse(sessionToken.isEmpty)
            XCTAssertTrue(manager.isValidSession(sessionToken))
        }

        // 刷新 PIN 后，旧会话必须全部立即失效
        let nextPIN = manager.generateNewPIN()
        XCTAssertEqual(nextPIN.count, 6)
        XCTAssertTrue(nextPIN.allSatisfy(\.isNumber))
        if let sessionToken {
            XCTAssertFalse(manager.isValidSession(sessionToken), "刷新 PIN 后旧会话令牌必须立即失效")
        }
    }

    // MARK: - 4. SafeFilenameSanitizer: 路径穿越防御单测 (Review Focus #5)

    func testSafeFilenameSanitizerStripsTraversalAndDangerousCharacters() {
        XCTAssertEqual(SafeFilenameSanitizer.sanitize("../../etc/passwd"), "passwd")
        XCTAssertEqual(SafeFilenameSanitizer.sanitize("/abs/path/evil.sh"), "evil.sh")
        XCTAssertEqual(SafeFilenameSanitizer.sanitize("..\\win\\a.txt"), "a.txt")
        XCTAssertEqual(SafeFilenameSanitizer.sanitize(""), "transfer.bin")
        XCTAssertEqual(SafeFilenameSanitizer.sanitize("   "), "transfer.bin")
        XCTAssertEqual(SafeFilenameSanitizer.sanitize("../.."), "transfer.bin")
        XCTAssertEqual(SafeFilenameSanitizer.sanitize("季度财报_2026.pdf"), "季度财报_2026.pdf")

        let maliciousInputs = [
            "../../etc/passwd",
            "/abs/path/evil.sh",
            "..\\win\\a.txt",
            "",
            "....//....//secret..key",
            "/var/root/.ssh/authorized_keys",
            "C:\\Windows\\System32\\cmd.exe"
        ]
        for raw in maliciousInputs {
            let safe = SafeFilenameSanitizer.sanitize(raw)
            XCTAssertFalse(safe.isEmpty, "净化结果不能为空: \(raw)")
            XCTAssertFalse(safe.contains("/"), "净化结果不得包含 /: \(safe)")
            XCTAssertFalse(safe.contains("\\"), "净化结果不得包含 \\: \(safe)")
            XCTAssertFalse(safe.contains(".."), "净化结果不得包含 ..: \(safe)")
        }
    }

    // MARK: - 5. QRCodeGenerator: CoreImage 二维码生成非空像素校验

    func testQRCodeGeneratorProducesNonEmptyBitmapImage() {
        let qrImage = QRCodeGenerator.makeImage(from: "http://192.168.1.88:48620/?pin=518204")
        XCTAssertNotNil(qrImage)
        if let qrImage {
            XCTAssertGreaterThan(qrImage.size.width, 0)
            XCTAssertGreaterThan(qrImage.size.height, 0)
            let cgImage = qrImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
            XCTAssertNotNil(cgImage)
            XCTAssertGreaterThan(cgImage?.width ?? 0, 0)
            XCTAssertGreaterThan(cgImage?.height ?? 0, 0)
        }
        XCTAssertNil(QRCodeGenerator.makeImage(from: ""))
    }

    // MARK: - 6. LANContinuityServer & AIAssistantCoordinator: 401 拦截、防越界上传、文件下载、媒体遥控与 AI 问答

    @MainActor
    func testLANServerRejectsUnauthorizedRequestsAndSanitizesUploadedFilePath() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("starisland-lan-test-\(UUID().uuidString)", isDirectory: true)
        let uploadDir = tempRoot.appendingPathComponent("Uploads", isDirectory: true)
        try FileManager.default.createDirectory(at: uploadDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let sharedSample = tempRoot.appendingPathComponent("演示文稿.pdf")
        let sampleData = Data("PDF-SAMPLE".utf8)
        try sampleData.write(to: sharedSample)

        let settingsURL = tempRoot.appendingPathComponent("settings.json")
        let store = SettingsStore(fileURL: settingsURL)
        let stateMachine = IslandStateMachine()
        let server = LANContinuityServer(
            settingsStore: store,
            stateMachine: stateMachine,
            uploadDirectoryURL: uploadDir
        )
        server.addSharedFiles([sharedSample])

        var receivedMediaCommands: [RemoteMediaCommand] = []
        server.onMediaCommand = { cmd in
            receivedMediaCommands.append(cmd)
        }

        // 首页中文控制台可正常加载
        let portalResp = server.handleHTTPRequest(LANHTTPRequest(method: "GET", path: "/"))
        XCTAssertEqual(portalResp.statusCode, 200)
        let portalHTML = String(data: portalResp.body, encoding: .utf8) ?? ""
        XCTAssertTrue(portalHTML.contains("星岛跨端互联"))

        // 未授权访问受保护 API 一律返回 401 Unauthorized
        for protectedPath in ["/api/files", "/api/clipboard", "/api/status"] {
            let unauth = server.handleHTTPRequest(LANHTTPRequest(method: "GET", path: protectedPath))
            XCTAssertEqual(unauth.statusCode, 401, "未授权请求 \(protectedPath) 必须返回 401")
        }

        let wrongBearerUpload = server.handleHTTPRequest(
            LANHTTPRequest(
                method: "POST",
                path: "/api/upload",
                headers: [
                    "Authorization": "Bearer invalid-token",
                    "X-File-Name": "note.txt"
                ],
                body: Data("hello".utf8)
            )
        )
        XCTAssertEqual(wrongBearerUpload.statusCode, 401)

        // 错误配对码请求 /api/pair 返回 401
        let badPIN = server.currentPIN == "123456" ? "654321" : "123456"
        let badPairBody = try JSONSerialization.data(withJSONObject: ["pin": badPIN])
        let badPairResp = server.handleHTTPRequest(
            LANHTTPRequest(method: "POST", path: "/api/pair", headers: ["Content-Type": "application/json"], body: badPairBody)
        )
        XCTAssertEqual(badPairResp.statusCode, 401)

        // 正确配对码换取 Bearer 会话令牌
        let okPairBody = try JSONSerialization.data(withJSONObject: ["pin": server.currentPIN, "deviceName": "iPhone 17 Pro"])
        let okPairResp = server.handleHTTPRequest(
            LANHTTPRequest(method: "POST", path: "/api/pair", headers: ["Content-Type": "application/json"], body: okPairBody)
        )
        XCTAssertEqual(okPairResp.statusCode, 200)
        let pairJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: okPairResp.body) as? [String: Any])
        let token = try XCTUnwrap(pairJSON["token"] as? String)
        let authHeaders = ["Authorization": "Bearer \(token)"]

        // 携带合法 Bearer 令牌但尝试路径穿越文件名上传，必须净化保存在 uploadDir 内部
        let payload = Data("safe-content-from-phone".utf8)
        let uploadResp = server.handleHTTPRequest(
            LANHTTPRequest(
                method: "POST",
                path: "/api/upload",
                headers: [
                    "Authorization": "Bearer \(token)",
                    "X-File-Name": "../../etc/passwd"
                ],
                body: payload
            )
        )
        XCTAssertEqual(uploadResp.statusCode, 200)

        let savedFile = uploadDir.appendingPathComponent("passwd")
        XCTAssertTrue(FileManager.default.fileExists(atPath: savedFile.path))
        XCTAssertEqual(try Data(contentsOf: savedFile), payload)
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempRoot.appendingPathComponent("passwd").path))

        // 查看并下载 Mac 共享文件
        let filesResp = server.handleHTTPRequest(
            LANHTTPRequest(method: "GET", path: "/api/files", headers: authHeaders)
        )
        XCTAssertEqual(filesResp.statusCode, 200)
        let filesJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: filesResp.body) as? [String: Any])
        let filesArray = try XCTUnwrap(filesJSON["files"] as? [[String: Any]])
        let firstSharedID = try XCTUnwrap(filesArray.first?["id"] as? String)

        let dlResp = server.handleHTTPRequest(
            LANHTTPRequest(method: "GET", path: "/api/files/\(firstSharedID)", headers: authHeaders)
        )
        XCTAssertEqual(dlResp.statusCode, 200)
        XCTAssertEqual(dlResp.body, sampleData)

        // 手机遥控媒体播放
        let mediaBody = try JSONSerialization.data(withJSONObject: ["command": "next"])
        let mediaResp = server.handleHTTPRequest(
            LANHTTPRequest(method: "POST", path: "/api/media", headers: authHeaders, body: mediaBody)
        )
        XCTAssertEqual(mediaResp.statusCode, 200)
        XCTAssertEqual(receivedMediaCommands, [.next])
    }

    @MainActor
    func testAIAssistantCoordinatorAskAndTranslateViaOllamaTransport() async throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("starisland-ai-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let store = SettingsStore(fileURL: tempRoot.appendingPathComponent("settings.json"))
        store.settings.activeAIProvider = AIProviderKind.ollama.rawValue
        store.settings.ollamaModel = "qwen2.5:7b"

        let stateMachine = IslandStateMachine()
        let coordinator = AIAssistantCoordinator(
            settingsStore: store,
            stateMachine: stateMachine,
            transport: { request in
                let responseBody = """
                {"message":{"role":"assistant","content":"已收到：\(request.url?.path ?? "")"}}
                """.data(using: .utf8)!
                let http = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: "HTTP/1.1",
                    headerFields: ["Content-Type": "application/json"]
                )!
                return (responseBody, http)
            }
        )

        let answer = try await coordinator.ask(prompt: "你好星岛", imagePNGData: nil)
        XCTAssertEqual(answer, "已收到：/api/chat")
        XCTAssertEqual(coordinator.messages.count, 2)

        let translated = try await coordinator.translate(text: "Dynamic Island", targetLanguage: "简体中文")
        XCTAssertEqual(translated, "已收到：/api/chat")
    }

    func testOneTimePINRotationAndBruteForceAutoReset() {
        let manager = PairingTokenManager()
        let firstPIN = manager.currentPIN
        guard let token = manager.issueSessionToken(forPIN: firstPIN, deviceName: "iPhone") else {
            return XCTFail("Expected valid session token on first use of PIN")
        }
        XCTAssertTrue(manager.isValidSession(token))

        // One-time PIN must immediately rotate after successful pairing while keeping issued session valid
        let secondPIN = manager.currentPIN
        XCTAssertNotEqual(secondPIN, firstPIN)
        XCTAssertNil(manager.issueSessionToken(forPIN: firstPIN, deviceName: "ReplayAttacker"))
        XCTAssertTrue(manager.isValidSession(token))

        // 5 consecutive wrong guesses must rotate currentPIN to defeat brute-force enumeration
        let wrongGuess = (secondPIN == "000000") ? "111111" : "000000"
        for _ in 0..<5 {
            XCTAssertNil(manager.issueSessionToken(forPIN: wrongGuess))
        }
        XCTAssertNotEqual(manager.currentPIN, secondPIN)

        // RemoteMediaCommand must support lockScreen
        XCTAssertEqual(RemoteMediaCommand(rawValue: "lockScreen"), .lockScreen)
    }
}
