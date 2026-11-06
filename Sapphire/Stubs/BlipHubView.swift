//
//  BlipHubView.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2026-08-30

#if !SAPPHIRE_FULL_BUILD
import SwiftUI

struct BlipHubView: View {
    @Binding var navigationStack: [NotchWidgetMode]

    init(navigationStack: Binding<[NotchWidgetMode]>) {
        _navigationStack = navigationStack
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles.rectangle.stack.fill").font(.system(size: 22))
            Text("当前构建版本未包含 Blip").font(.caption)
        }
        .frame(width: 320)
    }
}
#endif