//
//  PremiumFeatureViews.swift
//  Sapphire
//

#if !SAPPHIRE_FULL_BUILD
import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SystemPowerReading {
    let systemLoad: Double
    let adapterPower: Double
    let adapterConnected: Bool
    let isCharging: Bool

    var heroWatts: Double { adapterConnected ? max(adapterPower, systemLoad) : systemLoad }
    var adapterDisplayWatts: Double { adapterPower > 0 ? adapterPower : heroWatts }
    var statusLabel: String { isCharging ? "正在充电" : (adapterConnected ? "使用电源适配器" : "使用电池供电") }
    var statusColor: Color { isCharging ? .green : (adapterConnected ? .cyan : .orange) }
}

struct PowerSplitBar: View {
    let reading: SystemPowerReading
    var body: some View { Capsule().fill(reading.statusColor) }
}

extension StatsManager {
    var adapterSensorPower: Double { 0 }
}

struct ClipboardItemThumbnailView: View {
    let item: ClipboardItem
    var size: CGFloat = 24
    var cornerRadius: CGFloat = 7
    var fallbackSystemImage = "photo"
    var fallbackTint: Color = .purple
    var strokeColor: Color?

    var body: some View {
        Group {
            if let data = item.resolvedImageData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .overlay {
                        if let strokeColor {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .stroke(strokeColor, lineWidth: 1)
                        }
                    }
            } else {
                Image(systemName: fallbackSystemImage)
                    .foregroundStyle(fallbackTint)
                    .frame(width: size, height: size)
            }
        }
    }
}

struct AppLockSettingsView: View {
    @ObservedObject private var model = SettingsModel.shared
    @ObservedObject private var lockManager = AppLockManager.shared
    @State private var bundleIDInput: String = ""
    @State private var fallbackPassInput: String = ""
    @State private var passBanner: String = ""

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                SettingsCard(title: "Touch ID 应用隐私锁", description: "为敏感应用添加生物识别与密码护盾，未验证前自动遮蔽窗口内容。") {
                    ToggleRow(title: "启用应用隐私锁", description: "激活受保护应用时弹出模糊遮罩并请求验证", isOn: $model.settings.appLockEnabled)
                        .onChange(of: model.settings.appLockEnabled) { _, _ in lockManager.refresh() }
                    Divider().padding(.leading, 16)
                    ToggleRow(title: "使用 Touch ID 验证", isOn: $model.settings.appLockTouchIDEnabled)
                    Divider().padding(.leading, 16)
                    ToggleRow(title: "允许密码备用解锁", isOn: $model.settings.appLockPasswordFallbackEnabled)
                    Divider().padding(.leading, 16)
                    ToggleRow(title: "睡眠唤醒后重新加锁", isOn: $model.settings.appLockLockOnSleep)
                    Divider().padding(.leading, 16)

                    HStack(spacing: 10) {
                        SecureField(lockManager.hasPasswordFallback ? "已配置备用密码（输入可更新）" : "设置备用解锁密码", text: $fallbackPassInput)
                            .textFieldStyle(.roundedBorder)
                        Button("保存密码") {
                            lockManager.setFallbackPassword(fallbackPassInput)
                            fallbackPassInput = ""
                            passBanner = "备用密码已安全加密保存"
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(fallbackPassInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(16)
                    if !passBanner.isEmpty {
                        Text(passBanner).font(.system(size: 12)).foregroundStyle(.green).padding(.horizontal, 16).padding(.bottom, 10)
                    }
                }

                SettingsCard(title: "受保护的应用列表", description: "添加需要加锁的应用程序包标识符（Bundle ID）或从应用程序中选择。") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            TextField("输入 Bundle ID（如 com.tencent.xinWeChat）", text: $bundleIDInput)
                                .textFieldStyle(.roundedBorder)
                            Button("添加应用…") {
                                let panel = NSOpenPanel()
                                panel.directoryURL = URL(fileURLWithPath: "/Applications")
                                panel.allowedContentTypes = [.applicationBundle]
                                if panel.runModal() == .OK, let url = panel.url, let bid = Bundle(url: url)?.bundleIdentifier {
                                    model.settings.appLockProtectedApps.insert(bid)
                                    lockManager.refresh()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        ForEach(Array(model.settings.appLockProtectedApps).sorted(), id: \.self) { bid in
                            HStack {
                                Image(systemName: "lock.shield.fill").foregroundStyle(.cyan)
                                Text(AppShieldManager.displayName(for: bid)).font(.system(size: 13, weight: .medium))
                                Text(bid).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                                Spacer()
                                Button(role: .destructive) {
                                    model.settings.appLockProtectedApps.remove(bid)
                                    lockManager.refresh()
                                } label: { Image(systemName: "trash") }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .padding(24)
        }
    }
}

struct ContinuitySettingsView: View {
    @ObservedObject private var model = SettingsModel.shared
    @ObservedObject private var portal = StarIslandLANPortalServer.shared

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                SettingsCard(title: "星岛跨端局域网快传门户", description: "手机或平板扫码输入 6 位动态配对码，免装 App 互传剪贴板、文件与媒体控制。") {
                    ToggleRow(title: "启用局域网跨端互通服务", description: "启动本地加密配对网关并广播 Bonjour 服务", isOn: $model.settings.continuityEnabled)
                        .onChange(of: model.settings.continuityEnabled) { _, enabled in
                            if enabled { ContinuityManager.shared.startIfEnabled() } else { ContinuityManager.shared.stop() }
                        }
                    Divider().padding(.leading, 16)

                    HStack(spacing: 20) {
                        if let qr = portal.qrCodeImage {
                            Image(nsImage: qr)
                                .interpolation(.none)
                                .resizable()
                                .frame(width: 116, height: 116)
                                .padding(8)
                                .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Text("一次性 6 位安全码：")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                                Text(portal.currentPIN)
                                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.cyan)
                                Button("轮换配对码") { portal.refreshPIN() }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                            }
                            Text("网关状态：\(portal.statusMessage)")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            if let url = portal.pairingURL {
                                Button("复制局域网门户链接") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(url.absoluteString, forType: .string)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                    .padding(16)

                    Divider().padding(.leading, 16)
                    ToggleRow(title: "双向同步剪贴板", isOn: $model.settings.continuityClipboardSync)
                    Divider().padding(.leading, 16)
                    ToggleRow(title: "允许跨设备文件收发", isOn: $model.settings.continuityFiles)
                    Divider().padding(.leading, 16)
                    ToggleRow(title: "允许网页端遥控媒体播放", isOn: $model.settings.continuityMediaControls)
                }

                SettingsCard(title: "Mac 共享文件列表", description: "添加至此的文件可在已配对的手机网页端一键下载。") {
                    VStack(alignment: .leading, spacing: 10) {
                        Button("添加共享文件…") {
                            let panel = NSOpenPanel()
                            panel.allowsMultipleSelection = true
                            if panel.runModal() == .OK { portal.addSharedFiles(panel.urls) }
                        }
                        .buttonStyle(.borderedProminent)

                        ForEach(portal.sharedFiles) { file in
                            HStack {
                                Image(systemName: "doc.fill").foregroundStyle(.blue)
                                Text(file.name).font(.system(size: 13)).lineLimit(1)
                                Spacer()
                                Text(ByteCountFormatter.string(fromByteCount: file.sizeBytes, countStyle: .file))
                                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                                Button(role: .destructive) { portal.removeSharedFile(id: file.id) } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .padding(24)
        }
        .onAppear {
            if model.settings.continuityEnabled && !portal.isRunning {
                portal.start()
            }
        }
    }
}
#endif
