import AppKit
import Combine
import Foundation
import IslandCore

public enum HostsBlocklistRenderer {
    public static let beginMarker = "# BEGIN STARISLAND FOCUS"
    public static let endMarker = "# END STARISLAND FOCUS"

    public static func normalizeDomains(_ domains: [String]) -> [String] {
        var collected = Set<String>()
        let allowedChars = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789.-")

        for raw in domains {
            var token = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !token.isEmpty else { continue }

            if token.contains("://"), let url = URL(string: token), let host = url.host?.lowercased() {
                token = host
            } else {
                if token.hasPrefix("https://") { token.removeFirst("https://".count) }
                if token.hasPrefix("http://") { token.removeFirst("http://".count) }
                if let slashIdx = token.firstIndex(where: { $0 == "/" || $0 == "?" || $0 == ":" || $0 == "#" }) {
                    token = String(token[..<slashIdx])
                }
            }

            token = token.trimmingCharacters(in: CharacterSet(charactersIn: "."))
            guard token.contains("."),
                  token != "localhost",
                  token.unicodeScalars.allSatisfy({ allowedChars.contains($0) }) else {
                continue
            }

            collected.insert(token)
            if token.hasPrefix("www.") {
                let bare = String(token.dropFirst(4))
                if bare.contains(".") {
                    collected.insert(bare)
                }
            } else if token.filter({ $0 == "." }).count == 1 {
                collected.insert("www.\(token)")
            }
        }

        return collected.sorted()
    }

    public static func applyBlockDomains(_ domains: [String], to hostsContent: String) -> String {
        let base = removeManagedBlock(from: hostsContent)
        let normalized = normalizeDomains(domains)
        guard !normalized.isEmpty else { return base }

        var blockLines: [String] = [
            beginMarker,
            "# 由星岛 (StarIsland) 专注模式自动维护，请勿手动修改此区块"
        ]
        for domain in normalized {
            blockLines.append("127.0.0.1 \(domain)")
            blockLines.append("::1 \(domain)")
        }
        blockLines.append(endMarker)
        let block = blockLines.joined(separator: "\n")

        if base.isEmpty {
            return block
        } else if base.hasSuffix("\n") {
            return base + "\n" + block + "\n"
        } else {
            return base + "\n" + block
        }
    }

    public static func removeManagedBlock(from hostsContent: String) -> String {
        var current = hostsContent
        while let beginRange = current.range(of: beginMarker),
              let endRange = current.range(of: endMarker, range: beginRange.upperBound..<current.endIndex) {
            var removeStart = beginRange.lowerBound
            var removeEnd = endRange.upperBound

            let hadLeadingNewline: Bool
            if removeStart > current.startIndex, current[current.index(before: removeStart)] == "\n" {
                removeStart = current.index(before: removeStart)
                hadLeadingNewline = true
            } else {
                hadLeadingNewline = false
            }

            if removeEnd < current.endIndex, current[removeEnd] == "\n" {
                if hadLeadingNewline || removeStart == current.startIndex {
                    removeEnd = current.index(after: removeEnd)
                }
            }

            current.removeSubrange(removeStart..<removeEnd)
        }
        return current
    }
}

public struct PresetDistractionItem: Identifiable, Equatable, Sendable {
    public var id: String { value }
    public let title: String
    public let value: String

    public init(title: String, value: String) {
        self.title = title
        self.value = value
    }
}

@MainActor
public final class FocusBlockerService: ObservableObject {
    public static let shared = FocusBlockerService()

    public static let presetDomains: [PresetDistractionItem] = [
        .init(title: "微博", value: "weibo.com"),
        .init(title: "哔哩哔哩", value: "bilibili.com"),
        .init(title: "抖音网页版", value: "douyin.com"),
        .init(title: "小红书", value: "xiaohongshu.com"),
        .init(title: "知乎", value: "zhihu.com"),
        .init(title: "YouTube", value: "youtube.com"),
        .init(title: "X / Twitter", value: "x.com")
    ]

    public static let presetApps: [PresetDistractionItem] = [
        .init(title: "微信", value: "com.tencent.xinWeChat"),
        .init(title: "QQ", value: "com.tencent.qq"),
        .init(title: "Steam 游戏平台", value: "com.valvesoftware.steam"),
        .init(title: "网易云音乐", value: "com.netease.163music"),
        .init(title: "Discord", value: "com.hnc.Discord")
    ]

    @Published public private(set) var isFocusing: Bool = false
    @Published public private(set) var totalSeconds: TimeInterval = 0
    @Published public private(set) var remainingSeconds: TimeInterval = 0
    @Published public private(set) var interceptedCount: Int = 0
    @Published public private(set) var lastInterceptedAppName: String?
    @Published public private(set) var helperSyncMessage: String?

    private let settingsStore: SettingsStore
    private let stateMachine: IslandStateMachine
    private let mutationJournal: MutationJournal
    private let helperOverride: PrivilegedHelperProtocol?
    private var countdownTask: Task<Void, Never>?
    private var workspaceObservers: [NSObjectProtocol] = []

    public init(
        settingsStore: SettingsStore? = nil,
        stateMachine: IslandStateMachine? = nil,
        mutationJournal: MutationJournal? = nil,
        helperOverride: PrivilegedHelperProtocol? = nil
    ) {
        self.settingsStore = settingsStore ?? .shared
        self.stateMachine = stateMachine ?? .shared
        self.mutationJournal = mutationJournal ?? .shared
        self.helperOverride = helperOverride
    }

    public var formattedRemaining: String {
        CountdownTimerItem.formatClock(remainingSeconds)
    }

    public var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return min(1.0, max(0.0, 1.0 - (remainingSeconds / totalSeconds)))
    }

    private var resolvedHelper: PrivilegedHelperProtocol? {
        helperOverride ?? ServiceRegistry.shared.helperService
    }

    public func recoverPendingMutationsIfNeeded() async {
        let pending = mutationJournal.pendingRecords().filter { $0.kind == .focusHostsBlock }
        guard !pending.isEmpty else { return }
        if let helper = resolvedHelper {
            let ok = await helper.applyManagedBlockedDomains([])
            if ok {
                mutationJournal.clear(.focusHostsBlock)
                helperSyncMessage = "已自动恢复上次未正常退出的专注网站屏蔽规则"
            }
        }
    }

    public func startFocus(minutes: Int = 25) async {
        let duration = TimeInterval(max(1, minutes) * 60)
        totalSeconds = duration
        remainingSeconds = duration
        interceptedCount = 0
        lastInterceptedAppName = nil
        isFocusing = true

        installAppInterceptors()
        await applyHostsBlockIfConfigured()
        syncFocusActivityToIsland()
        startCountdownLoop()
    }

    public func stopFocus() async {
        countdownTask?.cancel()
        countdownTask = nil
        removeAppInterceptors()
        isFocusing = false
        remainingSeconds = 0
        stateMachine.clearCategory(.focus)

        let hasPendingHosts = mutationJournal.pendingRecords().contains { $0.kind == .focusHostsBlock }
        if hasPendingHosts || !settingsStore.settings.focusBlockedDomains.isEmpty {
            if let helper = resolvedHelper {
                let restored = await helper.applyManagedBlockedDomains([])
                if restored {
                    mutationJournal.clear(.focusHostsBlock)
                    helperSyncMessage = "专注模式已结束，网站访问已恢复正常"
                }
            } else {
                mutationJournal.clear(.focusHostsBlock)
            }
        }
    }

    public func addBlockedDomain(_ raw: String) {
        let normalized = HostsBlocklistRenderer.normalizeDomains([raw])
        guard let primary = normalized.first(where: { !$0.hasPrefix("www.") }) ?? normalized.first else { return }
        if !settingsStore.settings.focusBlockedDomains.contains(primary) {
            settingsStore.settings.focusBlockedDomains.append(primary)
        }
    }

    public func removeBlockedDomain(_ domain: String) {
        settingsStore.settings.focusBlockedDomains.removeAll { $0.caseInsensitiveCompare(domain) == .orderedSame }
    }

    public func addBlockedAppBundleID(_ bundleID: String) {
        let trimmed = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed != StarIslandHelperConstants.appBundleIdentifier,
              trimmed != "com.apple.finder" else {
            return
        }
        if !settingsStore.settings.focusBlockedAppBundleIDs.contains(trimmed) {
            settingsStore.settings.focusBlockedAppBundleIDs.append(trimmed)
        }
    }

    public func removeBlockedAppBundleID(_ bundleID: String) {
        settingsStore.settings.focusBlockedAppBundleIDs.removeAll { $0 == bundleID }
    }

    private func applyHostsBlockIfConfigured() async {
        let domains = HostsBlocklistRenderer.normalizeDomains(settingsStore.settings.focusBlockedDomains)
        guard !domains.isEmpty else { return }

        mutationJournal.record(
            MutationRecord(
                kind: .focusHostsBlock,
                previousValue: "clean",
                appliedValue: domains.joined(separator: ",")
            )
        )

        if let helper = resolvedHelper {
            let ok = await helper.applyManagedBlockedDomains(domains)
            helperSyncMessage = ok
                ? "已通过特权助手屏蔽 \(domains.count) 个分心域名"
                : "特权助手未能写入 hosts，应用拦截仍生效"
            if !ok {
                mutationJournal.clear(.focusHostsBlock)
            }
        } else {
            mutationJournal.clear(.focusHostsBlock)
            helperSyncMessage = "特权助手未连接，当前仅启用娱乐应用拦截"
        }
    }

    private func startCountdownLoop() {
        countdownTask?.cancel()
        countdownTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled && self.isFocusing {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled, self.isFocusing else { break }
                self.remainingSeconds = max(0, self.remainingSeconds - 1)
                if self.remainingSeconds <= 0 {
                    await self.stopFocus()
                    NSSound.beep()
                    self.stateMachine.submit(
                        IslandActivityItem(
                            id: "focus.completed",
                            category: .focus,
                            title: "深度专注圆满完成",
                            subtitle: "本次共为您拦截 \(self.interceptedCount) 次分心干扰",
                            iconSymbol: "moon.stars.fill",
                            trailingBadge: "完成",
                            priority: .interactive,
                            isPeek: true,
                            allowsOnLockScreen: true,
                            autoDismissAfter: 5.0
                        )
                    )
                    break
                } else {
                    self.syncFocusActivityToIsland()
                }
            }
        }
    }

    private func syncFocusActivityToIsland() {
        stateMachine.submit(
            IslandActivityItem(
                id: "focus.session",
                category: .focus,
                title: "深度专注中",
                subtitle: "剩余 \(formattedRemaining) · 已拦截 \(interceptedCount) 次",
                iconSymbol: "moon.fill",
                trailingBadge: formattedRemaining,
                progress: progress,
                priority: .ongoing,
                allowsOnLockScreen: true
            )
        )
    }

    private func installAppInterceptors() {
        removeAppInterceptors()
        let center = NSWorkspace.shared.notificationCenter
        let names: [Notification.Name] = [
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.didLaunchApplicationNotification
        ]
        for name in names {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                Task { @MainActor [weak self] in
                    guard let self, let app else { return }
                    self.inspectAndInterceptIfNeeded(app)
                }
            }
            workspaceObservers.append(token)
        }
    }

    private func removeAppInterceptors() {
        let center = NSWorkspace.shared.notificationCenter
        for obs in workspaceObservers {
            center.removeObserver(obs)
        }
        workspaceObservers.removeAll()
    }

    private func inspectAndInterceptIfNeeded(_ app: NSRunningApplication) {
        guard isFocusing,
              let bundleID = app.bundleIdentifier,
              settingsStore.settings.focusBlockedAppBundleIDs.contains(bundleID) else {
            return
        }

        let appName = app.localizedName ?? bundleID
        _ = app.hide()
        if let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first {
            _ = finder.activate()
        }

        interceptedCount += 1
        lastInterceptedAppName = appName
        syncFocusActivityToIsland()

        stateMachine.submit(
            IslandActivityItem(
                id: "focus.intercepted",
                category: .focus,
                title: "专注护航 · 已拦截「\(appName)」",
                subtitle: "保持心流，剩余专注时间 \(formattedRemaining)",
                iconSymbol: "hand.raised.fill",
                trailingBadge: "已拦截",
                priority: .urgent,
                isPeek: true,
                autoDismissAfter: 3.5
            )
        )
    }
}
