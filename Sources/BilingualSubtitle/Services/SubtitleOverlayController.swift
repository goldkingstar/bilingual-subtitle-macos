import AppKit

@MainActor
final class SubtitleOverlayController {
    private var panel: SubtitleOverlayPanel?
    private var overlayView: SubtitleOverlayView?

    func update(
        subtitle: OverlaySubtitle?,
        region: CaptureRegion,
        showGuide: Bool,
        appearance: SubtitleAppearance
    ) {
        guard let screen = NSScreen.screens.first(where: { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return false
            }
            return number.uint32Value == region.displayID
        }) else {
            hide()
            return
        }

        let view: SubtitleOverlayView
        if let existingPanel = panel, let existingView = overlayView {
            existingPanel.setFrame(screen.frame, display: true)
            view = existingView
        } else {
            let newPanel = SubtitleOverlayPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            newPanel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.overlayWindow)))
            newPanel.backgroundColor = .clear
            newPanel.isOpaque = false
            newPanel.hasShadow = false
            newPanel.ignoresMouseEvents = true
            newPanel.hidesOnDeactivate = false
            newPanel.isReleasedWhenClosed = false
            newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

            let newView = SubtitleOverlayView(frame: CGRect(origin: .zero, size: screen.frame.size))
            newPanel.contentView = newView
            panel = newPanel
            overlayView = newView
            view = newView
        }

        view.screenFrame = screen.frame
        view.captureRegion = region.globalRect
        view.subtitle = subtitle
        view.showGuide = showGuide
        view.subtitleAppearance = appearance
        view.needsDisplay = true

        if subtitle != nil || showGuide {
            panel?.orderFrontRegardless()
        } else {
            panel?.orderOut(nil)
        }
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func close() {
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
        overlayView = nil
    }
}

private final class SubtitleOverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class SubtitleOverlayView: NSView {
    var subtitle: OverlaySubtitle?
    var captureRegion: CGRect = .zero
    var screenFrame: CGRect = .zero
    var showGuide = false
    var subtitleAppearance: SubtitleAppearance = .readableDefault

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let localCaptureRect = captureRegion.offsetBy(dx: -screenFrame.minX, dy: -screenFrame.minY)
        if showGuide {
            let guide = NSBezierPath(roundedRect: localCaptureRect, xRadius: 4, yRadius: 4)
            guide.lineWidth = 1.5
            guide.setLineDash([6, 5], count: 2, phase: 0)
            NSColor.systemCyan.withAlphaComponent(0.72).setStroke()
            guide.stroke()
        }

        guard let subtitle, !subtitle.translatedText.isEmpty else { return }
        draw(subtitle: subtitle, in: localCaptureRect)
    }

    private func draw(subtitle: OverlaySubtitle, in captureRect: CGRect) {
        // Keep one stable size for the entire viewing session. Vision's glyph
        // bounds fluctuate from frame to frame (especially while a cue is
        // appearing), so deriving the font from each OCR observation made the
        // Chinese subtitle visibly pulse.
        let baseFontSize = min(30, max(20, captureRect.height * 0.055))
        let fontSize = min(42, max(16, baseFontSize * subtitleAppearance.fontScale))
        let font = NSFont.systemFont(ofSize: fontSize, weight: subtitleAppearance.fontWeight)
        let fontLineHeight = ceil(font.ascender - font.descender + font.leading)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byClipping
        paragraph.maximumLineHeight = fontLineHeight * 1.08
        paragraph.minimumLineHeight = fontLineHeight

        // The maximum wrap width is fixed for the selected lane. The actual
        // background is still measured from each visible line, so short Apple
        // TV captions retain a compact box without inheriting OCR width jitter.
        let maxLineWidth = captureRect.width * 0.62
        let lines = wrappedLines(
            subtitle.translatedText,
            font: font,
            maxWidth: maxLineWidth,
            maximumLineCount: 2
        )
        guard !lines.isEmpty else { return }

        let horizontalPadding = max(6, fontSize * 0.22)
        let verticalPadding = max(3, fontSize * 0.08)
        let lineDrawHeight = fontLineHeight + 4
        let lineBoxHeight = lineDrawHeight + verticalPadding * 2
        let lineBoxGap = max(2, fontSize * 0.06)
        let gap = max(10, fontSize * 0.36)

        // Use one fixed lane below the entire OCR capture region. Positioning
        // no longer follows Vision's per-frame glyph box, so it cannot jitter
        // or move upward over a newly arrived English caption.
        let safeTop = captureRect.minY - gap
        let totalBlockHeight = lineBoxHeight * CGFloat(lines.count)
            + lineBoxGap * CGFloat(max(0, lines.count - 1))
        let blockBottom = safeTop - totalBlockHeight
        guard blockBottom >= bounds.minY + 5 else { return }

        let centerX = captureRect.midX

        let outerShadow = NSShadow()
        outerShadow.shadowColor = NSColor.black.withAlphaComponent(0.98)
        outerShadow.shadowOffset = CGSize(width: 0, height: -max(1, fontSize * 0.025))
        outerShadow.shadowBlurRadius = max(2, fontSize * 0.08)

        let outerAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black,
            .strokeColor: NSColor.black,
            .strokeWidth: subtitleAppearance.outerStrokeWidth,
            .paragraphStyle: paragraph,
            .shadow: outerShadow
        ]
        let innerAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: subtitleAppearance.foregroundColor(sampledColor: subtitle.color),
            .strokeColor: NSColor.black,
            .strokeWidth: subtitleAppearance.innerStrokeWidth,
            .paragraphStyle: paragraph
        ]

        for (index, line) in lines.enumerated() {
            let string = line as NSString
            let glyphWidth = ceil(string.size(withAttributes: [.font: font]).width)
            let textWidth = min(maxLineWidth, max(fontSize * 1.2, glyphWidth + 2))
            let minCenterX = bounds.minX + 5 + horizontalPadding + textWidth / 2
            let maxCenterX = bounds.maxX - 5 - horizontalPadding - textWidth / 2
            let lineCenterX = min(max(centerX, minCenterX), maxCenterX)
            let verticalIndex = CGFloat(lines.count - 1 - index)
            let boxBottom = blockBottom + verticalIndex * (lineBoxHeight + lineBoxGap)
            let drawRect = CGRect(
                x: lineCenterX - textWidth / 2,
                y: boxBottom + verticalPadding,
                width: textWidth,
                height: lineDrawHeight
            )

            if subtitleAppearance.backgroundOpacity > 0 {
                let backgroundRect = drawRect.insetBy(
                    dx: -horizontalPadding,
                    dy: -verticalPadding
                )
                NSColor.black.withAlphaComponent(subtitleAppearance.backgroundOpacity).setFill()
                NSBezierPath(
                    roundedRect: backgroundRect,
                    xRadius: max(4, fontSize * 0.10),
                    yRadius: max(4, fontSize * 0.10)
                ).fill()
            }

            string.draw(
                with: drawRect,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: outerAttributes
            )
            string.draw(
                with: drawRect,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: innerAttributes
            )
        }
    }

    private func wrappedLines(
        _ text: String,
        font: NSFont,
        maxWidth: CGFloat,
        maximumLineCount: Int
    ) -> [String] {
        let explicitParagraphs = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Fast-dialogue cues are intentionally separated. Keep one visual row
        // per cue so wrapping the older sentence cannot consume the row meant
        // for the newest sentence. A single ordinary cue still wraps normally.
        if explicitParagraphs.count > 1 {
            return explicitParagraphs.suffix(maximumLineCount).map {
                clippedLine($0, font: font, maxWidth: maxWidth)
            }
        }

        let widthAttributes: [NSAttributedString.Key: Any] = [.font: font]
        var result: [String] = []

        for rawParagraph in explicitParagraphs {
            let paragraph = rawParagraph.trimmingCharacters(in: .whitespaces)
            guard !paragraph.isEmpty else { continue }

            var current = ""
            for character in paragraph {
                let candidate = current + String(character)
                let candidateWidth = ceil((candidate as NSString).size(
                    withAttributes: widthAttributes
                ).width)

                if candidateWidth <= maxWidth || current.isEmpty {
                    current = candidate
                } else {
                    result.append(current.trimmingCharacters(in: .whitespaces))
                    current = String(character).trimmingCharacters(in: .whitespaces)
                }
            }

            if !current.isEmpty {
                result.append(current.trimmingCharacters(in: .whitespaces))
            }
        }

        guard result.count > maximumLineCount else { return result }
        var visible = Array(result.prefix(maximumLineCount))
        var last = visible[maximumLineCount - 1]
        let ellipsis = "…"
        while !last.isEmpty {
            let candidateWidth = ceil(((last + ellipsis) as NSString).size(
                withAttributes: widthAttributes
            ).width)
            if candidateWidth <= maxWidth { break }
            last.removeLast()
        }
        visible[maximumLineCount - 1] = last + ellipsis
        return visible
    }

    private func clippedLine(_ text: String, font: NSFont, maxWidth: CGFloat) -> String {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        guard ceil((text as NSString).size(withAttributes: attributes).width) > maxWidth else {
            return text
        }

        var clipped = text
        let ellipsis = "…"
        while !clipped.isEmpty {
            let candidate = clipped + ellipsis
            if ceil((candidate as NSString).size(withAttributes: attributes).width) <= maxWidth {
                return candidate
            }
            clipped.removeLast()
        }
        return ellipsis
    }
}
