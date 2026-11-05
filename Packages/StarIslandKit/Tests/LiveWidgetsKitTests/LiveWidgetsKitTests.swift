import Foundation
import IslandCore
@testable import LiveWidgetsKit
import XCTest

final class LiveWidgetsKitTests: XCTestCase {

    // MARK: - 1. Open-Meteo 天气与城市搜索解析测试

    func testOpenMeteoParserParsesCurrentDailyAndWeatherCodeMapping() throws {
        let json = """
        {
          "latitude": 39.9042,
          "longitude": 116.4074,
          "current": {
            "time": "2026-11-05T14:00",
            "temperature_2m": 16.4,
            "apparent_temperature": 14.8,
            "is_day": 1,
            "weather_code": 61,
            "relative_humidity_2m": 72,
            "wind_speed_10m": 11.5,
            "precipitation_probability": 65
          },
          "hourly": {
            "time": ["2026-11-05T14:00", "2026-11-05T15:00", "2026-11-05T16:00"],
            "temperature_2m": [16.4, 15.9, 14.2],
            "precipitation_probability": [65, 40, 20],
            "weather_code": [61, 3, 1]
          },
          "daily": {
            "time": ["2026-11-05", "2026-11-06"],
            "weather_code": [61, 0],
            "temperature_2m_max": [18.5, 20.1],
            "temperature_2m_min": [7.2, 8.0],
            "precipitation_probability_max": [70, 5]
          }
        }
        """

        let snapshot = try OpenMeteoParser.parse(data: Data(json.utf8), cityName: "北京")
        XCTAssertEqual(snapshot.cityName, "北京")
        XCTAssertEqual(snapshot.temperatureC, 16.4, accuracy: 0.01)
        XCTAssertEqual(snapshot.apparentTemperatureC, 14.8, accuracy: 0.01)
        XCTAssertEqual(snapshot.weatherCode, 61)
        XCTAssertEqual(snapshot.conditionText, "小雨")
        XCTAssertEqual(snapshot.symbolName, "cloud.rain.fill")
        XCTAssertEqual(snapshot.highTempC, 18.5, accuracy: 0.01)
        XCTAssertEqual(snapshot.lowTempC, 7.2, accuracy: 0.01)
        XCTAssertEqual(snapshot.hourly.count, 3)
        XCTAssertEqual(snapshot.daily.count, 2)
        XCTAssertEqual(snapshot.daily[1].conditionText, "晴朗")
        XCTAssertEqual(snapshot.daily[1].symbolName, "sun.max.fill")
    }

    func testOpenMeteoGeocodingCitiesParsing() throws {
        let json = """
        {
          "results": [
            {
              "id": 1796236,
              "name": "上海",
              "latitude": 31.22222,
              "longitude": 121.45806,
              "country": "中国",
              "admin1": "上海市"
            },
            {
              "id": 1816670,
              "name": "北京",
              "latitude": 39.9075,
              "longitude": 116.39723,
              "country": "中国",
              "admin1": "北京市"
            }
          ]
        }
        """

        let cities = try OpenMeteoParser.parseCities(data: Data(json.utf8))
        XCTAssertEqual(cities.count, 2)
        XCTAssertEqual(cities[0].name, "上海")
        XCTAssertEqual(cities[0].latitude, 31.22222, accuracy: 0.0001)
        XCTAssertTrue(cities[0].displayTitle.contains("上海"))
    }

    // MARK: - 2. ESPN 实时记分牌解析与灵动岛胶囊同步测试

    @MainActor
    func testESPNScoreboardParserAndIslandSync() throws {
        let espnJSON = """
        {
          "events": [
            {
              "id": "401704812",
              "name": "Golden State Warriors at Los Angeles Lakers",
              "competitions": [
                {
                  "id": "401704812",
                  "status": {
                    "clock": 135.0,
                    "displayClock": "2:15",
                    "period": 4,
                    "type": {
                      "state": "in",
                      "completed": false,
                      "detail": "2:15 - 4th Quarter",
                      "shortDetail": "2:15 - 4th"
                    }
                  },
                  "competitors": [
                    {
                      "id": "13",
                      "homeAway": "home",
                      "score": "112",
                      "team": {
                        "abbreviation": "LAL",
                        "shortDisplayName": "Lakers",
                        "displayName": "Los Angeles Lakers"
                      }
                    },
                    {
                      "id": "9",
                      "homeAway": "away",
                      "score": "109",
                      "team": {
                        "abbreviation": "GSW",
                        "shortDisplayName": "Warriors",
                        "displayName": "Golden State Warriors"
                      }
                    }
                  ]
                }
              ]
            },
            {
              "id": "401704899",
              "name": "Boston Celtics at Miami Heat",
              "competitions": [
                {
                  "id": "401704899",
                  "status": {
                    "displayClock": "0.0",
                    "period": 4,
                    "type": {
                      "state": "post",
                      "completed": true,
                      "shortDetail": "Final"
                    }
                  },
                  "competitors": [
                    {
                      "homeAway": "home",
                      "score": "98",
                      "team": { "abbreviation": "MIA", "shortDisplayName": "Heat" }
                    },
                    {
                      "homeAway": "away",
                      "score": "104",
                      "team": { "abbreviation": "BOS", "shortDisplayName": "Celtics" }
                    }
                  ]
                }
              ]
            }
          ]
        }
        """

        let matches = try ESPNScoreboardParser.parse(data: Data(espnJSON.utf8), league: "basketball/nba")
        XCTAssertEqual(matches.count, 2)

        let liveGame = matches[0]
        XCTAssertEqual(liveGame.homeTeamAbbr, "LAL")
        XCTAssertEqual(liveGame.awayTeamAbbr, "GSW")
        XCTAssertEqual(liveGame.homeScore, "112")
        XCTAssertEqual(liveGame.awayScore, "109")
        XCTAssertEqual(liveGame.state, .live)
        XCTAssertTrue(liveGame.isLive)
        XCTAssertTrue(liveGame.periodText.contains("4") || liveGame.periodText.contains("2:15"))

        let finishedGame = matches[1]
        XCTAssertEqual(finishedGame.state, .finished)
        XCTAssertFalse(finishedGame.isLive)

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let settingsStore = SettingsStore(fileURL: tempDir.appendingPathComponent("settings.json"))
        settingsStore.settings.enableSportsLiveActivity = true
        let stateMachine = IslandStateMachine()
        let service = SportsLiveService(
            settingsStore: settingsStore,
            stateMachine: stateMachine,
            cacheURL: tempDir.appendingPathComponent("sports-cache.json")
        )

        service.syncLiveActivities(with: matches)
        XCTAssertEqual(stateMachine.displayState, .pill)
        XCTAssertEqual(stateMachine.primaryActivity?.category, .sports)
        XCTAssertTrue(stateMachine.primaryActivity?.title.contains("GSW") == true)
        XCTAssertTrue(stateMachine.primaryActivity?.title.contains("LAL") == true)
    }

    // MARK: - 3. Yahoo Finance 股票与 Binance 加密货币行情解析测试

    func testYahooChartParserExtractsPriceChangeAndSparkline() throws {
        let yahooJSON = """
        {
          "chart": {
            "result": [
              {
                "meta": {
                  "currency": "USD",
                  "symbol": "NVDA",
                  "shortName": "NVIDIA Corp",
                  "regularMarketPrice": 145.20,
                  "chartPreviousClose": 140.00,
                  "regularMarketDayHigh": 146.50,
                  "regularMarketDayLow": 141.10
                },
                "timestamp": [1730817000, 1730817900, 1730818800, 1730819700],
                "indicators": {
                  "quote": [
                    {
                      "close": [141.5, null, 143.8, 145.2]
                    }
                  ]
                }
              }
            ],
            "error": null
          }
        }
        """

        let quote = try YahooChartParser.parse(data: Data(yahooJSON.utf8), symbol: "NVDA")
        XCTAssertEqual(quote.symbol, "NVDA")
        XCTAssertEqual(quote.kind, .stock)
        XCTAssertEqual(quote.price, 145.20, accuracy: 0.001)
        XCTAssertEqual(quote.previousClose, 140.00, accuracy: 0.001)
        XCTAssertEqual(quote.changeAmount, 5.20, accuracy: 0.001)
        XCTAssertEqual(quote.changePercent, (5.20 / 140.00) * 100.0, accuracy: 0.01)
        XCTAssertEqual(quote.sparkline, [141.5, 143.8, 145.2])
        XCTAssertTrue(quote.isPositive)
    }

    func testBinanceTickerParserExtracts24hrStatsAndSparkline() throws {
        let binanceJSON = """
        {
          "symbol": "BTCUSDT",
          "priceChange": "-1520.00000000",
          "priceChangePercent": "-2.150",
          "weightedAvgPrice": "69850.50000000",
          "prevClosePrice": "70698.00000000",
          "lastPrice": "69178.00000000",
          "openPrice": "70698.00000000",
          "highPrice": "71200.00000000",
          "lowPrice": "68800.00000000",
          "volume": "24819.12000000"
        }
        """

        let quote = try BinanceTickerParser.parse(data: Data(binanceJSON.utf8))
        XCTAssertEqual(quote.symbol, "BTCUSDT")
        XCTAssertEqual(quote.kind, .crypto)
        XCTAssertEqual(quote.price, 69178.0, accuracy: 0.01)
        XCTAssertEqual(quote.changePercent, -2.15, accuracy: 0.01)
        XCTAssertFalse(quote.isPositive)
        XCTAssertGreaterThanOrEqual(quote.sparkline.count, 3)
        XCTAssertEqual(quote.sparkline.last ?? 0, 69178.0, accuracy: 0.01)
    }

    // MARK: - 4. 日历备注会议链接提取测试（Zoom / 腾讯会议 / 飞书 / Google Meet）

    func testMeetingLinkExtractorSupportsZoomTencentFeishuAndGoogleMeet() {
        let zoomNotes = "请准时参加架构评审（入会链接：https://us06web.zoom.us/j/89234561234?pwd=xyz987），密码 123456。"
        XCTAssertEqual(
            MeetingLinkExtractor.extractJoinURL(from: zoomNotes)?.absoluteString,
            "https://us06web.zoom.us/j/89234561234?pwd=xyz987"
        )

        let tencentNotes = """
        邀请您参加腾讯会议
        会议主题：星岛 v1.0 发版同步会
        点击链接入会，或添加至会议列表：
        https://meeting.tencent.com/dm/K8pLmN2qRsTu
        #腾讯会议：842-910-332
        """
        XCTAssertEqual(
            MeetingLinkExtractor.extractJoinURL(from: tencentNotes)?.absoluteString,
            "https://meeting.tencent.com/dm/K8pLmN2qRsTu"
        )

        let feishuNotes = "飞书视频会议：https://vc.feishu.cn/j/591028374，请提前调试麦克风。"
        XCTAssertEqual(
            MeetingLinkExtractor.extractJoinURL(from: feishuNotes)?.absoluteString,
            "https://vc.feishu.cn/j/591028374"
        )

        let gmeetNotes = "Weekly Sync - Join via Google Meet: https://meet.google.com/hyx-pqrs-tuv."
        XCTAssertEqual(
            MeetingLinkExtractor.extractJoinURL(from: gmeetNotes)?.absoluteString,
            "https://meet.google.com/hyx-pqrs-tuv"
        )

        let nonMeetingNotes = "参考文档：https://developer.apple.com/documentation/eventkit 无需线上会议"
        XCTAssertNil(MeetingLinkExtractor.extractJoinURL(from: nonMeetingNotes))
    }

    // MARK: - 5. /etc/hosts 受管屏蔽块幂等注入与无损移除测试

    func testHostsBlocklistRendererIdempotentApplyAndLosslessRestore() {
        let originalHosts = """
        ##
        # Host Database
        # localhost is used to configure the loopback interface
        ##
        127.0.0.1\tlocalhost
        255.255.255.255\tbroadcasthost
        ::1             localhost
        # Custom developer mapping
        127.0.0.1       local.dev.internal
        """

        let blockedOnce = HostsBlocklistRenderer.applyBlockDomains(
            ["https://weibo.com/hot", "bilibili.com", "WEIBO.COM"],
            to: originalHosts
        )

        XCTAssertTrue(blockedOnce.contains("# BEGIN STARISLAND FOCUS"))
        XCTAssertTrue(blockedOnce.contains("# END STARISLAND FOCUS"))
        XCTAssertTrue(blockedOnce.contains("127.0.0.1 weibo.com"))
        XCTAssertTrue(blockedOnce.contains("127.0.0.1 www.weibo.com"))
        XCTAssertTrue(blockedOnce.contains("127.0.0.1 bilibili.com"))
        XCTAssertTrue(blockedOnce.contains("::1 bilibili.com"))
        XCTAssertTrue(blockedOnce.contains("127.0.0.1       local.dev.internal"))

        // 幂等性校验：重复应用相同域名，结果必须逐字符完全一致，且只有一个 BEGIN 标记
        let blockedTwice = HostsBlocklistRenderer.applyBlockDomains(
            ["bilibili.com", "weibo.com"],
            to: blockedOnce
        )
        XCTAssertEqual(blockedOnce, blockedTwice)
        XCTAssertEqual(blockedTwice.components(separatedBy: "# BEGIN STARISLAND FOCUS").count - 1, 1)

        // 无损还原校验：移除受管块后必须 100% 还原原始 hosts 内容
        let restored = HostsBlocklistRenderer.removeManagedBlock(from: blockedTwice)
        XCTAssertEqual(restored, originalHosts)
    }

    // MARK: - 6. 终端 Zsh Hook 与专注模式异常残留自愈测试

    @MainActor
    func testTerminalShellHookAndFocusCrashRecovery() async {
        XCTAssertTrue(TerminalShellHook.zshSnippet.contains("preexec"))
        XCTAssertTrue(TerminalShellHook.zshSnippet.contains("precmd"))

        let payload = #"{"event":"finish","id":"cmd-42","command":"swift build -c release","exitCode":0,"duration":12}"#
        let parsed = TerminalShellHook.parseEvent(from: Data(payload.utf8))
        XCTAssertEqual(parsed?.event, "finish")
        XCTAssertEqual(parsed?.command, "swift build -c release")
        XCTAssertEqual(parsed?.exitCode, 0)
        XCTAssertEqual(parsed?.duration, 12)

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let journal = MutationJournal(fileURL: tempDir.appendingPathComponent("journal.json"))
        journal.record(MutationRecord(kind: .focusHostsBlock, previousValue: "none", appliedValue: "weibo.com"))

        let mockHelper = MockPrivilegedHelper()
        let settingsStore = SettingsStore(fileURL: tempDir.appendingPathComponent("settings.json"))
        let stateMachine = IslandStateMachine()
        let focusService = FocusBlockerService(
            settingsStore: settingsStore,
            stateMachine: stateMachine,
            mutationJournal: journal,
            helperOverride: mockHelper
        )

        await focusService.recoverPendingMutationsIfNeeded()
        XCTAssertEqual(mockHelper.lastAppliedDomains, [])
        XCTAssertTrue(journal.pendingRecords().isEmpty)
    }

    // MARK: - 7. 夜间天气映射、温度单位转换与异常容错测试

    @MainActor
    func testWeatherNightMappingTemperatureUnitAndInvalidJSON() throws {
        let nightMapping = OpenMeteoParser.mapWeatherCode(0, isDay: false)
        XCTAssertEqual(nightMapping.text, "晴朗")
        XCTAssertEqual(nightMapping.symbol, "moon.stars.fill")

        let stormMapping = OpenMeteoParser.mapWeatherCode(95, isDay: true)
        XCTAssertEqual(stormMapping.text, "雷阵雨")
        XCTAssertEqual(stormMapping.symbol, "cloud.bolt.rain.fill")

        XCTAssertThrowsError(try OpenMeteoParser.parse(data: Data("not-json".utf8), cityName: "深圳"))

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store = SettingsStore(fileURL: tempDir.appendingPathComponent("settings.json"))
        let service = WeatherService(
            settingsStore: store,
            stateMachine: IslandStateMachine(),
            cacheURL: tempDir.appendingPathComponent("weather.json")
        )
        store.settings.weatherUseCelsius = true
        XCTAssertEqual(service.formattedTemperature(25.0), "25°C")
        store.settings.weatherUseCelsius = false
        XCTAssertEqual(service.formattedTemperature(25.0), "77°F")
    }

    // MARK: - 8. 体育比分变化庆祝提醒、足球赛事解析与完赛下岛测试

    @MainActor
    func testSportsGoalCelebrationAndFinishedDismissal() throws {
        let soccerJSON = """
        {
          "events": [{
            "id": "7001",
            "name": "Arsenal at Liverpool",
            "competitions": [{
              "id": "7001",
              "status": { "displayClock": "78'", "period": 2, "type": { "state": "in", "completed": false } },
              "competitors": [
                { "homeAway": "home", "score": "2", "team": { "abbreviation": "LIV", "shortDisplayName": "Liverpool" } },
                { "homeAway": "away", "score": "1", "team": { "abbreviation": "ARS", "shortDisplayName": "Arsenal" } }
              ]
            }]
          }]
        }
        """
        var matches = try ESPNScoreboardParser.parse(data: Data(soccerJSON.utf8), league: "soccer/eng.1")
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].periodText, "下半场 78'")

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store = SettingsStore(fileURL: tempDir.appendingPathComponent("settings.json"))
        let sm = IslandStateMachine()
        let service = SportsLiveService(settingsStore: store, stateMachine: sm, cacheURL: tempDir.appendingPathComponent("s.json"))

        service.syncLiveActivities(with: matches)
        XCTAssertNil(service.celebratingMatchID)

        // 模拟客队进球扳平 2:2 -> 触发庆祝
        let equalized = LiveMatch(
            id: "7001", league: "soccer/eng.1", eventName: "Arsenal at Liverpool",
            homeTeamAbbr: "LIV", homeTeamName: "Liverpool", homeScore: "2",
            awayTeamAbbr: "ARS", awayTeamName: "Arsenal", awayScore: "2",
            periodNumber: 2, displayClock: "86'", periodText: "下半场 86'", state: .live
        )
        service.syncLiveActivities(with: [equalized])
        XCTAssertEqual(service.celebratingMatchID, "7001")
        XCTAssertTrue(sm.activities.contains(where: { $0.id == "sports.goal.7001" && $0.isPeek }))

        // 完赛后自动移除常驻实况胶囊
        sm.dismiss(id: "sports.goal.7001")
        matches = [LiveMatch(
            id: "7001", league: "soccer/eng.1", eventName: "Arsenal at Liverpool",
            homeTeamAbbr: "LIV", homeTeamName: "Liverpool", homeScore: "2",
            awayTeamAbbr: "ARS", awayTeamName: "Arsenal", awayScore: "2",
            periodNumber: 2, displayClock: "90'", periodText: "已结束", state: .finished
        )]
        service.syncLiveActivities(with: matches)
        XCTAssertEqual(sm.displayState, .compact)
    }

    // MARK: - 9. 计时器与终端实时活动状态机闭环测试

    @MainActor
    func testTimersAndTerminalActivityLifecycle() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store = SettingsStore(fileURL: tempDir.appendingPathComponent("settings.json"))
        let sm = IslandStateMachine()
        let timers = TimersEyeBreakManager(settingsStore: store, stateMachine: sm)

        timers.startPomodoro(minutes: 25)
        XCTAssertEqual(timers.timers.count, 1)
        XCTAssertEqual(sm.displayState, .pill)
        if let firstID = timers.timers.first?.id {
            timers.removeTimer(id: firstID)
        }
        XCTAssertEqual(sm.displayState, .compact)

        let terminal = TerminalActivityService(settingsStore: store, stateMachine: sm)
        terminal.ingest(TerminalHookEvent(event: "start", id: "job-9", command: "xcodebuild archive"))
        XCTAssertEqual(terminal.runningCommands.count, 1)
        XCTAssertEqual(sm.displayState, .pill)

        terminal.ingest(TerminalHookEvent(event: "finish", id: "job-9", command: "xcodebuild archive", exitCode: 0, duration: 14))
        XCTAssertTrue(terminal.runningCommands.isEmpty)
        XCTAssertEqual(sm.displayState, .peek)
    }
}

private final class MockPrivilegedHelper: PrivilegedHelperProtocol, @unchecked Sendable {
    var lastAppliedDomains: [String]?

    func ping() async -> Bool { true }
    func readHardwareSnapshot() async -> BatteryHardwareSnapshot? { nil }
    func setChargeInhibit(_ inhibit: Bool, chargeLimit: Int) async -> Bool { true }
    func setFanControl(manual: Bool, targetRPM: Int) async -> Bool { true }
    func applyManagedBlockedDomains(_ domains: [String]) async -> Bool {
        lastAppliedDomains = domains
        return true
    }
    func installStagedUpdate(from stagedAppPath: String, to targetAppPath: String) async throws -> Bool { true }
}
