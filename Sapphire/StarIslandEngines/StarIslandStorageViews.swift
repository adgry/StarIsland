//
//  StarIslandStorageViews.swift
//  Sapphire
//

#if !SAPPHIRE_FULL_BUILD
import AppKit
import SwiftUI

extension StorageCategory {
    var localizedTitle: String {
        switch self {
        case .caches: "缓存文件"
        case .trash: "废纸篓"
        case .downloads: "下载目录"
        case .largeFiles: "大文件"
        case .oldFiles: "陈旧文件"
        case .languagePacks: "多语言包"
        case .duplicates: "重复文件"
        case .appSupport: "应用支持"
        case .other: "其他项目"
        }
    }
}

struct StorageWorkspaceView: View {
    @ObservedObject var model: StorageViewModel

    var body: some View {
        let snap = model.spaceMapSnapshot(maximumItems: 12)
        VStack(alignment: .leading, spacing: 16) {
            SettingsCard(title: "磁盘空间概览", description: "扫描大文件、应用缓存与重复内容，所有清理操作均安全移入废纸篓。") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label(model.volumeName, systemImage: "internaldrive.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                        if model.total > 0 {
                            Text("已用 \(ByteCountFormatter.string(fromByteCount: model.used, countStyle: .file)) / 共 \(ByteCountFormatter.string(fromByteCount: model.total, countStyle: .file))（可用 \(ByteCountFormatter.string(fromByteCount: model.available, countStyle: .file))）")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.secondary.opacity(0.18))
                            Capsule()
                                .fill(LinearGradient(colors: [.cyan, .blue, .purple], startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(8, geo.size.width * snap.usedRatio))
                        }
                    }
                    .frame(height: 10)

                    HStack(spacing: 10) {
                        if model.isLoading {
                            ProgressView().controlSize(.small)
                            Text(model.indexingLabel.isEmpty ? "正在扫描存储目录…" : model.indexingLabel)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("取消") { model.cancelScan() }
                                .buttonStyle(.bordered)
                        } else {
                            Button("扫描空间") { model.rescan() }
                                .buttonStyle(.borderedProminent)
                            Toggle("深度扫描重复文件", isOn: $model.deepScanEnabled)
                                .toggleStyle(.checkbox)
                                .font(.system(size: 12))
                            Spacer()
                            if model.reclaimableBytes > 0 {
                                Text("可释放约 \(ByteCountFormatter.string(fromByteCount: model.reclaimableBytes, countStyle: .file))")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
                .padding(16)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    categoryChip(title: "全部", isSelected: model.categoryFilter == nil) {
                        model.categoryFilter = nil
                    }
                    ForEach(StorageCategory.allCases, id: \.self) { cat in
                        categoryChip(title: cat.localizedTitle, isSelected: model.categoryFilter == cat) {
                            model.categoryFilter = cat
                        }
                    }
                }
            }

            if model.confirmingRemoval {
                HStack {
                    Image(systemName: "trash.circle.fill").foregroundStyle(.orange)
                    Text("确认将选中的 \(model.pendingRemovalEntries.count) 个项目移入废纸篓？")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Button("取消") { model.cancelRemovalRequest() }
                        .buttonStyle(.bordered)
                    Button("移入废纸篓", role: .destructive) { model.removeConfirmed() }
                        .buttonStyle(.borderedProminent)
                }
                .padding(12)
                .background(Color.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
            }

            SettingsCard(title: "目录与文件明细", description: "点击文件夹可下钻浏览，或在访达中定位。") {
                let items = Array(model.filteredAndSortedEntries.prefix(60))
                if items.isEmpty {
                    Text(model.isLoading ? "正在建立存储索引…" : "点击上方「扫描空间」分析当前磁盘占用。")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .padding(20)
                } else {
                    VStack(spacing: 0) {
                        ForEach(items) { entry in
                            HStack(spacing: 10) {
                                Image(systemName: entry.isDirectory ? "folder.fill" : "doc.fill")
                                    .foregroundStyle(entry.category.color)
                                    .frame(width: 18)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.name)
                                        .font(.system(size: 13, weight: .medium))
                                        .lineLimit(1)
                                    Text(entry.url.path)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text(ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file))
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                Button {
                                    model.reveal(entry)
                                } label: {
                                    Image(systemName: "magnifyingglass.circle")
                                }
                                .buttonStyle(.borderless)
                                .help("在访达中显示")

                                if !entry.isSystemProtected {
                                    Button(role: .destructive) {
                                        model.requestRemoval(entry)
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                    .help("移入废纸篓")
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                model.open(entry)
                            }
                            Divider().padding(.leading, 44)
                        }
                    }
                }
            }
        }
        .onAppear {
            model.refreshCapacity()
            if model.entries.isEmpty {
                model.refreshFromCache()
            }
        }
    }

    private func categoryChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.14), in: Capsule())
                .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

@MainActor
private enum SharedNotchStorageHolder {
    static let viewModel = StorageViewModel()
}

struct StorageDetailView: View {
    @ObservedObject private var model = SharedNotchStorageHolder.viewModel

    var body: some View {
        let ratio = model.total > 0 ? min(1.0, Double(model.used) / Double(model.total)) : 0
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("存储空间", systemImage: "internaldrive.fill")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                if model.total > 0 {
                    Text("剩余 \(ByteCountFormatter.string(fromByteCount: model.available, countStyle: .file))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Button {
                    model.rescan()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.borderless)
            }

            ProgressView(value: ratio)
                .tint(ratio > 0.88 ? .orange : .cyan)

            ForEach(Array(model.filteredAndSortedEntries.prefix(4))) { item in
                HStack {
                    Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(item.category.color)
                    Text(item.name)
                        .font(.system(size: 11))
                        .lineLimit(1)
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .onAppear { model.refreshCapacity() }
    }
}

struct StorageWidgetView: View {
    @ObservedObject private var model = SharedNotchStorageHolder.viewModel

    var body: some View {
        let ratio = model.total > 0 ? min(1.0, Double(model.used) / Double(model.total)) : 0
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "internaldrive.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.cyan)
                Text("磁盘")
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                Text("\(Int((ratio * 100).rounded()))%")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: ratio)
                .tint(ratio > 0.88 ? .orange : .cyan)
            if model.total > 0 {
                Text("可用 \(ByteCountFormatter.string(fromByteCount: model.available, countStyle: .file))")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onAppear { model.refreshCapacity() }
    }
}
#endif
