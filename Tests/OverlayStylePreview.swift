import AppKit
import Foundation
import ImageIO

@main
enum OverlayStylePreview {
    static func main() throws {
        guard CommandLine.arguments.count == 3 else {
            fatalError("usage: OverlayStylePreview <input-image> <output-image>")
        }
        let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
        guard let imageSource = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
              let sourceImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            fatalError("Unable to load reference image")
        }

        let width = 1342
        let height = 1800
        guard let cgContext = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            fatalError("Unable to create preview bitmap")
        }

        let frame = CGRect(x: 0, y: 0, width: width, height: height)
        cgContext.interpolationQuality = .high
        cgContext.draw(sourceImage, in: frame)

        let context = NSGraphicsContext(cgContext: cgContext, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context

        let overlay = SubtitleOverlayView(frame: frame)
        overlay.screenFrame = frame
        overlay.captureRegion = CGRect(x: 180, y: 420, width: 1100, height: 240)
        overlay.subtitle = OverlaySubtitle(
            translatedText: "你是说我们现在就要走吗？\n对，马上，不然就来不及了。",
            normalizedSourceBounds: CGRect(x: 0.041, y: 0.554, width: 0.918, height: 0.192),
            sourceLineHeightFraction: 0.192,
            sourceLineCount: 1,
            color: .white
        )
        overlay.subtitleAppearance = .readableDefault
        overlay.draw(frame)
        NSGraphicsContext.restoreGraphicsState()

        guard let outputImage = cgContext.makeImage(),
              let png = NSBitmapImageRep(cgImage: outputImage).representation(using: .png, properties: [:]) else {
            fatalError("Unable to encode preview")
        }
        try png.write(to: outputURL)
        print("Overlay preview written to \(outputURL.path)")
    }
}
