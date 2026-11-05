import AIConnectKit
import AppKit
import IslandCore
import LiveWidgetsKit
import MediaAudioKit
import ProductivityKit
import SwiftUI
import UniformTypeIdentifiers

public struct StarIslandRootView: View {
    @ObservedObject private var stateMachine: IslandStateMachine
    @ObservedObject private var settingsStore: SettingsStore
    @State private var hoverWorkItem: DispatchWorkItem?
    @State private var isDropTargeted: Bool = false

    private let onOpenSettings: () -> Void

    @MainActor
    public init(
        stateMachine: IslandStateMachine? = nil,
        settingsStore: SettingsStore? = nil,
        onOpenSettings: @escaping () -> Void
    ) {
        self._stateMachine = ObservedObject(wrappedValue: stateMachine ?? .shared)
        self._settingsStore = ObservedObject(wrappedValue: settingsStore ?? .shared)
        self.onOpenSettings = onOpenSettings
    }

    public var body: some View {
        ZStack(alignment: .top) {
            islandContainer
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onHover { hovering in
            handleHoverChange(hovering)
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDroppedProviders(providers)
        }
        .onChange(of: isDropTargeted) { _, targeted in
            stateMachine.setDraggingFilesNearTop(targeted)
        }
    }

    @ViewBuilder
    private var islandContainer: some View {
        let state = stateMachine.displayState
        let cornerRadius: CGFloat = (state == .compact || state == .pill) ? 20 : 26

        ZStack(alignment: .top) {
            UnevenRoundedRectangle(
                topLeadingRadius: 10,
                bottomLeadingRadius: cornerRadius,
                bottomTrailingRadius: cornerRadius,
                topTrailingRadius: 10,
                style: .continuous
            )
            .fill(Color.black)
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 10,
                    bottomLeadingRadius: cornerRadius,
                    bottomTrailingRadius: cornerRadius,
                    topTrailingRadius: 10,
                    style: .continuous
                )
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(state == .compact ? 0.08 : 0.18),
                            Color.cyan.opacity(isDropTargeted ? 0.75 : 0.16),
                            Color.white.opacity(0.06),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isDropTargeted ? 1.6 : 0.9
                )
            )
            .shadow(color: .black.opacity(state == .compact ? 0.28 : 0.55), radius: state == .compact ? 6 : 18, y: 6)

            Group {
                switch state {
                case .compact:
                    compactView
                case .pill:
                    pillView
                case .peek:
                    peekView
                case .alertHUD:
                    alertHUDView
                case .expanded:
                    expandedView
                }
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: stateMachine.displayState)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: stateMachine.selectedTab)
    }

    private var compactView: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.cyan.opacity(0.88))
            Spacer(minLength: 0)
            Circle()
                .fill(Color.cyan.opacity(0.55))
                .frame(width: 5, height: 5)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            stateMachine.togglePinnedExpanded()
        }
    }

    private var pillView: some View {
        let primary = stateMachine.primaryActivity
        let secondary = stateMachine.secondaryActivity

        return HStack(spacing: 10) {
            if let primary {
                HStack(spacing: 6) {
                    Image(systemName: primary.iconSymbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.cyan)
                    Text(primary.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 16)
            if let badge = primary?.trailingBadge, !badge.isEmpty {
                Text(badge)
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.cyan.opacity(0.16), in: Capsule())
            } else if let secondary {
                HStack(spacing: 4) {
                    Image(systemName: secondary.iconSymbol)
                        .font(.system(size: 11))
                        .foregroundStyle(.purple)
                    Text(secondary.trailingBadge ?? secondary.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(1)
                }
            } else {
                Image(systemName: "waveform")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.cyan)
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            stateMachine.togglePinnedExpanded()
        }
    }

    private var peekView: some View {
        let item = stateMachine.primaryActivity
        return VStack(spacing: 8) {
            Spacer(minLength: 24)
            if let item {
                HStack(spacing: 12) {
                    Image(systemName: item.iconSymbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.cyan)
                        .frame(width: 36, height: 36)
                        .background(Color.cyan.opacity(0.16), in: RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        if !item.subtitle.isEmpty {
                            Text(item.subtitle)
                                .font(.system(size: 11.5))
                                .foregroundStyle(.white.opacity(0.70))
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    if let actionTitle = item.actionTitle {
                        Button(actionTitle) {
                            handleActivityAction(item)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.cyan)
                        .controlSize(.small)
                    } else if let badge = item.trailingBadge {
                        Text(badge)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.cyan)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            stateMachine.togglePinnedExpanded()
        }
    }

    private var alertHUDView: some View {
        let item = stateMachine.primaryActivity
        return VStack(spacing: 8) {
            Spacer(minLength: 22)
            if let item {
                HStack(spacing: 12) {
                    Image(systemName: item.iconSymbol)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(item.category == .otp ? .green : .cyan)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.title)
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(.white)
                            Spacer()
                            if let badge = item.trailingBadge {
                                Text(badge)
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.cyan)
                            }
                        }

                        if let progress = item.progress {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.14))
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [.cyan, .blue],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: max(4, geo.size.width * CGFloat(min(1.0, max(0.0, progress)))))
                                }
                            }
                            .frame(height: 6)
                        } else if !item.subtitle.isEmpty {
                            Text(item.subtitle)
                                .font(.system(size: 11.5))
                                .foregroundStyle(.white.opacity(0.72))
                                .lineLimit(1)
                        }
                    }

                    if let actionTitle = item.actionTitle {
                        Button(actionTitle) {
                            handleActivityAction(item)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .controlSize(.small)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var expandedView: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 26)

            // Top tab bar + utility buttons
            HStack(spacing: 6) {
                ForEach(IslandTab.allCases) { tab in
                    let isSelected = (stateMachine.selectedTab == tab)
                    Button {
                        stateMachine.selectTab(tab)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: tab.iconSymbol)
                                .font(.system(size: 11.5, weight: .semibold))
                            Text(tab.title)
                                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                        }
                        .foregroundStyle(isSelected ? Color.black : Color.white.opacity(0.78))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.cyan : Color.white.opacity(0.08))
                        )
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 4)

                Button {
                    CircleToSearchController.shared.beginSelection(
                        aiService: ServiceRegistry.shared.aiService,
                        mode: .ocrOnly
                    )
                } label: {
                    Image(systemName: "text.viewfinder")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .help("离线框选 OCR 识别文字 (⇧⌘2)")

                Button {
                    stateMachine.togglePinnedExpanded()
                } label: {
                    Image(systemName: stateMachine.isPinnedExpanded ? "pin.fill" : "pin")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(stateMachine.isPinnedExpanded ? .cyan : .white.opacity(0.75))
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .help(stateMachine.isPinnedExpanded ? "取消固定展开" : "固定展开面板")

                Button {
                    onOpenSettings()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .help("打开星岛设置中心")
            }
            .padding(.horizontal, 14)

            Divider()
                .overlay(Color.white.opacity(0.09))
                .padding(.horizontal, 14)

            // Active Tab Body
            Group {
                switch stateMachine.selectedTab {
                case .nowPlaying:
                    NowPlayingIslandTabView()
                case .shelf:
                    ShelfIslandTabView()
                case .widgets:
                    WidgetsIslandTabView()
                case .ai:
                    AIIslandTabView()
                case .connect:
                    ConnectIslandTabView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
        .preferredColorScheme(.dark)
    }

    private func handleHoverChange(_ hovering: Bool) {
        hoverWorkItem?.cancel()
        hoverWorkItem = nil

        if hovering {
            let delay = max(0.05, Double(settingsStore.settings.hoverExpandDelayMs) / 1000.0)
            let work = DispatchWorkItem {
                Task { @MainActor in
                    stateMachine.setHovering(true)
                }
            }
            hoverWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        } else {
            let work = DispatchWorkItem {
                Task { @MainActor in
                    if !stateMachine.isPinnedExpanded {
                        stateMachine.setHovering(false)
                    }
                }
            }
            hoverWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: work)
        }
    }

    private func handleActivityAction(_ item: IslandActivityItem) {
        if item.category == .otp, let code = item.actionPayload, !code.isEmpty {
            SmartInboxCoordinator.shared.copyOTPAndCollapse(code, activityID: item.id)
            return
        }
        if let payload = item.actionPayload, let url = URL(string: payload), url.scheme != nil {
            NSWorkspace.shared.open(url)
        }
        stateMachine.dismiss(id: item.id)
    }

    private func handleDroppedProviders(_ providers: [NSItemProvider]) -> Bool {
        var accepted = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            accepted = true
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                let resolvedURL: URL?
                if let urlData = data as? Data {
                    resolvedURL = URL(dataRepresentation: urlData, relativeTo: nil)
                } else if let url = data as? URL {
                    resolvedURL = url
                } else {
                    resolvedURL = nil
                }
                guard let fileURL = resolvedURL else { return }
                Task { @MainActor in
                    _ = DropzoneShelfManager.shared.addFiles([fileURL])
                    stateMachine.selectTab(.shelf)
                }
            }
        }
        return accepted
    }
}
