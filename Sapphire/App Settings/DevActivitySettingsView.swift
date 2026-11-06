//
//  DevActivitySettingsView.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2026-09-12
//

import SwiftUI

struct DevActivitySettingsView: View {
    @EditingSettings var settings: SettingsEditingSession
    @ObservedObject private var monitor = DevActivityMonitor.shared

    private func kindBinding(_ kind: DevTaskKind, keyPath: WritableKeyPath<Settings, Set<String>>) -> Binding<Bool> {
        Binding(
            get: { settings.settings[keyPath: keyPath].contains(kind.rawValue) },
            set: { isOn in
                if isOn {
                    settings.settings[keyPath: keyPath].insert(kind.rawValue)
                } else {
                    settings.settings[keyPath: keyPath].remove(kind.rawValue)
                }
            }
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                Text("开发活动")
                    .font(.largeTitle.bold())
                    .padding(.bottom)

                detectionSection
                whatIsRunningSection
                accuracySection
                stayAwakeSection
                supportedToolsSection
            }
            .padding(25)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onAppear { monitor.refreshNow() }
    }

    // MARK: - Sections

    private var detectionSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ToggleRow(
                title: "在灵动岛中显示运行中的任务",
                description: "当 AI 智能体、构建任务或终端命令运行时，在灵动岛展示实时活动。",
                isOn: $settings.settings.devActivityEnabled
            )

            Divider().padding(.leading, 20)

            ToggleRow(
                title: "AI 智能体",
                description: "支持 Claude、Codex、Cursor、Antigravity、GitHub Copilot、Devin/Windsurf、Gemini、Aider 及其他编程智能体。",
                isOn: kindBinding(.ai, keyPath: \.devActivityKinds)
            )

            Divider().padding(.leading, 20)

            ToggleRow(
                title: "构建与测试",
                description: "支持 Xcode、Android Studio 与 Gradle、Swift、cargo、Go、npm 系列工具、make、Docker 及各类测试运行。",
                isOn: kindBinding(.build, keyPath: \.devActivityKinds)
            )

            Divider().padding(.leading, 20)

            ToggleRow(
                title: "终端命令",
                description: "在终端、iTerm、Warp、Ghostty 或编辑器内置终端中启动的长时间运行命令。文件监听器与开发服务器不会结束，因此会自动忽略。",
                isOn: kindBinding(.command, keyPath: \.devActivityKinds)
            )

            Divider().padding(.leading, 20)

            ToggleRow(
                title: "优先于其他活动显示",
                description: "将运行中的任务提升至与通知同级的优先级（高于常驻信息展示），即使正在播放音乐也能优先显示。",
                isOn: $settings.settings.devActivityHighPriority
            )

            Divider().padding(.leading, 20)

            ToggleRow(
                title: "点击打开详情",
                description: "点击实时活动可查看任务详情：智能体对话记录、命令的终端输出、相关进程，以及可直接回复消息或发送命令的输入框。",
                isOn: $settings.settings.devActivityOpenOnClick
            )

            Divider().padding(.leading, 20)

            ToggleRow(
                title: "开发小组件",
                description: "在灵动岛中展示运行中的任务，以及今日 Claude Code、Codex、Cursor、Antigravity 和 Gemini 的用量统计。点击可打开完整看板与命令运行器。",
                isOn: $settings.settings.devWidgetEnabled
            )
        }
        .modifier(SettingsContainerModifier())
    }

    private var whatIsRunningSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("当前检测到的任务")
                    .font(.system(size: 14, weight: .medium))
                Spacer()
                Button("刷新") { monitor.refreshNow() }
                    .buttonStyle(.borderless)
                    .font(.caption)
            }
            .padding()

            Divider().padding(.leading, 20)

            if monitor.tasks.isEmpty {
                Text(settings.settings.devActivityEnabled || settings.settings.devWidgetEnabled || settings.settings.caffeinateAutoDuringTasks
                     ? "当前没有运行中的任务。启动构建或向智能体发送指令后，任务将显示在这里。"
                     : "检测已关闭。请在上方开启灵动岛活动或任务期间自动保持唤醒以开始监测。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ForEach(monitor.tasks) { task in
                    DevTaskRow(task: task)
                    if task.id != monitor.tasks.last?.id {
                        Divider().padding(.leading, 20)
                    }
                }
            }
        }
        .modifier(SettingsContainerModifier())
    }

    private var accuracySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ToggleRow(
                title: "检测编辑器内置智能体",
                description: "Cursor、Antigravity、Devin、VS Code 和 Zed 的智能体运行在编辑器主进程内，因此需根据进程负载推断活跃状态。如果普通打字被误判为智能体运行，可关闭此项。",
                isOn: $settings.settings.devActivityDetectIDEAgents
            )

            Divider().padding(.leading, 20)

            VStack(alignment: .leading, spacing: 4) {
                CustomSliderRowView(
                    label: "灵敏度",
                    value: $settings.settings.devActivitySensitivity,
                    range: 0.4...2.0,
                    specifier: "%.1f×"
                )
                Text("较低的值能捕捉更轻微的任务，但可能将繁忙的编辑器误判为运行中的智能体；较高的值仅报告持续的高负载活动。仅在运行期间存在的命令行工具不受此项影响。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .modifier(SettingsContainerModifier())
    }

    private var stayAwakeSection: some View { CaffeineAutoTaskSettingsView() }

    private var supportedToolsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("检测工作原理")
                .font(.system(size: 14, weight: .medium))

            Text("""
            Sapphire 仅监测你本人的进程——不会读取应用内部数据，无需辅助功能权限，所有数据均不会离开这台 Mac。

            仅在运行期间存在的工具（如 xcodebuild、cargo、gradle、npm run build 或你手动输入的命令）会在启动瞬间被立即识别；常驻后台的工具（如 Claude、Codex、编辑器内置智能体或 Gradle 守护进程）仅在实际工作时才会被报告，这也是设置“灵敏度”的原因。
            """)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(SettingsContainerModifier())
    }
}

private struct DevTaskRow: View {
    let task: DevTask

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: task.tool.symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(task.tool.tint)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 13, weight: .medium))
                HStack(spacing: 6) {
                    Text(task.kind.displayName)
                    if !task.detail.isEmpty {
                        Text("·")
                        Text(task.detail)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(DevTaskFormatting.elapsed(task.elapsed))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

enum DevTaskFormatting {
    static func elapsed(_ interval: TimeInterval) -> String {
        let total = Int(max(0, interval))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, seconds) }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct CaffeineAutoTaskSettingsView: View {
    @EditingSettings var settings: SettingsEditingSession
    @ObservedObject private var monitor = DevActivityMonitor.shared

    private var unmonitoredKinds: [DevTaskKind] {
        DevTaskKind.allCases.filter {
            settings.settings.caffeinateAutoTaskKinds.contains($0.rawValue)
                && !settings.settings.devActivityKinds.contains($0.rawValue)
        }
    }

    private var runningSummary: String {
        let kinds = settings.settings.caffeinateAutoTaskKinds
        let relevant = monitor.tasks.filter { kinds.contains($0.kind.rawValue) }
        guard let first = relevant.first else { return "无运行中的任务" }
        if relevant.count == 1 { return first.title }
        return "\(first.title) 及另外 \(relevant.count - 1) 项"
    }

    private func kindBinding(_ kind: DevTaskKind) -> Binding<Bool> {
        Binding(
            get: { settings.settings.caffeinateAutoTaskKinds.contains(kind.rawValue) },
            set: { isOn in
                if isOn {
                    settings.settings.caffeinateAutoTaskKinds.insert(kind.rawValue)
                } else {
                    settings.settings.caffeinateAutoTaskKinds.remove(kind.rawValue)
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ToggleRow(
                title: "任务运行期间保持唤醒",
                description: "当 AI 智能体、构建任务或终端命令开始时自动开启保持唤醒，并在所有任务完成后自动关闭。你手动开启的保持唤醒绝不会被此功能关闭。",
                isOn: $settings.settings.caffeinateAutoDuringTasks
            )

            if settings.settings.caffeinateAutoDuringTasks {
                Divider().padding(.leading, 20)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("当前检测到")
                        Text(runningSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Circle()
                        .fill(monitor.isBusy ? Color.green : Color.secondary.opacity(0.4))
                        .frame(width: 8, height: 8)
                }
                .padding()

                Divider().padding(.leading, 20)

                ToggleRow(title: "AI 智能体", description: "", isOn: kindBinding(.ai))

                Divider().padding(.leading, 20)

                ToggleRow(title: "构建与测试", description: "", isOn: kindBinding(.build))

                Divider().padding(.leading, 20)

                ToggleRow(
                    title: "终端命令",
                    description: "",
                    isOn: kindBinding(.command)
                )

                Divider().padding(.leading, 20)

                VStack(alignment: .leading, spacing: 4) {
                    CustomSliderRowView(
                        label: "任务结束后继续保持唤醒",
                        value: $settings.settings.caffeinateAutoTaskGrace,
                        range: 0...600,
                        specifier: "%.0fs"
                    )
                    Text("最后一个任务结束后的缓冲时间，避免连续执行任务间隙屏幕进入睡眠。检测相关设置位于“开发活动”面板中。")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !unmonitoredKinds.isEmpty {
                        Label(
                            "\(unmonitoredKinds.map(\.displayName).joined(separator: "、"))在“开发活动”中处于关闭状态，因此该类任务不会触发保持唤醒。",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(.orange)
                    }
                }
                .padding()
            }
        }
        .modifier(SettingsContainerModifier())
        .onAppear { monitor.refreshNow() }
    }
}