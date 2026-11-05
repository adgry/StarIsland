import CoreGraphics
import Foundation
import Vision

public struct OCRRecognitionResult: Equatable, Sendable {
    public let fullText: String
    public let lines: [String]
    public let barcodes: [String]

    public init(fullText: String, lines: [String], barcodes: [String]) {
        self.fullText = fullText
        self.lines = lines
        self.barcodes = barcodes
    }
}

public enum VisionOCRService {
    public static let preferredLanguages: [String] = [
        "zh-Hans", "zh-Hant", "en-US", "ja-JP", "ko-KR"
    ]

    /// 调用 Apple Vision 框架对 CGImage 执行高精度中英日韩离线文字识别。
    public static func recognizeText(
        in cgImage: CGImage,
        languages: [String] = preferredLanguages
    ) async throws -> String {
        let detailed = try await recognizeDetailed(in: cgImage, languages: languages)
        if !detailed.fullText.isEmpty {
            return detailed.fullText
        }
        return detailed.barcodes.joined(separator: "\n")
    }

    /// 同时离线识别画面中的多语种文字与条码/二维码内容。
    public static func recognizeDetailed(
        in cgImage: CGImage,
        languages: [String] = preferredLanguages
    ) async throws -> OCRRecognitionResult {
        try await Task.detached(priority: .userInitiated) {
            let textRequest = VNRecognizeTextRequest()
            textRequest.recognitionLevel = .accurate
            textRequest.usesLanguageCorrection = true
            textRequest.recognitionLanguages = languages

            let barcodeRequest = VNDetectBarcodesRequest()

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try handler.perform([textRequest, barcodeRequest])

            let textObservations = textRequest.results ?? []
            // Vision 坐标系原点在左下角，按从上到下、同行从左到右排序
            let sortedObservations = textObservations.sorted { lhs, rhs in
                let verticalDelta = abs(lhs.boundingBox.midY - rhs.boundingBox.midY)
                if verticalDelta > 0.025 {
                    return lhs.boundingBox.midY > rhs.boundingBox.midY
                }
                return lhs.boundingBox.minX < rhs.boundingBox.minX
            }

            let lines: [String] = sortedObservations.compactMap { obs in
                obs.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines)
            }.filter { !$0.isEmpty }

            let barcodes: [String] = (barcodeRequest.results ?? []).compactMap { obs in
                obs.payloadStringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
            }.filter { !$0.isEmpty }

            let fullText = lines.joined(separator: "\n")
            return OCRRecognitionResult(fullText: fullText, lines: lines, barcodes: barcodes)
        }.value
    }
}
