//
//  MicrophoneLiveActivityView.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2026-08-10

import SwiftUI

struct MicrophoneLiveActivityViewLeft: View {
    @ObservedObject private var mic = MicrophoneUsageManager.shared
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: mic.isMuted ? "mic.slash.fill" : "mic.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(mic.isMuted ? Color.red : Color.orange)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mic.isMuted ? "取消麦克风静音" : "将麦克风静音")
    }
}

struct MicrophoneLiveActivityViewRight: View {
    @ObservedObject private var mic = MicrophoneUsageManager.shared
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(mic.isMuted ? "已静音" : "使用中")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(mic.isMuted ? Color.red : Color.orange)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mic.isMuted ? "取消麦克风静音" : "将麦克风静音")
    }
}

struct MicrophoneLiveActivityView {
    static func left(action: @escaping () -> Void) -> some View {
        MicrophoneLiveActivityViewLeft(action: action)
    }

    static func right(action: @escaping () -> Void) -> some View {
        MicrophoneLiveActivityViewRight(action: action)
    }
}