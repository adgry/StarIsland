import AppKit
import IslandCore
import SwiftUI
import UniformTypeIdentifiers

/// 灵动岛「手机互联」扫码配对与双向快传工作台
public struct ConnectIslandTabView: View {
    @ObservedObject private var server: LANContinuityServer
    @ObservedObject private var settingsStore: SettingsStore
    @State private var isDropTargeted: Bool = false

    @MainActor
    public init(
        server: LANContinuityServer? = nil,
        settingsStore: SettingsStore? = nil
    ) {
        self.server = server ?? .shared
        self.settingsStore = settingsStore ?? .shared
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 14) {
            qrPairingCard
                .frame(width: 176)

            Divider()

            transferWorkspace
        }
        .padding(12)
        .onAppear {
            if settingsStore.settings.enableLANContinuityServer && !server.isRunning {
                server.start()
            }
        }
    }

    private var qrPairingCard: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .frame(width: 128, height: 128)
                if let qr = server.qrCodeImage {
                    Image(nsImage: qr)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 114, height: 114)
                } else {
                    Image(systemName: "qrcode")
                        .font(.largeTitle)
                        .foregroundStyle(Color.black)
                }
            }

            VStack(spacing: 2) {
                Text("6 位动态安全配对码")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.secondary)
                Text(server.currentPIN)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .tracking(2)
            }

            Text(server.isRunning ? "\(server.localIPAddress):\(server.listeningPort)" : "局域网服务未启动")
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(server.isRunning ? Color.green : Color.secondary)
                .lineLimit(1)

            HStack(spacing: 6) {
                Button(server.isRunning ? "刷新配对码" : "立即启动") {
                    if server.isRunning {
                        server.refreshPIN()
                    } else {
                        server.start()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)

                if let url = server.pairingURL {
                    Button("复制链接") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(url.absoluteString, forType: .string)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }
        }
    }

    private var transferWorkspace: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(
                    server.connectedSessions.isEmpty
                        ? "手机相机扫码免装 App 即连"
                        : "已连接 \(server.connectedSessions.count) 台手机",
                    systemImage: server.connectedSessions.isEmpty ? "iphone.slash" : "iphone.radiowaves.left.and.right"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(server.connectedSessions.isEmpty ? Color.secondary : Color.green)

                Spacer()

                Button("添加共享文件") {
                    pickFilesToShare()
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Mac 共享列表（拖入文件供手机下载）")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.secondary)

                ScrollView {
                    if server.sharedFiles.isEmpty {
                        Text("拖拽任意文件到此处，手机端网页点击即可极速下载")
                            .font(.caption2)
                            .foregroundStyle(Color.secondary)
                            .frame(maxWidth: .infinity, minHeight: 46)
                    } else {
                        VStack(spacing: 4) {
                            ForEach(server.sharedFiles) { item in
                                HStack {
                                    Image(systemName: "doc.fill")
                                        .font(.caption)
                                        .foregroundStyle(Color.blue)
                                    Text(item.name)
                                        .font(.caption)
                                        .lineLimit(1)
                                    Spacer()
                                    Button {
                                        server.removeSharedFile(id: item.id)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(Color.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .frame(height: 62)
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(isDropTargeted ? 0.14 : 0.05))
                )
                .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                    handleDroppedProviders(providers)
                }
            }

            if !server.receivedFiles.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("最近收到的手机快传")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.secondary)
                    ForEach(server.receivedFiles.prefix(2)) { recv in
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(Color.green)
                                .font(.caption)
                            Text(recv.name)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            Button("在访达中显示") {
                                NSWorkspace.shared.activateFileViewerSelecting([recv.fileURL])
                            }
                            .buttonStyle(.link)
                            .font(.caption2)
                        }
                    }
                }
            }
        }
    }

    private func pickFilesToShare() {
        let panel = NSOpenPanel()
        panel.title = "选择要共享给手机下载的文件"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            server.addSharedFiles(panel.urls)
        }
    }

    private func handleDroppedProviders(_ providers: [NSItemProvider]) -> Bool {
        var accepted = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            accepted = true
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let resolvedURL: URL?
                if let data = item as? Data {
                    resolvedURL = URL(dataRepresentation: data, relativeTo: nil)
                } else if let url = item as? URL {
                    resolvedURL = url
                } else {
                    resolvedURL = nil
                }
                if let resolvedURL {
                    Task { @MainActor in
                        server.addSharedFiles([resolvedURL])
                    }
                }
            }
        }
        return accepted
    }
}
