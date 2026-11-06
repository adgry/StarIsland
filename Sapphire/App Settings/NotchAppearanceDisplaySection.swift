//
//  NotchAppearanceDisplaySection.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2026-10-15
//

import AppKit
import SwiftUI

struct NotchAppearanceDisplaySection: View {
    @EditingSettings var settings: SettingsEditingSession
    @State private var selectedDisplay: String?
    @State private var screensRevision = 0

    private var screens: [NSScreen] { NSScreen.screens }

    var body: some View {
        let _ = screensRevision
        VStack(alignment: .leading, spacing: 20) {
            if screens.count > 1 {
                displayPicker
            }
            NotchAppearanceEditorView(appearance: widgetBinding, title: "展开态灵动岛外观")
            NotchAppearanceEditorView(appearance: liveActivityBinding, title: "收起态灵动岛外观")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            screensRevision += 1
            if let selectedDisplay, !screens.contains(where: { $0.displayIdentifier == selectedDisplay }) {
                self.selectedDisplay = nil
            }
        }
    }

    // MARK: Picker

    private var displayPicker: some View {
        let current = settings.settings.value
        let hasOverride = selectedDisplay.map { current.hasAppearanceOverride(forDisplayID: $0) } ?? false
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                SettingsRowLabel(title: "外观生效范围", description: pickerDescription(hasOverride: hasOverride))
                Spacer(minLength: 8)
                Picker("外观生效范围", selection: $selectedDisplay) {
                    Text("所有显示器").tag(String?.none)
                    ForEach(screens, id: \.displayIdentifier) { screen in
                        let custom = current.hasAppearanceOverride(forDisplayID: screen.displayIdentifier)
                        Text(screen.displayLabel + (custom ? "（自定义）" : ""))
                            .tag(Optional(screen.displayIdentifier))
                    }
                }
                .labelsHidden()
                .frame(width: 240)
            }
            if let key = selectedDisplay, hasOverride {
                HStack(spacing: 16) {
                    Spacer()
                    Button {
                        settings.settings.value.applyAppearanceToAllDisplays(from: key)
                        selectedDisplay = nil
                    } label: {
                        Label("应用到所有显示器", systemImage: "rectangle.on.rectangle")
                    }
                    .help("将此显示器的外观设为全局默认外观，并清除各显示器的单独外观覆盖")
                    Button {
                        resetOverride(for: key)
                    } label: {
                        Label("恢复默认", systemImage: "arrow.counterclockwise")
                    }
                    .help("让此显示器重新使用所有显示器共享的默认外观")
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .font(.callout)
            }
        }
        .padding()
        .modifier(SettingsContainerModifier())
    }

    private func pickerDescription(hasOverride: Bool) -> String {
        guard let selectedDisplay else {
            return "所作修改将应用于所有未单独设置外观的显示器。"
        }
        let name = screens.first { $0.displayIdentifier == selectedDisplay }?.displayLabel ?? "此显示器"
        return hasOverride
            ? "\(name) 当前使用独立外观。"
            : "\(name) 当前使用默认外观；修改下方任一选项将为其创建独立外观。"
    }

    private func resetOverride(for key: String) {
        let connected = screens.map(\.displayIdentifier)
        DisplaySettingsKey.removeValue(from: &settings.settings.perDisplayNotchWidgetAppearance, for: key, connectedKeys: connected)
        DisplaySettingsKey.removeValue(from: &settings.settings.perDisplayNotchLiveActivityAppearance, for: key, connectedKeys: connected)
    }

    // MARK: Bindings

    private var widgetBinding: Binding<NotchAppearanceSettings> {
        guard let key = selectedDisplay else { return $settings.settings.notchWidgetAppearance }
        return Binding(
            get: { settings.settings.value.resolvedNotchWidgetAppearance(forDisplayID: key) },
            set: { newValue in
                adoptOverride(for: key)
                settings.settings.perDisplayNotchWidgetAppearance[key] = newValue
            }
        )
    }

    private var liveActivityBinding: Binding<NotchAppearanceSettings> {
        guard let key = selectedDisplay else { return $settings.settings.notchLiveActivityAppearance }
        return Binding(
            get: { settings.settings.value.resolvedNotchLiveActivityAppearance(forDisplayID: key) },
            set: { newValue in
                adoptOverride(for: key)
                settings.settings.perDisplayNotchLiveActivityAppearance[key] = newValue
            }
        )
    }

    private func adoptOverride(for key: String) {
        let current = settings.settings.value
        if DisplaySettingsKey.value(in: current.perDisplayNotchWidgetAppearance, for: key) == nil {
            settings.settings.perDisplayNotchWidgetAppearance[key] = current.notchWidgetAppearance
        }
        if DisplaySettingsKey.value(in: current.perDisplayNotchLiveActivityAppearance, for: key) == nil {
            settings.settings.perDisplayNotchLiveActivityAppearance[key] = current.notchLiveActivityAppearance
        }
    }
}