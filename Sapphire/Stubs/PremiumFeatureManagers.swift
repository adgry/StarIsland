//
//  PremiumFeatureManagers.swift
//  Sapphire
//

#if !SAPPHIRE_FULL_BUILD
import AppKit
import Combine
import Foundation
import PDFKit

final class OCRScreenshotMonitor {
    static let shared = OCRScreenshotMonitor()
    private init() {}
}

final class SystemEnhanceWindowRegistry {
    static let shared = SystemEnhanceWindowRegistry()
    private init() {}
}

final class SystemEnhanceDockPreviewController {
    static let shared = SystemEnhanceDockPreviewController()
    private init() {}
    func start() {}
    func dismiss() {}
}

final class SystemEnhanceWindowSwitcher {
    static let shared = SystemEnhanceWindowSwitcher()
    private init() {}
    func start() {}
    func dismiss() {}
}

final class SystemEnhanceDockClicks {
    static let shared = SystemEnhanceDockClicks()
    private init() {}
    func start() {}
    func stopMonitoring() {}
}

final class SystemEnhanceAutoQuit {
    static let shared = SystemEnhanceAutoQuit()
    private init() {}
    func start() {}
    func stopObserving() {}
}

final class SystemEnhanceQuitProtection {
    static let shared = SystemEnhanceQuitProtection()
    private init() {}
    func start() {}
    func removeTap() {}
}

final class SystemEnhanceGreenMaximize {
    static let shared = SystemEnhanceGreenMaximize()
    private init() {}
    func start() {}
    func stopMonitoring() {}
}

final class SystemEnhanceContextMenu {
    static let shared = SystemEnhanceContextMenu()
    private init() {}
    func installIfNeeded() {}
}

final class SystemEnhanceHingeAnimationManager {
    static let shared = SystemEnhanceHingeAnimationManager()
    private init() {}
    func start() {}
    func stop() {}
}

final class DockLayoutsManager {
    static let shared = DockLayoutsManager()
    private init() {}
    func start() {}
    func startDockBehaviorSync() {}

    @MainActor
    func captureCurrentLayout(named name: String) -> DockLayout? {
        let dockPlist = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/com.apple.dock.plist")
        guard let data = try? Data(contentsOf: dockPlist) else { return nil }
        let plist = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any]
        let apps = (plist?["persistent-apps"] as? [[String: Any]])?.count
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return DockLayout(
            name: trimmed.isEmpty ? "程序坞快照" : trimmed,
            plistDataBase64: data.base64EncodedString(),
            appCount: apps
        )
    }

    @MainActor
    @discardableResult
    func applyLayout(_ layout: DockLayout) -> Bool {
        guard let base64 = layout.plistDataBase64,
              let data = Data(base64Encoded: base64) else { return false }
        let dockPlist = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/com.apple.dock.plist")
        do {
            try data.write(to: dockPlist, options: .atomic)
            let killall = Process()
            killall.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            killall.arguments = ["Dock"]
            try? killall.run()
            return true
        } catch {
            return false
        }
    }

    func importLayoutFiles(at urls: [URL]) {
        Task { @MainActor in
            var added: [DockLayout] = []
            for url in urls {
                guard let data = try? Data(contentsOf: url) else { continue }
                if let decoded = try? JSONDecoder().decode([DockLayout].self, from: data) {
                    added.append(contentsOf: decoded)
                } else if let single = try? JSONDecoder().decode(DockLayout.self, from: data) {
                    added.append(single)
                } else {
                    added.append(DockLayout(name: url.deletingPathExtension().lastPathComponent, plistDataBase64: data.base64EncodedString()))
                }
            }
            guard !added.isEmpty else { return }
            var current = SettingsModel.shared.settings.dockLayoutsPresets
            current.append(contentsOf: added)
            SettingsModel.shared.settings.dockLayoutsPresets = current
        }
    }
}

enum MediaOptimizeKind: String {
    case image, pdf, video, audio

    var actionTitle: String {
        switch self {
        case .image: "压缩图片"
        case .pdf: "压缩 PDF"
        case .video: "优化视频"
        case .audio: "优化音频"
        }
    }

    var systemImage: String {
        switch self {
        case .image: "photo.badge.arrow.down"
        case .pdf: "doc.zipper"
        case .video: "film"
        case .audio: "waveform"
        }
    }
}

struct MediaOptimizeResult: Equatable {
    let sourceURL: URL
    let outputURL: URL
    let kind: MediaOptimizeKind
    let originalBytes: Int64
    let optimizedBytes: Int64

    var savedBytes: Int64 { max(0, originalBytes - optimizedBytes) }
    var savedPercent: Int {
        guard originalBytes > 0, savedBytes > 0 else { return 0 }
        return min(99, Int((Double(savedBytes) / Double(originalBytes) * 100.0).rounded()))
    }
}

enum MediaOptimizeError: LocalizedError, Equatable {
    case unsupportedFormat
    case readFailed
    case encodeFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat: "不支持优化该文件格式。"
        case .readFailed: "无法读取源媒体文件。"
        case .encodeFailed: "媒体压缩编码失败。"
        }
    }
}

enum MediaOptimizer {
    private static let imageExts: Set<String> = ["png", "jpg", "jpeg", "heic", "tiff", "tif", "bmp", "webp"]

    static func kind(for url: URL) -> MediaOptimizeKind? {
        let ext = url.pathExtension.lowercased()
        if imageExts.contains(ext) { return .image }
        if ext == "pdf" { return .pdf }
        return nil
    }

    static func canOCR(_ url: URL) -> Bool {
        imageExts.contains(url.pathExtension.lowercased())
    }
}

@MainActor
final class MediaOptimizerManager {
    static let shared = MediaOptimizerManager()
    private init() {}
    func start() {}

    func optimizeFile(_ url: URL) async -> Result<MediaOptimizeResult, MediaOptimizeError> {
        guard let kind = MediaOptimizer.kind(for: url) else {
            return .failure(.unsupportedFormat)
        }
        let quality = min(max(SettingsModel.shared.settings.mediaToolsImageQuality, 0.2), 0.95)
        let maxDim = max(256, SettingsModel.shared.settings.mediaToolsMaxImageDimension)
        return await Task.detached(priority: .userInitiated) {
            let origSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
            switch kind {
            case .image:
                guard let image = NSImage(contentsOf: url),
                      let cgSource = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                    return .failure(.readFailed)
                }
                let srcW = Double(cgSource.width)
                let srcH = Double(cgSource.height)
                let scale = min(1.0, maxDim / max(srcW, srcH))
                let targetW = max(1, Int((srcW * scale).rounded()))
                let targetH = max(1, Int((srcH * scale).rounded()))

                guard let bitmap = NSBitmapImageRep(
                    bitmapDataPlanes: nil,
                    pixelsWide: targetW,
                    pixelsHigh: targetH,
                    bitsPerSample: 8,
                    samplesPerPixel: 4,
                    hasAlpha: true,
                    isPlanar: false,
                    colorSpaceName: .deviceRGB,
                    bytesPerRow: 0,
                    bitsPerPixel: 0
                ) else {
                    return .failure(.encodeFailed)
                }
                NSGraphicsContext.saveGraphicsState()
                if let ctx = NSGraphicsContext(bitmapImageRep: bitmap) {
                    NSGraphicsContext.current = ctx
                    NSColor.white.setFill()
                    NSRect(x: 0, y: 0, width: targetW, height: targetH).fill()
                    ctx.cgContext.interpolationQuality = .high
                    ctx.cgContext.draw(cgSource, in: CGRect(x: 0, y: 0, width: targetW, height: targetH))
                }
                NSGraphicsContext.restoreGraphicsState()

                guard let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality]) else {
                    return .failure(.encodeFailed)
                }
                let baseName = url.deletingPathExtension().lastPathComponent
                let outDir = FileManager.default.temporaryDirectory.appendingPathComponent("StarIslandOptimized", isDirectory: true)
                try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
                let outURL = outDir.appendingPathComponent("\(baseName)-optimized.jpg")
                do {
                    try jpeg.write(to: outURL, options: .atomic)
                    return .success(MediaOptimizeResult(
                        sourceURL: url,
                        outputURL: outURL,
                        kind: .image,
                        originalBytes: origSize,
                        optimizedBytes: Int64(jpeg.count)
                    ))
                } catch {
                    return .failure(.encodeFailed)
                }
            case .pdf:
                guard let doc = PDFDocument(url: url) else { return .failure(.readFailed) }
                let baseName = url.deletingPathExtension().lastPathComponent
                let outDir = FileManager.default.temporaryDirectory.appendingPathComponent("StarIslandOptimized", isDirectory: true)
                try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
                let outURL = outDir.appendingPathComponent("\(baseName)-optimized.pdf")
                guard doc.write(to: outURL) else { return .failure(.encodeFailed) }
                let optSize = (try? FileManager.default.attributesOfItem(atPath: outURL.path)[.size] as? NSNumber)?.int64Value ?? origSize
                return .success(MediaOptimizeResult(sourceURL: url, outputURL: outURL, kind: .pdf, originalBytes: origSize, optimizedBytes: optSize))
            case .video, .audio:
                return .failure(.unsupportedFormat)
            }
        }.value
    }

    func recognizeText(in url: URL) async -> String? {
        guard let image = NSImage(contentsOf: url),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        let text = await CircleToSearchManager.shared.recognizeText(in: cgImage)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

final class EmojiShortcutManager {
    static let shared = EmojiShortcutManager()
    private init() {}
    func stopMonitoring() {}
}

@MainActor
final class ClipboardPickerManager: ObservableObject {
    static let shared = ClipboardPickerManager()
    private init() {}
    func presentPicker() {
        NotificationCenter.default.post(name: Notification.Name("sapphireOpenClipboardPicker"), object: nil)
    }
    func stopMonitoring() {}
}

final class ClipboardAutoClearManager {
    static let shared = ClipboardAutoClearManager()
    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private var lastChangedAt: Date = Date()
    private init() {}

    func start() {
        stop()
        lastChangeCount = NSPasteboard.general.changeCount
        lastChangedAt = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        Task { @MainActor in
            guard SettingsModel.shared.settings.clipboardAutoClearEnabled else { return }
            let pb = NSPasteboard.general
            if pb.changeCount != self.lastChangeCount {
                self.lastChangeCount = pb.changeCount
                self.lastChangedAt = Date()
                return
            }
            let limitMinutes = max(1, SettingsModel.shared.settings.clipboardAutoClearInterval)
            if Date().timeIntervalSince(self.lastChangedAt) >= limitMinutes * 60 {
                pb.clearContents()
                self.lastChangeCount = pb.changeCount
                self.lastChangedAt = Date()
            }
        }
    }
}

final class CleanURLManager {
    static let shared = CleanURLManager()
    private var pollTimer: Timer?
    private var lastObservedCount: Int = -1
    private init() {}

    func start() {
        stopPolling()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.pollPasteboardIfEnabled()
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func stopMonitoring() { stopPolling() }

    func cleanClipboardLinkNow() {
        Task { @MainActor in
            let pb = NSPasteboard.general
            guard let raw = pb.string(forType: .string) else { return }
            let extra = SettingsModel.shared.settings.clipboardCleanURLCustomParams
            if let cleaned = Self.cleanedURL(raw, extraParams: extra) {
                pb.clearContents()
                pb.setString(cleaned, forType: .string)
                self.lastObservedCount = pb.changeCount
            }
        }
    }

    private func pollPasteboardIfEnabled() {
        Task { @MainActor in
            let s = SettingsModel.shared.settings
            guard s.clipboardCleanURLEnabled, s.clipboardCleanURLAutoClean else { return }
            let pb = NSPasteboard.general
            guard pb.changeCount != self.lastObservedCount else { return }
            self.lastObservedCount = pb.changeCount
            guard let raw = pb.string(forType: .string),
                  let cleaned = Self.cleanedURL(raw, extraParams: s.clipboardCleanURLCustomParams) else {
                return
            }
            pb.clearContents()
            pb.setString(cleaned, forType: .string)
            self.lastObservedCount = pb.changeCount
        }
    }

    static func cleanedURL(_ raw: String, extraParams: [String]) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains(where: \.isWhitespace),
              var components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host?.lowercased(),
              let rawQuery = components.percentEncodedQuery,
              !rawQuery.isEmpty else {
            return nil
        }

        let baseStripped: Set<String> = [
            "fbclid", "gclid", "dclid", "msclkid", "gbraid", "wbraid",
            "yclid", "ttclid", "_hsenc", "_hsmi", "mkt_tok", "srsltid",
            "igshid", "mc_cid", "mc_eid",
            "spm", "spm_id_from", "vd_source", "share_source", "share_medium",
            "share_plat", "share_session_id", "share_tag", "unique_k"
        ]
        let extra = Set(extraParams.map { $0.lowercased() })
        let isYouTube = host == "youtu.be" || host == "youtube.com" || host.hasSuffix(".youtube.com")

        let pairs = rawQuery.split(separator: "&", omittingEmptySubsequences: false).map(String.init)
        var kept: [String] = []
        var changed = false

        for pair in pairs {
            let key = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? pair
            let lower = (key.removingPercentEncoding ?? key).lowercased()
            let shouldStrip = lower.hasPrefix("utm_")
                || baseStripped.contains(lower)
                || extra.contains(lower)
                || (isYouTube && (lower == "si" || lower == "pp"))
            if shouldStrip {
                changed = true
            } else {
                kept.append(pair)
            }
        }

        guard changed else { return nil }
        components.percentEncodedQuery = kept.isEmpty ? nil : kept.joined(separator: "&")
        return components.string
    }
}

final class FinderCutPasteManager {
    static let shared = FinderCutPasteManager()
    private init() {}
    func start() {}
    func removeTap() {}
}

final class SnippetManager {
    static let shared = SnippetManager()
    private init() {}
    func start() {}
    func removeHandler() {}
}

final class MouseControlManager {
    static let shared = MouseControlManager()
    private init() {}
    func shutdown() {}
    func restoreSystemSettings() {}
}

final class FocusFollowsMouseManager {
    static let shared = FocusFollowsMouseManager()
    private init() {}
    func start() {}
    func removeMonitors() {}
}

final class ExtraClickFilterManager {
    static let shared = ExtraClickFilterManager()
    private init() {}
    func start() {}
    func shutdown() {}

    static func shouldSuppressClick(deltaSeconds: Double, threshold: Double) -> Bool {
        guard threshold > 0, deltaSeconds >= 0 else { return false }
        return deltaSeconds < threshold
    }
}

final class KeyboardDebounceManager {
    static let shared = KeyboardDebounceManager()
    private init() {}
    func start() {}
    func stopMonitoring() {}

    static func shouldSuppressKeyRepeat(deltaSeconds: Double, threshold: Double) -> Bool {
        guard threshold > 0, deltaSeconds >= 0 else { return false }
        return deltaSeconds < threshold
    }
}

final class SuperKeyManager {
    static let shared = SuperKeyManager()
    private init() {}
    func start() {}
    func stopMonitoring() {}
}
#endif
