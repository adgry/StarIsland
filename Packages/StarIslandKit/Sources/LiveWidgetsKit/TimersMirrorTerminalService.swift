import AppKit
@preconcurrency import AVFoundation
import Combine
import Foundation
import IslandCore
import Network
import SwiftUI

// MARK: - 1. 多路计时器、秒表、番茄钟与 20-20-20 护眼提醒

public struct CountdownTimerItem: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public var title: String
    public var totalSeconds: TimeInterval
    public var remainingSeconds: TimeInterval
    public var isRunning: Bool
    public var isPomodoro: Bool

    public var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return min(1.0, max(0.0, 1.0 - (remainingSeconds / totalSeconds)))
    }

    public var formattedRemaining: String { Self.formatClock(remainingSeconds) }

    public static func formatClock(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        let hours = total / 3600, minutes = (total % 3600) / 60, seconds = total % 60
        return hours > 0
            ? String(format: "%02d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%02d:%02d", minutes, seconds)
    }

    public init(
        id: UUID = UUID(), title: String, totalSeconds: TimeInterval,
        remainingSeconds: TimeInterval? = nil, isRunning: Bool = true, isPomodoro: Bool = false
    ) {
        self.id = id; self.title = title
        self.totalSeconds = max(1, totalSeconds)
        self.remainingSeconds = remainingSeconds ?? max(1, totalSeconds)
        self.isRunning = isRunning; self.isPomodoro = isPomodoro
    }
}

@MainActor
public final class TimersEyeBreakManager: ObservableObject {
    public static let shared = TimersEyeBreakManager()

    @Published public private(set) var timers: [CountdownTimerItem] = []
    @Published public private(set) var stopwatchSeconds: TimeInterval = 0
    @Published public private(set) var isStopwatchRunning: Bool = false
    @Published public private(set) var secondsUntilEyeBreak: TimeInterval = 1200
    @Published public private(set) var eyeBreakRemainingSeconds: Int = 0

    private let settingsStore: SettingsStore
    private let stateMachine: IslandStateMachine
    private var tickTask: Task<Void, Never>?

    public init(
        settingsStore: SettingsStore? = nil,
        stateMachine: IslandStateMachine? = nil
    ) {
        self.settingsStore = settingsStore ?? .shared
        self.stateMachine = stateMachine ?? .shared
        let intervalMinutes = max(5, self.settingsStore.settings.eyeBreakIntervalMinutes)
        self.secondsUntilEyeBreak = TimeInterval(intervalMinutes * 60)
    }

    public var formattedStopwatch: String {
        CountdownTimerItem.formatClock(stopwatchSeconds)
    }

    public func startCountdown(title: String, seconds: TimeInterval, isPomodoro: Bool = false) {
        let item = CountdownTimerItem(title: title, totalSeconds: seconds, isRunning: true, isPomodoro: isPomodoro)
        timers.insert(item, at: 0)
        ensureTickLoopRunning()
        syncTimersToIsland()
    }

    public func startPomodoro(minutes: Int = 25) {
        startCountdown(title: "番茄专注 \(minutes)分钟", seconds: TimeInterval(minutes * 60), isPomodoro: true)
    }

    public func toggleTimer(id: UUID) {
        guard let idx = timers.firstIndex(where: { $0.id == id }) else { return }
        timers[idx].isRunning.toggle()
        ensureTickLoopRunning()
        syncTimersToIsland()
    }

    public func removeTimer(id: UUID) {
        timers.removeAll { $0.id == id }
        stateMachine.dismiss(id: "timer.\(id.uuidString)")
        syncTimersToIsland()
    }

    public func toggleStopwatch() {
        isStopwatchRunning.toggle()
        ensureTickLoopRunning()
        syncTimersToIsland()
    }

    public func resetStopwatch() {
        isStopwatchRunning = false
        stopwatchSeconds = 0
        stateMachine.dismiss(id: "timer.stopwatch")
    }

    public func triggerEyeBreakNow() {
        eyeBreakRemainingSeconds = 20
        ensureTickLoopRunning()
        presentEyeBreakActivity()
    }

    public func startEyeBreakMonitorIfNeeded() {
        let mins = max(5, settingsStore.settings.eyeBreakIntervalMinutes)
        secondsUntilEyeBreak = TimeInterval(mins * 60)
        ensureTickLoopRunning()
    }

    private func ensureTickLoopRunning() {
        guard tickTask == nil else { return }
        tickTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { break }
                self.handleSecondTick()
                if !self.hasActiveWork {
                    self.tickTask = nil
                    break
                }
            }
        }
    }

    private var hasActiveWork: Bool {
        timers.contains(where: \.isRunning)
            || isStopwatchRunning
            || eyeBreakRemainingSeconds > 0
            || settingsStore.settings.enableEyeBreakReminder
    }

    private func handleSecondTick() {
        var finishedItems: [CountdownTimerItem] = []
        for idx in timers.indices where timers[idx].isRunning {
            timers[idx].remainingSeconds = max(0, timers[idx].remainingSeconds - 1)
            if timers[idx].remainingSeconds <= 0 {
                timers[idx].isRunning = false
                finishedItems.append(timers[idx])
            }
        }

        for done in finishedItems {
            timers.removeAll { $0.id == done.id }
            stateMachine.dismiss(id: "timer.\(done.id.uuidString)")
            NSSound.beep()
            stateMachine.submit(
                IslandActivityItem(
                    id: "timer.done.\(done.id.uuidString)",
                    category: .timer,
                    title: "\(done.title) 时间到",
                    subtitle: done.isPomodoro ? "已完成一轮番茄钟，起身休息一下吧" : "倒计时已顺利结束",
                    iconSymbol: "bell.and.waves.left.and.right.fill",
                    trailingBadge: "完成",
                    priority: .urgent,
                    isPeek: true,
                    allowsOnLockScreen: true,
                    autoDismissAfter: 5.0
                )
            )
        }

        if isStopwatchRunning {
            stopwatchSeconds += 1
        }

        if eyeBreakRemainingSeconds > 0 {
            eyeBreakRemainingSeconds -= 1
            if eyeBreakRemainingSeconds > 0 {
                presentEyeBreakActivity()
            } else {
                stateMachine.dismiss(id: "timer.eyebreak")
                let mins = max(5, settingsStore.settings.eyeBreakIntervalMinutes)
                secondsUntilEyeBreak = TimeInterval(mins * 60)
            }
        } else if settingsStore.settings.enableEyeBreakReminder {
            secondsUntilEyeBreak = max(0, secondsUntilEyeBreak - 1)
            if secondsUntilEyeBreak <= 0 {
                eyeBreakRemainingSeconds = 20
                presentEyeBreakActivity()
            }
        }

        syncTimersToIsland()
    }

    private func presentEyeBreakActivity() {
        stateMachine.submit(
            IslandActivityItem(
                id: "timer.eyebreak",
                category: .timer,
                title: "20-20-20 护眼休息",
                subtitle: "请望向 6 米（20 英尺）远处放松双眼 · 剩余 \(eyeBreakRemainingSeconds) 秒",
                iconSymbol: "eye.circle.fill",
                trailingBadge: "\(eyeBreakRemainingSeconds)s",
                progress: Double(20 - eyeBreakRemainingSeconds) / 20.0,
                priority: .ambient,
                isPeek: eyeBreakRemainingSeconds >= 17,
                allowsOnLockScreen: false
            )
        )
    }

    private func syncTimersToIsland() {
        if let active = timers.first(where: \.isRunning) {
            stateMachine.submit(
                IslandActivityItem(
                    id: "timer.\(active.id.uuidString)",
                    category: .timer,
                    title: active.title,
                    subtitle: "剩余 \(active.formattedRemaining)",
                    iconSymbol: active.isPomodoro ? "timer.circle.fill" : "timer",
                    trailingBadge: active.formattedRemaining,
                    progress: active.progress,
                    priority: .ongoing,
                    allowsOnLockScreen: true
                )
            )
        }

        if isStopwatchRunning {
            stateMachine.submit(
                IslandActivityItem(
                    id: "timer.stopwatch",
                    category: .timer,
                    title: "秒表计时中",
                    subtitle: formattedStopwatch,
                    iconSymbol: "stopwatch.fill",
                    trailingBadge: formattedStopwatch,
                    priority: .ongoing,
                    allowsOnLockScreen: true
                )
            )
        } else {
            stateMachine.dismiss(id: "timer.stopwatch")
        }
    }
}

// MARK: - 2. 高清圆角随身镜（AVCaptureSession + 镜像翻转 + 环形柔光补光）

@MainActor
public final class PocketMirrorController: ObservableObject {
    public static let shared = PocketMirrorController()

    @Published public private(set) var isActive: Bool = false
    @Published public var isMirrored: Bool = true
    @Published public var isRingLightEnabled: Bool = false
    @Published public var useWarmLight: Bool = true
    @Published public private(set) var errorMessage: String?

    public let captureSession = AVCaptureSession()
    private var isConfigured = false
    private let sessionQueue = DispatchQueue(label: "com.adgry.starisland.pocketmirror")

    public init() {}

    public func startMirror() async {
        guard !isActive else { return }
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if !granted {
                errorMessage = "未授予摄像头权限，请在系统设置中开启"
                return
            }
        } else if status != .authorized {
            errorMessage = "摄像头权限已关闭，请前往系统设置开启"
            return
        }

        if !isConfigured {
            guard configureSession() else { return }
            isConfigured = true
        }

        errorMessage = nil
        isActive = true
        let session = captureSession
        sessionQueue.async {
            if !session.isRunning {
                session.startRunning()
            }
        }
    }

    public func stopMirror() {
        guard isActive else { return }
        isActive = false
        let session = captureSession
        sessionQueue.async {
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    private func configureSession() -> Bool {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        captureSession.sessionPreset = .high

        let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            ?? AVCaptureDevice.default(for: .video)
        guard let camera = device else {
            errorMessage = "未检测到可用的前置摄像头"
            return false
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
            return true
        } catch {
            errorMessage = "初始化随身镜失败：\(error.localizedDescription)"
            return false
        }
    }
}

public final class MirrorPreviewHostView: NSView {
    let previewLayer: AVCaptureVideoPreviewLayer
    var isMirrored: Bool = true {
        didSet { applyMirrorTransform() }
    }

    init(session: AVCaptureSession) {
        self.previewLayer = AVCaptureVideoPreviewLayer(session: session)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = true
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layer?.addSublayer(previewLayer)
        applyMirrorTransform()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer.bounds = bounds
        previewLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        applyMirrorTransform()
        CATransaction.commit()
    }

    private func applyMirrorTransform() {
        previewLayer.transform = isMirrored
            ? CATransform3DMakeScale(-1, 1, 1)
            : CATransform3DIdentity
    }
}

public struct CameraMirrorPreviewRepresentable: NSViewRepresentable {
    public let session: AVCaptureSession
    public let isMirrored: Bool

    public init(session: AVCaptureSession, isMirrored: Bool) {
        self.session = session
        self.isMirrored = isMirrored
    }

    public func makeNSView(context: Context) -> MirrorPreviewHostView {
        let view = MirrorPreviewHostView(session: session)
        view.isMirrored = isMirrored
        return view
    }

    public func updateNSView(_ nsView: MirrorPreviewHostView, context: Context) {
        nsView.isMirrored = isMirrored
    }
}

// MARK: - 3. 终端耗时命令实时活动（Zsh Hook + 本地 UDP 监听）

public struct TerminalHookEvent: Codable, Equatable, Sendable {
    public let event: String
    public let id: String
    public let command: String
    public let exitCode: Int?
    public let duration: Int?

    public init(event: String, id: String, command: String, exitCode: Int? = nil, duration: Int? = nil) {
        self.event = event
        self.id = id
        self.command = command
        self.exitCode = exitCode
        self.duration = duration
    }
}

public enum TerminalShellHook {
    public static let defaultUDPPort: UInt16 = 48621

    public static var zshSnippet: String {
        """
        # >>> 星岛 StarIsland 终端实时活动 Hook >>>
        autoload -Uz add-zsh-hook
        _starisland_preexec() {
          _SI_CMD_START=$SECONDS
          _SI_CMD_ID="$$-$RANDOM"
          _SI_CMD_TEXT="${1//\\"/\\\\\\"}"
          ( sleep 5 && /usr/bin/nc -u -w 0 127.0.0.1 \(defaultUDPPort) <<< "{\\"event\\":\\"start\\",\\"id\\":\\"$_SI_CMD_ID\\",\\"command\\":\\"$_SI_CMD_TEXT\\"}" ) >/dev/null 2>&1 &!
          _SI_WATCH_PID=$!
        }
        _starisland_precmd() {
          local code=$?
          [[ -n "$_SI_WATCH_PID" ]] && kill "$_SI_WATCH_PID" >/dev/null 2>&1
          if [[ -n "$_SI_CMD_START" ]]; then
            local elapsed=$(( SECONDS - _SI_CMD_START ))
            if (( elapsed >= 5 )); then
              /usr/bin/nc -u -w 0 127.0.0.1 \(defaultUDPPort) <<< "{\\"event\\":\\"finish\\",\\"id\\":\\"$_SI_CMD_ID\\",\\"command\\":\\"$_SI_CMD_TEXT\\",\\"exitCode\\":$code,\\"duration\\":$elapsed}" >/dev/null 2>&1
            fi
          fi
          unset _SI_CMD_START _SI_CMD_ID _SI_CMD_TEXT _SI_WATCH_PID
        }
        add-zsh-hook preexec _starisland_preexec
        add-zsh-hook precmd _starisland_precmd
        # <<< 星岛 StarIsland 终端实时活动 Hook <<<
        """
    }

    public static func parseEvent(from data: Data) -> TerminalHookEvent? {
        let trimmed = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let cleanData = trimmed.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(TerminalHookEvent.self, from: cleanData)
    }
}

@MainActor
public final class TerminalActivityService: ObservableObject {
    public static let shared = TerminalActivityService()

    @Published public private(set) var runningCommands: [TerminalHookEvent] = []
    @Published public private(set) var lastFinishedEvent: TerminalHookEvent?

    private let settingsStore: SettingsStore
    private let stateMachine: IslandStateMachine
    private var listener: NWListener?
    private let listenerQueue = DispatchQueue(label: "com.adgry.starisland.terminal-udp")

    public init(
        settingsStore: SettingsStore? = nil,
        stateMachine: IslandStateMachine? = nil
    ) {
        self.settingsStore = settingsStore ?? .shared
        self.stateMachine = stateMachine ?? .shared
    }

    public func startListening(port: UInt16 = TerminalShellHook.defaultUDPPort) {
        guard listener == nil, let nwPort = NWEndpoint.Port(rawValue: port) else { return }
        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true
        params.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: nwPort)

        guard let udpListener = try? NWListener(using: params) else { return }
        udpListener.newConnectionHandler = { [weak self] connection in
            connection.start(queue: self?.listenerQueue ?? .global())
            connection.receiveMessage { data, _, _, _ in
                if let data, let event = TerminalShellHook.parseEvent(from: data) {
                    Task { @MainActor [weak self] in
                        self?.ingest(event)
                    }
                }
                connection.cancel()
            }
        }
        udpListener.start(queue: listenerQueue)
        self.listener = udpListener
    }

    public func stopListening() {
        listener?.cancel()
        listener = nil
    }

    public func ingest(_ event: TerminalHookEvent) {
        guard settingsStore.settings.enableTerminalLiveActivity else { return }
        let shortCmd = String(event.command.prefix(42))

        if event.event == "start" {
            if !runningCommands.contains(where: { $0.id == event.id }) {
                runningCommands.append(event)
            }
            stateMachine.submit(
                IslandActivityItem(
                    id: "terminal.run.\(event.id)",
                    category: .terminal,
                    title: "终端执行中 · \(shortCmd)",
                    subtitle: "正在后台运行耗时命令…",
                    iconSymbol: "terminal.fill",
                    trailingBadge: "运行中",
                    priority: .ongoing,
                    allowsOnLockScreen: false
                )
            )
        } else if event.event == "finish" {
            runningCommands.removeAll { $0.id == event.id }
            lastFinishedEvent = event
            stateMachine.dismiss(id: "terminal.run.\(event.id)")

            let code = event.exitCode ?? 0
            let succeeded = (code == 0)
            let secs = event.duration ?? 5
            stateMachine.submit(
                IslandActivityItem(
                    id: "terminal.done.\(event.id)",
                    category: .terminal,
                    title: succeeded ? "终端任务已完成 (\(secs)s)" : "终端任务失败 · 退出码 \(code)",
                    subtitle: shortCmd,
                    iconSymbol: succeeded ? "checkmark.rectangle.stack.fill" : "xmark.octagon.fill",
                    trailingBadge: succeeded ? "成功" : "退出 \(code)",
                    priority: .interactive,
                    isPeek: true,
                    autoDismissAfter: 4.5
                )
            )
        }
    }
}
