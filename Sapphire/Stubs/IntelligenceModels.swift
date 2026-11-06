//
//  IntelligenceModels.swift
//  Sapphire
//

#if !SAPPHIRE_FULL_BUILD
import Foundation

enum StarIslandAIKeyStore {
    private static let defaults = UserDefaults.standard

    static var deepseekAPIKey: String {
        get { StarIslandKeychainVault.string(forAccount: "ai.deepseekKey", legacyDefaultsKey: "starisland.ai.deepseekKey") }
        set { StarIslandKeychainVault.setString(newValue, forAccount: "ai.deepseekKey", legacyDefaultsKey: "starisland.ai.deepseekKey") }
    }

    static var qwenAPIKey: String {
        get { StarIslandKeychainVault.string(forAccount: "ai.qwenKey", legacyDefaultsKey: "starisland.ai.qwenKey") }
        set { StarIslandKeychainVault.setString(newValue, forAccount: "ai.qwenKey", legacyDefaultsKey: "starisland.ai.qwenKey") }
    }

    static var ollamaEndpoint: String {
        get { defaults.string(forKey: "starisland.ai.ollamaEndpoint") ?? "http://127.0.0.1:11434" }
        set { defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "starisland.ai.ollamaEndpoint") }
    }

    static var ollamaModel: String {
        get { defaults.string(forKey: "starisland.ai.ollamaModel") ?? "qwen2.5:7b" }
        set { defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "starisland.ai.ollamaModel") }
    }
}

enum LLMBackendError: LocalizedError {
    case missingAPIKey(String)
    case invalidEndpoint
    case httpStatus(Int, String)
    case emptyReply

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let name): return "尚未配置 \(name) API 密钥，请在「智能助手」设置中填写或切换至本地 Ollama。"
        case .invalidEndpoint: return "AI 接口地址格式无效。"
        case .httpStatus(let code, let body): return "AI 接口返回 HTTP \(code)：\(body.prefix(140))"
        case .emptyReply: return "AI 模型未返回有效文本。"
        }
    }
}

enum LLMBackend: String, Codable, CaseIterable {
    case auto, gemini, openAI, anthropic, openRouter, xai, nvidia, hackclub, deepseek, qwen, ollama

    var displayName: String {
        switch self {
        case .auto: return "自动优选"
        case .gemini: return "Google Gemini"
        case .deepseek: return "DeepSeek 深度求索"
        case .qwen: return "通义千问 Qwen"
        case .openAI: return "OpenAI"
        case .openRouter: return "OpenRouter"
        case .anthropic: return "Anthropic Claude"
        case .xai: return "xAI Grok"
        case .nvidia: return "NVIDIA NIM"
        case .hackclub: return "Hack Club AI"
        case .ollama: return "本地 Ollama (免密钥)"
        }
    }

    var isKeyConfigured: Bool {
        switch self {
        case .ollama:
            return true
        case .auto:
            return true
        default:
            return !resolveAPIKey(fallbackGeminiKey: APIKeyManager.shared.geminiAPIKey).isEmpty
        }
    }

    func resolveAPIKey(fallbackGeminiKey: String) -> String {
        let km = APIKeyManager.shared
        switch self {
        case .gemini:
            let k = km.geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
            return k.isEmpty ? fallbackGeminiKey.trimmingCharacters(in: .whitespacesAndNewlines) : k
        case .deepseek:
            return StarIslandAIKeyStore.deepseekAPIKey
        case .qwen:
            return StarIslandAIKeyStore.qwenAPIKey
        case .openAI:
            return km.openAIAPIKey
        case .anthropic:
            return km.anthropicAPIKey
        case .openRouter:
            return km.openRouterAPIKey
        case .xai:
            return km.xaiAPIKey
        case .nvidia:
            return km.nvidiaAPIKey
        case .hackclub:
            return km.hackClubAPIKey
        case .ollama:
            return "ollama-local"
        case .auto:
            for candidate: LLMBackend in [.gemini, .deepseek, .qwen, .openRouter, .openAI, .anthropic] {
                let key = candidate.resolveAPIKey(fallbackGeminiKey: fallbackGeminiKey)
                if !key.isEmpty { return key }
            }
            return "ollama-local"
        }
    }

    func resolvedExecutionBackend(fallbackGeminiKey: String) -> LLMBackend {
        guard self == .auto else { return self }
        for candidate: LLMBackend in [.gemini, .deepseek, .qwen, .openRouter, .openAI, .anthropic] {
            if !candidate.resolveAPIKey(fallbackGeminiKey: fallbackGeminiKey).isEmpty {
                return candidate
            }
        }
        return .ollama
    }

    static func buildChatRequest(
        prompt: String,
        backend: LLMBackend,
        apiKey: String,
        geminiSpeedMode: GeminiSpeedMode,
        imagePNGData: Data? = nil
    ) throws -> URLRequest {
        let resolved = backend.resolvedExecutionBackend(fallbackGeminiKey: apiKey)
        let key = (apiKey.isEmpty ? resolved.resolveAPIKey(fallbackGeminiKey: "") : apiKey)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let systemPrompt = "你是星岛 (StarIsland) macOS 灵动岛智能助手，请用简洁准确的简体中文回答。"

        switch resolved {
        case .gemini:
            guard !key.isEmpty else { throw LLMBackendError.missingAPIKey(resolved.displayName) }
            let model = geminiSpeedMode == .fast ? "gemini-2.5-flash" : "gemini-2.5-pro"
            guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(key)") else {
                throw LLMBackendError.invalidEndpoint
            }
            var parts: [[String: Any]] = [["text": prompt]]
            if let imagePNGData {
                parts.append(["inlineData": ["mimeType": "image/png", "data": imagePNGData.base64EncodedString()]])
            }
            let payload: [String: Any] = [
                "systemInstruction": ["parts": [["text": systemPrompt]]],
                "contents": [["role": "user", "parts": parts]]
            ]
            var req = URLRequest(url: url, timeoutInterval: 35)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: payload)
            return req

        case .anthropic:
            guard !key.isEmpty else { throw LLMBackendError.missingAPIKey(resolved.displayName) }
            guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
                throw LLMBackendError.invalidEndpoint
            }
            let model = BlipModelPreferences.anthropicModel.isEmpty ? "claude-3-5-sonnet-latest" : BlipModelPreferences.anthropicModel
            let payload: [String: Any] = [
                "model": model,
                "max_tokens": 2048,
                "system": systemPrompt,
                "messages": [["role": "user", "content": prompt]]
            ]
            var req = URLRequest(url: url, timeoutInterval: 35)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue(key, forHTTPHeaderField: "x-api-key")
            req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            req.httpBody = try JSONSerialization.data(withJSONObject: payload)
            return req

        case .ollama:
            let base = StarIslandAIKeyStore.ollamaEndpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
            guard let url = URL(string: "\(base)/api/chat") else { throw LLMBackendError.invalidEndpoint }
            let payload: [String: Any] = [
                "model": StarIslandAIKeyStore.ollamaModel.isEmpty ? "qwen2.5:7b" : StarIslandAIKeyStore.ollamaModel,
                "stream": false,
                "messages": [
                    ["role": "system", "content": systemPrompt],
                    ["role": "user", "content": prompt]
                ]
            ]
            var req = URLRequest(url: url, timeoutInterval: 45)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: payload)
            return req

        default:
            guard !key.isEmpty else { throw LLMBackendError.missingAPIKey(resolved.displayName) }
            let (endpoint, defaultModel): (String, String) = {
                switch resolved {
                case .deepseek: return ("https://api.deepseek.com/v1/chat/completions", "deepseek-chat")
                case .qwen: return ("https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions", "qwen-plus")
                case .openRouter: return ("https://openrouter.ai/api/v1/chat/completions", BlipModelPreferences.openRouterModelStored.isEmpty ? "openai/gpt-4o-mini" : BlipModelPreferences.openRouterModelStored)
                case .xai: return ("https://api.x.ai/v1/chat/completions", "grok-2-latest")
                case .nvidia: return ("https://integrate.api.nvidia.com/v1/chat/completions", "meta/llama-3.1-70b-instruct")
                case .hackclub: return ("https://ai.hackclub.com/chat/completions", "llama-3.3-70b-versatile")
                default: return ("https://api.openai.com/v1/chat/completions", "gpt-4o-mini")
                }
            }()
            guard let url = URL(string: endpoint) else { throw LLMBackendError.invalidEndpoint }
            let payload: [String: Any] = [
                "model": defaultModel,
                "messages": [
                    ["role": "system", "content": systemPrompt],
                    ["role": "user", "content": prompt]
                ]
            ]
            var req = URLRequest(url: url, timeoutInterval: 35)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            req.httpBody = try JSONSerialization.data(withJSONObject: payload)
            return req
        }
    }

    static func parseChatResponse(data: Data, backend: LLMBackend) throws -> String {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMBackendError.emptyReply
        }
        if let candidates = root["candidates"] as? [[String: Any]],
           let content = candidates.first?["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]] {
            let text = parts.compactMap { $0["text"] as? String }.joined().trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { return text }
        }
        if let choices = root["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any],
           let text = (message["content"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            return text
        }
        if let contentBlocks = root["content"] as? [[String: Any]] {
            let text = contentBlocks.compactMap { $0["text"] as? String }.joined().trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { return text }
        }
        if let message = root["message"] as? [String: Any],
           let text = (message["content"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            return text
        }
        throw LLMBackendError.emptyReply
    }
}

enum GeminiSpeedMode: String, Codable, CaseIterable {
    case fast, quality
}

enum GeminiModelOption: String, Codable, CaseIterable {
    case auto, flash35Lite
}

enum OpenAIModelOption: String, Codable, CaseIterable { case auto }
enum AnthropicModelOption: String, Codable, CaseIterable { case auto }
enum XAIModelOption: String, Codable, CaseIterable { case auto }
enum NVIDIAModelOption: String, Codable, CaseIterable { case auto }
enum OpenRouterModelPreset: String, Codable, CaseIterable { case auto }

enum BlipModelPreferences {
    static var openAIModel = ""
    static var anthropicModel = ""
    static var openRouterModelStored = ""
    static var xaiModel = ""
    static var nvidiaModel = ""
}
#endif
