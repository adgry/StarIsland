//
//  FinanceAPIService.swift
//  Sapphire
//


#if !SAPPHIRE_FULL_BUILD
import Combine
import Foundation
import SwiftUI

struct FinanceQuote: Equatable {
    let symbol: String
    let price: Double
    let change: Double
    let changePercent: Double
    let name: String
    let isAfterHours: Bool
    let sparkline: [Double]

    init(
        symbol: String,
        price: Double,
        change: Double,
        changePercent: Double,
        name: String,
        isAfterHours: Bool,
        sparkline: [Double] = []
    ) {
        self.symbol = symbol
        self.price = price
        self.change = change
        self.changePercent = changePercent
        self.name = name
        self.isAfterHours = isAfterHours
        self.sparkline = sparkline
    }
}

final class FinanceAPIService: ObservableObject {
    static let shared = FinanceAPIService()

    @Published private(set) var quotesBySymbol: [String: FinanceQuote] = [:]
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var lastUpdated: Date?

    private let lock = NSLock()
    private var cache: [String: (quote: FinanceQuote, fetchedAt: Date)] = [:]
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 12
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15"
        ]
        self.session = URLSession(configuration: config)
    }

    static func isCryptoSymbol(_ symbol: String) -> Bool {
        let upper = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return upper.hasSuffix("USDT") || upper.hasSuffix("USDC") || upper.hasSuffix("BUSD") || upper.hasSuffix("FDUSD")
    }

    func cachedQuote(symbol: String) -> FinanceQuote? {
        let key = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        lock.lock()
        defer { lock.unlock() }
        return cache[key]?.quote
    }

    func makePayload(symbol: String, index: Int, quote: FinanceQuote?) -> FinancePayload {
        let resolved = quote ?? cachedQuote(symbol: symbol)
        let upper = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard let q = resolved else {
            return FinancePayload(
                symbol: upper,
                price: "$--.--",
                change: "0.00",
                changePercent: "0.00%",
                isPositive: true,
                name: upper,
                isAfterHours: false,
                closingPrice: nil
            )
        }

        let isPositive = q.change >= 0
        let sign = isPositive ? "+" : ""
        let priceFormat = q.price >= 1 ? "%.2f" : "%.4f"
        let prevClose = q.price - q.change

        return FinancePayload(
            symbol: q.symbol,
            price: "$\(String(format: priceFormat, q.price))",
            change: "\(sign)\(String(format: "%.2f", q.change))",
            changePercent: "\(sign)\(String(format: "%.2f", q.changePercent))%",
            isPositive: isPositive,
            name: q.name,
            isAfterHours: q.isAfterHours,
            closingPrice: String(format: priceFormat, prevClose)
        )
    }

    static func parseYahooChart(data: Data, fallbackSymbol: String) -> FinanceQuote? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let chart = root["chart"] as? [String: Any],
              let results = chart["result"] as? [[String: Any]],
              let first = results.first,
              let meta = first["meta"] as? [String: Any] else {
            return nil
        }

        var closes: [Double] = []
        if let indicators = first["indicators"] as? [String: Any],
           let quoteArr = indicators["quote"] as? [[String: Any]],
           let rawClose = quoteArr.first?["close"] as? [Any] {
            closes = rawClose.compactMap { ($0 as? NSNumber)?.doubleValue }.filter(\.isFinite)
        }

        let price = (meta["regularMarketPrice"] as? NSNumber)?.doubleValue ?? closes.last
        guard let currentPrice = price else { return nil }

        let prevClose = (meta["chartPreviousClose"] as? NSNumber)?.doubleValue
            ?? (meta["previousClose"] as? NSNumber)?.doubleValue
            ?? closes.first
            ?? currentPrice

        let change = currentPrice - prevClose
        let pct = prevClose != 0 ? (change / prevClose) * 100.0 : 0.0
        let sym = ((meta["symbol"] as? String) ?? fallbackSymbol).uppercased()
        let name = (meta["shortName"] as? String) ?? (meta["longName"] as? String) ?? sym
        let marketState = ((meta["marketState"] as? String) ?? "REGULAR").uppercased()
        let isAfterHours = marketState != "REGULAR" && marketState != "OPEN"
        let sparkline = closes.count >= 2 ? Array(closes.suffix(32)) : [prevClose, currentPrice]

        return FinanceQuote(
            symbol: sym,
            price: currentPrice,
            change: change,
            changePercent: pct,
            name: name,
            isAfterHours: isAfterHours,
            sparkline: sparkline
        )
    }

    static func parseBinanceTicker(data: Data, displaySymbol: String, klines: [Double]? = nil) -> FinanceQuote? {
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        func num(_ key: String) -> Double? {
            if let d = dict[key] as? Double { return d }
            if let n = dict[key] as? NSNumber { return n.doubleValue }
            if let s = dict[key] as? String { return Double(s) }
            return nil
        }
        guard let last = num("lastPrice") else { return nil }
        let open = num("openPrice") ?? num("prevClosePrice") ?? last
        let change = num("priceChange") ?? (last - open)
        let pct = num("priceChangePercent") ?? (open != 0 ? (change / open) * 100.0 : 0.0)
        let sym = ((dict["symbol"] as? String) ?? displaySymbol).uppercased()
        let cleanName = sym.replacingOccurrences(of: "USDT", with: " / USDT")
        let series = (klines?.count ?? 0) >= 2 ? klines! : [open, (open + last) * 0.5, last]

        return FinanceQuote(
            symbol: sym,
            price: last,
            change: change,
            changePercent: pct,
            name: cleanName,
            isAfterHours: false,
            sparkline: series
        )
    }
}

extension FinanceAPIService {
    func fetchQuote(symbol: String, forceRefresh: Bool = false) async -> FinanceQuote? {
        let upper = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !upper.isEmpty else { return nil }

        if !forceRefresh {
            lock.lock()
            let existing = cache[upper]
            lock.unlock()
            if let existing, Date().timeIntervalSince(existing.fetchedAt) < 30 {
                return existing.quote
            }
        }

        let fetched: FinanceQuote?
        if Self.isCryptoSymbol(upper) {
            fetched = await fetchBinance(symbol: upper)
        } else {
            fetched = await fetchYahoo(symbol: upper)
        }

        if let fetched {
            lock.lock()
            cache[upper] = (fetched, Date())
            lock.unlock()
            await MainActor.run {
                self.quotesBySymbol[upper] = fetched
                self.lastUpdated = Date()
            }
        }
        return fetched
    }

    func refreshWatchlist(_ symbols: [String]) async {
        await MainActor.run { self.isLoading = true }
        for sym in symbols {
            _ = await fetchQuote(symbol: sym, forceRefresh: true)
        }
        await MainActor.run { self.isLoading = false }
    }

    private func fetchYahoo(symbol: String) async -> FinanceQuote? {
        let encoded = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(encoded)?interval=15m&range=1d"),
              let (data, response) = try? await session.data(from: url),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            return nil
        }
        return Self.parseYahooChart(data: data, fallbackSymbol: symbol)
    }

    private func fetchBinance(symbol: String) async -> FinanceQuote? {
        guard let url = URL(string: "https://api.binance.com/api/v3/ticker/24hr?symbol=\(symbol)"),
              let (data, response) = try? await session.data(from: url),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            return nil
        }
        return Self.parseBinanceTicker(data: data, displaySymbol: symbol)
    }
}

enum FinanceLiveActivityView {
    @ViewBuilder
    static func left(for payload: FinancePayload) -> some View {
        HStack(spacing: 5) {
            Image(systemName: payload.isPositive ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(payload.isPositive ? Color.green : Color.red)
            Text(payload.symbol)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    static func right(for payload: FinancePayload) -> some View {
        HStack(spacing: 5) {
            Text(payload.price)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Text(payload.changePercent)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(payload.isPositive ? Color.green : Color.red)
        }
    }
}
#endif
