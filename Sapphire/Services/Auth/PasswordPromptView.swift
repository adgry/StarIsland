//
//  PasswordPromptView.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2025-09-13.
//

import SwiftUI

struct PasswordPromptView: View {
    @Binding var isPresented: Bool
    var validate: ((String) -> Bool)?
    var title: String = "需要身份验证"
    var message: String = "要启用蓝牙靠近解锁，Sapphire 需要你的 Mac 登录密码。密码将安全保存在系统钥匙串中，仅用于解锁设备。"
    var onSubmit: (String) -> Void

    @State private var password = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            SecureField("密码", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .multilineTextAlignment(.center)

            if let message = errorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            HStack(spacing: 12) {
                Button("取消") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button("好") {
                    if password.isEmpty {
                        errorMessage = "密码不能为空。"
                    } else if let validate = validate, !validate(password) {
                        errorMessage = "密码不正确，请重试。"
                        password = ""
                    } else {
                        onSubmit(password)
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(25)
        .frame(width: 350)
    }
}