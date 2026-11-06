//
//  CircleToSearchResultsView.swift
//  Sapphire
//

#if !SAPPHIRE_FULL_BUILD
import AppKit
import SwiftUI

struct CircleToSearchResultsView: View {
    @Binding var navigationStack: [NotchWidgetMode]
    @ObservedObject private var manager = CircleToSearchManager.shared
    @ObservedObject private var settingsModel = SettingsModel.shared

    init(navigationStack: Binding<[NotchWidgetMode]>) {
        _navigationStack = navigationStack
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
                Label("画圈搜屏与离线 OCR", systemImage: "viewfinder")
                    .font(.subheadline.weight(.bold))
                Spacer()

                Button("重新框选") {
                    manager.startInteractiveSelection()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            HStack(alignment: .top, spacing: 10) {
                if let img = manager.latestImage {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 110, height: 86)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 6) {
                    if manager.isRecognizing {
                        ProgressView("正在执行中英视觉识别…").controlSize(.small)
                    } else if manager.recognizedText.isEmpty {
                        Text("点击右上角「重新框选」，拖拽选取屏幕任意区域即可提取文字或搜索。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView {
                            Text(manager.recognizedText)
                                .font(.system(size: 12))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 90)
                    }
                }
            }

            if !manager.recognizedText.isEmpty {
                HStack(spacing: 8) {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(manager.recognizedText, forType: .string)
                    } label: {
                        Label("复制全文", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button {
                        let q = manager.recognizedText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                        if let url = URL(string: "https://www.google.com/search?q=\(q)") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Label("网页搜索", systemImage: "safari")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        let vm = (NSApp.delegate as? AppDelegate)?.intelligenceViewModel ?? IntelligenceNotchViewModel()
                        vm.taskInput = "请解释并总结以下屏幕提取文字：\n\(manager.recognizedText)"
                        let backend = settingsModel.settings.intelligenceBackend
                        let key = backend.resolveAPIKey(fallbackGeminiKey: APIKeyManager.shared.geminiAPIKey)
                        vm.run(apiKey: key, backend: backend, geminiSpeedMode: settingsModel.settings.intelligenceGeminiSpeedMode)
                        navigationStack.append(.agentS)
                    } label: {
                        Label("AI 解读", systemImage: "sparkles")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(14)
        .frame(width: 440)
        .foregroundStyle(.white)
    }
}
#endif
