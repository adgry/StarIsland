//
//  FocusWidgetView.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2026-08-25
//

import AppKit
import SwiftUI

struct FocusWidgetView: View {
    @EnvironmentObject private var focusManager: FocusSessionManager
    @ObservedSettings private var settings: SettingsObserver
    @Environment(\.navigationStack) private var navigationStack

    private var accent: Color { focusManager.isFocusBlock ? .green : .orange }
    private var accentColors: [Color] {
        focusManager.isFocusBlock ? [.green, .mint, .teal] : [.orange, .yellow, .pink]
    }

    private var phaseLabel: String {
        if focusManager.isPaused { return "已暂停" }
        return focusManager.isFocusBlock ? "专注中" : "休息中"
    }

    private var blockedCount: Int {
        guard focusManager.isBlockingActive else { return 0 }
        return settings.settings.focusBlockedApps.count + settings.settings.focusBlockedWebsites.count
    }

    var body: some View {
        Button {
            Task {
                try? await Task.sleep(for: .seconds(NotchConfiguration.primaryWidgetSwitchDelay))
                navigationStack.wrappedValue.append(NotchWidgetMode.focusSessionDetailView)
            }
        } label: {
            ZStack {
                HStack(alignment: .center, spacing: 10) {
                    primaryInfo.layoutPriority(1)
                    secondaryInfo
                }
                .padding(.horizontal, 10)
            }
        }
        .buttonStyle(.plain)
        .frame(minWidth: 200, minHeight: 90)
        .fixedSize()
        .foregroundColor(.white)
        .preferredColorScheme(.dark)
        .contentShape(Rectangle())
        .animation(.default, value: focusManager.phase)
    }

    // MARK: - Primary readout

    @ViewBuilder
    private var primaryInfo: some View {
        HStack(spacing: 8) {
            if focusManager.isSessionActive {
                FocusWidgetTimerRing(
                    focusManager: focusManager,
                    accent: accent,
                    accentColors: accentColors
                )
            } else {
                Image(systemName: "moon.fill")
                    .font(.system(size: 40))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(
                        LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .shadow(radius: 2)
            }

            VStack(alignment: .leading, spacing: 2) {
                Group {
                    if focusManager.isSessionActive {
                        FocusWidgetCountdownText(focusManager: focusManager)
                    } else {
                        Text("专注")
                    }
                }
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .animation(.easeInOut(duration: 0.4), value: focusManager.isSessionActive)

                Text(focusManager.isSessionActive ? phaseLabel : "准备开始专注")
                    .font(.headline).fontWeight(.medium).lineLimit(1).minimumScaleFactor(0.7)
                    .foregroundColor(focusManager.isSessionActive ? accent : .secondary)

                Text(focusManager.isSessionActive
                     ? (blockedCount > 0 ? "已屏蔽 \(blockedCount) 项干扰" : "未开启干扰屏蔽")
                     : "\(Int(settings.settings.focusSessionDuration / 60))分钟 · 今日 \(FocusSessionManager.format(focusManager.completedToday))")
                    .font(.subheadline).opacity(0.8).lineLimit(1).minimumScaleFactor(0.7)
            }
        }
    }

    // MARK: - Secondary stats (streak leads)

    private var secondaryInfo: some View {
        VStack(alignment: .trailing, spacing: 4) {
            streakRow
            CompactInfoRow(iconName: "sun.max.fill", value: FocusSessionManager.format(focusManager.completedToday))
            CompactInfoRow(
                iconName: focusManager.isSessionActive ? "square.stack.3d.up.fill" : "checkmark.seal.fill",
                value: focusManager.isSessionActive
                    ? "\(focusManager.blocksCompletedThisSession) 轮"
                    : "共 \(focusManager.history.count) 次"
            )
        }
        .animation(.easeInOut(duration: 0.4), value: focusManager.isSessionActive)
        .animation(.default, value: focusManager.currentStreak)
    }

    private var streakRow: some View {
        HStack(spacing: 5) {
            StreakFlame(size: 20, isActive: focusManager.currentStreak > 0)

            Text(streakText)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.orange)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .id(streakText)
        .transition(.opacity)
    }

    private var streakText: String {
        let s = focusManager.currentStreak
        return "连续 \(s) 天"
    }
}

@MainActor
private struct FocusWidgetTimerRing: View {
    @ObservedObject var focusManager: FocusSessionManager
    let accent: Color
    let accentColors: [Color]

    var body: some View {
        ZStack {
            LayerGradientProgressRing(
                motion: .focusBlock(focusManager),
                lineWidth: 4,
                colors: accentColors,
                shadowColor: accent.opacity(0.45),
                shadowRadius: 6,
                shadowIncludesTrack: true
            )
            Image(systemName: focusManager.isFocusBlock ? "figure.mind.and.body" : "cup.and.saucer.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(accent)
                .shadow(color: accent.opacity(0.45), radius: 6)
        }
        .frame(width: 44, height: 44)
    }
}

@MainActor
private struct FocusWidgetCountdownText: View {
    let focusManager: FocusSessionManager

    private static let font: NSFont = {
        let base = NSFont.systemFont(ofSize: 30, weight: .bold)
        guard let rounded = base.fontDescriptor.withDesign(.rounded) else { return base }
        return NSFont(descriptor: rounded, size: 30) ?? base
    }()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            LayerNumericText(
                text: FocusSessionManager.format(focusManager.remaining(at: context.date)),
                font: Self.font,
                color: .white
            )
        }
    }
}