import AppKit
import IslandCore
import SwiftUI
import UniformTypeIdentifiers

public struct ShelfIslandTabView: View {
    @ObservedObject private var shelfManager: DropzoneShelfManager
    @ObservedObject private var clipboardManager: ClipboardManager
    @ObservedObject private var inboxCoordinator: SmartInboxCoordinator
    @ObservedObject private var circleController: CircleToSearchController

    @State private var isDropTargeted: Bool = false

    @MainActor
    public init(
        shelfManager: DropzoneShelfManager? = nil,
        clipboardManager: ClipboardManager? = nil,
        inboxCoordinator: SmartInboxCoordinator? = nil,
        circleController: CircleToSearchController? = nil
    ) {
        self.shelfManager = shelfManager ?? .shared
        self.clipboardManager = clipboardManager ?? .shared
        self.inboxCoordinator = inboxCoordinator ?? .shared
        self.circleController = circleController ?? .shared
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            quickToolsHeader
            dropzoneContainer
            if !inboxCoordinator.recentOTPs.isEmpty || !inboxCoordinator.recentParcels.isEmpty {
                smartInboxStrip
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var quickToolsHeader: some View {
        HStack(spacing: 8) {
            Button {
                circleController.beginSelection(mode: .ocrOnly)
            } label: {
                Label("离线 OCR", systemImage: "text.viewfinder")
                    .font(.system(size: 11.5, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                circleController.beginSelection(mode: .circleToSearch)
            } label: {
                Label("圈选识图", systemImage: "sparkle.magnifyingglass")
                    .font(.system(size: 11.5, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                clipboardManager.presentPicker()
            } label: {
                Label("剪贴板 (\(clipboardManager.items.count))", systemImage: "doc.on.clipboard")
                    .font(.system(size: 11.5, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer()

            if !shelfManager.items.isEmpty {
                Button {
                    Task { await shelfManager.optimizeAll() }
                } label: {
                    Label(shelfManager.isProcessing ? "压缩中…" : "一键压缩", systemImage: "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 11.5, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(shelfManager.isProcessing)

                Button {
                    shelfManager.shareViaAirDrop()
                } label: {
                    Image(systemName: "airplayaudio")
                        .font(.system(size: 11.5))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("隔空投送暂存架全部文件")

                Button {
                    shelfManager.clear()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11.5))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("清空暂存架")
            }
        }
    }

    private var dropzoneContainer: some View {
        VStack(alignment: .leading, spacing: 6) {
            if shelfManager.items.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: isDropTargeted ? "arrow.down.doc.fill" : "tray.and.arrow.down")
                        .font(.system(size: 22))
                        .foregroundStyle(isDropTargeted ? Color.cyan : Color.secondary)
                    Text("拖拽任意文件、图片、PDF 或文本到此处暂存")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                    Text("支持多文件合并拖出、去定位图片压缩、PDF 瘦身与音视频转换")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 88)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(shelfManager.items) { item in
                            ShelfCardItemView(
                                item: item,
                                isBusy: shelfManager.isProcessing,
                                onOptimize: {
                                    Task { await shelfManager.optimizeItem(item) }
                                },
                                onReveal: {
                                    shelfManager.revealInFinder(item)
                                },
                                onRemove: {
                                    shelfManager.remove(item.id)
                                }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(height: 82)
            }

            if let report = shelfManager.lastReportMessage {
                Text(report)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.green)
                    .lineLimit(1)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isDropTargeted ? Color.cyan.opacity(0.14) : Color.primary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isDropTargeted ? Color.cyan : Color.primary.opacity(0.14),
                    style: StrokeStyle(lineWidth: 1, dash: shelfManager.items.isEmpty ? [5, 4] : [])
                )
        )
        .onDrop(of: [.fileURL, .plainText], isTargeted: $isDropTargeted) { providers in
            handleDropProviders(providers)
        }
    }

    private var smartInboxStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(inboxCoordinator.recentOTPs.prefix(4)) { otp in
                    Button {
                        inboxCoordinator.copyOTPAndCollapse(otp.code)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "key.horizontal.fill")
                                .foregroundStyle(.orange)
                            Text("验证码 \(otp.code)")
                                .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                            Text("复制")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.orange.opacity(0.14)))
                    }
                    .buttonStyle(.plain)
                }

                ForEach(inboxCoordinator.recentParcels.prefix(4)) { parcel in
                    Button {
                        inboxCoordinator.openParcelTracking(parcel)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "shippingbox.fill")
                                .foregroundStyle(.cyan)
                            Text("\(parcel.carrierName) \(parcel.trackingNumber)")
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.cyan.opacity(0.14)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func handleDropProviders(_ providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                handled = true
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                    let resolvedURL: URL?
                    if let urlData = data as? Data {
                        resolvedURL = URL(dataRepresentation: urlData, relativeTo: nil)
                    } else if let directURL = data as? URL {
                        resolvedURL = directURL
                    } else {
                        resolvedURL = nil
                    }
                    if let resolvedURL {
                        Task { @MainActor in
                            _ = self.shelfManager.addFiles([resolvedURL])
                        }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                handled = true
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                    let str: String?
                    if let s = item as? String {
                        str = s
                    } else if let d = item as? Data {
                        str = String(data: d, encoding: .utf8)
                    } else {
                        str = nil
                    }
                    if let str {
                        Task { @MainActor in
                            _ = self.shelfManager.addTextSnippet(str)
                        }
                    }
                }
            }
        }
        return handled
    }
}

private struct ShelfCardItemView: View {
    let item: ShelfFileItem
    let isBusy: Bool
    let onOptimize: () -> Void
    let onReveal: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: item.fileURL.path))
                    .resizable()
                    .frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.fileName)
                        .font(.system(size: 11.5, weight: .medium))
                        .lineLimit(1)
                    Text(item.formattedSize)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 2)
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 6) {
                if item.canOptimizeLocally {
                    Button(item.isPDF ? "PDF 瘦身" : "压缩", action: onOptimize)
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .disabled(isBusy)
                }
                Button("定位", action: onReveal)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
            }
        }
        .padding(8)
        .frame(width: 168)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.07)))
        .onDrag {
            NSItemProvider(object: item.fileURL as NSURL)
        }
    }
}

// MARK: - 效率与视觉工具完整中文设置页

public struct ProductivitySettingsPaneView: View {
    @ObservedObject private var settingsStore: SettingsStore
    @ObservedObject private var clipboardManager: ClipboardManager
    @ObservedObject private var shelfManager: DropzoneShelfManager
    @ObservedObject private var inboxCoordinator: SmartInboxCoordinator
    @ObservedObject private var circleController: CircleToSearchController

    @MainActor
    public init(
        settingsStore: SettingsStore? = nil,
        clipboardManager: ClipboardManager? = nil,
        shelfManager: DropzoneShelfManager? = nil,
        inboxCoordinator: SmartInboxCoordinator? = nil,
        circleController: CircleToSearchController? = nil
    ) {
        self.settingsStore = settingsStore ?? .shared
        self.clipboardManager = clipboardManager ?? .shared
        self.shelfManager = shelfManager ?? .shared
        self.inboxCoordinator = inboxCoordinator ?? .shared
        self.circleController = circleController ?? .shared
    }

    private var customParamsBinding: Binding<String> {
        Binding(
            get: { settingsStore.settings.customBlockedURLParams.joined(separator: ", ") },
            set: { newValue in
                let parts = newValue
                    .split(whereSeparator: { $0 == "," || $0 == "，" || $0.isWhitespace })
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                settingsStore.settings.customBlockedURLParams = parts
            }
        )
    }

    public var body: some View {
        Form {
            Section("智能验证码与快递物流识别") {
                Toggle("启用双因子智能验证码识别（严格排除聊天普通数字与重复弹窗）", isOn: $settingsStore.settings.enableSmartOTP)
                Toggle("检测到新验证码后自动复制到系统剪贴板", isOn: $settingsStore.settings.autoCopyOTP)
                    .disabled(!settingsStore.settings.enableSmartOTP)
                Toggle("自动识别快递物流单号（顺丰 / 京东 / 通达系 / EMS / UPS / FedEx / DHL）", isOn: $settingsStore.settings.enableParcelTracking)
            }

            Section("可视化剪贴板中心与追踪链接净化") {
                Toggle("记录剪贴板历史（自动跳过 1Password / 系统钥匙串等密码隐私条目）", isOn: $settingsStore.settings.enableClipboardHistory)

                Stepper(
                    "最大历史保留条数：\(settingsStore.settings.clipboardMaxItems) 条",
                    value: $settingsStore.settings.clipboardMaxItems,
                    in: 20...500,
                    step: 20
                )

                Picker("隐私倒计时自动清空", selection: $settingsStore.settings.clipboardAutoClearMinutes) {
                    Text("不自动清空").tag(0)
                    Text("5 分钟后自动清空未置顶记录").tag(5)
                    Text("15 分钟后自动清空未置顶记录").tag(15)
                    Text("30 分钟后自动清空未置顶记录").tag(30)
                    Text("60 分钟后自动清空未置顶记录").tag(60)
                }

                Toggle("复制链接时自动剥离追踪参数（utm_*、fbclid、gclid、spm、vd_source 等）", isOn: $settingsStore.settings.enableCleanURL)

                TextField("自定义额外剥离参数（以逗号分隔，例如 ref, track_id）", text: customParamsBinding)
                    .disabled(!settingsStore.settings.enableCleanURL)

                HStack(spacing: 12) {
                    Button("打开剪贴板悬浮选择器（⌥⌘V）") {
                        clipboardManager.presentPicker()
                    }
                    Button("清空全部剪贴板历史", role: .destructive) {
                        clipboardManager.clearAll(keepPinned: false)
                    }
                    Spacer()
                    Text("当前已存 \(clipboardManager.items.count) 条")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("灵动文件暂存架与本地媒体无损/有损压缩") {
                Toggle("拖拽文件靠近屏幕顶部边缘时自动展开灵动岛暂存架", isOn: $settingsStore.settings.enableDropzoneShelf)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("本地图片压缩默认画质（自动清除 GPS 定位 EXIF）")
                        Spacer()
                        Text("\(Int((settingsStore.settings.imageCompressionQuality * 100).rounded()))%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settingsStore.settings.imageCompressionQuality, in: 0.40...0.95, step: 0.05)
                }
            }

            Section("离线 Vision OCR 识字与圈选识图搜索") {
                Text("内置 Apple Vision 高精度多语种引擎（简体中文 / 繁体中文 / 英语 / 日语 / 韩语及二维码识别），全程本机离线完成，并可一键联动星岛 AI 翻译或识图解答。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button("立即启动离线 OCR 框选（⇧⌘2）") {
                        circleController.beginSelection(mode: .ocrOnly)
                    }
                    Button("立即启动圈选识图搜索（⇧⌘S）") {
                        circleController.beginSelection(mode: .circleToSearch)
                    }
                    Spacer()
                    Button("检查屏幕录制权限") {
                        PermissionsCenter.shared.openSystemSettings(for: .screenRecording)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
