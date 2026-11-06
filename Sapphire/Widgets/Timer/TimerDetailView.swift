//
//  TimerDetailView.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2025-09-26
//

import AppKit
import SwiftUI

struct TimerDetailView: View {
    @EnvironmentObject var timerManager: TimerManager
    @Binding var navigationStack: [NotchWidgetMode]

    @State private var selectedMinutes: Int = 15

    var body: some View {
        VStack(spacing: 16) {
            durationPickerSection
            sapphireTimersSection
            systemTimersSection
            systemStopwatchesSection

            if timerManager.activeTimers.isEmpty
                && timerManager.activeStopwatches.isEmpty
                && timerManager.sapphireTimers.isEmpty {
                Text("暂无进行中的计时器或秒表")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            }
        }
        .padding()
        .frame(minWidth: 350)
        .animation(.default, value: timerManager.activeTimers.map(\.id))
        .animation(.default, value: timerManager.activeStopwatches.map(\.id))
        .animation(.default, value: timerManager.sapphireTimers.map(\.id))
    }

    // MARK: - Duration picker

    private var durationPickerSection: some View {
        VStack(spacing: 12) {
            TimerDurationRuler(minutes: $selectedMinutes, range: 1...120)
                .frame(height: 74)

            HStack(spacing: 12) {
                Button {
                    startTimer()
                } label: {
                    Text("开始计时")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 18)
                        .frame(height: 34)
                        .background(Capsule().fill(Color.orange.opacity(0.22)))
                        .foregroundColor(.orange)
                }
                .buttonStyle(TimerPillButtonStyle())

                Spacer()

                LayerNumericText(
                    text: String(format: "%d:00", selectedMinutes),
                    font: Self.pickerFont,
                    color: Self.pickerColor,
                    duration: 0.18
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private static let pickerFont: NSFont = {
        let base = NSFont.monospacedDigitSystemFont(ofSize: 40, weight: .light)
        guard let rounded = base.fontDescriptor.withDesign(.rounded) else { return base }
        return NSFont(descriptor: rounded, size: 40) ?? base
    }()

    private static let pickerColor = NSColor.notchResolved(.orange)

    private func startTimer() {
        let duration = TimeInterval(selectedMinutes * 60)
        _ = timerManager.startSapphireTimer(duration: duration)
    }

    // MARK: - Sapphire-Owned Timers

    @ViewBuilder
    private var sapphireTimersSection: some View {
        let timers = timerManager.sapphireTimers
        if !timers.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Sapphire 计时器")
                        .font(.title3.bold())
                        .foregroundColor(.orange)
                    Spacer()
                    if timers.contains(where: { $0.remainingTime <= 0 }) {
                        Button("清除已完成") {
                            timerManager.clearFinishedSapphireTimers()
                        }
                        .font(.caption)
                        .buttonStyle(.plain)
                        .foregroundColor(.orange)
                    }
                }

                ForEach(timers) { timer in
                    HStack {
                        Image(systemName: timer.isRunning ? "timer" : "timer.pause")
                            .foregroundColor(timer.isRunning ? .orange : .secondary)

                        SapphireTimerClockText(timer: timer)

                        Spacer()

                        if timer.remainingTime <= 0 {
                            Text("已完成")
                                .font(.caption)
                                .foregroundColor(.orange)
                        } else {
                            Text(timer.isRunning ? "运行中" : "已暂停")
                                .font(.caption)
                                .foregroundColor(timer.isRunning ? .orange : .secondary)
                        }

                        controls(for: timer)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func controls(for timer: SapphireTimer) -> some View {
        HStack(spacing: 6) {
            if timer.remainingTime <= 0 {
                controlButton("checkmark", accent: .orange) {
                    timerManager.clearFinishedSapphireTimers()
                }
            } else if timer.isRunning {
                controlButton("pause.fill", accent: .orange) {
                    timerManager.pauseSapphireTimer(id: timer.id)
                }
                controlButton("hourglass.badge.plus", accent: .orange) {
                    timerManager.addOneMinuteToSapphireTimer(id: timer.id)
                }
                .help("增加 1 分钟")
                controlButton("stop.fill", accent: .red) {
                    timerManager.removeSapphireTimer(id: timer.id)
                }
                .help("停止计时器")
            } else {
                controlButton("play.fill", accent: .green) {
                    timerManager.resumeSapphireTimer(id: timer.id)
                }
                controlButton("stop.fill", accent: .red) {
                    timerManager.removeSapphireTimer(id: timer.id)
                }
                .help("移除计时器")
            }
        }
    }

    private func controlButton(_ systemImage: String, accent: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 26, height: 26)
                .background(Circle().fill(accent.opacity(0.18)))
                .foregroundColor(accent)
        }
        .buttonStyle(.plain)
    }

    // MARK: - System Timers & Stopwatches (detected from the Clock app)

    @ViewBuilder
    private var systemTimersSection: some View {
        if !timerManager.activeTimers.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("计时器")
                    .font(.title3.bold())
                    .foregroundColor(.orange)
                ForEach(timerManager.activeTimers) { timer in
                    HStack {
                        Image(systemName: "timer")
                        SystemTimerClockText(timer: timer)
                        Spacer()
                        Text(timer.state == .system ? "运行中" : "已暂停")
                            .font(.caption)
                            .foregroundColor(timer.state == .system ? .orange : .secondary)
                    }
                    .font(.system(.body, design: .monospaced).weight(.medium))
                    .buttonStyle(.plain)
                    .font(.title3)
                }
            }
        }
    }

    @ViewBuilder
    private var systemStopwatchesSection: some View {
        if !timerManager.activeStopwatches.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("秒表")
                    .font(.title3.bold())
                    .foregroundColor(.green)
                ForEach(timerManager.activeStopwatches) { stopwatch in
                    VStack(alignment: .leading) {
                        HStack {
                            Image(systemName: "stopwatch")
                            SystemStopwatchClockText(stopwatch: stopwatch)
                            Spacer()
                            Text(stopwatch.state == .stopwatch ? "运行中" : "已暂停")
                                .font(.caption)
                                .foregroundColor(stopwatch.state == .stopwatch ? .green : .secondary)
                        }
                        .font(.system(.body, design: .monospaced).weight(.medium))
                        .font(.title3)

                        if !stopwatch.laps.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(stopwatch.laps.indices.reversed(), id: \.self) { index in
                                    HStack {
                                        Text("计次 \(index + 1)")
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text(stopwatch.laps[index].asStopwatchClock)
                                    }
                                    .font(.system(.callout, design: .monospaced))
                                }
                            }
                            .padding(.leading, 28)
                            .padding(.top, 4)
                        }
                    }
                }
            }
        }
    }
}

private struct TimerClockLabel: View {
    let text: String
    let font: NSFont

    static let titleFont = NSFont.monospacedSystemFont(ofSize: NSFont.preferredFont(forTextStyle: .title3).pointSize, weight: .medium)
    static let bodyFont = NSFont.monospacedSystemFont(ofSize: NSFont.preferredFont(forTextStyle: .body).pointSize, weight: .medium)

    var body: some View {
        LayerNumericText(text: text, font: font, color: TimerActivityView.primaryTextColor)
    }
}

private struct SapphireTimerClockText: View {
    let timer: SapphireTimer

    var body: some View {
        if timer.isRunning {
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                clock(timer.remainingTime)
            }
        } else {
            clock(timer.remainingTime)
        }
    }

    private func clock(_ value: TimeInterval) -> some View {
        TimerClockLabel(text: value.asStopwatchClock, font: TimerClockLabel.titleFont)
    }
}

private struct SystemTimerClockText: View {
    let timer: SystemTimerInfo

    var body: some View {
        if timer.state == .system {
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                clock(timer.remainingTime)
            }
        } else {
            clock(timer.remainingTime)
        }
    }

    private func clock(_ value: TimeInterval) -> some View {
        TimerClockLabel(text: value.asStopwatchClock, font: TimerClockLabel.bodyFont)
    }
}

private struct SystemStopwatchClockText: View {
    let stopwatch: SystemStopwatchInfo

    var body: some View {
        if stopwatch.state == .stopwatch {
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                clock(stopwatch.elapsedTime)
            }
        } else {
            clock(stopwatch.elapsedTime)
        }
    }

    private func clock(_ value: TimeInterval) -> some View {
        TimerClockLabel(text: value.asStopwatchClock, font: TimerClockLabel.bodyFont)
    }
}