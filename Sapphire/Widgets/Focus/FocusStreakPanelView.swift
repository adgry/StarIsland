//
//  FocusStreakPanelView.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2026-08-30
//

import SwiftUI

struct StreakFlame: View {
    var size: CGFloat = 20
    var isActive: Bool = true

    var body: some View {
        Image(systemName: "flame.fill")
            .font(.system(size: size * 0.62, weight: .semibold))
            .foregroundColor(isActive ? .orange : Color.white.opacity(0.2))
            .frame(width: size, height: size)
    }
}

@MainActor
struct FocusStreakPanelView: View {
    @EnvironmentObject var focusManager: FocusSessionManager
    var expanded: Bool = false

    @State private var immunityDate: Date = {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return cal.date(byAdding: .day, value: 3, to: today) ?? Date()
    }()
    @State private var confirmationText: String?

    private var snapshot: FocusStreakSnapshot { focusManager.streakSnapshot }

    private var earliestImmunity: Date {
        let cal = Calendar.current
        return cal.date(byAdding: .day, value: 3, to: cal.startOfDay(for: Date())) ?? Date()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            heroRow
            FocusStreakWeekStrip(days: 7, showLetters: false)
                .environmentObject(focusManager)
            if !expanded {
                stripLegend
            } else {
                Divider().overlay(Color.white.opacity(0.08))
                immunitySection
            }
            Divider().overlay(Color.white.opacity(0.08))
            passesRow
            if snapshot.canRestore {
                reviveRow
            }
        }
        .padding(12)
        .background(panelBackground)
    }

    // MARK: - Hero: big streak

    private var heroRow: some View {
        HStack(spacing: 14) {
            StreakFlame(size: 42, isActive: snapshot.streak > 0)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(snapshot.streak)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("天")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.55))
                }
                Text("专注连续打卡")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            Spacer()
        }
        .animation(.default, value: snapshot.streak)
    }

    private var stripLegend: some View {
        HStack(spacing: 12) {
            legendItem(icon: "flame.fill", color: .orange, label: "已专注")
            legendItem(icon: "shield.fill", color: .teal, label: "免签保护")
            legendItem(icon: "circle.fill", color: .white.opacity(0.12), label: "已漏签")
        }
        .padding(.top, 2)
    }

    private func legendItem(icon: String, color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    // MARK: - Passes

    private var passesRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "ticket.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.purple)
                Text("补签卡")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
                Text("本月剩余 \(snapshot.passesAvailableThisMonth) 张")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(snapshot.passesAvailableThisMonth > 0 ? .purple : .white.opacity(0.4))
            }

            passDots

            Text("\(snapshot.tierName) 用户每月可获 \(snapshot.passesBaseAllowance) 张免费补签卡，可用于恢复中断的连续打卡。")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.45))
        }
    }

    private var passDots: some View {
        let total = snapshot.passesBaseAllowance
        let available = max(0, snapshot.passesAvailableThisMonth)
        return HStack(spacing: 5) {
            ForEach(0..<total, id: \.self) { i in
                Circle()
                    .fill(i < available ? Color.purple : Color.white.opacity(0.1))
                    .frame(width: 8, height: 8)
            }
        }
    }

    // MARK: - Revive a broken streak

    private var reviveRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("连续打卡已中断")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                    Text(brokenDayText)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                }
                Spacer()
            }

            Button(action: {
                if focusManager.restoreStreak() {
                    confirmationText = "连续打卡已恢复 "
                }
            }) {
                Label("使用补签卡恢复连续打卡", systemImage: "flame.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(Color.orange.opacity(0.28), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)

            if let confirmationText {
                Text(confirmationText)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.orange)
            }
        }
        .padding(10)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var brokenDayText: String {
        guard let day = snapshot.brokenDay,
              let date = Calendar.current.date(from: day) else { return "你在未设置免签保护的情况下漏掉了一天。" }
        return "漏签日期：" + date.formatted(date: .abbreviated, time: .omitted) + " — 可使用补签卡恢复。"
    }

    // MARK: - Immunity scheduling (expanded only)

    private var immunitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "shield.lefthalf.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.teal)
                Text("免签保护日")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
                Text("不限次数")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.teal)
            }
            Text("提前至少 3 天报备无法专注的日期，当天将不会中断你的连续打卡，次数不限。")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.45))

            HStack(spacing: 8) {
                DatePicker(
                    "免签保护日",
                    selection: $immunityDate,
                    in: earliestImmunity...Date.distantFuture,
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                Button(action: addImmunity) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 30, height: 26)
                        .background(Color.teal.opacity(0.3), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            if !snapshot.upcomingImmunityDays.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(focusManager.upcomingImmunityDays) { day in
                        HStack(spacing: 8) {
                            Circle().fill(Color.teal.opacity(0.6)).frame(width: 5, height: 5)
                            Text(Self.dateText(day.date))
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.75))
                            Spacer()
                            Button {
                                focusManager.removeImmunityDay(id: day.id)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color.teal.opacity(0.9))
                            }
                            .buttonStyle(.plain)
                            .help("移除此免签保护日")
                        }
                    }
                }
            } else {
                Text("暂无即将到来的免签保护日。")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }

    private func addImmunity() {
        if focusManager.scheduleImmunity(on: immunityDate) {
            immunityDate = earliestImmunity
            confirmationText = "已预约免签保护日 "
        }
    }

    private static func dateText(_ components: DateComponents) -> String {
        guard let date = Calendar.current.date(from: components) else { return "" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.white.opacity(0.03))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
    }
}

@MainActor
struct FocusStreakWeekStrip: View {
    @EnvironmentObject var focusManager: FocusSessionManager
    var days: Int = 7
    var showLetters: Bool = true

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE"
        return formatter
    }()

    private struct DayCell {
        let date: Date
        let covered: Bool
        let immunized: Bool
        let isToday: Bool
    }

    private var cells: [DayCell] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<max(1, days)).reversed().map { offset in
            let date = cal.date(byAdding: .day, value: -offset, to: today) ?? today
            return DayCell(
                date: date,
                covered: focusManager.isStreakCovered(date),
                immunized: focusManager.isImmunized(date),
                isToday: offset == 0
            )
        }
    }

    private var compact: Bool { days <= 7 }

    var body: some View {
        let cells = cells
        HStack(alignment: .top, spacing: compact ? 8 : 5) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                VStack(spacing: 3) {
                    ZStack {
                        Circle()
                            .fill(fillColor(for: cell))
                            .frame(width: compact ? 15 : 11, height: compact ? 15 : 11)
                            .overlay(
                                Circle()
                                    .stroke(cell.isToday ? Color.white : Color.white.opacity(0.15), lineWidth: 1.2)
                            )
                        if cell.immunized {
                            Image(systemName: "shield.fill")
                                .font(.system(size: compact ? 7 : 5, weight: .bold))
                                .foregroundColor(.teal)
                        } else if cell.covered {
                            Image(systemName: "flame.fill")
                                .font(.system(size: compact ? 7 : 5, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    if showLetters {
                        Text(weekdayLetter(for: cell.date))
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(cell.isToday ? .white : .white.opacity(0.35))
                    }
                }
            }
        }
    }

    private func fillColor(for cell: DayCell) -> Color {
        if cell.immunized { return Color.teal.opacity(0.3) }
        if cell.covered { return Color.orange.opacity(0.75) }
        return Color.white.opacity(0.08)
    }

    private func weekdayLetter(for date: Date) -> String {
        Self.weekdayFormatter.string(from: date)
    }
}