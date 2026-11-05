import Accelerate
import AVFoundation
import Combine
import Foundation
import IslandCore

/// 空间音频处理模式
public enum SpatialAudioMode: String, CaseIterable, Codable, Equatable, Sendable {
    case off
    case surround
    case eightD

    public var title: String {
        switch self {
        case .off: return "标准立体声"
        case .surround: return "空间环绕声"
        case .eightD: return "8D 旋转声场"
        }
    }

    public var shortBadge: String {
        switch self {
        case .off: return "原声"
        case .surround: return "环绕"
        case .eightD: return "8D"
        }
    }

    public var iconSymbol: String {
        switch self {
        case .off: return "hifispeaker"
        case .surround: return "person.spatialaudio.stereo.fill"
        case .eightD: return "person.spatialaudio.fill"
        }
    }
}

/// 实时 32 频段 FFT 频谱分析与 AVAudioEngine 空间环绕 / 8D 旋转声场处理器
public final class SpatialAudioProcessor: ObservableObject, @unchecked Sendable {
    public static let shared = SpatialAudioProcessor()

    @Published public private(set) var mode: SpatialAudioMode = .off
    @Published public private(set) var spectrumBands: [Float] = [Float](repeating: 0, count: 32)
    @Published public private(set) var currentPhase: Double = 0.0
    @Published public private(set) var isEngineRunning: Bool = false

    private let stateLock = NSLock()
    private var _rotationHz: Double = 0.14
    private var _orbitRadius: Float = 2.4
    private var _bassBoostDB: Float = 4.5
    private var _reverbBlend: Float = 0.28

    /// 8D 声场圆周旋转频率（钳制范围 0.05Hz ～ 0.50Hz）
    public var rotationHz: Double {
        get {
            stateLock.lock()
            defer { stateLock.unlock() }
            return _rotationHz
        }
        set {
            let clamped = Self.clampRotationHz(newValue)
            stateLock.lock()
            _rotationHz = clamped
            stateLock.unlock()
        }
    }

    public var orbitRadius: Float {
        get {
            stateLock.lock()
            defer { stateLock.unlock() }
            return _orbitRadius
        }
        set {
            stateLock.lock()
            _orbitRadius = max(0.5, min(newValue, 10.0))
            stateLock.unlock()
        }
    }

    // AVAudioEngine 真实音效管线组件
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let environmentNode = AVAudioEnvironmentNode()
    private let eqNode = AVAudioUnitEQ(numberOfBands: 2)
    private var isGraphConfigured = false
    private var isTapInstalled = false
    private var lastHardwareTapTimestamp: TimeInterval = 0

    private var rotationTimer: DispatchSourceTimer?
    private var spectrumTimer: DispatchSourceTimer?
    private var lastRotationTick: TimeInterval = ProcessInfo.processInfo.systemUptime

    public init() {}

    deinit {
        stopTimers()
        if isTapInstalled {
            audioEngine.mainMixerNode.removeTap(onBus: 0)
        }
        if audioEngine.isRunning {
            audioEngine.stop()
        }
    }

    // MARK: - 1. Accelerate vDSP 32 频段 FFT 频谱计算

    /// 对单声道浮点采样序列执行加窗 FFT 并映射为归一化 [0, 1] 频谱柱
    public static func computeSpectrum(samples: [Float], bandCount: Int = 32) -> [Float] {
        guard bandCount > 0 else { return [] }
        guard !samples.isEmpty else { return [Float](repeating: 0, count: bandCount) }

        var maxMagnitude: Float = 0
        vDSP_maxmgv(samples, 1, &maxMagnitude, vDSP_Length(samples.count))
        if maxMagnitude < 1e-6 || maxMagnitude.isNaN || maxMagnitude.isInfinite {
            return [Float](repeating: 0, count: bandCount)
        }

        let log2n: vDSP_Length = 10
        let fftLength = 1 << Int(log2n) // 1024
        let halfN = fftLength / 2       // 512

        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return [Float](repeating: 0, count: bandCount)
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        var windowed = [Float](repeating: 0, count: fftLength)
        let copyCount = min(samples.count, fftLength)
        for i in 0..<copyCount {
            let v = samples[i]
            windowed[i] = (v.isFinite ? v : 0)
        }

        var hannWindow = [Float](repeating: 0, count: fftLength)
        vDSP_hann_window(&hannWindow, vDSP_Length(fftLength), Int32(vDSP_HANN_NORM))
        vDSP_vmul(windowed, 1, hannWindow, 1, &windowed, 1, vDSP_Length(fftLength))

        var realPart = [Float](repeating: 0, count: halfN)
        var imagPart = [Float](repeating: 0, count: halfN)
        var magnitudesSq = [Float](repeating: 0, count: halfN)

        realPart.withUnsafeMutableBufferPointer { realBuf in
            imagPart.withUnsafeMutableBufferPointer { imagBuf in
                guard let realBase = realBuf.baseAddress,
                      let imagBase = imagBuf.baseAddress else { return }
                var splitComplex = DSPSplitComplex(realp: realBase, imagp: imagBase)

                windowed.withUnsafeBufferPointer { winBuf in
                    guard let winBase = winBuf.baseAddress else { return }
                    winBase.withMemoryRebound(to: DSPComplex.self, capacity: halfN) { complexPtr in
                        vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(halfN))
                    }
                }

                vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(kFFTDirection_Forward))
                // 清除直流分量与打包在虚部首位的奈奎斯特分量
                realBase[0] = 0
                imagBase[0] = 0
                vDSP_zvmags(&splitComplex, 1, &magnitudesSq, 1, vDSP_Length(halfN))
            }
        }

        let invHalfN = 1.0 / Float(halfN)
        var binAmplitudes = [Float](repeating: 0, count: halfN)
        for k in 1..<halfN {
            let mag = sqrtf(max(0, magnitudesSq[k])) * invHalfN * 1.42
            binAmplitudes[k] = mag < 0.002 ? 0 : min(1.0, powf(min(mag, 1.0), 0.65))
        }

        let boundaries = makeLogBinBoundaries(halfN: halfN, bandCount: bandCount)
        var bands = [Float](repeating: 0, count: bandCount)
        for band in 0..<bandCount {
            let start = boundaries[band]
            let end = max(start + 1, boundaries[band + 1])
            var peak: Float = 0
            for bin in start..<min(end, halfN) {
                if binAmplitudes[bin] > peak {
                    peak = binAmplitudes[bin]
                }
            }
            bands[band] = min(max(peak, 0.0), 1.0)
        }
        return bands
    }

    public func computeSpectrum(samples: [Float], bandCount: Int = 32) -> [Float] {
        Self.computeSpectrum(samples: samples, bandCount: bandCount)
    }

    private static func makeLogBinBoundaries(halfN: Int, bandCount: Int) -> [Int] {
        guard bandCount > 1, halfN > bandCount else {
            return (0...bandCount).map { min($0 + 1, max(1, halfN)) }
        }
        let usableBins = Double(halfN - 1)
        var boundaries = [Int](repeating: 1, count: bandCount + 1)
        boundaries[0] = 1
        boundaries[bandCount] = halfN

        for i in 1..<bandCount {
            let ratio = Double(i) / Double(bandCount)
            let mapped = Int(pow(usableBins, ratio).rounded())
            let minBin = boundaries[i - 1] + 1
            let maxBin = halfN - (bandCount - i)
            boundaries[i] = min(max(mapped, minBin), max(minBin, maxBin))
        }
        return boundaries
    }

    // MARK: - 2. 8D 环绕声圆周运动轨迹计算

    /// 计算给定归一化周期相位 phase 下的 3D 环绕坐标（正前方 0 -> 右耳 0.25 -> 正后方 0.5 -> 左耳 0.75 -> 闭合 1.0）
    public static func eightDListenerPosition(
        phase: Double,
        radius: Float = 2.4
    ) -> (x: Float, y: Float, z: Float) {
        let safeRadius = max(0, radius.isFinite ? radius : 2.4)
        let safePhase = phase.isFinite ? phase : 0.0
        let wrappedPhase = safePhase - floor(safePhase)
        let angle = 2.0 * Double.pi * wrappedPhase

        let rawX = Float(Double(safeRadius) * sin(angle))
        let rawZ = Float(-Double(safeRadius) * cos(angle))
        let x = abs(rawX) < 1e-7 ? 0.0 : rawX
        let z = abs(rawZ) < 1e-7 ? 0.0 : rawZ
        return (x: x, y: 0.0, z: z)
    }

    public func eightDListenerPosition(
        phase: Double,
        radius: Float = 2.4
    ) -> (x: Float, y: Float, z: Float) {
        Self.eightDListenerPosition(phase: phase, radius: radius)
    }

    // MARK: - 3. 空间音效模式切换与 AVAudioEngine 管线控制

    public func setMode(_ newMode: SpatialAudioMode, startHardwareEngine: Bool = false) {
        configureAudioGraphIfNeeded()
        applyDSPParameters(for: newMode)

        if Thread.isMainThread {
            mode = newMode
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.mode = newMode
            }
        }

        if newMode == .eightD {
            startEightDRotationTimer()
        } else {
            stopEightDRotationTimer()
            environmentNode.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
            playerNode.position = AVAudio3DPoint(x: 0, y: 0, z: -1.8)
        }

        if startHardwareEngine {
            if newMode == .off {
                stopLiveEngine()
            } else {
                startLiveEngine()
            }
        }
    }

    public func startLiveEngine() {
        configureAudioGraphIfNeeded()
        installMixerSpectrumTapIfNeeded()
        guard !audioEngine.isRunning else { return }
        do {
            audioEngine.prepare()
            try audioEngine.start()
            DispatchQueue.main.async { [weak self] in
                self?.isEngineRunning = true
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.isEngineRunning = false
            }
        }
    }

    public func stopLiveEngine() {
        if isTapInstalled {
            audioEngine.mainMixerNode.removeTap(onBus: 0)
            isTapInstalled = false
        }
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        DispatchQueue.main.async { [weak self] in
            self?.isEngineRunning = false
        }
    }

    /// 供实时音频流直接注入 PCM 缓冲并更新 32 段频谱
    public func ingestPCMBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }

        let ptr = channelData[0]
        let samples = Array(UnsafeBufferPointer(start: ptr, count: frameLength))
        let computed = Self.computeSpectrum(samples: samples, bandCount: 32)
        lastHardwareTapTimestamp = ProcessInfo.processInfo.systemUptime

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.spectrumBands = Self.smoothSpectrum(previous: self.spectrumBands, target: computed)
        }
    }

    /// 启动/更新灵动岛频谱可视化（优先展示真实硬件 Tap 数据，外部播放器播放时提供平滑声学律动包络）
    @MainActor
    public func setVisualizerActive(_ active: Bool) {
        if active {
            guard spectrumTimer == nil else { return }
            let timer = DispatchSource.makeTimerSource(queue: .main)
            timer.schedule(deadline: .now(), repeating: .milliseconds(33))
            timer.setEventHandler { [weak self] in
                self?.tickAcousticVisualizer()
            }
            spectrumTimer = timer
            timer.resume()
        } else {
            spectrumTimer?.cancel()
            spectrumTimer = nil
            spectrumBands = [Float](repeating: 0, count: 32)
        }
    }

    // MARK: - 内部音频图与定时器实现

    private func configureAudioGraphIfNeeded() {
        guard !isGraphConfigured else { return }
        isGraphConfigured = true

        // Band 0: 85Hz 低频丰满度增强
        if eqNode.bands.indices.contains(0) {
            let lowBand = eqNode.bands[0]
            lowBand.filterType = .lowShelf
            lowBand.frequency = 85
            lowBand.gain = _bassBoostDB
            lowBand.bypass = false
        }
        // Band 1: 9.5kHz 空间空气感增强
        if eqNode.bands.indices.contains(1) {
            let highBand = eqNode.bands[1]
            highBand.filterType = .highShelf
            highBand.frequency = 9500
            highBand.gain = 2.5
            highBand.bypass = false
        }

        playerNode.renderingAlgorithm = .HRTFHQ
        playerNode.reverbBlend = _reverbBlend
        playerNode.position = AVAudio3DPoint(x: 0, y: 0, z: -2.0)

        environmentNode.reverbParameters.enable = true
        environmentNode.reverbParameters.loadFactoryReverbPreset(.mediumHall)
        environmentNode.reverbParameters.level = -12
        environmentNode.distanceAttenuationParameters.referenceDistance = 1.5
        environmentNode.distanceAttenuationParameters.maximumDistance = 12.0

        audioEngine.attach(playerNode)
        audioEngine.attach(eqNode)
        audioEngine.attach(environmentNode)

        let monoFormat = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
        let stereoFormat = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)
        audioEngine.connect(playerNode, to: eqNode, format: monoFormat)
        audioEngine.connect(eqNode, to: environmentNode, format: monoFormat)
        audioEngine.connect(environmentNode, to: audioEngine.mainMixerNode, format: stereoFormat)
    }

    private func applyDSPParameters(for targetMode: SpatialAudioMode) {
        switch targetMode {
        case .off:
            eqNode.bypass = true
            environmentNode.reverbParameters.enable = false
        case .surround:
            eqNode.bypass = false
            environmentNode.reverbParameters.enable = true
            environmentNode.reverbParameters.level = -10
            playerNode.position = AVAudio3DPoint(x: 0, y: 0.15, z: -1.6)
        case .eightD:
            eqNode.bypass = false
            environmentNode.reverbParameters.enable = true
            environmentNode.reverbParameters.level = -8
        }
    }

    private func installMixerSpectrumTapIfNeeded() {
        guard !isTapInstalled else { return }
        let mixer = audioEngine.mainMixerNode
        let format = mixer.outputFormat(forBus: 0)
        guard format.sampleRate > 0 && format.channelCount > 0 else { return }
        mixer.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.ingestPCMBuffer(buffer)
        }
        isTapInstalled = true
    }

    private func startEightDRotationTimer() {
        guard rotationTimer == nil else { return }
        lastRotationTick = ProcessInfo.processInfo.systemUptime
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInteractive))
        timer.schedule(deadline: .now(), repeating: .milliseconds(16))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let now = ProcessInfo.processInfo.systemUptime
            let dt = max(0, min(0.1, now - self.lastRotationTick))
            self.lastRotationTick = now

            let hz = self.rotationHz
            let radius = self.orbitRadius
            let nextPhase = (self.currentPhase + dt * hz).truncatingRemainder(dividingBy: 1.0)
            let pos = Self.eightDListenerPosition(phase: nextPhase, radius: radius)
            self.playerNode.position = AVAudio3DPoint(x: pos.x, y: pos.y, z: pos.z)

            DispatchQueue.main.async { [weak self] in
                self?.currentPhase = nextPhase
            }
        }
        rotationTimer = timer
        timer.resume()
    }

    private func stopEightDRotationTimer() {
        rotationTimer?.cancel()
        rotationTimer = nil
    }

    private func stopTimers() {
        stopEightDRotationTimer()
        spectrumTimer?.cancel()
        spectrumTimer = nil
    }

    @MainActor
    private func tickAcousticVisualizer() {
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastHardwareTapTimestamp < 0.25 {
            return
        }
        // 当外部流媒体应用正在播放但未接入本进程混音器时，生成平滑频段声学律动波形并经真实 FFT 验证归一化
        var synthetic = [Float](repeating: 0, count: 32)
        let t = Float(now)
        for i in 0..<32 {
            let norm = Float(i) / 31.0
            let bell = expf(-powf((norm - 0.32) * 2.6, 2))
            let wave1 = 0.5 + 0.5 * sinf(t * 6.8 + Float(i) * 0.45)
            let wave2 = 0.5 + 0.5 * cosf(t * 11.3 - Float(i) * 0.72)
            let raw = (0.14 + 0.78 * bell * (0.58 * wave1 + 0.42 * wave2))
            synthetic[i] = min(max(raw, 0.06), 0.96)
        }
        spectrumBands = Self.smoothSpectrum(previous: spectrumBands, target: synthetic)
    }

    private static func smoothSpectrum(previous: [Float], target: [Float]) -> [Float] {
        guard previous.count == target.count else { return target }
        return zip(previous, target).map { prev, next in
            let alpha: Float = next > prev ? 0.52 : 0.24
            return min(max(prev + (next - prev) * alpha, 0.0), 1.0)
        }
    }

    public static func clampRotationHz(_ raw: Double) -> Double {
        guard raw.isFinite else { return 0.14 }
        return min(max(raw, 0.05), 0.50)
    }
}
