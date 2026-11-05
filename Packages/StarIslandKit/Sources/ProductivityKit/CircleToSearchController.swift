import AppKit
import Combine
import CoreGraphics
import Foundation
import ImageIO
import IslandCore
import ScreenCaptureKit
import SwiftUI
import UniformTypeIdentifiers

public enum ScreenSelectionMode: String, Sendable {
    case ocrOnly
    case circleToSearch
}

private final class OverlaySelectionWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
public final class CircleToSearchController: ObservableObject {
    public static let shared = CircleToSearchController()

    @Published public private(set) var isSelecting: Bool = false
    @Published public private(set) var capturedCGImage: CGImage?
    @Published public private(set) var recognizedText: String = ""
    @Published public private(set) var aiResultText: String = ""
    @Published public private(set) var statusBanner: String?
    @Published public private(set) var isWorking: Bool = false

    private let stateMachine: IslandStateMachine
    private var activeAIService: AIQueryServiceProtocol?
    private var currentMode: ScreenSelectionMode = .circleToSearch
    private var overlayPanel: OverlaySelectionWindow?
    private var toolbarPanel: OverlaySelectionWindow?
    private var escapeMonitor: Any?

    public init(stateMachine: IslandStateMachine? = nil) {
        self.stateMachine = stateMachine ?? .shared
    }

    public func beginSelection(
        aiService: AIQueryServiceProtocol? = nil,
        mode: ScreenSelectionMode = .circleToSearch
    ) {
        dismissAllPanels()
        self.activeAIService = aiService
        self.currentMode = mode
        self.recognizedText = ""
        self.aiResultText = ""
        self.statusBanner = nil
        self.capturedCGImage = nil

        guard CGPreflightScreenCaptureAccess() else {
            _ = CGRequestScreenCaptureAccess()
            stateMachine.submit(
                IslandActivityItem(
                    id: "ocr-permission-needed",
                    category: .shelf,
                    title: "需要屏幕录制权限",
                    subtitle: "请在系统设置中授权「星岛」屏幕录制后再试",
                    iconSymbol: "menubar.dock.rectangle.badge.record",
                    priority: .urgent,
                    isAlertHUD: true,
                    autoDismissAfter: 4.0
                )
            )
            return
        }

        let mouseLoc = NSEvent.mouseLocation
        guard let targetScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) })
                ?? NSScreen.main
                ?? NSScreen.screens.first else {
            return
        }

        isSelecting = true
        let panel = OverlaySelectionWindow(
            contentRect: targetScreen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let overlayView = ScreenFreezeSelectionView(
            mode: mode,
            screenFrame: targetScreen.frame,
            onSelectionFinished: { [weak self] localViewRect in
                self?.handleSelectionCompleted(localViewRect: localViewRect, on: targetScreen)
            },
            onCancel: { [weak self] in
                self?.cancelSelection()
            }
        )
        panel.contentView = NSHostingView(rootView: overlayView)
        overlayPanel = panel
        panel.makeKeyAndOrderFront(nil)
        installEscapeKeyMonitor()
    }

    public func cancelSelection() {
        isSelecting = false
        dismissAllPanels()
    }

    public func copyRecognizedText() {
        let text = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            statusBanner = "未检测到可复制的文字"
            return
        }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        statusBanner = "已复制 \(text.count) 个字符到剪贴板"
    }

    public func translateRecognizedText(
        targetLanguage: String = "简体中文",
        aiService: AIQueryServiceProtocol? = nil
    ) async {
        let sourceText = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sourceText.isEmpty else {
            statusBanner = "选区内暂无可翻译文字，可尝试「AI 识图解答」"
            return
        }
        guard let service = aiService ?? activeAIService ?? ServiceRegistry.shared.aiService else {
            statusBanner = "尚未配置星岛 AI 服务，请前往设置启用 Gemini / OpenAI / Ollama"
            ServiceRegistry.shared.onOpenSettingsSection?(.aiConnect)
            return
        }

        isWorking = true
        statusBanner = "正在翻译为\(targetLanguage)…"
        defer { isWorking = false }

        do {
            let translated = try await service.translate(text: sourceText, targetLanguage: targetLanguage)
            aiResultText = translated
            statusBanner = "翻译完成"
        } catch {
            statusBanner = "翻译失败：\(error.localizedDescription)"
        }
    }

    public func askAIAboutSelection(
        prompt: String = "请结合截图内容进行中文解析、总结或解答其中的问题。",
        aiService: AIQueryServiceProtocol? = nil
    ) async {
        guard let cgImage = capturedCGImage else {
            statusBanner = "当前无可用选区图像"
            return
        }
        guard let service = aiService ?? activeAIService ?? ServiceRegistry.shared.aiService else {
            statusBanner = "尚未配置星岛 AI 服务，请前往设置配置模型密钥或本地 Ollama"
            ServiceRegistry.shared.onOpenSettingsSection?(.aiConnect)
            return
        }

        isWorking = true
        statusBanner = "星岛 AI 正在识图分析…"
        defer { isWorking = false }

        let pngData = Self.encodePNGData(from: cgImage)
        let enrichedPrompt: String
        if recognizedText.isEmpty {
            enrichedPrompt = prompt
        } else {
            enrichedPrompt = "\(prompt)\n\n【离线 OCR 提取文字参考】：\n\(recognizedText)"
        }

        do {
            let reply = try await service.ask(prompt: enrichedPrompt, imagePNGData: pngData)
            aiResultText = reply
            statusBanner = "AI 识图解答完成"
        } catch {
            statusBanner = "AI 请求失败：\(error.localizedDescription)"
        }
    }

    public func searchInBrowser() {
        if let cgImage = capturedCGImage {
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.writeObjects([nsImage])
        }

        let trimmed = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty,
           let encoded = String(trimmed.prefix(120)).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let searchURL = URL(string: "https://www.bing.com/search?q=\(encoded)") {
            NSWorkspace.shared.open(searchURL)
            statusBanner = "已在浏览器搜索识别文本（截图亦已复制到剪贴板）"
        } else if let lensURL = URL(string: "https://lens.google.com/") {
            NSWorkspace.shared.open(lensURL)
            statusBanner = "已打开 Google 识图，可直接按 ⌘V 粘贴刚才框选的截图"
        }
    }

    // MARK: - 选区捕获与浮动操作栏

    private func handleSelectionCompleted(localViewRect: CGRect, on screen: NSScreen) {
        isSelecting = false
        overlayPanel?.orderOut(nil)
        overlayPanel = nil

        guard localViewRect.width >= 8, localViewRect.height >= 8 else {
            dismissAllPanels()
            return
        }

        // SwiftUI Canvas/GeometryReader 原点在左上角：localViewRect 即为屏幕左上角原点坐标（points）
        let globalAppKitRect = CGRect(
            x: screen.frame.minX + localViewRect.minX,
            y: screen.frame.maxY - localViewRect.maxY,
            width: localViewRect.width,
            height: localViewRect.height
        )

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 50_000_000)
            do {
                let image = try await Self.captureScreenRegion(
                    topLeftPointsRect: localViewRect,
                    on: screen
                )
                self.capturedCGImage = image
                let text = (try? await VisionOCRService.recognizeText(in: image)) ?? ""
                self.recognizedText = text

                if self.currentMode == .ocrOnly {
                    self.finishImmediateOCRMode(recognized: text)
                } else {
                    self.presentFloatingActionToolbar(near: globalAppKitRect, on: screen)
                }
            } catch {
                self.stateMachine.submit(
                    IslandActivityItem(
                        id: "ocr-capture-failed",
                        category: .shelf,
                        title: "框选截屏失败",
                        subtitle: error.localizedDescription,
                        iconSymbol: "exclamationmark.triangle.fill",
                        priority: .urgent,
                        isAlertHUD: true,
                        autoDismissAfter: 3.5
                    )
                )
            }
        }
    }

    private func finishImmediateOCRMode(recognized: String) {
        let trimmed = recognized.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            stateMachine.submit(IslandActivityItem(
                id: "ocr-empty", category: .shelf, title: "未识别到文字或二维码",
                subtitle: "请框选包含清晰文字的区域重试", iconSymbol: "text.viewfinder",
                priority: .interactive, isAlertHUD: true, autoDismissAfter: 3.0
            ))
            return
        }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(trimmed, forType: .string)
        stateMachine.submit(IslandActivityItem(
            id: "ocr-copied", category: .shelf, title: "OCR 已复制（\(trimmed.count) 字）",
            subtitle: String(trimmed.replacingOccurrences(of: "\n", with: " ").prefix(42)),
            iconSymbol: "doc.on.doc.fill", trailingBadge: "已复制",
            priority: .urgent, isAlertHUD: true, autoDismissAfter: 3.5
        ))
    }

    private func presentFloatingActionToolbar(near selectionGlobalRect: CGRect, on screen: NSScreen) {
        let panelWidth: CGFloat = 440
        let panelHeight: CGFloat = 250
        let visible = screen.visibleFrame

        var originX = selectionGlobalRect.midX - panelWidth * 0.5
        var originY = selectionGlobalRect.minY - panelHeight - 12
        if originY < visible.minY + 12 {
            originY = min(visible.maxY - panelHeight - 12, selectionGlobalRect.maxY + 12)
        }
        originX = max(visible.minX + 12, min(originX, visible.maxX - panelWidth - 12))

        let panel = OverlaySelectionWindow(
            contentRect: NSRect(x: originX, y: originY, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let toolbarView = CircleFloatingToolbarView(
            controller: self,
            onClose: { [weak self] in
                self?.dismissAllPanels()
            }
        )
        panel.contentView = NSHostingView(rootView: toolbarView)
        toolbarPanel = panel
        panel.makeKeyAndOrderFront(nil)
    }

    private func dismissAllPanels() {
        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
            self.escapeMonitor = nil
        }
        overlayPanel?.orderOut(nil)
        overlayPanel = nil
        toolbarPanel?.orderOut(nil)
        toolbarPanel = nil
    }

    private func installEscapeKeyMonitor() {
        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
        }
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.cancelSelection()
                return nil
            }
            return event
        }
    }

    private static func captureScreenRegion(topLeftPointsRect: CGRect, on screen: NSScreen) async throws -> CGImage {
        guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            throw MediaToolboxError.unsupportedInput("无法获取目标屏幕标识符")
        }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let scDisplay = content.displays.first(where: { $0.displayID == displayID }) ?? content.displays.first else {
            throw MediaToolboxError.unsupportedInput("未找到可捕获的显示器")
        }

        let scale = max(1.0, screen.backingScaleFactor)
        let filter = SCContentFilter(display: scDisplay, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.sourceRect = topLeftPointsRect
        config.width = max(1, Int((topLeftPointsRect.width * scale).rounded()))
        config.height = max(1, Int((topLeftPointsRect.height * scale).rounded()))
        config.showsCursor = false

        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }

    private static func encodePNGData(from cgImage: CGImage) -> Data? {
        let mutableData = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(mutableData, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(dest, cgImage, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return mutableData as Data
    }
}

private struct ScreenFreezeSelectionView: View {
    let mode: ScreenSelectionMode
    let screenFrame: CGRect
    let onSelectionFinished: (CGRect) -> Void
    let onCancel: () -> Void

    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?

    private var selectionRect: CGRect? {
        guard let s = dragStart, let c = dragCurrent else { return nil }
        return CGRect(
            x: min(s.x, c.x),
            y: min(s.y, c.y),
            width: abs(c.x - s.x),
            height: abs(c.y - s.y)
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.28)
                .ignoresSafeArea()

            if let rect = selectionRect {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.cyan, lineWidth: 2)
                    )
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
            }

            HStack(spacing: 10) {
                Image(systemName: mode == .ocrOnly ? "text.viewfinder" : "sparkle.magnifyingglass")
                    .foregroundStyle(.cyan)
                Text(mode == .ocrOnly ? "拖拽框选需要离线 OCR 识别的区域 · 按 Esc 取消" : "拖拽圈选屏幕内容：支持离线识字、AI 翻译解答与以图搜图 · 按 Esc 取消")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                Button("取消", action: onCancel)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.top, 44)
        }
        .frame(width: screenFrame.width, height: screenFrame.height)
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { value in
                    if dragStart == nil {
                        dragStart = value.startLocation
                    }
                    dragCurrent = value.location
                }
                .onEnded { value in
                    let start = dragStart ?? value.startLocation
                    let end = value.location
                    let finalRect = CGRect(
                        x: min(start.x, end.x),
                        y: min(start.y, end.y),
                        width: abs(end.x - start.x),
                        height: abs(end.y - start.y)
                    )
                    dragStart = nil
                    dragCurrent = nil
                    onSelectionFinished(finalRect)
                }
        )
    }
}

private struct CircleFloatingToolbarView: View {
    @ObservedObject var controller: CircleToSearchController
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Button {
                    controller.copyRecognizedText()
                } label: {
                    Label("复制文字", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(controller.recognizedText.isEmpty)

                Button {
                    Task { await controller.translateRecognizedText() }
                } label: {
                    Label("AI 翻译", systemImage: "character.bubble")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(controller.isWorking)

                Button {
                    Task { await controller.askAIAboutSelection() }
                } label: {
                    Label("AI 识图解答", systemImage: "sparkles")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(controller.isWorking)

                Button {
                    controller.searchInBrowser()
                } label: {
                    Label("浏览器搜图", systemImage: "safari")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if let banner = controller.statusBanner {
                HStack(spacing: 6) {
                    if controller.isWorking {
                        ProgressView().controlSize(.mini)
                    }
                    Text(banner)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if !controller.aiResultText.isEmpty {
                        Text(controller.aiResultText)
                            .font(.system(size: 12.5))
                            .textSelection(.enabled)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.12)))
                    }
                    if !controller.recognizedText.isEmpty {
                        Text(controller.recognizedText)
                            .font(.system(size: 12))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if controller.aiResultText.isEmpty {
                        Text("选区内未检测到明显文本，您可以直接点击上方「AI 识图解答」或「浏览器搜图」。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 440, height: 250)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
        )
    }
}
