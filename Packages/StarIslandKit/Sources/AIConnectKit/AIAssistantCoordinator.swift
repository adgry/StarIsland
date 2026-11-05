import AppKit
import AVFoundation
import Combine
import Foundation
import IslandCore
import ScreenCaptureKit
import Speech

private final class SpeechSynthesizerDelegateProxy: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    var onSpeakingChanged: (@Sendable (Bool) -> Void)?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        onSpeakingChanged?(true)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onSpeakingChanged?(false)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        onSpeakingChanged?(false)
    }
}

@MainActor
public final class AIAssistantCoordinator: ObservableObject, AIQueryServiceProtocol {
    public static let shared: AIAssistantCoordinator = {
        let instance = AIAssistantCoordinator()
        ServiceRegistry.shared.aiService = instance
        return instance
    }()

    public static let supportedTranslationLanguages: [String] = [
        "简体中文", "英语", "日语", "韩语", "法语", "德语"
    ]

    @Published public private(set) var messages: [AIChatMessage] = []
    @Published public private(set) var isGenerating: Bool = false
    @Published public var lastErrorMessage: String?
    @Published public var pendingImagePNGData: Data?
    @Published public var autoSpeakReplies: Bool = false
    @Published public private(set) var isSpeaking: Bool = false
    @Published public private(set) var isListeningSpeech: Bool = false
    @Published public var targetTranslationLanguage: String = "简体中文"

    private let settingsStore: SettingsStore
    private let stateMachine: IslandStateMachine
    private let keychain: KeychainVault
    private let transport: AITransportHandler

    private let synthesizer = AVSpeechSynthesizer()
    private let speechProxy = SpeechSynthesizerDelegateProxy()
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private static let concealedPasteboardType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")

    public init(
        settingsStore: SettingsStore? = nil,
        stateMachine: IslandStateMachine? = nil,
        keychain: KeychainVault = .shared,
        transport: AITransportHandler? = nil
    ) {
        self.settingsStore = settingsStore ?? .shared
        self.stateMachine = stateMachine ?? .shared
        self.keychain = keychain
        self.transport = transport ?? Self.defaultURLSessionTransport

        speechProxy.onSpeakingChanged = { [weak self] speaking in
            Task { @MainActor [weak self] in
                self?.isSpeaking = speaking
            }
        }
        synthesizer.delegate = speechProxy
    }

    public var activeProvider: AIProviderKind {
        get {
            AIProviderKind(rawValue: settingsStore.settings.activeAIProvider) ?? .gemini
        }
        set {
            settingsStore.settings.activeAIProvider = newValue.rawValue
            objectWillChange.send()
        }
    }

    // MARK: - AIQueryServiceProtocol 实现

    public func ask(prompt: String, imagePNGData: Data? = nil) async throws -> String {
        let effectiveImage = imagePNGData ?? pendingImagePNGData
        if imagePNGData == nil {
            pendingImagePNGData = nil
        }

        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || effectiveImage != nil else {
            throw AIProviderError.emptyPrompt
        }

        let priorHistory = Array(messages.suffix(12))
        let displayPrompt = trimmed.isEmpty ? "请识别并分析这张图片" : trimmed
        let userMessage = AIChatMessage(
            role: .user,
            content: displayPrompt,
            attachedImagePNGData: effectiveImage
        )
        messages.append(userMessage)
        isGenerating = true
        lastErrorMessage = nil
        submitAIActivity(title: "星岛 AI 正在思考…", subtitle: displayPrompt, isPeek: false, ttl: nil)

        defer {
            isGenerating = false
        }

        do {
            let reply = try await performInference(
                prompt: displayPrompt,
                imagePNGData: effectiveImage,
                history: priorHistory,
                systemInstruction: AIRequestBuilder.defaultSystemInstruction
            )
            let assistantMessage = AIChatMessage(role: .assistant, content: reply)
            messages.append(assistantMessage)
            submitAIActivity(
                title: "星岛 AI 已回复",
                subtitle: String(reply.prefix(48)),
                isPeek: true,
                ttl: 3.5
            )
            if autoSpeakReplies {
                speak(reply)
            }
            return reply
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            lastErrorMessage = message
            stateMachine.dismiss(id: "ai.thinking")
            throw error
        }
    }

    public func translate(text: String, targetLanguage: String) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AIProviderError.emptyPrompt
        }

        isGenerating = true
        lastErrorMessage = nil
        defer { isGenerating = false }

        let instruction = """
        你是一名专业精准的多语种翻译引擎。请将用户提供的文本准确、地道地翻译为「\(targetLanguage)」。
        只直接输出译文正文，不要输出任何额外解释、引号或前缀说明。
        """

        do {
            return try await performInference(
                prompt: trimmed,
                imagePNGData: nil,
                history: [],
                systemInstruction: instruction
            )
        } catch {
            lastErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            throw error
        }
    }

    public func clearConversation() {
        messages.removeAll()
        pendingImagePNGData = nil
        lastErrorMessage = nil
        stopSpeaking()
    }

    // MARK: - 剪贴板与屏幕截图多模态采集

    public func readClipboardText() -> String? {
        let pb = NSPasteboard.general
        if let types = pb.types, types.contains(Self.concealedPasteboardType) {
            return nil
        }
        guard let raw = pb.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }
        return raw
    }

    @discardableResult
    public func attachClipboardImage() -> Bool {
        let pb = NSPasteboard.general
        if let types = pb.types, types.contains(Self.concealedPasteboardType) {
            return false
        }
        guard let image = NSImage(pasteboard: pb),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            lastErrorMessage = "当前剪贴板中没有可读取的图片"
            return false
        }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = rep.representation(using: .png, properties: [:]) else {
            return false
        }
        pendingImagePNGData = pngData
        lastErrorMessage = nil
        return true
    }

    @discardableResult
    public func captureMainDisplayScreenshot() async -> Data? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first else {
                lastErrorMessage = "未找到可用的显示器画面"
                return nil
            }
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.width = max(1, display.width)
            config.height = max(1, display.height)
            config.showsCursor = false

            let cgImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
            let rep = NSBitmapImageRep(cgImage: cgImage)
            guard let pngData = rep.representation(using: .png, properties: [:]) else {
                return nil
            }
            pendingImagePNGData = pngData
            lastErrorMessage = nil
            return pngData
        } catch {
            lastErrorMessage = "屏幕截图失败，请在「系统设置 -> 屏幕录制」中授予星岛权限"
            return nil
        }
    }

    // MARK: - 中文语音播报与语音听写

    public func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    public func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }

    public func toggleVoiceInput(onTranscript: @escaping @MainActor (String) -> Void) {
        if isListeningSpeech {
            stopVoiceInput()
        } else {
            Task {
                await startVoiceInput(onTranscript: onTranscript)
            }
        }
    }

    public func startVoiceInput(onTranscript: @escaping @MainActor (String) -> Void) async {
        stopVoiceInput()

        let authStatus = await Self.requestSpeechAuthorization()
        guard authStatus == .authorized else {
            lastErrorMessage = "未获得语音识别权限，请在系统隐私设置中允许星岛使用麦克风与语音识别"
            return
        }

        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN")),
              recognizer.isAvailable else {
            lastErrorMessage = "当前系统中文语音识别服务暂不可用"
            return
        }

        let engine = AVAudioEngine()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.channelCount > 0 else {
            lastErrorMessage = "未检测到可用的麦克风输入设备"
            return
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        do {
            engine.prepare()
            try engine.start()
            self.audioEngine = engine
            self.recognitionRequest = request
            self.isListeningSpeech = true
            self.lastErrorMessage = nil

            self.recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                let transcript = result?.bestTranscription.formattedString
                let isFinal = result?.isFinal ?? false
                let hasError = error != nil
                Task { @MainActor [weak self] in
                    if let transcript, !transcript.isEmpty {
                        onTranscript(transcript)
                    }
                    if isFinal || hasError {
                        self?.stopVoiceInput()
                    }
                }
            }
        } catch {
            inputNode.removeTap(onBus: 0)
            lastErrorMessage = "无法启动麦克风录音：\(error.localizedDescription)"
            isListeningSpeech = false
        }
    }

    public func stopVoiceInput() {
        if let engine = audioEngine {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        isListeningSpeech = false
    }

    // MARK: - 内部请求派发

    private func performInference(
        prompt: String,
        imagePNGData: Data?,
        history: [AIChatMessage],
        systemInstruction: String
    ) async throws -> String {
        let provider = activeProvider
        let settings = settingsStore.settings
        let request: URLRequest

        switch provider {
        case .gemini:
            let key = keychain.readAPIKey(for: .gemini) ?? ""
            request = try AIRequestBuilder.buildGeminiRequest(
                model: settings.geminiModel,
                apiKey: key,
                prompt: prompt,
                imagePNGData: imagePNGData,
                history: history,
                systemInstruction: systemInstruction
            )

        case .openAICompatible:
            let key = keychain.readAPIKey(for: .openAICompatible) ?? ""
            request = try AIRequestBuilder.buildOpenAIRequest(
                baseURL: settings.openAIBaseURL,
                apiKey: key,
                model: settings.openAIModel,
                prompt: prompt,
                imagePNGData: imagePNGData,
                history: history,
                systemInstruction: systemInstruction
            )

        case .ollama:
            request = try AIRequestBuilder.buildOllamaRequest(
                baseURL: settings.ollamaBaseURL,
                model: settings.ollamaModel,
                prompt: prompt,
                imagePNGData: imagePNGData,
                history: history,
                systemInstruction: systemInstruction
            )
        }

        let (data, httpResponse) = try await transport(request)
        guard (200..<300).contains(httpResponse.statusCode) else {
            let detail = Self.extractHTTPErrorDetail(from: data) ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            throw AIProviderError.httpError(statusCode: httpResponse.statusCode, message: detail)
        }

        switch provider {
        case .gemini:
            return try AIRequestBuilder.parseGeminiResponse(data)
        case .openAICompatible:
            return try AIRequestBuilder.parseOpenAIResponse(data)
        case .ollama:
            return try AIRequestBuilder.parseOllamaResponse(data)
        }
    }

    private func submitAIActivity(title: String, subtitle: String, isPeek: Bool, ttl: TimeInterval?) {
        let item = IslandActivityItem(
            id: "ai.thinking",
            category: .ai,
            title: title,
            subtitle: subtitle,
            iconSymbol: "sparkles",
            priority: .interactive,
            isPeek: isPeek,
            allowsOnLockScreen: false,
            autoDismissAfter: ttl
        )
        stateMachine.submit(item)
    }

    private static func extractHTTPErrorDetail(from data: Data) -> String? {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let err = json["error"] as? [String: Any], let msg = err["message"] as? String {
                return msg
            }
            if let errStr = json["error"] as? String {
                return errStr
            }
        }
        let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let raw, !raw.isEmpty {
            return String(raw.prefix(160))
        }
        return nil
    }

    private static let defaultURLSessionTransport: AITransportHandler = { request in
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = max(8, request.timeoutInterval)
        config.timeoutIntervalForResource = 60
        let session = URLSession(configuration: config)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AIProviderError.malformedResponse("无效的 HTTP 响应对象")
        }
        return (data, http)
    }

    private nonisolated static func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        let current = SFSpeechRecognizer.authorizationStatus()
        if current != .notDetermined {
            return current
        }
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}
