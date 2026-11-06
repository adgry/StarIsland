//
//  ClipboardSettingsRows.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2026-10-07
//

import SwiftUI

struct PlainTextPasteShortcutRow: View {
    @EditingSettings var settings: SettingsEditingSession
    @ObservedObject private var shortcutRecorder = GlobalShortcutRecorder.shared

    private static let recordingIdentifier = "plainTextPasteShortcut"

    private var isRecording: Bool {
        shortcutRecorder.isRecording && shortcutRecorder.recordingIdentifier == Self.recordingIdentifier
    }

    private var label: String {
        let shortcut = settings.settings.systemEnhancePasteAsPlainShortcut
        return "\(KeyboardShortcutHelper.description(for: shortcut.modifiers))\(shortcut.key)"
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("快捷键")
                    .font(.system(size: 14, weight: .medium))
                Text("若应用支持“粘贴并匹配样式”，将优先调用该命令。必须包含 ⌘ 或 ⌃，普通 ⌘V 不会被改动。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if !isRecording {
                Text(label)
                    .font(.caption.monospaced())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.07))
                    .clipShape(Capsule())
            }
            Button(isRecording ? "取消" : "录制…") {
                if isRecording {
                    shortcutRecorder.stopRecording()
                } else {
                    shortcutRecorder.startRecording(identifier: Self.recordingIdentifier) { key, modifiers in
                        guard modifiers.contains(.command) || modifiers.contains(.control) else {
                            NSSound.beep()
                            return
                        }
                        settings.settings.systemEnhancePasteAsPlainShortcut = KeyboardShortcut(key: key, modifiers: modifiers)
                    }
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding()
    }
}

struct ClipboardStorageLimitRow: View {
    @EditingSettings var settings: SettingsEditingSession

    var body: some View {
        CustomSliderRowView(
            label: "存储上限",
            value: Binding(
                get: { Double(settings.settings.clipboardHistoryStorageLimitMB) },
                set: { settings.settings.clipboardHistoryStorageLimitMB = Int($0.rounded()) }
            ),
            range: Double(ClipboardHistoryBudget.storageLimitRangeMB.lowerBound)...Double(ClipboardHistoryBudget.storageLimitRangeMB.upperBound),
            specifier: "%.0f MB"
        )
        .help("历史记录超过此大小时将优先清理最早的项目。已置顶的项目会始终保留。")
    }
}

struct ClipboardIgnoredAppsRow: View {
    @EditingSettings var settings: SettingsEditingSession
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("忽略的应用")
                        .font(.system(size: 14, weight: .medium))
                    Text("在这些应用中复制的内容不会被保存。已忽略 \(settings.settings.clipboardIgnoredAppBundleIDs.count) 个应用。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(isExpanded ? "完成" : "编辑…") { isExpanded.toggle() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            if isExpanded {
                AppTogglesListView(
                    isEnabled: { app in $settings.settings.clipboardIgnoredAppBundleIDs.membership(of: app.id) },
                    showSearch: true
                )
                HStack {
                    Spacer()
                    Button("恢复密码管理器默认列表") {
                        var ids = settings.settings.clipboardIgnoredAppBundleIDs
                        for id in ClipboardIgnoredApps.defaultBundleIDs where !ids.contains(id) { ids.append(id) }
                        settings.settings.clipboardIgnoredAppBundleIDs = ids
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
            }
        }
        .padding()
    }
}