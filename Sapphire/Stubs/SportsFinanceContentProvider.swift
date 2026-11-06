//
//  SportsFinanceContentProvider.swift
//  Sapphire
//


#if !SAPPHIRE_FULL_BUILD
import Foundation

enum SportsFinanceContentProvider {
    static func makeSportsPayload(from live: LiveSportsEvent) -> SportsPayload {
        SportsPayload(
            league: live.leagueRoute.displayName,
            homeTeam: live.homeTeam,
            awayTeam: live.awayTeam,
            homeScore: live.homeScore,
            awayScore: live.awayScore,
            status: live.isLive ? "Live" : live.status,
            time: live.clock,
            league_logo: nil,
            homeLogoURL: live.homeLogoURL,
            awayLogoURL: live.awayLogoURL
        )
    }

    static func makeSportsPayload(for teamOrLeague: String, index: Int) -> SportsPayload {
        if let cached = SportsAPIService.shared.cachedLiveEvent(for: teamOrLeague) {
            return makeSportsPayload(from: cached)
        }
        let route = SportsAPIService.resolveLeagueRoute(for: teamOrLeague)
        return SportsPayload(
            league: route.displayName,
            homeTeam: teamOrLeague,
            awayTeam: "待开赛",
            homeScore: 0,
            awayScore: 0,
            status: "即将开始",
            time: "--:--"
        )
    }
}
#endif
