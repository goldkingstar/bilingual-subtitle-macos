import AppKit
import CoreGraphics

@MainActor
final class RegionSelectionController {
    private var panel: RegionSelectionPanel?

    func beginSelection(completion: @escaping (CaptureRegion?) -> Void) {
        cancelSelection()

        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen,
              let displayNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            completion(nil)
            return
        }

        let selectionPanel = RegionSelectionPanel(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        selectionPanel.level = .screenSaver
        selectionPanel.backgroundColor = .clear
        selectionPanel.isOpaque = false
        selectionPanel.hasShadow = false
        selectionPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        selectionPanel.isReleasedWhenClosed = false

        let selectionView = RegionSelectionView(frame: CGRect(origin: .zero, size: screen.frame.size))
        selectionView.onCancel = { [weak self] in
            self?.cancelSelection()
            completion(nil)
        }
        selectionView.onSelection = { [weak self, weak selectionPanel] localRect in
            guard let panel = selectionPanel else {
                completion(nil)
                return
            }
            let globalRect = panel.convertToScreen(localRect).integral
            self?.cancelSelection()
            completion(CaptureRegion(
                displayID: CGDirectDisplayID(displayNumber.uint32Value),
                displayName: screen.localizedName,
                globalRect: globalRect,
                screenFrame: screen.frame,
                backingScaleFactor: screen.backingScaleFactor
            ))
        }

        selectionPanel.contentView = selectionView
        panel = selectionPanel
        NSCursor.crosshair.push()
        selectionPanel.makeKeyAndOrderFront(nil)
        selectionPanel.makeFirstResponder(selectionView)
    }

    func cancelSelection() {
        if panel != nil { NSCursor.pop() }
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
    }
}

private final class RegionSelectionPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private final class RegionSelectionView: NSView {
    var onSelection: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    private var startPoint: CGPoint?
    private var selectionRect: CGRect = .zero

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        selectionRect = .zero
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let startPoint else { return }
        let current = convert(event.locationInWindow, from: nil)
        selectionRect = CGRect(
            x: min(startPoint.x, current.x),
            y: min(startPoint.y, current.y),
            width: abs(current.x - startPoint.x),
            height: abs(current.y - startPoint.y)
        ).intersection(bounds)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard selectionRect.width >= 80, selectionRect.height >= 24 else {
            NSSound.beep()
            startPoint = nil
            selectionRect = .zero
            needsDisplay = true
            return
        }
        onSelection?(selectionRect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
        } else {
            super.keyDown(with: event)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        // Keep the movie and its captions readable while the user chooses a
        // region. A heavy dimming layer makes the very text being selected
        // unnecessarily difficult to see.
        NSColor.black.withAlphaComponent(0.14).setFill()
        bounds.fill()

        if !selectionRect.isEmpty {
            NSColor.clear.setFill()
            selectionRect.fill(using: .copy)

            let border = NSBezierPath(roundedRect: selectionRect, xRadius: 5, yRadius: 5)
            border.lineWidth = 3
            NSColor.systemCyan.setStroke()
            border.stroke()
        }

        drawInstruction()
    }

    private func drawInstruction() {
        let text = "拖动框选原语言字幕范围（建议先暂停画面） · 按 Esc 取消" as NSString
        let font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let textSize = text.size(withAttributes: attributes)
        let pillRect = CGRect(
            x: bounds.midX - textSize.width / 2 - 18,
            y: bounds.maxY - textSize.height - 50,
            width: textSize.width + 36,
            height: textSize.height + 18
        )
        NSColor.black.withAlphaComponent(0.78).setFill()
        NSBezierPath(roundedRect: pillRect, xRadius: 11, yRadius: 11).fill()
        text.draw(
            at: CGPoint(x: pillRect.minX + 18, y: pillRect.minY + 9),
            withAttributes: attributes
        )
    }
}
