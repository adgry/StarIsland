import Combine
import Foundation

public enum IslandDisplayState: String, Equatable, Sendable {
    case compact
    case pill
    case peek
    case expanded
    case alertHUD
}

public enum IslandTab: String, CaseIterable, Identifiable, Codable, Sendable {
    case nowPlaying
    case shelf
    case widgets
    case ai
    case connect

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .nowPlaying: return "正在播放"
        case .shelf: return "暂存与效率"
        case .widgets: return "全景看板"
        case .ai: return "星岛 AI"
        case .connect: return "手机互联"
        }
    }

    public var iconSymbol: String {
        switch self {
        case .nowPlaying: return "Waveform" == "" ? "music.note" : "music.quarternote.3"
        case .shelf: return "tray.and.arrow.down.fill"
        case .widgets: return "square.grid.2x2.fill"
        case .ai: return "sparkles"
        case .connect: return "qrcode.viewfinder"
        }
    }
}

public enum ActivityPriority: Int, Comparable, Codable, Sendable {
    case ambient = 20
    case ongoing = 40
    case interactive = 60
    case urgent = 80
    case critical = 100

    public static func < (lhs: ActivityPriority, rhs: ActivityPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum ActivityCategory: String, Codable, Equatable, Sendable {
    case media
    case systemHUD
    case otp
    case clipboard
    case shelf
    case timer
    case sports
    case finance
    case weather
    case terminal
    case battery
    case appLock
    case focus
    case ai
    case continuity
}

public struct IslandActivityItem: Identifiable, Equatable, Sendable {
    public let id: String
    public var category: ActivityCategory
    public var title: String
    public var subtitle: String
    public var iconSymbol: String
    public var trailingBadge: String?
    public var progress: Double?
    public var priority: ActivityPriority
    public var isAlertHUD: Bool
    public var isPeek: Bool
    public var allowsOnLockScreen: Bool
    public var autoDismissAfter: TimeInterval?
    public var actionTitle: String?
    public var actionPayload: String?
    public var updatedAt: Date

    public init(
        id: String,
        category: ActivityCategory,
        title: String,
        subtitle: String = "",
        iconSymbol: String,
        trailingBadge: String? = nil,
        progress: Double? = nil,
        priority: ActivityPriority,
        isAlertHUD: Bool = false,
        isPeek: Bool = false,
        allowsOnLockScreen: Bool = false,
        autoDismissAfter: TimeInterval? = nil,
        actionTitle: String? = nil,
        actionPayload: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.subtitle = subtitle
        self.iconSymbol = iconSymbol
        self.trailingBadge = trailingBadge
        self.progress = progress
        self.priority = priority
        self.isAlertHUD = isAlertHUD
        self.isPeek = isPeek
        self.allowsOnLockScreen = allowsOnLockScreen
        self.autoDismissAfter = autoDismissAfter
        self.actionTitle = actionTitle
        self.actionPayload = actionPayload
        self.updatedAt = updatedAt
    }
}

@MainActor
public final class IslandStateMachine: ObservableObject {
    public static let shared = IslandStateMachine()

    @Published public private(set) var displayState: IslandDisplayState = .compact
    @Published public var selectedTab: IslandTab = .nowPlaying
    @Published public private(set) var isHovering: Bool = false
    @Published public private(set) var isPinnedExpanded: Bool = false
    @Published public private(set) var isDraggingFilesNearTop: Bool = false
    @Published public private(set) var isScreenLocked: Bool = false
    @Published public private(set) var activities: [IslandActivityItem] = []

    private var dismissTasks: [String: Task<Void, Never>] = [:]
    private var lockObservers: [NSObjectProtocol] = []

    public init(observeSystemLockNotifications: Bool = false) {
        if observeSystemLockNotifications {
            installScreenLockObservers()
        }
    }

    public var visibleActivities: [IslandActivityItem] {
        let filtered = isScreenLocked ? activities.filter(\.allowsOnLockScreen) : activities
        return filtered.sorted { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority > rhs.priority
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    public var primaryActivity: IslandActivityItem? {
        visibleActivities.first
    }

    public var secondaryActivity: IslandActivityItem? {
        visibleActivities.dropFirst().first
    }

    public func submit(_ item: IslandActivityItem) {
        dismissTasks[item.id]?.cancel()
        dismissTasks[item.id] = nil

        if let index = activities.firstIndex(where: { $0.id == item.id }) {
            activities[index] = item
        } else {
            activities.append(item)
        }

        if let ttl = item.autoDismissAfter, ttl > 0 {
            let itemID = item.id
            dismissTasks[itemID] = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(ttl * 1_000_000_000))
                guard !Task.isCancelled else { return }
                self?.dismiss(id: itemID)
            }
        }

        recomputeDisplayState()
    }

    public func dismiss(id: String) {
        dismissTasks[id]?.cancel()
        dismissTasks[id] = nil
        activities.removeAll { $0.id == id }
        recomputeDisplayState()
    }

    public func clearCategory(_ category: ActivityCategory) {
        let ids = activities.filter { $0.category == category }.map(\.id)
        for id in ids {
            dismissTasks[id]?.cancel()
            dismissTasks[id] = nil
        }
        activities.removeAll { $0.category == category }
        recomputeDisplayState()
    }

    public func setHovering(_ hovering: Bool) {
        guard isHovering != hovering else { return }
        isHovering = hovering
        if !hovering {
            isPinnedExpanded = false
        }
        recomputeDisplayState()
    }

    public func togglePinnedExpanded() {
        isPinnedExpanded.toggle()
        recomputeDisplayState()
    }

    public func collapseExpanded() {
        isPinnedExpanded = false
        isHovering = false
        isDraggingFilesNearTop = false
        recomputeDisplayState()
    }

    public func setDraggingFilesNearTop(_ dragging: Bool) {
        guard isDraggingFilesNearTop != dragging else { return }
        isDraggingFilesNearTop = dragging
        if dragging {
            selectedTab = .shelf
        }
        recomputeDisplayState()
    }

    public func setScreenLocked(_ locked: Bool) {
        guard isScreenLocked != locked else { return }
        isScreenLocked = locked
        if locked {
            isHovering = false
            isPinnedExpanded = false
        }
        recomputeDisplayState()
    }

    public func selectTab(_ tab: IslandTab) {
        selectedTab = tab
        isPinnedExpanded = true
        recomputeDisplayState()
    }

    private func recomputeDisplayState() {
        if !isScreenLocked && (isHovering || isPinnedExpanded || isDraggingFilesNearTop) {
            if displayState != .expanded { displayState = .expanded }
            return
        }

        guard let top = primaryActivity else {
            if displayState != .compact { displayState = .compact }
            return
        }

        let nextState: IslandDisplayState
        if top.isAlertHUD {
            nextState = .alertHUD
        } else if top.isPeek {
            nextState = .peek
        } else {
            nextState = .pill
        }

        if displayState != nextState {
            displayState = nextState
        }
    }

    private func installScreenLockObservers() {
        let center = DistributedNotificationCenter.default()
        let lockedObs = center.addObserver(
            forName: Notification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.setScreenLocked(true) }
        }
        let unlockedObs = center.addObserver(
            forName: Notification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.setScreenLocked(false) }
        }
        lockObservers = [lockedObs, unlockedObs]
    }
}
