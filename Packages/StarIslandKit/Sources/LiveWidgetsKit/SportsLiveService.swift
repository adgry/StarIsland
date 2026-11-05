import Combine
import Foundation
import IslandCore

public enum SportsParseError: LocalizedError, Equatable, Sendable {
    case invalidPayload
    case networkFailure(String)

    public var errorDescription: String? {
        switch self {
        case .invalidPayload:
            return "体育记分牌数据格式无法解析"
        case .networkFailure(let detail):
            return "获取体育实时比分失败：\(detail)"
        }
    }
}

public enum SportsLeague: String, CaseIterable, Codable, Identifiable, Sendable {
    case nba = "basketball/nba"
    case epl = "soccer/eng.1"
    case ucl = "soccer/uefa.champions"
    case laliga = "soccer/esp.1"
    case mlb = "baseball/mlb"
    case nfl = "football/nfl"
    case f1 = "racing/f1"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .nba: return "NBA 职业篮球"
        case .epl: return "英超联赛"
        case .ucl: return "欧洲冠军联赛"
        case .laliga: return "西甲联赛"
        case .mlb: return "MLB 棒球大联盟"
        case .nfl: return "NFL 职业橄榄球"
        case .f1: return "F1 世界一级方程式"
        }
    }

    public var shortTitle: String {
        switch self {
        case .nba: return "NBA"
        case .epl: return "英超"
        case .ucl: return "欧冠"
        case .laliga: return "西甲"
        case .mlb: return "MLB"
        case .nfl: return "NFL"
        case .f1: return "F1"
        }
    }

    public var iconSymbol: String {
        switch self {
        case .nba: return "basketball.fill"
        case .epl, .ucl, .laliga: return "soccerball"
        case .mlb: return "baseball.fill"
        case .nfl: return "football.fill"
        case .f1: return "flag.checkered"
        }
    }

    public static func iconSymbol(for leaguePath: String) -> String {
        SportsLeague(rawValue: leaguePath)?.iconSymbol ?? "sportscourt.fill"
    }

    public static func scoreboardURL(for leaguePath: String) -> URL? {
        let trimmed = leaguePath.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard !trimmed.isEmpty else { return nil }
        return URL(string: "https://site.api.espn.com/apis/site/v2/sports/\(trimmed)/scoreboard")
    }
}

public enum MatchStatusState: String, Codable, Equatable, Sendable {
    case scheduled
    case live
    case finished
}

public struct LiveMatch: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let league: String
    public let eventName: String
    public let homeTeamAbbr: String
    public let homeTeamName: String
    public let homeScore: String
    public let awayTeamAbbr: String
    public let awayTeamName: String
    public let awayScore: String
    public let periodNumber: Int
    public let displayClock: String
    public let periodText: String
    public let state: MatchStatusState

    public var isLive: Bool { state == .live }

    public var scoreHeadline: String {
        "\(awayTeamAbbr) \(awayScore) : \(homeScore) \(homeTeamAbbr)"
    }

    public init(
        id: String,
        league: String,
        eventName: String,
        homeTeamAbbr: String,
        homeTeamName: String,
        homeScore: String,
        awayTeamAbbr: String,
        awayTeamName: String,
        awayScore: String,
        periodNumber: Int,
        displayClock: String,
        periodText: String,
        state: MatchStatusState
    ) {
        self.id = id
        self.league = league
        self.eventName = eventName
        self.homeTeamAbbr = homeTeamAbbr
        self.homeTeamName = homeTeamName
        self.homeScore = homeScore
        self.awayTeamAbbr = awayTeamAbbr
        self.awayTeamName = awayTeamName
        self.awayScore = awayScore
        self.periodNumber = periodNumber
        self.displayClock = displayClock
        self.periodText = periodText
        self.state = state
    }
}

public enum ESPNScoreboardParser {
    private struct FlexibleString: Decodable {
        let value: String

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let str = try? container.decode(String.self) {
                self.value = str
            } else if let intVal = try? container.decode(Int.self) {
                self.value = String(intVal)
            } else if let doubleVal = try? container.decode(Double.self) {
                self.value = String(format: "%.0f", doubleVal)
            } else {
                self.value = "0"
            }
        }
    }

    private struct ScoreboardDTO: Decodable {
        struct EventDTO: Decodable {
            struct CompetitionDTO: Decodable {
                struct StatusDTO: Decodable {
                    struct StatusTypeDTO: Decodable {
                        let state: String?
                        let completed: Bool?
                        let detail: String?
                        let shortDetail: String?
                    }
                    let displayClock: String?
                    let period: Int?
                    let type: StatusTypeDTO?
                }

                struct CompetitorDTO: Decodable {
                    struct TeamDTO: Decodable {
                        let abbreviation: String?
                        let shortDisplayName: String?
                        let displayName: String?
                        let name: String?
                    }
                    struct AthleteDTO: Decodable {
                        let shortName: String?
                        let displayName: String?
                    }
                    let id: String?
                    let order: Int?
                    let homeAway: String?
                    let score: FlexibleString?
                    let team: TeamDTO?
                    let athlete: AthleteDTO?
                }

                let id: String?
                let status: StatusDTO?
                let competitors: [CompetitorDTO]?
            }

            let id: String?
            let name: String?
            let shortName: String?
            let competitions: [CompetitionDTO]?
            let status: CompetitionDTO.StatusDTO?
        }

        let events: [EventDTO]?
    }

    public static func parse(data: Data, league: String) throws -> [LiveMatch] {
        let dto: ScoreboardDTO
        do {
            dto = try JSONDecoder().decode(ScoreboardDTO.self, from: data)
        } catch {
            throw SportsParseError.invalidPayload
        }

        guard let events = dto.events else { return [] }
        var results: [LiveMatch] = []

        for event in events {
            guard let competition = event.competitions?.first,
                  let competitors = competition.competitors,
                  competitors.count >= 2 else {
                continue
            }

            let status = competition.status ?? event.status
            let state = mapState(status?.type?.state, completed: status?.type?.completed)
            let period = status?.period ?? 0
            let clock = status?.displayClock ?? ""
            let periodText = localizedPeriodText(
                state: state,
                league: league,
                period: period,
                clock: clock,
                shortDetail: status?.type?.shortDetail ?? status?.type?.detail
            )

            let homeComp = competitors.first(where: { $0.homeAway?.lowercased() == "home" })
            let awayComp = competitors.first(where: { $0.homeAway?.lowercased() == "away" })

            let first: ScoreboardDTO.EventDTO.CompetitionDTO.CompetitorDTO
            let second: ScoreboardDTO.EventDTO.CompetitionDTO.CompetitorDTO
            if let homeComp, let awayComp {
                first = homeComp
                second = awayComp
            } else {
                let sorted = competitors.sorted { ($0.order ?? 99) < ($1.order ?? 99) }
                first = sorted[0]
                second = sorted[1]
            }

            let homeName = extractName(from: first)
            let awayName = extractName(from: second)
            let homeAbbr = extractAbbreviation(from: first, fallbackName: homeName)
            let awayAbbr = extractAbbreviation(from: second, fallbackName: awayName)
            let homeScore = first.score?.value ?? (first.order.map { "P\($0)" } ?? "0")
            let awayScore = second.score?.value ?? (second.order.map { "P\($0)" } ?? "0")

            let matchID = competition.id ?? event.id ?? "\(league)-\(awayAbbr)-\(homeAbbr)"
            let title = event.shortName ?? event.name ?? "\(awayName) vs \(homeName)"

            results.append(
                LiveMatch(
                    id: matchID,
                    league: league,
                    eventName: title,
                    homeTeamAbbr: homeAbbr,
                    homeTeamName: homeName,
                    homeScore: homeScore,
                    awayTeamAbbr: awayAbbr,
                    awayTeamName: awayName,
                    awayScore: awayScore,
                    periodNumber: period,
                    displayClock: clock,
                    periodText: periodText,
                    state: state
                )
            )
        }
        return results
    }

    private static func mapState(_ raw: String?, completed: Bool?) -> MatchStatusState {
        if completed == true { return .finished }
        switch raw?.lowercased() {
        case "in": return .live
        case "post": return .finished
        default: return .scheduled
        }
    }

    private static func extractName(from comp: ScoreboardDTO.EventDTO.CompetitionDTO.CompetitorDTO) -> String {
        comp.team?.shortDisplayName
            ?? comp.team?.displayName
            ?? comp.team?.name
            ?? comp.athlete?.shortName
            ?? comp.athlete?.displayName
            ?? "未知队伍"
    }

    private static func extractAbbreviation(
        from comp: ScoreboardDTO.EventDTO.CompetitionDTO.CompetitorDTO,
        fallbackName: String
    ) -> String {
        if let abbr = comp.team?.abbreviation, !abbr.isEmpty {
            return abbr.uppercased()
        }
        let letters = fallbackName.replacingOccurrences(of: " ", with: "")
        return String(letters.prefix(3)).uppercased()
    }

    private static func localizedPeriodText(
        state: MatchStatusState,
        league: String,
        period: Int,
        clock: String,
        shortDetail: String?
    ) -> String {
        switch state {
        case .finished:
            return "已结束"
        case .scheduled:
            if let shortDetail, !shortDetail.isEmpty {
                return "未开赛 · \(shortDetail)"
            }
            return "即将开赛"
        case .live:
            if league.contains("soccer") {
                let half = period <= 1 ? "上半场" : "下半场"
                return clock.isEmpty ? "\(half) 进行中" : "\(half) \(clock)"
            } else if league.contains("racing") {
                return period > 0 ? "第\(period)圈 竞速中" : "正赛进行中"
            } else if period > 0 {
                let periodTitle = period > 4 ? "加时\(period - 4)" : "第\(period)节"
                return clock.isEmpty || clock == "0.0" ? periodTitle : "\(periodTitle) \(clock)"
            }
            return shortDetail ?? "比赛进行中"
        }
    }
}

@MainActor
public final class SportsLiveService: ObservableObject {
    public static let shared = SportsLiveService()

    @Published public private(set) var matches: [LiveMatch] = []
    @Published public private(set) var celebratingMatchID: String?
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var lastUpdated: Date?
    @Published public private(set) var errorMessage: String?

    private let settingsStore: SettingsStore
    private let stateMachine: IslandStateMachine
    private let session: URLSession
    private let cacheURL: URL
    private var pollingTask: Task<Void, Never>?
    private var previousScores: [String: String] = [:]
    private var consecutiveFailures: Int = 0

    public init(
        settingsStore: SettingsStore? = nil,
        stateMachine: IslandStateMachine? = nil,
        session: URLSession? = nil,
        cacheURL: URL? = nil
    ) {
        self.settingsStore = settingsStore ?? .shared
        self.stateMachine = stateMachine ?? .shared
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 8
            config.timeoutIntervalForResource = 12
            self.session = URLSession(configuration: config)
        }
        self.cacheURL = cacheURL ?? StarIslandPaths.cachesDirectory.appendingPathComponent("sports-cache.json")
        loadCachedMatches()
    }

    public func startAutoRefresh(interval: TimeInterval = 30) {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refresh()
                let backoff = min(180.0, pow(2.0, Double(self.consecutiveFailures)) * 5.0)
                let waitSeconds = self.consecutiveFailures > 0 ? backoff : max(15.0, interval)
                try? await Task.sleep(nanoseconds: UInt64(waitSeconds * 1_000_000_000))
            }
        }
    }

    public func stopAutoRefresh() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    public func selectLeague(_ leaguePath: String) async {
        settingsStore.settings.favoriteSportsLeague = leaguePath
        await refresh()
    }

    public func refresh() async {
        let leaguePath = settingsStore.settings.favoriteSportsLeague
        guard let url = SportsLeague.scoreboardURL(for: leaguePath) else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let (data, response) = try await session.data(from: url)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw SportsParseError.networkFailure("HTTP \(http.statusCode)")
            }
            let parsed = try ESPNScoreboardParser.parse(data: data, league: leaguePath)
            matches = parsed
            lastUpdated = Date()
            errorMessage = nil
            consecutiveFailures = 0
            persistMatches(parsed)
            syncLiveActivities(with: parsed)
        } catch {
            consecutiveFailures += 1
            errorMessage = error.localizedDescription
        }
    }

    public func syncLiveActivities(with currentMatches: [LiveMatch]) {
        guard settingsStore.settings.enableSportsLiveActivity else {
            stateMachine.clearCategory(.sports)
            return
        }

        let liveMatches = currentMatches.filter(\.isLive)
        let activeLiveIDs = Set(liveMatches.map { "sports.live.\($0.id)" })

        // 移除已结束或下线的比赛胶囊
        for existing in stateMachine.activities where existing.category == .sports && existing.id.hasPrefix("sports.live.") {
            if !activeLiveIDs.contains(existing.id) {
                stateMachine.dismiss(id: existing.id)
            }
        }

        for match in liveMatches.prefix(2) {
            let scoreKey = "\(match.awayScore)-\(match.homeScore)"
            let previous = previousScores[match.id]
            previousScores[match.id] = scoreKey

            let icon = SportsLeague.iconSymbol(for: match.league)
            stateMachine.submit(
                IslandActivityItem(
                    id: "sports.live.\(match.id)",
                    category: .sports,
                    title: match.scoreHeadline,
                    subtitle: match.periodText,
                    iconSymbol: icon,
                    trailingBadge: "实况",
                    priority: .ongoing,
                    allowsOnLockScreen: true
                )
            )

            // 比分刷新庆祝动效
            if let previous, previous != scoreKey {
                celebratingMatchID = match.id
                stateMachine.submit(
                    IslandActivityItem(
                        id: "sports.goal.\(match.id)",
                        category: .sports,
                        title: "比分刷新！\(match.scoreHeadline)",
                        subtitle: "\(match.eventName) · \(match.periodText)",
                        iconSymbol: "party.popper.fill",
                        trailingBadge: "得分",
                        priority: .interactive,
                        isPeek: true,
                        allowsOnLockScreen: true,
                        autoDismissAfter: 3.5
                    )
                )
            }
        }
    }

    private func loadCachedMatches() {
        guard let data = try? Data(contentsOf: cacheURL),
              let decoded = try? JSONDecoder().decode([LiveMatch].self, from: data) else {
            return
        }
        matches = decoded
    }

    private func persistMatches(_ items: [LiveMatch]) {
        let dir = cacheURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: cacheURL, options: .atomic)
        }
    }
}
