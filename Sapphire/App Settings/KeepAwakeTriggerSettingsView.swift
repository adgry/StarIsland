//
//  KeepAwakeTriggerSettingsView.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2026-10-07

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct KeepAwakeTriggerSettingsView: View {
    @EditingSettings var settings: SettingsEditingSession

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("自动保持唤醒").font(.headline).padding([.top, .horizontal])
            Text("满足以下任一条件时将自动开启保持唤醒，所有条件均结束时自动关闭。若你手动关闭保持唤醒，将在本次条件结束前暂停自动触发。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 4)

            if !settings.settings.caffeinateEnabled {
                InfoContainer(
                    text: "上方的“保持唤醒”功能已关闭，因此此处的规则暂不会阻止 Mac 休眠。",
                    iconName: "exclamationmark.triangle",
                    color: .orange
                )
                .padding([.horizontal, .top])
            }

            ToggleRow(
                title: "指定应用运行时",
                description: "只要下方任意应用处于打开状态，即保持唤醒。",
                isOn: $settings.settings.caffeinateWhileAppsRun
            )

            if settings.settings.caffeinateWhileAppsRun {
                KeepAwakeAppList(bundleIDs: $settings.settings.caffeinateTriggerAppBundleIDs)
                    .padding([.horizontal, .bottom])
            }

            Divider().padding(.leading, 20)

            ToggleRow(
                title: "连接电源适配器时",
                description: "只要 Mac 接通电源，即保持唤醒。",
                isOn: $settings.settings.caffeinateWhileOnACPower
            )

            Divider().padding(.leading, 20)

            ToggleRow(
                title: "连接外接显示器时",
                description: "连接物理显示器时保持唤醒（不包含隔空播放与随航显示器）。",
                isOn: $settings.settings.caffeinateWhileExternalDisplay
            )

            Divider().padding(.leading, 20)

            ToggleRow(
                title: "锁屏期间暂停",
                description: "锁屏后允许 Mac 正常休眠（即使仍满足上方条件）；你手动开启的保持唤醒不受影响。",
                isOn: $settings.settings.caffeinatePauseTriggersWhenLocked
            )
        }
        .modifier(SettingsContainerModifier())
    }
}

private struct KeepAwakeAppList: View {
    @Binding var bundleIDs: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if bundleIDs.isEmpty {
                Text("尚未选择任何应用。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(bundleIDs, id: \.self) { bundleID in
                HStack(spacing: 8) {
                    Image(nsImage: Self.icon(for: bundleID))
                        .resizable()
                        .frame(width: 18, height: 18)
                    Text(Self.name(for: bundleID))
                    Spacer()
                    Button {
                        DispatchQueue.main.async {
                            bundleIDs.removeAll { $0 == bundleID }
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("移除 \(Self.name(for: bundleID))")
                }
            }
            Button("添加应用…", action: chooseApps)
                .controlSize(.small)
        }
    }

    private func chooseApps() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "添加"
        guard panel.runModal() == .OK else { return }
        let chosen = panel.urls.compactMap { Bundle(url: $0)?.bundleIdentifier }
        let existing = Set(bundleIDs)
        let additions = chosen.filter { !existing.contains($0) }
        guard !additions.isEmpty else { return }
        bundleIDs.append(contentsOf: Set(additions).sorted())
    }

    private static func name(for bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return bundleID }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    private static func icon(for bundleID: String) -> NSImage {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return NSWorkspace.shared.icon(for: .application)
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}