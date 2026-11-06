//
//  ShopifyOrdersView.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2026-08-31

import SwiftUI

struct ShopifyOrdersView: View {
    @Environment(\.navigationStack) private var navigationStack
    @StateObject private var shopify = ShopifyService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bag.fill")
                    .foregroundStyle(.green)
                Text("Shopify 订单")
                    .font(.headline)
                Spacer()
                Button {
                    Task { await shopify.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("刷新订单")
                .disabled(shopify.isLoading || !shopify.isConfigured)
            }

            if !shopify.isConfigured {
                Text("请在“设置”的 Shopify 页面中连接 Shopify，以查看近期订单。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if shopify.isLoading && shopify.orders.isEmpty {
                ProgressView().frame(maxWidth: .infinity)
            } else if let error = shopify.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if shopify.orders.isEmpty {
                Text("未找到订单。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(shopify.orders.prefix(5)) { order in
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(order.name).font(.system(size: 13, weight: .semibold))
                            Text(order.customerDisplayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(order.currency) \(order.totalPrice)")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                            Text(Self.localizedStatus(order.financialStatus))
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
        }
        .padding()
        .task {
            if shopify.isConfigured { await shopify.refresh() }
        }
    }

    private static func localizedStatus(_ raw: String?) -> String {
        guard let raw = raw?.lowercased(), !raw.isEmpty else { return "未知" }
        switch raw {
        case "paid": return "已付款"
        case "pending": return "待付款"
        case "authorized": return "已授权"
        case "partially_paid": return "部分付款"
        case "refunded": return "已退款"
        case "partially_refunded": return "部分退款"
        case "voided": return "已作废"
        case "expired": return "已过期"
        case "unknown": return "未知"
        default: return raw.capitalized
        }
    }
}