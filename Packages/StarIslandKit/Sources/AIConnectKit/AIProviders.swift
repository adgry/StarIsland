import Foundation

public enum AIProviderKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case gemini
    case openAICompatible
    case ollama

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .gemini:
            return "Google Gemini"
        case .openAICompatible:
            return "OpenAI 兼容接口"
        case .ollama:
            return "本地 Ollama"
        }
    }

    public var subtitle: String {
        switch self {
        case .gemini:
            return "支持 Gemini 2.5 Flash/Pro 原生图文多模态极速推理"
        case .openAICompatible:
            return "兼容 OpenAI、DeepSeek、通义千问、硅基流动等标准端点"
        case .ollama:
            return "连接本机 127.0.0.1:11434，零云端成本离线问答与翻译"
        }
    }

    public var iconSymbol: String {
        switch self {
        case .gemini:
            return "sparkles"
        case .openAICompatible:
            return "network"
        case .ollama:
            return "desktopcomputer"
        }
    }

    public var requiresAPIKey: Bool {
        switch self {
        case .gemini, .openAICompatible:
            return true
        case .ollama:
            return false
        }
    }
}

public enum AIChatRole: String, Codable, Equatable, Sendable {
    case system
    case user
    case assistant
}

public struct AIChatMessage: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var role: AIChatRole
    public var content: String
    public var attachedImagePNGData: Data?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        role: AIChatRole,
        content: String,
        attachedImagePNGData: Data? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.attachedImagePNGData = attachedImagePNGData
        self.createdAt = createdAt
    }
}

public enum AIProviderError: LocalizedError, Equatable, Sendable {
    case missingAPIKey(AIProviderKind)
    case invalidEndpoint(String)
    case emptyPrompt
    case httpError(statusCode: Int, message: String)
    case malformedResponse(String)
    case emptyModelReply

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            return "尚未配置 \(provider.displayName) 的 API 密钥，请在「设置 -> AI 助手与手机互联」中录入。"
        case .invalidEndpoint(let raw):
            return "无效的服务接口地址：\(raw)"
        case .emptyPrompt:
            return "请输入提问内容或附带需要识别的图片。"
        case .httpError(let statusCode, let message):
            return "AI 服务请求失败（HTTP \(statusCode)）：\(message)"
        case .malformedResponse(let detail):
            return "无法解析 AI 服务响应：\(detail)"
        case .emptyModelReply:
            return "AI 模型返回了空内容，请稍后重试或切换模型。"
        }
    }
}

public typealias AITransportHandler = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

public enum AIRequestBuilder {
    public static let defaultSystemInstruction = "你是「星岛 StarIsland」内置的原生 macOS 灵动岛智能助手。请默认使用清晰、地道、简洁的简体中文回答问题。"

    // MARK: - Google Gemini (generateContent)

    public static func buildGeminiRequest(
        model: String,
        apiKey: String,
        prompt: String,
        imagePNGData: Data? = nil,
        history: [AIChatMessage] = [],
        systemInstruction: String? = nil,
        timeout: TimeInterval = 30
    ) throws -> URLRequest {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw AIProviderError.missingAPIKey(.gemini)
        }

        let modelName = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedModel = modelName.isEmpty ? "gemini-2.5-flash" : modelName
        guard let encodedModel = resolvedModel.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(encodedModel):generateContent") else {
            throw AIProviderError.invalidEndpoint(resolvedModel)
        }

        var contents: [[String: Any]] = []
        for item in history where item.role != .system {
            var parts: [[String: Any]] = []
            if !item.content.isEmpty {
                parts.append(["text": item.content])
            }
            if let img = item.attachedImagePNGData {
                parts.append([
                    "inlineData": [
                        "mimeType": "image/png",
                        "data": img.base64EncodedString()
                    ]
                ])
            }
            guard !parts.isEmpty else { continue }
            contents.append([
                "role": item.role == .assistant ? "model" : "user",
                "parts": parts
            ])
        }

        var currentParts: [[String: Any]] = []
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPrompt.isEmpty {
            currentParts.append(["text": trimmedPrompt])
        } else if imagePNGData != nil {
            currentParts.append(["text": "请详细识别并解析这张图片中的内容。"])
        }
        if let imagePNGData {
            currentParts.append([
                "inlineData": [
                    "mimeType": "image/png",
                    "data": imagePNGData.base64EncodedString()
                ]
            ])
        }
        guard !currentParts.isEmpty else {
            throw AIProviderError.emptyPrompt
        }

        contents.append([
            "role": "user",
            "parts": currentParts
        ])

        var payload: [String: Any] = [
            "contents": contents,
            "generationConfig": [
                "temperature": 0.4
            ]
        ]

        if let systemInstruction, !systemInstruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            payload["systemInstruction"] = [
                "parts": [
                    ["text": systemInstruction]
                ]
            ]
        }

        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(trimmedKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        return request
    }

    public static func parseGeminiResponse(_ data: Data) throws -> String {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIProviderError.malformedResponse("响应不是有效 JSON 对象")
        }
        if let errorDict = root["error"] as? [String: Any],
           let message = errorDict["message"] as? String {
            let code = (errorDict["code"] as? Int) ?? 400
            throw AIProviderError.httpError(statusCode: code, message: message)
        }
        guard let candidates = root["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            throw AIProviderError.malformedResponse("缺少 candidates.content.parts 字段")
        }
        let combined = parts.compactMap { $0["text"] as? String }.joined()
        let trimmed = combined.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AIProviderError.emptyModelReply
        }
        return trimmed
    }

    // MARK: - OpenAI 兼容接口 (/chat/completions)

    public static func buildOpenAIRequest(
        baseURL: String,
        apiKey: String,
        model: String,
        prompt: String,
        imagePNGData: Data? = nil,
        history: [AIChatMessage] = [],
        systemInstruction: String? = nil,
        timeout: TimeInterval = 30
    ) throws -> URLRequest {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw AIProviderError.missingAPIKey(.openAICompatible)
        }

        let endpointURL = try resolveEndpoint(baseURL: baseURL, defaultPathSuffix: "/chat/completions")
        let resolvedModel = model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "gpt-4o-mini"
            : model.trimmingCharacters(in: .whitespacesAndNewlines)

        var messages: [[String: Any]] = []
        if let systemInstruction, !systemInstruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messages.append([
                "role": "system",
                "content": systemInstruction
            ])
        }

        for item in history where item.role != .system {
            if let img = item.attachedImagePNGData {
                let dataURI = "data:image/png;base64,\(img.base64EncodedString())"
                messages.append([
                    "role": item.role.rawValue,
                    "content": [
                        ["type": "text", "text": item.content],
                        ["type": "image_url", "image_url": ["url": dataURI]]
                    ]
                ])
            } else {
                messages.append([
                    "role": item.role.rawValue,
                    "content": item.content
                ])
            }
        }

        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectivePrompt = trimmedPrompt.isEmpty && imagePNGData != nil
            ? "请详细识别并解析这张图片中的内容。"
            : trimmedPrompt
        guard !effectivePrompt.isEmpty else {
            throw AIProviderError.emptyPrompt
        }

        if let imagePNGData {
            let dataURI = "data:image/png;base64,\(imagePNGData.base64EncodedString())"
            messages.append([
                "role": "user",
                "content": [
                    ["type": "text", "text": effectivePrompt],
                    ["type": "image_url", "image_url": ["url": dataURI]]
                ]
            ])
        } else {
            messages.append([
                "role": "user",
                "content": effectivePrompt
            ])
        }

        let payload: [String: Any] = [
            "model": resolvedModel,
            "stream": false,
            "messages": messages
        ]

        var request = URLRequest(url: endpointURL, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        return request
    }

    public static func parseOpenAIResponse(_ data: Data) throws -> String {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIProviderError.malformedResponse("响应不是有效 JSON 对象")
        }
        if let err = root["error"] as? [String: Any],
           let msg = err["message"] as? String {
            throw AIProviderError.httpError(statusCode: 400, message: msg)
        }
        guard let choices = root["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any] else {
            throw AIProviderError.malformedResponse("缺少 choices[0].message 字段")
        }

        let rawText: String
        if let contentString = message["content"] as? String {
            rawText = contentString
        } else if let contentParts = message["content"] as? [[String: Any]] {
            rawText = contentParts.compactMap { $0["text"] as? String }.joined()
        } else {
            throw AIProviderError.malformedResponse("choices[0].message.content 格式不支持")
        }

        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AIProviderError.emptyModelReply
        }
        return trimmed
    }

    // MARK: - 本地 Ollama (/api/chat)

    public static func buildOllamaRequest(
        baseURL: String,
        model: String,
        prompt: String,
        imagePNGData: Data? = nil,
        history: [AIChatMessage] = [],
        systemInstruction: String? = nil,
        timeout: TimeInterval = 45
    ) throws -> URLRequest {
        let endpointURL = try resolveEndpoint(baseURL: baseURL, defaultPathSuffix: "/api/chat")
        let resolvedModel = model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "qwen2.5:7b"
            : model.trimmingCharacters(in: .whitespacesAndNewlines)

        var messages: [[String: Any]] = []
        if let systemInstruction, !systemInstruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messages.append([
                "role": "system",
                "content": systemInstruction
            ])
        }

        for item in history where item.role != .system {
            var entry: [String: Any] = [
                "role": item.role.rawValue,
                "content": item.content
            ]
            if let img = item.attachedImagePNGData {
                entry["images"] = [img.base64EncodedString()]
            }
            messages.append(entry)
        }

        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectivePrompt = trimmedPrompt.isEmpty && imagePNGData != nil
            ? "请详细识别并解析这张图片中的内容。"
            : trimmedPrompt
        guard !effectivePrompt.isEmpty else {
            throw AIProviderError.emptyPrompt
        }

        var userEntry: [String: Any] = [
            "role": "user",
            "content": effectivePrompt
        ]
        if let imagePNGData {
            userEntry["images"] = [imagePNGData.base64EncodedString()]
        }
        messages.append(userEntry)

        let payload: [String: Any] = [
            "model": resolvedModel,
            "stream": false,
            "messages": messages
        ]

        var request = URLRequest(url: endpointURL, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        return request
    }

    public static func parseOllamaResponse(_ data: Data) throws -> String {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIProviderError.malformedResponse("响应不是有效 JSON 对象")
        }
        if let errorMsg = root["error"] as? String {
            throw AIProviderError.httpError(statusCode: 400, message: errorMsg)
        }
        let rawText: String
        if let message = root["message"] as? [String: Any],
           let content = message["content"] as? String {
            rawText = content
        } else if let directResponse = root["response"] as? String {
            rawText = directResponse
        } else {
            throw AIProviderError.malformedResponse("缺少 message.content 字段")
        }

        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AIProviderError.emptyModelReply
        }
        return trimmed
    }

    // MARK: - 端点规范化辅助

    private static func resolveEndpoint(baseURL: String, defaultPathSuffix: String) throws -> URL {
        var cleaned = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while cleaned.hasSuffix("/") {
            cleaned.removeLast()
        }
        guard !cleaned.isEmpty else {
            throw AIProviderError.invalidEndpoint(baseURL)
        }
        let fullString = cleaned.hasSuffix(defaultPathSuffix) ? cleaned : (cleaned + defaultPathSuffix)
        guard let url = URL(string: fullString),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil else {
            throw AIProviderError.invalidEndpoint(baseURL)
        }
        return url
    }
}
