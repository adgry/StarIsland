//
//  BlipHubView.swift
//  Sapphire
//

#if !SAPPHIRE_FULL_BUILD
import SwiftUI

struct BlipHubView: View {
    @Binding var navigationStack: [NotchWidgetMode]

    init(navigationStack: Binding<[NotchWidgetMode]>) {
        _navigationStack = navigationStack
    }

    var body: some View {
        IntelligenceNotchView(navigationStack: $navigationStack)
    }
}
#endif
