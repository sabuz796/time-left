import Foundation
import Cocoa

func renderIcon(pixels: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: pixels, height: pixels)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    defer { NSGraphicsContext.restoreGraphicsState() }
    let ctx = NSGraphicsContext.current!.cgContext

    let s = CGFloat(pixels) / 1024.0

    // Small sizes: detailed SVG strokes blur into noise, so draw a simplified
    // mark (orange disc + dark ring) that stays readable at 16–64px.
    if pixels < 128 {
        let c = CGPoint(x: CGFloat(pixels) / 2, y: CGFloat(pixels) / 2)
        let diameter = CGFloat(pixels) * 0.82
        let radius = diameter / 2

        // outer dark ring
        ctx.setFillColor(CGColor(red: 0.06, green: 0.06, blue: 0.07, alpha: 1))
        ctx.fillEllipse(in: CGRect(x: c.x - radius, y: c.y - radius, width: diameter, height: diameter))
        // light gray ring
        ctx.setFillColor(CGColor(red: 0.93, green: 0.93, blue: 0.93, alpha: 1))
        ctx.fillEllipse(in: CGRect(x: c.x - radius * 0.80, y: c.y - radius * 0.80, width: diameter * 0.80, height: diameter * 0.80))
        // orange disc
        let orangeRadius = radius * 0.62
        ctx.setFillColor(CGColor(red: 1.0, green: 0.74, blue: 0.32, alpha: 1))
        ctx.fillEllipse(in: CGRect(x: c.x - orangeRadius, y: c.y - orangeRadius, width: orangeRadius * 2, height: orangeRadius * 2))

        return rep
    }

    // Larger sizes: render the project SVG icon (images/time-left-icon.svg) with ~8% margin.
    let svgURL = URL(fileURLWithPath: (#filePath as NSString).deletingLastPathComponent)
        .deletingLastPathComponent()
        .appendingPathComponent("images/time-left-icon.svg")
    guard let svg = NSImage(contentsOf: svgURL) else {
        fatalError("Could not load \(svgURL.path)")
    }

    let iconSize = 820 * s // full canvas 1024 → ~90% coverage
    let origin = (CGFloat(pixels) - iconSize) / 2
    svg.draw(in: NSRect(x: origin, y: origin, width: iconSize, height: iconSize))

    return rep
}

func writePNG(_ rep: NSBitmapImageRep, to url: URL) {
    guard let png = rep.representation(using: .png, properties: [:]) else {
        fatalError("PNG encode failed")
    }
    try! png.write(to: url)
}

@main
struct IconGen {
    static func main() {
        let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
        try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        for f in (try? FileManager.default.contentsOfDirectory(atPath: outDir)) ?? [] {
            try? FileManager.default.removeItem(atPath: "\(outDir)/\(f)")
        }

        let specs: [(Int, String)] = [
            (16, "icon_16x16.png"),
            (32, "icon_16x16@2x.png"),
            (32, "icon_32x32.png"),
            (64, "icon_32x32@2x.png"),
            (128, "icon_128x128.png"),
            (256, "icon_128x128@2x.png"),
            (256, "icon_256x256.png"),
            (512, "icon_256x256@2x.png"),
            (512, "icon_512x512.png"),
            (1024, "icon_512x512@2x.png"),
        ]
        for (pixels, name) in specs {
            writePNG(renderIcon(pixels: pixels), to: URL(fileURLWithPath: "\(outDir)/\(name)"))
        }
        print("Icon set generated at \(outDir)")
    }
}