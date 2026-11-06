//
//  FinancePlayerView.swift
//  Sapphire
//

import SwiftUI

struct FinancePlayerView: View {
    @Binding var navigationStack: [NotchWidgetMode]
    @ObservedObject private var service = FinanceAPIService.shared
    @ObservedObject private var settingsModel = SettingsModel.shared

    init(navigationStack: Binding<[NotchWidgetMode]>) {
        _navigationStack = navigationStack
    }

    private var symbols: [String] {
        let favs = settingsModel.settings.financeFavoriteSymbols
        return favs.isEmpty ? ["AAPL", "NVDA", "MSFT", "BTCUSDT"] : favs
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
                Text("全球证券与加密货币自选看板")
                    .font(.subheadline.weight(.bold))
                Spacer()

                Button {
                    Task { await service.refreshWatchlist(symbols) }
                } label: {
                    Image(systemName: service.isLoading ? "hourglass" : "arrow.clockwise")
                        .font(.caption.weight(.bold))
                }
                .buttonStyle(.plain)
            }

            ScrollView {
                VStack(spacing: 6) {
                    ForEach(Array(symbols.enumerated()), id: \.offset) { idx, sym in
                        let upper = sym.uppercased()
                        let quote = service.quotesBySymbol[upper] ?? service.cachedQuote(symbol: upper)
                        let payload = service.makePayload(symbol: upper, index: idx, quote: quote)
                        let tint: Color = payload.isPositive ? .green : .red

                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(payload.symbol)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                Text(payload.name)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(width: 110, alignment: .leading)

                            if let pts = quote?.sparkline, pts.count >= 2 {
                                StarIslandSparklineShape(points: pts)
                                    .stroke(tint, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                                    .frame(width: 90, height: 22)
                            } else {
                                Spacer()
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(payload.price)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                Text(payload.changePercent)
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundStyle(tint)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.06)))
                        .onTapGesture {
                            settingsModel.settings.financeFavoriteSymbolIndex = idx
                        }
                    }
                }
            }
            .frame(maxHeight: 165)
        }
        .padding(14)
        .frame(width: 440)
        .foregroundStyle(.white)
        .task {
            await service.refreshWatchlist(symbols)
        }
    }
}
