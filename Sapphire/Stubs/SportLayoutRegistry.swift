//
//  SportLayoutRegistry.swift
//  Sapphire
//

import Foundation

enum SportLayoutRegistry {
    static func resolve(league: String) -> SportLayoutKind {
        let lower = league.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lower.contains("nba") || lower.contains("wnba") || lower.contains("basketball") || lower.contains("篮球") {
            return .basketball
        }
        if lower.contains("soccer") || lower.contains("epl") || lower.contains("premier") || lower.contains("ucl")
            || lower.contains("champions") || lower.contains("laliga") || lower.contains("足球")
            || lower.contains("英超") || lower.contains("欧冠") || lower.contains("西甲") {
            return .soccer
        }
        if lower.contains("nfl") || lower.contains("ncaaf") || lower.contains("football") || lower.contains("橄榄球") {
            return .football
        }
        if lower.contains("mlb") || lower.contains("baseball") || lower.contains("棒球") {
            return .baseball
        }
        if lower.contains("nhl") || lower.contains("hockey") || lower.contains("冰球") {
            return .hockey
        }
        if lower.contains("f1") || lower.contains("formula") || lower.contains("racing") || lower.contains("nascar") || lower.contains("赛车") {
            return .racing
        }
        if lower.contains("ufc") || lower.contains("mma") || lower.contains("boxing") || lower.contains("格斗") {
            return .combat
        }
        if lower.contains("atp") || lower.contains("wta") || lower.contains("tennis") || lower.contains("网球") {
            return .tennis
        }
        if lower.contains("pga") || lower.contains("golf") || lower.contains("高尔夫") {
            return .golf
        }
        if lower.contains("ipl") || lower.contains("cricket") || lower.contains("板球") {
            return .cricket
        }
        return .generic
    }
}
