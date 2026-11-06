//
//  EarbudControlsView.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2026-09-21

import SwiftUI

struct EarbudControlsView: View {
    var device: AudioDevice? = nil
    @ObservedObject private var manager = EarbudControlManager.shared
    @State private var finding = false

    private var snap: EarbudControlSnapshot { manager.snapshot }

    private var bandCount: Int { snap.vendor == .sony ? 5 : 9 }

    private var frequencies: [Double] {
        snap.vendor == .sony
            ? [400, 1_000, 2_500, 6_300, 16_000]
            : [60, 150, 300, 600, 1_000, 2_500, 4_000, 6_000, 8_000]
    }

    private var eqPresets: [(String, String)] {
        snap.vendor == .sony
            ? [
                ("关闭", "off"), ("明亮", "bright"), ("激昂", "excited"),
                ("柔和", "mellow"), ("轻松", "relaxed"), ("人声", "vocal"),
                ("低音增强", "bassBoost"), ("高音增强", "trebleBoost"),
                ("演讲", "speech"), ("手动", "custom")
            ]
            : [
                ("正常", "off"), ("低音增强", "bassBoost"), ("柔和", "soft"),
                ("动态", "dynamic"), ("清澈", "clear"), ("高音增强", "trebleBoost"),
                ("自定义", "custom")
            ]
    }

    private var noiseModes: [(String, String, String)] {
        var modes: [(String, String, String)] = [
            ("关闭", "off", "speaker.slash.fill"),
            ("主动降噪", "anc", "ear.badge.waveform"),
            ("环境音", "ambient", "ear")
        ]
        if snap.supportsAdaptive {
            modes.append(("自适应", "adaptive", "waveform.path"))
        }
        return modes
    }

    private var eqGainsBinding: Binding<[Double]> {
        Binding(
            get: {
                let raw = snap.customEQBands
                return (0..<bandCount).map { Double(raw.indices.contains($0) ? raw[$0] : 0) }
            },
            set: { values in
                manager.setCustomEQ(values.map { Int($0.rounded()) })
            }
        )
    }

    private var bassBinding: Binding<Double> {
        Binding(
            get: { Double(snap.bassGain) },
            set: { manager.setBass(Int($0.rounded())) }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 10)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    if snap.supportsANC {
                        noiseSection
                    }
                    if snap.supportsEQ {
                        eqSection
                    }
                    extrasSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
        .frame(width: 600, height: 446)
        .background(Color.black)
        .clipShape(Rectangle())
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: snap.noiseMode)
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: snap.eqPreset)
        .onAppear {
            if let device {
                manager.present(for: device)
            } else {
                manager.presentCurrent()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(snap.vendor == .sony ? "Sony 耳机" : "Galaxy Buds")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(1.2)
                Text(snap.name.isEmpty ? (device?.name ?? snap.vendor.displayName) : snap.name)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 6) {
                    statusPill
                    Image(systemName: snap.vendor == .sony ? "headphones" : "earbuds")
                        .font(.title3)
                        .foregroundStyle(snap.connected ? Color.accentColor : .white.opacity(0.35))
                }
                batteryRow
            }
        }
    }

    private var statusPill: some View {
        Text(statusLabel)
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(Capsule().fill(snap.connected ? Color.green.opacity(0.22) : Color.white.opacity(0.08)))
            .foregroundStyle(snap.connected ? Color.green : .secondary)
    }

    private var statusLabel: String {
        if snap.connected {
            return snap.ownedLocally ? "此 Mac" : "手机端"
        }
        return "空闲"
    }

    @ViewBuilder
    private var batteryRow: some View {
        HStack(spacing: 5) {
            if snap.batteryLeft > 0 || snap.batteryRight > 0 {
                batteryBadge("左", snap.batteryLeft)
                batteryBadge("右", snap.batteryRight)
                if snap.batteryCase > 0 { batteryBadge("充电盒", snap.batteryCase) }
            } else if snap.batteryMain > 0 {
                batteryBadge("电量", snap.batteryMain)
            }
        }
    }

    private func batteryBadge(_ label: String, _ percent: Int) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
            Text("\(percent)%")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(percent <= 15 ? Color.orange : .white.opacity(0.85))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(Capsule().fill(Color.white.opacity(0.06)))
    }

    // MARK: - Noise

    private var noiseSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("噪声控制")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(noiseModes, id: \.1) { title, wire, icon in
                        Button {
                            manager.setNoise(wire)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: icon)
                                    .font(.system(size: 11, weight: .semibold))
                                Text(title)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(snap.noiseMode == wire ? Color.accentColor : Color.white.opacity(0.1))
                            .foregroundColor(snap.noiseMode == wire ? .white : .primary)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if snap.noiseMode == "anc", snap.vendor == .galaxy {
                HStack(spacing: 8) {
                    Text("降噪强度")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    ModernChip(title: "低", isSelected: !snap.ancHigh) { manager.setAncHigh(false) }
                    ModernChip(title: "高", isSelected: snap.ancHigh) { manager.setAncHigh(true) }
                }
            } else if snap.noiseMode == "ambient" {
                EarbudAmbientSlider(
                    level: Binding(
                        get: { Double(snap.ambientLevel) },
                        set: { manager.setAmbientLevel(Int($0.rounded())) }
                    ),
                    range: snap.vendor == .sony ? 1...20 : 0...4
                )
            }
        }
    }

    // MARK: - EQ

    private var eqSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("均衡器")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(eqPresets, id: \.1) { title, wire in
                        ModernChip(title: title, isSelected: snap.eqPreset == wire) {
                            manager.setEQ(wire)
                        }
                    }
                }
            }

            VStack(spacing: 6) {
                WaveformEQView(gains: eqGainsBinding, range: -10...10)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: snap.customEQBands)
                    .frame(height: 110)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.black.opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(.white.opacity(0.1), lineWidth: 1)
                            )
                    )

                EQFrequencyAxis(frequencies: frequencies)

                if snap.vendor == .sony {
                    EQBassControl(bassGain: bassBinding, bandGains: eqGainsBinding.wrappedValue)
                }
            }
        }
    }

    // MARK: - Extras (compact, matches EQ chrome)

    private var extrasSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("更多功能")

            VStack(spacing: 0) {
                if snap.supportsDSEE {
                    compactToggle(
                        title: "DSEE Extreme",
                        detail: "提升压缩音频音质",
                        symbol: "waveform.badge.plus",
                        isOn: Binding(get: { snap.dsee }, set: { manager.setDsee($0) })
                    )
                }
                if snap.supportsSeamless {
                    if snap.supportsDSEE { extrasDivider }
                    compactToggle(
                        title: "无缝连接",
                        detail: "同时保持与 Mac 和手机连接",
                        symbol: "antenna.radiowaves.left.and.right",
                        isOn: Binding(get: { snap.seamless }, set: { manager.setSeamless($0) })
                    )
                }
                if snap.vendor == .galaxy {
                    if snap.supportsDSEE || snap.supportsSeamless {
                        extrasDivider
                    }
                    if snap.supportsDetectConversations {
                        compactToggle(
                            title: "语音检测",
                            detail: "开始说话时自动切换至环境音",
                            symbol: "person.wave.2.fill",
                            isOn: Binding(get: { snap.detectConversations }, set: { manager.setDetectConversations($0) })
                        )
                        if snap.detectConversations {
                            extrasDivider
                            HStack(spacing: 8) {
                                Text("恢复时间")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                ForEach([(0, "5 秒"), (1, "10 秒"), (2, "15 秒")], id: \.0) { item in
                                    Button(item.1) {
                                        manager.setDetectConversationsDuration(item.0)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(snap.detectConversationsDuration == item.0 ? .accentColor : .secondary)
                                    .controlSize(.small)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                    if snap.supportsGaming {
                        if snap.supportsDetectConversations { extrasDivider }
                        compactToggle(
                            title: "游戏模式",
                            detail: "降低游戏与视频音频延迟",
                            symbol: "gamecontroller.fill",
                            isOn: Binding(get: { snap.gamingMode }, set: { manager.setGamingMode($0) })
                        )
                    }
                    if snap.supportsSpatial {
                        extrasDivider
                        compactToggle(
                            title: "空间音频",
                            detail: "在耳机上呈现沉浸式空间音效",
                            symbol: "dot.radiowaves.left.and.right",
                            isOn: Binding(get: { snap.spatialAudio }, set: { manager.setSpatialAudio($0) })
                        )
                    }
                    if snap.supportsTouchLock {
                        extrasDivider
                        compactToggle(
                            title: "锁定触控板",
                            detail: "防止误触耳机触控区域",
                            symbol: "lock.fill",
                            isOn: Binding(get: { snap.touchpadLocked }, set: { manager.setTouchpadLock($0) })
                        )
                        if snap.supportsOutsideDoubleTap {
                            extrasDivider
                            compactToggle(
                                title: "双击耳机边缘",
                                detail: "轻拍两次耳机外侧边缘以调节音量",
                                symbol: "hand.tap.fill",
                                isOn: Binding(get: { snap.outsideDoubleTap }, set: { manager.setOutsideDoubleTap($0) })
                            )
                        }
                        extrasDivider
                        touchOptionRow(title: "触控操作 · 左耳", selected: snap.touchLeft) {
                            manager.setTouchLeft($0)
                        }
                        extrasDivider
                        touchOptionRow(title: "触控操作 · 右耳", selected: snap.touchRight) {
                            manager.setTouchRight($0)
                        }
                    }
                    if snap.supportsPassthrough {
                        extrasDivider
                        compactToggle(
                            title: "耳压舒缓",
                            detail: "缓解耳道负压感（Galaxy Buds Live）",
                            symbol: "wind",
                            isOn: Binding(get: { snap.passthrough }, set: { manager.setPassthrough($0) })
                        )
                    }
                    if snap.supportsAmbientExtras {
                        extrasDivider
                        compactToggle(
                            title: "侧音",
                            detail: "通话时清晰听到自己的声音",
                            symbol: "mic.fill",
                            isOn: Binding(get: { snap.sidetone }, set: { manager.setSidetone($0) })
                        )
                        extrasDivider
                        compactToggle(
                            title: "超高环境音",
                            detail: "进一步放大环境音与通透音量",
                            symbol: "speaker.wave.3.fill",
                            isOn: Binding(get: { snap.extraHighAmbient }, set: { manager.setExtraHighAmbient($0) })
                        )
                        extrasDivider
                        compactToggle(
                            title: "增强环境音",
                            detail: "提升环境声音拾取强度",
                            symbol: "waveform.badge.plus",
                            isOn: Binding(get: { snap.amplifyAmbient }, set: { manager.setAmplifyAmbient($0) })
                        )
                        extrasDivider
                        compactToggle(
                            title: "无缝交谈",
                            detail: "说话时保持主动降噪开启",
                            symbol: "mouth.fill",
                            isOn: Binding(get: { snap.speakSeamlessly }, set: { manager.setSpeakSeamlessly($0) })
                        )
                    }
                    if snap.supportsANC {
                        extrasDivider
                        compactToggle(
                            title: "单耳主动降噪",
                            detail: "仅佩戴单只耳机时仍保持降噪",
                            symbol: "ear",
                            isOn: Binding(get: { snap.ancOneEarbud }, set: { manager.setAncOneEarbud($0) })
                        )
                    }
                    extrasDivider
                    compactToggle(
                        title: "自动切换音频",
                        detail: "在不同设备的播放间自动跟随切换",
                        symbol: "arrow.left.arrow.right",
                        isOn: Binding(get: { snap.autoSwitchAudio }, set: { manager.setAutoSwitchAudio($0) })
                    )
                    extrasDivider
                    compactToggle(
                        title: "取下单只耳机时暂停",
                        detail: "取下任意一只耳机时自动暂停媒体播放",
                        symbol: "pause.circle",
                        isOn: Binding(get: { snap.pauseOnOneBudRemoved }, set: { manager.setPauseOnOneBud($0) })
                    )
                    if snap.supportsCallExtras {
                        extrasDivider
                        compactToggle(
                            title: "耳机内来电铃声",
                            detail: "来电时在耳机中播放手机铃声",
                            symbol: "bell.fill",
                            isOn: Binding(get: { snap.inBandRingtone }, set: { manager.setInBandRingtone($0) })
                        )
                        extrasDivider
                        compactToggle(
                            title: "使用耳机接听通话",
                            detail: "将手机通话音频路由至耳机",
                            symbol: "phone.fill",
                            isOn: Binding(get: { snap.callPathControl }, set: { manager.setCallPathControl($0) })
                        )
                        extrasDivider
                        compactToggle(
                            title: "通话时开启环境音",
                            detail: "通话期间清晰听到周围环境声音",
                            symbol: "ear.badge.waveform",
                            isOn: Binding(get: { snap.ambientDuringCall }, set: { manager.setAmbientDuringCall($0) })
                        )
                        if snap.supportsExtraClearCall {
                            extrasDivider
                            compactToggle(
                                title: "超清通话音质",
                                detail: "增强通话时的人声清晰度",
                                symbol: "waveform",
                                isOn: Binding(get: { snap.extraClearCall }, set: { manager.setExtraClearCall($0) })
                            )
                        }
                    }
                    if snap.supportsFitTest {
                        extrasDivider
                        Button {
                            manager.startFitTest()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "ear.fill")
                                    .foregroundStyle(.cyan)
                                    .frame(width: 22)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(snap.fitTesting ? "正在检测贴合度…" : "耳塞贴合度测试")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text(
                                        snap.fitTesting
                                            ? "耳机正在播放测试音，请保持静止"
                                            : (snap.fitLeftGood || snap.fitRightGood
                                               ? "左耳：\(snap.fitLeftGood ? "贴合良好" : "需调整") · 右耳：\(snap.fitRightGood ? "贴合良好" : "需调整")"
                                               : "检测耳塞气密性以获得最佳降噪与低音效果")
                                    )
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                    extrasDivider
                    Button {
                        manager.enterPairingMode()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "link.badge.plus")
                                .foregroundStyle(.cyan)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("进入配对模式")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("使耳机可被新设备搜索并配对")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
                if snap.supportsFind || snap.vendor == .galaxy {
                    extrasDivider
                    findRow
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
    }

    private var extrasDivider: some View {
        Divider().opacity(0.2).padding(.leading, 34)
    }

    private func touchOptionRow(
        title: String,
        selected: GalaxyTouchOption,
        onSelect: @escaping (GalaxyTouchOption) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ForEach(GalaxyTouchOption.allCases) { option in
                    Button(option.displayName) {
                        onSelect(option)
                    }
                    .buttonStyle(.bordered)
                    .tint(selected == option ? .accentColor : .secondary)
                    .controlSize(.small)
                }
            }
            .padding(.bottom, 4)
        }
        .padding(.vertical, 4)
    }

    private func compactToggle(
        title: String,
        detail: String,
        symbol: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isOn.wrappedValue ? Color.accentColor : .secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            SettingsSwitch(isOn: isOn)
        }
        .padding(.vertical, 8)
    }

    private var findRow: some View {
        HStack(spacing: 10) {
            Image(systemName: finding ? "speaker.wave.3.fill" : "location.magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(finding ? Color.orange : Color.accentColor)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(finding ? "正在响铃…" : "查找耳机")
                    .font(.system(size: 13, weight: .semibold))
                Text(finding ? "正在两侧耳机上播放提示音" : "找不到耳机时让其发出提示音")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Button {
                finding.toggle()
                manager.find(finding)
            } label: {
                Text(finding ? "停止" : "响铃")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(finding ? Color.orange.opacity(0.28) : Color.accentColor.opacity(0.28))
                    .foregroundStyle(finding ? Color.orange : Color.accentColor)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .black))
            .foregroundStyle(.secondary)
            .tracking(1.1)
    }
}

private struct EarbudAmbientSlider: View {
    @Binding var level: Double
    var range: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("环境音等级", systemImage: "ear")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(Int(level))")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.accentColor)
            }
            Slider(value: $level, in: range, step: 1)
                .tint(.accentColor)
        }
    }
}