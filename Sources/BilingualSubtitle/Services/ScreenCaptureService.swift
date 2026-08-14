import CoreGraphics
import Foundation
import ScreenCaptureKit

enum ScreenCaptureServiceError: LocalizedError {
    case permissionDenied
    case displayUnavailable
    case invalidRegion

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "请在系统设置的“隐私与安全性 → 屏幕与系统音频录制”中允许双语字幕镜，然后重新开始。"
        case .displayUnavailable:
            "找不到刚才框选字幕的显示器，请重新框选。"
        case .invalidRegion:
            "字幕区域无效，请重新框选一个更大的范围。"
        }
    }
}

actor ScreenCaptureService {
    private var preparedDisplayID: CGDirectDisplayID?
    private var preparedRect: CGRect = .zero
    private var filter: SCContentFilter?
    private var configuration: SCStreamConfiguration?

    func requestPermissionIfNeeded() -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }
        return CGRequestScreenCaptureAccess()
    }

    func invalidate() {
        preparedDisplayID = nil
        preparedRect = .zero
        filter = nil
        configuration = nil
    }

    func capture(region: CaptureRegion) async throws -> CGImage {
        guard region.globalRect.width >= 40, region.globalRect.height >= 20 else {
            throw ScreenCaptureServiceError.invalidRegion
        }

        if preparedDisplayID != region.displayID || preparedRect != region.globalRect {
            try await prepare(region: region)
        }
        guard let filter, let configuration else {
            throw ScreenCaptureServiceError.displayUnavailable
        }
        return try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )
    }

    private func prepare(region: CaptureRegion) async throws {
        guard CGPreflightScreenCaptureAccess() else {
            throw ScreenCaptureServiceError.permissionDenied
        }

        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )
        guard let display = content.displays.first(where: { $0.displayID == region.displayID }) else {
            throw ScreenCaptureServiceError.displayUnavailable
        }

        let ownApplications = content.applications.filter {
            $0.processID == ProcessInfo.processInfo.processIdentifier
        }
        let nextFilter = SCContentFilter(
            display: display,
            excludingApplications: ownApplications,
            exceptingWindows: []
        )

        let localX = region.globalRect.minX - region.screenFrame.minX
        let localYFromTop = region.screenFrame.maxY - region.globalRect.maxY
        let sourceRect = CGRect(
            x: localX,
            y: localYFromTop,
            width: region.globalRect.width,
            height: region.globalRect.height
        )

        let nextConfiguration = SCStreamConfiguration()
        nextConfiguration.sourceRect = sourceRect
        nextConfiguration.width = max(2, region.pixelWidth)
        nextConfiguration.height = max(2, region.pixelHeight)
        nextConfiguration.showsCursor = false
        nextConfiguration.capturesAudio = false

        preparedDisplayID = region.displayID
        preparedRect = region.globalRect
        filter = nextFilter
        configuration = nextConfiguration
    }
}
