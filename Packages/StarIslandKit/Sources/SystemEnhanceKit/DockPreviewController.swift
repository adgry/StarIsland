import AppKit
import ApplicationServices
import Combine
import CoreGraphics
import Foundation
import IslandCore
import SwiftUI

/// Dock 常用应用布局备份单项
public struct DockAppBackupEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: String { bundleIdentifier.isEmpty ? bundlePath : bundleIdentifier }
    public let bundleIdentifier: String
    public let label: String
    public let bundlePath: String

    public init(bundleIdentifier: String, label: String, bundlePath: String) {
        self.bundleIdentifier = bundleIdentifier
        self.label = label
        self.bundlePath = bundlePath
    }
}

/// Dock 常用应用布局完整备份包
public struct DockLayoutBackup: Codable, Equatable, Sendable {
    public let version: Int
    public let exportedAt: Date
    public let apps: [DockAppBackupEntry]

    public init(version: Int = 1, exportedAt: Date = Date(), apps: [DockAppBackupEntry]) {
        self.version = version
        self.exportedAt = exportedAt
        self.apps = apps
    }
}

/// Dock 图标命中元数据
public struct DockHoveredAppItem: Equatable, Sendable {
    public let bundleIdentifier: String
    public let appName: String
    public let pid: pid_t
    public let iconAppKitFrame: CGRect
}

/// Dock 悬停实时窗口预览浮层、点击当前激活图标最小化与 Dock 布局导入导出控制器
@MainActor
public final class DockPreviewController: ObservableObject {
    public static let shared = DockPreviewController()

    @Published public private(set) var hoveredApp: DockHoveredAppItem?
    @Published public private(set) var previewWindows: [ManagedWindowInfo] = []
    @Published public private(set) var isPreviewVisible: Bool = false

    public let windowRegistry: WindowRegistry
    private let settingsStore: SettingsStore
    private let eventTapBus: EventTapBus

    private var tapRegistrationID: UUID?
    private var previewPanel: NSPanel?
    private var lastHoverCheckTime: TimeInterval = 0
    private var hideDismissTask: Task<Void, Never>?

    public init(
        settingsStore: SettingsStore? = nil,
        eventTapBus: EventTapBus? = nil,
        windowRegistry: WindowRegistry? = nil
    ) {
        self.settingsStore = settingsStore ?? .shared
        self.eventTapBus = eventTapBus ?? .shared
        self.windowRegistry = windowRegistry ?? .shared
    }

    public func start() {
        guard tapRegistrationID == nil else { return }
        let mask = EventTapEntry.mask(for: [.mouseMoved, .leftMouseDown, .otherMouseDown])
        let entry = EventTapEntry(name: "DockHoverAndClick", priority: 60, eventMask: mask) { [weak self] context in
            guard let self else { return .passThrough }
            return self.handleEventNonisolated(context)
        }
        tapRegistrationID = eventTapBus.register(entry)
    }

    public func stop() {
        if let id = tapRegistrationID {
            eventTapBus.unregister(id)
            tapRegistrationID = nil
        }
        hideDismissTask?.cancel()
        hidePreview()
    }

    public func activatePreviewWindow(_ window: ManagedWindowInfo) {
        hidePreview()
        _ = windowRegistry.activateWindow(window)
    }

    public func closePreviewWindow(_ window: ManagedWindowInfo) {
        _ = windowRegistry.closeWindow(window)
        previewWindows.removeAll { $0.windowID == window.windowID }
        if previewWindows.isEmpty {
            hidePreview()
        } else if let hovered = hoveredApp {
            repositionPanel(above: hovered.iconAppKitFrame, count: previewWindows.count)
        }
    }

    public func hidePreview() {
        previewPanel?.orderOut(nil)
        isPreviewVisible = false
        hoveredApp = nil
        previewWindows = []
    }

    // MARK: - Dock 布局导出与导入恢复

    public func exportDockLayout() throws -> Data {
        let dockDefaults = UserDefaults(suiteName: "com.apple.dock")
        let persistentApps = (dockDefaults?.array(forKey: "persistent-apps") as? [[String: Any]]) ?? []

        var entries: [DockAppBackupEntry] = []
        for item in persistentApps {
            guard let tileData = item["tile-data"] as? [String: Any] else { continue }
            let bundleID = (tileData["bundle-identifier"] as? String) ?? ""
            let label = (tileData["file-label"] as? String) ?? ""
            var bundlePath = ""
            if let fileData = tileData["file-data"] as? [String: Any],
               let urlStr = fileData["_CFURLString"] as? String {
                if let url = URL(string: urlStr), url.isFileURL {
                    bundlePath = url.path
                } else {
                    bundlePath = urlStr
                }
            }
            if !bundleID.isEmpty || !bundlePath.isEmpty {
                entries.append(DockAppBackupEntry(bundleIdentifier: bundleID, label: label, bundlePath: bundlePath))
            }
        }

        let backup = DockLayoutBackup(exportedAt: Date(), apps: entries)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    @discardableResult
    public func importDockLayout(_ data: Data, restartDock: Bool = false) throws -> DockLayoutBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(DockLayoutBackup.self, from: data)

        var rebuiltTiles: [[String: Any]] = []
        for entry in backup.apps {
            let resolvedURL: URL?
            if !entry.bundlePath.isEmpty && FileManager.default.fileExists(atPath: entry.bundlePath) {
                resolvedURL = URL(fileURLWithPath: entry.bundlePath)
            } else if !entry.bundleIdentifier.isEmpty {
                resolvedURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: entry.bundleIdentifier)
            } else {
                resolvedURL = nil
            }

            guard let appURL = resolvedURL else { continue }
            let tileDict: [String: Any] = [
                "tile-type": "file-tile",
                "tile-data": [
                    "bundle-identifier": entry.bundleIdentifier,
                    "file-label": entry.label.isEmpty ? appURL.deletingPathExtension().lastPathComponent : entry.label,
                    "file-data": [
                        "_CFURLString": appURL.absoluteString,
                        "_CFURLStringType": 15
                    ]
                ]
            ]
            rebuiltTiles.append(tileDict)
        }

        if !rebuiltTiles.isEmpty, let dockDefaults = UserDefaults(suiteName: "com.apple.dock") {
            dockDefaults.set(rebuiltTiles, forKey: "persistent-apps")
            CFPreferencesAppSynchronize("com.apple.dock" as CFString)
            if restartDock {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
                proc.arguments = ["Dock"]
                try? proc.run()
            }
        }
        return backup
    }

    // MARK: - 悬停探测与点击激活最小化

    private nonisolated func handleEventNonisolated(_ context: EventTapContext) -> EventTapDisposition {
        switch context.eventType {
        case .mouseMoved:
            Task { @MainActor [weak self] in
                self?.evaluateMouseMoved(quartzLocation: context.location)
            }
            return .passThrough

        case .leftMouseDown:
            // 若开启“点击当前激活 Dock 图标最小化”，同步命中测试以精准拦截原生点击
            guard AXIsProcessTrusted() else { return .passThrough }
            if let hit = Self.hitTestDockAppIcon(atQuartzPoint: context.location),
               let front = NSWorkspace.shared.frontmostApplication,
               front.bundleIdentifier == hit.bundleIdentifier {
                var shouldMinimize = false
                if Thread.isMainThread {
                    shouldMinimize = MainActor.assumeIsolated {
                        self.settingsStore.settings.enableDockClickMinimize
                    }
                }
                if shouldMinimize {
                    Task { @MainActor [weak self] in
                        self?.hidePreview()
                        _ = self?.windowRegistry.minimizeOrHideApp(bundleID: hit.bundleIdentifier)
                    }
                    return .suppress
                }
            }
            return .passThrough

        default:
            return .passThrough
        }
    }

    private func evaluateMouseMoved(quartzLocation: CGPoint) {
        guard settingsStore.settings.enableDockHoverPreview, AXIsProcessTrusted() else {
            if isPreviewVisible { hidePreview() }
            return
        }

        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastHoverCheckTime >= 0.08 else { return }
        lastHoverCheckTime = now

        let primaryHeight = AXWindowHelper.primaryScreenHeight()
        let appKitCursor = AXWindowHelper.appKitPoint(fromQuartz: quartzLocation, primaryHeight: primaryHeight)

        // 若鼠标位于已显示的预览面板内部，保持浮层不收起
        if isPreviewVisible, let panel = previewPanel, panel.frame.insetBy(dx: -14, dy: -14).contains(appKitCursor) {
            hideDismissTask?.cancel()
            return
        }

        // 仅当光标靠近任一屏幕底边/左边/右边 110pt 区域内时才向 Dock 查询 AX，保障日常移动零负担
        let nearScreenDockEdge = NSScreen.screens.contains { screen in
            let f = screen.frame
            return (appKitCursor.y - f.minY <= 110)
                || (appKitCursor.x - f.minX <= 110)
                || (f.maxX - appKitCursor.x <= 110)
        }

        guard nearScreenDockEdge, let hitItem = Self.hitTestDockAppIcon(atQuartzPoint: quartzLocation) else {
            scheduleDelayedHide()
            return
        }

        hideDismissTask?.cancel()
        if hoveredApp == hitItem && isPreviewVisible {
            return
        }

        let allWindows = windowRegistry.refreshWindows(includeMinimized: true)
        let matching = allWindows.filter { $0.bundleIdentifier == hitItem.bundleIdentifier || $0.ownerPID == hitItem.pid }
        guard !matching.isEmpty else {
            hidePreview()
            return
        }

        hoveredApp = hitItem
        previewWindows = matching
        showPreview(above: hitItem.iconAppKitFrame)

        Task {
            await windowRegistry.refreshThumbnails(for: matching)
        }
    }

    private func scheduleDelayedHide() {
        guard isPreviewVisible else { return }
        hideDismissTask?.cancel()
        hideDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }
            self?.hidePreview()
        }
    }

    private nonisolated static func hitTestDockAppIcon(atQuartzPoint point: CGPoint) -> DockHoveredAppItem? {
        guard let dockApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            return nil
        }
        let dockAX = AXUIElementCreateApplication(dockApp.processIdentifier)
        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(dockAX, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let topChildren = childrenRef as? [AXUIElement] else {
            return nil
        }

        for listCandidate in topChildren {
            var roleRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(listCandidate, kAXRoleAttribute as CFString, &roleRef) == .success,
                  (roleRef as? String) == (kAXListRole as String) else {
                continue
            }

            var itemsRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(listCandidate, kAXChildrenAttribute as CFString, &itemsRef) == .success,
                  let dockItems = itemsRef as? [AXUIElement] else {
                continue
            }

            for item in dockItems {
                guard let quartzFrame = AXWindowHelper.readQuartzFrame(of: item),
                      quartzFrame.contains(point) else {
                    continue
                }

                var subroleRef: CFTypeRef?
                let subrole = (AXUIElementCopyAttributeValue(item, kAXSubroleAttribute as CFString, &subroleRef) == .success)
                    ? (subroleRef as? String ?? "")
                    : ""
                guard subrole == "AXApplicationDockItem" else { return nil }

                var titleRef: CFTypeRef?
                let title = (AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &titleRef) == .success)
                    ? (titleRef as? String ?? "")
                    : ""

                var urlRef: CFTypeRef?
                var resolvedApp: NSRunningApplication?
                if AXUIElementCopyAttributeValue(item, kAXURLAttribute as CFString, &urlRef) == .success,
                   let appURL = urlRef as? URL,
                   let bundle = Bundle(url: appURL),
                   let bid = bundle.bundleIdentifier {
                    resolvedApp = NSRunningApplication.runningApplications(withBundleIdentifier: bid).first
                }
                if resolvedApp == nil && !title.isEmpty {
                    resolvedApp = NSWorkspace.shared.runningApplications.first {
                        $0.activationPolicy == .regular && $0.localizedName == title
                    }
                }

                guard let runningApp = resolvedApp,
                      let bundleID = runningApp.bundleIdentifier else {
                    return nil
                }

                let appKitIconRect = AXWindowHelper.appKitRect(fromQuartz: quartzFrame)
                return DockHoveredAppItem(
                    bundleIdentifier: bundleID,
                    appName: runningApp.localizedName ?? title,
                    pid: runningApp.processIdentifier,
                    iconAppKitFrame: appKitIconRect
                )
            }
        }
        return nil
    }

    private func showPreview(above iconFrame: CGRect) {
        if previewPanel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 260, height: 190),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .statusBar
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
            panel.contentView = NSHostingView(rootView: DockPreviewOverlayView(controller: self))
            previewPanel = panel
        }

        repositionPanel(above: iconFrame, count: previewWindows.count)
        previewPanel?.orderFrontRegardless()
        isPreviewVisible = true
    }

    private func repositionPanel(above iconFrame: CGRect, count: Int) {
        guard let panel = previewPanel else { return }
        let visibleCount = min(max(count, 1), 4)
        let width = CGFloat(visibleCount) * 214 + 24
        let height: CGFloat = 192
        let screen = NSScreen.screens.first(where: { $0.frame.intersects(iconFrame) }) ?? NSScreen.main
        let screenFrame = screen?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)

        var originX = iconFrame.midX - width / 2
        originX = min(max(originX, screenFrame.minX + 12), screenFrame.maxX - width - 12)
        let originY = min(iconFrame.maxY + 12, screenFrame.maxY - height - 12)

        panel.setFrame(CGRect(x: originX.rounded(), y: originY.rounded(), width: width, height: height), display: true)
    }
}

private struct DockPreviewOverlayView: View {
    @ObservedObject var controller: DockPreviewController
    @ObservedObject var registry: WindowRegistry

    init(controller: DockPreviewController) {
        self.controller = controller
        self.registry = controller.windowRegistry
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let app = controller.hoveredApp {
                HStack(spacing: 6) {
                    Image(nsImage: registry.appIcon(for: app.bundleIdentifier, pid: app.pid))
                        .resizable()
                        .frame(width: 16, height: 16)
                    Text(app.appName)
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text("\(controller.previewWindows.count) 个窗口")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
            }

            HStack(spacing: 10) {
                ForEach(controller.previewWindows.prefix(4)) { win in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Text(win.displayTitle)
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Button {
                                controller.closePreviewWindow(win)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("关闭该窗口")
                        }

                        Button {
                            controller.activatePreviewWindow(win)
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.black.opacity(0.26))
                                if let image = registry.thumbnails[win.windowID] {
                                    Image(nsImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .clipShape(RoundedRectangle(cornerRadius: 7))
                                } else {
                                    Image(nsImage: registry.appIcon(for: win.bundleIdentifier, pid: win.ownerPID))
                                        .resizable()
                                        .frame(width: 40, height: 40)
                                }
                            }
                            .frame(width: 192, height: 118)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }
}
