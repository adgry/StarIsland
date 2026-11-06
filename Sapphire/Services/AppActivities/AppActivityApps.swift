//
//  AppActivityApps.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2026-09-28
//

import AppKit

enum AppActivityControl: String, CaseIterable, Identifiable {
    case mute, video, share, deafen, stop, leave, show
    var id: String { rawValue }
}

enum AppActivityKind {
    case meeting, call, recording, remoteSession

    var verb: String {
        switch self {
        case .meeting: "会议中"
        case .call: "通话中"
        case .recording: "录制中"
        case .remoteSession: "已连接"
        }
    }
}

enum AppActivityAction {
    case menu([String])
    case shortcut(key: CGKeyCode, flags: CGEventFlags)
    case focus
    case closeTab
}

enum AppActivityApp: String, CaseIterable, Identifiable, Codable {
    case zoom, googleMeet, teams, slack, discord, faceTime, webex, voiceMemos, quickTime, screenSharing

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .zoom: "Zoom"
        case .googleMeet: "Google Meet"
        case .teams: "Microsoft Teams"
        case .slack: "Slack 抱团通话"
        case .discord: "Discord 语音频道"
        case .faceTime: "FaceTime 通话"
        case .webex: "Webex"
        case .voiceMemos: "语音备忘录"
        case .quickTime: "QuickTime 录制"
        case .screenSharing: "屏幕共享"
        }
    }

    var kind: AppActivityKind {
        switch self {
        case .zoom, .googleMeet, .teams, .webex: .meeting
        case .slack, .discord, .faceTime: .call
        case .voiceMemos, .quickTime: .recording
        case .screenSharing: .remoteSession
        }
    }

    var bundleIDs: [String] {
        switch self {
        case .zoom: ["us.zoom.xos"]
        case .googleMeet: ["com.google.Chrome", "com.microsoft.edgemac", "com.brave.Browser", "company.thebrowser.Browser", "com.apple.Safari"]
        case .teams: ["com.microsoft.teams2", "com.microsoft.teams"]
        case .slack: ["com.tinyspeck.slackmacgap"]
        case .discord: ["com.hnc.Discord", "com.hnc.DiscordPTB", "com.hnc.DiscordCanary"]
        case .faceTime: ["com.apple.FaceTime"]
        case .webex: ["Cisco-Systems.Spark", "com.webex.meetingmanager"]
        case .voiceMemos: ["com.apple.VoiceMemos"]
        case .quickTime: ["com.apple.QuickTimePlayerX"]
        case .screenSharing: ["com.apple.ScreenSharing"]
        }
    }

    var microphonePrefixes: [String] {
        switch self {
        case .googleMeet:
            ["com.google.Chrome", "com.microsoft.edgemac", "com.brave.Browser", "company.thebrowser",
             "com.apple.WebKit.GPU", "com.apple.WebKit"]
        case .zoom: ["us.zoom"]
        case .teams: ["com.microsoft.teams"]
        case .webex: ["Cisco-Systems", "com.webex"]
        case .screenSharing: []
        default: bundleIDs
        }
    }

    var windowHints: [String] {
        switch self {
        case .zoom: ["Zoom Meeting", "Zoom Webinar", "Zoom Workplace - Meeting"]
        case .quickTime: ["Screen Recording", "Movie Recording", "Audio Recording"]
        case .screenSharing: []
        default: []
        }
    }

    var controls: [AppActivityControl] {
        switch self {
        case .zoom: [.mute, .video, .share, .leave, .show]
        case .googleMeet: [.mute, .video, .leave, .show]
        case .teams: [.mute, .video, .share, .leave, .show]
        case .slack: [.mute, .leave, .show]
        case .discord: [.mute, .deafen, .show]
        case .faceTime: [.mute, .video, .leave, .show]
        case .webex: [.mute, .video, .show]
        case .voiceMemos: [.stop, .show]
        case .quickTime: [.stop, .show]
        case .screenSharing: [.leave, .show]
        }
    }

    func action(for control: AppActivityControl) -> AppActivityAction? {
        let cmd: CGEventFlags = .maskCommand, shift: CGEventFlags = .maskShift
        switch (self, control) {
        case (_, .show): return .focus
        case (.zoom, .mute): return .menu(["Mute Audio", "Unmute Audio"])
        case (.zoom, .video): return .menu(["Stop Video", "Start Video"])
        case (.zoom, .share): return .menu(["Start Share", "Stop Share", "Share Screen"])
        case (.zoom, .leave): return .shortcut(key: AppActivityKeys.w, flags: cmd)
        case (.faceTime, .mute): return .menu(["Mute", "Unmute"])
        case (.faceTime, .video): return .menu(["Turn Camera Off", "Turn Camera On", "Pause Video", "Resume Video"])
        case (.faceTime, .leave): return .menu(["End Call", "Leave Call", "End"])
        case (.googleMeet, .mute): return .shortcut(key: AppActivityKeys.d, flags: cmd)
        case (.googleMeet, .video): return .shortcut(key: AppActivityKeys.e, flags: cmd)
        case (.googleMeet, .leave): return .closeTab
        case (.teams, .mute): return .shortcut(key: AppActivityKeys.m, flags: [cmd, shift])
        case (.teams, .video): return .shortcut(key: AppActivityKeys.o, flags: [cmd, shift])
        case (.teams, .share): return .shortcut(key: AppActivityKeys.e, flags: [cmd, shift])
        case (.teams, .leave): return .shortcut(key: AppActivityKeys.h, flags: [cmd, shift])
        case (.slack, .mute): return .shortcut(key: AppActivityKeys.space, flags: [cmd, shift])
        case (.slack, .leave): return .shortcut(key: AppActivityKeys.h, flags: [cmd, shift])
        case (.discord, .mute): return .shortcut(key: AppActivityKeys.m, flags: [cmd, shift])
        case (.discord, .deafen): return .shortcut(key: AppActivityKeys.d, flags: [cmd, shift])
        case (.webex, .mute): return .shortcut(key: AppActivityKeys.m, flags: [cmd, shift])
        case (.webex, .video): return .shortcut(key: AppActivityKeys.v, flags: [cmd, shift])
        case (.voiceMemos, .stop): return .menu(["Stop Recording", "Stop", "Done"])
        case (.quickTime, .stop): return .menu(["Stop Recording"])
        case (.screenSharing, .leave): return .shortcut(key: AppActivityKeys.w, flags: cmd)
        default: return nil
        }
    }

    func stateTitles(for control: AppActivityControl) -> (on: [String], off: [String])? {
        switch (self, control) {
        case (.zoom, .mute): (on: ["Unmute Audio"], off: ["Mute Audio"])
        case (.zoom, .video): (on: ["Stop Video"], off: ["Start Video"])
        case (.zoom, .share): (on: ["Stop Share"], off: ["Start Share", "Share Screen"])
        case (.faceTime, .mute): (on: ["Unmute"], off: ["Mute"])
        case (.faceTime, .video): (on: ["Turn Camera Off", "Pause Video"], off: ["Turn Camera On", "Resume Video"])
        default: nil
        }
    }

    var isInstalled: Bool {
        if self == .googleMeet { return true }
        return bundleIDs.contains { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil }
    }

    var icon: NSImage? {
        if self == .googleMeet {
            return NSImage(systemSymbolName: "video.fill", accessibilityDescription: "Google Meet")
        }
        for id in bundleIDs {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
                return NSWorkspace.shared.icon(forFile: url.path)
            }
        }
        return nil
    }

    var detectionDetail: String {
        switch self {
        case .zoom: "处于会议中时显示。静音、视频和共享状态与 Zoom 保持同步。"
        case .googleMeet: "当 Chrome、Edge、Brave、Arc 或 Safari 中的 Meet 标签页正在使用麦克风时显示。需要控制浏览器的权限。"
        case .teams: "当 Teams 通话或会议正在使用麦克风时显示。"
        case .slack: "处于抱团通话中时显示。"
        case .discord: "处于语音频道中时显示。"
        case .faceTime: "正在进行 FaceTime 通话时显示。"
        case .webex: "当 Webex 会议正在使用麦克风时显示。"
        case .voiceMemos: "当“语音备忘录”正在录音时显示。"
        case .quickTime: "当 QuickTime 正在录制屏幕、影片或音频时显示。"
        case .screenSharing: "连接到另一台 Mac 时显示。"
        }
    }
}

enum AppActivityKeys {
    static let d: CGKeyCode = 0x02
    static let e: CGKeyCode = 0x0E
    static let h: CGKeyCode = 0x04
    static let m: CGKeyCode = 0x2E
    static let o: CGKeyCode = 0x1F
    static let v: CGKeyCode = 0x09
    static let w: CGKeyCode = 0x0D
    static let space: CGKeyCode = 0x31
}