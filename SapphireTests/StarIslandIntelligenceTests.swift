import AppKit
import XCTest
@testable import Sapphire

final class StarIslandIntelligenceTests: XCTestCase {

    func testMultiProviderLLMRequestBuildingAndResponseParsing() throws {
        XCTAssertTrue(LLMBackend.ollama.isKeyConfigured, "本地 Ollama 无需云端密钥即可就绪")

        let geminiReq = try LLMBackend.buildChatRequest(
            prompt: "你好，星岛",
            backend: .gemini,
            apiKey: "AIzaSyTestKey1234567890",
            geminiSpeedMode: .fast
        )
        XCTAssertEqual(geminiReq.httpMethod, "POST")
        XCTAssertTrue(geminiReq.url?.absoluteString.contains("generativelanguage.googleapis.com") == true)

        let openAIReq = try LLMBackend.buildChatRequest(
            prompt: "总结剪贴板",
            backend: .openRouter,
            apiKey: "sk-or-test-123",
            geminiSpeedMode: .fast
        )
        XCTAssertEqual(openAIReq.value(forHTTPHeaderField: "Authorization"), "Bearer sk-or-test-123")

        let ollamaReq = try LLMBackend.buildChatRequest(
            prompt: "离线翻译",
            backend: .ollama,
            apiKey: "",
            geminiSpeedMode: .fast
        )
        XCTAssertTrue(ollamaReq.url?.absoluteString.contains("11434") == true)

        let geminiJSON = """
        {"candidates":[{"content":{"parts":[{"text":"你好！我是星岛灵动岛智能助手。"}]}}]}
        """.data(using: .utf8)!
        XCTAssertEqual(try LLMBackend.parseChatResponse(data: geminiJSON, backend: .gemini), "你好！我是星岛灵动岛智能助手。")

        let openAIJSON = """
        {"choices":[{"message":{"role":"assistant","content":"已完成总结：共 3 条重点。"}}]}
        """.data(using: .utf8)!
        XCTAssertEqual(try LLMBackend.parseChatResponse(data: openAIJSON, backend: .openRouter), "已完成总结：共 3 条重点。")

        let ollamaJSON = """
        {"message":{"role":"assistant","content":"本地离线推理成功"}}
        """.data(using: .utf8)!
        XCTAssertEqual(try LLMBackend.parseChatResponse(data: ollamaJSON, backend: .ollama), "本地离线推理成功")
    }

    func testVisionCircleToSearchRecognizesSynthesizedBilingualText() async throws {
        let width = 520
        let height = 140
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            XCTFail("无法创建测试位图上下文")
            return
        }

        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let nsGraphics = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsGraphics
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 42),
            .foregroundColor: NSColor.black
        ]
        ("StarIsland 2026" as NSString).draw(at: NSPoint(x: 32, y: 45), withAttributes: attrs)
        NSGraphicsContext.restoreGraphicsState()

        guard let cgImage = ctx.makeImage() else {
            XCTFail("无法导出 CGImage")
            return
        }

        let recognized = await CircleToSearchManager.shared.recognizeText(in: cgImage)
        XCTAssertTrue(
            recognized.localizedCaseInsensitiveContains("StarIsland") || recognized.contains("2026"),
            "Vision OCR 未识别出预期文本，实际输出: \(recognized)"
        )
    }
}
