//
//  SportsAPIService.swift
//  Sapphire
//


#if !SAPPHIRE_FULL_BUILD
import Combine
import Foundation
import SwiftUI

final class SportsAPIService: ObservableObject {
    static let shared = SportsAPIService()

    static let presetRoutes: [ESPNLeagueRoute] = [
        ESPNLeagueRoute(sport: "basketball", league: "nba", displayName: "NBA", shortName: "NBA"),
        ESPNLeagueRoute(sport: "soccer", league: "eng.1", displayName: "英超", shortName: "EPL"),
        ESPNLeagueRoute(sport: "soccer", league: "uefa.champions", displayName: "欧冠", shortName: "UCL"),
        ESPNLeagueRoute(sport: "soccer", league: "esp.1", displayName: "西甲", shortName: "LaLiga"),
        ESPNLeagueRoute(sport: "football", league: "nfl", displayName: "NFL", shortName: "NFL"),
        ESPNLeagueRoute(sport: "baseball", league: "mlb", displayName: "MLB", shortName: "MLB"),
        ESPNLeagueRoute(sport: "hockey", league: "nhl", displayName: "NHL", shortName: "NHL"),
        ESPNLeagueRoute(sport: "racing", league: "f1", displayName: "F1", shortName: "F1")
    ]

    @Published private(set) var allEvents: [LiveSportsEvent] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var lastUpdated: Date?

    private let lock = NSLock()
    private var cacheByQuery: [String: (event: LiveSportsEvent, fetchedAt: Date)] = [:]
    private var latestCommentaryByEventID: [String: SportsComment] = [:]
    private var didBootstrap = false
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 12
        self.session = URLSession(configuration: config)
    }

    func bootstrapIfNeeded() {
        lock.lock()
        let shouldStart = !didBootstrap
        didBootstrap = true
        lock.unlock()
        guard shouldStart else { return }
        let favorites = SettingsModel.shared.current.sportsFavoriteTeams
        Task {
            await prefetchLiveScoreboards(for: favorites.isEmpty ? ["NBA"] : favorites)
        }
    }

    func cachedLiveEvent(for teamOrLeague: String) -> LiveSportsEvent? {
        let key = teamOrLeague.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        lock.lock()
        defer { lock.unlock() }
        if let direct = cacheByQuery[key] {
            return direct.event
        }
        return allEvents.first { Self.event($0, matches: key) }
    }

    func peekLatestCommentary(for event: LiveSportsEvent) -> SportsComment? {
        lock.lock()
        defer { lock.unlock() }
        if let comment = latestCommentaryByEventID[event.eventId] {
            return comment
        }
        if event.isLive {
            return SportsComment(
                id: "\(event.eventId)-\(event.awayScore)-\(event.homeScore)",
                text: "\(event.awayTeam) \(event.awayScore) - \(event.homeScore) \(event.homeTeam) · \(event.clock)",
                clock: event.clock,
                period: event.status
            )
        }
        return nil
    }

    static func resolveLeagueRoute(for query: String) -> ESPNLeagueRoute {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.contains("英超") || q.contains("epl") || q.contains("arsenal") || q.contains("liverpool") || q.contains("chelsea") || q.contains("city") {
            return presetRoutes[1]
        }
        if q.contains("欧冠") || q.contains("ucl") || q.contains("champions") {
            return presetRoutes[2]
        }
        if q.contains("西甲") || q.contains("laliga") || q.contains("madrid") || q.contains("barcelona") {
            return presetRoutes[3]
        }
        if q.contains("nfl") || q.contains("chiefs") || q.contains("49ers") || q.contains("eagles") || q.contains("bills") {
            return presetRoutes[4]
        }
        if q.contains("mlb") || q.contains("dodgers") || q.contains("yankees") {
            return presetRoutes[5]
        }
        if q.contains("nhl") || q.contains("oilers") || q.contains("rangers") {
            return presetRoutes[6]
        }
        if q.contains("f1") || q.contains("formula") || q.contains("verstappen") || q.contains("ferrari") {
            return presetRoutes[7]
        }
        return presetRoutes[0]
    }

    static func parseESPNScoreboard(data: Data, leagueRoute: ESPNLeagueRoute) -> [LiveSportsEvent] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let events = root["events"] as? [[String: Any]] else {
            return []
        }

        var parsed: [LiveSportsEvent] = []
        for event in events {
            let eventID = (event["id"] as? String) ?? UUID().uuidString
            guard let competitions = event["competitions"] as? [[String: Any]],
                  let comp = competitions.first,
                  let competitors = comp["competitors"] as? [[String: Any]],
                  competitors.count >= 2 else {
                continue
            }

            let statusObj = (comp["status"] as? [String: Any]) ?? (event["status"] as? [String: Any]) ?? [:]
            let typeObj = (statusObj["type"] as? [String: Any]) ?? [:]
            let stateStr = (typeObj["state"] as? String)?.lowercased() ?? "pre"
            let completed = (typeObj["completed"] as? Bool) ?? false
            let isLive = (stateStr == "in") && !completed
            let displayClock = (statusObj["displayClock"] as? String) ?? ""
            let shortDetail = (typeObj["shortDetail"] as? String) ?? (typeObj["detail"] as? String) ?? ""
            let period = (statusObj["period"] as? Int) ?? 0

            let homeDict = competitors.first { ($0["homeAway"] as? String)?.lowercased() == "home" } ?? competitors[0]
            let awayDict = competitors.first { ($0["homeAway"] as? String)?.lowercased() == "away" } ?? competitors[1]

            let homeTeam = extractTeamName(homeDict)
            let awayTeam = extractTeamName(awayDict)
            let homeScoreStr = extractScoreString(homeDict)
            let awayScoreStr = extractScoreString(awayDict)
            let homeScore = Int(homeScoreStr) ?? 0
            let awayScore = Int(awayScoreStr) ?? 0

            let statusText: String = completed ? "已结束" : (isLive ? "Live" : "即将开始")
            let clockText: String
            if isLive {
                let pLabel = period > 0 ? "第\(period)节 " : ""
                clockText = displayClock.isEmpty ? (shortDetail.isEmpty ? "进行中" : shortDetail) : "\(pLabel)\(displayClock)"
            } else {
                clockText = shortDetail.isEmpty ? (completed ? "终场" : "待开赛") : shortDetail
            }

            parsed.append(
                LiveSportsEvent(
                    eventId: eventID,
                    homeTeam: homeTeam,
                    awayTeam: awayTeam,
                    homeScore: homeScore,
                    awayScore: awayScore,
                    homeScoreDisplay: homeScoreStr,
                    awayScoreDisplay: awayScoreStr,
                    status: statusText,
                    clock: clockText,
                    homeLogoURL: extractLogoURL(homeDict),
                    awayLogoURL: extractLogoURL(awayDict),
                    leagueRoute: leagueRoute,
                    isLive: isLive,
                    dataSource: "ESPN"
                )
            )
        }
        return parsed
    }

    private static func extractTeamName(_ comp: [String: Any]) -> String {
        if let team = comp["team"] as? [String: Any] {
            return (team["shortDisplayName"] as? String)
                ?? (team["displayName"] as? String)
                ?? (team["abbreviation"] as? String)
                ?? "队伍"
        }
        if let athlete = comp["athlete"] as? [String: Any] {
            return (athlete["shortName"] as? String) ?? (athlete["displayName"] as? String) ?? "选手"
        }
        return "队伍"
    }

    private static func extractScoreString(_ comp: [String: Any]) -> String {
        if let s = comp["score"] as? String { return s }
        if let n = comp["score"] as? Int { return String(n) }
        if let d = comp["score"] as? Double { return String(Int(d)) }
        return "0"
    }

    private static func extractLogoURL(_ comp: [String: Any]) -> URL? {
        guard let team = comp["team"] as? [String: Any],
              let logo = team["logo"] as? String else { return nil }
        return URL(string: logo)
    }

    fileprivate static func event(_ event: LiveSportsEvent, matches query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }
        return event.homeTeam.lowercased().contains(q)
            || event.awayTeam.lowercased().contains(q)
            || event.leagueRoute.displayName.lowercased().contains(q)
            || event.leagueRoute.league.lowercased().contains(q)
            || (event.leagueRoute.shortName?.lowercased().contains(q) ?? false)
    }
}

extension SportsAPIService {
    func prefetchLiveScoreboards(for teams: [String]) async {
        let targets = teams.isEmpty ? ["NBA", "英超"] : teams
        await MainActor.run { self.isLoading = true }
        var aggregated: [LiveSportsEvent] = []
        var seenIDs: Set<String> = []
        var visitedRoutes: Set<ESPNLeagueRoute> = []

        for query in targets {
            let route = Self.resolveLeagueRoute(for: query)
            if !visitedRoutes.contains(route) {
                visitedRoutes.insert(route)
                let fetched = await fetchRouteEvents(route)
                for ev in fetched where seenIDs.insert(ev.eventId).inserted {
                    aggregated.append(ev)
                }
            }
            let key = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if let matched = aggregated.first(where: { Self.event($0, matches: key) }) ?? aggregated.first {
                lock.lock()
                cacheByQuery[key] = (matched, Date())
                lock.unlock()
            }
        }

        let snapshot = aggregated
        await MainActor.run {
            if !snapshot.isEmpty { self.allEvents = snapshot }
            self.lastUpdated = Date()
            self.isLoading = false
        }
    }

    func fetchLiveEvent(for team: String, forceRefresh: Bool = false) async -> LiveSportsEvent? {
        let key = team.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !forceRefresh {
            lock.lock()
            let cached = cacheByQuery[key]
            lock.unlock()
            if let cached, Date().timeIntervalSince(cached.fetchedAt) < 25 {
                return cached.event
            }
        }
        let route = Self.resolveLeagueRoute(for: team)
        let events = await fetchRouteEvents(route)
        let best = events.first(where: { Self.event($0, matches: key) && $0.isLive })
            ?? events.first(where: { Self.event($0, matches: key) })
            ?? events.first(where: \.isLive)
            ?? events.first
        if let best {
            lock.lock()
            cacheByQuery[key] = (best, Date())
            lock.unlock()
            await MainActor.run {
                if self.allEvents.isEmpty { self.allEvents = events }
                self.lastUpdated = Date()
            }
        }
        return best
    }

    private func fetchRouteEvents(_ route: ESPNLeagueRoute) async -> [LiveSportsEvent] {
        guard let url = URL(string: "https://site.api.espn.com/apis/site/v2/sports/\(route.sport)/\(route.league)/scoreboard") else {
            return []
        }
        guard let (data, response) = try? await session.data(from: url),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            return []
        }
        return Self.parseESPNScoreboard(data: data, leagueRoute: route)
    }
}

enum SportsLiveActivityView {
    @ViewBuilder
    static func left(for payload: SportsPayload, preferLogo: Bool) -> some View {
        HStack(spacing: 5) {
            if preferLogo, let url = payload.awayLogoURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    Image(systemName: "sportscourt.fill").foregroundStyle(.orange)
                }
                .frame(width: 16, height: 16)
            } else {
                Image(systemName: "sportscourt.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.orange)
            }
            Text("\(String(payload.awayTeam.prefix(3)).uppercased()) \(payload.awayScore)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    static func right(for payload: SportsPayload, preferLogo: Bool) -> some View {
        HStack(spacing: 5) {
            Text("\(payload.homeScore) \(String(payload.homeTeam.prefix(3)).uppercased())")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
            if payload.status == "Live" {
                Circle().fill(Color.red).frame(width: 6, height: 6)
            }
        }
    }
}
#endif
