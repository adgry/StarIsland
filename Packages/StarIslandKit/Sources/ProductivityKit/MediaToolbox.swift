import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers

public enum ImageOutputFormat: String, CaseIterable, Codable, Sendable {
    case jpeg
    case png
    case heic

    public var title: String {
        switch self {
        case .jpeg: return "JPEG"
        case .png: return "PNG"
        case .heic: return "HEIC"
        }
    }

    public var utType: UTType {
        switch self {
        case .jpeg: return .jpeg
        case .png: return .png
        case .heic: return .heic
        }
    }

    public var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .png: return "png"
        case .heic: return "heic"
        }
    }
}

public enum MediaConvertPreset: String, CaseIterable, Codable, Sendable {
    case hevcHighestQuality
    case h264MediumQuality
    case audioM4AOnly

    public var title: String {
        switch self {
        case .hevcHighestQuality: return "HEVC 高画质压缩 (.mp4)"
        case .h264MediumQuality: return "H.264 均衡兼容 (.mp4)"
        case .audioM4AOnly: return "提取纯音频 (.m4a)"
        }
    }

    public var fileExtension: String {
        switch self {
        case .hevcHighestQuality, .h264MediumQuality: return "mp4"
        case .audioM4AOnly: return "m4a"
        }
    }

    public var avFileType: AVFileType {
        switch self {
        case .hevcHighestQuality, .h264MediumQuality: return .mp4
        case .audioM4AOnly: return .m4a
        }
    }

    public var exportPresetName: String {
        switch self {
        case .hevcHighestQuality: return AVAssetExportPresetHEVCHighestQuality
        case .h264MediumQuality: return AVAssetExportPresetMediumQuality
        case .audioM4AOnly: return AVAssetExportPresetAppleM4A
        }
    }
}

public enum MediaToolboxError: LocalizedError, Sendable {
    case fileNotFound(URL)
    case unsupportedInput(String)
    case encodingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "找不到待处理文件：\(url.lastPathComponent)"
        case .unsupportedInput(let detail):
            return "不支持的媒体输入：\(detail)"
        case .encodingFailed(let detail):
            return "媒体编码输出失败：\(detail)"
        }
    }
}

public struct MediaOptimizationReport: Equatable, Sendable {
    public let inputURL: URL
    public let outputURL: URL
    public let originalBytes: Int64
    public let optimizedBytes: Int64

    public init(inputURL: URL, outputURL: URL, originalBytes: Int64, optimizedBytes: Int64) {
        self.inputURL = inputURL
        self.outputURL = outputURL
        self.originalBytes = originalBytes
        self.optimizedBytes = optimizedBytes
    }

    public var savedBytes: Int64 {
        max(0, originalBytes - optimizedBytes)
    }

    public var savedPercentage: Int {
        guard originalBytes > 0 else { return 0 }
        let ratio = Double(originalBytes - optimizedBytes) / Double(originalBytes)
        return max(0, Int((ratio * 100.0).rounded()))
    }

    public var summaryText: String {
        let origStr = ByteCountFormatter.string(fromByteCount: originalBytes, countStyle: .file)
        let outStr = ByteCountFormatter.string(fromByteCount: optimizedBytes, countStyle: .file)
        if optimizedBytes < originalBytes {
            return "已完成：\(outputURL.lastPathComponent)（\(origStr) → \(outStr)，节省 \(savedPercentage)%）"
        } else {
            return "已转换输出：\(outputURL.lastPathComponent)（\(outStr)）"
        }
    }
}

public enum MediaToolbox {
    /// 基于 ImageIO 压缩与转换本地图片，默认剥离 EXIF 与 GPS 定位元数据。
    public static func compressImage(
        at inputURL: URL,
        quality: Double = 0.78,
        maxDimension: Int = 2560,
        format: ImageOutputFormat = .jpeg,
        stripMetadata: Bool = true,
        outputURL: URL? = nil
    ) throws -> MediaOptimizationReport {
        guard FileManager.default.fileExists(atPath: inputURL.path) else {
            throw MediaToolboxError.fileNotFound(inputURL)
        }
        let originalBytes = Self.fileSize(at: inputURL)

        guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil) else {
            throw MediaToolboxError.unsupportedInput(inputURL.lastPathComponent)
        }

        let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let srcWidth = (props?[kCGImagePropertyPixelWidth] as? Int) ?? 0
        let srcHeight = (props?[kCGImagePropertyPixelHeight] as? Int) ?? 0
        let largestSide = max(srcWidth, srcHeight)

        let cgImage: CGImage
        if maxDimension > 0 && largestSide > maxDimension {
            let thumbOpts: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: maxDimension,
            ]
            guard let scaled = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOpts as CFDictionary) else {
                throw MediaToolboxError.encodingFailed("缩略重采样失败")
            }
            cgImage = scaled
        } else {
            guard let full = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                throw MediaToolboxError.unsupportedInput("无法解码源图片位图")
            }
            cgImage = full
        }

        let finalOutput = outputURL ?? Self.uniqueSiblingURL(
            beside: inputURL,
            suffix: "-compressed",
            ext: format.fileExtension
        )
        try? FileManager.default.removeItem(at: finalOutput)

        guard let destination = CGImageDestinationCreateWithURL(
            finalOutput as CFURL,
            format.utType.identifier as CFString,
            1,
            nil
        ) else {
            throw MediaToolboxError.encodingFailed("无法创建目标图像编码器（\(format.title)）")
        }

        let clampedQuality = min(1.0, max(0.1, quality))
        var encodeProps: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: clampedQuality
        ]
        if !stripMetadata, let existingProps = props {
            for (k, v) in existingProps where k != kCGImagePropertyGPSDictionary {
                encodeProps[k] = v
            }
        }

        CGImageDestinationAddImage(destination, cgImage, encodeProps as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw MediaToolboxError.encodingFailed("写入压缩图片失败")
        }

        let optimizedBytes = Self.fileSize(at: finalOutput)
        return MediaOptimizationReport(
            inputURL: inputURL,
            outputURL: finalOutput,
            originalBytes: originalBytes,
            optimizedBytes: optimizedBytes
        )
    }

    /// 基于 PDFKit 与 Quartz 重采样内嵌页面图像以减小 PDF 体积。
    public static func compressPDF(
        at inputURL: URL,
        renderScale: CGFloat = 1.25,
        jpegQuality: Double = 0.65,
        outputURL: URL? = nil
    ) throws -> MediaOptimizationReport {
        guard FileManager.default.fileExists(atPath: inputURL.path) else {
            throw MediaToolboxError.fileNotFound(inputURL)
        }
        let originalBytes = Self.fileSize(at: inputURL)

        guard let document = PDFDocument(url: inputURL), document.pageCount > 0 else {
            throw MediaToolboxError.unsupportedInput("无法解析 PDF 文档：\(inputURL.lastPathComponent)")
        }

        let finalOutput = outputURL ?? Self.uniqueSiblingURL(beside: inputURL, suffix: "-slim", ext: "pdf")
        try? FileManager.default.removeItem(at: finalOutput)

        var defaultBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let pdfCtx = CGContext(finalOutput as CFURL, mediaBox: &defaultBox, nil) else {
            throw MediaToolboxError.encodingFailed("无法创建输出 PDF 上下文")
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let clampedScale = max(0.5, min(2.0, renderScale))

        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            var pageBounds = page.bounds(for: .mediaBox)
            if pageBounds.width <= 0 || pageBounds.height <= 0 {
                pageBounds = defaultBox
            }

            let pixelW = max(1, Int((pageBounds.width * clampedScale).rounded()))
            let pixelH = max(1, Int((pageBounds.height * clampedScale).rounded()))

            guard let bitmapCtx = CGContext(
                data: nil,
                width: pixelW,
                height: pixelH,
                bitsPerComponent: 8,
                bytesPerRow: pixelW * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ) else {
                continue
            }

            bitmapCtx.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
            bitmapCtx.fill(CGRect(x: 0, y: 0, width: pixelW, height: pixelH))
            bitmapCtx.saveGState()
            bitmapCtx.scaleBy(x: clampedScale, y: clampedScale)
            bitmapCtx.translateBy(x: -pageBounds.origin.x, y: -pageBounds.origin.y)
            page.draw(with: .mediaBox, to: bitmapCtx)
            bitmapCtx.restoreGState()

            guard let rawPageImage = bitmapCtx.makeImage() else { continue }

            // 将页面位图通过 JPEG 有损编码后再嵌入 PDF 页，显著压缩扫描件与大图体积
            let jpegData = NSMutableData()
            var finalDrawingImage = rawPageImage
            if let imgDest = CGImageDestinationCreateWithData(jpegData, UTType.jpeg.identifier as CFString, 1, nil) {
                let opts: [CFString: Any] = [
                    kCGImageDestinationLossyCompressionQuality: min(0.95, max(0.25, jpegQuality))
                ]
                CGImageDestinationAddImage(imgDest, rawPageImage, opts as CFDictionary)
                if CGImageDestinationFinalize(imgDest),
                   let imgSrc = CGImageSourceCreateWithData(jpegData, nil),
                   let decodedJPEG = CGImageSourceCreateImageAtIndex(imgSrc, 0, nil) {
                    finalDrawingImage = decodedJPEG
                }
            }

            let pageInfo: [CFString: Any] = [
                kCGPDFContextMediaBox: Data(bytes: &pageBounds, count: MemoryLayout<CGRect>.size)
            ]
            pdfCtx.beginPDFPage(pageInfo as CFDictionary)
            pdfCtx.draw(finalDrawingImage, in: pageBounds)
            pdfCtx.endPDFPage()
        }

        pdfCtx.closePDF()

        let optimizedBytes = Self.fileSize(at: finalOutput)
        return MediaOptimizationReport(
            inputURL: inputURL,
            outputURL: finalOutput,
            originalBytes: originalBytes,
            optimizedBytes: optimizedBytes
        )
    }

    /// 基于 AVAssetExportSession 将本地视频压缩为 HEVC/H.264 或提取 M4A 纯音频。
    public static func convertAudioOrVideo(
        at inputURL: URL,
        preset: MediaConvertPreset = .hevcHighestQuality,
        outputURL: URL? = nil
    ) async throws -> MediaOptimizationReport {
        guard FileManager.default.fileExists(atPath: inputURL.path) else {
            throw MediaToolboxError.fileNotFound(inputURL)
        }
        let originalBytes = Self.fileSize(at: inputURL)
        let asset = AVURLAsset(url: inputURL)

        let chosenPreset: String
        let isPrimaryCompatible = await AVAssetExportSession.compatibility(
            ofExportPreset: preset.exportPresetName,
            with: asset,
            outputFileType: preset.avFileType
        )
        if isPrimaryCompatible {
            chosenPreset = preset.exportPresetName
        } else if preset != .audioM4AOnly,
                  await AVAssetExportSession.compatibility(
                      ofExportPreset: AVAssetExportPresetMediumQuality,
                      with: asset,
                      outputFileType: .mp4
                  ) {
            chosenPreset = AVAssetExportPresetMediumQuality
        } else {
            throw MediaToolboxError.unsupportedInput("当前媒体不支持预设：\(preset.title)")
        }

        let finalOutput = outputURL ?? Self.uniqueSiblingURL(
            beside: inputURL,
            suffix: preset == .audioM4AOnly ? "-audio" : "-converted",
            ext: preset.fileExtension
        )
        try? FileManager.default.removeItem(at: finalOutput)

        guard let session = AVAssetExportSession(asset: asset, presetName: chosenPreset) else {
            throw MediaToolboxError.encodingFailed("无法创建 AVAssetExportSession")
        }

        if #available(macOS 15.0, *) {
            try await session.export(to: finalOutput, as: preset.avFileType)
        } else {
            session.outputURL = finalOutput
            session.outputFileType = preset.avFileType
            session.shouldOptimizeForNetworkUse = true
            try await Self.runLegacyExport(session)
        }

        let optimizedBytes = Self.fileSize(at: finalOutput)
        return MediaOptimizationReport(
            inputURL: inputURL,
            outputURL: finalOutput,
            originalBytes: originalBytes,
            optimizedBytes: optimizedBytes
        )
    }

    @available(macOS, introduced: 14.0, obsoleted: 15.0)
    private static func runLegacyExport(_ session: AVAssetExportSession) async throws {
        final class SessionBox: @unchecked Sendable {
            let session: AVAssetExportSession
            init(_ session: AVAssetExportSession) { self.session = session }
        }
        let box = SessionBox(session)
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            box.session.exportAsynchronously {
                switch box.session.status {
                case .completed:
                    cont.resume()
                case .failed, .cancelled:
                    let msg = box.session.error?.localizedDescription ?? "导出已取消或失败"
                    cont.resume(throwing: MediaToolboxError.encodingFailed(msg))
                default:
                    cont.resume(throwing: MediaToolboxError.encodingFailed("未知导出状态"))
                }
            }
        }
    }

    private static func fileSize(at url: URL) -> Int64 {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attrs?[.size] as? NSNumber)?.int64Value ?? 0
    }

    private static func uniqueSiblingURL(beside inputURL: URL, suffix: String, ext: String) -> URL {
        let dir = inputURL.deletingLastPathComponent()
        let stem = inputURL.deletingPathExtension().lastPathComponent
        var candidate = dir.appendingPathComponent("\(stem)\(suffix).\(ext)")
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = dir.appendingPathComponent("\(stem)\(suffix)-\(counter).\(ext)")
            counter += 1
        }
        return candidate
    }
}
