//
//  OverviewSettingsView.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2026-09-26

import AppKit
import SwiftUI

struct OverviewSettingsView: View {
    @EditingSettings var settings: SettingsEditingSession
    @StateObject private var assistant = SettingsAssistant()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("概览").font(.largeTitle.bold())
                    Text("询问任意设置项、获取优化建议，或让 Sapphire 直接为你修改设置。")
                        .foregroundStyle(.secondary)
                }

                SettingsAssistantCard(assistant: assistant)
                DisplaySettingsView()
            }
            .padding(25)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .onAppear { assistant.attach(settings) }
    }
}

enum SettingsNavigation {
    static func open(_ section: SettingsSection) {
        NotificationCenter.default.post(name: NSNotification.Name("SapphireSelectSection"), object: section.rawValue)
    }
}

// MARK: - Assistant

private struct SettingsAssistantCard: View {
    @ObservedObject var assistant: SettingsAssistant
    @State private var draft = ""
    @FocusState private var isInputFocused: Bool

    private let starters = [
        "没有播放音乐时能隐藏灵动岛吗？",
        "推荐几个能省电的设置",
        "在全屏模式下隐藏实时活动",
        "音乐播放器有哪些可以调整的选项？"
    ]

    var body: some View {
        SettingsCard(title: "询问 Sapphire", description: "通过 Apple 智能在设备端本地运行。修改将立即生效，并可随时撤销。") {
            VStack(alignment: .leading, spacing: 12) {
                if let reason = assistant.unavailableReason {
                    InfoContainer(text: reason, iconName: "apple.intelligence", color: .orange)
                }

                if assistant.messages.isEmpty {
                    starterPrompts
                } else {
                    conversation
                }

                inputBar
            }
            .padding([.horizontal, .bottom])
        }
    }

    private var starterPrompts: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("试试这样问")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 8) {
                ForEach(starters, id: \.self) { starter in
                    Button(starter) { assistant.send(starter) }
                        .buttonStyle(.plain)
                        .font(.callout)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.08), in: Capsule())
                        .disabled(assistant.unavailableReason != nil)
                }
            }
        }
    }

    private var conversation: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(assistant.messages) { message in
                MessageView(message: message, assistant: assistant)
            }
            if assistant.isResponding {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("正在思考…").font(.callout).foregroundStyle(.secondary)
                }
            }
            HStack {
                Spacer()
                Button("清空") { assistant.clearConversation() }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .disabled(assistant.isResponding)
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("询问设置项，或直接说明想修改的内容…", text: $draft)
                .textFieldStyle(.plain)
                .focused($isInputFocused)
                .onSubmit(send)
                .padding(10)
                .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill").font(.system(size: 22))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || assistant.isResponding || assistant.unavailableReason != nil)
            .keyboardShortcut(.return, modifiers: [])
        }
    }

    private func send() {
        let text = draft
        draft = ""
        assistant.send(text)
    }
}

private struct MessageView: View {
    let message: SettingsAssistant.Message
    @ObservedObject var assistant: SettingsAssistant

    var body: some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 60)
                Text(message.text)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.accentColor.opacity(0.25), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        case .assistant:
            VStack(alignment: .leading, spacing: 8) {
                Text(message.text)
                    .textSelection(.enabled)
                    .foregroundStyle(message.isError ? Color.orange : Color.primary)
                ForEach(message.changes) { change in
                    ChangeRow(change: change, isUndone: assistant.undoneChangeIDs.contains(change.id)) {
                        assistant.undo(change)
                    }
                }
                if !message.suggestions.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(message.suggestions) { entry in
                            SettingsEntryRow(entry: entry)
                            if entry != message.suggestions.last { Divider().padding(.leading, 12) }
                        }
                    }
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ChangeRow: View {
    let change: SettingsIndex.Change
    let isUndone: Bool
    let onUndo: () -> Void

    private func displayValue(_ value: SettingsIndex.Value) -> String {
        switch value {
        case .bool(let on): return on ? "开启" : "关闭"
        default: return value.description
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isUndone ? "arrow.uturn.backward.circle" : "checkmark.circle.fill")
                .foregroundStyle(isUndone ? Color.secondary : Color.green)
            Text("\(change.entry.displayTitle)：\(displayValue(change.oldValue)) → \(displayValue(change.newValue))")
                .font(.callout)
                .strikethrough(isUndone)
            Spacer()
            if isUndone {
                Text("已撤销").font(.caption).foregroundStyle(.secondary)
            } else {
                Button("撤销", action: onUndo).buttonStyle(.plain).font(.caption).foregroundStyle(Color.accentColor)
            }
            if let section = change.entry.section {
                Button("打开") { SettingsNavigation.open(section) }
                    .buttonStyle(.plain).font(.caption).foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.green.opacity(isUndone ? 0.03 : 0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct SettingsEntryRow: View {
    @EditingSettings var settings: SettingsEditingSession
    let entry: SettingsIndex.Entry

    private var value: SettingsIndex.Value? {
        SettingsIndex.value(of: entry.key, in: settings.settings.value)
    }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayTitle).font(.callout)
                if let section = entry.section {
                    Text(section.label).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            control
            if let section = entry.section {
                Button {
                    SettingsNavigation.open(section)
                } label: {
                    Image(systemName: "arrow.up.forward.square")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("打开“\(section.label)”设置")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var control: some View {
        switch value {
        case .bool(let on)?:
            SettingsSwitch(title: entry.displayTitle, isOn: Binding(get: { on }, set: { set($0 ? "on" : "off") }))
        case .text(let current)? where entry.options != nil:
            Picker("", selection: Binding(get: { current }, set: { set($0) })) {
                ForEach(entry.options ?? [], id: \.self) { option in
                    Text(SettingsIndex.humanized(option)).tag(option)
                }
            }
            .labelsHidden()
            .frame(maxWidth: 150)
        case let current?:
            Text(current.description).font(.callout.monospacedDigit()).foregroundStyle(.secondary)
        case nil:
            EmptyView()
        }
    }

    private func set(_ raw: String) {
        if case .success(let (updated, _)) = SettingsIndex.applying(key: entry.key, rawValue: raw, to: settings.settings.value) {
            settings.settings.value = updated
        }
    }
}