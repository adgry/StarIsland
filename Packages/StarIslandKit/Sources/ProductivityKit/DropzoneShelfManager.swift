import AppKit
import Combine
import Foundation
import IslandCore
import UniformTypeIdentifiers

public struct ShelfFileItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let fileURL: URL
    public var fileName: String
    public var fileSizeBytes: Int64
    public var utiIdentifier: String
    public var addedAt: Date

    public init(
        id: UUID = UUID(),
        fileURL: URL,
        fileName: String? = nil,
        fileSizeBytes: Int64? = nil,
        utiIdentifier: String? = nil,
        addedAt: Date = Date()
    ) {
        let standardized = fileURL.standardizedFileURL
        self.id = id
        self.fileURL = standardized
        self.fileName = fileName ?? standardized.lastPathComponent

        if let fileSizeBytes {
            self.fileSizeBytes = fileSizeBytes
        } else {
            let attrs = try? FileManager.default.attributesOfItem(atPath: standardized.path)
            self.fileSizeBytes = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
        }

        if let utiIdentifier {
            self.utiIdentifier = utiIdentifier
        } else if let contentType = try? standardized.resourceValues(forKeys: [.contentTypeKey]).contentType {
            self.utiIdentifier = contentType.identifier
        } else {
            self.utiIdentifier = UTType(filenameExtension: standardized.pathExtension)?.identifier ?? UTType.data.identifier
        }

        self.addedAt = addedAt
    }

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSizeBytes, countStyle: .file)
    }

    public var contentType: UTType? {
        UTType(utiIdentifier) ?? UTType(filenameExtension: fileURL.pathExtension)
    }

    public var isImage: Bool {
        contentType?.conforms(to: .image) ?? false
    }

    public var isPDF: Bool {
        contentType?.conforms(to: .pdf) ?? (fileURL.pathExtension.lowercased() == "pdf")
    }

    public var isAudioOrVideo: Bool {
        guard let ct = contentType else { return false }
        return ct.conforms(to: .movie) || ct.conforms(to: .video) || ct.conforms(to: .audio)
    }

    public var canOptimizeLocally: Bool {
        isImage || isPDF || isAudioOrVideo
    }
}

@MainActor
public final class DropzoneShelfManager: ObservableObject {
    public static let shared = DropzoneShelfManager()

    @Published public private(set) var items: [ShelfFileItem] = []
    @Published public private(set) var isProcessing: Bool = false
    @Published public var lastReportMessage: String?

    private let storageURL: URL
    private let stateMachine: IslandStateMachine
    private let settingsStore: SettingsStore
    private var globalDragMonitor: Any?
    private var globalMouseUpMonitor: Any?
    private var observedDragChangeCount: Int = 0

    public init(
        storageURL: URL? = nil,
        stateMachine: IslandStateMachine? = nil,
        settingsStore: SettingsStore? = nil
    ) {
        self.storageURL = storageURL ?? StarIslandPaths.appSupportDirectory.appendingPathComponent("dropzone-shelf.json")
        self.stateMachine = stateMachine ?? .shared
        self.settingsStore = settingsStore ?? .shared
        self.items = Self.loadFromDisk(url: self.storageURL)
    }

    @discardableResult
    public func addFiles(_ urls: [URL]) -> Int {
        guard settingsStore.settings.enableDropzoneShelf else { return 0 }
        var addedCount = 0

        for rawURL in urls {
            let cleanURL = rawURL.standardizedFileURL
            guard FileManager.default.fileExists(atPath: cleanURL.path) else { continue }
            if items.contains(where: { $0.fileURL.standardizedFileURL == cleanURL }) {
                continue
            }
            let newItem = ShelfFileItem(fileURL: cleanURL)
            items.insert(newItem, at: 0)
            addedCount += 1
        }

        if addedCount > 0 {
            persist()
            let peekItem = IslandActivityItem(
                id: "shelf-added",
                category: .shelf,
                title: "已暂存 \(addedCount) 个文件",
                subtitle: "当前暂存架共 \(items.count) 项 · 可一键压缩或拖出",
                iconSymbol: "tray.and.arrow.down.fill",
                trailingBadge: "\(items.count)",
                priority: .interactive,
                isPeek: true,
                allowsOnLockScreen: false,
                autoDismissAfter: 3.0
            )
            stateMachine.submit(peekItem)
        }

        return addedCount
    }

    @discardableResult
    public func addTextSnippet(_ text: String) -> ShelfFileItem? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let snippetsDir = StarIslandPaths.cachesDirectory.appendingPathComponent("ShelfSnippets", isDirectory: true)
        try? FileManager.default.createDirectory(at: snippetsDir, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "HHmmss"
        let fileURL = snippetsDir.appendingPathComponent("文本摘录-\(formatter.string(from: Date())).txt")
        do {
            try Data(trimmed.utf8).write(to: fileURL, options: .atomic)
            _ = addFiles([fileURL])
            return items.first(where: { $0.fileURL == fileURL.standardizedFileURL })
        } catch {
            return nil
        }
    }

    public func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
        persist()
    }

    public func remove(_ item: ShelfFileItem) {
        remove(item.id)
    }

    public func clear() {
        items.removeAll()
        lastReportMessage = nil
        persist()
    }

    public func revealInFinder(_ item: ShelfFileItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.fileURL])
    }

    public func shareViaAirDrop(_ urls: [URL]? = nil) {
        let targets = urls ?? items.map(\.fileURL)
        guard !targets.isEmpty,
              let service = NSSharingService(named: .sendViaAirDrop) else { return }
        service.perform(withItems: targets)
    }

    public func optimizeItem(_ item: ShelfFileItem, videoPreset: MediaConvertPreset = .hevcHighestQuality) async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }

        let quality = settingsStore.settings.imageCompressionQuality
        do {
            let report: MediaOptimizationReport
            if item.isImage {
                report = try await Task.detached(priority: .userInitiated) {
                    try MediaToolbox.compressImage(at: item.fileURL, quality: quality)
                }.value
            } else if item.isPDF {
                report = try await Task.detached(priority: .userInitiated) {
                    try MediaToolbox.compressPDF(at: item.fileURL)
                }.value
            } else if item.isAudioOrVideo {
                report = try await MediaToolbox.convertAudioOrVideo(at: item.fileURL, preset: videoPreset)
            } else {
                lastReportMessage = "该文件格式暂不支持媒体压缩：\(item.fileName)"
                return
            }

            _ = addFiles([report.outputURL])
            lastReportMessage = report.summaryText
        } catch {
            lastReportMessage = "处理失败：\(error.localizedDescription)"
        }
    }

    public func optimizeAll() async {
        let targets = items.filter(\.canOptimizeLocally)
        guard !targets.isEmpty else {
            lastReportMessage = "暂存架中没有可压缩的图片、PDF 或音视频文件"
            return
        }
        for target in targets {
            await optimizeItem(target)
        }
    }

    public func startGlobalDragMonitor() {
        stopGlobalDragMonitor()
        observedDragChangeCount = NSPasteboard(name: .drag).changeCount

        globalDragMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { [weak self] _ in
            Task { @MainActor in
                self?.handleGlobalMouseDragged()
            }
        }
        globalMouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            Task { @MainActor in
                self?.stateMachine.setDraggingFilesNearTop(false)
            }
        }
    }

    public func stopGlobalDragMonitor() {
        if let globalDragMonitor {
            NSEvent.removeMonitor(globalDragMonitor)
            self.globalDragMonitor = nil
        }
        if let globalMouseUpMonitor {
            NSEvent.removeMonitor(globalMouseUpMonitor)
            self.globalMouseUpMonitor = nil
        }
    }

    private func handleGlobalMouseDragged() {
        guard settingsStore.settings.enableDropzoneShelf else { return }
        let dragPB = NSPasteboard(name: .drag)
        guard dragPB.changeCount != observedDragChangeCount || stateMachine.isDraggingFilesNearTop else {
            return
        }
        let mouseLoc = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) else {
            return
        }
        let distanceFromTop = screen.frame.maxY - mouseLoc.y
        if distanceFromTop <= 36 {
            observedDragChangeCount = dragPB.changeCount
            stateMachine.setDraggingFilesNearTop(true)
        } else if distanceFromTop > 260, stateMachine.isDraggingFilesNearTop {
            stateMachine.setDraggingFilesNearTop(false)
        }
    }

    private func persist() {
        let dir = storageURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: storageURL, options: .atomic)
        }
    }

    private static func loadFromDisk(url: URL) -> [ShelfFileItem] {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([ShelfFileItem].self, from: data) else {
            return []
        }
        return decoded.filter { FileManager.default.fileExists(atPath: $0.fileURL.path) }
    }
}
