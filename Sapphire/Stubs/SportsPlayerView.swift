//
//  SportsPlayerView.swift
//  Sapphire
//


#if !SAPPHIRE_FULL_BUILD
import SwiftUI

struct SportsPlayerView: View {
    @Binding var navigationStack: [NotchWidgetMode]
    @ObservedObject private var service = SportsAPIService.shared
    @ObservedObject private var settingsModel = SettingsModel.shared
    @State private var selectedRoute: ESPNLeagueRoute = SportsAPIService.presetRoutes[0]

    init(navigationStack: Binding<[NotchWidgetMode]>) {
        _navigationStack = navigationStack
    }

    private var displayedEvents: [LiveSportsEvent] {
        let filtered = service.allEvents.filter { $0.leagueRoute == selectedRoute }
        return filtered.isEmpty ? service.allEvents : filtered
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button {
                    if !navigationStack.isEmpty { navigationStack.removeLast() }
                } label: {
                    Label("返回", systemImage: "chevron.left")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.85))

                Spacer()
                Text("ESPN 全球赛事记分牌")
                    .font(.subheadline.weight(.bold))
                Spacer()

                Button {
                    Task {
                        await service.prefetchLiveScoreboards(for: [selectedRoute.displayName])
                    }
                } label: {
                    Image(systemName: service.isLoading ? "hourglass" : "arrow.clockwise")
                        .font(.caption.weight(.bold))
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(SportsAPIService.presetRoutes, id: \.self) { route in
                        Button {
                            selectedRoute = route
                            Task { await service.prefetchLiveScoreboards(for: [route.displayName]) }
                        } label: {
                            Text(route.displayName)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule().fill(selectedRoute == route ? Color.orange : Color.white.opacity(0.1))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if displayedEvents.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "sportscourt")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text(service.isLoading ? "正在同步 ESPN 实时赛况…" : "当前联赛暂无今日赛程")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 110)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(displayedEvents.prefix(8), id: \.eventId) { ev in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(ev.awayTeam) vs \(ev.homeTeam)")
                                        .font(.system(size: 12, weight: .semibold))
                                        .lineLimit(1)
                                    Text("\(ev.leagueRoute.displayName) · \(ev.clock)")
                                        .font(.system(size: 10))
                                        .foregroundStyle(ev.isLive ? .red : .secondary)
                                }
                                Spacer()
                                Text("\(ev.awayScoreDisplay) : \(ev.homeScoreDisplay)")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.06)))
                        }
                    }
                }
                .frame(maxHeight: 150)
            }
        }
        .padding(14)
        .frame(width: 440)
        .foregroundStyle(.white)
        .task {
            let favs = settingsModel.settings.sportsFavoriteTeams
            await service.prefetchLiveScoreboards(for: favs + [selectedRoute.displayName])
        }
    }
}
#endif
