//
//  AppLockOverlayView.swift
//  Sapphire
//

#if !SAPPHIRE_FULL_BUILD
import SwiftUI

struct AppLockOverlayView: View {
    let appName: String
    @ObservedObject var lockManager: AppLockManager
    let hasFaceID: Bool
    let hasTouchID: Bool
    let hasPassword: Bool
    let onFaceID: () -> Void
    let onTouchID: () -> Void
    let onSubmitPassword: (String) -> Bool
    let onQuit: (() -> Void)?
    var quitButtonTitle: String = "退出应用"

    @State private var passwordInput: String = ""
    @State private var showError = false

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 46))
                .foregroundStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))

            VStack(spacing: 5) {
                Text("「\(appName)」已受星岛隐私锁保护")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                Text("请验证身份以解锁并继续使用")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            if hasTouchID {
                Button(action: onTouchID) {
                    Label(lockManager.isAuthenticating ? "正在验证…" : "使用 Touch ID 解锁", systemImage: "touchid")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .disabled(lockManager.isAuthenticating)
            }

            if hasPassword {
                HStack(spacing: 8) {
                    SecureField("输入备用解锁密码", text: $passwordInput)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                        .onSubmit { submitPassword() }
                    Button("解锁") { submitPassword() }
                        .buttonStyle(.bordered)
                }
            }

            if showError {
                Text("密码不正确，请重试")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.red)
            }

            if let onQuit {
                Button(quitButtonTitle, action: onQuit)
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(32)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 24, y: 10)
    }

    private func submitPassword() {
        guard !passwordInput.isEmpty else { return }
        if onSubmitPassword(passwordInput) {
            showError = false
            passwordInput = ""
        } else {
            showError = true
            passwordInput = ""
        }
    }
}
#endif
