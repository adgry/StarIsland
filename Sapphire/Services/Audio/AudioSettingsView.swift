//
//  AudioSettingsView.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2026-08-10

import SwiftUI

struct AudioSettingsView: View {
    @EditingSettings var settings: SettingsEditingSession
    @ObservedObject private var audioManager = MultiAudioManager.shared
    @ObservedObject private var permissionsManager = PermissionsManager.shared
    @State private var showResetAppConfirmation = false
    @State private var showResetDeviceConfirmation = false
    @State private var mixerNavigationStack: [NotchWidgetMode] = []
    @State private var selectedAdjustment: AudioSettingsAdjustment?
    @AppStorage(AudioEQ.displayedBandCountDefaultsKey) private var displayedBandCount = AudioEQBandLayout.thirtyOne.rawValue

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                Text("音频")
                    .font(.largeTitle.bold())
                    .padding(.bottom, 4)

                VStack(alignment: .leading, spacing: 0) {
                    Text("灵动岛")
                        .font(.headline)
                        .padding([.top, .horizontal])

                    CompactToggleRow(
                        title: "灵动岛多路音频",
                        description: "在展开的灵动岛中显示分应用混音器。",
                        isOn: Binding(
                            get: { settings.settings.notchButtonOrder.contains(.multiAudio) },
                            set: { enabled in
                                if enabled && !settings.settings.notchButtonOrder.contains(.multiAudio) {
                                    settings.settings.notchButtonOrder.append(.multiAudio)
                                } else if !enabled {
                                    settings.settings.notchButtonOrder.removeAll { $0 == .multiAudio }
                                }
                            }
                        )
                    )
                    .disabled(permissionsManager.screenRecordingStatus != .granted)
                    Divider().padding(.leading, 20)
                    CompactToggleRow(
                        title: "触感反馈",
                        description: "调节音频控件时提供轻微振动反馈。",
                        isOn: $settings.settings.hapticFeedbackEnabled
                    )
                    Divider().padding(.leading, 20)
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("均衡器频段")
                            Text("选择应用与设备均衡器中显示的频段控制数量。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Picker("均衡器频段", selection: $displayedBandCount) {
                            ForEach(AudioEQBandLayout.allCases) { layout in
                                Text(layout.displayName).tag(layout.rawValue)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 110)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                .modifier(SettingsContainerModifier())

                MicrophoneAmplifierSettingsView()
                    .modifier(SettingsContainerModifier())

                AudioSwitchingSettingsView()
                    .modifier(SettingsContainerModifier())

                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("应用与设备混音器")
                            .font(.headline)
                        Text("提供与灵动岛中相同的音量、音频路由、均衡器、8D 音效、环绕声、声道平衡及延迟控制。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                    SystemAudioPanel(navigationStack: $mixerNavigationStack)
                        .frame(maxWidth: .infinity)
                        .frame(height: 430)
                }
                .modifier(SettingsContainerModifier())

                VStack(alignment: .leading, spacing: 0) {
                    Text("重置")
                        .font(.headline)
                        .padding([.top, .horizontal])

                    AudioResetRow(
                        title: "重置分应用音频调节",
                        subtitle: "清除所有应用的自定义音量、静音、均衡器及 8D 空间音频设置。",
                        buttonTitle: "重置应用",
                        buttonColor: .red
                    ) {
                        showResetAppConfirmation = true
                    }
                    .alert("重置分应用设置？", isPresented: $showResetAppConfirmation) {
                        Button("取消", role: .cancel) { }
                        Button("重置", role: .destructive) { resetAllAppSettings() }
                    } message: {
                        Text("这将为所有应用恢复默认音量、平直均衡器、环绕声及 8D 音效设置。")
                    }

                    Divider().padding(.leading, 20)

                    AudioResetRow(
                        title: "重置设备设置",
                        subtitle: "清除所有设备的主音量、声道平衡、延迟及均衡器设置。",
                        buttonTitle: "重置设备",
                        buttonColor: .red
                    ) {
                        showResetDeviceConfirmation = true
                    }
                    .alert("重置设备设置？", isPresented: $showResetDeviceConfirmation) {
                        Button("取消", role: .cancel) { }
                        Button("重置", role: .destructive) { resetAllDeviceSettings() }
                    } message: {
                        Text("这将把所有已连接的输出设备恢复为默认状态。")
                    }
                }
                .modifier(SettingsContainerModifier())

                RequiredPermissionsView(section: .audio)
            }
            .padding(25)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onChange(of: permissionsManager.screenRecordingStatus) { _, newStatus in
            if newStatus == .granted, !settings.settings.notchButtonOrder.contains(.multiAudio) {
                settings.settings.notchButtonOrder.append(.multiAudio)
            }
        }
        .onChange(of: mixerNavigationStack.count) { _, _ in
            presentLatestMixerAdjustment()
        }
        .sheet(item: $selectedAdjustment) { adjustment in
            AudioSettingsAdjustmentSheet(adjustment: adjustment)
        }
    }

    private func presentLatestMixerAdjustment() {
        guard let destination = mixerNavigationStack.last else { return }
        mixerNavigationStack.removeAll()

        switch destination {
        case .multiAudioDeviceAdjust(let device):
            selectedAdjustment = .deviceAdjust(device)
        case .multiAudioEQ(let device):
            selectedAdjustment = .deviceEQ(device)
        case .earbudControls(let device):
            selectedAdjustment = .earbudControls(device)
        case .multiAudioAppEQ(let bundleID, let appName):
            selectedAdjustment = .appEQ(bundleID: bundleID, appName: appName)
        case .multiAudioApp8D(let bundleID, let appName):
            selectedAdjustment = .app8D(bundleID: bundleID, appName: appName)
        case .multiAudioAppSurround(let bundleID, let appName):
            selectedAdjustment = .appSurround(bundleID: bundleID, appName: appName)
        default:
            break
        }
    }

    private func resetAllAppSettings() {
        Task { @MainActor in
            PerAppAudioController.shared.clearAllPersistedState()
            MultiAudioManager.shared.clearAllEightDAudioSettings()
            MultiAudioManager.shared.resetAllTaps()
        }
    }

    private func resetAllDeviceSettings() {
        Task { @MainActor in
            MultiAudioManager.shared.clearAllDeviceSettings()
        }
    }
}

private enum AudioSettingsAdjustment: Identifiable {
    case deviceAdjust(AudioDevice)
    case deviceEQ(AudioDevice)
    case earbudControls(AudioDevice)
    case appEQ(bundleID: String, appName: String)
    case app8D(bundleID: String, appName: String)
    case appSurround(bundleID: String, appName: String)

    var id: String {
        switch self {
        case .deviceAdjust(let device):
            return "device-adjust-\(device.id)"
        case .deviceEQ(let device):
            return "device-eq-\(device.id)"
        case .earbudControls(let device):
            return "earbuds-\(device.id)"
        case .appEQ(let bundleID, _):
            return "app-eq-\(bundleID)"
        case .app8D(let bundleID, _):
            return "app-8d-\(bundleID)"
        case .appSurround(let bundleID, _):
            return "app-surround-\(bundleID)"
        }
    }
}

private struct AudioSettingsAdjustmentSheet: View {
    let adjustment: AudioSettingsAdjustment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("音频调节")
                    .font(.headline)
                Spacer()
                Button("完成") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .frame(height: 48)

            Divider()

            adjustmentView
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var adjustmentView: some View {
        switch adjustment {
        case .deviceAdjust(let device):
            DeviceAdjustView(device: device)
        case .deviceEQ(let device):
            DeviceEQView(device: device)
        case .earbudControls(let device):
            EarbudControlsView(device: device)
        case .appEQ(let bundleID, let appName):
            AppEQView(bundleID: bundleID, appName: appName)
        case .app8D(let bundleID, let appName):
            EightDAudioView(bundleID: bundleID, appName: appName)
        case .appSurround(let bundleID, let appName):
            SurroundAudioView(bundleID: bundleID, appName: appName)
        }
    }
}

// MARK: - Microphone gain preview

private struct MicrophoneAmplifierSettingsView: View {
    @ObservedObject private var mic = MicrophoneUsageManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("麦克风增益预览")
                .font(.headline)
                .padding([.top, .horizontal])

            CompactToggleRow(
                title: "增益预览",
                description: "对 Sapphire 的实时电平表应用增益以便检查削波失真，其他应用仍接收原始麦克风信号。",
                isOn: $mic.amplifierEnabled
            )

            Divider().padding(.leading, 20)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("预览增益")
                    Spacer()
                    Text("×\(mic.amplifierGain, specifier: "%.1f")")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Slider(value: $mic.amplifierGain, in: 1...4, step: 0.1)
                    .tint(.orange)
                    .disabled(!mic.amplifierEnabled)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider().padding(.leading, 20)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(mic.isClipping ? "检测到削波失真" : "实时输入电平", systemImage: mic.isClipping ? "exclamationmark.triangle.fill" : "mic.fill")
                        .foregroundStyle(mic.isClipping ? .red : .primary)
                    Spacer()
                    Text("\(Int(mic.audioLevel * 100))%")
                        .font(.caption.monospacedDigit())
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.18))
                        Capsule()
                            .fill(mic.isClipping ? Color.red : (mic.audioLevel > 0.85 ? Color.orange : Color.green))
                            .frame(width: proxy.size.width * CGFloat(mic.audioLevel))
                        Rectangle()
                            .fill(Color.red.opacity(0.8))
                            .frame(width: 2)
                            .offset(x: max(0, proxy.size.width - 2))
                    }
                }
                .frame(height: 8)
                Text(mic.isMicInUse ? (mic.isClipping ? "请降低增益或麦克风输入电平。" : "峰值：\(Int(mic.peakLevel * 100))%") : "开始使用麦克风后即可查看实时电平。")
                    .font(.caption)
                    .foregroundStyle(mic.isClipping ? .red : .secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .onAppear { mic.beginMetering() }
        .onDisappear { mic.endMetering() }
    }
}

// MARK: - Rows

private struct AudioResetRow: View {
    let title: String
    let subtitle: String
    let buttonTitle: String
    let buttonColor: Color
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button(buttonTitle, action: action)
                .buttonStyle(.bordered)
                .tint(buttonColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
// MARK: - Output switching & microphone

private struct AudioSwitchingSettingsView: View {
    @ObservedObject private var switcher = AudioOutputSwitcher.shared
    @ObservedObject private var audio = MultiAudioManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("输出切换与麦克风")
                .font(.headline)
                .padding([.top, .horizontal])

            AudioShortcutRow(
                title: "循环切换输出设备",
                subtitle: "将下方列表中的下一个输出设备设为系统默认输出。",
                identifier: "audioOutputCycleShortcut",
                shortcut: $switcher.cycleShortcut
            )

            if !audio.availableOutputDevices.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("参与循环切换的输出设备")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(audio.availableOutputDevices) { device in
                        Toggle(device.name, isOn: cycleBinding(for: device.uid))
                            .toggleStyle(.checkbox)
                            .font(.system(size: 12))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }

            Divider().padding(.leading, 20)

            CompactToggleRow(
                title: "耳机断开时自动降低音量",
                description: "耳机断开时将扬声器降至安全音量，并在耳机重新连接时恢复原音量。",
                isOn: $switcher.lowerVolumeOnHeadphoneDisconnect
            )
            HStack {
                Text("扬声器音量")
                Slider(value: $switcher.headphoneDisconnectLevel, in: 0...0.8, step: 0.05)
                Text("\(Int(switcher.headphoneDisconnectLevel * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .trailing)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
            .disabled(!switcher.lowerVolumeOnHeadphoneDisconnect)

            Divider().padding(.leading, 20)

            AudioShortcutRow(
                title: "麦克风静音",
                subtitle: "切换所有输入设备的静音状态。",
                identifier: "microphoneMuteShortcut",
                shortcut: $switcher.micMuteShortcut
            )

            Divider().padding(.leading, 20)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("首选麦克风")
                    Text("即使连接了自带麦克风的耳机，也始终保持该设备作为系统输入。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("首选麦克风", selection: preferredInputBinding) {
                    Text("系统默认").tag(String?.none)
                    ForEach(audio.availableInputDevices) { device in
                        Text(device.name).tag(String?.some(device.uid))
                    }
                    if let preferred = audio.preferredInputUID,
                       !audio.availableInputDevices.contains(where: { $0.uid == preferred }) {
                        Text("已断开的设备").tag(String?.some(preferred))
                    }
                }
                .labelsHidden()
                .frame(width: 200)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    private func cycleBinding(for uid: String) -> Binding<Bool> {
        Binding(
            get: { switcher.cycleDeviceUIDs.isEmpty || switcher.cycleDeviceUIDs.contains(uid) },
            set: { included in
                var uids = switcher.cycleDeviceUIDs.isEmpty ? audio.availableOutputDevices.map(\.uid) : switcher.cycleDeviceUIDs
                if included {
                    if !uids.contains(uid) { uids.append(uid) }
                } else {
                    uids.removeAll { $0 == uid }
                }
                switcher.cycleDeviceUIDs = uids
            }
        )
    }

    private var preferredInputBinding: Binding<String?> {
        Binding(
            get: { audio.preferredInputUID },
            set: { uid in
                if let uid, let device = audio.availableInputDevices.first(where: { $0.uid == uid }) {
                    audio.selectInputDevice(device)
                } else if uid == nil {
                    audio.clearPreferredInput()
                }
            }
        )
    }
}

private struct AudioShortcutRow: View {
    let title: String
    let subtitle: String
    let identifier: String
    @Binding var shortcut: KeyboardShortcut?
    @ObservedObject private var recorder = GlobalShortcutRecorder.shared

    private var isRecordingThis: Bool {
        recorder.isRecording && recorder.recordingIdentifier == identifier
    }

    private var shortcutText: String {
        guard let shortcut else { return "未设置" }
        var text = ""
        if shortcut.modifiers.contains(.control) { text += "⌃" }
        if shortcut.modifiers.contains(.option) { text += "⌥" }
        if shortcut.modifiers.contains(.shift) { text += "⇧" }
        if shortcut.modifiers.contains(.command) { text += "⌘" }
        return text + shortcut.key
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(isRecordingThis ? "请按下快捷键…" : shortcutText)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(shortcut == nil && !isRecordingThis ? .secondary : .primary)
            Button(isRecordingThis ? "取消" : "录制") {
                if isRecordingThis {
                    recorder.stopRecording()
                } else if !recorder.isRecording {
                    recorder.startRecording(identifier: identifier) { key, flags in
                        shortcut = KeyboardShortcut(key: key, modifiers: flags)
                    }
                }
            }
            .buttonStyle(.bordered)
            if shortcut != nil {
                Button("清除") { shortcut = nil }
                    .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}