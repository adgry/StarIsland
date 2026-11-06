//
//  InstalledAppUpdatesBatchControls.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2026-10-07
//

import SwiftUI

struct InstalledAppUpdatesBatchBar: View {
    @ObservedObject var checker: InstalledAppUpdatesChecker

    var body: some View {
        let selectableCount = checker.entries.filter(checker.isSelectable).count
        let selectedCount = checker.selectedUpdatableCount
        let skipped = checker.skippedEntries

        VStack(alignment: .leading, spacing: 8) {
            if selectableCount > 1 || selectedCount > 0 || !skipped.isEmpty {
                HStack(spacing: 10) {
                    if selectableCount > 1 || selectedCount > 0 {
                        Button(selectedCount == selectableCount && selectableCount > 0 ? "取消全选" : "全选") {
                            if selectedCount == selectableCount {
                                checker.clearSelection()
                            } else {
                                checker.selectAllUpdates()
                            }
                        }
                        .buttonStyle(.link)
                        .font(.caption)

                        Text(selectedCount == 0 ? "未选择" : "已选 \(selectedCount) 项")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if !skipped.isEmpty {
                        Menu {
                            ForEach(skipped) { entry in
                                Button("取消跳过 \(entry.name) \(checker.skippedVersion(for: entry.id) ?? "")") {
                                    checker.unskip(entryID: entry.id)
                                }
                            }
                        } label: {
                            Label("已跳过（\(skipped.count)）", systemImage: "forward.end")
                                .font(.caption)
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }

                    if selectableCount > 1 || selectedCount > 0 {
                        Button {
                            checker.updateSelected()
                        } label: {
                            Label("更新所选项", systemImage: "arrow.down.circle")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(selectedCount == 0)
                    }
                }
            }

            if let notice = checker.homebrewNotice {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "terminal")
                        .foregroundStyle(.secondary)
                    Text(notice)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Button {
                        checker.homebrewNotice = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("关闭")
                }
            }
        }
    }
}

struct InstalledAppUpdateSelectionToggle: View {
    @ObservedObject var checker: InstalledAppUpdatesChecker
    let entry: InstalledAppUpdateEntry

    var body: some View {
        if checker.isSelectable(entry) {
            Toggle(
                "选择 \(entry.name)",
                isOn: Binding(
                    get: { checker.isSelected(entry.id) },
                    set: { checker.setSelected($0, for: entry.id) }
                )
            )
            .toggleStyle(.checkbox)
            .labelsHidden()
        } else if entry.status.isUpdateAvailable {
            Toggle("选择 \(entry.name)", isOn: .constant(false))
                .toggleStyle(.checkbox)
                .labelsHidden()
                .disabled(true)
                .help("需在对应行单独更新 — 不包含在批量更新中")
        }
    }
}

struct InstalledAppUpdateSkipMenuItems: View {
    @ObservedObject var checker: InstalledAppUpdatesChecker
    let entry: InstalledAppUpdateEntry

    var body: some View {
        if let skipped = checker.skippedVersion(for: entry.id) {
            Button("取消跳过版本 \(skipped)") { checker.unskip(entryID: entry.id) }
        } else if let version = checker.skippableVersion(for: entry) {
            Button("跳过版本 \(version)") { checker.skipCurrentUpdate(for: entry.id) }
        }
    }
}