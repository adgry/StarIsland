//
//  AppActivitiesSettingsView.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2026-09-28
//

import SwiftUI

struct AppActivitiesSettingsView: View {
    @EditingSettings var settings: SettingsEditingSession
    @ObservedObject private var monitor = AppActivityMonitor.shared

    private func appBinding(_ app: AppActivityApp) -> Binding<Bool> {
        Binding(
            get: { !settings.settings.appActivitiesDisabled.contains(app.rawValue) },
            set: { on in
                if on { settings.settings.appActivitiesDisabled.remove(app.rawValue) }
                else { settings.settings.appActivitiesDisabled.insert(app.rawValue) }
            }
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                Text("应用活动（测试版）").font(.largeTitle.bold()).padding(.bottom)

                VStack(alignment: .leading, spacing: 0) {
                    ToggleRow(
                        title: "在灵动岛中显示应用活动",
                        description: "在会议、通话、录制或连接另一台 Mac 时，显示带有应用图标和计时器的实时活动。点击可打开控制项。",
                        isOn: $settings.settings.appActivitiesEnabled
                    )
                    Divider().padding(.leading, 20)
                    ToggleRow(
                        title: "执行控制后返回原应用",
                        description: "部分应用仅在前台时响应快捷键；静音或切换视频后，自动切回你刚才使用的应用。",
                        isOn: $settings.settings.appActivityRestoreFocus
                    )
                }
                .modifier(SettingsContainerModifier())

                if !monitor.activities.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("当前活跃").font(.headline)
                        ForEach(monitor.activities) { activity in
                            HStack(spacing: 10) {
                                AppActivityIcon(app: activity.app, size: 22)
                                Text(activity.title)
                                if let subtitle = activity.subtitle { Text(subtitle).foregroundStyle(.secondary) }
                                Spacer()
                                Text(activity.startedAt, style: .timer).monospacedDigit().foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                    .modifier(SettingsContainerModifier())
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text("应用").font(.headline).padding([.top, .horizontal])
                    Text("控制功能需要“辅助功能”权限；Google Meet 还需要控制浏览器的权限。")
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.horizontal).padding(.bottom, 8)
                    let apps = AppActivityApp.allCases.filter(\.isInstalled)
                    ForEach(Array(apps.enumerated()), id: \.element) { index, app in
                        if index > 0 { Divider().padding(.leading, 56) }
                        HStack(spacing: 12) {
                            AppActivityIcon(app: app, size: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.displayName)
                                Text(app.detectionDetail).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: appBinding(app)).labelsHidden().toggleStyle(.switch)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                }
                .modifier(SettingsContainerModifier())
                .disabled(!settings.settings.appActivitiesEnabled)
            }
            .padding(25)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}