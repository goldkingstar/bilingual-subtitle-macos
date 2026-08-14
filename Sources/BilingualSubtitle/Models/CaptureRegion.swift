import AppKit
import CoreGraphics

struct CaptureRegion: Equatable {
    let displayID: CGDirectDisplayID
    let displayName: String
    let globalRect: CGRect
    let screenFrame: CGRect
    let backingScaleFactor: CGFloat

    var pixelWidth: Int {
        Int((globalRect.width * backingScaleFactor).rounded())
    }

    var pixelHeight: Int {
        Int((globalRect.height * backingScaleFactor).rounded())
    }

    var description: String {
        "\(displayName) · \(Int(globalRect.width)) × \(Int(globalRect.height)) pt"
    }

    static func appleTVFullScreenPreset(for screen: NSScreen) -> CaptureRegion? {
        guard let displayNumber = screen.deviceDescription[
            NSDeviceDescriptionKey("NSScreenNumber")
        ] as? NSNumber else {
            return nil
        }

        // Measured from ten live Apple TV full-screen captures: non-empty
        // captions occupied 3...22.8% of the screen width, including two-line
        // cues. A centered 50% lane leaves more than 2x tolerance for unusually
        // long cues without making the guide look like a near-full-width box.
        // The lower 22% band covers both observed caption baselines while
        // excluding substantially more player UI from OCR.
        let frame = screen.frame
        let globalRect = CGRect(
            x: frame.minX + frame.width * 0.25,
            y: frame.minY + frame.height * 0.13,
            width: frame.width * 0.50,
            height: frame.height * 0.22
        ).integral

        return CaptureRegion(
            displayID: CGDirectDisplayID(displayNumber.uint32Value),
            displayName: "\(screen.localizedName) · Apple TV 全屏预设",
            globalRect: globalRect,
            screenFrame: frame,
            backingScaleFactor: screen.backingScaleFactor
        )
    }
}
