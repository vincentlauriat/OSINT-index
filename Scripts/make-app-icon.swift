#!/usr/bin/env swift
// Generates the OSINT-index app icon set into the AppIcon.appiconset: a dark
// navy-to-blue gradient square with a white magnifying glass (SF Symbol),
// evoking investigation/search. Usage: ./Scripts/make-app-icon.swift
import AppKit

// Resolve the appiconset next to this script (…/Scripts/../OSINTIndex/Assets…).
let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let root = scriptDir.deletingLastPathComponent()
let fm = FileManager.default
guard let assets = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        .first(where: { $0.pathExtension == "" && fm.fileExists(atPath: $0.appendingPathComponent("Assets.xcassets").path) })
        .map({ $0.appendingPathComponent("Assets.xcassets/AppIcon.appiconset") }) else {
    FileHandle.standardError.write(Data("could not locate AppIcon.appiconset\n".utf8))
    exit(1)
}

func render(_ size: Int) -> Data {
    let s = CGFloat(size)
    // Draw into a bitmap of EXACTLY `size`×`size` pixels. NSImage.lockFocus()
    // would render at the screen's backing scale (2× on Retina) and double every
    // icon, which iOS rejects ("did not have any applicable content").
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: s, height: s)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let rect = NSRect(x: 0, y: 0, width: s, height: s)
    let radius = s * 0.22
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.11, green: 0.19, blue: 0.35, alpha: 1),
        NSColor(calibratedRed: 0.05, green: 0.09, blue: 0.19, alpha: 1),
    ])!
    gradient.draw(in: path, angle: -90)

    let symbolConfig = NSImage.SymbolConfiguration(pointSize: s * 0.52, weight: .semibold)
    guard let symbol = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)?
        .withSymbolConfiguration(symbolConfig) else {
        FileHandle.standardError.write(Data("could not load SF Symbol\n".utf8))
        exit(1)
    }
    let tinted = NSImage(size: symbol.size, flipped: false) { rect in
        NSColor.white.set()
        symbol.draw(in: rect)
        rect.fill(using: .sourceAtop)
        return true
    }
    let symbolRect = NSRect(
        x: (s - tinted.size.width) / 2,
        y: (s - tinted.size.height) / 2,
        width: tinted.size.width, height: tinted.size.height)
    tinted.draw(in: symbolRect)

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for size in [16, 32, 64, 128, 256, 512, 1024] {
    let url = assets.appendingPathComponent("icon_\(size).png")
    try! render(size).write(to: url)
    print("wrote \(url.lastPathComponent)")
}
print("✅ app icon set generated (magnifying glass on navy gradient)")
