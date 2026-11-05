import AppKit
import ApplicationServices
import Combine
import CoreGraphics
import Foundation
import IslandCore
import ScreenCaptureKit

/// 桌面活动窗口元数据快照
public struct ManagedWindowInfo: Identifiable, Equatable, Sendable {
    public let windowID: CGWindowID
    public let ownerPID: pid_t
    public let bundleIdentifier: String
    public let appName: String
    public let title: String
    public let quartzBounds: CGRect
    public let appKitFrame: CGRect
    public let layer: Int
    public let isOnScreen: Bool
    public let isMinimized: Bool

    public var id: CGWindowID { windowID }

    public init(
        windowID: CGWindowID,
        ownerPID: pid_t,
        bundleIdentifier: String,
        appName: String,
        title: String,
        quartzBounds: CGRect,
        appKitFrame: CGRect,
        layer: Int = 0,
        isOnScreen: Bool = true,
        isMinimized: Bool = false
    ) {
        self.windowID = windowID
        self.ownerPID = ownerPID
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.title = title
        self.quartzBounds = quartzBounds
        self.appKitFrame = appKitFrame
        self.layer = layer
        self.isOnScreen = isOnScreen
        self.isMinimized = isMinimized
    }

    public var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? appName : trimmed
    }
}

/// Quartz（左上角原点）与 AppKit（主屏左下角原点）坐标互转及 AXUIElement 窗口操作工具
public enum AXWindowHelper {
    public static func primaryScreenHeight() -> CGFloat {
        if Thread.isMainThread {
            return NSScreen.screens.first?.frame.height ?? 900
        }
        return DispatchQueue.main.sync {
            NSScreen.screens.first?.frame.height ?? 900
        }
    }

    public static func appKitPoint(fromQuartz point: CGPoint, primaryHeight: CGFloat? = nil) -> CGPoint {
        let h = primaryHeight ?? primaryScreenHeight()
        return CGPoint(x: point.x, y: h - point.y)
    }

    public static func quartzPoint(fromAppKit point: CGPoint, primaryHeight: CGFloat? = nil) -> CGPoint {
        let h = primaryHeight ?? primaryScreenHeight()
        return CGPoint(x: point.x, y: h - point.y)
    }

    public static func appKitRect(fromQuartz rect: CGRect, primaryHeight: CGFloat? = nil) -> CGRect {
        let h = primaryHeight ?? primaryScreenHeight()
        return CGRect(
            x: rect.origin.x,
            y: h - rect.origin.y - rect.size.height,
            width: rect.size.width,
            height: rect.size.height
        )
    }

    public static func quartzRect(fromAppKit rect: CGRect, primaryHeight: CGFloat? = nil) -> CGRect {
        let h = primaryHeight ?? primaryScreenHeight()
        return CGRect(
            x: rect.origin.x,
            y: h - rect.maxY,
            width: rect.size.width,
            height: rect.size.height
        )
    }

    public static func focusedWindowElement(for pid: pid_t? = nil) -> AXUIElement? {
        guard AXIsProcessTrusted() else { return nil }
        let resolvedPID: pid_t
        if let pid {
            resolvedPID = pid
        } else if let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier {
            resolvedPID = frontPID
        } else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(resolvedPID)
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &value)
        guard status == .success, let windowRef = value, CFGetTypeID(windowRef) == AXUIElementGetTypeID() else {
            return nil
        }
        return (windowRef as! AXUIElement)
    }

    public static func elementAndParentWindow(atQuartzPoint point: CGPoint) -> (element: AXUIElement, window: AXUIElement, subrole: String?)? {
        guard AXIsProcessTrusted() else { return nil }
        let systemWide = AXUIElementCreateSystemWide()
        var hitRef: CFTypeRef?
        var rawElement: AXUIElement?
        let err = AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &rawElement)
        guard err == .success, let element = rawElement else { return nil }

        var subroleString: String?
        if AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &hitRef) == .success,
           let str = hitRef as? String {
            subroleString = str
        }

        var current: AXUIElement? = element
        for _ in 0..<8 {
            guard let candidate = current else { break }
            var roleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(candidate, kAXRoleAttribute as CFString, &roleRef) == .success,
               let role = roleRef as? String,
               role == (kAXWindowRole as String) {
                return (element, candidate, subroleString)
            }
            var parentRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(candidate, kAXParentAttribute as CFString, &parentRef) == .success,
               let parent = parentRef,
               CFGetTypeID(parent) == AXUIElementGetTypeID() {
                current = (parent as! AXUIElement)
            } else {
                break
            }
        }
        return nil
    }

    public static func readQuartzFrame(of windowElement: AXUIElement) -> CGRect? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(windowElement, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(windowElement, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let posVal = posRef, CFGetTypeID(posVal) == AXValueGetTypeID(),
              let sizeVal = sizeRef, CFGetTypeID(sizeVal) == AXValueGetTypeID() else {
            return nil
        }

        var origin = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(posVal as! AXValue, .cgPoint, &origin),
              AXValueGetValue(sizeVal as! AXValue, .cgSize, &size) else {
            return nil
        }
        return CGRect(origin: origin, size: size)
    }

    @discardableResult
    public static func setAppKitFrame(
        _ appKitFrame: CGRect,
        for windowElement: AXUIElement,
        primaryHeight: CGFloat? = nil
    ) -> Bool {
        guard AXIsProcessTrusted() else { return false }
        let quartz = quartzRect(fromAppKit: appKitFrame, primaryHeight: primaryHeight)
        var targetOrigin = quartz.origin
        var targetSize = quartz.size

        guard let posAX = AXValueCreate(.cgPoint, &targetOrigin),
              let sizeAX = AXValueCreate(.cgSize, &targetSize) else {
            return false
        }

        // 先设尺寸再设位置再校正尺寸，兼容跨显示器缩放与窗口最小尺寸约束
        _ = AXUIElementSetAttributeValue(windowElement, kAXSizeAttribute as CFString, sizeAX)
        let posErr = AXUIElementSetAttributeValue(windowElement, kAXPositionAttribute as CFString, posAX)
        let sizeErr = AXUIElementSetAttributeValue(windowElement, kAXSizeAttribute as CFString, sizeAX)
        return posErr == .success || sizeErr == .success
    }

    public static func axWindows(for pid: pid_t) -> [AXUIElement] {
        guard AXIsProcessTrusted() else { return [] }
        let appElement = AXUIElementCreateApplication(pid)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let array = windowsRef as? [AXUIElement] else {
            return []
        }
        return array
    }

    public static func matchAXWindow(for info: ManagedWindowInfo) -> AXUIElement? {
        let candidates = axWindows(for: info.ownerPID)
        guard !candidates.isEmpty else { return nil }

        // 优先匹配标题 + 几何接近的窗口
        for element in candidates {
            var titleRef: CFTypeRef?
            let axTitle = (AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef) == .success)
                ? (titleRef as? String ?? "")
                : ""
            if let frame = readQuartzFrame(of: element) {
                let dx = abs(frame.origin.x - info.quartzBounds.origin.x)
                let dy = abs(frame.origin.y - info.quartzBounds.origin.y)
                if dx < 24 && dy < 24 && (info.title.isEmpty || axTitle == info.title) {
                    return element
                }
            }
            if !info.title.isEmpty && axTitle == info.title {
                return element
            }
        }
        return candidates.first
    }
}

/// 全局活动窗口缓存与 ScreenCaptureKit 实时缩略图注册表
@MainActor
public final class WindowRegistry: ObservableObject {
    public static let shared = WindowRegistry()

    @Published public private(set) var windows: [ManagedWindowInfo] = []
    @Published public private(set) var thumbnails: [CGWindowID: NSImage] = [:]

    private let ignoredBundleIDs: Set<String> = [
        StarIslandHelperConstants.appBundleIdentifier,
        "com.apple.dock",
        "com.apple.WindowManager",
        "com.apple.controlcenter",
        "com.apple.notificationcenterui",
        "com.apple.loginwindow",
        "com.apple.Spotlight"
    ]

    public init() {}

    /// 扫描当前桌面标准应用窗口（融合 CGWindowList 与 AX 最小化窗口补充）
    @discardableResult
    public func refreshWindows(includeMinimized: Bool = true) -> [ManagedWindowInfo] {
        let primaryHeight = AXWindowHelper.primaryScreenHeight()
        let runningAppsByPID: [pid_t: NSRunningApplication] = Dictionary(
            uniqueKeysWithValues: NSWorkspace.shared.runningApplications.map { ($0.processIdentifier, $0) }
        )

        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        let rawList = (CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]]) ?? []

        var collected: [ManagedWindowInfo] = []
        var seenWindowIDs = Set<CGWindowID>()

        for entry in rawList {
            guard let layer = entry[kCGWindowLayer as String] as? Int, layer == 0,
                  let pidInt = entry[kCGWindowOwnerPID as String] as? Int32,
                  let windowNumber = entry[kCGWindowNumber as String] as? UInt32,
                  let boundsDict = entry[kCGWindowBounds as String] as? NSDictionary,
                  let quartzBounds = CGRect(dictionaryRepresentation: boundsDict) else {
                continue
            }

            guard quartzBounds.width >= 100, quartzBounds.height >= 70 else { continue }
            let alpha = (entry[kCGWindowAlpha as String] as? Double) ?? 1.0
            guard alpha > 0.05 else { continue }

            let app = runningAppsByPID[pidInt]
            if let policy = app?.activationPolicy, policy != .regular {
                continue
            }

            let bundleID = app?.bundleIdentifier ?? ""
            if ignoredBundleIDs.contains(bundleID) { continue }

            let ownerName = (entry[kCGWindowOwnerName as String] as? String)
                ?? app?.localizedName
                ?? "未知应用"
            let rawTitle = (entry[kCGWindowName as String] as? String) ?? ""
            let windowID = CGWindowID(windowNumber)
            guard seenWindowIDs.insert(windowID).inserted else { continue }

            let appKitFrame = AXWindowHelper.appKitRect(fromQuartz: quartzBounds, primaryHeight: primaryHeight)
            collected.append(
                ManagedWindowInfo(
                    windowID: windowID,
                    ownerPID: pidInt,
                    bundleIdentifier: bundleID,
                    appName: ownerName,
                    title: rawTitle,
                    quartzBounds: quartzBounds,
                    appKitFrame: appKitFrame,
                    layer: layer,
                    isOnScreen: true,
                    isMinimized: false
                )
            )
        }

        if includeMinimized && AXIsProcessTrusted() {
            appendMinimizedAXWindows(
                into: &collected,
                runningApps: Array(runningAppsByPID.values),
                primaryHeight: primaryHeight
            )
        }

        self.windows = collected
        let validIDs = Set(collected.map(\.windowID))
        self.thumbnails = self.thumbnails.filter { validIDs.contains($0.key) }
        return collected
    }

    public func windows(forBundleID bundleID: String) -> [ManagedWindowInfo] {
        windows.filter { $0.bundleIdentifier == bundleID }
    }

    public func windows(forPID pid: pid_t) -> [ManagedWindowInfo] {
        windows.filter { $0.ownerPID == pid }
    }

    public func topWindow(atQuartzPoint point: CGPoint) -> ManagedWindowInfo? {
        if windows.isEmpty {
            refreshWindows(includeMinimized: false)
        }
        return windows.first { info in
            info.isOnScreen && info.quartzBounds.contains(point)
        }
    }

    public func appIcon(for bundleID: String, pid: pid_t) -> NSImage {
        if let app = NSRunningApplication(processIdentifier: pid), let icon = app.icon {
            return icon
        }
        if !bundleID.isEmpty,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSImage(systemSymbolName: "macwindow", accessibilityDescription: "应用窗口") ?? NSImage()
    }

    /// 使用 ScreenCaptureKit SCScreenshotManager 获取指定窗口高清实时缩略图
    public func captureThumbnail(
        for window: ManagedWindowInfo,
        maxPixelSize: CGSize = CGSize(width: 440, height: 280)
    ) async -> NSImage? {
        guard CGPreflightScreenCaptureAccess() else {
            return thumbnails[window.windowID]
        }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            guard let scWindow = content.windows.first(where: { $0.windowID == window.windowID }) else {
                return thumbnails[window.windowID]
            }

            let filter = SCContentFilter(desktopIndependentWindow: scWindow)
            let config = SCStreamConfiguration()
            let srcWidth = max(scWindow.frame.width, 1)
            let srcHeight = max(scWindow.frame.height, 1)
            let scale = min(maxPixelSize.width / srcWidth, maxPixelSize.height / srcHeight, 2.0)
            config.width = max(Int((srcWidth * scale).rounded()), 64)
            config.height = max(Int((srcHeight * scale).rounded()), 48)
            config.showsCursor = false
            config.scalesToFit = true

            let cgImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
            let nsImage = NSImage(
                cgImage: cgImage,
                size: NSSize(width: cgImage.width / 2, height: cgImage.height / 2)
            )
            thumbnails[window.windowID] = nsImage
            return nsImage
        } catch {
            return thumbnails[window.windowID]
        }
    }

    public func refreshThumbnails(for targetWindows: [ManagedWindowInfo]) async {
        for item in targetWindows.prefix(8) {
            _ = await captureThumbnail(for: item)
        }
    }

    /// 激活指定窗口并自动取消最小化置顶
    @discardableResult
    public func activateWindow(_ info: ManagedWindowInfo) -> Bool {
        if let axWin = AXWindowHelper.matchAXWindow(for: info) {
            _ = AXUIElementSetAttributeValue(axWin, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            _ = AXUIElementPerformAction(axWin, kAXRaiseAction as CFString)
            _ = AXUIElementSetAttributeValue(axWin, kAXMainAttribute as CFString, kCFBooleanTrue)
        }
        if let app = NSRunningApplication(processIdentifier: info.ownerPID) {
            app.unhide()
            return app.activate()
        }
        return false
    }

    /// 通过辅助功能触发指定窗口的原生关闭按钮
    @discardableResult
    public func closeWindow(_ info: ManagedWindowInfo) -> Bool {
        guard let axWin = AXWindowHelper.matchAXWindow(for: info) else { return false }
        var closeButtonRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axWin, kAXCloseButtonAttribute as CFString, &closeButtonRef) == .success,
              let closeButton = closeButtonRef,
              CFGetTypeID(closeButton) == AXUIElementGetTypeID() else {
            return false
        }
        let result = AXUIElementPerformAction(closeButton as! AXUIElement, kAXPressAction as CFString) == .success
        if result {
            windows.removeAll { $0.windowID == info.windowID }
            thumbnails.removeValue(forKey: info.windowID)
        }
        return result
    }

    /// 一键隐藏或最小化当前已处于前台的指定应用（用于点击当前激活 Dock 图标最小化）
    @discardableResult
    public func minimizeOrHideApp(bundleID: String) -> Bool {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
            return false
        }
        if AXIsProcessTrusted() {
            let axWins = AXWindowHelper.axWindows(for: app.processIdentifier)
            if !axWins.isEmpty {
                var minimizedAny = false
                for win in axWins {
                    if AXUIElementSetAttributeValue(win, kAXMinimizedAttribute as CFString, kCFBooleanTrue) == .success {
                        minimizedAny = true
                    }
                }
                if minimizedAny { return true }
            }
        }
        return app.hide()
    }

    private func appendMinimizedAXWindows(
        into list: inout [ManagedWindowInfo],
        runningApps: [NSRunningApplication],
        primaryHeight: CGFloat
    ) {
        for app in runningApps where app.activationPolicy == .regular {
            let bundleID = app.bundleIdentifier ?? ""
            if ignoredBundleIDs.contains(bundleID) { continue }
            let axWins = AXWindowHelper.axWindows(for: app.processIdentifier)
            for (idx, axWin) in axWins.enumerated() {
                var minRef: CFTypeRef?
                let isMin = (AXUIElementCopyAttributeValue(axWin, kAXMinimizedAttribute as CFString, &minRef) == .success)
                    && ((minRef as? Bool) == true)
                guard isMin else { continue }

                var titleRef: CFTypeRef?
                let title = (AXUIElementCopyAttributeValue(axWin, kAXTitleAttribute as CFString, &titleRef) == .success)
                    ? (titleRef as? String ?? "")
                    : ""
                let quartz = AXWindowHelper.readQuartzFrame(of: axWin) ?? CGRect(x: 0, y: 0, width: 800, height: 600)
                let syntheticID = CGWindowID(UInt32(bitPattern: app.processIdentifier) &* 1000 &+ UInt32(idx + 1))
                guard !list.contains(where: { $0.windowID == syntheticID }) else { continue }

                list.append(
                    ManagedWindowInfo(
                        windowID: syntheticID,
                        ownerPID: app.processIdentifier,
                        bundleIdentifier: bundleID,
                        appName: app.localizedName ?? "应用",
                        title: title,
                        quartzBounds: quartz,
                        appKitFrame: AXWindowHelper.appKitRect(fromQuartz: quartz, primaryHeight: primaryHeight),
                        layer: 0,
                        isOnScreen: false,
                        isMinimized: true
                    )
                )
            }
        }
    }
}
