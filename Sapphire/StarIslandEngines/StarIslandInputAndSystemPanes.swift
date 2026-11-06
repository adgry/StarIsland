//
//  StarIslandInputAndSystemPanes.swift
//  Sapphire
//

#if !SAPPHIRE_FULL_BUILD
import AppKit
import SwiftUI

struct KeyboardShortcutsSettingsView: View {
    @ObservedObject private var model = SettingsModel.shared
    @State private var newTrigger: String = ""
    @State private var newReplacement: String = ""

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                SettingsCard(title: "输入防抖与超级键", description: "过滤机械键盘连击抖动，或将单键映射为 Hyper 超级修饰键。") {
                    ToggleRow(title: "启用键盘输入防抖", description: "自动过滤短于阈值的重复触发信号", isOn: $model.settings.keyboardDebounceEnabled)
                    if model.settings.keyboardDebounceEnabled {
                        Divider().padding(.leading, 16)
                        HStack {
                            Text("防抖阈值：\(Int((model.settings.keyboardDebounceInterval * 1000).rounded())) ms")
                                .font(.system(size: 13))
                            Spacer()
                            Slider(value: $model.settings.keyboardDebounceInterval, in: 0.01...0.15, step: 0.005)
                                .frame(width: 180)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                    }
                    Divider().padding(.leading, 16)
                    ToggleRow(title: "启用 Hyper 超级键", description: "将选定按键映射为 ⌃⌥⌘⇧ 组合修饰键", isOn: $model.settings.superKeyEnabled)
                }

                SettingsCard(title: "文本片段快捷展开", description: "输入简短触发词后自动替换为常用长文本。") {
                    ToggleRow(title: "启用文本片段展开", description: "全局监听并展开自定义短语", isOn: $model.settings.snippetsEnabled)
                    Divider().padding(.leading, 16)
                    ToggleRow(title: "敲击空格后触发", description: "避免输入词根时误触发替换", isOn: $model.settings.snippetsExpandAfterSpace)
                    Divider().padding(.leading, 16)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            TextField("触发词（如 ;mail）", text: $newTrigger)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 140)
                            TextField("展开内容", text: $newReplacement)
                                .textFieldStyle(.roundedBorder)
                            Button("添加") {
                                let t = newTrigger.trimmingCharacters(in: .whitespacesAndNewlines)
                                let r = newReplacement.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !t.isEmpty, !r.isEmpty else { return }
                                model.settings.snippetsList.append(SnippetEntry(trigger: t, replacement: r))
                                newTrigger = ""
                                newReplacement = ""
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        ForEach(model.settings.snippetsList) { entry in
                            HStack {
                                Text(entry.trigger)
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color.accentColor.opacity(0.15), in: Capsule())
                                Text(entry.replacement)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Spacer()
                                Button(role: .destructive) {
                                    model.settings.snippetsList.removeAll { $0.id == entry.id }
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    .padding(16)
                }

                SettingsCard(title: "灵动岛快捷动作", description: "立即唤起常用全局效率工具。") {
                    HStack(spacing: 12) {
                        Button("启动画圈搜屏 OCR") {
                            CircleToSearchManager.shared.startInteractiveSelection()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("立即净化剪贴板链接") {
                            CleanURLManager.shared.cleanClipboardLinkNow()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(16)
                }
            }
            .padding(24)
        }
    }
}

struct EmojiSettingsView: View {
    @ObservedObject private var model = SettingsModel.shared

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                SettingsCard(title: "表情符号快捷输入", description: "通过冒号联想与全局面板快速插入 Emoji。") {
                    ToggleRow(title: "启用表情符号增强", description: "开启全局表情符号快速检索与输入", isOn: $model.settings.emojiEnabled)
                    Divider().padding(.leading, 16)
                    ToggleRow(title: "输入冒号 (:) 自动联想", description: "输入 :smile 等英文或拼音关键字时弹出候选", isOn: $model.settings.emojiSuggestOnColon)
                    Divider().padding(.leading, 16)
                    HStack {
                        Text("默认肤色偏好")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        Picker("", selection: $model.settings.emojiSkinTone) {
                            ForEach(EmojiSkinTone.allCases) { tone in
                                Text(tone.displayName).tag(tone)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 150)
                    }
                    .padding(16)
                }
            }
            .padding(24)
        }
    }
}

struct MouseSettingsView: View {
    @ObservedObject private var model = SettingsModel.shared

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                SettingsCard(title: "滚动与指针优化", description: "独立调节外接鼠标滚动方向、平滑惯性与指针加速度。") {
                    ToggleRow(title: "启用鼠标增强引擎", description: "接管第三方鼠标滚轮与侧键行为", isOn: $model.settings.mouseControlEnabled)
                    Divider().padding(.leading, 16)
                    ToggleRow(title: "反转垂直滚动方向", description: "使外接滚轮保持传统自然/非自然方向而不影响触控板", isOn: $model.settings.mouseInvertScroll)
                    Divider().padding(.leading, 16)
                    ToggleRow(title: "启用平滑惯性滚动", description: "为离散滚轮提供丝滑帧率插值", isOn: $model.settings.mouseSmoothScrollEnabled)
                    Divider().padding(.leading, 16)
                    ToggleRow(title: "禁用指针曲线加速", description: "提供 1:1 线性精准定位体验", isOn: $model.settings.mouseDisableAcceleration)
                    Divider().padding(.leading, 16)
                    HStack {
                        Text("滚轮速度倍率：\(String(format: "%.1fx", model.settings.mouseScrollSpeed))")
                            .font(.system(size: 13))
                        Spacer()
                        Slider(value: $model.settings.mouseScrollSpeed, in: 0.3...4.0, step: 0.1)
                            .frame(width: 180)
                    }
                    .padding(16)
                }

                SettingsCard(title: "微动防双击与焦点跟随", description: "修复鼠标微动老化双击并提升多窗口切换效率。") {
                    ToggleRow(title: "过滤微动误触发双击", description: "自动屏蔽间隔过短的异常微动弹跳点击", isOn: $model.settings.mouseExtraClickFilterEnabled)
                    if model.settings.mouseExtraClickFilterEnabled {
                        Divider().padding(.leading, 16)
                        HStack {
                            Text("防抖间隔：\(Int((model.settings.mouseExtraClickFilterInterval * 1000).rounded())) ms")
                                .font(.system(size: 13))
                            Spacer()
                            Slider(value: $model.settings.mouseExtraClickFilterInterval, in: 0.015...0.12, step: 0.005)
                                .frame(width: 180)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                    }
                    Divider().padding(.leading, 16)
                    ToggleRow(title: "窗口焦点跟随鼠标悬停", description: "光标移入窗口延迟后自动激活对应窗口", isOn: $model.settings.mouseFocusFollowsEnabled)
                }
            }
            .padding(24)
        }
    }
}

struct MonitoringSettingsView: View {
    @ObservedObject private var model = SettingsModel.shared

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                SettingsCard(title: "菜单栏实时读数", description: "在菜单栏实时显示处理器、内存与网络吞吐指标。") {
                    ToggleRow(title: "显示菜单栏硬件监控", description: "在顶部状态栏呈现精简实时性能指标", isOn: $model.settings.monitoringMenuBarReadoutsEnabled)
                    Divider().padding(.leading, 16)
                    ToggleRow(title: "显示 CPU 负载", isOn: $model.settings.monitoringReadoutShowCPU)
                    Divider().padding(.leading, 16)
                    ToggleRow(title: "显示内存占用", isOn: $model.settings.monitoringReadoutShowMemory)
                    Divider().padding(.leading, 16)
                    ToggleRow(title: "显示实时网速", isOn: $model.settings.monitoringReadoutShowNetwork)
                }

                SettingsCard(title: "异常阈值灵动岛预警", description: "当硬件负载或剩余空间触及警戒线时在灵动岛发出提醒。") {
                    ToggleRow(title: "启用系统健康预警", isOn: $model.settings.monitoringAlertsEnabled)
                    Divider().padding(.leading, 16)
                    HStack {
                        Text("CPU 持续高负载阈值：\(Int(model.settings.monitoringAlertCPUThreshold))%")
                            .font(.system(size: 13))
                        Spacer()
                        Slider(value: $model.settings.monitoringAlertCPUThreshold, in: 60...99, step: 1)
                            .frame(width: 180)
                    }
                    .padding(16)
                    Divider().padding(.leading, 16)
                    HStack {
                        Text("磁盘剩余空间预警：\(Int(model.settings.monitoringAlertDiskThresholdGB)) GB")
                            .font(.system(size: 13))
                        Spacer()
                        Slider(value: $model.settings.monitoringAlertDiskThresholdGB, in: 5...100, step: 5)
                            .frame(width: 180)
                    }
                    .padding(16)
                }
            }
            .padding(24)
        }
    }
}

struct SEQuitProtectionRulesView: View {
    @ObservedObject private var model = SettingsModel.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider().padding(.leading, 16)
            ToggleRow(title: "保护 ⌘Q 退出应用", description: "防止误按 Command+Q 导致工作丢失", isOn: $model.settings.systemEnhanceQuitProtectionProtectQuit, style: .compact)
            Divider().padding(.leading, 16)
            ToggleRow(title: "保护 ⌘W 关闭窗口", description: "对受保护窗口启用二次确认或长按关闭", isOn: $model.settings.systemEnhanceQuitProtectionProtectClose, style: .compact)
            Divider().padding(.leading, 16)
            HStack {
                Text("长按触发时长：\(String(format: "%.1f 秒", model.settings.systemEnhanceQuitProtectionHoldInterval))")
                    .font(.system(size: 13))
                Spacer()
                Slider(value: $model.settings.systemEnhanceQuitProtectionHoldInterval, in: 0.4...3.0, step: 0.1)
                    .frame(width: 170)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
    }
}
#endif
