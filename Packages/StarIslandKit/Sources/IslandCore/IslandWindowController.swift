import AppKit
import Combine
import SwiftUI

public final class IslandPanel: NSPanel {
    public var allowsKeyFocus: Bool = false

    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 3)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        acceptsMouseMovedEvents = true
        isMovable = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
    }

    public override var canBecomeKey: Bool {
        allowsKeyFocus
    }

    public override var canBecomeMain: Bool {
        false
    }
}

@MainActor
public final class IslandWindowController {
    private var panelsByDisplayID: [CGDirectDisplayID: IslandPanel] = [:]
    private let stateMachine: IslandStateMachine
    private let settingsStore: SettingsStore
    private let rootViewBuilder: @MainActor () -> AnyView
    private var cancellables = Set<AnyCancellable>()

    public init(
        stateMachine: IslandStateMachine? = nil,
        settingsStore: SettingsStore? = nil,
        rootViewBuilder: @escaping @MainActor () -> AnyView
    ) {
        self.stateMachine = stateMachine ?? .shared
        self.settingsStore = settingsStore ?? .shared
        self.rootViewBuilder = rootViewBuilder
    }

    public func start() {
        rebuildPanels()

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.rebuildPanels()
            }
            .store(in: &cancellables)

        stateMachine.$displayState
            .combineLatest(stateMachine.$selectedTab, settingsStore.$settings)
            .receive(on: RunLoop.main)
            .sink { [weak self] state, tab, _ in
                guard let self else { return }
                let wantsKeyboard = (state == .expanded && (tab == .ai || tab == .shelf || tab == .widgets))
                self.updatePanelFrames(animated: true, allowsKeyboard: wantsKeyboard)
            }
            .store(in: &cancellables)
    }

    public func stop() {
        for panel in panelsByDisplayID.values {
            panel.orderOut(nil)
            panel.close()
        }
        panelsByDisplayID.removeAll()
        cancellables.removeAll()
    }

    public func rebuildPanels() {
        let screens = targetScreens()
        var activeIDs = Set<CGDirectDisplayID>()

        for screen in screens {
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                continue
            }
            activeIDs.insert(id)
            let metrics = IslandGeometry.resolve(for: screen, scale: settingsStore.settings.islandScale)
            let initialFrame = metrics.panelFrame(for: stateMachine.displayState)

            if let existing = panelsByDisplayID[id] {
                existing.setFrame(initialFrame, display: true)
                existing.orderFrontRegardless()
            } else {
                let panel = IslandPanel(contentRect: initialFrame)
                let hosting = NSHostingView(rootView: rootViewBuilder())
                hosting.frame = NSRect(origin: .zero, size: initialFrame.size)
                hosting.autoresizingMask = [.width, .height]
                panel.contentView = hosting
                panel.orderFrontRegardless()
                panelsByDisplayID[id] = panel
            }
        }

        let staleIDs = Set(panelsByDisplayID.keys).subtracting(activeIDs)
        for stale in staleIDs {
            panelsByDisplayID[stale]?.orderOut(nil)
            panelsByDisplayID[stale]?.close()
            panelsByDisplayID.removeValue(forKey: stale)
        }
    }

    private func updatePanelFrames(animated: Bool, allowsKeyboard: Bool) {
        for screen in targetScreens() {
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
                  let panel = panelsByDisplayID[id] else {
                continue
            }
            panel.allowsKeyFocus = allowsKeyboard
            let metrics = IslandGeometry.resolve(for: screen, scale: settingsStore.settings.islandScale)
            let frame = metrics.panelFrame(for: stateMachine.displayState)
            if animated {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.28
                    context.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1.0, 0.36, 1.0)
                    panel.animator().setFrame(frame, display: true)
                }
            } else {
                panel.setFrame(frame, display: true)
            }
        }
    }

    private func targetScreens() -> [NSScreen] {
        if settingsStore.settings.showOnExternalDisplays {
            return NSScreen.screens
        }
        if let main = NSScreen.screens.first {
            return [main]
        }
        return []
    }
}
