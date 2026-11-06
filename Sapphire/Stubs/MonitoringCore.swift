//
//  MonitoringCore.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2026-08-30

#if !SAPPHIRE_FULL_BUILD
import Foundation
import SwiftUI

enum MonitorType: String, Codable, CaseIterable {
    case screen, audio, location, calendar, contacts

    var displayName: String {
        switch self {
        case .screen: return "屏幕"
        case .audio: return "音频"
        case .location: return "位置"
        case .calendar: return "日历"
        case .contacts: return "通讯录"
        }
    }
    var icon: String { "circle.dashed" }
}

struct DataSummary {
    var totalDataPoints: Int = 0
    var countsByMonitorType: [String: Int] = [:]
    var oldestEntry: Date?
    var newestEntry: Date?
    var databaseSizeMB: Double = 0
}

final class MemorySystemManager {
    static let shared = MemorySystemManager()
    private init() {}

    func getDataSummary() throws -> DataSummary { DataSummary() }
}

struct IntelligenceSettingsView: View {
    var body: some View {
        Text("当前构建版本未包含智能功能。")
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#endif