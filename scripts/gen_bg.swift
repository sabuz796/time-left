import Cocoa

let width: CGFloat = 660
let height: CGFloat = 400

let image = NSImage(size: NSSize(width: width, height: height))
image.lockFocus()

guard let context = NSGraphicsContext.current?.cgContext else {
    print("Failed to get graphics context")
    exit(1)
}

// Background color - dark gray
context.setFillColor(CGColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0))
context.fill(CGRect(x: 0, y: 0, width: width, height: height))

// Title
let titleFont = NSFont.boldSystemFont(ofSize: 24)
let titleAttributes: [NSAttributedString.Key: Any] = [
    .font: titleFont,
    .foregroundColor: NSColor.white
]
let title = "Time Left"
let titleSize = title.size(withAttributes: titleAttributes)
let titleX = (width - titleSize.width) / 2
let titleY: CGFloat = height - 80
title.draw(at: NSPoint(x: titleX, y: titleY), withAttributes: titleAttributes)

// Slogan
let sloganFont = NSFont.systemFont(ofSize: 11)
let sloganAttributes: [NSAttributedString.Key: Any] = [
    .font: sloganFont,
    .foregroundColor: NSColor.gray
]
let slogan1 = "“Don’t waste your time in anger, regrets, worries, and grudges."
let slogan2 = "Life is too short to be unhappy.” — Roy T. Bennett"
let s1Size = slogan1.size(withAttributes: sloganAttributes)
slogan1.draw(at: NSPoint(x: (width - s1Size.width) / 2, y: height - 140), withAttributes: sloganAttributes)
let s2Size = slogan2.size(withAttributes: sloganAttributes)
slogan2.draw(at: NSPoint(x: (width - s2Size.width) / 2, y: height - 156), withAttributes: sloganAttributes)

// Subtitle - privacy message
let subtitleFont = NSFont.systemFont(ofSize: 14)
let subtitleAttributes: [NSAttributedString.Key: Any] = [
    .font: subtitleFont,
    .foregroundColor: NSColor.lightGray
]
let subtitle = "100% on-device • No network • Nothing leaves this Mac"
let subtitleSize = subtitle.size(withAttributes: subtitleAttributes)
let subtitleX = (width - subtitleSize.width) / 2
let subtitleY: CGFloat = height - 120
subtitle.draw(at: NSPoint(x: subtitleX, y: subtitleY), withAttributes: subtitleAttributes)

// Instructions
let instructionFont = NSFont.systemFont(ofSize: 12)
let instructionAttributes: [NSAttributedString.Key: Any] = [
    .font: instructionFont,
    .foregroundColor: NSColor.gray
]
let instruction = "Drag YearPassing.app to Applications to install"
let instructionSize = instruction.size(withAttributes: instructionAttributes)
let instructionX = (width - instructionSize.width) / 2
let instructionY: CGFloat = 60
instruction.draw(at: NSPoint(x: instructionX, y: instructionY), withAttributes: instructionAttributes)

// Arrow pointing to Applications folder
let arrowFont = NSFont.systemFont(ofSize: 32)
let arrowAttributes: [NSAttributedString.Key: Any] = [
    .font: arrowFont,
    .foregroundColor: NSColor.white
]
let arrow = "→"
let arrowSize = arrow.size(withAttributes: arrowAttributes)
let arrowX = width / 2 - arrowSize.width / 2
let arrowY: CGFloat = 100
arrow.draw(at: NSPoint(x: arrowX, y: arrowY), withAttributes: arrowAttributes)

image.unlockFocus()

// Save to build directory
let buildDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("build/.dmg-src")
try? FileManager.default.createDirectory(at: buildDir, withIntermediateDirectories: true)

let outputPath = buildDir.appendingPathComponent("background.png")
if let tiffData = image.tiffRepresentation,
   let bitmapImage = NSBitmapImageRep(data: tiffData),
   let pngData = bitmapImage.representation(using: .png, properties: [:]) {
    try! pngData.write(to: outputPath)
    print("Generated: \(outputPath.path)")
} else {
    print("Failed to generate image")
    exit(1)
}
