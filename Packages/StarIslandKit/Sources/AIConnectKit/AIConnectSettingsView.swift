import AppKit
import IslandCore
import SwiftUI

/// 设置中心「AI 助手与手机互联」配置面板
public struct AIConnectSettingsPaneView: View {
    @ObservedObject private var settingsStore: SettingsStore
    @ObservedObject private var coordinator: AIAssistantCoordinator
    @ObservedObject private var server: LANContinuityServer
    private let keychain: KeychainVault

    @State private var geminiKeyDraft: String = ""
    @State private var openAIKeyDraft: String = ""
    @State private var keyStatusNotice: String = ""
    @State private var portText: String = ""

    @MainActor
    public init(
        settingsStore: SettingsStore? = nil,
        coordinator: AIAssistantCoordinator? = nil,
        server: LANContinuityServer? = nil,
        keychain: KeychainVault = .shared
    ) {
        let resolvedStore = settingsStore ?? .shared
        self.settingsStore = resolvedStore
        self.coordinator = coordinator ?? .shared
        self.server = server ?? .shared
        self.keychain = keychain
        _portText = State(initialValue: String(resolvedStore.settings.lanServerPort))
    }

    public var body: some View {
        Form {
            Section("AI 模型推理引擎") {
                Picker("当前激活引擎", selection: $settingsStore.settings.activeAIProvider) {
                    ForEach(AIProviderKind.allCases) { provider in
                        Text(provider.displayName).tag(provider.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                Text(coordinator.activeProvider.subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }

            Section("Google Gemini 配置（密钥安全存储于系统钥匙串）") {
                TextField("Gemini 模型名称", text: $settingsStore.settings.geminiModel)
                HStack {
                    SecureField(
                        keychain.hasAPIKey(for: .gemini) ? "已存入钥匙串（输入新密钥可覆盖）" : "粘贴 Gemini API Key",
                        text: $geminiKeyDraft
                    )
                    Button("保存密钥") {
                        saveKey(geminiKeyDraft, for: .gemini)
                        geminiKeyDraft = ""
                    }
                    .disabled(geminiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if keychain.hasAPIKey(for: .gemini) {
                        Button("清除", role: .destructive) {
                            clearKey(for: .gemini)
                        }
                    }
                }
            }

            Section("OpenAI 兼容接口（支持 DeepSeek / 通义千问 / 硅基流动）") {
                TextField("接口 Base URL", text: $settingsStore.settings.openAIBaseURL)
                HStack(spacing: 8) {
                    Text("快捷预设：")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                    Button("OpenAI") {
                        settingsStore.settings.openAIBaseURL = "https://api.openai.com/v1"
                        settingsStore.settings.openAIModel = "gpt-4o-mini"
                    }
                    .controlSize(.mini)
                    Button("DeepSeek") {
                        settingsStore.settings.openAIBaseURL = "https://api.deepseek.com/v1"
                        settingsStore.settings.openAIModel = "deepseek-chat"
                    }
                    .controlSize(.mini)
                    Button("硅基流动") {
                        settingsStore.settings.openAIBaseURL = "https://api.siliconflow.cn/v1"
                        settingsStore.settings.openAIModel = "Qwen/Qwen2.5-7B-Instruct"
                    }
                    .controlSize(.mini)
                }
                TextField("兼容模型名称", text: $settingsStore.settings.openAIModel)
                HStack {
                    SecureField(
                        keychain.hasAPIKey(for: .openAICompatible) ? "已存入钥匙串（输入新密钥可覆盖）" : "粘贴 Bearer API Key",
                        text: $openAIKeyDraft
                    )
                    Button("保存密钥") {
                        saveKey(openAIKeyDraft, for: .openAICompatible)
                        openAIKeyDraft = ""
                    }
                    .disabled(openAIKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if keychain.hasAPIKey(for: .openAICompatible) {
                        Button("清除", role: .destructive) {
                            clearKey(for: .openAICompatible)
                        }
                    }
                }
            }

            Section("本地 Ollama 离线模型") {
                TextField("Ollama 服务地址", text: $settingsStore.settings.ollamaBaseURL)
                TextField("本地模型标识（如 qwen2.5:7b）", text: $settingsStore.settings.ollamaModel)
            }

            if !keyStatusNotice.isEmpty {
                Section {
                    Text(keyStatusNotice)
                        .font(.caption)
                        .foregroundStyle(Color.green)
                }
            }

            Section("局域网手机免装 App 扫码互联") {
                Toggle("启用局域网跨端互联服务（Bonjour _starisland._tcp）", isOn: $settingsStore.settings.enableLANContinuityServer)
                    .onChange(of: settingsStore.settings.enableLANContinuityServer) { _, enabled in
                        if enabled {
                            server.start()
                        } else {
                            server.stop()
                        }
                    }

                HStack {
                    TextField("HTTP 监听端口", text: $portText)
                        .frame(width: 180)
                    Button("应用端口并重启服务") {
                        if let parsed = UInt16(portText.trimmingCharacters(in: .whitespacesAndNewlines)),
                           parsed >= 1024 {
                            settingsStore.settings.lanServerPort = parsed
                            if settingsStore.settings.enableLANContinuityServer {
                                server.start()
                            }
                        }
                    }
                    Spacer()
                    Button("刷新 6 位安全配对码") {
                        server.refreshPIN()
                    }
                }

                HStack {
                    Text("状态：\(server.statusMessage) · 当前配对码：\(server.currentPIN)")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                    Spacer()
                    Button("打开接收目录") {
                        NSWorkspace.shared.open(server.uploadDirectoryURL)
                    }
                    .controlSize(.small)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func saveKey(_ raw: String, for provider: AIProviderKind) {
        do {
            try keychain.saveAPIKey(raw, for: provider)
            keyStatusNotice = "\(provider.displayName) 密钥已加密保存至 macOS 钥匙串（Service: \(keychain.service)）"
        } catch {
            keyStatusNotice = error.localizedDescription
        }
    }

    private func clearKey(for provider: AIProviderKind) {
        do {
            try keychain.deleteAPIKey(for: provider)
            keyStatusNotice = "已从系统钥匙串移除 \(provider.displayName) 密钥"
        } catch {
            keyStatusNotice = error.localizedDescription
        }
    }
}
