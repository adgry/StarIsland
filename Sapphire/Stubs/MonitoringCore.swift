//
//  MonitoringCore.swift
//  Sapphire
//

#if !SAPPHIRE_FULL_BUILD
import Foundation
import SwiftUI

enum MonitorType: String, Codable, CaseIterable {
    case screen, audio, location, calendar, contacts

    var displayName: String {
        switch self {
        case .screen: return "屏幕上下文"
        case .audio: return "音频转录"
        case .location: return "位置情境"
        case .calendar: return "日历日程"
        case .contacts: return "通讯录"
        }
    }

    var icon: String {
        switch self {
        case .screen: return "display"
        case .audio: return "waveform"
        case .location: return "location.fill"
        case .calendar: return "calendar"
        case .contacts: return "person.crop.circle"
        }
    }
}

struct DataSummary {
    var totalDataPoints: Int = 0
    var countsByMonitorType: [String: Int] = [:]
    var oldestEntry: Date?
    var newestEntry: Date?
    var databaseSizeMB: Double = 0
}

final class MemorySystemManager {
    static let shared = MemorySystemManager()

    private let lock = NSLock()
    private var records: [(date: Date, prompt: String, reply: String)] = []

    private init() {}

    func recordInteraction(prompt: String, reply: String) {
        lock.lock()
        records.append((Date(), prompt, reply))
        if records.count > 200 { records.removeFirst(records.count - 200) }
        lock.unlock()
    }

    func getDataSummary() throws -> DataSummary {
        lock.lock()
        defer { lock.unlock() }
        let bytes = records.reduce(0) { $0 + $1.prompt.utf8.count + $1.reply.utf8.count }
        return DataSummary(
            totalDataPoints: records.count,
            countsByMonitorType: [MonitorType.screen.rawValue: records.count],
            oldestEntry: records.first?.date,
            newestEntry: records.last?.date,
            databaseSizeMB: Double(bytes) / (1024.0 * 1024.0)
        )
    }
}

struct IntelligenceSettingsView: View {
    @EditingSettings var settings: SettingsEditingSession
    @State private var geminiKey: String = APIKeyManager.shared.geminiAPIKey
    @State private var deepseekKey: String = StarIslandAIKeyStore.deepseekAPIKey
    @State private var qwenKey: String = StarIslandAIKeyStore.qwenAPIKey
    @State private var openAIKey: String = APIKeyManager.shared.openAIAPIKey
    @State private var openRouterKey: String = APIKeyManager.shared.openRouterAPIKey
    @State private var ollamaEndpoint: String = StarIslandAIKeyStore.ollamaEndpoint
    @State private var ollamaModel: String = StarIslandAIKeyStore.ollamaModel
    @State private var savedBannerVisible = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                Text("智能助手与画圈搜屏").font(.largeTitle.bold()).padding(.bottom, 6)

                SettingsCard(title: "AI 模型通道选择", description: "支持云端多模态大模型与本机免密钥 Ollama 离线推理。") {
                    ToggleRow(title: "启用灵动岛智能助手", description: "在展开的灵动岛顶栏展示 AI 助手与快捷指令工作台。", isOn: $settings.settings.intelligenceEnabled)
                    Divider().padding(.leading, 20)

                    HStack {
                        Text("默认推理引擎")
                        Spacer()
                        Picker("", selection: $settings.settings.intelligenceBackend) {
                            ForEach([LLMBackend.auto, .gemini, .deepseek, .qwen, .openRouter, .openAI, .ollama], id: \.self) { backend in
                                Text(backend.displayName).tag(backend)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 220)
                    }
                    .padding(20)
                }

                SettingsCard(title: "API 密钥与本地端点配置", description: "密钥安全存储在 macOS 钥匙串与本地沙盒中，随时可切换。") {
                    VStack(alignment: .leading, spacing: 12) {
                        keyFieldRow("Google Gemini API Key", text: $geminiKey, placeholder: "AIzaSy...")
                        keyFieldRow("DeepSeek API Key", text: $deepseekKey, placeholder: "sk-...")
                        keyFieldRow("通义千问 DashScope Key", text: $qwenKey, placeholder: "sk-...")
                        keyFieldRow("OpenRouter API Key", text: $openRouterKey, placeholder: "sk-or-...")
                        keyFieldRow("OpenAI API Key", text: $openAIKey, placeholder: "sk-...")

                        Divider()

                        HStack(spacing: 10) {
                            Text("Ollama 地址").frame(width: 150, alignment: .leading)
                            TextField("http://127.0.0.1:11434", text: $ollamaEndpoint).textFieldStyle(.roundedBorder)
                            Text("模型")
                            TextField("qwen2.5:7b", text: $ollamaModel).textFieldStyle(.roundedBorder).frame(width: 140)
                        }

                        HStack {
                            Button("保存模型配置") {
                                APIKeyManager.shared.geminiAPIKey = geminiKey
                                APIKeyManager.shared.openAIAPIKey = openAIKey
                                APIKeyManager.shared.openRouterAPIKey = openRouterKey
                                StarIslandAIKeyStore.deepseekAPIKey = deepseekKey
                                StarIslandAIKeyStore.qwenAPIKey = qwenKey
                                StarIslandAIKeyStore.ollamaEndpoint = ollamaEndpoint
                                StarIslandAIKeyStore.ollamaModel = ollamaModel
                                savedBannerVisible = true
                            }
                            .buttonStyle(.borderedProminent)

                            if savedBannerVisible {
                                Label("已保存生效", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                            Spacer()
                        }
                    }
                    .padding(20)
                }

                SettingsCard(title: "画圈搜屏与离线视觉 OCR", description: "框选屏幕任意区域即可离线识别中英文字、复制或交由 AI 解读。") {
                    ToggleRow(title: "启用画圈搜屏", description: "支持从灵动岛或全局快捷键随时框选屏幕识别。", isOn: $settings.settings.circleToSearchEnabled)
                    Divider().padding(.leading, 20)
                    HStack {
                        Button {
                            CircleToSearchManager.shared.startInteractiveSelection()
                        } label: {
                            Label("立即启动全屏框选识别", systemImage: "viewfinder")
                        }
                        .buttonStyle(.borderedProminent)
                        Spacer()
                    }
                    .padding(20)
                }

                SettingsCard(title: "即时对话测试台", description: "直接在下方输入指令验证当前所选模型通道。") {
                    IntelligenceRunnerView(
                        apiKey: geminiKey,
                        backend: settings.settings.intelligenceBackend,
                        geminiSpeedMode: settings.settings.intelligenceGeminiSpeedMode
                    )
                    .padding(20)
                }
            }
            .padding(25)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func keyFieldRow(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        HStack(spacing: 10) {
            Text(label).font(.system(size: 13, weight: .medium)).frame(width: 170, alignment: .leading)
            SecureField(placeholder, text: text).textFieldStyle(.roundedBorder)
        }
    }
}
#endif
