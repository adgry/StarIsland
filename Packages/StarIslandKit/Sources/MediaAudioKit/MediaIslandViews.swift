import AppKit
import Foundation
import IslandCore
import SwiftUI

/// 灵动岛展开态「正在播放」主工作台视图（封面流光、进度拖动、32 柱频谱、卡拉 OK 滚动歌词、8D/环绕快捷开关）
public struct NowPlayingIslandTabView: View {
    @ObservedObject private var nowPlayingService: NowPlayingService
    @ObservedObject private var lyricsService: LyricsService
    @ObservedObject private var spatialProcessor: SpatialAudioProcessor
    @ObservedObject private var settingsStore: SettingsStore

    @State private var isDraggingSeek = false
    @State private var draggedSeconds: Double = 0
    @State private var liveElapsedSeconds: Double = 0

    private let progressTick = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    @MainActor
    public init(
        nowPlayingService: NowPlayingService? = nil,
        lyricsService: LyricsService? = nil,
        spatialProcessor: SpatialAudioProcessor? = nil,
        settingsStore: SettingsStore? = nil
    ) {
        self.nowPlayingService = nowPlayingService ?? .shared
        self.lyricsService = lyricsService ?? .shared
        self.spatialProcessor = spatialProcessor ?? .shared
        self.settingsStore = settingsStore ?? .shared
    }

    public var body: some View {
        let palette = nowPlayingService.currentTrack?.palette ?? .starIslandDefault

        ZStack {
            fluidGlowBackground(palette: palette)

            if let track = nowPlayingService.currentTrack {
                HStack(spacing: 16) {
                    leftControlColumn(track: track, palette: palette)
                        .frame(width: 268)
                    Divider().background(.white.opacity(0.12))
                    rightLyricsColumn(track: track, palette: palette)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            } else {
                emptyMediaStateView()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onAppear {
            syncVisualizerAndSpatialMode()
            if let track = nowPlayingService.currentTrack { liveElapsedSeconds = track.interpolatedElapsedTime() }
        }
        .onChange(of: nowPlayingService.currentTrack) { _, newTrack in
            syncVisualizerAndSpatialMode()
            if !isDraggingSeek, let newTrack { liveElapsedSeconds = newTrack.interpolatedElapsedTime() }
        }
        .onChange(of: settingsStore.settings) { _, _ in syncVisualizerAndSpatialMode() }
        .onReceive(progressTick) { _ in
            guard !isDraggingSeek, let track = nowPlayingService.currentTrack else { return }
            liveElapsedSeconds = track.interpolatedElapsedTime()
        }
    }

    // MARK: - 左侧封面、控制、进度与 32 柱频谱

    @ViewBuilder
    private func leftControlColumn(track: NowPlayingTrack, palette: DominantColorPalette) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                artworkThumbnail(track: track, palette: palette)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Image(systemName: track.source.iconSymbol).font(.system(size: 10, weight: .semibold))
                        Text(track.source.displayName).font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.68))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(.white.opacity(0.10), in: Capsule())

                    Text(track.title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(track.artist.isEmpty ? (track.album.isEmpty ? "未知艺术家" : track.album) : track.artist)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Button { nowPlayingService.toggleFavorite() } label: {
                    Image(systemName: track.isFavorited ? "heart.fill" : "heart")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(track.isFavorited ? Color.pink : .white.opacity(0.65))
                }
                .buttonStyle(.plain)
                .help(track.isFavorited ? "取消喜爱" : "标记为喜爱")
            }

            VStack(spacing: 3) {
                let maxDur = max(track.duration, 1.0)
                let shownSec = isDraggingSeek ? draggedSeconds : min(liveElapsedSeconds, maxDur)

                Slider(
                    value: Binding(get: { shownSec }, set: { draggedSeconds = $0 }),
                    in: 0...maxDur,
                    onEditingChanged: { editing in
                        if editing {
                            draggedSeconds = liveElapsedSeconds
                            isDraggingSeek = true
                        } else {
                            isDraggingSeek = false
                            liveElapsedSeconds = draggedSeconds
                            nowPlayingService.seek(to: draggedSeconds)
                        }
                    }
                )
                .tint(palette.primaryColor)
                .controlSize(.mini)

                HStack {
                    Text(NowPlayingTrack.formatTimestamp(shownSec))
                    Spacer()
                    Text(track.duration > 0 ? NowPlayingTrack.formatTimestamp(track.duration) : "--:--")
                }
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.62))
            }

            if settingsStore.settings.enableAudioSpectrum {
                SpectrumBarsStripView(
                    bands: spatialProcessor.spectrumBands,
                    accentColor: palette.primaryColor,
                    secondaryColor: palette.secondaryColor
                )
                .frame(height: 28)
            }

            HStack(spacing: 10) {
                HStack(spacing: 14) {
                    Button { nowPlayingService.previousTrack() } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .buttonStyle(.plain)
                    .help("上一首")

                    Button { nowPlayingService.togglePlayPause() } label: {
                        Image(systemName: track.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 30, height: 30)
                            .background(.white, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help(track.isPlaying ? "暂停" : "播放")

                    Button { nowPlayingService.nextTrack() } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .buttonStyle(.plain)
                    .help("下一首")
                }

                Spacer()
                spatialQuickPills(palette: palette)
            }
        }
    }

    @ViewBuilder
    private func artworkThumbnail(track: NowPlayingTrack, palette: DominantColorPalette) -> some View {
        Group {
            if let data = track.artworkData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage).resizable().aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    LinearGradient(colors: [palette.primaryColor, palette.secondaryColor], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "music.quarternote.3")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                }
            }
        }
        .frame(width: 58, height: 58)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .shadow(color: palette.primaryColor.opacity(0.45), radius: 10, y: 4)
    }

    @ViewBuilder
    private func spatialQuickPills(palette: DominantColorPalette) -> some View {
        HStack(spacing: 4) {
            ForEach(SpatialAudioMode.allCases, id: \.rawValue) { item in
                let isSelected = spatialProcessor.mode == item
                Button { selectSpatialMode(item) } label: {
                    Text(item.shortBadge)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.68))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(isSelected ? palette.primaryColor.opacity(0.85) : Color.white.opacity(0.09), in: Capsule())
                }
                .buttonStyle(.plain)
                .help(item.title)
            }

            Button { settingsStore.settings.showDesktopFloatingLyrics.toggle() } label: {
                Image(systemName: "captions.bubble.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(settingsStore.settings.showDesktopFloatingLyrics ? palette.primaryColor : .white.opacity(0.58))
                    .padding(5)
                    .background(.white.opacity(0.09), in: Circle())
            }
            .buttonStyle(.plain)
            .help("桌面悬浮歌词开关")
        }
    }

    // MARK: - 右侧卡拉 OK 滚动歌词栏

    @ViewBuilder
    private func rightLyricsColumn(track: NowPlayingTrack, palette: DominantColorPalette) -> some View {
        if !settingsStore.settings.enableSyncedLyrics {
            VStack(spacing: 8) {
                Image(systemName: "quote.bubble").font(.system(size: 22)).foregroundStyle(.white.opacity(0.45))
                Text("同步歌词已关闭").font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.6))
                Button("开启同步歌词") { settingsStore.settings.enableSyncedLyrics = true }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if lyricsService.isLoading {
            VStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("正在检索毫秒级同步歌词…").font(.system(size: 12)).foregroundStyle(.white.opacity(0.68))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !lyricsService.lines.isEmpty {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 9) {
                        ForEach(Array(lyricsService.lines.enumerated()), id: \.element.id) { index, line in
                            let isActive = (lyricsService.activeIndex == index)
                            Button {
                                nowPlayingService.seek(to: line.time)
                                lyricsService.updatePlaybackPosition(line.time)
                            } label: {
                                Text(line.text.isEmpty ? "♪ · · ·" : line.text)
                                    .font(.system(size: isActive ? 14.5 : 12.0, weight: isActive ? .bold : .medium, design: .rounded))
                                    .foregroundStyle(
                                        isActive
                                            ? AnyShapeStyle(LinearGradient(colors: [.white, palette.primaryColor.opacity(0.95)], startPoint: .leading, endPoint: .trailing))
                                            : AnyShapeStyle(Color.white.opacity(0.42))
                                    )
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .scaleEffect(isActive ? 1.02 : 1.0, anchor: .leading)
                                    .animation(.easeOut(duration: 0.2), value: isActive)
                            }
                            .buttonStyle(.plain)
                            .id(line.id)
                        }
                    }
                    .padding(.vertical, 36)
                }
                .onChange(of: lyricsService.activeIndex) { _, newIdx in
                    guard let newIdx, lyricsService.lines.indices.contains(newIdx) else { return }
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) {
                        proxy.scrollTo(lyricsService.lines[newIdx].id, anchor: .center)
                    }
                }
            }
        } else if let plain = lyricsService.plainLyricsFallback, !plain.isEmpty {
            ScrollView(.vertical, showsIndicators: false) {
                Text(plain)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            }
        } else {
            VStack(spacing: 6) {
                Image(systemName: "music.note.list").font(.system(size: 22)).foregroundStyle(.white.opacity(0.42))
                Text(lyricsService.currentLineText.isEmpty ? "暂无匹配同步歌词" : lyricsService.currentLineText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                Text(track.title).font(.system(size: 11)).foregroundStyle(.white.opacity(0.38)).lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func emptyMediaStateView() -> some View {
        VStack(spacing: 10) {
            Image(systemName: "waveform.circle.fill").font(.system(size: 34)).foregroundStyle(.white.opacity(0.55))
            Text("当前暂无正在播放的音频")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.88))
            Text("在 Apple 音乐、Spotify 或浏览器播放媒体后，星岛将自动同步封面、32 段频谱与卡拉 OK 歌词")
                .font(.system(size: 11.5))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func fluidGlowBackground(palette: DominantColorPalette) -> some View {
        ZStack {
            Color.black.opacity(0.84)
            RadialGradient(colors: [palette.primaryColor.opacity(0.34), .clear], center: .topLeading, startRadius: 12, endRadius: 290)
            RadialGradient(colors: [palette.secondaryColor.opacity(0.26), .clear], center: .bottomTrailing, startRadius: 16, endRadius: 260)
        }
    }

    private func selectSpatialMode(_ target: SpatialAudioMode) {
        settingsStore.settings.enableSurroundAudio = (target == .surround)
        settingsStore.settings.enableEightDAudio = (target == .eightD)
        spatialProcessor.rotationHz = settingsStore.settings.eightDRotationHz
        spatialProcessor.setMode(target)
    }

    private func syncVisualizerAndSpatialMode() {
        let settings = settingsStore.settings
        let desiredMode: SpatialAudioMode = settings.enableEightDAudio ? .eightD : (settings.enableSurroundAudio ? .surround : .off)
        spatialProcessor.rotationHz = settings.eightDRotationHz
        if spatialProcessor.mode != desiredMode { spatialProcessor.setMode(desiredMode) }
        spatialProcessor.setVisualizerActive((nowPlayingService.currentTrack?.isPlaying ?? false) && settings.enableAudioSpectrum)
    }
}

/// 32 柱实时声波频谱组件
private struct SpectrumBarsStripView: View {
    let bands: [Float]
    let accentColor: Color
    let secondaryColor: Color

    var body: some View {
        let count = min(bands.count, 32)
        let barGradient = LinearGradient(
            colors: [accentColor, secondaryColor.opacity(0.75)],
            startPoint: .top,
            endPoint: .bottom
        )
        HStack(alignment: .bottom, spacing: 2.5) {
            ForEach(0..<count, id: \.self) { index in
                let clamped = min(max(Double(bands[index]), 0.0), 1.0)
                let barHeight = CGFloat(3.0 + clamped * 24.0)
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(barGradient)
                    .frame(maxWidth: .infinity)
                    .frame(height: barHeight)
                    .animation(.easeOut(duration: 0.08), value: barHeight)
            }
        }
    }
}

/// 「媒体与空间音效」中文设置面板（完整绑定 SettingsStore）
public struct MediaSettingsPaneView: View {
    @ObservedObject private var settingsStore: SettingsStore
    @ObservedObject private var lyricsService: LyricsService
    @ObservedObject private var spatialProcessor: SpatialAudioProcessor
    @ObservedObject private var hudInterceptor: SystemHUDInterceptor

    @State private var cachedLyricsCount: Int = 0

    @MainActor
    public init(
        settingsStore: SettingsStore? = nil,
        lyricsService: LyricsService? = nil,
        spatialProcessor: SpatialAudioProcessor? = nil,
        hudInterceptor: SystemHUDInterceptor? = nil
    ) {
        self.settingsStore = settingsStore ?? .shared
        self.lyricsService = lyricsService ?? .shared
        self.spatialProcessor = spatialProcessor ?? .shared
        self.hudInterceptor = hudInterceptor ?? .shared
    }

    public var body: some View {
        Form {
            Section("正在播放与逐行同步歌词") {
                Toggle("在灵动岛显示正在播放媒体卡片（支持锁屏安全显示）", isOn: $settingsStore.settings.enableNowPlaying)
                Toggle("自动检索毫秒级同步歌词（免密钥 LRCLIB 歌词源）", isOn: $settingsStore.settings.enableSyncedLyrics)
                Toggle("显示桌面底部悬浮卡拉 OK 歌词条", isOn: $settingsStore.settings.showDesktopFloatingLyrics)
                    .disabled(!settingsStore.settings.enableSyncedLyrics)

                HStack {
                    Text("本地歌词离线缓存：已缓存 \(cachedLyricsCount) 首曲目")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("清空歌词缓存") {
                        lyricsService.clearCache()
                        cachedLyricsCount = lyricsService.cachedFileCount()
                    }
                    .controlSize(.small)
                }
            }

            Section("32 频段实时频谱与空间声场增强") {
                Toggle("显示 32 柱实时 FFT 音频频谱动画", isOn: $settingsStore.settings.enableAudioSpectrum)

                Toggle("启用 HRTF 空间环绕声增强", isOn: Binding(
                    get: { settingsStore.settings.enableSurroundAudio },
                    set: { enabled in
                        settingsStore.settings.enableSurroundAudio = enabled
                        if enabled { settingsStore.settings.enableEightDAudio = false }
                        applySpatialSettings()
                    }
                ))

                Toggle("启用 8D 环绕旋转声场（音源绕听者圆周运动）", isOn: Binding(
                    get: { settingsStore.settings.enableEightDAudio },
                    set: { enabled in
                        settingsStore.settings.enableEightDAudio = enabled
                        if enabled { settingsStore.settings.enableSurroundAudio = false }
                        applySpatialSettings()
                    }
                ))

                VStack(alignment: .leading, spacing: 4) {
                    let hz = settingsStore.settings.eightDRotationHz
                    let period = hz > 0 ? (1.0 / hz) : 7.0
                    HStack {
                        Text("8D 旋转频率")
                        Spacer()
                        Text(String(format: "%.2f Hz（约 %.1f 秒/圈）", hz, period))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: Binding(
                            get: { settingsStore.settings.eightDRotationHz },
                            set: { newHz in
                                settingsStore.settings.eightDRotationHz = newHz
                                spatialProcessor.rotationHz = newHz
                            }
                        ),
                        in: 0.05...0.50,
                        step: 0.01
                    )
                    .disabled(!settingsStore.settings.enableEightDAudio)
                }
            }

            Section("原生系统 HUD 灵动接管") {
                Toggle("接管系统音量、静音与蓝牙音频连接 HUD", isOn: $settingsStore.settings.enableCustomVolumeHUD)
                Toggle("接管屏幕亮度与键盘背光调节 HUD", isOn: $settingsStore.settings.enableCustomBrightnessHUD)

                HStack(spacing: 12) {
                    Button("预览音量 HUD") { hudInterceptor.presentHUD(kind: .volume, value: 0.72, isMuted: false) }
                        .controlSize(.small)
                    Button("预览屏幕亮度 HUD") { hudInterceptor.presentHUD(kind: .brightness, value: 0.80, isMuted: false) }
                        .controlSize(.small)
                    Button("预览键盘背光 HUD") { hudInterceptor.presentHUD(kind: .keyboardBacklight, value: 0.50, isMuted: false) }
                        .controlSize(.small)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { cachedLyricsCount = lyricsService.cachedFileCount() }
    }

    private func applySpatialSettings() {
        spatialProcessor.rotationHz = settingsStore.settings.eightDRotationHz
        if settingsStore.settings.enableEightDAudio {
            spatialProcessor.setMode(.eightD)
        } else if settingsStore.settings.enableSurroundAudio {
            spatialProcessor.setMode(.surround)
        } else {
            spatialProcessor.setMode(.off)
        }
    }
}
