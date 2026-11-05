import AppKit
import IslandCore
import SwiftUI

/// 灵动岛「星岛 AI」多模态对话 / 识图 / 翻译工作台
public struct AIIslandTabView: View {
    @ObservedObject private var coordinator: AIAssistantCoordinator
    @ObservedObject private var settingsStore: SettingsStore

    @State private var inputText: String = ""
    @State private var isTranslationMode: Bool = false
    @State private var translatedResult: String = ""

    @MainActor
    public init(
        coordinator: AIAssistantCoordinator? = nil,
        settingsStore: SettingsStore? = nil
    ) {
        self.coordinator = coordinator ?? .shared
        self.settingsStore = settingsStore ?? .shared
    }

    public var body: some View {
        VStack(spacing: 10) {
            headerToolbar

            if isTranslationMode {
                translationWorkspace
            } else {
                chatHistoryArea
            }

            if let error = coordinator.lastErrorMessage, !error.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Color.orange)
                        .lineLimit(2)
                    Spacer()
                    Button("打开设置") {
                        ServiceRegistry.shared.onOpenSettingsSection?(.aiConnect)
                    }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.blue)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            }

            composerBar
        }
        .padding(12)
    }

    private var headerToolbar: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(AIProviderKind.allCases) { kind in
                    Button {
                        coordinator.activeProvider = kind
                    } label: {
                        Label(
                            kind.displayName,
                            systemImage: coordinator.activeProvider == kind ? "checkmark.circle.fill" : kind.iconSymbol
                        )
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: coordinator.activeProvider.iconSymbol)
                    Text(coordinator.activeProvider.displayName)
                        .font(.caption.weight(.semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.1), in: Capsule())
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Picker("", selection: $isTranslationMode) {
                Text("多轮对话").tag(false)
                Text("多语互译").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 136)

            Spacer()

            Button {
                Task { _ = await coordinator.captureMainDisplayScreenshot() }
            } label: {
                Image(systemName: "camera.viewfinder")
            }
            .buttonStyle(.plain)
            .help("截取当前屏幕附带提问")

            Button {
                if !coordinator.attachClipboardImage(),
                   let clipText = coordinator.readClipboardText() {
                    inputText = inputText.isEmpty ? clipText : "\(inputText)\n\(clipText)"
                }
            } label: {
                Image(systemName: "doc.on.clipboard")
            }
            .buttonStyle(.plain)
            .help("附带当前剪贴板图片或文字")

            Button {
                coordinator.autoSpeakReplies.toggle()
                if !coordinator.autoSpeakReplies {
                    coordinator.stopSpeaking()
                }
            } label: {
                Image(systemName: coordinator.autoSpeakReplies ? "speaker.wave.2.fill" : "speaker.slash")
                    .foregroundStyle(coordinator.autoSpeakReplies ? Color.blue : Color.secondary)
            }
            .buttonStyle(.plain)
            .help("自动语音播报 AI 回复")

            Button {
                coordinator.clearConversation()
                translatedResult = ""
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .help("清空当前会话")
        }
    }

    private var chatHistoryArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if coordinator.messages.isEmpty {
                    emptyPromptSuggestions
                } else {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(coordinator.messages) { msg in
                            messageBubble(msg)
                                .id(msg.id)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .frame(minHeight: 150, maxHeight: 220)
            .onChange(of: coordinator.messages.count) { _, _ in
                if let lastID = coordinator.messages.last?.id {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var emptyPromptSuggestions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("星岛灵动 AI 助手")
                .font(.subheadline.weight(.semibold))
            Text("支持连续多轮问答、屏幕截图理解、剪贴板速读与中文语音交互。")
                .font(.caption)
                .foregroundStyle(Color.secondary)
            HStack(spacing: 8) {
                quickSuggestionButton("总结剪贴板内容") {
                    if let clip = coordinator.readClipboardText() {
                        inputText = "请帮我提炼总结以下内容的要点：\n\(clip)"
                        submitCurrentAction()
                    } else {
                        coordinator.lastErrorMessage = "当前剪贴板为空"
                    }
                }
                quickSuggestionButton("截图解答问题") {
                    Task {
                        if await coordinator.captureMainDisplayScreenshot() != nil {
                            inputText = "请分析当前屏幕画面中的关键信息并给出建议。"
                            submitCurrentAction()
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }

    private func quickSuggestionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.2), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func messageBubble(_ message: AIChatMessage) -> some View {
        let isUser = message.role == .user
        return HStack(alignment: .top) {
            if isUser { Spacer(minLength: 32) }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                if let imgData = message.attachedImagePNGData,
                   let nsImg = NSImage(data: imgData) {
                    Image(nsImage: nsImg)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 84)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                Text(message.content)
                    .font(.system(size: 12.5))
                    .textSelection(.enabled)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        isUser ? Color.blue.opacity(0.75) : Color.white.opacity(0.1),
                        in: RoundedRectangle(cornerRadius: 11)
                    )
                if !isUser {
                    HStack(spacing: 10) {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(message.content, forType: .string)
                        } label: {
                            Label("复制", systemImage: "doc.on.doc")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.plain)

                        Button {
                            coordinator.speak(message.content)
                        } label: {
                            Label("朗读", systemImage: "speaker.wave.2")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.plain)
                    }
                    .foregroundStyle(Color.secondary)
                }
            }
            if !isUser { Spacer(minLength: 32) }
        }
    }

    private var translationWorkspace: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("目标语言：")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                Picker("目标语言", selection: $coordinator.targetTranslationLanguage) {
                    ForEach(AIAssistantCoordinator.supportedTranslationLanguages, id: \.self) { lang in
                        Text(lang).tag(lang)
                    }
                }
                .labelsHidden()
                .frame(width: 120)

                Spacer()

                Button("粘贴剪贴板并翻译") {
                    if let clip = coordinator.readClipboardText() {
                        inputText = clip
                        submitCurrentAction()
                    }
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            ScrollView {
                Text(translatedResult.isEmpty ? "在下方输入任意语种文本并点击发送，即可精准翻译…" : translatedResult)
                    .font(.system(size: 13))
                    .foregroundStyle(translatedResult.isEmpty ? Color.secondary : Color.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(10)
            }
            .frame(height: 118)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var composerBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let pendingData = coordinator.pendingImagePNGData,
               let preview = NSImage(data: pendingData) {
                HStack(spacing: 8) {
                    Image(nsImage: preview)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 34, height: 34)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    Text("已附带图片（随下次提问一并发送）")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                    Spacer()
                    Button {
                        coordinator.pendingImagePNGData = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }

            HStack(spacing: 8) {
                Button {
                    coordinator.toggleVoiceInput { transcript in
                        inputText = transcript
                    }
                } label: {
                    Image(systemName: coordinator.isListeningSpeech ? "waveform.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(coordinator.isListeningSpeech ? Color.red : Color.secondary)
                }
                .buttonStyle(.plain)
                .help("中文语音听写输入")

                TextField(isTranslationMode ? "输入待翻译文本…" : "向星岛 AI 提问…", text: $inputText)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
                    .onSubmit {
                        submitCurrentAction()
                    }

                Button {
                    submitCurrentAction()
                } label: {
                    if coordinator.isGenerating {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.blue)
                    }
                }
                .buttonStyle(.plain)
                .disabled(coordinator.isGenerating)
            }
        }
    }

    private func submitCurrentAction() {
        let prompt = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !coordinator.isGenerating else { return }
        guard !prompt.isEmpty || coordinator.pendingImagePNGData != nil else { return }

        if isTranslationMode {
            Task {
                if let res = try? await coordinator.translate(
                    text: prompt,
                    targetLanguage: coordinator.targetTranslationLanguage
                ) {
                    translatedResult = res
                }
            }
        } else {
            inputText = ""
            Task {
                _ = try? await coordinator.ask(prompt: prompt)
            }
        }
    }
}
