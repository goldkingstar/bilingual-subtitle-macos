import CoreGraphics

enum SubtitleStyleEstimator {
    static func estimateColor(in image: CGImage, normalizedBounds: CGRect) -> SubtitleColor {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return .white }

        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return .white
        }

        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        let padded = normalizedBounds.insetBy(dx: -0.012, dy: -0.012).intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        let minX = max(1, Int(padded.minX * CGFloat(width)))
        let maxX = min(width - 2, Int(ceil(padded.maxX * CGFloat(width))))
        let minY = max(1, Int((1 - padded.maxY) * CGFloat(height)))
        let maxY = min(height - 2, Int(ceil((1 - padded.minY) * CGFloat(height))))
        guard minX < maxX, minY < maxY else { return .white }

        var histogram: [Int: Int] = [:]
        var accepted = 0

        func components(atX x: Int, y: Int) -> (CGFloat, CGFloat, CGFloat) {
            let index = (y * width + x) * 4
            return (
                CGFloat(pixels[index]) / 255,
                CGFloat(pixels[index + 1]) / 255,
                CGFloat(pixels[index + 2]) / 255
            )
        }

        func luminance(_ value: (CGFloat, CGFloat, CGFloat)) -> CGFloat {
            value.0 * 0.2126 + value.1 * 0.7152 + value.2 * 0.0722
        }

        for y in stride(from: minY, through: maxY, by: 2) {
            for x in stride(from: minX, through: maxX, by: 2) {
                let rgb = components(atX: x, y: y)
                guard luminance(rgb) > 0.58 else { continue }

                let neighborIsDark = [
                    components(atX: x - 1, y: y),
                    components(atX: x + 1, y: y),
                    components(atX: x, y: y - 1),
                    components(atX: x, y: y + 1)
                ].contains { luminance($0) < 0.28 }
                guard neighborIsDark else { continue }

                let r = min(15, Int(rgb.0 * 15))
                let g = min(15, Int(rgb.1 * 15))
                let b = min(15, Int(rgb.2 * 15))
                histogram[(r << 8) | (g << 4) | b, default: 0] += 1
                accepted += 1
            }
        }

        guard accepted >= 8, let best = histogram.max(by: { $0.value < $1.value })?.key else {
            return .white
        }

        let red = CGFloat((best >> 8) & 0xF) / 15
        let green = CGFloat((best >> 4) & 0xF) / 15
        let blue = CGFloat(best & 0xF) / 15
        let maximum = max(red, green, blue)
        let minimum = min(red, green, blue)

        // Neutral subtitle glyphs are intentionally normalized to clean white;
        // saturated subtitle colors retain the sampled hue.
        if maximum - minimum < 0.16 {
            return .white
        }
        return SubtitleColor(red: red, green: green, blue: blue, alpha: 1)
    }
}
