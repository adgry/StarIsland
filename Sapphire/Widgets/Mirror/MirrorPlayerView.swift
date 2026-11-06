//
//  MirrorPlayerView.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2026-08-11
//

import SwiftUI
import AVFoundation
import AppKit

struct MirrorPlayerView: View {
    @Environment(\.navigationStack) var navigationStack
    @ObservedSettings var settings: SettingsObserver
    @ObservedObject private var camera = MirrorCameraManager.shared

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ZStack {
                if camera.isLive {
                    MirrorCameraPreviewView(
                        session: camera.session,
                        flipHorizontally: settings.settings.mirrorFlipHorizontally,
                        rotationAngle: camera.effectivePreviewRotationAngle,
                        sessionEpoch: camera.sessionEpoch
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                } else {
                    offlineState
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(width: 560, height: 380)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.indigo.opacity(0.22), Color.black.opacity(0.28)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(MaterialChartPalette.outlineStrong, lineWidth: 1)
        )
        .onAppear {
            if camera.isLive {
                camera.restartPreviewIfNeeded()
            } else {
                camera.start()
            }
        }
        .onDisappear {
            MirrorCameraManager.shared.teardown()
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(camera.isLive ? Color.green.opacity(0.2) : Color.white.opacity(0.08))
                        .frame(width: 30, height: 30)
                    Image(systemName: "camera.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(camera.isLive ? Color.green : Color.secondary)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("随身镜")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    if camera.isLive {
                        HStack(spacing: 4) {
                            Circle().fill(Color.red).frame(width: 5, height: 5)
                            Text("实时预览")
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.red.opacity(0.9))
                        }
                    } else {
                        Text(camera.isDenied ? "无摄像头权限" : (camera.isError ? "摄像头不可用" : "摄像头已关闭"))
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 8)

            if camera.cameras.count > 1 {
                cameraPicker
            }

            if camera.isLive {
                iconButton(systemName: "arrow.left.arrow.right", help: "水平镜像翻转") {
                    settings.settings.mirrorFlipHorizontally.toggle()
                    camera.updateMirroring(flipHorizontally: settings.settings.mirrorFlipHorizontally)
                }

                iconButton(systemName: "rotate.right", help: "旋转画面") {
                    settings.settings.mirrorRotationMode = settings.settings.mirrorRotationMode.next
                }

                stopButton
            }

            iconButton(systemName: "arrow.up.left.and.arrow.down.right", help: "全屏显示") {
                MirrorFullscreenWindowController.shared.present()
            }

            closeButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func iconButton(systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 30, height: 30)
                .background(.black.opacity(0.28), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var cameraPicker: some View {
        Menu {
            MirrorCameraMenuItems(camera: camera)
        } label: {
            Image(systemName: "web.camera")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 30, height: 30)
                .background(.black.opacity(0.28), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 0.5))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("选择摄像头")
    }

    private var stopButton: some View {
        Button {
            camera.stop()
        } label: {
            Label("停止", systemImage: "stop.fill")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.red.opacity(0.85), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .help("关闭摄像头")
    }

    private var closeButton: some View {
        Button {
            camera.stop()
            if navigationStack.wrappedValue.count > 1 {
                navigationStack.wrappedValue.removeLast()
            } else {
                navigationStack.wrappedValue = [.defaultWidgets]
            }
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 30, height: 30)
                .background(.black.opacity(0.28), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .help("关闭面板并停用摄像头")
    }

    private var offlineState: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.indigo.opacity(0.45), Color.purple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 84, height: 84)
                Circle()
                    .stroke(.white.opacity(0.2), lineWidth: 1)
                    .frame(width: 84, height: 84)
                Image(systemName: camera.isDenied ? "camera.slash" : "camera")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(.white.opacity(0.9))
            }

            VStack(spacing: 6) {
                Text(camera.isDenied ? "摄像头访问被拒绝" : (camera.isError ? "摄像头不可用" : (camera.isPending ? "正在启动摄像头…" : "摄像头已关闭")))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                Text(offlineMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            HStack(spacing: 10) {
                if camera.isPending {
                    Button {
                        camera.stop()
                    } label: {
                        Label("取消", systemImage: "xmark")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button {
                        camera.start()
                    } label: {
                        Label("开启摄像头", systemImage: "camera.fill")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(camera.isDenied ? Color.red : Color.indigo)
                    .disabled(camera.isDenied)
                }

                if camera.isDenied {
                    Button("打开隐私设置") {
                        camera.openSystemPrivacySettings()
                    }
                    .buttonStyle(.bordered)
                } else if camera.isError {
                    Button("重试") {
                        camera.start()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }

    private var offlineMessage: String {
        if camera.isDenied {
            return "请在“系统设置 → 隐私与安全性 → 摄像头”中授予摄像头访问权限以使用随身镜。"
        } else if camera.isError {
            return camera.errorMessage ?? "未找到可用摄像头，或摄像头正被其他应用占用。"
        } else if camera.status == .requestingPermission {
            return "正在等待摄像头授权，请在系统弹窗中允许 Sapphire 访问。"
        } else if camera.isPending {
            return "正在打开摄像头…"
        } else {
            return "摄像头已关闭，点击开启即可使用实时随身镜。"
        }
    }
}

struct MirrorFullscreenView: View {
    @ObservedSettings var settings: SettingsObserver
    @ObservedObject private var camera = MirrorCameraManager.shared

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if camera.isLive {
                MirrorCameraPreviewView(
                    session: camera.session,
                    flipHorizontally: settings.settings.mirrorFlipHorizontally,
                    rotationAngle: camera.effectivePreviewRotationAngle,
                    sessionEpoch: camera.sessionEpoch
                )
                .ignoresSafeArea()
            }

            VStack {
                HStack(spacing: 10) {
                    if camera.isLive {
                        HStack(spacing: 5) {
                            Circle().fill(Color.red).frame(width: 7, height: 7)
                            Text("实时预览")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.5), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 0.5))
                    }

                    Spacer()

                    if camera.isLive {
                        Button {
                            settings.settings.mirrorFlipHorizontally.toggle()
                            camera.updateMirroring(flipHorizontally: settings.settings.mirrorFlipHorizontally)
                        } label: {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(.black.opacity(0.5), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .help("水平镜像翻转")

                        Button {
                            settings.settings.mirrorRotationMode = settings.settings.mirrorRotationMode.next
                        } label: {
                            Image(systemName: "rotate.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(.black.opacity(0.5), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .help("旋转画面")

                        Button {
                            camera.stop()
                        } label: {
                            Label("停止", systemImage: "stop.fill")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.red.opacity(0.85), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .help("关闭摄像头")
                    }

                    Button {
                        MirrorFullscreenWindowController.shared.dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(.black.opacity(0.5), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("退出全屏")
                }
                .padding(16)

                Spacer()

                if !camera.isLive {
                    Text(camera.isDenied ? "摄像头访问被拒绝" : "摄像头已关闭")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.bottom, 40)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MirrorCameraMenuItems: View {
    @ObservedObject var camera: MirrorCameraManager

    var body: some View {
        ForEach(camera.cameras) { option in
            Button {
                camera.selectCamera(id: option.id)
            } label: {
                if option.id == (camera.activeCameraID ?? camera.preferredCameraID) {
                    Label(option.name, systemImage: "checkmark")
                } else {
                    Text(option.name)
                }
            }
        }
    }
}

@MainActor
final class MirrorFullscreenWindowController {
    static let shared = MirrorFullscreenWindowController()
    private var window: NSWindow?
    private var escapeMonitor: Any?

    private init() {}

    func present() {
        let screens = NSScreen.screens
        guard let index = OCRScreenTextSupport.indexOfScreen(containing: NSEvent.mouseLocation, in: screens.map(\.frame)) else { return }
        let screen = screens[index]

        let window: NSWindow
        if let existing = self.window {
            window = existing
        } else {
            window = KeyableWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.backgroundColor = .black
            window.isOpaque = true
            window.hasShadow = false
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: MirrorFullscreenView())
            self.window = window
        }

        if window.frame != screen.frame {
            window.setFrame(screen.frame, display: true)
        }

        if escapeMonitor == nil {
            escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard event.keyCode == 53 else { return event }
                self?.dismiss()
                return nil
            }
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func dismiss(destroy: Bool = false) {
        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
            self.escapeMonitor = nil
        }
        window?.orderOut(nil)
        if destroy {
            window?.contentView = nil
            window = nil
        }
    }
}