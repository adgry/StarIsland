//
//  CrossfadeOrchestrator.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2026-08-21

import AudioToolbox
import os

enum CrossfadeError: LocalizedError {
    case tapCreationFailed(OSStatus)
    case aggregateCreationFailed(OSStatus)
    case deviceNotReady
    case secondaryTapFailed
    case noTapDescription

    var errorDescription: String? {
        switch self {
        case .tapCreationFailed(let status):
            return "创建进程音频捕获失败：\(status)"
        case .aggregateCreationFailed(let status):
            return "创建聚合设备失败：\(status)"
        case .deviceNotReady:
            return "设备等待就绪超时"
        case .secondaryTapFailed:
            return "备用音频捕获在超时后无效"
        case .noTapDescription:
            return "无可用的音频捕获描述"
        }
    }
}

enum CrossfadeConfig {
    static let defaultDuration: TimeInterval = 0.050

    static var duration: TimeInterval {
        let custom = UserDefaults.standard.double(forKey: "SapphireCrossfadeDuration")
        return custom > 0 ? custom : defaultDuration
    }

    static func totalSamples(at sampleRate: Double) -> Int64 {
        max(1, Int64(sampleRate * duration))
    }
}