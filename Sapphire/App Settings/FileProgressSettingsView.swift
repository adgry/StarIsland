//
//  FileProgressSettingsView.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2026-09-28
//

import SwiftUI
import AppKit

struct FileProgressSettingsView: View {
    @EditingSettings var settings: SettingsEditingSession
    @ObservedObject private var tracker = FileProgressTracker.shared

    private var installedApps: [FileProgressApp] {
        FileProgressApp.allCases.filter(\.isInstalled)
    }

    private func appBinding(_ app: FileProgressApp) -> Binding<Bool> {
        Binding(
            get: { !settings.settings.fileProgressDisabledApps.contains(app.rawValue) },
            set: { on in
                if on { settings.settings.fileProgressDisabledApps.remove(app.rawValue) }
                else { settings.settings.fileProgressDisabledApps.insert(app.rawValue) }
            }
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                Text("文件传输进度（测试版）").font(.largeTitle.bold()).padding(.bottom)

                VStack(alignment: .leading, spacing: 0) {
                    ToggleRow(
                        title: "在灵动岛中显示传输进度",
                        description: "当下载、拷贝文件或通过 AirDrop 接收文件时，以实时活动显示应用图标与传输进度。",
                        isOn: $settings.settings.fileProgressLiveActivityEnabled
                    )
                    Divider().padding(.leading, 20)
                    ToggleRow(
                        title: "点击时打开传输列表",
                        description: "点击实时活动即可查看所有传输任务，并支持暂停、取消、打开和在访达中显示。",
                        isOn: $settings.settings.fileProgressOpenOnClick
                    )
                }
                .modifier(SettingsContainerModifier())

                VStack(alignment: .leading, spacing: 0) {
                    Text("应用").font(.headline).padding([.top, .horizontal])
                    Text("按各应用自身上报传输状态的方式进行跟踪，只要应用提供进度即可显示精确百分比。")
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.horizontal).padding(.bottom, 8)
                    ForEach(Array(installedApps.enumerated()), id: \.element) { index, app in
                        if index > 0 { Divider().padding(.leading, 56) }
                        HStack(spacing: 12) {
                            Group {
                                if let icon = app.icon {
                                    Image(nsImage: icon).resizable().aspectRatio(contentMode: .fit)
                                } else {
                                    Image(systemName: "app.dashed")
                                }
                            }
                            .frame(width: 28, height: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.displayName)
                                Text(app.trackingDetail).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: appBinding(app)).labelsHidden().toggleStyle(.switch)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                }
                .modifier(SettingsContainerModifier())
                .disabled(!settings.settings.fileProgressLiveActivityEnabled)

                VStack(alignment: .leading, spacing: 0) {
                    ToggleRow(title: "显示速率", description: "在进度百分比旁显示下载或拷贝速率。",
                              isOn: $settings.settings.fileProgressShowSpeed)
                    Divider().padding(.leading, 20)
                    ToggleRow(title: "显示剩余时间", description: "显示预估剩余完成时间。",
                              isOn: $settings.settings.fileProgressShowTimeRemaining)
                    Divider().padding(.leading, 20)
                    ToggleRow(title: "将已完成的文件加入文件暂存架",
                              description: "下载完成后自动放入文件暂存架，方便随时拖用。",
                              isOn: $settings.settings.fileProgressAddFinishedToShelf)
                    Divider().padding(.leading, 20)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("已完成传输保留显示时长")
                            Spacer()
                            Text("\(Int(settings.settings.fileProgressKeepFinishedSeconds)) 秒").foregroundStyle(.secondary).monospacedDigit()
                        }
                        Slider(value: $settings.settings.fileProgressKeepFinishedSeconds, in: 1...30, step: 1)
                    }
                    .padding()
                }
                .modifier(SettingsContainerModifier())
                .disabled(!settings.settings.fileProgressLiveActivityEnabled)

                VStack(alignment: .leading, spacing: 0) {
                    Text("监控的文件夹").font(.headline).padding([.top, .horizontal])
                    Text("“下载”、“桌面”、“文稿”以及各浏览器自身的下载目录会自动识别。你还可以添加其他应用保存文件的目录。")
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.horizontal).padding(.bottom, 8)
                    ForEach(tracker.watchedFolders, id: \.self) { folder in
                        let isExtra = settings.settings.fileProgressExtraFolders.contains {
                            ($0 as NSString).expandingTildeInPath == folder.path
                        }
                        HStack {
                            Image(systemName: "folder").foregroundStyle(.secondary)
                            Text((folder.path as NSString).abbreviatingWithTildeInPath)
                                .lineLimit(1).truncationMode(.middle)
                            Spacer()
                            if isExtra {
                                Button("移除") {
                                    settings.settings.fileProgressExtraFolders.removeAll {
                                        ($0 as NSString).expandingTildeInPath == folder.path
                                    }
                                }
                                .buttonStyle(.borderless)
                            } else {
                                Text("自动").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 5)
                    }
                    HStack {
                        Spacer()
                        Button("添加文件夹…", action: addFolder)
                    }
                    .padding()
                }
                .modifier(SettingsContainerModifier())
                .disabled(!settings.settings.fileProgressLiveActivityEnabled)
            }
            .padding(25)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "监控"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            let path = (url.path as NSString).abbreviatingWithTildeInPath
            if !settings.settings.fileProgressExtraFolders.contains(path) {
                settings.settings.fileProgressExtraFolders.append(path)
            }
        }
    }
}