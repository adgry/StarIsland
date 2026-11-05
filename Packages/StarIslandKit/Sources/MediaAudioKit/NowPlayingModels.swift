import AppKit
import CoreGraphics
import Foundation
import ImageIO
import SwiftUI

/// 媒体播放来源枚举
public enum MediaPlayerSource: String, CaseIterable, Codable, Equatable, Sendable {
    case appleMusic
    case spotify
    case mediaRemote
    case unknown

    public var displayName: String {
        switch self {
        case .appleMusic: return "Apple 音乐"
        case .spotify: return "Spotify"
        case .mediaRemote: return "系统媒体"
        case .unknown: return "未知来源"
        }
    }

    public var bundleIdentifier: String? {
        switch self {
        case .appleMusic: return "com.apple.Music"
        case .spotify: return "com.spotify.client"
        case .mediaRemote, .unknown: return nil
        }
    }

    public var iconSymbol: String {
        switch self {
        case .appleMusic: return "music.note"
        case .spotify: return "dot.radiowaves.left.and.right"
        case .mediaRemote: return "play.tv.fill"
        case .unknown: return "waveform"
        }
    }

    public static func resolve(bundleID: String?) -> MediaPlayerSource {
        guard let lower = bundleID?.lowercased(), !lower.isEmpty else {
            return .mediaRemote
        }
        if lower == "com.apple.music" || lower == "com.apple.itunes" {
            return .appleMusic
        }
        if lower == "com.spotify.client" {
            return .spotify
        }
        return .mediaRemote
    }
}

/// 专辑封面主色调调色板（驱动灵动岛流体背景与阴影）
public struct DominantColorPalette: Codable, Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var secondaryRed: Double
    public var secondaryGreen: Double
    public var secondaryBlue: Double

    public static let starIslandDefault = DominantColorPalette(
        red: 0.34,
        green: 0.50,
        blue: 0.96,
        secondaryRed: 0.58,
        secondaryGreen: 0.30,
        secondaryBlue: 0.92
    )

    public init(
        red: Double,
        green: Double,
        blue: Double,
        secondaryRed: Double,
        secondaryGreen: Double,
        secondaryBlue: Double
    ) {
        self.red = Self.clamp(red)
        self.green = Self.clamp(green)
        self.blue = Self.clamp(blue)
        self.secondaryRed = Self.clamp(secondaryRed)
        self.secondaryGreen = Self.clamp(secondaryGreen)
        self.secondaryBlue = Self.clamp(secondaryBlue)
    }

    public var primaryColor: Color {
        Color(red: red, green: green, blue: blue)
    }

    public var secondaryColor: Color {
        Color(red: secondaryRed, green: secondaryGreen, blue: secondaryBlue)
    }

    /// 从专辑封面二进制数据中提取高饱和度主色调与次级流光色
    public static func extract(from imageData: Data?) -> DominantColorPalette {
        guard let data = imageData,
              !data.isEmpty,
              let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return .starIslandDefault
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 24
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return .starIslandDefault
        }

        let width = max(1, min(cgImage.width, 24))
        let height = max(1, min(cgImage.height, 24))
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var rawPixels = [UInt8](repeating: 0, count: height * bytesPerRow)

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: &rawPixels,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return .starIslandDefault
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var weightedR = 0.0
        var weightedG = 0.0
        var weightedB = 0.0
        var totalWeight = 0.0

        var altR = 0.0
        var altG = 0.0
        var altB = 0.0
        var altWeight = 0.0

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let alpha = Double(rawPixels[offset + 3]) / 255.0
                guard alpha > 0.25 else { continue }

                let r = Double(rawPixels[offset]) / 255.0
                let g = Double(rawPixels[offset + 1]) / 255.0
                let b = Double(rawPixels[offset + 2]) / 255.0

                let maxC = max(r, g, b)
                let minC = min(r, g, b)
                let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
                guard luminance > 0.06 && luminance < 0.94 else { continue }

                let saturation = maxC > 0 ? (maxC - minC) / maxC : 0
                let weight = 0.25 + saturation * 2.2

                if (x + y) % 2 == 0 {
                    weightedR += r * weight
                    weightedG += g * weight
                    weightedB += b * weight
                    totalWeight += weight
                } else {
                    altR += r * weight
                    altG += g * weight
                    altB += b * weight
                    altWeight += weight
                }
            }
        }

        guard totalWeight > 0.01 else {
            return .starIslandDefault
        }

        let pr = boostVibrance(weightedR / totalWeight)
        let pg = boostVibrance(weightedG / totalWeight)
        let pb = boostVibrance(weightedB / totalWeight)

        let sr = altWeight > 0.01 ? boostVibrance(altR / altWeight) : clamp(pr * 0.75 + 0.18)
        let sg = altWeight > 0.01 ? boostVibrance(altG / altWeight) : clamp(pg * 0.80 + 0.10)
        let sb = altWeight > 0.01 ? boostVibrance(altB / altWeight) : clamp(pb * 0.85 + 0.15)

        return DominantColorPalette(
            red: pr,
            green: pg,
            blue: pb,
            secondaryRed: sr,
            secondaryGreen: sg,
            secondaryBlue: sb
        )
    }

    private static func boostVibrance(_ component: Double) -> Double {
        clamp(0.16 + component * 0.78)
    }

    private static func clamp(_ value: Double) -> Double {
        guard !value.isNaN && !value.isInfinite else { return 0.5 }
        return min(max(value, 0.0), 1.0)
    }
}

/// 当前正在播放的媒体曲目快照
public struct NowPlayingTrack: Equatable, Identifiable, Sendable {
    public var id: String {
        "\(title.lowercased())|\(artist.lowercased())|\(album.lowercased())"
    }

    public var title: String
    public var artist: String
    public var album: String
    public var duration: TimeInterval
    public var elapsedTime: TimeInterval
    public var isPlaying: Bool
    public var playbackRate: Double
    public var source: MediaPlayerSource
    public var sourceAppBundleID: String?
    public var artworkData: Data?
    public var palette: DominantColorPalette
    public var isFavorited: Bool
    public var updatedAt: Date

    public init(
        title: String,
        artist: String,
        album: String = "",
        duration: TimeInterval = 0,
        elapsedTime: TimeInterval = 0,
        isPlaying: Bool = false,
        playbackRate: Double = 1.0,
        source: MediaPlayerSource = .mediaRemote,
        sourceAppBundleID: String? = nil,
        artworkData: Data? = nil,
        palette: DominantColorPalette? = nil,
        isFavorited: Bool = false,
        updatedAt: Date = Date()
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = max(0, duration)
        self.elapsedTime = min(max(0, elapsedTime), max(0, duration > 0 ? duration : elapsedTime))
        self.isPlaying = isPlaying
        self.playbackRate = playbackRate
        self.source = source
        self.sourceAppBundleID = sourceAppBundleID ?? source.bundleIdentifier
        self.artworkData = artworkData
        self.palette = palette ?? DominantColorPalette.extract(from: artworkData)
        self.isFavorited = isFavorited
        self.updatedAt = updatedAt
    }

    /// 归一化播放进度 [0, 1]
    public var progressFraction: Double {
        guard duration > 0.1 else { return 0.0 }
        return min(max(elapsedTime / duration, 0.0), 1.0)
    }

    /// 根据时间戳动态推算实时播放秒数
    public func interpolatedElapsedTime(at date: Date = Date()) -> TimeInterval {
        guard isPlaying else { return elapsedTime }
        let delta = max(0, date.timeIntervalSince(updatedAt)) * max(0, playbackRate)
        let raw = elapsedTime + delta
        return duration > 0 ? min(raw, duration) : raw
    }

    public var formattedElapsed: String {
        Self.formatTimestamp(elapsedTime)
    }

    public var formattedDuration: String {
        Self.formatTimestamp(duration)
    }

    public static func formatTimestamp(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "00:00" }
        let total = Int(seconds.rounded(.down))
        let mins = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
