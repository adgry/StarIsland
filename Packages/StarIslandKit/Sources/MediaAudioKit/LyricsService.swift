import AppKit
import Combine
import Foundation
import IslandCore
import SwiftUI

/// 单行带毫秒级时间轴的同步歌词模型
public struct TimedLyricLine: Equatable, Identifiable, Codable, Sendable {
    public let id: String
    public let time: TimeInterval
    public let text: String

    public init(id: String? = nil, time: TimeInterval, text: String) {
        let clampedTime = max(0, time)
        self.time = clampedTime
        self.text = text
        self.id = id ?? "\(Int((clampedTime * 1000).rounded())):\(text)"
    }
}

/// 标准与扩展 LRC 歌词解析器（支持百分秒、毫秒、多时间标签行与二分查找定位）
public enum LRCParser {
    private static let timeTagRegex = try! NSRegularExpression(pattern: #"\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]"#)
    private static let offsetRegex = try! NSRegularExpression(pattern: #"\[offset:\s*([+-]?\d+)\s*\]"#, options: [.caseInsensitive])
    private static let inlineWordTagRegex = try! NSRegularExpression(pattern: #"<\d{1,3}:\d{1,2}(?:[.:]\d{1,3})?>"#)

    /// 解析原始 LRC 文本为按时间升序排列的歌词数组
    public static func parse(_ lrc: String) -> [TimedLyricLine] {
        guard !lrc.isEmpty else { return [] }

        var globalOffsetSeconds: TimeInterval = 0
        let nsFull = lrc as NSString
        if let match = offsetRegex.firstMatch(in: lrc, range: NSRange(location: 0, length: nsFull.length)),
           match.numberOfRanges >= 2,
           let ms = Double(nsFull.substring(with: match.range(at: 1))) {
            globalOffsetSeconds = ms / 1000.0
        }

        var rawEntries: [(time: TimeInterval, order: Int, text: String)] = []
        var lineCounter = 0

        for rawLine in lrc.components(separatedBy: .newlines) {
            let trimmedLine = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else { continue }

            let nsLine = trimmedLine as NSString
            let fullRange = NSRange(location: 0, length: nsLine.length)
            let matches = timeTagRegex.matches(in: trimmedLine, range: fullRange)
            guard !matches.isEmpty else { continue }

            let strippedTags = timeTagRegex.stringByReplacingMatches(in: trimmedLine, range: fullRange, withTemplate: "")
            let strippedInline = inlineWordTagRegex.stringByReplacingMatches(
                in: strippedTags,
                range: NSRange(location: 0, length: (strippedTags as NSString).length),
                withTemplate: ""
            )
            let lyricText = strippedInline.trimmingCharacters(in: .whitespacesAndNewlines)

            for match in matches {
                let minutes = Double(nsLine.substring(with: match.range(at: 1))) ?? 0
                let seconds = Double(nsLine.substring(with: match.range(at: 2))) ?? 0

                var fraction: Double = 0
                let fracRange = match.range(at: 3)
                if fracRange.location != NSNotFound, fracRange.length > 0 {
                    let fracStr = nsLine.substring(with: fracRange)
                    let value = Double(fracStr) ?? 0
                    switch fracStr.count {
                    case 1: fraction = value / 10.0
                    case 2: fraction = value / 100.0
                    default: fraction = value / 1000.0
                    }
                }

                let timestamp = max(0, minutes * 60.0 + seconds + fraction + globalOffsetSeconds)
                rawEntries.append((time: timestamp, order: lineCounter, text: lyricText))
                lineCounter += 1
            }
        }

        rawEntries.sort { lhs, rhs in
            if abs(lhs.time - rhs.time) > 1e-6 { return lhs.time < rhs.time }
            return lhs.order < rhs.order
        }

        return rawEntries.enumerated().map { idx, item in
            TimedLyricLine(id: "\(idx)-\(Int((item.time * 1000).rounded()))", time: item.time, text: item.text)
        }
    }

    /// 二分查找当前播放秒数对应的活跃歌词行下标（O(log n)）
    public static func activeLineIndex(in lines: [TimedLyricLine], at position: TimeInterval) -> Int? {
        guard !lines.isEmpty else { return nil }
        let epsilon = 1e-5
        guard position + epsilon >= lines[0].time else { return nil }

        var low = 0
        var high = lines.count - 1
        var bestIndex: Int? = nil

        while low <= high {
            let mid = low + (high - low) / 2
            if lines[mid].time <= position + epsilon {
                bestIndex = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return bestIndex
    }
}

private struct LRCLIBEntryDTO: Decodable {
    let plainLyrics: String?
    let syncedLyrics: String?
}

/// 逐行同步歌词检索、磁盘缓存与实时高亮推进服务
@MainActor
public final class LyricsService: ObservableObject {
    public static let shared = LyricsService()

    @Published public private(set) var lines: [TimedLyricLine] = []
    @Published public private(set) var activeIndex: Int?
    @Published public private(set) var currentLineText: String = ""
    @Published public private(set) var nextLineText: String = ""
    @Published public private(set) var plainLyricsFallback: String?
    @Published public private(set) var isLoading: Bool = false

    public let cacheDirectory: URL

    private let nowPlayingService: NowPlayingService
    private let settingsStore: SettingsStore
    private let urlSession: URLSession
    private var fetchTask: Task<Void, Never>?
    private var syncTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var loadedTrackIdentity: String?
    private lazy var floatingPanel = FloatingLyricsPanelController(lyricsService: self, nowPlayingService: nowPlayingService)

    public init(
        nowPlayingService: NowPlayingService? = nil,
        settingsStore: SettingsStore? = nil,
        cacheDirectory: URL? = nil,
        autoBind: Bool = true
    ) {
        self.nowPlayingService = nowPlayingService ?? .shared
        self.settingsStore = settingsStore ?? .shared
        let resolvedCache = cacheDirectory ?? StarIslandPaths.cachesDirectory.appendingPathComponent("Lyrics", isDirectory: true)
        self.cacheDirectory = resolvedCache
        try? FileManager.default.createDirectory(at: resolvedCache, withIntermediateDirectories: true)

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8.0
        config.timeoutIntervalForResource = 8.0
        self.urlSession = URLSession(configuration: config)

        if autoBind { bindStreams() }
    }

    public func loadLyrics(for track: NowPlayingTrack) {
        guard settingsStore.settings.enableSyncedLyrics else {
            resetLyrics()
            return
        }

        if loadedTrackIdentity == track.id && (!lines.isEmpty || plainLyricsFallback != nil) {
            updatePlaybackPosition(track.interpolatedElapsedTime())
            return
        }

        loadedTrackIdentity = track.id
        fetchTask?.cancel()

        let cacheURL = cacheFileURL(for: track)
        if let cachedLRC = try? String(contentsOf: cacheURL, encoding: .utf8),
           !cachedLRC.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            applyParsedLRC(cachedLRC, at: track.interpolatedElapsedTime())
            return
        }

        isLoading = true
        lines = []
        activeIndex = nil
        currentLineText = "正在搜索同步歌词…"
        nextLineText = ""
        plainLyricsFallback = nil

        let title = track.title
        let artist = track.artist
        let album = track.album
        let duration = track.duration
        let session = urlSession

        fetchTask = Task { [weak self] in
            let fetched = await Self.fetchFromLRCLIB(title: title, artist: artist, album: album, duration: duration, session: session)
            guard !Task.isCancelled, let self else { return }
            self.isLoading = false

            if let synced = fetched?.synced, !synced.isEmpty {
                try? synced.write(to: cacheURL, atomically: true, encoding: .utf8)
                let pos = self.nowPlayingService.currentTrack?.interpolatedElapsedTime() ?? 0
                self.applyParsedLRC(synced, at: pos)
            } else if let plain = fetched?.plain, !plain.isEmpty {
                self.lines = []
                self.activeIndex = nil
                self.plainLyricsFallback = plain
                self.currentLineText = plain.components(separatedBy: .newlines).first ?? ""
                self.nextLineText = ""
            } else {
                self.lines = []
                self.activeIndex = nil
                self.plainLyricsFallback = nil
                self.currentLineText = "暂无匹配同步歌词"
                self.nextLineText = ""
            }
        }
    }

    public func applyParsedLRC(_ rawLRC: String, at position: TimeInterval = 0) {
        lines = LRCParser.parse(rawLRC)
        plainLyricsFallback = nil
        updatePlaybackPosition(position)
    }

    public func updatePlaybackPosition(_ position: TimeInterval) {
        guard !lines.isEmpty else { return }
        let idx = LRCParser.activeLineIndex(in: lines, at: position)
        if activeIndex != idx { activeIndex = idx }
        if let idx, lines.indices.contains(idx) {
            let candidate = lines[idx].text
            currentLineText = candidate.isEmpty ? "♪ 间奏中…" : candidate
            let nextIdx = idx + 1
            nextLineText = lines.indices.contains(nextIdx) ? lines[nextIdx].text : ""
        } else {
            currentLineText = lines.first?.text ?? ""
            nextLineText = lines.dropFirst().first?.text ?? ""
        }
    }

    public func resetLyrics() {
        fetchTask?.cancel()
        isLoading = false
        loadedTrackIdentity = nil
        lines = []
        activeIndex = nil
        currentLineText = ""
        nextLineText = ""
        plainLyricsFallback = nil
    }

    public func clearCache() {
        let urls = (try? FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)) ?? []
        urls.forEach { try? FileManager.default.removeItem(at: $0) }
    }

    public func cachedFileCount() -> Int {
        let urls = (try? FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)) ?? []
        return urls.filter { $0.pathExtension == "lrc" }.count
    }

    // MARK: - 内部绑定与网络请求

    private func bindStreams() {
        nowPlayingService.$currentTrack
            .sink { [weak self] track in
                guard let self else { return }
                if let track {
                    self.loadLyrics(for: track)
                    self.updateFloatingPanelVisibility()
                } else {
                    self.resetLyrics()
                    self.floatingPanel.hide()
                }
            }
            .store(in: &cancellables)

        settingsStore.$settings
            .sink { [weak self] settings in
                guard let self else { return }
                if !settings.enableSyncedLyrics {
                    self.resetLyrics()
                } else if let track = self.nowPlayingService.currentTrack, self.lines.isEmpty {
                    self.loadLyrics(for: track)
                }
                self.updateFloatingPanelVisibility()
            }
            .store(in: &cancellables)

        syncTimer = Timer.scheduledTimer(withTimeInterval: 0.16, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let track = self.nowPlayingService.currentTrack, track.isPlaying else { return }
                self.updatePlaybackPosition(track.interpolatedElapsedTime())
            }
        }
    }

    private func updateFloatingPanelVisibility() {
        let shouldShow = settingsStore.settings.enableSyncedLyrics
            && settingsStore.settings.showDesktopFloatingLyrics
            && nowPlayingService.currentTrack != nil
        shouldShow ? floatingPanel.show() : floatingPanel.hide()
    }

    private func cacheFileURL(for track: NowPlayingTrack) -> URL {
        let rawKey = "\(track.title.lowercased())|\(track.artist.lowercased())|\(Int(track.duration.rounded()))"
        return cacheDirectory.appendingPathComponent("\(ConsumedEventStore.sha256Hex(rawKey)).lrc")
    }

    private static func fetchFromLRCLIB(
        title: String,
        artist: String,
        album: String,
        duration: TimeInterval,
        session: URLSession
    ) async -> (synced: String?, plain: String?)? {
        if var getComps = URLComponents(string: "https://lrclib.net/api/get") {
            var items = [
                URLQueryItem(name: "track_name", value: title),
                URLQueryItem(name: "artist_name", value: artist)
            ]
            if !album.isEmpty { items.append(URLQueryItem(name: "album_name", value: album)) }
            if duration > 1 { items.append(URLQueryItem(name: "duration", value: String(Int(duration.rounded())))) }
            getComps.queryItems = items
            if let url = getComps.url,
               let entry: LRCLIBEntryDTO = await requestJSON(url: url, session: session),
               (entry.syncedLyrics != nil || entry.plainLyrics != nil) {
                return (entry.syncedLyrics, entry.plainLyrics)
            }
        }

        if var searchComps = URLComponents(string: "https://lrclib.net/api/search") {
            searchComps.queryItems = [
                URLQueryItem(name: "track_name", value: title),
                URLQueryItem(name: "artist_name", value: artist)
            ]
            if let url = searchComps.url,
               let entries: [LRCLIBEntryDTO] = await requestJSON(url: url, session: session) {
                if let bestSynced = entries.first(where: { !($0.syncedLyrics ?? "").isEmpty }) {
                    return (bestSynced.syncedLyrics, bestSynced.plainLyrics)
                }
                if let bestPlain = entries.first(where: { !($0.plainLyrics ?? "").isEmpty }) {
                    return (nil, bestPlain.plainLyrics)
                }
            }
        }
        return nil
    }

    private static func requestJSON<T: Decodable>(url: URL, session: URLSession) async -> T? {
        var req = URLRequest(url: url)
        req.setValue("StarIsland/1.0.0 (https://github.com/adgry/StarIsland)", forHTTPHeaderField: "User-Agent")
        guard let (data, resp) = try? await session.data(for: req),
              let http = resp as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

/// 桌面悬浮歌词条窗口控制器
@MainActor
public final class FloatingLyricsPanelController {
    private var panel: NSPanel?
    private unowned let lyricsService: LyricsService
    private unowned let nowPlayingService: NowPlayingService

    public init(lyricsService: LyricsService, nowPlayingService: NowPlayingService) {
        self.lyricsService = lyricsService
        self.nowPlayingService = nowPlayingService
    }

    public func show() {
        if let panel {
            panel.orderFrontRegardless()
            return
        }
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let rect = NSRect(x: screenFrame.midX - 280, y: screenFrame.minY + 28, width: 560, height: 64)

        let newPanel = NSPanel(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        newPanel.isFloatingPanel = true
        newPanel.level = .floating
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.backgroundColor = .clear
        newPanel.isOpaque = false
        newPanel.hasShadow = true
        newPanel.isMovableByWindowBackground = true
        newPanel.hidesOnDeactivate = false
        newPanel.contentView = NSHostingView(
            rootView: FloatingLyricsBannerView(lyricsService: lyricsService, nowPlayingService: nowPlayingService)
        )
        newPanel.orderFrontRegardless()
        self.panel = newPanel
    }

    public func hide() {
        panel?.orderOut(nil)
    }
}

private struct FloatingLyricsBannerView: View {
    @ObservedObject var lyricsService: LyricsService
    @ObservedObject var nowPlayingService: NowPlayingService

    var body: some View {
        let palette = nowPlayingService.currentTrack?.palette ?? .starIslandDefault
        VStack(spacing: 3) {
            Text(lyricsService.currentLineText.isEmpty ? "♪ 星岛同步歌词" : lyricsService.currentLineText)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [.white, palette.primaryColor.opacity(0.95)], startPoint: .leading, endPoint: .trailing)
                )
                .lineLimit(1)
                .shadow(color: .black.opacity(0.55), radius: 3, y: 1)

            if !lyricsService.nextLineText.isEmpty {
                Text(lyricsService.nextLineText)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(Capsule(style: .continuous).strokeBorder(.white.opacity(0.16), lineWidth: 0.8))
        )
        .environment(\.colorScheme, .dark)
    }
}
