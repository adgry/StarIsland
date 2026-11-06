//
//  AppProtectionCore.swift
//  Sapphire
//

#if !SAPPHIRE_FULL_BUILD
import AppKit
import SwiftUI

@MainActor
final class AppBlocker {
    var isBlocked: (String) -> Bool = { _ in false }
    var makeShieldContent: (String, String) -> AnyView = { _, _ in AnyView(EmptyView()) }
    var shieldsAreKeyable = false
    var forceClosesOnActivation = false
    var shieldsOnlyWhenFrontmost = false
    var keepsShieldWhenNotFrontmost: (String) -> Bool = { _ in false }
    var onAppActivated: ((_ appName: String, _ bundleID: String, _ app: NSRunningApplication) -> Void)?
    private(set) var isBlocking = false

    private var workspaceObservers: [NSObjectProtocol] = []
    private var shieldPanelsByBundleID: [String: [NSPanel]] = [:]

    func setBlocking(_ enabled: Bool) {
        guard isBlocking != enabled else {
            if enabled { refresh() }
            return
        }
        isBlocking = enabled
        if enabled {
            installObserversIfNeeded()
            refresh()
        } else {
            removeObservers()
            removeAllShields()
        }
    }

    func refresh() {
        guard isBlocking else {
            removeAllShields()
            return
        }
        for bid in Array(shieldPanelsByBundleID.keys) where !isBlocked(bid) {
            unshield(bundleID: bid)
        }
        if let front = NSWorkspace.shared.frontmostApplication,
           let bid = front.bundleIdentifier,
           bid != Bundle.main.bundleIdentifier,
           isBlocked(bid) {
            if forceClosesOnActivation {
                AppShieldManager.forceClose(front)
            } else {
                shield(bundleID: bid)
            }
        }
    }

    func shield(bundleID: String) {
        guard isBlocking, !bundleID.isEmpty, bundleID != Bundle.main.bundleIdentifier else { return }
        if isShielded(bundleID) { return }
        let appName = AppShieldManager.displayName(for: bundleID)
        var panels: [NSPanel] = []
        for screen in NSScreen.screens {
            let mask: NSWindow.StyleMask = shieldsAreKeyable ? [.borderless] : [.borderless, .nonactivatingPanel]
            let panel = KeyableShieldPanel(contentRect: screen.frame, styleMask: mask, backing: .buffered, defer: false)
            panel.allowsKey = shieldsAreKeyable
            panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 2)
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            let content = ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Color.black.opacity(0.45)
                makeShieldContent(appName, bundleID)
            }
            .ignoresSafeArea()
            panel.contentView = NSHostingView(rootView: content)
            if shieldsAreKeyable {
                panel.makeKeyAndOrderFront(nil)
            } else {
                panel.orderFrontRegardless()
            }
            panels.append(panel)
        }
        shieldPanelsByBundleID[bundleID] = panels
    }

    func isShielded(_ bundleID: String) -> Bool {
        guard let panels = shieldPanelsByBundleID[bundleID] else { return false }
        return !panels.isEmpty
    }

    func unshield(bundleID: String) {
        guard let panels = shieldPanelsByBundleID.removeValue(forKey: bundleID) else { return }
        for panel in panels { panel.orderOut(nil) }
    }

    func removeAllShields() {
        for (_, panels) in shieldPanelsByBundleID {
            for panel in panels { panel.orderOut(nil) }
        }
        shieldPanelsByBundleID.removeAll()
    }

    private func installObserversIfNeeded() {
        guard workspaceObservers.isEmpty else { return }
        let nc = NSWorkspace.shared.notificationCenter
        let act = nc.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            Task { @MainActor [weak self] in
                guard let self, self.isBlocking, let app, let bid = app.bundleIdentifier, bid != Bundle.main.bundleIdentifier else { return }
                let name = AppShieldManager.displayName(for: bid)
                self.onAppActivated?(name, bid, app)
                if self.shieldsOnlyWhenFrontmost {
                    for existing in Array(self.shieldPanelsByBundleID.keys) where existing != bid && !self.keepsShieldWhenNotFrontmost(existing) {
                        self.unshield(bundleID: existing)
                    }
                }
                if self.isBlocked(bid) {
                    if self.forceClosesOnActivation {
                        AppShieldManager.forceClose(app)
                    } else {
                        self.shield(bundleID: bid)
                    }
                }
            }
        }
        workspaceObservers = [act]
    }

    private func removeObservers() {
        let nc = NSWorkspace.shared.notificationCenter
        for obs in workspaceObservers { nc.removeObserver(obs) }
        workspaceObservers.removeAll()
    }
}

private final class KeyableShieldPanel: NSPanel {
    var allowsKey = false
    override var canBecomeKey: Bool { allowsKey }
    override var canBecomeMain: Bool { false }
}

@MainActor
enum AppShieldManager {
    static func displayName(for bundleID: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let name = FileManager.default.displayName(atPath: url.path)
            if name.lowercased().hasSuffix(".app") {
                return String(name.dropLast(4))
            }
            return name
        }
        return bundleID
    }

    @discardableResult
    static func forceClose(
        _ app: NSRunningApplication,
        guard isValid: @autoclosure @escaping () -> Bool = true,
        immediate: Bool = false
    ) -> Bool {
        guard isValid() else { return false }
        if immediate { return app.forceTerminate() }
        return app.terminate()
    }
}

enum AppShieldMode {
    case focus(
        intensity: FocusIntensity,
        onUnblockNow: () -> Void,
        onSnooze: (Int) -> Void,
        onRequestUnblock: () -> Void,
        remainingUnblockTime: () -> TimeInterval?,
        onHide: () -> Void
    )
}

struct AppShieldView: View {
    let appName: String
    let mode: AppShieldMode

    var body: some View {
        switch mode {
        case let .focus(_, onUnblockNow, onSnooze, _, _, onHide):
            VStack(spacing: 16) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(.purple)
                Text("专注模式已拦截「\(appName)」")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text("当前处于专注时段，建议保持心流或稍后再查看。")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    Button("隐藏应用", action: onHide)
                        .buttonStyle(.borderedProminent)
                    Button("小憩 5 分钟") { onSnooze(5) }
                        .buttonStyle(.bordered)
                    Button("暂时放行", action: onUnblockNow)
                        .buttonStyle(.bordered)
                }
            }
            .padding(32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }
}
#endif
