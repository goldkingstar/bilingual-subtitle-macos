import AppKit
import Foundation

@main
enum OCRSmokeTests {
    static func main() async {
        do {
            try await run()
        } catch {
            let nsError = error as NSError
            fatalError("OCR error domain=\(nsError.domain) code=\(nsError.code) info=\(nsError.userInfo)")
        }
    }

    private static func run() async throws {
        let samples: [(SubtitleSourceLanguage, String)] = [
            (.english, "The story begins here."),
            (.japanese, "これは日本語の字幕です"),
            (.traditionalChinese, "繁體字幕測試"),
            (.french, "Comment allez-vous ?"),
            (.german, "Wie geht es Ihnen?"),
            (.spanish, "¿Cómo estás?")
        ]

        for (language, text) in samples {
            let image = makeSubtitleImage(text)
            guard let observation = try await OCRService().recognize(
                image,
                sourceLanguage: language
            ) else {
                fatalError("Vision did not find the generated \(language.title) subtitle")
            }
            precondition(
                SubtitleTextNormalizer.comparisonKey(observation.sourceText)
                    == SubtitleTextNormalizer.comparisonKey(text),
                "Unexpected \(language.title) OCR result: \(observation.sourceText)"
            )
            precondition(observation.normalizedBounds.width > 0.05)
            precondition(observation.confidence >= 0.45)
            print("\(language.title) OCR: \(text) -> \(observation.sourceText)")
        }
    }

    private static func makeSubtitleImage(_ text: String) -> CGImage {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 1200,
            pixelsHigh: 240,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bitmapFormat: [],
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
            fatalError("Unable to create test bitmap")
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext
        NSColor.black.setFill()
        NSRect(x: 0, y: 0, width: 1200, height: 240).fill()
        let string = text as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 54, weight: .semibold),
            .foregroundColor: NSColor.white,
            .strokeColor: NSColor.black,
            .strokeWidth: -3
        ]
        let textWidth = string.size(withAttributes: attributes).width
        string.draw(at: CGPoint(x: (1200 - textWidth) / 2, y: 82), withAttributes: attributes)
        NSGraphicsContext.restoreGraphicsState()

        guard let image = bitmap.cgImage else {
            fatalError("Unable to produce test CGImage")
        }
        return image
    }
}
