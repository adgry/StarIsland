import AppKit
import Foundation

public struct IslandMetrics: Equatable, Sendable {
    public let screenFrame: CGRect
    public let hasPhysicalNotch: Bool
    public let compactSize: CGSize
    public let pillSize: CGSize
    public let peekSize: CGSize
    public let expandedSize: CGSize
    public let alertHUDSize: CGSize
    public let cornerRadiusCompact: CGFloat
    public let cornerRadiusExpanded: CGFloat

    public func size(for state: IslandDisplayState) -> CGSize {
        switch state {
        case .compact:
            return compactSize
        case .pill:
            return pillSize
        case .peek:
            return peekSize
        case .expanded:
            return expandedSize
        case .alertHUD:
            return alertHUDSize
        }
    }

    public func panelFrame(for state: IslandDisplayState) -> CGRect {
        let target = size(for: state)
        let topOffset: CGFloat = hasPhysicalNotch ? 0 : 6
        let originX = screenFrame.midX - target.width / 2.0
        let originY = screenFrame.maxY - target.height - topOffset
        return CGRect(
            x: originX.rounded(),
            y: originY.rounded(),
            width: target.width.rounded(),
            height: target.height.rounded()
        )
    }
}

public enum IslandGeometry {
    public static func resolve(
        screenFrame: CGRect,
        safeTopInset: CGFloat,
        auxiliaryLeftWidth: CGFloat?,
        auxiliaryRightWidth: CGFloat?,
        scale: Double = 1.0
    ) -> IslandMetrics {
        let clampedScale = CGFloat(min(max(scale, 0.8), 1.35))
        let hasNotch = safeTopInset > 0 && auxiliaryLeftWidth != nil && auxiliaryRightWidth != nil

        let baseCompactWidth: CGFloat
        let baseCompactHeight: CGFloat
        if hasNotch, let left = auxiliaryLeftWidth, let right = auxiliaryRightWidth {
            baseCompactWidth = max(180, screenFrame.width - left - right)
            baseCompactHeight = max(32, safeTopInset)
        } else {
            baseCompactWidth = 184 * clampedScale
            baseCompactHeight = 32 * clampedScale
        }

        let compactSize = CGSize(width: baseCompactWidth, height: baseCompactHeight)
        let pillSize = CGSize(
            width: max(baseCompactWidth + 136 * clampedScale, 320 * clampedScale),
            height: max(baseCompactHeight, 36 * clampedScale)
        )
        let peekSize = CGSize(
            width: max(pillSize.width + 48 * clampedScale, 380 * clampedScale),
            height: 86 * clampedScale
        )
        let expandedWidth = min(screenFrame.width - 40, 620 * clampedScale)
        let expandedSize = CGSize(
            width: max(expandedWidth, 480),
            height: 310 * clampedScale
        )
        let alertHUDSize = CGSize(
            width: max(pillSize.width + 32 * clampedScale, 356 * clampedScale),
            height: 92 * clampedScale
        )

        return IslandMetrics(
            screenFrame: screenFrame,
            hasPhysicalNotch: hasNotch,
            compactSize: compactSize,
            pillSize: pillSize,
            peekSize: peekSize,
            expandedSize: expandedSize,
            alertHUDSize: alertHUDSize,
            cornerRadiusCompact: hasNotch ? 14 : baseCompactHeight / 2,
            cornerRadiusExpanded: 28
        )
    }

    @MainActor
    public static func resolve(for screen: NSScreen, scale: Double = 1.0) -> IslandMetrics {
        let safeTop = screen.safeAreaInsets.top
        let leftWidth = screen.auxiliaryTopLeftArea?.width
        let rightWidth = screen.auxiliaryTopRightArea?.width
        return resolve(
            screenFrame: screen.frame,
            safeTopInset: safeTop,
            auxiliaryLeftWidth: leftWidth,
            auxiliaryRightWidth: rightWidth,
            scale: scale
        )
    }
}
