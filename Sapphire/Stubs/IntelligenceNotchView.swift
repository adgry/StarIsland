//
//  IntelligenceNotchView.swift
//  Sapphire
//

#if !SAPPHIRE_FULL_BUILD
import AppKit
import SwiftUI

struct IntelligenceNotchView: View {
    @Binding var navigationStack: [NotchWidgetMode]
    @ObservedObject private var settingsModel = SettingsModel.shared
    @ObservedObject private var vm: IntelligenceNotchViewModel

    init(navigationStack: Binding<[NotchWidgetMode]>) {
        _navigationStack = navigationStack
        let resolved = (NSApp.delegate as? AppDelegate)?.intelligenceViewModel ?? IntelligenceNotchViewModel()
        _vm = ObservedObject(wrappedValue: resolved)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button {
                    if !navigationStack.isEmpty { navigationStack.removeLast() }
                } label: {
                    Label("返回", systemImage: "chevron.left")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)

                Spacer()
                Label("星岛 AI 灵动助手", systemImage: "sparkles")
                    .font(.subheadline.weight(.bold))
                Spacer()

                Button {
                    CircleToSearchManager.shared.startInteractiveSelection()
                } label: {
                    Label("画圈搜屏", systemImage: "viewfinder")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            HStack(spacing: 6) {
                quickChip("总结剪贴板") {
                    let clip = NSPasteboard.general.string(forType: .string) ?? ""
                    vm.taskInput = clip.isEmpty ? "请介绍你的核心能力" : "请用 3 条要点总结以下内容：\n\(clip.prefix(1500))"
                    triggerRun()
                }
                quickChip("中英互译") {
                    let clip = NSPasteboard.general.string(forType: .string) ?? ""
                    vm.taskInput = clip.isEmpty ? "请将 Hello StarIsland 翻译为优美中文" : "请将以下内容中英互译并保持自然语感：\n\(clip.prefix(1500))"
                    triggerRun()
                }
                quickChip("润色表达") {
                    let clip = NSPasteboard.general.string(forType: .string) ?? ""
                    vm.taskInput = "请润色以下文字，使其更专业精炼：\n\(clip.prefix(1500))"
                    triggerRun()
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    if vm.logEntries.isEmpty {
                        Text("支持 Gemini、DeepSeek、通义千问、OpenRouter 及本地免密钥 Ollama。可直接输入问题或点击上方快捷指令。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 12)
                    } else {
                        ForEach(vm.logEntries.suffix(8)) { entry in
                            Text(entry.text)
                                .font(.system(size: 12))
                                .foregroundStyle(entry.isError ? .orange : (entry.isSubtask ? .cyan : .white))
                                .textSelection(.enabled)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
                        }
                    }
                }
            }
            .frame(minHeight: 85, maxHeight: 140)

            HStack(spacing: 8) {
                TextField("向星岛 AI 提问…", text: $vm.taskInput)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.09)))
                    .onSubmit { triggerRun() }

                Button {
                    vm.isRunning ? vm.stop() : triggerRun()
                } label: {
                    Image(systemName: vm.isRunning ? "stop.fill" : "arrow.up.circle.fill")
                        .font(.title3)
                        .foregroundStyle(vm.isRunning ? .red : .purple)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(width: 440)
        .foregroundStyle(.white)
    }

    private func quickChip(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.purple.opacity(0.24)))
            .buttonStyle(.plain)
    }

    private func triggerRun() {
        let backend = settingsModel.settings.intelligenceBackend
        let key = backend.resolveAPIKey(fallbackGeminiKey: APIKeyManager.shared.geminiAPIKey)
        vm.run(apiKey: key, backend: backend, geminiSpeedMode: settingsModel.settings.intelligenceGeminiSpeedMode)
    }
}
#endif
