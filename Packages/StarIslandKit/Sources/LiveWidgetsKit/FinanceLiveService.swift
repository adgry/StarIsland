import Combine
import Foundation
import IslandCore
import SwiftUI

public enum FinanceParseError: LocalizedError, Equatable, Sendable {
    case invalidPayload
    case emptyChartResult
    case networkFailure(String)

    public var errorDescription: String? {
        switch self {
        case .invalidPayload:
            return "行情数据格式无法解析"
        case .emptyChartResult:
            return "未查询到对应证券或加密货币行情"
        case .networkFailure(let detail):
            return "请求实时行情失败：\(detail)"
        }
    }
}

public enum MarketAssetKind: String, Codable, Equatable, Sendable {
    case stock
    case crypto
}

public struct MarketQuote: Codable, Equatable, Identifiable, Sendable {
    public var id: String { symbol }
    public let symbol: String
    public let displayName: String
    public let kind: MarketAssetKind
    public let price: Double
    public let previousClose: Double
    public let changeAmount: Double
    public let changePercent: Double
    public let currency: String
    public let sparkline: [Double]
    public let high24h: Double?
    public let low24h: Double?
    public let updatedAt: Date

    public var isPositive: Bool { changePercent >= 0 }

    public var formattedPrice: String {
        if price >= 1000 {
            return String(format: "%.2f", price)
        } else if price >= 1 {
            return String(format: "%.2f", price)
        } else {
            return String(format: "%.4f", price)
        }
    }

    public var formattedChangePercent: String {
        let sign = changePercent >= 0 ? "+" : ""
        return String(format: "%@%.2f%%", sign, changePercent)
    }

    public init(
        symbol: String,
        displayName: String,
        kind: MarketAssetKind,
        price: Double,
        previousClose: Double,
        changeAmount: Double,
        changePercent: Double,
        currency: String,
        sparkline: [Double],
        high24h: Double? = nil,
        low24h: Double? = nil,
        updatedAt: Date = Date()
    ) {
        self.symbol = symbol
        self.displayName = displayName
        self.kind = kind
        self.price = price
        self.previousClose = previousClose
        self.changeAmount = changeAmount
        self.changePercent = changePercent
        self.currency = currency
        self.sparkline = sparkline
        self.high24h = high24h
        self.low24h = low24h
        self.updatedAt = updatedAt
    }
}

public enum YahooChartParser {
    private struct ChartEnvelopeDTO: Decodable {
        struct ChartBodyDTO: Decodable {
            struct ResultDTO: Decodable {
                struct MetaDTO: Decodable {
                    let currency: String?
                    let symbol: String?
                    let shortName: String?
                    let longName: String?
                    let regularMarketPrice: Double?
                    let chartPreviousClose: Double?
                    let previousClose: Double?
                    let regularMarketDayHigh: Double?
                    let regularMarketDayLow: Double?
                }

                struct IndicatorsDTO: Decodable {
                    struct QuoteSeriesDTO: Decodable {
                        let close: [Double?]?
                    }
                    let quote: [QuoteSeriesDTO]?
                }

                let meta: MetaDTO
                let indicators: IndicatorsDTO?
            }

            let result: [ResultDTO]?
        }

        let chart: ChartBodyDTO
    }

    public static func parse(data: Data, symbol: String, now: Date = Date()) throws -> MarketQuote {
        let envelope: ChartEnvelopeDTO
        do {
            envelope = try JSONDecoder().decode(ChartEnvelopeDTO.self, from: data)
        } catch {
            throw FinanceParseError.invalidPayload
        }

        guard let first = envelope.chart.result?.first else {
            throw FinanceParseError.emptyChartResult
        }

        let meta = first.meta
        let rawCloses = first.indicators?.quote?.first?.close?.compactMap { $0 }.filter { $0.isFinite } ?? []
        guard let currentPrice = meta.regularMarketPrice ?? rawCloses.last else {
            throw FinanceParseError.emptyChartResult
        }

        let prevClose = meta.chartPreviousClose ?? meta.previousClose ?? rawCloses.first ?? currentPrice
        let changeAmt = currentPrice - prevClose
        let changePct = prevClose != 0 ? (changeAmt / prevClose) * 100.0 : 0.0

        let series: [Double]
        if rawCloses.isEmpty {
            series = [prevClose, currentPrice]
        } else if rawCloses.count > 36 {
            series = downsample(rawCloses, targetCount: 32)
        } else {
            series = rawCloses
        }

        let resolvedSymbol = (meta.symbol ?? symbol).uppercased()
        let name = meta.shortName ?? meta.longName ?? resolvedSymbol

        return MarketQuote(
            symbol: resolvedSymbol,
            displayName: name,
            kind: .stock,
            price: currentPrice,
            previousClose: prevClose,
            changeAmount: changeAmt,
            changePercent: changePct,
            currency: meta.currency ?? "USD",
            sparkline: series,
            high24h: meta.regularMarketDayHigh,
            low24h: meta.regularMarketDayLow,
            updatedAt: now
        )
    }

    private static func downsample(_ values: [Double], targetCount: Int) -> [Double] {
        guard values.count > targetCount, targetCount >= 2 else { return values }
        var sampled: [Double] = []
        sampled.reserveCapacity(targetCount)
        let step = Double(values.count - 1) / Double(targetCount - 1)
        for i in 0..<targetCount {
            let idx = min(values.count - 1, Int((Double(i) * step).rounded()))
            sampled.append(values[idx])
        }
        return sampled
    }
}

public enum BinanceTickerParser {
    private struct FlexibleDouble: Decodable {
        let value: Double

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let num = try? container.decode(Double.self) {
                self.value = num
            } else if let str = try? container.decode(String.self), let parsed = Double(str) {
                self.value = parsed
            } else {
                throw FinanceParseError.invalidPayload
            }
        }
    }

    private struct Ticker24hrDTO: Decodable {
        let symbol: String
        let priceChange: FlexibleDouble?
        let priceChangePercent: FlexibleDouble
        let weightedAvgPrice: FlexibleDouble?
        let prevClosePrice: FlexibleDouble?
        let lastPrice: FlexibleDouble
        let openPrice: FlexibleDouble?
        let highPrice: FlexibleDouble?
        let lowPrice: FlexibleDouble?
    }

    public static func parse(
        data: Data,
        klineSparkline: [Double]? = nil,
        now: Date = Date()
    ) throws -> MarketQuote {
        let dto: Ticker24hrDTO
        do {
            dto = try JSONDecoder().decode(Ticker24hrDTO.self, from: data)
        } catch {
            throw FinanceParseError.invalidPayload
        }

        let last = dto.lastPrice.value
        let open = dto.openPrice?.value ?? dto.prevClosePrice?.value ?? last
        let changeAmt = dto.priceChange?.value ?? (last - open)
        let changePct = dto.priceChangePercent.value
        let high = dto.highPrice?.value
        let low = dto.lowPrice?.value
        let weighted = dto.weightedAvgPrice?.value ?? ((open + last) / 2.0)

        let sparkline: [Double]
        if let klineSparkline, klineSparkline.count >= 3 {
            var copy = klineSparkline
            copy[copy.count - 1] = last
            sparkline = copy
        } else {
            let midFirst = changePct >= 0 ? (low ?? open) : (high ?? open)
            let midSecond = changePct >= 0 ? (high ?? weighted) : (low ?? weighted)
            sparkline = [open, midFirst, weighted, midSecond, last]
        }

        let cleanName = dto.symbol.uppercased()
            .replacingOccurrences(of: "USDT", with: " / USDT")
            .replacingOccurrences(of: "USDC", with: " / USDC")

        return MarketQuote(
            symbol: dto.symbol.uppercased(),
            displayName: cleanName,
            kind: .crypto,
            price: last,
            previousClose: open,
            changeAmount: changeAmt,
            changePercent: changePct,
            currency: "USDT",
            sparkline: sparkline,
            high24h: high,
            low24h: low,
            updatedAt: now
        )
    }

    public static func parseKlineCloses(data: Data) -> [Double]? {
        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [[Any]] else {
            return nil
        }
        let closes: [Double] = raw.compactMap { row in
            guard row.count > 4 else { return nil }
            if let str = row[4] as? String { return Double(str) }
            if let num = row[4] as? NSNumber { return num.doubleValue }
            return nil
        }
        return closes.count >= 3 ? closes : nil
    }
}

public struct SparklineShape: Shape {
    public let points: [Double]
    public let closedBottom: Bool

    public init(points: [Double], closedBottom: Bool = false) {
        self.points = points
        self.closedBottom = closedBottom
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        guard points.count >= 2, rect.width > 1, rect.height > 1 else { return path }

        let minVal = points.min() ?? 0
        let maxVal = points.max() ?? 1
        let span = max(maxVal - minVal, 1e-6)

        func point(at index: Int) -> CGPoint {
            let x = rect.minX + CGFloat(index) / CGFloat(points.count - 1) * rect.width
            let normalized = (points[index] - minVal) / span
            let insetY = rect.height * 0.1
            let usableH = rect.height * 0.8
            let y = rect.maxY - insetY - CGFloat(normalized) * usableH
            return CGPoint(x: x, y: y)
        }

        let firstPt = point(at: 0)
        path.move(to: firstPt)

        for idx in 1..<points.count {
            let prev = point(at: idx - 1)
            let curr = point(at: idx)
            let mid = CGPoint(x: (prev.x + curr.x) * 0.5, y: (prev.y + curr.y) * 0.5)
            path.addQuadCurve(to: mid, control: prev)
            if idx == points.count - 1 {
                path.addQuadCurve(to: curr, control: curr)
            }
        }

        if closedBottom {
            let lastPt = point(at: points.count - 1)
            path.addLine(to: CGPoint(x: lastPt.x, y: rect.maxY))
            path.addLine(to: CGPoint(x: firstPt.x, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }
}

public struct MarketSparklineView: View {
    public let points: [Double]
    public let isPositive: Bool

    public init(points: [Double], isPositive: Bool) {
        self.points = points
        self.isPositive = isPositive
    }

    public var body: some View {
        let tint = isPositive ? Color.green : Color.red
        ZStack {
            SparklineShape(points: points, closedBottom: true)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.28), tint.opacity(0.01)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            SparklineShape(points: points, closedBottom: false)
                .stroke(tint, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
        }
    }
}

@MainActor
public final class FinanceLiveService: ObservableObject {
    public static let shared = FinanceLiveService()

    @Published public private(set) var quotes: [MarketQuote] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var errorMessage: String?
    @Published public var alertThresholdPercent: Double = 5.0

    private let settingsStore: SettingsStore
    private let stateMachine: IslandStateMachine
    private let session: URLSession
    private let cacheURL: URL
    private var pollingTask: Task<Void, Never>?
    private var alertedSymbols: Set<String> = []
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
            config.httpAdditionalHeaders = [
                "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15"
            ]
            self.session = URLSession(configuration: config)
        }
        self.cacheURL = cacheURL ?? StarIslandPaths.cachesDirectory.appendingPathComponent("finance-cache.json")
        loadCachedQuotes()
    }

    public static func isCryptoSymbol(_ symbol: String) -> Bool {
        let upper = symbol.uppercased()
        return upper.hasSuffix("USDT") || upper.hasSuffix("USDC") || upper.hasSuffix("BUSD") || upper.hasSuffix("FDUSD")
    }

    public func startAutoRefresh(interval: TimeInterval = 45) {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refresh()
                let backoff = min(240.0, pow(2.0, Double(self.consecutiveFailures)) * 5.0)
                let delay = self.consecutiveFailures > 0 ? backoff : max(20.0, interval)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    public func stopAutoRefresh() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    public func addSymbol(_ raw: String) async {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleaned.isEmpty else { return }
        if !settingsStore.settings.watchlistSymbols.contains(cleaned) {
            settingsStore.settings.watchlistSymbols.append(cleaned)
        }
        await refresh()
    }

    public func removeSymbol(_ symbol: String) {
        let upper = symbol.uppercased()
        settingsStore.settings.watchlistSymbols.removeAll { $0.uppercased() == upper }
        quotes.removeAll { $0.symbol.uppercased() == upper }
        persistQuotes(quotes)
    }

    public func refresh() async {
        guard settingsStore.settings.enableFinanceWidget else { return }
        let symbols = settingsStore.settings.watchlistSymbols
        guard !symbols.isEmpty else {
            quotes = []
            return
        }

        isLoading = true
        defer { isLoading = false }

        var fetchedBySymbol: [String: MarketQuote] = [:]
        var lastErr: Error?
        let localSession = session

        for sym in symbols {
            do {
                let quote = try await Self.fetchSingleQuote(symbol: sym, session: localSession)
                fetchedBySymbol[sym.uppercased()] = quote
            } catch {
                lastErr = error
            }
        }

        if fetchedBySymbol.isEmpty, let lastErr {
            consecutiveFailures += 1
            errorMessage = lastErr.localizedDescription
            return
        }

        consecutiveFailures = 0
        errorMessage = nil
        let existingMap = Dictionary(uniqueKeysWithValues: quotes.map { ($0.symbol.uppercased(), $0) })
        let ordered = symbols.compactMap { sym -> MarketQuote? in
            let key = sym.uppercased()
            return fetchedBySymbol[key] ?? existingMap[key]
        }
        quotes = ordered
        persistQuotes(ordered)
        checkVolatilityAlerts(for: ordered)
    }

    private static func fetchSingleQuote(symbol: String, session: URLSession) async throws -> MarketQuote {
        let upper = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if isCryptoSymbol(upper) {
            guard let tickerURL = URL(string: "https://api.binance.com/api/v3/ticker/24hr?symbol=\(upper)") else {
                throw FinanceParseError.invalidPayload
            }
            let (tickerData, response) = try await session.data(from: tickerURL)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw FinanceParseError.networkFailure("Binance HTTP \(http.statusCode)")
            }
            var klineSeries: [Double]?
            if let klineURL = URL(string: "https://api.binance.com/api/v3/klines?symbol=\(upper)&interval=1h&limit=24"),
               let (klineData, _) = try? await session.data(from: klineURL) {
                klineSeries = BinanceTickerParser.parseKlineCloses(data: klineData)
            }
            return try BinanceTickerParser.parse(data: tickerData, klineSparkline: klineSeries)
        } else {
            let encoded = upper.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? upper
            guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(encoded)?interval=15m&range=1d") else {
                throw FinanceParseError.invalidPayload
            }
            let (data, response) = try await session.data(from: url)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw FinanceParseError.networkFailure("Yahoo HTTP \(http.statusCode)")
            }
            return try YahooChartParser.parse(data: data, symbol: upper)
        }
    }

    private func checkVolatilityAlerts(for items: [MarketQuote]) {
        for quote in items where abs(quote.changePercent) >= alertThresholdPercent {
            guard !alertedSymbols.contains(quote.symbol) else { continue }
            alertedSymbols.insert(quote.symbol)
            stateMachine.submit(
                IslandActivityItem(
                    id: "finance.alert.\(quote.symbol)",
                    category: .finance,
                    title: "\(quote.symbol) 异动 \(quote.formattedChangePercent)",
                    subtitle: "最新价 \(quote.formattedPrice) \(quote.currency)",
                    iconSymbol: quote.isPositive ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis",
                    trailingBadge: quote.formattedChangePercent,
                    priority: .interactive,
                    isPeek: true,
                    autoDismissAfter: 4.0
                )
            )
        }
    }

    private func loadCachedQuotes() {
        guard let data = try? Data(contentsOf: cacheURL),
              let decoded = try? JSONDecoder().decode([MarketQuote].self, from: data) else {
            return
        }
        quotes = decoded
    }

    private func persistQuotes(_ items: [MarketQuote]) {
        let dir = cacheURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: cacheURL, options: .atomic)
        }
    }
}
