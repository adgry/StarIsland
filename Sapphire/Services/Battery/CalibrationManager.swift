//
//  CalibrationManager.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2025-10-23
//

import Foundation
import Combine

@MainActor
class CalibrationManager: ObservableObject {
    static let shared = CalibrationManager()

    enum State: CustomStringConvertible, Equatable {
        case idle
        case chargingToFull
        case holdingAtFull(timeRemaining: TimeInterval)
        case dischargingToLow
        case finalChargeToLimit
        case done
        case error(String)

        var description: String {
            switch self {
            case .idle: return "空闲"
            case .chargingToFull: return "第 1 步：充至 100%"
            case .holdingAtFull(let time): return "第 2 步：在 100% 保持（\(time.formattedInterval())）"
            case .dischargingToLow: return "第 3 步：放电至 10%"
            case .finalChargeToLimit: return "第 4 步：回充至原定上限"
            case .done: return "校准完成"
            case .error(let msg): return "错误：\(msg)"
            }
        }
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var progress: Double = 0.0

    let calibrationEventPublisher = PassthroughSubject<State, Never>()
    var isActive: Bool {
        switch state {
        case .idle, .done, .error: return false
        default: return true
        }
    }

    private let batteryManager = BatteryManager.shared
    private let batteryMonitor = BatteryMonitor.shared
    private let caffeineManager = CaffeineManager.shared
    private let settings = SettingsModel.shared

    private var cancellables = Set<AnyCancellable>()
    private var holdTimer: Timer?
    private var originalChargeLimit: Int = 80
    private let holdDuration: TimeInterval = 2 * 60 * 60

    private init() {}

    func start() {
        guard !isActive else {
            print("[CalibrationManager] Calibration is already active.")
            return
        }

        print("[CalibrationManager] Starting calibration cycle.")
        originalChargeLimit = settings.current.batteryChargeLimit

        if settings.current.preventSleepDuringCalibration {
            caffeineManager.start(forcePreventSleepInClamshell: true)
        }

        batteryMonitor.$currentState
            .sink { [weak self] _ in self?.evaluateNextStep() }
            .store(in: &cancellables)

        // Calibration needs a full charge, so hand the native limit back until it finishes.
        if NativeChargeLimit.sapphireOwnsLimit {
            Task { await NativeChargeLimit.release() }
        }

        transition(to: .chargingToFull)
    }

    func cancel() {
        print("[CalibrationManager] Calibration cancelled by user.")
        transition(to: .idle)
    }

    private func transition(to newState: State) {
        self.state = newState
        print("[CalibrationManager] Transitioning to state: \(newState.description)")
        calibrationEventPublisher.send(newState)

        switch newState {
        case .idle, .error, .done:
            resetToIdle()

        case .chargingToFull:
            progress = 0.0
            batteryManager.beginCalibrationCycle { [weak self] error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let error = error {
                        print("[CalibrationManager] Failed to start calibration: \(error.localizedDescription)")
                        self.transition(to: .error("无法启动校准：\(error.localizedDescription)"))
                    }
                }
            }

        case .holdingAtFull:
            holdTimer?.invalidate()
            holdTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.updateHoldTime()
                }
            }

        case .dischargingToLow:
            batteryManager.setDischarge(discharging: true, safetyFloor: 10, rechargeOnFloor: false, bypassSafetyFloor: false)

        case .finalChargeToLimit:
            batteryManager.setDischarge(discharging: false)
            batteryManager.enableCharging(true)
        }
    }

    private func evaluateNextStep() {
        guard let battery = batteryMonitor.currentState else { return }

        switch state {
        case .chargingToFull:
            progress = Double(battery.level) / 100.0
            if battery.level >= 100 && !battery.isCharging {
                transition(to: .holdingAtFull(timeRemaining: holdDuration))
            }

        case .dischargingToLow:
            progress = 1.0 - (Double(battery.level - 10) / 90.0)
            if battery.level <= 10 {
                transition(to: .finalChargeToLimit)
            }

        case .finalChargeToLimit:
            progress = Double(battery.level) / Double(originalChargeLimit)
            if battery.level >= originalChargeLimit {
                transition(to: .done)
            }

        default:
            break
        }
    }

    private func updateHoldTime() {
        if case .holdingAtFull(let timeRemaining) = state {
            let newTime = timeRemaining - 1
            if newTime <= 0 {
                holdTimer?.invalidate()
                transition(to: .dischargingToLow)
            } else {
                state = .holdingAtFull(timeRemaining: newTime)
                progress = 1.0 - (newTime / holdDuration)
            }
        }
    }

    private func resetToIdle() {
        cancellables.removeAll()
        holdTimer?.invalidate()
        holdTimer = nil

        caffeineManager.stopIfAutoStartedByBatteryDischarge()

        batteryManager.setDischarge(discharging: false)
        restoreChargePolicy()

        switch state {
        case .done, .error: break
        default: state = .idle
        }
        progress = 0.0
    }

    private func restoreChargePolicy() {
        let limit = originalChargeLimit
        Task { @MainActor in
            let mode = await batteryManager.currentChargeControlMode()
            switch mode {
            case .firmware:
                batteryManager.setChargeLimit(limit)
            case .adapter:
                batteryManager.enableCharging(true)
            case .legacy, .unsupported:
                if batteryManager.isAppleSilicon {
                    batteryManager.enableCharging(true)
                } else {
                    batteryManager.setChargeLimit(limit)
                }
            }
        }
    }
}

fileprivate extension TimeInterval {
    func formattedInterval() -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: self) ?? "00:00:00"
    }
}