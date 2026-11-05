import AppKit
import ApplicationServices
import Combine
import CoreGraphics
import Foundation
import IslandCore
import SwiftUI

/// 窗口磁吸分屏区域枚举（涵盖左右半屏、全屏填满、四角四分屏与左中右三分屏）
public enum SnapZone: String, CaseIterable, Codable, Identifiable, Sendable {
    case leftHalf, rightHalf, topMaximize
    case topLeftQuarter, topRightQuarter, bottomLeftQuarter, bottomRightQuarter
    case leftThird, centerThird, rightThird

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .leftHalf: return "左半屏"
        case .rightHalf: return "右半屏"
        case .topMaximize: return "全屏填满"
        case .topLeftQuarter: return "左上四分屏"
        case .topRightQuarter: return "右上四分屏"
        case .bottomLeftQuarter: return "左下四分屏"
        case .bottomRightQuarter: return "右下四分屏"
        case .leftThird: return "左侧三分屏"
        case .centerThird: return "居中三分屏"
        case .rightThird: return "右侧三分屏"
        }
    }

    public var iconSymbol: String {
        switch self {
        case .leftHalf: return "rectangle.lefthalf.inset.filled"
        case .rightHalf: return "rectangle.righthalf.inset.filled"
        case .topMaximize: return "arrow.up.left.and.arrow.down.right.rectangle.fill"
        case .topLeftQuarter: return "rectangle.inset.topleft.filled"
        case .topRightQuarter: return "rectangle.inset.topright.filled"
        case .bottomLeftQuarter: return "rectangle.inset.bottomleft.filled"
        case .bottomRightQuarter: return "rectangle.inset.bottomright.filled"
        case .leftThird: return "rectangle.split.3x1"
        case .centerThird: return "rectangle.center.inset.filled"
        case .rightThird: return "rectangle.split.3x1.fill"
        }
    }
}

/// 窗口分屏几何计算与屏幕边缘悬停判定纯函数
public enum WindowSnapGeometry {
    /// 计算给定分屏区域在目标显示器 `visibleFrame`（AppKit 左下角坐标系）内的精确矩形
    public static func targetFrame(for zone: SnapZone, in visibleFrame: CGRect) -> CGRect {
        let minX = visibleFrame.minX, minY = visibleFrame.minY
        let width = visibleFrame.width, height = visibleFrame.height
        let halfW = (width / 2.0).rounded(.down)
        let halfH = (height / 2.0).rounded(.down)
        let thirdW = (width / 3.0).rounded(.down)

        switch zone {
        case .leftHalf: return CGRect(x: minX, y: minY, width: halfW, height: height)
        case .rightHalf: return CGRect(x: minX + halfW, y: minY, width: width - halfW, height: height)
        case .topMaximize: return visibleFrame
        case .topLeftQuarter: return CGRect(x: minX, y: minY + halfH, width: halfW, height: height - halfH)
        case .topRightQuarter: return CGRect(x: minX + halfW, y: minY + halfH, width: width - halfW, height: height - halfH)
        case .bottomLeftQuarter: return CGRect(x: minX, y: minY, width: halfW, height: halfH)
        case .bottomRightQuarter: return CGRect(x: minX + halfW, y: minY, width: width - halfW, height: halfH)
        case .leftThird: return CGRect(x: minX, y: minY, width: thirdW, height: height)
        case .centerThird: return CGRect(x: minX + thirdW, y: minY, width: thirdW, height: height)
        case .rightThird: return CGRect(x: minX + thirdW * 2.0, y: minY, width: width - thirdW * 2.0, height: height)
        }
    }

    /// 判定当前光标位置（AppKit 屏幕坐标系）是否命中屏幕边缘或四角热区
    public static func hoveredZone(cursor: CGPoint, in screenFrame: CGRect, edgeThreshold: CGFloat = 24) -> SnapZone? {
        guard edgeThreshold > 0, screenFrame.width > 0, screenFrame.height > 0,
              cursor.x >= screenFrame.minX, cursor.x <= screenFrame.maxX,
              cursor.y >= screenFrame.minY, cursor.y <= screenFrame.maxY else { return nil }

        let dxLeft = cursor.x - screenFrame.minX, dxRight = screenFrame.maxX - cursor.x
        let dyBottom = cursor.y - screenFrame.minY, dyTop = screenFrame.maxY - cursor.y
        let nearLeft = dxLeft <= edgeThreshold, nearRight = dxRight <= edgeThreshold
        let nearTop = dyTop <= edgeThreshold, nearBottom = dyBottom <= edgeThreshold
        let cornerSpan = max(edgeThreshold * 2.5, 56)

        if (nearLeft && dyTop <= cornerSpan) || (nearTop && dxLeft <= cornerSpan) { return .topLeftQuarter }
        if (nearRight && dyTop <= cornerSpan) || (nearTop && dxRight <= cornerSpan) { return .topRightQuarter }
        if (nearLeft && dyBottom <= cornerSpan) || (nearBottom && dxLeft <= cornerSpan) { return .bottomLeftQuarter }
        if (nearRight && dyBottom <= cornerSpan) || (nearBottom && dxRight <= cornerSpan) { return .bottomRightQuarter }
        if nearLeft { return .leftHalf }
        if nearRight { return .rightHalf }
        if nearTop { return .topMaximize }
        return nil
    }
}

/// 窗口磁吸毛玻璃预览框与分屏落位管理器
@MainActor
public final class WindowSnapManager: ObservableObject {
    public static let shared = WindowSnapManager()

    @Published public private(set) var activeSnapZone: SnapZone?
    @Published public private(set) var isDraggingWindow: Bool = false

    private let settingsStore: SettingsStore
    private let eventTapBus: EventTapBus
    private let windowRegistry: WindowRegistry
    private weak var switcherController: WindowSwitcherPanelController?

    private var tapRegistrationID: UUID?
    private var previewPanel: NSPanel?
    private var previewLabel: NSTextField?

    private var trackedWindowElement: AXUIElement?
    private var initialWindowQuartzOrigin: CGPoint?
    private var initialMouseQuartzPoint: CGPoint?
    private var activeScreen: NSScreen?

    public init(
        settingsStore: SettingsStore? = nil,
        eventTapBus: EventTapBus? = nil,
        windowRegistry: WindowRegistry? = nil,
        switcherController: WindowSwitcherPanelController? = nil
    ) {
        self.settingsStore = settingsStore ?? .shared
        self.eventTapBus = eventTapBus ?? .shared
        self.windowRegistry = windowRegistry ?? .shared
        self.switcherController = switcherController
    }

    public func bindSwitcher(_ controller: WindowSwitcherPanelController) {
        self.switcherController = controller
    }

    public func start() {
        guard tapRegistrationID == nil else { return }
        let mask = EventTapEntry.mask(for: [.leftMouseDown, .leftMouseDragged, .leftMouseUp, .keyDown])
        let entry = EventTapEntry(name: "WindowSnapAndShortcuts", priority: 65, eventMask: mask) { [weak self] context in
            guard let self else { return .passThrough }
            return self.handleTapEventNonisolated(context)
        }
        tapRegistrationID = eventTapBus.register(entry)
    }

    public func stop() {
        if let id = tapRegistrationID {
            eventTapBus.unregister(id)
            tapRegistrationID = nil
        }
        hidePreviewPanel()
        resetDragTracking()
    }

    /// 将当前前台聚焦窗口吸附到指定分屏区域
    @discardableResult
    public func snapFocusedWindow(to zone: SnapZone, on screen: NSScreen? = nil) -> Bool {
        guard let axWindow = AXWindowHelper.focusedWindowElement() else { return false }
        let resolvedScreen = screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let targetScreen = resolvedScreen else { return false }
        let frame = WindowSnapGeometry.targetFrame(for: zone, in: targetScreen.visibleFrame)
        return AXWindowHelper.setAppKitFrame(frame, for: axWindow)
    }

    // MARK: - 事件分发与拖拽状态跟踪

    private nonisolated func handleTapEventNonisolated(_ context: EventTapContext) -> EventTapDisposition {
        if context.eventType == .keyDown {
            let ctrlAlt: CGEventFlags = [.maskControl, .maskAlternate]
            let relevantFlags = context.flags.intersection([.maskControl, .maskAlternate, .maskCommand, .maskShift])
            if relevantFlags == ctrlAlt {
                if let mappedZone = Self.shortcutSnapZone(forKeyCode: context.keyCode) {
                    Task { @MainActor [weak self] in
                        guard let self, self.settingsStore.settings.enableWindowSnap else { return }
                        _ = self.snapFocusedWindow(to: mappedZone)
                    }
                    return .suppress
                }
                // ⌃⌥Tab 呼出增强型窗口切换浮层
                if context.keyCode == 48 {
                    Task { @MainActor [weak self] in
                        guard let self, self.settingsStore.settings.enableWindowSwitcher else { return }
                        self.switcherController?.toggle()
                    }
                    return .suppress
                }
            }
            return .passThrough
        }

        Task { @MainActor [weak self] in
            self?.processMouseDragEvent(context)
        }
        return .passThrough
    }

    private nonisolated static func shortcutSnapZone(forKeyCode keyCode: Int64) -> SnapZone? {
        switch keyCode {
        case 123: return .leftHalf            // ⌃⌥←
        case 124: return .rightHalf           // ⌃⌥→
        case 126, 36: return .topMaximize     // ⌃⌥↑ 或 ⌃⌥↩
        case 32: return .topLeftQuarter       // ⌃⌥U
        case 34: return .topRightQuarter      // ⌃⌥I
        case 38: return .bottomLeftQuarter    // ⌃⌥J
        case 40: return .bottomRightQuarter   // ⌃⌥K
        case 2: return .leftThird             // ⌃⌥D
        case 3: return .centerThird           // ⌃⌥F
        case 5: return .rightThird            // ⌃⌥G
        default: return nil
        }
    }

    private func processMouseDragEvent(_ context: EventTapContext) {
        guard settingsStore.settings.enableWindowSnap else {
            if previewPanel?.isVisible == true { hidePreviewPanel() }
            return
        }

        switch context.eventType {
        case .leftMouseDown:
            initialMouseQuartzPoint = context.location
            if let focused = AXWindowHelper.focusedWindowElement(),
               let frame = AXWindowHelper.readQuartzFrame(of: focused) {
                trackedWindowElement = focused
                initialWindowQuartzOrigin = frame.origin
            } else {
                trackedWindowElement = nil
                initialWindowQuartzOrigin = nil
            }
            isDraggingWindow = false
            activeSnapZone = nil

        case .leftMouseDragged:
            guard let windowEl = trackedWindowElement,
                  let startWinOrigin = initialWindowQuartzOrigin,
                  let startMouse = initialMouseQuartzPoint else {
                return
            }

            let mouseDelta = hypot(context.location.x - startMouse.x, context.location.y - startMouse.y)
            guard mouseDelta >= 10 else { return }

            if !isDraggingWindow {
                guard let currentFrame = AXWindowHelper.readQuartzFrame(of: windowEl) else { return }
                let winDelta = hypot(currentFrame.origin.x - startWinOrigin.x, currentFrame.origin.y - startWinOrigin.y)
                guard winDelta >= 4 else { return }
                isDraggingWindow = true
            }

            let primaryHeight = AXWindowHelper.primaryScreenHeight()
            let appKitCursor = AXWindowHelper.appKitPoint(fromQuartz: context.location, primaryHeight: primaryHeight)
            guard let screen = NSScreen.screens.first(where: {
                appKitCursor.x >= $0.frame.minX && appKitCursor.x <= $0.frame.maxX &&
                appKitCursor.y >= $0.frame.minY && appKitCursor.y <= $0.frame.maxY
            }) else {
                hidePreviewPanel()
                return
            }

            activeScreen = screen
            if let zone = WindowSnapGeometry.hoveredZone(cursor: appKitCursor, in: screen.frame, edgeThreshold: 22) {
                let target = WindowSnapGeometry.targetFrame(for: zone, in: screen.visibleFrame).insetBy(dx: 6, dy: 6)
                if activeSnapZone != zone {
                    activeSnapZone = zone
                }
                showPreviewPanel(frame: target, title: zone.title)
            } else {
                activeSnapZone = nil
                hidePreviewPanel()
            }

        case .leftMouseUp:
            if isDraggingWindow,
               let zone = activeSnapZone,
               let windowEl = trackedWindowElement,
               let screen = activeScreen {
                let finalFrame = WindowSnapGeometry.targetFrame(for: zone, in: screen.visibleFrame)
                _ = AXWindowHelper.setAppKitFrame(finalFrame, for: windowEl)
            }
            hidePreviewPanel()
            resetDragTracking()

        default:
            break
        }
    }

    private func resetDragTracking() {
        trackedWindowElement = nil
        initialWindowQuartzOrigin = nil
        initialMouseQuartzPoint = nil
        activeScreen = nil
        activeSnapZone = nil
        isDraggingWindow = false
    }

    private func showPreviewPanel(frame: CGRect, title: String) {
        let panel: NSPanel
        if let existing = previewPanel {
            panel = existing
        } else {
            let created = NSPanel(
                contentRect: frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            created.isFloatingPanel = true
            created.level = .statusBar
            created.backgroundColor = .clear
            created.isOpaque = false
            created.hasShadow = true
            created.ignoresMouseEvents = true
            created.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

            let effect = NSVisualEffectView(frame: NSRect(origin: .zero, size: frame.size))
            effect.autoresizingMask = [.width, .height]
            effect.material = .hudWindow
            effect.blendingMode = .behindWindow
            effect.state = .active
            effect.wantsLayer = true
            effect.layer?.cornerRadius = 16
            effect.layer?.masksToBounds = true
            effect.layer?.borderWidth = 2.0
            effect.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.75).cgColor

            let label = NSTextField(labelWithString: title)
            label.font = .systemFont(ofSize: 15, weight: .semibold)
            label.textColor = .white
            label.alignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            effect.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: effect.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: effect.centerYAnchor)
            ])

            created.contentView = effect
            previewPanel = created
            previewLabel = label
            panel = created
        }

        previewLabel?.stringValue = "松手吸附：\(title)"
        if !panel.isVisible {
            panel.setFrame(frame, display: true)
            panel.orderFrontRegardless()
        } else {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.14
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(frame, display: true)
            }
        }
    }

    private func hidePreviewPanel() {
        previewPanel?.orderOut(nil)
    }
}

/// 增强型桌面窗口切换浮层控制器（展示实时缩略图、窗口标题、应用图标，支持键盘快速检索跳转）
@MainActor
public final class WindowSwitcherPanelController: ObservableObject {
    public static let shared = WindowSwitcherPanelController()

    @Published public private(set) var isPresented: Bool = false
    @Published public var filterQuery: String = ""
    @Published public var selectedIndex: Int = 0

    public let windowRegistry: WindowRegistry
    private var switcherPanel: NSPanel?
    private var localKeyMonitor: Any?

    public init(windowRegistry: WindowRegistry? = nil) {
        self.windowRegistry = windowRegistry ?? .shared
    }

    public var filteredWindows: [ManagedWindowInfo] {
        let query = filterQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return windowRegistry.windows }
        return windowRegistry.windows.filter {
            $0.displayTitle.lowercased().contains(query) || $0.appName.lowercased().contains(query)
        }
    }

    public func toggle() {
        isPresented ? dismiss() : present()
    }

    public func present() {
        let items = windowRegistry.refreshWindows(includeMinimized: true)
        filterQuery = ""
        selectedIndex = items.count > 1 ? 1 : 0
        ensurePanel()

        if let screen = NSScreen.main ?? NSScreen.screens.first, let panel = switcherPanel {
            let size = CGSize(width: min(820, screen.visibleFrame.width - 80), height: 420)
            let origin = CGPoint(
                x: screen.visibleFrame.midX - size.width / 2,
                y: screen.visibleFrame.midY - size.height / 2
            )
            panel.setFrame(CGRect(origin: origin, size: size), display: true)
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate()
        }

        isPresented = true
        installKeyMonitor()
        Task {
            await windowRegistry.refreshThumbnails(for: items)
        }
    }

    public func dismiss() {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
        switcherPanel?.orderOut(nil)
        isPresented = false
    }

    public func moveSelection(by delta: Int) {
        let list = filteredWindows
        guard !list.isEmpty else { selectedIndex = 0; return }
        selectedIndex = (selectedIndex + delta + list.count) % list.count
    }

    public func activateSelected() {
        let list = filteredWindows
        guard list.indices.contains(selectedIndex) else { dismiss(); return }
        let target = list[selectedIndex]
        dismiss()
        _ = windowRegistry.activateWindow(target)
    }

    private func ensurePanel() {
        guard switcherPanel == nil else { return }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 400),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.contentView = NSHostingView(rootView: WindowSwitcherOverlayView(controller: self))
        switcherPanel = panel
    }

    private func installKeyMonitor() {
        if let monitor = localKeyMonitor { NSEvent.removeMonitor(monitor) }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isPresented else { return event }
            switch event.keyCode {
            case 53: self.dismiss(); return nil
            case 36, 76: self.activateSelected(); return nil
            case 123, 126: self.moveSelection(by: -1); return nil
            case 124, 125, 48: self.moveSelection(by: 1); return nil
            default: return event
            }
        }
    }
}

private struct WindowSwitcherOverlayView: View {
    @ObservedObject var controller: WindowSwitcherPanelController
    @ObservedObject var registry: WindowRegistry

    init(controller: WindowSwitcherPanelController) {
        self.controller = controller
        self.registry = controller.windowRegistry
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "macwindow.on.rectangle").foregroundStyle(.cyan)
                TextField("输入窗口标题或应用名快速筛选…", text: $controller.filterQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .medium))
                Spacer()
                Text("方向键选择 · 回车切换 · Esc 关闭").font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))

            if controller.filteredWindows.isEmpty {
                Spacer()
                Text("暂无匹配的活动窗口").foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(Array(controller.filteredWindows.enumerated()), id: \.element.id) { idx, win in
                            let selected = (idx == controller.selectedIndex)
                            Button {
                                controller.selectedIndex = idx
                                controller.activateSelected()
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.28))
                                        if let thumb = registry.thumbnails[win.windowID] {
                                            Image(nsImage: thumb).resizable().scaledToFit()
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        } else {
                                            Image(nsImage: registry.appIcon(for: win.bundleIdentifier, pid: win.ownerPID))
                                                .resizable().frame(width: 48, height: 48)
                                        }
                                    }
                                    .frame(width: 210, height: 132)

                                    HStack(spacing: 6) {
                                        Image(nsImage: registry.appIcon(for: win.bundleIdentifier, pid: win.ownerPID))
                                            .resizable().frame(width: 18, height: 18)
                                        Text(win.displayTitle).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                                    }
                                    Text(win.isMinimized ? "\(win.appName) · 已最小化" : win.appName)
                                        .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                                }
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 14).fill(selected ? Color.accentColor.opacity(0.26) : Color.white.opacity(0.05)))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? Color.accentColor : Color.white.opacity(0.12), lineWidth: selected ? 2 : 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.18), lineWidth: 1))
    }
}
