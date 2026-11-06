//
//  FinanceWidgetView.swift
//  Sapphire
//

import SwiftUI

struct StarIslandSparklineShape: Shape {
    let points: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard points.count >= 2, rect.width > 1, rect.height > 1 else { return path }
        let minV = points.min() ?? 0
        let maxV = points.max() ?? 1
        let span = max(maxV - minV, 1e-6)

        for (i, val) in points.enumerated() {
            let x = rect.minX + CGFloat(i) / CGFloat(points.count - 1) * rect.width
            let y = rect.maxY - CGFloat((val - minV) / span) * rect.height
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}

struct FinanceWidgetView: View {
    @ObservedObject private var service = FinanceAPIService.shared
    @ObservedObject private var settingsModel = SettingsModel.shared

    private var activeSymbol: String {
        settingsModel.settings.currentFinanceFavoriteSymbol() ?? "AAPL"
    }

    private var quote: FinanceQuote? {
        service.quotesBySymbol[activeSymbol.uppercased()] ?? service.cachedQuote(symbol: activeSymbol)
    }

    private var payload: FinancePayload {
        service.makePayload(symbol: activeSymbol, index: 0, quote: quote)
    }

    var body: some View {
        let tint: Color = payload.isPositive ? .green : .red
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(payload.symbol)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Spacer()
                Text(payload.changePercent)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(tint.opacity(0.22)))
                    .foregroundStyle(tint)
            }

            if let sparkline = quote?.sparkline, sparkline.count >= 2 {
                StarIslandSparklineShape(points: sparkline)
                    .stroke(tint, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                    .frame(height: 22)
            } else {
                Spacer(minLength: 10)
            }

            HStack(alignment: .firstTextBaseline) {
                Text(payload.price)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Spacer()
                Text(payload.name)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 190, height: 90)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.07)))
        .foregroundStyle(.white)
        .task {
            _ = await service.fetchQuote(symbol: activeSymbol)
        }
    }
}
