import Foundation
import IslandCore
import MediaAudioKit
import XCTest

final class MediaAudioKitTests: XCTestCase {

    // MARK: - 1. LRCParser 毫秒级解析与二分查找测试

    func testLRCParserParsesCentisecondAndMillisecondTimestamps() {
        let rawLRC = """
        [ti:星岛夜航]
        [ar:StarIsland]
        [al:银河漫游]
        [01:23.45]穿过静谧的云海
        [00:05.120]前奏轻轻响起
        [00:02.00]
        """

        let lines = LRCParser.parse(rawLRC)
        XCTAssertEqual(lines.count, 3)

        XCTAssertEqual(lines[0].time, 2.00, accuracy: 0.001)
        XCTAssertEqual(lines[0].text, "")

        XCTAssertEqual(lines[1].time, 5.12, accuracy: 0.0005)
        XCTAssertEqual(lines[1].text, "前奏轻轻响起")

        XCTAssertEqual(lines[2].time, 83.45, accuracy: 0.001)
        XCTAssertEqual(lines[2].text, "穿过静谧的云海")
    }

    func testLRCParserExpandsMultipleTagsOnSameLine() {
        let rawLRC = """
        [00:15.25][01:45.800][02:50.05]同一句星河副歌
        [00:42.00]主歌过渡段
        """

        let lines = LRCParser.parse(rawLRC)
        XCTAssertEqual(lines.count, 4)

        XCTAssertEqual(lines[0].time, 15.25, accuracy: 0.001)
        XCTAssertEqual(lines[0].text, "同一句星河副歌")

        XCTAssertEqual(lines[1].time, 42.00, accuracy: 0.001)
        XCTAssertEqual(lines[1].text, "主歌过渡段")

        XCTAssertEqual(lines[2].time, 105.80, accuracy: 0.001)
        XCTAssertEqual(lines[2].text, "同一句星河副歌")

        XCTAssertEqual(lines[3].time, 170.05, accuracy: 0.001)
        XCTAssertEqual(lines[3].text, "同一句星河副歌")
    }

    func testLRCParserActiveLineBinarySearch() {
        let rawLRC = """
        [00:05.120]第一句
        [00:15.25]第二句
        [00:42.00]第三句
        [01:23.45]第四句
        [01:45.800]第五句
        """
        let lines = LRCParser.parse(rawLRC)

        XCTAssertNil(LRCParser.activeLineIndex(in: [], at: 10.0))
        XCTAssertNil(LRCParser.activeLineIndex(in: lines, at: 0.0))
        XCTAssertNil(LRCParser.activeLineIndex(in: lines, at: 5.10))

        XCTAssertEqual(LRCParser.activeLineIndex(in: lines, at: 5.12), 0)
        XCTAssertEqual(LRCParser.activeLineIndex(in: lines, at: 14.99), 0)
        XCTAssertEqual(LRCParser.activeLineIndex(in: lines, at: 15.25), 1)
        XCTAssertEqual(LRCParser.activeLineIndex(in: lines, at: 83.45), 3)
        XCTAssertEqual(LRCParser.activeLineIndex(in: lines, at: 99.00), 3)
        XCTAssertEqual(LRCParser.activeLineIndex(in: lines, at: 300.0), 4)
    }

    // MARK: - 2. SpatialAudioProcessor FFT 32 段频谱测试

    func testComputeSpectrumSilenceOutputsAllZeros() {
        let silence = [Float](repeating: 0.0, count: 1024)
        let bands = SpatialAudioProcessor.computeSpectrum(samples: silence, bandCount: 32)

        XCTAssertEqual(bands.count, 32)
        for value in bands {
            XCTAssertEqual(value, 0.0, accuracy: 1e-6)
        }
    }

    func testComputeSpectrumSineWaveNormalizedInUnitRange() {
        let sampleCount = 1024
        let sampleRate: Float = 44_100
        let frequency: Float = 880
        let samples: [Float] = (0..<sampleCount).map { index in
            sin(2.0 * .pi * frequency * Float(index) / sampleRate)
        }

        let processor = SpatialAudioProcessor()
        let bands = processor.computeSpectrum(samples: samples, bandCount: 32)

        XCTAssertEqual(bands.count, 32)
        for band in bands {
            XCTAssertFalse(band.isNaN)
            XCTAssertFalse(band.isInfinite)
            XCTAssertGreaterThanOrEqual(band, 0.0)
            XCTAssertLessThanOrEqual(band, 1.0)
        }

        let peak = bands.max() ?? 0.0
        let minimum = bands.min() ?? 1.0
        XCTAssertGreaterThan(peak, 0.35, "正弦波输入应在对应频段产生显著响应")
        XCTAssertLessThan(minimum, peak, "频谱不应退化为全频段常数")
    }

    // MARK: - 3. SpatialAudioProcessor 8D 圆周轨迹坐标与周期连续性测试

    func testEightDListenerPositionCircularAccuracyAndPeriodicity() {
        let radius: Float = 2.4

        let p0 = SpatialAudioProcessor.eightDListenerPosition(phase: 0.0, radius: radius)
        let p025 = SpatialAudioProcessor.eightDListenerPosition(phase: 0.25, radius: radius)
        let p05 = SpatialAudioProcessor.eightDListenerPosition(phase: 0.5, radius: radius)
        let p10 = SpatialAudioProcessor.eightDListenerPosition(phase: 1.0, radius: radius)

        // phase = 0: 正前方 (0, 0, -R)
        XCTAssertEqual(p0.x, 0.0, accuracy: 1e-4)
        XCTAssertEqual(p0.y, 0.0, accuracy: 1e-4)
        XCTAssertEqual(p0.z, -radius, accuracy: 1e-4)

        // phase = 0.25: 右侧 (+R, 0, 0)
        XCTAssertEqual(p025.x, radius, accuracy: 1e-4)
        XCTAssertEqual(p025.y, 0.0, accuracy: 1e-4)
        XCTAssertEqual(p025.z, 0.0, accuracy: 1e-4)

        // phase = 0.5: 正后方 (0, 0, +R)
        XCTAssertEqual(p05.x, 0.0, accuracy: 1e-4)
        XCTAssertEqual(p05.y, 0.0, accuracy: 1e-4)
        XCTAssertEqual(p05.z, radius, accuracy: 1e-4)

        // phase = 1.0 与 phase = 0.0 严格周期闭合
        XCTAssertEqual(p10.x, p0.x, accuracy: 1e-5)
        XCTAssertEqual(p10.y, p0.y, accuracy: 1e-5)
        XCTAssertEqual(p10.z, p0.z, accuracy: 1e-5)

        // 校验圆周半径恒定与边界连续性
        let nearWrap = SpatialAudioProcessor.eightDListenerPosition(phase: 0.999, radius: radius)
        let jumpDistance = sqrt(
            pow(nearWrap.x - p10.x, 2) +
            pow(nearWrap.y - p10.y, 2) +
            pow(nearWrap.z - p10.z, 2)
        )
        XCTAssertLessThan(jumpDistance, 0.03, "周期边界附近应平滑连续无跳变")

        for step in 0...8 {
            let pos = SpatialAudioProcessor.eightDListenerPosition(phase: Double(step) / 8.0, radius: radius)
            let dist = sqrt(pos.x * pos.x + pos.y * pos.y + pos.z * pos.z)
            XCTAssertEqual(dist, radius, accuracy: 1e-4)
        }
    }

    func testSpatialAudioProcessorModeAndRotationRateClamping() {
        let processor = SpatialAudioProcessor()
        XCTAssertEqual(processor.mode, .off)

        processor.rotationHz = 9.0
        XCTAssertEqual(processor.rotationHz, 0.5, accuracy: 1e-6)

        processor.rotationHz = 0.001
        XCTAssertEqual(processor.rotationHz, 0.05, accuracy: 1e-6)

        processor.setMode(.surround)
        XCTAssertEqual(processor.mode, .surround)

        processor.setMode(.off)
        XCTAssertEqual(processor.mode, .off)
    }

    // MARK: - 4. SystemHUDInterceptor 数值钳制、静音图标与 alertHUD 状态测试

    @MainActor
    func testSystemHUDInterceptorClampingMuteMappingAndAlertHUDSubmission() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let stateMachine = IslandStateMachine()
        let settingsStore = SettingsStore(fileURL: tempDir.appendingPathComponent("settings.json"))
        let interceptor = SystemHUDInterceptor(
            stateMachine: stateMachine,
            settingsStore: settingsStore,
            observeCoreAudio: false
        )

        // 1. 音量超出上限 > 1.0 钳制为 1.0
        interceptor.presentHUD(kind: .volume, value: 1.65, isMuted: false)
        XCTAssertEqual(stateMachine.displayState, .alertHUD)
        let volHigh = try XCTUnwrap(stateMachine.primaryActivity)
        XCTAssertTrue(volHigh.isAlertHUD)
        XCTAssertEqual(volHigh.category, .systemHUD)
        XCTAssertEqual(volHigh.progress ?? -1, 1.0, accuracy: 1e-6)
        XCTAssertEqual(volHigh.trailingBadge, "100%")
        XCTAssertEqual(volHigh.iconSymbol, "speaker.wave.3.fill")

        // 2. 屏幕亮度低于下限 < 0.0 钳制为 0.0
        interceptor.presentHUD(kind: .brightness, value: -0.4, isMuted: false)
        XCTAssertEqual(stateMachine.displayState, .alertHUD)
        let brightLow = try XCTUnwrap(stateMachine.primaryActivity)
        XCTAssertTrue(brightLow.isAlertHUD)
        XCTAssertEqual(brightLow.progress ?? -1, 0.0, accuracy: 1e-6)
        XCTAssertEqual(brightLow.trailingBadge, "0%")
        XCTAssertEqual(brightLow.iconSymbol, "sun.min.fill")

        // 3. 键盘背光正常区间百分比映射
        interceptor.presentHUD(kind: .keyboardBacklight, value: 0.64, isMuted: false)
        let kbItem = try XCTUnwrap(stateMachine.primaryActivity)
        XCTAssertTrue(kbItem.isAlertHUD)
        XCTAssertEqual(kbItem.progress ?? -1, 0.64, accuracy: 1e-6)
        XCTAssertEqual(kbItem.trailingBadge, "64%")
        XCTAssertEqual(kbItem.iconSymbol, "light.max")

        // 4. 静音状态图标映射
        interceptor.presentHUD(kind: .volume, value: 0.58, isMuted: true)
        let mutedItem = try XCTUnwrap(stateMachine.primaryActivity)
        XCTAssertTrue(mutedItem.isAlertHUD)
        XCTAssertEqual(mutedItem.iconSymbol, "speaker.slash.fill")
        XCTAssertEqual(mutedItem.trailingBadge, "静音")
        XCTAssertEqual(mutedItem.progress ?? -1, 0.0, accuracy: 1e-6)
    }

    // MARK: - 5. NowPlayingService 锁屏实时活动推送测试

    @MainActor
    func testNowPlayingServiceSubmitsLockScreenVisibleActivity() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let stateMachine = IslandStateMachine()
        let settingsStore = SettingsStore(fileURL: tempDir.appendingPathComponent("settings.json"))
        let service = NowPlayingService(
            stateMachine: stateMachine,
            settingsStore: settingsStore,
            autoStart: false
        )

        let track = NowPlayingTrack(
            title: "夜曲",
            artist: "周杰伦",
            album: "十一月的萧邦",
            duration: 226,
            elapsedTime: 45,
            isPlaying: true,
            source: .appleMusic
        )
        service.applyTrackSnapshot(track)

        let activity = try XCTUnwrap(stateMachine.primaryActivity)
        XCTAssertEqual(activity.category, .media)
        XCTAssertTrue(activity.allowsOnLockScreen)
        XCTAssertEqual(stateMachine.displayState, .pill)

        stateMachine.setScreenLocked(true)
        XCTAssertNotNil(stateMachine.primaryActivity, "锁屏状态下媒体实时活动仍应保留显示")
    }

    // MARK: - 6. LyricsService 本地磁盘缓存读取与实时行推进测试

    @MainActor
    func testLyricsServiceLoadsFromDiskCacheAndTracksPosition() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cacheDir = tempDir.appendingPathComponent("Lyrics", isDirectory: true)
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let stateMachine = IslandStateMachine()
        let settingsStore = SettingsStore(fileURL: tempDir.appendingPathComponent("settings.json"))
        let nowPlaying = NowPlayingService(stateMachine: stateMachine, settingsStore: settingsStore, autoStart: false)
        let lyricsService = LyricsService(
            nowPlayingService: nowPlaying,
            settingsStore: settingsStore,
            cacheDirectory: cacheDir,
            autoBind: false
        )

        let track = NowPlayingTrack(title: "星岛漫游", artist: "StarIsland", duration: 180, elapsedTime: 18)
        let hash = ConsumedEventStore.sha256Hex("星岛漫游|starisland|180")
        let cachedLRC = """
        [00:04.50]第一缕星光
        [00:16.200]越过山海与云层
        [00:32.00]抵达宁静港湾
        """
        try cachedLRC.write(to: cacheDir.appendingPathComponent("\(hash).lrc"), atomically: true, encoding: .utf8)

        lyricsService.loadLyrics(for: track)
        XCTAssertEqual(lyricsService.lines.count, 3)
        XCTAssertEqual(lyricsService.activeIndex, 1)
        XCTAssertEqual(lyricsService.currentLineText, "越过山海与云层")
        XCTAssertEqual(lyricsService.nextLineText, "抵达宁静港湾")
        XCTAssertEqual(lyricsService.cachedFileCount(), 1)

        lyricsService.clearCache()
        XCTAssertEqual(lyricsService.cachedFileCount(), 0)
    }
}
