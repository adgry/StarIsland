//
//  SportsWidgetView.swift
//  Sapphire
//


#if !SAPPHIRE_FULL_BUILD
import SwiftUI

struct SportsWidgetView: View {
    @ObservedObject private var service = SportsAPIService.shared
    @ObservedObject private var settingsModel = SettingsModel.shared

    private var activeQuery: String {
        let teams = settingsModel.settings.sportsFavoriteTeams
        guard !teams.isEmpty else { return "NBA" }
        let idx = max(0, min(settingsModel.settings.sportsFavoriteTeamIndex, teams.count - 1))
        return teams[idx]
    }

    private var payload: SportsPayload {
        if let live = service.cachedLiveEvent(for: activeQuery) {
            return SportsFinanceContentProvider.makeSportsPayload(from: live)
        }
        return SportsFinanceContentProvider.makeSportsPayload(for: activeQuery, index: 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(payload.league.isEmpty ? "体育实况" : payload.league, systemImage: "sportscourt.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.orange)
                Spacer()
                Text(payload.status == "Live" ? "直播中" : payload.time)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(payload.status == "Live" ? .red : .secondary)
            }

            HStack {
                Text(payload.awayTeam)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                Text("\(payload.awayScore)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }

            HStack {
                Text(payload.homeTeam)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                Text("\(payload.homeScore)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 190, height: 90)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.07)))
        .foregroundStyle(.white)
        .task {
            service.bootstrapIfNeeded()
            _ = await service.fetchLiveEvent(for: activeQuery)
        }
    }
}
#endif
