import AppKit
import Combine
import Darwin
import Foundation
import IslandCore

/// 动态加载 macOS MediaRemote 私有框架桥接层
enum MediaRemoteBridge {
    enum Command: UInt32 {
        case play = 0
        case pause = 1
        case togglePlayPause = 2
        case stop = 3
        case nextTrack = 4
        case previousTrack = 5
    }

    private typealias RegisterNotificationsFn = @convention(c) (DispatchQueue) -> Void
    private typealias UnregisterNotificationsFn = @convention(c) () -> Void
    private typealias GetNowPlayingInfoFn = @convention(c) (DispatchQueue, @escaping @convention(block) (NSDictionary?) -> Void) -> Void
    private typealias GetIsPlayingFn = @convention(c) (DispatchQueue, @escaping @convention(block) (DarwinBoolean) -> Void) -> Void
    private typealias SendCommandFn = @convention(c) (UInt32, NSDictionary?) -> DarwinBoolean
    private typealias SetElapsedTimeFn = @convention(c) (Double) -> Void

    private static let handle: UnsafeMutableRawPointer? = {
        dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY)
    }()

    private static func symbol<T>(_ name: String, as type: T.Type) -> T? {
        guard let handle, let raw = dlsym(handle, name) else { return nil }
        return unsafeBitCast(raw, to: type)
    }

    static func registerNotifications() {
        symbol("MRMediaRemoteRegisterForNowPlayingNotifications", as: RegisterNotificationsFn.self)?(.main)
    }

    static func unregisterNotifications() {
        symbol("MRMediaRemoteUnregisterForNowPlayingNotifications", as: UnregisterNotificationsFn.self)?()
    }

    @discardableResult
    static func sendCommand(_ command: Command) -> Bool {
        guard let fn = symbol("MRMediaRemoteSendCommand", as: SendCommandFn.self) else { return false }
        return fn(command.rawValue, nil).boolValue
    }

    static func seek(to seconds: TimeInterval) -> Bool {
        guard let fn = symbol("MRMediaRemoteSetElapsedTime", as: SetElapsedTimeFn.self) else { return false }
        fn(max(0, seconds))
        return true
    }

    static func fetchSnapshot() async -> NowPlayingTrack? {
        guard let infoFn = symbol("MRMediaRemoteGetNowPlayingInfo", as: GetNowPlayingInfoFn.self) else {
            return nil
        }
        let queue = DispatchQueue.global(qos: .userInitiated)
        return await withCheckedContinuation { continuation in
            infoFn(queue) { rawDict in
                guard let dict = rawDict as? [String: Any],
                      let title = (dict["kMRMediaRemoteNowPlayingInfoTitle"] as? String)?
                        .trimmingCharacters(in: .whitespacesAndNewlines),
                      !title.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }

                let artist = (dict["kMRMediaRemoteNowPlayingInfoArtist"] as? String) ?? ""
                let album = (dict["kMRMediaRemoteNowPlayingInfoAlbum"] as? String) ?? ""
                let duration = (dict["kMRMediaRemoteNowPlayingInfoDuration"] as? Double) ?? 0
                let baseElapsed = (dict["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double) ?? 0
                let rate = (dict["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double) ?? 0
                let timestamp = dict["kMRMediaRemoteNowPlayingInfoTimestamp"] as? Date
                let artworkData = dict["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data
                let clientBundle = dict["kMRMediaRemoteNowPlayingInfoClientPropertiesData"] as? String

                let computedElapsed: Double
                if let timestamp, rate > 0 {
                    computedElapsed = baseElapsed + max(0, Date().timeIntervalSince(timestamp)) * rate
                } else {
                    computedElapsed = baseElapsed
                }

                if let playingFn = symbol("MRMediaRemoteGetNowPlayingApplicationIsPlaying", as: GetIsPlayingFn.self) {
                    playingFn(queue) { isPlayingFlag in
                        let playing = isPlayingFlag.boolValue || rate > 0.01
                        continuation.resume(returning: NowPlayingTrack(
                            title: title, artist: artist, album: album,
                            duration: duration, elapsedTime: computedElapsed,
                            isPlaying: playing, playbackRate: playing ? max(rate, 1.0) : 0.0,
                            source: MediaPlayerSource.resolve(bundleID: clientBundle),
                            sourceAppBundleID: clientBundle, artworkData: artworkData
                        ))
                    }
                } else {
                    let playing = rate > 0.01
                    continuation.resume(returning: NowPlayingTrack(
                        title: title, artist: artist, album: album,
                        duration: duration, elapsedTime: computedElapsed,
                        isPlaying: playing, playbackRate: playing ? max(rate, 1.0) : 0.0,
                        source: MediaPlayerSource.resolve(bundleID: clientBundle),
                        sourceAppBundleID: clientBundle, artworkData: artworkData
                    ))
                }
            }
        }
    }
}

/// 静默 AppleScript 播放器桥接（严格先检查进程运行态，绝不拉起未运行播放器）
enum SilentPlayerAppleScriptBridge {
    private static let scriptQueue = DispatchQueue(label: "com.adgry.starisland.applescript.media", qos: .utility)
    static let appleMusicBundleID = "com.apple.Music"
    static let spotifyBundleID = "com.spotify.client"

    @MainActor
    static func runningPlayerBundleIDs() -> Set<String> {
        Set(NSWorkspace.shared.runningApplications.filter { !$0.isTerminated }.compactMap(\.bundleIdentifier))
    }

    static func queryActiveTrack(runningBundleIDs: Set<String>) async -> NowPlayingTrack? {
        let musicRunning = runningBundleIDs.contains(appleMusicBundleID)
        let spotifyRunning = runningBundleIDs.contains(spotifyBundleID)
        guard musicRunning || spotifyRunning else { return nil }

        return await withCheckedContinuation { continuation in
            scriptQueue.async {
                if musicRunning, let track = readAppleMusicTrack(), track.isPlaying {
                    continuation.resume(returning: track)
                    return
                }
                if spotifyRunning, let track = readSpotifyTrack(), track.isPlaying {
                    continuation.resume(returning: track)
                    return
                }
                if musicRunning, let pausedMusic = readAppleMusicTrack() {
                    continuation.resume(returning: pausedMusic)
                    return
                }
                if spotifyRunning, let pausedSpotify = readSpotifyTrack() {
                    continuation.resume(returning: pausedSpotify)
                    return
                }
                continuation.resume(returning: nil)
            }
        }
    }

    static func performAction(_ scriptBody: String, targetBundleID: String, runningBundleIDs: Set<String>) {
        guard runningBundleIDs.contains(targetBundleID) else { return }
        scriptQueue.async {
            let source = """
            if application id "\(targetBundleID)" is running then
                tell application id "\(targetBundleID)"
                    try
                        \(scriptBody)
                    end try
                end tell
            end if
            """
            var error: NSDictionary?
            NSAppleScript(source: source)?.executeAndReturnError(&error)
        }
    }

    private static func readAppleMusicTrack() -> NowPlayingTrack? {
        let source = """
        if application id "com.apple.Music" is running then
            tell application id "com.apple.Music"
                try
                    set pState to (player state as string)
                    if pState is "stopped" then return ""
                    return (name of current track) & "|||" & (artist of current track) & "|||" & (album of current track) & "|||" & ((duration of current track) as string) & "|||" & ((player position) as string) & "|||" & pState & "|||" & ((favorited of current track) as string)
                end try
            end tell
        end if
        return ""
        """
        guard let raw = runStringScript(source), !raw.isEmpty else { return nil }
        let parts = raw.components(separatedBy: "|||")
        guard parts.count >= 7, !parts[0].isEmpty else { return nil }

        let isPlaying = parts[5].lowercased().contains("playing")
        return NowPlayingTrack(
            title: parts[0],
            artist: parts[1],
            album: parts[2],
            duration: parseScriptDouble(parts[3]),
            elapsedTime: parseScriptDouble(parts[4]),
            isPlaying: isPlaying,
            playbackRate: isPlaying ? 1.0 : 0.0,
            source: .appleMusic,
            sourceAppBundleID: appleMusicBundleID,
            artworkData: readAppleMusicArtworkData(),
            isFavorited: parts[6].lowercased() == "true"
        )
    }

    private static func readAppleMusicArtworkData() -> Data? {
        let source = """
        if application id "com.apple.Music" is running then
            tell application id "com.apple.Music"
                try
                    if (count of artworks of current track) > 0 then return raw data of artwork 1 of current track
                end try
            end tell
        end if
        """
        var error: NSDictionary?
        guard let descriptor = NSAppleScript(source: source)?.executeAndReturnError(&error) else { return nil }
        return descriptor.data.isEmpty ? nil : descriptor.data
    }

    private static func readSpotifyTrack() -> NowPlayingTrack? {
        let source = """
        if application id "com.spotify.client" is running then
            tell application id "com.spotify.client"
                try
                    set pState to (player state as string)
                    if pState is "stopped" then return ""
                    return (name of current track) & "|||" & (artist of current track) & "|||" & (album of current track) & "|||" & ((duration of current track) as string) & "|||" & ((player position) as string) & "|||" & pState
                end try
            end tell
        end if
        return ""
        """
        guard let raw = runStringScript(source), !raw.isEmpty else { return nil }
        let parts = raw.components(separatedBy: "|||")
        guard parts.count >= 6, !parts[0].isEmpty else { return nil }

        let rawDur = parseScriptDouble(parts[3])
        let isPlaying = parts[5].lowercased().contains("playing")
        return NowPlayingTrack(
            title: parts[0],
            artist: parts[1],
            album: parts[2],
            duration: rawDur > 1000 ? rawDur / 1000.0 : rawDur,
            elapsedTime: parseScriptDouble(parts[4]),
            isPlaying: isPlaying,
            playbackRate: isPlaying ? 1.0 : 0.0,
            source: .spotify,
            sourceAppBundleID: spotifyBundleID
        )
    }

    private static func runStringScript(_ source: String) -> String? {
        var error: NSDictionary?
        return NSAppleScript(source: source)?
            .executeAndReturnError(&error)
            .stringValue?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseScriptDouble(_ text: String) -> Double {
        Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
}

/// 多源系统正在播放控制器（MediaRemote + 静默 AppleScript 双引擎）
@MainActor
public final class NowPlayingService: ObservableObject {
    public static let shared = NowPlayingService()
    public static let activityID = "media.nowplaying"
    private static let peekActivityID = "media.trackchange"

    @Published public private(set) var currentTrack: NowPlayingTrack?
    @Published public private(set) var isMonitoring: Bool = false

    private let stateMachine: IslandStateMachine
    private let settingsStore: SettingsStore
    private var pollTimer: Timer?
    private var distributedObservers: [NSObjectProtocol] = []
    private var notificationObservers: [NSObjectProtocol] = []
    private var settingsCancellable: AnyCancellable?
    private var lastTrackIdentity: String?

    public init(
        stateMachine: IslandStateMachine? = nil,
        settingsStore: SettingsStore? = nil,
        autoStart: Bool = false
    ) {
        self.stateMachine = stateMachine ?? .shared
        self.settingsStore = settingsStore ?? .shared

        settingsCancellable = self.settingsStore.$settings
            .map(\.enableNowPlaying)
            .removeDuplicates()
            .sink { [weak self] enabled in
                guard let self else { return }
                if !enabled {
                    self.stateMachine.dismiss(id: Self.activityID)
                    self.stateMachine.dismiss(id: Self.peekActivityID)
                } else if let track = self.currentTrack {
                    self.publishToStateMachine(track: track, triggerPeek: false)
                }
            }

        if autoStart { startMonitoring() }
    }

    public func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        MediaRemoteBridge.registerNotifications()
        installNotificationObservers()

        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshNow() }
        }
        refreshNow()
    }

    public func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        pollTimer?.invalidate()
        pollTimer = nil

        distributedObservers.forEach { DistributedNotificationCenter.default().removeObserver($0) }
        distributedObservers.removeAll()
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
        notificationObservers.removeAll()
        MediaRemoteBridge.unregisterNotifications()
    }

    public func refreshNow() {
        guard settingsStore.settings.enableNowPlaying else { return }
        let runningIDs = SilentPlayerAppleScriptBridge.runningPlayerBundleIDs()

        Task { @MainActor [weak self] in
            if let mrTrack = await MediaRemoteBridge.fetchSnapshot() {
                self?.applyTrackSnapshot(mrTrack)
                return
            }
            let scriptTrack = await SilentPlayerAppleScriptBridge.queryActiveTrack(runningBundleIDs: runningIDs)
            self?.applyTrackSnapshot(scriptTrack)
        }
    }

    /// 应用媒体快照并同步推送至灵动岛状态机（allowsOnLockScreen = true）
    public func applyTrackSnapshot(_ track: NowPlayingTrack?) {
        let previousIdentity = lastTrackIdentity
        currentTrack = track
        lastTrackIdentity = track?.id

        guard settingsStore.settings.enableNowPlaying, let track else {
            stateMachine.dismiss(id: Self.activityID)
            stateMachine.dismiss(id: Self.peekActivityID)
            return
        }

        let didSwitchSong = (previousIdentity != nil && previousIdentity != track.id && track.isPlaying)
        publishToStateMachine(track: track, triggerPeek: didSwitchSong)
    }

    // MARK: - 播放控制动作

    public func togglePlayPause() {
        let runningIDs = SilentPlayerAppleScriptBridge.runningPlayerBundleIDs()
        if let bundleID = resolvedTargetPlayerBundleID(runningIDs: runningIDs) {
            SilentPlayerAppleScriptBridge.performAction("playpause", targetBundleID: bundleID, runningBundleIDs: runningIDs)
        } else {
            MediaRemoteBridge.sendCommand(.togglePlayPause)
        }

        if var track = currentTrack {
            track.elapsedTime = track.interpolatedElapsedTime()
            track.isPlaying.toggle()
            track.playbackRate = track.isPlaying ? 1.0 : 0.0
            track.updatedAt = Date()
            applyTrackSnapshot(track)
        }
    }

    public func nextTrack() {
        let runningIDs = SilentPlayerAppleScriptBridge.runningPlayerBundleIDs()
        if let bundleID = resolvedTargetPlayerBundleID(runningIDs: runningIDs) {
            SilentPlayerAppleScriptBridge.performAction("next track", targetBundleID: bundleID, runningBundleIDs: runningIDs)
        } else {
            MediaRemoteBridge.sendCommand(.nextTrack)
        }
        scheduleDelayedRefresh()
    }

    public func previousTrack() {
        let runningIDs = SilentPlayerAppleScriptBridge.runningPlayerBundleIDs()
        if let bundleID = resolvedTargetPlayerBundleID(runningIDs: runningIDs) {
            SilentPlayerAppleScriptBridge.performAction("previous track", targetBundleID: bundleID, runningBundleIDs: runningIDs)
        } else {
            MediaRemoteBridge.sendCommand(.previousTrack)
        }
        scheduleDelayedRefresh()
    }

    public func seek(to seconds: TimeInterval) {
        let clamped = max(0, seconds)
        let runningIDs = SilentPlayerAppleScriptBridge.runningPlayerBundleIDs()
        if let bundleID = resolvedTargetPlayerBundleID(runningIDs: runningIDs) {
            SilentPlayerAppleScriptBridge.performAction(
                String(format: "set player position to %.2f", clamped),
                targetBundleID: bundleID,
                runningBundleIDs: runningIDs
            )
        } else {
            _ = MediaRemoteBridge.seek(to: clamped)
        }

        if var track = currentTrack {
            track.elapsedTime = track.duration > 0 ? min(clamped, track.duration) : clamped
            track.updatedAt = Date()
            applyTrackSnapshot(track)
        }
    }

    public func toggleFavorite() {
        let runningIDs = SilentPlayerAppleScriptBridge.runningPlayerBundleIDs()
        guard var track = currentTrack else { return }
        let nextFav = !track.isFavorited
        if runningIDs.contains(SilentPlayerAppleScriptBridge.appleMusicBundleID), track.source == .appleMusic {
            SilentPlayerAppleScriptBridge.performAction(
                "set favorited of current track to \(nextFav ? "true" : "false")",
                targetBundleID: SilentPlayerAppleScriptBridge.appleMusicBundleID,
                runningBundleIDs: runningIDs
            )
        }
        track.isFavorited = nextFav
        applyTrackSnapshot(track)
    }

    // MARK: - 私有辅助

    private func resolvedTargetPlayerBundleID(runningIDs: Set<String>) -> String? {
        if let explicit = currentTrack?.source.bundleIdentifier, runningIDs.contains(explicit) { return explicit }
        if runningIDs.contains(SilentPlayerAppleScriptBridge.appleMusicBundleID) { return SilentPlayerAppleScriptBridge.appleMusicBundleID }
        if runningIDs.contains(SilentPlayerAppleScriptBridge.spotifyBundleID) { return SilentPlayerAppleScriptBridge.spotifyBundleID }
        return nil
    }

    private func scheduleDelayedRefresh() {
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            self?.refreshNow()
        }
    }

    private func publishToStateMachine(track: NowPlayingTrack, triggerPeek: Bool) {
        let subtitle = track.artist.isEmpty ? track.album : track.artist
        stateMachine.submit(IslandActivityItem(
            id: Self.activityID, category: .media, title: track.title, subtitle: subtitle,
            iconSymbol: track.isPlaying ? "waveform" : "pause.fill", trailingBadge: track.formattedElapsed,
            progress: track.progressFraction, priority: .ongoing, isAlertHUD: false, isPeek: false,
            allowsOnLockScreen: true, updatedAt: track.updatedAt
        ))
        if triggerPeek {
            stateMachine.submit(IslandActivityItem(
                id: Self.peekActivityID, category: .media, title: track.title, subtitle: subtitle,
                iconSymbol: "music.quarternote.3", trailingBadge: "切歌", progress: track.progressFraction,
                priority: .ongoing, isAlertHUD: false, isPeek: true, allowsOnLockScreen: true,
                autoDismissAfter: 2.8, updatedAt: Date()
            ))
        }
    }

    private func installNotificationObservers() {
        for name in ["com.apple.Music.playerInfo", "com.spotify.client.PlaybackStateChanged"] {
            distributedObservers.append(DistributedNotificationCenter.default().addObserver(
                forName: Notification.Name(name), object: nil, queue: .main
            ) { [weak self] _ in Task { @MainActor in self?.refreshNow() } })
        }
        for name in ["kMRMediaRemoteNowPlayingInfoDidChangeNotification", "kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification"] {
            notificationObservers.append(NotificationCenter.default.addObserver(
                forName: Notification.Name(name), object: nil, queue: .main
            ) { [weak self] _ in Task { @MainActor in self?.refreshNow() } })
        }
    }
}
