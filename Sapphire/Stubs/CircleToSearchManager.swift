//
//  CircleToSearchManager.swift
//  Sapphire
//

#if !SAPPHIRE_FULL_BUILD
import AppKit
import Combine
import Foundation
import Vision

final class CircleToSearchManager: ObservableObject {
    static let shared = CircleToSearchManager()

    @Published var latestImage: NSImage?
    @Published var recognizedText: String = ""
    @Published var aiExplanation: String = ""
    @Published var isRecognizing: Bool = false

    private var overlayWindows: [NSWindow] = []

    private init() {}

    func recognizeText(in image: CGImage) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let resumeLock = NSLock()
                var didResume = false
                let finish: (String) -> Void = { result in
                    resumeLock.lock()
                    defer { resumeLock.unlock() }
                    guard !didResume else { return }
                    didResume = true
                    continuation.resume(returning: result)
                }

                let request = VNRecognizeTextRequest { req, _ in
                    let observations = (req.results as? [VNRecognizedTextObservation]) ?? []
                    let lines: [OCRScreenTextSupport.RecognizedLine] = observations.compactMap { obs in
                        guard let top = obs.topCandidates(1).first else { return nil }
                        return OCRScreenTextSupport.RecognizedLine(text: top.string, boundingBox: obs.boundingBox)
                    }
                    finish(OCRScreenTextSupport.orderedText(lines))
                }
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                request.recognitionLanguages = ["zh-Hans", "en-US"]

                let handler = VNImageRequestHandler(cgImage: image, options: [:])
                do {
                    try handler.perform([request])
                    finish("")
                } catch {
                    finish("")
                }
            }
        }
    }

    @MainActor
    func startInteractiveSelection() {
        dismissSelectionOverlays()
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let displayID = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? CGMainDisplayID()
        guard let fullScreenshot = CGDisplayCreateImage(displayID) else { return }

        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.isOpaque = false
        panel.backgroundColor = NSColor.black.withAlphaComponent(0.22)
        panel.hasShadow = false
        panel.ignoresMouseEvents = false

        let selectorView = RegionSelectionNSView(frame: CGRect(origin: .zero, size: screen.frame.size)) { [weak self] rectInView in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.dismissSelectionOverlays()
                guard let rectInView, rectInView.width >= 8, rectInView.height >= 8 else { return }
                await self.processSelectedRegion(rectInView, screenSize: screen.frame.size, fullCGImage: fullScreenshot)
            }
        }
        panel.contentView = selectorView
        panel.makeKeyAndOrderFront(nil)
        overlayWindows = [panel]
    }

    @MainActor
    private func processSelectedRegion(_ viewRect: CGRect, screenSize: CGSize, fullCGImage: CGImage) async {
        let scaleX = CGFloat(fullCGImage.width) / max(screenSize.width, 1)
        let scaleY = CGFloat(fullCGImage.height) / max(screenSize.height, 1)
        // NSView 默认左下原点 -> CGImage 左上原点翻转
        let flippedY = screenSize.height - viewRect.maxY
        let cropRect = CGRect(
            x: viewRect.minX * scaleX,
            y: flippedY * scaleY,
            width: viewRect.width * scaleX,
            height: viewRect.height * scaleY
        ).integral

        let targetCG = fullCGImage.cropping(to: cropRect) ?? fullCGImage
        latestImage = NSImage(cgImage: targetCG, size: viewRect.size)
        isRecognizing = true
        aiExplanation = ""
        NotificationCenter.default.post(name: .sapphireOpenCircleToSearch, object: nil)

        let text = await recognizeText(in: targetCG)
        recognizedText = text
        isRecognizing = false
        if !text.isEmpty {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
    }

    @MainActor
    private func dismissSelectionOverlays() {
        for win in overlayWindows { win.orderOut(nil) }
        overlayWindows.removeAll()
    }

    func endResultsPresentation() {
        Task { @MainActor in dismissSelectionOverlays() }
    }
}

private final class RegionSelectionNSView: NSView {
    private var startPoint: NSPoint?
    private var currentRect: NSRect?
    private let onComplete: (CGRect?) -> Void

    init(frame frameRect: NSRect, onComplete: @escaping (CGRect?) -> Void) {
        self.onComplete = onComplete
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) { nil }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onComplete(nil) }
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentRect = nil
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }
        let cur = convert(event.locationInWindow, from: nil)
        currentRect = NSRect(
            x: min(start.x, cur.x),
            y: min(start.y, cur.y),
            width: abs(cur.x - start.x),
            height: abs(cur.y - start.y)
        )
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        onComplete(currentRect)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let rect = currentRect else { return }
        NSColor.white.withAlphaComponent(0.14).setFill()
        let path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        path.fill()
        NSColor.systemCyan.setStroke()
        path.lineWidth = 2
        path.stroke()
    }
}

extension Notification.Name {
    static let sapphireOpenCircleToSearch = Notification.Name("sapphireOpenCircleToSearch")
}
#endif
