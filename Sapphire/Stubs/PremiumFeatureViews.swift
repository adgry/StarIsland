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

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                SettingsCard(title: "Touch ID 应用隐私锁", description: "为敏感应用添加生物识别与密码护盾，未验证前自动遮蔽窗口内容。") {
                    ToggleRow(title: "启用应用隐私锁", description: "激活受保护应用时弹出模糊遮罩并请求验证", isOn: $model.settings.appLockEnabled)
                    Divider().padding(.leading, 16)
                    ToggleRow(title: "使用 Touch ID 验证", isOn: $model.settings.appLockTouchIDEnabled)
                    Divider().padding(.leading, 16)
                    ToggleRow(title: "允许密码备用解锁", isOn: $model.settings.appLockPasswordFallbackEnabled)
                    Divider().padding(.leading, 16)
                    ToggleRow(title: "睡眠唤醒后重新加锁", isOn: $model.settings.appLockLockOnSleep)
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
                                if panel.runModal() == .OK,
                                   let url = panel.url,
                                   let bid = Bundle(url: url)?.bundleIdentifier {
                                    model.settings.appLockProtectedApps.insert(bid)
                                    lockManager.refresh()
                                }
                            }
                            .buttonStyle(.borderedProminent)

                            if !bundleIDInput.trimmingCharacters(in: .whitespaces).isEmpty {
                                Button("添加 ID") {
                                    model.settings.appLockProtectedApps.insert(bundleIDInput.trimmingCharacters(in: .whitespaces))
                                    bundleIDInput = ""
                                    lockManager.refresh()
                                }
                                .buttonStyle(.bordered)
                            }
                        }

                        ForEach(Array(model.settings.appLockProtectedApps).sorted(), id: \.self) { bid in
                            HStack {
                                Image(systemName: "lock.shield.fill").foregroundStyle(.cyan)
                                Text(AppShieldManager.displayName(for: bid))
                                    .font(.system(size: 13, weight: .medium))
                                Text(bid)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button(role: .destructive) {
                                    model.settings.appLockProtectedApps.remove(bid)
                                    lockManager.refresh()
                                } label: {
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
    }
}

struct ContinuitySettingsView: View {
    @ObservedObject private var model = SettingsModel.shared

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                SettingsCard(title: "星岛跨端局域网快传门户", description: "手机或平板扫码输入 6 位动态配对码，免装 App 互传剪贴板、文件与媒体控制。") {
                    ToggleRow(title: "启用局域网跨端互通服务", description: "启动本地加密配对网关并广播 Bonjour 服务", isOn: $model.settings.continuityEnabled)
                        .onChange(of: model.settings.continuityEnabled) { _, enabled in
                            if enabled {
                                ContinuityManager.shared.startIfEnabled()
                            } else {
                                ContinuityManager.shared.stop()
                            }
                        }
                    Divider().padding(.leading, 16)
                    ToggleRow(title: "双向同步剪贴板", isOn: $model.settings.continuityClipboardSync)
                    Divider().padding(.leading, 16)
                    ToggleRow(title: "允许跨设备文件收发", isOn: $model.settings.continuityFiles)
                    Divider().padding(.leading, 16)
                    ToggleRow(title: "允许网页端遥控媒体播放", isOn: $model.settings.continuityMediaControls)
                }
            }
            .padding(24)
        }
    }
}
#endif
