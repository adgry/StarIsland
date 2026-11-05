#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "App/AppIcon.icns"

let outputURL = URL(fileURLWithPath: outputPath)
let tempIconsetURL = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("StarIsland-\(UUID().uuidString).iconset", isDirectory: true)

try FileManager.default.createDirectory(at: tempIconsetURL, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

func drawIcon(pixelSize: Int) -> Data? {
    let s = CGFloat(pixelSize)
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
          let ctx = CGContext(
              data: nil,
              width: pixelSize,
              height: pixelSize,
              bitsPerComponent: 8,
              bytesPerRow: 0,
              space: space,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          ) else {
        return nil
    }

    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)

    // macOS squircle inset
    let pad = s * 0.085
    let rect = CGRect(x: pad, y: pad, width: s - pad * 2, height: s - pad * 2)
    let corner = rect.width * 0.225
    let squircle = CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil)

    // Background deep cosmic gradient
    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()

    let bgColors = [
        CGColor(srgbRed: 0.09, green: 0.13, blue: 0.30, alpha: 1.0),
        CGColor(srgbRed: 0.04, green: 0.06, blue: 0.15, alpha: 1.0),
        CGColor(srgbRed: 0.02, green: 0.03, blue: 0.08, alpha: 1.0)
    ] as CFArray
    if let bgGrad = CGGradient(colorsSpace: space, colors: bgColors, locations: [0.0, 0.55, 1.0]) {
        ctx.drawLinearGradient(
            bgGrad,
            start: CGPoint(x: s * 0.5, y: s * 0.92),
            end: CGPoint(x: s * 0.5, y: s * 0.08),
            options: []
        )
    }

    // Subtle aurora nebula glow behind island
    let glowColors = [
        CGColor(srgbRed: 0.24, green: 0.78, blue: 1.0, alpha: 0.42),
        CGColor(srgbRed: 0.46, green: 0.34, blue: 0.98, alpha: 0.20),
        CGColor(srgbRed: 0.05, green: 0.07, blue: 0.18, alpha: 0.0)
    ] as CFArray
    if let glow = CGGradient(colorsSpace: space, colors: glowColors, locations: [0.0, 0.5, 1.0]) {
        ctx.drawRadialGradient(
            glow,
            startCenter: CGPoint(x: s * 0.5, y: s * 0.56),
            startRadius: s * 0.02,
            endCenter: CGPoint(x: s * 0.5, y: s * 0.56),
            endRadius: s * 0.38,
            options: []
        )
    }

    // Dynamic Island black capsule in center-top
    let pillW = rect.width * 0.72
    let pillH = rect.height * 0.25
    let pillRect = CGRect(
        x: (s - pillW) / 2.0,
        y: s * 0.56 - pillH / 2.0,
        width: pillW,
        height: pillH
    )
    let pillPath = CGPath(roundedRect: pillRect, cornerWidth: pillH / 2.0, cornerHeight: pillH / 2.0, transform: nil)
    ctx.setFillColor(CGColor(srgbRed: 0.02, green: 0.02, blue: 0.04, alpha: 0.96))
    ctx.addPath(pillPath)
    ctx.fillPath()

    // Glowing border around Dynamic Island
    ctx.setStrokeColor(CGColor(srgbRed: 0.38, green: 0.86, blue: 1.0, alpha: 0.65))
    ctx.setLineWidth(max(1.0, s * 0.011))
    ctx.addPath(pillPath)
    ctx.strokePath()

    // Four-point radiant star inside left side of island
    let starCenter = CGPoint(x: pillRect.minX + pillH * 0.62, y: pillRect.midY)
    let outerR = pillH * 0.30
    let innerR = outerR * 0.32
    let starPath = CGMutablePath()
    for i in 0..<8 {
        let angle = CGFloat(i) * (.pi / 4.0)
        let r = (i % 2 == 0) ? outerR : innerR
        let pt = CGPoint(x: starCenter.x + cos(angle) * r, y: starCenter.y + sin(angle) * r)
        if i == 0 {
            starPath.move(to: pt)
        } else {
            starPath.addLine(to: pt)
        }
    }
    starPath.closeSubpath()
    ctx.setFillColor(CGColor(srgbRed: 0.38, green: 0.92, blue: 1.0, alpha: 1.0))
    ctx.addPath(starPath)
    ctx.fillPath()

    // Equalizer / live activity bars inside right side of island
    let barHeights: [CGFloat] = [0.28, 0.54, 0.38, 0.62, 0.32]
    let barW = max(1.5, pillH * 0.095)
    let barGap = pillH * 0.085
    let totalBarsW = CGFloat(barHeights.count) * barW + CGFloat(barHeights.count - 1) * barGap
    let startX = pillRect.maxX - pillH * 0.45 - totalBarsW
    for (idx, ratio) in barHeights.enumerated() {
        let bh = pillH * ratio
        let bx = startX + CGFloat(idx) * (barW + barGap)
        let by = pillRect.midY - bh / 2.0
        let barRect = CGRect(x: bx, y: by, width: barW, height: bh)
        let barPath = CGPath(roundedRect: barRect, cornerWidth: barW / 2, cornerHeight: barW / 2, transform: nil)
        let t = CGFloat(idx) / CGFloat(max(1, barHeights.count - 1))
        ctx.setFillColor(CGColor(
            srgbRed: 0.35 + 0.35 * t,
            green: 0.88 - 0.25 * t,
            blue: 1.0,
            alpha: 0.95
        ))
        ctx.addPath(barPath)
        ctx.fillPath()
    }

    // Orbiting starlight arc below island
    let arcPath = CGMutablePath()
    arcPath.move(to: CGPoint(x: s * 0.26, y: s * 0.33))
    arcPath.addQuadCurve(
        to: CGPoint(x: s * 0.74, y: s * 0.33),
        control: CGPoint(x: s * 0.50, y: s * 0.23)
    )
    ctx.setStrokeColor(CGColor(srgbRed: 0.48, green: 0.78, blue: 1.0, alpha: 0.45))
    ctx.setLineCap(.round)
    ctx.setLineWidth(max(1.0, s * 0.016))
    ctx.addPath(arcPath)
    ctx.strokePath()

    // Outer squircle glass highlight border
    ctx.setStrokeColor(CGColor(srgbRed: 0.65, green: 0.82, blue: 1.0, alpha: 0.24))
    ctx.setLineWidth(max(1.0, s * 0.012))
    ctx.addPath(squircle)
    ctx.strokePath()
    ctx.restoreGState()

    guard let cgImage = ctx.makeImage() else { return nil }
    let rep = NSBitmapImageRep(cgImage: cgImage)
    return rep.representation(using: .png, properties: [:])
}

let specs: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (filename, size) in specs {
    guard let png = drawIcon(pixelSize: size) else {
        fputs("Failed to render \(filename)\n", stderr)
        exit(1)
    }
    try png.write(to: tempIconsetURL.appendingPathComponent(filename))
}

let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", tempIconsetURL.path, "-o", outputURL.path]
try proc.run()
proc.waitUntilExit()
try? FileManager.default.removeItem(at: tempIconsetURL)

guard proc.terminationStatus == 0 else {
    fputs("iconutil failed with status \(proc.terminationStatus)\n", stderr)
    exit(proc.terminationStatus)
}
print("Generated \(outputURL.path)")
