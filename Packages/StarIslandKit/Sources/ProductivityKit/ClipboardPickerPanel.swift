import AppKit
import SwiftUI

private final class KeyableFloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
public final class ClipboardPickerPanelController {
    public static let shared = ClipboardPickerPanelController()

    private var panel: KeyableFloatingPanel?
    private weak var previousFrontmostApp: NSRunningApplication?
    private var keyMonitor: Any?

    public init() {}

    public var isVisible: Bool {
        panel?.isVisible ?? false
    }

    public func present(with manager: ClipboardManager? = nil) {
        let resolvedManager = manager ?? .shared
        previousFrontmostApp = NSWorkspace.shared.frontmostApplication

        if panel == nil {
            let newPanel = KeyableFloatingPanel(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            newPanel.isFloatingPanel = true
            newPanel.level = .statusBar
            newPanel.backgroundColor = .clear
            newPanel.isOpaque = false
            newPanel.hasShadow = true
            newPanel.hidesOnDeactivate = false
            newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
            panel = newPanel
        }

        guard let panel else { return }

        let rootView = ClipboardPickerContentView(
            manager: resolvedManager,
            onCommitItem: { [weak self] item in
                self?.commitSelection(item, manager: resolvedManager)
            },
            onClose: { [weak self] in
                self?.dismiss()
            }
        )
        panel.contentView = NSHostingView(rootView: rootView)

        positionPanelNearMouseOrCenter(panel)
        panel.makeKeyAndOrderFront(nil)
        installEscapeKeyMonitor()
    }

    public func dismiss() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        panel?.orderOut(nil)
    }

    private func commitSelection(_ item: ClipboardHistoryItem, manager: ClipboardManager) {
        dismiss()
        if let targetApp = previousFrontmostApp,
           targetApp.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            targetApp.activate()
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 80_000_000)
            manager.copyToPasteboard(item, simulatePaste: true)
        }
    }

    private func positionPanelNearMouseOrCenter(_ panel: NSPanel) {
        let mouseLoc = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens.first

        guard let visibleFrame = screen?.visibleFrame else { return }
        let size = panel.frame.size
        var originX = mouseLoc.x - size.width * 0.5
        var originY = mouseLoc.y - size.height * 0.45

        originX = max(visibleFrame.minX + 16, min(originX, visibleFrame.maxX - size.width - 16))
        originY = max(visibleFrame.minY + 16, min(originY, visibleFrame.maxY - size.height - 16))
        panel.setFrameOrigin(NSPoint(x: originX, y: originY))
    }

    private func installEscapeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.dismiss()
                return nil
            }
            return event
        }
    }
}

struct ClipboardPickerContentView: View {
    @ObservedObject var manager: ClipboardManager
    let onCommitItem: (ClipboardHistoryItem) -> Void
    let onClose: () -> Void

    @State private var selectedID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            headerSearchBar
            Divider().opacity(0.25)
            categoryFilterStrip
            Divider().opacity(0.2)
            itemListBody
            Divider().opacity(0.25)
            footerShortcutBar
        }
        .frame(width: 480, height: 420)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.14), lineWidth: 1)
        )
        .onAppear {
            selectedID = manager.filteredItems.first?.id
        }
        .onChange(of: manager.searchQuery) { _, _ in
            selectedID = manager.filteredItems.first?.id
        }
    }

    private var headerSearchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("搜索剪贴板文本、链接或来源应用…", text: $manager.searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .onSubmit {
                    if let current = selectedItem ?? manager.filteredItems.first {
                        onCommitItem(current)
                    }
                }
            if !manager.searchQuery.isEmpty {
                Button {
                    manager.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(5)
                    .background(Circle().fill(Color.primary.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .help("关闭剪贴板选择器")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private var categoryFilterStrip: some View {
        HStack(spacing: 8) {
            filterChip(title: "全部", kind: nil)
            ForEach(ClipboardPayloadKind.allCases, id: \.rawValue) { kind in
                filterChip(title: kind.title, kind: kind)
            }
            Spacer()
            Text("共 \(manager.filteredItems.count) 条")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }

    private func filterChip(title: String, kind: ClipboardPayloadKind?) -> some View {
        let isSelected = manager.selectedKindFilter == kind
        return Button {
            manager.selectedKindFilter = kind
            selectedID = manager.filteredItems.first?.id
        } label: {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor.opacity(0.22) : Color.primary.opacity(0.06))
                )
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
    }

    private var itemListBody: some View {
        Group {
            if manager.filteredItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text("暂无匹配的剪贴板历史")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("密码管理器隐私条目会自动跳过不入库")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(manager.filteredItems) { item in
                            ClipboardItemRowView(
                                item: item,
                                isSelected: selectedID == item.id,
                                onSelect: {
                                    selectedID = item.id
                                    onCommitItem(item)
                                },
                                onTogglePin: {
                                    manager.togglePin(id: item.id)
                                },
                                onDelete: {
                                    manager.remove(id: item.id)
                                }
                            )
                        }
                    }
                    .padding(10)
                }
            }
        }
    }

    private var footerShortcutBar: some View {
        HStack {
            Text("单击或按 ⏎ 直接粘贴 · 图钉置顶常驻 · Esc 关闭")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            if !manager.items.isEmpty {
                Button("清空未置顶") {
                    manager.clearAll(keepPinned: true)
                }
                .buttonStyle(.plain)
                .font(.caption2)
                .foregroundStyle(.red.opacity(0.85))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var selectedItem: ClipboardHistoryItem? {
        guard let selectedID else { return nil }
        return manager.filteredItems.first(where: { $0.id == selectedID })
    }
}

private struct ClipboardItemRowView: View {
    let item: ClipboardHistoryItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.kind.iconSymbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 22)

            if item.kind == .image, let data = item.imageThumbnailPNG, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 38, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.textContent)
                    .font(.system(size: 12.5))
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    if let app = item.sourceAppName, !app.isEmpty {
                        Text(app)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    if item.wasURLCleaned {
                        Text("已去追踪参数")
                            .font(.system(size: 9.5, weight: .medium))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.green.opacity(0.18)))
                            .foregroundStyle(.green)
                    }
                }
            }

            Spacer(minLength: 4)

            Button(action: onTogglePin) {
                Image(systemName: item.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 11))
                    .foregroundStyle(item.isPinned ? Color.orange : Color.secondary)
            }
            .buttonStyle(.plain)
            .help(item.isPinned ? "取消置顶" : "置顶此条记录")

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("删除此条记录")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.primary.opacity(0.04))
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }
}
