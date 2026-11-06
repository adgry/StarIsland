import XCTest
@testable import Sapphire

final class StarIslandWidgetsAPITests: XCTestCase {

    func testESPNScoreboardParsingAndSportLayoutResolution() {
        let sampleESPN = """
        {
          "events": [
            {
              "id": "401704891",
              "name": "Golden State Warriors at Los Angeles Lakers",
              "shortName": "GSW @ LAL",
              "competitions": [
                {
                  "id": "401704891",
                  "status": {
                    "displayClock": "02:14",
                    "period": 4,
                    "type": {
                      "state": "in",
                      "completed": false,
                      "shortDetail": "2:14 - 4th"
                    }
                  },
                  "competitors": [
                    {
                      "homeAway": "home",
                      "score": "112",
                      "team": {
                        "abbreviation": "LAL",
                        "shortDisplayName": "Lakers",
                        "displayName": "Los Angeles Lakers",
                        "logo": "https://a.espncdn.com/i/teamlogos/nba/500/lal.png"
                      }
                    },
                    {
                      "homeAway": "away",
                      "score": "109",
                      "team": {
                        "abbreviation": "GSW",
                        "shortDisplayName": "Warriors",
                        "displayName": "Golden State Warriors",
                        "logo": "https://a.espncdn.com/i/teamlogos/nba/500/gs.png"
                      }
                    }
                  ]
                }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let route = ESPNLeagueRoute(sport: "basketball", league: "nba", displayName: "NBA", shortName: "NBA")
        let events = SportsAPIService.parseESPNScoreboard(data: sampleESPN, leagueRoute: route)

        XCTAssertEqual(events.count, 1)
        let first = events[0]
        XCTAssertEqual(first.homeTeam, "Lakers")
        XCTAssertEqual(first.awayTeam, "Warriors")
        XCTAssertEqual(first.homeScore, 112)
        XCTAssertEqual(first.awayScore, 109)
        XCTAssertTrue(first.isLive)
        XCTAssertTrue(first.clock.contains("02:14"))
        XCTAssertNotNil(first.homeLogoURL)

        let payload = SportsFinanceContentProvider.makeSportsPayload(from: first)
        XCTAssertEqual(payload.league, "NBA")
        XCTAssertEqual(payload.homeScore, 112)
        XCTAssertEqual(payload.awayScore, 109)

        XCTAssertEqual(SportLayoutRegistry.resolve(league: "NBA"), .basketball)
        XCTAssertEqual(SportLayoutRegistry.resolve(league: "英超 EPL Soccer"), .soccer)
        XCTAssertEqual(SportLayoutRegistry.resolve(league: "NFL"), .football)
        XCTAssertEqual(SportLayoutRegistry.resolve(league: "Formula 1 F1"), .racing)
        XCTAssertEqual(SportLayoutRegistry.resolve(league: "MLB"), .baseball)
    }

    func testYahooFinanceAndBinanceTickerParsingAndPayloadFormatting() {
        let yahooJSON = """
        {
          "chart": {
            "result": [
              {
                "meta": {
                  "currency": "USD",
                  "symbol": "AAPL",
                  "shortName": "Apple Inc.",
                  "regularMarketPrice": 228.50,
                  "chartPreviousClose": 225.00
                },
                "indicators": {
                  "quote": [
                    { "close": [225.0, 226.4, 227.8, 228.5] }
                  ]
                }
              }
            ]
          }
        }
        """.data(using: .utf8)!

        let stockQuote = FinanceAPIService.parseYahooChart(data: yahooJSON, fallbackSymbol: "AAPL")
        XCTAssertNotNil(stockQuote)
        XCTAssertEqual(stockQuote?.symbol, "AAPL")
        XCTAssertEqual(stockQuote?.name, "Apple Inc.")
        XCTAssertEqual(stockQuote?.price ?? 0, 228.50, accuracy: 0.001)
        XCTAssertEqual(stockQuote?.change ?? 0, 3.50, accuracy: 0.001)

        let positivePayload = FinanceAPIService.shared.makePayload(symbol: "AAPL", index: 0, quote: stockQuote)
        XCTAssertTrue(positivePayload.isPositive)
        XCTAssertEqual(positivePayload.price, "$228.50")
        XCTAssertTrue(positivePayload.change.hasPrefix("+"))

        let binanceJSON = """
        {
          "symbol": "BTCUSDT",
          "priceChange": "-1250.00",
          "priceChangePercent": "-1.42",
          "lastPrice": "86750.00",
          "openPrice": "88000.00"
        }
        """.data(using: .utf8)!

        let cryptoQuote = FinanceAPIService.parseBinanceTicker(data: binanceJSON, displaySymbol: "BTCUSDT")
        XCTAssertNotNil(cryptoQuote)
        XCTAssertEqual(cryptoQuote?.price ?? 0, 86750.00, accuracy: 0.01)
        XCTAssertEqual(cryptoQuote?.changePercent ?? 0, -1.42, accuracy: 0.01)

        let negativePayload = FinanceAPIService.shared.makePayload(symbol: "BTCUSDT", index: 1, quote: cryptoQuote)
        XCTAssertFalse(negativePayload.isPositive)
        XCTAssertTrue(negativePayload.changePercent.contains("-1.42%"))
    }
}
