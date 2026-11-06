//
//  DisplaySettingsView.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2026-09-27

import AppKit
import SwiftUI

struct DisplaySettingsView: View {
    @EditingSettings var settings: SettingsEditingSession
    @ObservedObject private var debugMode = DebugMode.shared
    @ObservedObject private var testDisplay = DebugTestDisplay.shared
    @State private var screensRevision = 0

    private var connectedScreens: [NSScreen] { NSScreen.screens }

    private var usesSelectedActivities: Bool {
        connectedScreens.contains {
            settings.settings.value.resolvedFullScreenBehavior(forDisplayID: $0.displayIdentifier).activityVisibility == .hideSelected
        }
    }

    var body: some View {
        let _ = screensRevision
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("显示器").font(.title2.bold())
                    Text("设置每台显示器的灵动岛尺寸、隐藏方式与全屏行为。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if debugMode.isEnabled {
                    Button {
                        testDisplay.toggle()
                    } label: {
                        Label(testDisplay.isActive ? "移除测试显示器" : "添加测试显示器", systemImage: "display.2")
                    }
                    .help("调试：添加一台以窗口显示的 1920×1080 无刘海虚拟显示器，用于测试多显示器与悬浮灵动岛行为")
                }
            }

            if debugMode.isEnabled, let error = testDisplay.captureError {
                InfoContainer(text: error, iconName: "exclamationmark.triangle", color: .orange)
            }

            if connectedScreens.count > 1 {
                HStack(spacing: 12) {
                    SettingsRowLabel(
                        title: "显示灵动岛的位置",
                        description: "适用于下方未单独开启或关闭的显示器，包括之后新连接的显示器。"
                    )
                    Spacer(minLength: 8)
                    Picker("显示灵动岛的位置", selection: $settings.settings.notchDisplayTarget) {
                        ForEach(NotchDisplayTarget.allCases) { target in
                            Text(target.displayName).tag(target)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 200)
                }
                .padding()
                .modifier(SettingsContainerModifier())
            }

            if usesSelectedActivities {
                FullScreenSelectedActivitiesCard()
                    .transition(.opacity)
            }

            if connectedScreens.isEmpty {
                Text("未检测到显示器。")
                    .foregroundColor(.secondary)
                    .padding()
                    .modifier(SettingsContainerModifier())
            } else {
                ForEach(connectedScreens, id: \.displayIdentifier) { screen in
                    PerDisplaySettingsCard(screen: screen, canApplyToAll: connectedScreens.count > 1)
                }
            }
        }
        .animation(.default, value: usesSelectedActivities)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            screensRevision += 1
        }
    }
}

// MARK: - Software dimming

struct SoftwareDimmingRows: View {
    private struct Row: Identifiable, Equatable {
        let id: CGDirectDisplayID
        let name: String
        let prefersSoftware: Bool
    }

    @State private var rows: [Row] = []

    var body: some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                Divider().padding(.leading, 20)
                ToggleRow(
                    title: "始终在“\(row.name)”上使用软件调光",
                    description: "即使显示器支持 DDC 也改用软件调光，适合 DDC 响应较慢或不稳定的显示器。",
                    isOn: Binding(
                        get: { row.prefersSoftware },
                        set: { newValue in
                            (DisplayManager.shared.display(for: row.id) as? OtherDisplay)?.setPrefersSoftware(newValue)
                            reload()
                        }
                    )
                )
            }
        }
        .onAppear(perform: reload)
        .onReceive(NotificationCenter.default.publisher(for: DisplayManager.brightnessStateDidChange)) { _ in reload() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in reload() }
    }

    private func reload() {
        let newRows = DisplayManager.shared.getOtherDisplays().map {
            Row(id: $0.identifier, name: $0.name, prefersSoftware: $0.prefersSoftware)
        }
        if newRows != rows { rows = newRows }
    }
}

// MARK: - Full screen

private struct FullScreenBehaviorEditor: View {
    @Binding var visibility: FullScreenActivityVisibility
    @Binding var hideNotch: Bool
    @Binding var hideLyrics: Bool

    private var musicCanShow: Bool {
        visibility == .showAll || visibility == .hideSelected
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsRowLabel(title: "全屏模式下", description: visibility.detail)
            Picker("全屏模式下", selection: $visibility) {
                ForEach(FullScreenActivityVisibility.allCases) { visibility in
                    Text(visibility.displayName).tag(visibility)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            HStack(spacing: 12) {
                SettingsRowLabel(title: "隐藏灵动岛", description: hideNotchDescription)
                Spacer(minLength: 8)
                SettingsSwitch(title: "隐藏灵动岛", isOn: $hideNotch)
            }

            if musicCanShow {
                HStack(spacing: 12) {
                    SettingsRowLabel(
                        title: "隐藏歌词",
                        description: "隐藏音乐实时活动下方的歌词行，避免遮挡全屏应用；当前歌曲仍会显示。"
                    )
                    Spacer(minLength: 8)
                    SettingsSwitch(title: "隐藏歌词", isOn: $hideLyrics)
                }
            }
        }
    }

    private var hideNotchDescription: String {
        switch visibility {
        case .hideAll:
            "应用全屏时彻底隐藏灵动岛。"
        case .showAll:
            "无动态时隐藏灵动岛，有任意实时活动时自动显现。"
        case .hidePersistent, .hideSelected:
            "无动态时隐藏灵动岛；未被隐藏的活动（如音量 HUD）仍会正常显现。"
        }
    }
}

private struct FullScreenSelectedActivitiesCard: View {
    @EditingSettings var settings: SettingsEditingSession

    var body: some View {
        SettingsCard(title: "隐藏所选活动", description: "在全屏策略设为“隐藏所选活动”的显示器上，全屏时隐藏以下勾选的活动。") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12, alignment: .leading)], alignment: .leading, spacing: 10) {
                ForEach(LiveActivityType.allCases) { type in
                    Toggle(type.displayName, isOn: binding(for: type))
                        .toggleStyle(.checkbox)
                }
            }
            .padding()
        }
    }

    private func binding(for type: LiveActivityType) -> Binding<Bool> {
        Binding(
            get: { settings.settings.hideActivitiesInFullScreen[type.rawValue, default: false] },
            set: { settings.settings.hideActivitiesInFullScreen[type.rawValue] = $0 }
        )
    }
}

// MARK: - Per display

private struct PerDisplaySettingsCard: View {
    @EditingSettings var settings: SettingsEditingSession
    let screen: NSScreen
    let canApplyToAll: Bool
    @State private var showsIslandAdvanced = false

    private var displayID: String { screen.displayIdentifier }
    private var isBuiltIn: Bool { CGDisplayIsBuiltin(screen.displayID) != 0 }
    private var hasSizeOverride: Bool { sizeOverride != nil }
    private var sizeOverride: NotchSizeOverride? {
        DisplaySettingsKey.value(in: settings.settings.value.perDisplayNotchSize, for: displayID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: isBuiltIn ? "laptopcomputer" : "display")
                    .foregroundColor(.secondary)
                Text(screen.displayLabel).font(.headline)
                if isBuiltIn { Text("内置").font(.caption).foregroundColor(.secondary) }
                Spacer()
                if canApplyToAll && showsNotch {
                    Button("应用到所有显示器") {
                        settings.settings.value.applyDisplaySettingsToAllDisplays(
                            from: displayID,
                            includeFloatingIsland: !NotchConfiguration.hasHardwareNotch(on: screen)
                        )
                    }
                    .controlSize(.small)
                    .help("将此显示器的灵动岛尺寸、隐藏方式和全屏设置应用到所有显示器（包括之后新连接的显示器）")
                }
                SettingsSwitch(title: "显示灵动岛", isOn: showNotchBinding)
                    .help("在此显示器上显示灵动岛")
            }
            .padding([.top, .horizontal])

            if showsNotch {
                notchRows
            } else {
                Text("此显示器上的灵动岛已关闭。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .modifier(SettingsContainerModifier())
        .animation(.default, value: showsNotch)
    }

    private var showsNotch: Bool {
        NotchScreens.showsNotch(on: screen, settings: settings.settings.value)
    }

    private var showNotchBinding: Binding<Bool> {
        Binding(
            get: { showsNotch },
            set: { settings.settings.perDisplayShowNotch[displayID] = $0 }
        )
    }

    @ViewBuilder
    private var notchRows: some View {
        sizeRow.padding()
        if !NotchConfiguration.hasHardwareNotch(on: screen) {
            Divider().padding(.leading, 20)
            floatingIslandRows
        }
        Divider().padding(.leading, 20)
        HStack(spacing: 12) {
            SettingsRowLabel(title: "无活动时隐藏灵动岛", description: "平时隐藏灵动岛，有动态时再自动显现。")
            Spacer(minLength: 8)
            SettingsSwitch(title: "无活动时隐藏灵动岛", isOn: inactiveBinding)
        }
        .padding()
        Divider().padding(.leading, 20)
        FullScreenBehaviorEditor(
            visibility: fullScreenBinding(\.activityVisibility),
            hideNotch: fullScreenBinding(\.hideNotch),
            hideLyrics: fullScreenBinding(\.hideLyrics)
        )
        .padding()
    }

    private var sizeRow: some View {
        let resolved = ResolvedNotchConfiguration(from: settings.settings.value, screen: screen)
        return HStack(spacing: 18) {
            Text("灵动岛尺寸")
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
                .layoutPriority(-1)
            Spacer(minLength: 8)
            sizeControl(label: "宽度", value: sizeBinding(\.width, fallback: resolved.universalWidth), range: 80...400)
            sizeControl(label: "高度", value: sizeBinding(\.height, fallback: resolved.universalHeight), range: 10...80)
            resetButton(visible: hasSizeOverride, help: "清除此显示器的自定义灵动岛尺寸") {
                DisplaySettingsKey.removeValue(
                    from: &settings.settings.perDisplayNotchSize,
                    for: screen.displayIdentifier,
                    connectedKeys: NSScreen.screens.map(\.displayIdentifier)
                )
            }
        }
    }

    @ViewBuilder
    private var floatingIslandRows: some View {
        let isIsland = settings.settings.value.resolvedFloatingIsland(forDisplayID: displayID)
        HStack(spacing: 12) {
            SettingsRowLabel(
                title: "悬浮灵动岛",
                description: "在屏幕顶部边缘下方显示胶囊形悬浮灵动岛，而非贴边刘海。此显示器无硬件刘海。"
            )
            Spacer(minLength: 8)
            SettingsSwitch(title: "悬浮灵动岛", isOn: floatingIslandBinding)
        }
        .padding()
        if isIsland {
            Button {
                withAnimation(.snappy) { showsIslandAdvanced.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Text("高级")
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .rotationEffect(.degrees(showsIslandAdvanced ? 90 : 0))
                    Spacer()
                }
                .foregroundColor(.secondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding([.horizontal, .bottom])
            .accessibilityLabel(showsIslandAdvanced ? "隐藏悬浮灵动岛高级设置" : "显示悬浮灵动岛高级设置")

            if showsIslandAdvanced {
                VStack(spacing: 0) {
                    FloatingIslandPreview(config: ResolvedNotchConfiguration(from: settings.settings.value, screen: screen))
                        .padding(.horizontal)
                        .padding(.bottom)

                    HStack(spacing: 12) {
                        SettingsRowLabel(title: "顶部偏移距离", description: "距离屏幕顶部边缘的间距。")
                        Spacer(minLength: 8)
                        DeferredValueEditor(value: islandTopOffsetBinding) { draft, onEditingChanged in
                            HStack(spacing: 8) {
                                Slider(value: draft, in: 0...40, step: 1, onEditingChanged: onEditingChanged)
                                    .frame(width: 150)
                                    .accessibilityLabel("顶部偏移距离")
                                Text("\(Int(draft.wrappedValue)) pt")
                                    .monospacedDigit()
                                    .frame(width: 42, alignment: .trailing)
                            }
                        }
                    }
                    .padding([.horizontal, .bottom])

                    VStack(spacing: 0) {
                        islandSlider("两侧内边距", \.sidePadding, range: FloatingIslandStyle.sidePaddingRange)
                        islandSlider("中间间距", \.centerGap, range: FloatingIslandStyle.centerGapRange)
                        islandSlider("展开圆角半径", \.openCornerRadius, range: FloatingIslandStyle.openCornerRadiusRange)
                        islandSlider("展开内边距", \.openPadding, range: FloatingIslandStyle.openPaddingRange)
                    }
                    HStack {
                        Spacer()
                        resetButton(visible: hasIslandStyleOverride, help: "恢复默认悬浮灵动岛间距") {
                            DisplaySettingsKey.removeValue(
                                from: &settings.settings.perDisplayFloatingIslandStyle,
                                for: screen.displayIdentifier,
                                connectedKeys: NSScreen.screens.map(\.displayIdentifier)
                            )
                        }
                    }
                    .padding([.horizontal, .bottom])
                }
                .transition(.opacity)
            }
        }
    }

    private var hasIslandStyleOverride: Bool {
        DisplaySettingsKey.value(in: settings.settings.value.perDisplayFloatingIslandStyle, for: displayID) != nil
    }

    private func islandSlider(_ label: String, _ keyPath: WritableKeyPath<FloatingIslandStyle, CGFloat>, range: ClosedRange<CGFloat>) -> some View {
        CustomSliderRowView(
            label: label,
            value: Binding(
                get: { Double(settings.settings.value.resolvedFloatingIslandStyle(forDisplayID: displayID)[keyPath: keyPath]) },
                set: { newValue in
                    var style = settings.settings.value.resolvedFloatingIslandStyle(forDisplayID: displayID)
                    style[keyPath: keyPath] = CGFloat(newValue.rounded())
                    settings.settings.perDisplayFloatingIslandStyle[displayID] = style
                }
            ),
            range: Double(range.lowerBound)...Double(range.upperBound),
            specifier: "%.0f pt"
        )
        .padding(.horizontal)
    }

    private func resetButton(visible: Bool, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label("重置", systemImage: "arrow.counterclockwise").font(.callout)
        }
        .buttonStyle(.plain)
        .foregroundColor(.accentColor)
        .help(help)
        .fixedSize()
        .opacity(visible ? 1 : 0)
        .disabled(!visible)
        .accessibilityHidden(!visible)
    }

    private var inactiveBinding: Binding<Bool> {
        Binding(
            get: { settings.settings.value.resolvedHideNotchWhenInactive(forDisplayID: displayID) },
            set: { settings.settings.perDisplayHideNotchWhenInactive[displayID] = $0 }
        )
    }

    private var floatingIslandBinding: Binding<Bool> {
        Binding(
            get: { settings.settings.value.resolvedFloatingIsland(forDisplayID: displayID) },
            set: { settings.settings.perDisplayFloatingIsland[displayID] = $0 }
        )
    }

    private var islandTopOffsetBinding: Binding<Double> {
        Binding(
            get: { Double(settings.settings.value.resolvedFloatingIslandTopOffset(forDisplayID: displayID)) },
            set: { settings.settings.perDisplayFloatingIslandTopOffset[displayID] = CGFloat($0) }
        )
    }

    private func fullScreenBinding<Value>(_ keyPath: WritableKeyPath<FullScreenBehavior, Value>) -> Binding<Value> {
        Binding(
            get: { settings.settings.value.resolvedFullScreenBehavior(forDisplayID: displayID)[keyPath: keyPath] },
            set: { newValue in
                var behavior = settings.settings.value.resolvedFullScreenBehavior(forDisplayID: displayID)
                behavior[keyPath: keyPath] = newValue
                settings.settings.perDisplayFullScreenBehavior[displayID] = behavior
            }
        )
    }

    private func sizeBinding(_ keyPath: WritableKeyPath<NotchSizeOverride, CGFloat>, fallback: CGFloat) -> Binding<Double> {
        Binding(
            get: {
                let value: CGFloat = sizeOverride?[keyPath: keyPath] ?? 0
                return Double(value > 0 ? value : fallback)
            },
            set: { newValue in
                var override = sizeOverride ?? NotchSizeOverride()
                override[keyPath: keyPath] = CGFloat(newValue.rounded())
                settings.settings.perDisplayNotchSize[displayID] = override
            }
        )
    }

    private func sizeControl(label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: true, vertical: false)
                .lineLimit(1)
            TextField(label, value: value, format: .number.precision(.fractionLength(0)))
                .textFieldStyle(.roundedBorder)
                .monospacedDigit()
                .frame(width: 62)
                .multilineTextAlignment(.trailing)
            VStack(spacing: 0) {
                Button {
                    value.wrappedValue = min(range.upperBound, (value.wrappedValue + 1).rounded())
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 9, weight: .bold))
                        .frame(width: 16, height: 9)
                }
                .buttonStyle(.plain)
                .help("增加\(label)")

                Button {
                    value.wrappedValue = max(range.lowerBound, (value.wrappedValue - 1).rounded())
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .frame(width: 16, height: 9)
                }
                .buttonStyle(.plain)
                .help("减小\(label)")
            }
            Text("pt")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .fixedSize()
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

// MARK: - Floating island preview

private struct FloatingIslandPreview: View {
    let config: ResolvedNotchConfiguration

    private static let openSize = CGSize(width: 620, height: 260)
    private static let openScale: CGFloat = 0.42

    private var islandShape: CustomNotchShape {
        CustomNotchShape(
            cornerRadius: 0,
            bottomCornerRadius: 0,
            isFloatingIsland: true,
            floatingIslandCornerRadius: config.floatingIslandCornerRadius
        )
    }

    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            labelled("紧凑") { compact }
            labelled("展开") {
                open
                    .scaleEffect(Self.openScale, anchor: .topLeading)
                    .frame(
                        width: Self.openSize.width * Self.openScale,
                        height: Self.openSize.height * Self.openScale,
                        alignment: .topLeading
                    )
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color(white: 0.32), Color(white: 0.18)], startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    private func labelled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            content()
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var compact: some View {
        let height = config.universalHeight
        let art = height * 0.62
        let contentWidth = art * 2 + config.activityCenterGap + config.activityDefaultHorizontalPadding * 2
        return HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: art * 0.25, style: .continuous)
                .fill(LinearGradient(colors: [.pink, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: art, height: art)
            Spacer(minLength: 0)
            HStack(spacing: 2) {
                ForEach([0.5, 0.9, 0.65, 1.0, 0.45], id: \.self) { level in
                    Capsule().fill(.white.opacity(0.85)).frame(width: 2.5, height: art * level)
                }
            }
            .frame(width: art)
        }
        .padding(.horizontal, config.activityDefaultHorizontalPadding)
        .frame(width: max(contentWidth, config.universalWidth), height: height)
        .background(islandShape.fill(.black))
    }

    private var open: some View {
        let padding = config.contentHorizontalPadding
        let barHeight = NotchIslandBar.height
        let card = CGSize(width: Self.openSize.width, height: Self.openSize.height - NotchIslandBar.reservedHeight)
        return VStack(spacing: NotchIslandBar.gap) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.14))
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.14))
            }
            .padding(.top, config.contentTopPadding)
            .padding(.bottom, config.contentBottomPadding)
            .padding(.horizontal, padding)
            .frame(width: card.width, height: card.height)
            .clipShape(islandShape)
            .background(islandShape.fill(.black))

            HStack(spacing: 0) {
                ForEach(["house.fill", "tray.full.fill", "note.text", "list.clipboard.fill", "gearshape.fill"], id: \.self) { symbol in
                    Image(systemName: symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(symbol == "house.fill" ? 1 : 0.62))
                        .frame(width: NotchIslandBar.itemWidth - 4, height: barHeight - 8)
                        .background(Capsule().fill(.white.opacity(symbol == "house.fill" ? 0.16 : 0)))
                        .frame(width: NotchIslandBar.itemWidth)
                }
            }
            .padding(.horizontal, NotchIslandBar.padding)
            .frame(height: barHeight)
            .background(Capsule(style: .continuous).fill(.black))
        }
        .frame(width: Self.openSize.width, height: Self.openSize.height, alignment: .top)
    }
}