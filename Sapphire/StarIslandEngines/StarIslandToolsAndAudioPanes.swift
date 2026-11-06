//
//  StarIslandToolsAndAudioPanes.swift
//  Sapphire
//

#if !SAPPHIRE_FULL_BUILD
import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ArchivesAndDMGInstallerSettingsView: View {
    @ObservedObject private var model = SettingsModel.shared
    @ObservedObject private var dmgManager = DMGInstallerManager.shared

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                SettingsCard(title: "压缩包智能解压", description: "双击或拖入压缩包时自动整理单层目录并清理残留。") {
                    ToggleRow(title: "启用智能压缩包解压", description: "自动避免产生冗余嵌套文件夹或散落满桌面文件", isOn: $model.settings.archiveExtractorEnabled)
                    Divider().padding(.leading, 16)
                    ToggleRow(title: "解压完成后移入废纸篓", description: "成功提取全部文件后自动回收源压缩包", isOn: $model.settings.archiveDeleteAfterExtract)
                }

                SettingsCard(title: "DMG 磁盘镜像无感安装", description: "自动静默挂载 DMG、将应用拷入应用程序目录并弹出卸载镜像。") {
                    ToggleRow(title: "启用 DMG 一键安装助手", isOn: $model.settings.dmgInstallerEnabled)
                    Divider().padding(.leading, 16)
                    ToggleRow(title: "安装后回收源 DMG 文件", description: "释放下载目录磁盘空间", isOn: $model.settings.dmgInstallerTrashAfterInstall)
                    Divider().padding(.leading, 16)

                    HStack(spacing: 12) {
                        Button("选择 DMG 镜像立即安装…") {
                            let panel = NSOpenPanel()
                            panel.allowedContentTypes = [UTType(filenameExtension: "dmg") ?? .data]
                            panel.allowsMultipleSelection = true
                            if panel.runModal() == .OK {
                                dmgManager.handleOpenURLs(panel.urls)
                            }
                        }
                        .buttonStyle(.borderedProminent)

                        if !dmgManager.lastStatusMessage.isEmpty {
                            Text(dmgManager.lastStatusMessage)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                }
            }
            .padding(24)
        }
    }
}

struct DockLayoutsSettingsView: View {
    @ObservedObject private var model = SettingsModel.shared
    @State private var presetName: String = ""
    @State private var statusText: String = ""

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                SettingsCard(title: "程序坞布局快照", description: "保存工作、专注或演示场景下的 macOS 程序坞图标集并随时一键切换。") {
                    ToggleRow(title: "启用程序坞布局管理", isOn: $model.settings.dockLayoutsEnabled)
                    Divider().padding(.leading, 16)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            TextField("新快照名称（如：开发模式）", text: $presetName)
                                .textFieldStyle(.roundedBorder)
                            Button("保存当前程序坞") {
                                if let snap = DockLayoutsManager.shared.captureCurrentLayout(named: presetName) {
                                    model.settings.dockLayoutsPresets.append(snap)
                                    presetName = ""
                                    statusText = "已保存快照「\(snap.name)」"
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        if !statusText.isEmpty {
                            Text(statusText)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }

                        ForEach(model.settings.dockLayoutsPresets) { preset in
                            HStack {
                                Image(systemName: "dock.rectangle")
                                    .foregroundStyle(Color.accentColor)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preset.name).font(.system(size: 13, weight: .medium))
                                    if let count = preset.appCount {
                                        Text("\(count) 个常驻应用").font(.system(size: 11)).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Button("应用") {
                                    let ok = DockLayoutsManager.shared.applyLayout(preset)
                                    statusText = ok ? "已切换至「\(preset.name)」" : "此快照无本地程序坞数据"
                                }
                                .buttonStyle(.bordered)

                                Button(role: .destructive) {
                                    model.settings.dockLayoutsPresets.removeAll { $0.id == preset.id }
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(16)
                }
            }
            .padding(24)
        }
    }
}

struct MediaOptimizerSettingsView: View {
    @ObservedObject private var model = SettingsModel.shared
    @State private var resultBanner: String = ""
    @State private var isBusy = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                SettingsCard(title: "媒体瘦身与离线 OCR", description: "在文件暂存架及本地工具中无损/有损压缩图片与 PDF，并提取中英文字。") {
                    ToggleRow(title: "在文件暂存架显示压缩与提取按钮", description: "拖入图片或文档至灵动岛暂存架时展示快捷操作", isOn: $model.settings.mediaToolsShowShelfActions)
                    Divider().padding(.leading, 16)
                    ToggleRow(title: "自动优化剪贴板大图", isOn: $model.settings.mediaToolsAutoOptimizeClipboard)
                    Divider().padding(.leading, 16)

                    HStack {
                        Text("JPEG 压缩质量：\(Int((model.settings.mediaToolsImageQuality * 100).rounded()))%")
                            .font(.system(size: 13))
                        Spacer()
                        Slider(value: $model.settings.mediaToolsImageQuality, in: 0.3...0.95, step: 0.05)
                            .frame(width: 180)
                    }
                    .padding(16)

                    Divider().padding(.leading, 16)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Button(isBusy ? "处理中…" : "选择图片/PDF 立即压缩…") {
                                pickAndOptimize()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isBusy)

                            Button("选择图片提取文字 (OCR)…") {
                                pickAndOCR()
                            }
                            .buttonStyle(.bordered)
                            .disabled(isBusy)
                        }
                        if !resultBanner.isEmpty {
                            Text(resultBanner)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                }
            }
            .padding(24)
        }
    }

    private func pickAndOptimize() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .pdf]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        isBusy = true
        Task {
            let outcome = await MediaOptimizerManager.shared.optimizeFile(url)
            isBusy = false
            switch outcome {
            case .success(let res):
                resultBanner = "已生成 \(res.outputURL.lastPathComponent)，节省 \(res.savedPercent)%（\(ByteFormatter.string(res.savedBytes))）"
                NSWorkspace.shared.activateFileViewerSelecting([res.outputURL])
            case .failure(let err):
                resultBanner = err.localizedDescription
            }
        }
    }

    private func pickAndOCR() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        isBusy = true
        Task {
            let text = await MediaOptimizerManager.shared.recognizeText(in: url)
            isBusy = false
            if let text, !text.isEmpty {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                resultBanner = "已提取 \(text.count) 个字符并复制到剪贴板"
            } else {
                resultBanner = "未在所选图片中识别到文字"
            }
        }
    }
}

struct EightDAudioView: View {
    let bundleID: String
    let appName: String
    @ObservedObject private var audio = MultiAudioManager.shared

    private var config: EightDAudioSettings {
        audio.eightDAudioSettings(for: bundleID)
    }

    private func update(_ mutate: (inout EightDAudioSettings) -> Void) {
        var next = config
        mutate(&next)
        audio.setEightDAudioSettings(next, for: bundleID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("\(appName) · 8D 空间环绕声", systemImage: "headphones")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Toggle("", isOn: Binding(get: { config.enabled }, set: { val in update { $0.enabled = val } }))
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            Group {
                sliderRow("环绕旋转速度", value: config.rotationSpeed, range: 0.02...0.6) { v in update { $0.rotationSpeed = v } }
                sliderRow("空间景深", value: config.depth, range: 0.0...1.0) { v in update { $0.depth = v } }
                sliderRow("声场混响房间", value: config.roomSize, range: 0.0...1.0) { v in update { $0.roomSize = v } }
                sliderRow("低频增强 (dB)", value: config.bassBoost, range: 0.0...12.0) { v in update { $0.bassBoost = v } }
                sliderRow("整体强度", value: config.intensity, range: 0.0...1.0) { v in update { $0.intensity = v } }
            }
            .disabled(!config.enabled)
            .opacity(config.enabled ? 1 : 0.5)
        }
        .padding(12)
    }

    private func sliderRow(_ title: String, value: Double, range: ClosedRange<Double>, onChange: @escaping (Double) -> Void) -> some View {
        HStack(spacing: 10) {
            Text(title).font(.system(size: 11)).frame(width: 92, alignment: .leading)
            Slider(value: Binding(get: { value }, set: onChange), in: range)
            Text(String(format: "%.2f", value)).font(.system(size: 11, design: .monospaced)).frame(width: 38, alignment: .trailing)
        }
    }
}

struct SurroundAudioView: View {
    let bundleID: String
    let appName: String
    @ObservedObject private var audio = MultiAudioManager.shared

    private var config: SurroundAudioSettings {
        audio.surroundAudioSettings(for: bundleID)
    }

    private func update(_ mutate: (inout SurroundAudioSettings) -> Void) {
        var next = config
        mutate(&next)
        audio.setSurroundAudioSettings(next, for: bundleID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("\(appName) · 全景声场扩展", systemImage: "hifispeaker.2.fill")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Toggle("", isOn: Binding(get: { config.enabled }, set: { val in update { $0.enabled = val } }))
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            Group {
                sliderRow("声场宽度", value: config.width, range: 1.0...2.5) { v in update { $0.width = v } }
                sliderRow("双耳互馈", value: config.crossfeed, range: 0.0...0.5) { v in update { $0.crossfeed = v } }
                sliderRow("环境包围感", value: config.ambience, range: 0.0...1.0) { v in update { $0.ambience = v } }
                sliderRow("纵深层次", value: config.depth, range: 0.0...1.0) { v in update { $0.depth = v } }
                sliderRow("人声中置聚焦", value: config.centerFocus, range: 0.0...1.0) { v in update { $0.centerFocus = v } }
            }
            .disabled(!config.enabled)
            .opacity(config.enabled ? 1 : 0.5)
        }
        .padding(12)
    }

    private func sliderRow(_ title: String, value: Double, range: ClosedRange<Double>, onChange: @escaping (Double) -> Void) -> some View {
        HStack(spacing: 10) {
            Text(title).font(.system(size: 11)).frame(width: 92, alignment: .leading)
            Slider(value: Binding(get: { value }, set: onChange), in: range)
            Text(String(format: "%.2f", value)).font(.system(size: 11, design: .monospaced)).frame(width: 38, alignment: .trailing)
        }
    }
}
#endif
