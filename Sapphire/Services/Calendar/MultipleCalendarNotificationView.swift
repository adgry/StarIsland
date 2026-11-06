//
//  MultipleCalendarNotificationView.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2025-09-01.
//

import SwiftUI
import EventKit

struct MultipleCalendarNotificationView: View {
    let events: [EKEvent]
    let timeUntil: String

    @Environment(LiveActivityManager.self) private var liveActivityManager

    var body: some View {
        CalendarNotificationLayout(
            color: .red,
            systemImage: "calendar.badge.clock",
            category: "日历",
            onDismiss: { liveActivityManager.dismissCalendarNotification() },
            onSnooze: {
                liveActivityManager.snoozeCalendarNotification(
                    eventIDs: events.compactMap(\.eventIdentifier)
                )
            }
        ) {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(events.count) 个日程")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.96))

                Text("\(timeUntil)开始")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))

                if let firstEvent = events.first {
                    Text("下一个：\((firstEvent.title?.isEmpty == false ? firstEvent.title : nil) ?? "无标题日程")")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.48))
                        .lineLimit(1)
                }
            }
        }
    }
}