//
//  EQPreset.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2026-08-21

import Foundation

enum EQPreset: String, CaseIterable, Identifiable {
    case flat
    case bassBoost
    case bassCut
    case trebleBoost
    case vocalClarity
    case podcast
    case spokenWord
    case loudness
    case lateNight
    case smallSpeakers
    case rock
    case pop
    case electronic
    case jazz
    case classical
    case hipHop
    case rnb
    case deep
    case acoustic
    case movie

    var id: String { rawValue }

    // MARK: - Categories

    enum Category: String, CaseIterable, Identifiable {
        case utility = "实用"
        case speech = "人声"
        case listening = "聆听"
        case music = "音乐"
        case media = "影音"

        var id: String { rawValue }
    }

    var category: Category {
        switch self {
        case .flat, .bassBoost, .bassCut, .trebleBoost:
            return .utility
        case .vocalClarity, .podcast, .spokenWord:
            return .speech
        case .loudness, .lateNight, .smallSpeakers:
            return .listening
        case .rock, .pop, .electronic, .jazz, .classical, .hipHop, .rnb, .deep, .acoustic:
            return .music
        case .movie:
            return .media
        }
    }

    static func presets(for category: Category) -> [EQPreset] {
        allCases.filter { $0.category == category }
    }

    var name: String {
        switch self {
        case .flat: return "平直"
        case .bassBoost: return "低音增强"
        case .bassCut: return "低音减弱"
        case .trebleBoost: return "高音增强"
        case .vocalClarity: return "人声清晰"
        case .podcast: return "播客"
        case .spokenWord: return "口语"
        case .loudness: return "响度增强"
        case .lateNight: return "深夜"
        case .smallSpeakers: return "小型扬声器"
        case .rock: return "摇滚"
        case .pop: return "流行"
        case .electronic: return "电子"
        case .jazz: return "爵士"
        case .classical: return "古典"
        case .hipHop: return "嘻哈"
        case .rnb: return "R&B"
        case .deep: return "深沉"
        case .acoustic: return "原声"
        case .movie: return "电影"
        }
    }

    var settings: EQSettings {
        switch self {
        // MARK: - Utility
        case .flat:
            return EQSettings(bandGains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
        case .bassBoost:
            return EQSettings(bandGains: [6, 6, 5, -1, 0, 0, 0, 0, 0, 0])
        case .bassCut:
            return EQSettings(bandGains: [-6, -5, -4, -2, 0, 0, 0, 0, 0, 0])
        case .trebleBoost:
            return EQSettings(bandGains: [0, 0, 0, 0, 0, 0, 2, 4, 5, 6])

        // MARK: - Speech
        case .vocalClarity:
            return EQSettings(bandGains: [-4, -2, -1, -3, 0, 2, 4, 4, 1, 0])
        case .podcast:
            return EQSettings(bandGains: [-6, -4, -2, -1, 0, 2, 4, 3, 1, 0])
        case .spokenWord:
            return EQSettings(bandGains: [-8, -6, -3, -2, 0, 2, 4, 4, 2, 0])

        // MARK: - Listening
        case .loudness:
            return EQSettings(bandGains: [5, 4, 2, 0, -2, -2, 0, 2, 4, 5])
        case .lateNight:
            return EQSettings(bandGains: [-6, -4, -2, 0, 0, 1, 2, 2, 1, 0])
        case .smallSpeakers:
            return EQSettings(bandGains: [3, 4, 5, 2, 0, 1, 2, 2, 1, 0])

        // MARK: - Music
        case .rock:
            return EQSettings(bandGains: [4, 3, 2, 0, -1, 0, 2, 3, 2, 1])
        case .pop:
            return EQSettings(bandGains: [3, 3, 2, 0, -1, 1, 2, 3, 3, 4])
        case .electronic:
            return EQSettings(bandGains: [7, 6, 4, 0, -2, -2, 1, 3, 4, 3])
        case .jazz:
            return EQSettings(bandGains: [3, 2, 1, 0, 0, 0, 1, 2, 2, 1])
        case .classical:
            return EQSettings(bandGains: [0, 0, 0, 0, 0, 0, 1, 2, 2, 2])
        case .hipHop:
            return EQSettings(bandGains: [6, 5, 4, 0, -1, 0, 2, 3, 4, 3])
        case .rnb:
            return EQSettings(bandGains: [4, 4, 3, 1, -1, 0, 2, 3, 3, 2])
        case .deep:
            return EQSettings(bandGains: [5, 6, 4, 1, -2, -2, 0, 1, 2, 1])
        case .acoustic:
            return EQSettings(bandGains: [0, 1, 2, 2, 1, 0, 1, 2, 2, 1])

        // MARK: - Media
        case .movie:
            return EQSettings(bandGains: [4, 4, 3, -1, -1, 1, 3, 3, 2, 1])
        }
    }
}