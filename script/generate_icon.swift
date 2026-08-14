import AppKit
import Foundation

guard CommandLine.arguments.count == 3 else {
    fatalError("usage: generate_icon <iconset-directory> <icns-file>")
}

let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let icnsDestination = URL(fileURLWithPath: CommandLine.arguments[2])
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

let variants: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

func speechBubble(in rect: CGRect, tailOnRight: Bool) -> NSBezierPath {
    let body = rect.insetBy(dx: 0, dy: rect.height * 0.10)
    let path = NSBezierPath(roundedRect: body, xRadius: rect.height * 0.23, yRadius: rect.height * 0.23)
    let tail = NSBezierPath()
    if tailOnRight {
        tail.move(to: CGPoint(x: body.maxX - body.width * 0.16, y: body.minY + 1))
        tail.line(to: CGPoint(x: body.maxX - body.width * 0.03, y: rect.minY))
        tail.line(to: CGPoint(x: body.maxX - body.width * 0.05, y: body.minY + body.height * 0.30))
    } else {
        tail.move(to: CGPoint(x: body.minX + body.width * 0.16, y: body.minY + 1))
        tail.line(to: CGPoint(x: body.minX + body.width * 0.03, y: rect.minY))
        tail.line(to: CGPoint(x: body.minX + body.width * 0.05, y: body.minY + body.height * 0.30))
    }
    tail.close()
    path.append(tail)
    return path
}

func makeIcon(pixelSize: Int) -> Data {
    let size = CGFloat(pixelSize)
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: [],
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        fatalError("Unable to create icon bitmap")
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high

    let canvas = CGRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    canvas.fill()

    let tile = canvas.insetBy(dx: size * 0.055, dy: size * 0.055)
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: size * 0.215, yRadius: size * 0.215)
    NSGraphicsContext.current?.saveGraphicsState()
    let tileShadow = NSShadow()
    tileShadow.shadowColor = NSColor.black.withAlphaComponent(0.30)
    tileShadow.shadowBlurRadius = size * 0.055
    tileShadow.shadowOffset = CGSize(width: 0, height: -size * 0.026)
    tileShadow.set()
    NSColor(calibratedRed: 0.08, green: 0.26, blue: 0.78, alpha: 1).setFill()
    tilePath.fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.16, green: 0.62, blue: 1.00, alpha: 1),
        NSColor(calibratedRed: 0.22, green: 0.16, blue: 0.68, alpha: 1)
    ])!
    gradient.draw(in: tilePath, angle: -55)

    let highlight = NSBezierPath(ovalIn: CGRect(
        x: size * 0.02,
        y: size * 0.52,
        width: size * 0.78,
        height: size * 0.62
    ))
    NSGraphicsContext.current?.saveGraphicsState()
    tilePath.addClip()
    NSColor.white.withAlphaComponent(0.11).setFill()
    highlight.fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    let englishRect = CGRect(x: size * 0.17, y: size * 0.48, width: size * 0.66, height: size * 0.28)
    let chineseRect = CGRect(x: size * 0.23, y: size * 0.20, width: size * 0.60, height: size * 0.27)
    let englishBubble = speechBubble(in: englishRect, tailOnRight: true)
    let chineseBubble = speechBubble(in: chineseRect, tailOnRight: false)

    NSColor.white.withAlphaComponent(0.97).setFill()
    englishBubble.fill()
    NSColor(calibratedRed: 0.64, green: 0.96, blue: 1.00, alpha: 1).setFill()
    chineseBubble.fill()

    func drawCentered(_ string: String, in rect: CGRect, color: NSColor, scale: CGFloat) {
        let font = NSFont.systemFont(ofSize: size * scale, weight: .heavy)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        let text = string as NSString
        let measured = text.size(withAttributes: attributes)
        text.draw(
            in: CGRect(
                x: rect.minX,
                y: rect.midY - measured.height / 2 + size * 0.012,
                width: rect.width,
                height: measured.height
            ),
            withAttributes: attributes
        )
    }

    drawCentered("EN", in: englishRect.insetBy(dx: size * 0.04, dy: size * 0.03), color: NSColor(calibratedRed: 0.08, green: 0.24, blue: 0.66, alpha: 1), scale: 0.115)
    drawCentered("中", in: chineseRect.insetBy(dx: size * 0.04, dy: size * 0.03), color: NSColor(calibratedRed: 0.08, green: 0.28, blue: 0.50, alpha: 1), scale: 0.13)

    NSGraphicsContext.restoreGraphicsState()
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Unable to encode icon PNG")
    }
    return data
}

for (name, size) in variants {
    try makeIcon(pixelSize: size).write(to: destination.appendingPathComponent(name))
}

let icnsRepresentations: [(String, String)] = [
    ("icp4", "icon_16x16.png"),
    ("icp5", "icon_32x32.png"),
    ("icp6", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic08", "icon_256x256.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png")
]

func bigEndianData(_ value: UInt32) -> Data {
    var bigEndian = value.bigEndian
    return withUnsafeBytes(of: &bigEndian) { Data($0) }
}

let chunks: [(String, Data)] = try icnsRepresentations.map { type, filename in
    (type, try Data(contentsOf: destination.appendingPathComponent(filename)))
}
let totalSize = 8 + chunks.reduce(0) { $0 + 8 + $1.1.count }
var icns = Data("icns".utf8)
icns.append(bigEndianData(UInt32(totalSize)))
for (type, png) in chunks {
    icns.append(Data(type.utf8))
    icns.append(bigEndianData(UInt32(png.count + 8)))
    icns.append(png)
}
try icns.write(to: icnsDestination)
