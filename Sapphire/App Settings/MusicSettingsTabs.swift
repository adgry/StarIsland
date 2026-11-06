//
//  MusicSettingsTabs.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2026-09-26

import AppKit
import MusicKit
import SwiftUI

enum MusicSettingsTab: String, CaseIterable, Identifiable {
    case general = "通用"
    case player = "播放器"
    case features = "功能"
    case accounts = "账户"
    case lyrics = "歌词"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .player: return "play.rectangle"
        case .features: return "sparkles"
        case .accounts: return "person.crop.circle"
        case .lyrics: return "quote.bubble"
        }
    }
}

// MARK: - Player features (shared by Spotify and Apple Music)

struct MusicPlayerFeaturesCard: View {
    @EditingSettings var settings: SettingsEditingSession
    let isSpotifyAvailable: Bool

    enum Service {
        case spotify, appleMusic

        var title: String { self == .spotify ? "Spotify" : "Apple Music" }
        var color: Color { self == .spotify ? .green : .pink }
        var icon: String { self == .spotify ? "dot.radiowaves.left.and.right" : "music.note" }
    }

    var body: some View {
        SettingsCard(
            title: "播放器增强功能",
            description: "在音乐播放器中显示的附加信息与扩展能力，开启后将自动应用于所有支持该功能的服务。"
        ) {
            if !isSpotifyAvailable {
                InfoContainer(
                    text: "Spotify 扩展功能需要在“账户”标签页中登录 Spotify 私有 API；Apple Music 扩展功能无需额外登录即可使用。",
                    iconName: "info.circle",
                    color: .blue
                )
                .padding(.horizontal)
                .padding(.bottom, 6)
            }

            row("艺人简介",
                "在艺人名称旁显示艺人头像。Spotify 会额外显示认证标识与月听众数；Apple Music 会显示流派、发行年份与你的播放次数。",
                services: [.spotify, .appleMusic],
                isOn: $settings.settings.spotifyShowArtistProfile)
            Divider().padding(.leading, 20)
            row("热门度",
                "显示曲目的热门度评分。Apple Music 评分来自 stats.fm，无需登录。",
                services: [.spotify, .appleMusic],
                isOn: $settings.settings.showPopularityInMusicPlayer)
            Divider().padding(.leading, 20)
            row("下一首播放",
                "在当前播放曲目标题下方显示播放队列中的下一首曲目。",
                services: [.spotify, .appleMusic],
                isOn: $settings.settings.spotifyShowNextSong)
            Divider().padding(.leading, 20)
            row("下一首专辑封面",
                "在实时活动的下一首曲目旁显示专辑封面。",
                services: [.spotify, .appleMusic],
                isOn: $settings.settings.spotifyShowNextSongAlbumArt)
                .disabled(!settings.settings.spotifyShowNextSong)
            Divider().padding(.leading, 20)
            row("推荐歌曲",
                "在音乐播放器中显示可直接点播的推荐歌曲标签：Spotify 显示相似曲目，Apple Music 显示该艺人的更多作品。",
                services: [.spotify, .appleMusic],
                isOn: $settings.settings.spotifyShowSuggestedSongs)
            Divider().padding(.leading, 20)
            row("演出门票",
                "当该艺人附近有近期演出时，显示紧凑的购票入口按钮。",
                services: [.spotify],
                isOn: $settings.settings.spotifyShowConcertTickets)
            Divider().padding(.leading, 20)
            row("账户徽章",
                "在曲目标题旁显示 Premium / Free 账户徽章。",
                services: [.spotify],
                isOn: $settings.settings.spotifyShowAccountBadge)
        }
    }

    private func row(_ title: String, _ description: String, services: [Service], isOn: Binding<Bool>) -> some View {
        let available = services.contains(.appleMusic) || isSpotifyAvailable
        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    ForEach(services, id: \.title) { service in
                        StatusCapsuleLabel(title: service.title, color: service.color, icon: service.icon)
                    }
                }
            }
            Spacer(minLength: 8)
            SettingsSwitch(title: title, isOn: isOn)
        }
        .padding()
        .disabled(!available)
        .opacity(available ? 1 : 0.5)
    }
}

// MARK: - Apple Music account

struct AppleMusicAccountCard: View {
    private var musicKit: MusicKitAppleMusicManager { .shared }
    @State private var isRequesting = false

    private var account: AppleMusicAccountState { musicKit.account }

    var body: some View {
        SettingsCard(
            title: "Apple Music",
            description: "Sapphire 使用 MusicKit 获取 Apple Music 专辑封面、艺人详情、播放队列与资料库内容。除授予媒体资料库访问权限外无需额外登录。"
        ) {
            HStack(spacing: 10) {
                Image(systemName: statusIcon).foregroundStyle(statusColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusTitle)
                    if let detail = statusDetail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
                actionButton
            }
            .padding()
        }
        .onAppear { musicKit.refreshAuthorizationStatus() }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch account.authorization {
        case .notDetermined:
            Button(isRequesting ? "正在请求…" : "允许访问") {
                isRequesting = true
                Task {
                    await AppleMusicManager.shared.requestAuthorization()
                    isRequesting = false
                }
            }
            .disabled(isRequesting)
        case .denied, .restricted:
            Button("打开隐私设置") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Media") {
                    NSWorkspace.shared.open(url)
                }
            }
        default:
            EmptyView()
        }
    }

    private var statusTitle: String {
        switch account.authorization {
        case .authorized: return account.canPlayCatalogContent ? "已连接 · 已订阅 Apple Music" : "已连接 · 未订阅"
        case .notDetermined: return "未连接"
        case .denied: return "访问权限已关闭"
        case .restricted: return "访问权限受限"
        @unknown default: return "未知"
        }
    }

    private var statusDetail: String? {
        if let error = account.lastError { return error }
        switch account.authorization {
        case .authorized:
            return account.canPlayCatalogContent ? nil : "支持资料库与“音乐”应用本地播放控制；流媒体曲库点播需订阅 Apple Music。"
        case .notDetermined:
            return "允许访问后即可为 Apple Music 显示高清封面、艺人简介与待播清单。"
        case .denied, .restricted:
            return "请在“系统设置 › 隐私与安全性 › 媒体与 Apple Music”中开启 Sapphire 的访问权限。"
        @unknown default:
            return nil
        }
    }

    private var statusIcon: String {
        switch account.authorization {
        case .authorized: return "checkmark.circle.fill"
        case .notDetermined: return "circle.dashed"
        default: return "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch account.authorization {
        case .authorized: return .green
        case .notDetermined: return .secondary
        default: return .orange
        }
    }
}