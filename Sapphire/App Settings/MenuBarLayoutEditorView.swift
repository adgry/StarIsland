//
//  MenuBarLayoutEditorView.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2026-10-12
//

import AppKit
import SwiftUI

struct MenuBarLayoutEditorView: View {
    @EditingSettings var settings: SettingsEditingSession
    @StateObject private var model = MenuBarLayoutEditorModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("菜单栏布局").font(.headline)
                    Text("选择各应用菜单栏图标的归属分组。你也可以按住 Option 键点击控制图标直接在菜单栏中拖动排列，再次点击后 Sapphire 会自动记住新布局。")
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Button("刷新") { model.reload() }
                    .buttonStyle(.bordered).controlSize(.small)
            }
            .padding()

            ForEach(model.rows) { row in
                Divider().padding(.leading, 20)
                rowView(row)
            }

            Divider().padding(.leading, 20)
            ToggleRow(
                title: "在独立展开栏中显示隐藏图标",
                description: "点击控制图标时，在菜单栏下方弹出独立展开栏显示隐藏的图标，而不在菜单栏内腾出空间。适合灵动岛两侧空间不足时使用。",
                isOn: $settings.settings.menuBarUseHiddenItemsBar
            )

            InfoContainer(
                text: "macOS 27 会按应用整体显示或隐藏其所有菜单栏图标。隐藏图标期间，未在此处列出的系统项目（专注模式、正在播放、Siri、实时活动）以及不在“应用程序”文件夹中的应用图标也会一并隐藏。点击时钟仍可正常打开通知中心。",
                iconName: "info.circle",
                color: .blue
            )
            .padding()
        }
        .modifier(SettingsContainerModifier())
        .onAppear { model.reload() }
        .onReceive(NotificationCenter.default.publisher(for: .menuBarSectionsDidChange)) { _ in model.refreshSections() }
    }

    private func rowView(_ row: MenuBarLayoutEditorModel.Row) -> some View {
        HStack(spacing: 12) {
            Group {
                if let icon = row.icon {
                    Image(nsImage: icon).resizable().scaledToFit()
                } else {
                    Image(systemName: row.symbolName).font(.system(size: 15, weight: .medium)).foregroundStyle(.secondary)
                }
            }
            .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(row.title).font(.system(size: 14, weight: .medium)).lineLimit(1)
                if !row.isRunning {
                    Text("未运行").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 12)
            Picker("", selection: Binding(
                get: { row.section },
                set: { model.assign($0, to: row) }
            )) {
                ForEach(availableSections, id: \.self) { section in
                    Text(section.title).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: availableSections.count == 3 ? 270 : 180)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var availableSections: [MenuBarSectionKind] {
        settings.settings.enableAlwaysHiddenSection ? MenuBarSectionKind.allCases : [.shown, .hidden]
    }
}

@MainActor
final class MenuBarLayoutEditorModel: ObservableObject {
    struct Row: Identifiable, Equatable {
        let id: String
        let title: String
        let icon: NSImage?
        let symbolName: String
        let isRunning: Bool
        var section: MenuBarSectionKind
    }

    @Published private(set) var rows: [Row] = []

    func reload() {
        MenuBarItemCatalog.shared.start()
        MenuBarItemCatalog.shared.items(maxAge: 1) { [weak self] items in
            self?.build(from: items)
        }
    }

    func refreshSections() {
        let store = MenuBarSectionStore.shared
        rows = rows.map { row in
            var row = row
            row.section = store.section(for: row.id)
            return row
        }
    }

    func assign(_ section: MenuBarSectionKind, to row: Row) {
        MenuBarSectionStore.shared.set(section, for: row.id, name: row.title)
        refreshSections()
    }

    private func build(from items: [MenuBarStatusItem]) {
        let store = MenuBarSectionStore.shared
        let ownBundleID = Bundle.main.bundleIdentifier
        let agentPID = MenuBarAgentHost.agentPID

        var appRows: [String: Row] = [:]
        for pid in Set(items.map(\.pid)) where pid != agentPID {
            guard let app = NSRunningApplication(processIdentifier: pid),
                  let key = MenuBarSectionStore.key(for: app), key != ownBundleID else { continue }
            appRows[key] = Row(
                id: key, title: app.localizedName ?? key, icon: app.icon, symbolName: "app",
                isRunning: true, section: store.section(for: key)
            )
        }
        for (key, section) in store.assignments where appRows[key] == nil && !key.hasPrefix("system:") {
            appRows[key] = Row(
                id: key, title: store.names[key] ?? key,
                icon: NSWorkspace.shared.urlForApplication(withBundleIdentifier: key).map { NSWorkspace.shared.icon(forFile: $0.path) },
                symbolName: "app", isRunning: false, section: section
            )
        }

        let systemRows = MenuBarSystemItem.allCases.map { item in
            Row(id: item.key, title: item.title, icon: nil, symbolName: item.symbolName, isRunning: true, section: store.section(for: item.key))
        }
        rows = appRows.values.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending } + systemRows
    }
}