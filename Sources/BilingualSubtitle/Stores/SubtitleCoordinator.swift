import AppKit
import Foundation

@MainActor
final class SubtitleCoordinator: ObservableObject {
    @Published private(set) var region: CaptureRegion?
    @Published private(set) var status: CoordinatorStatus = .idle
    @Published private(set) var isRunning = false
    @Published private(set) var sourceText = ""
    @Published private(set) var translatedText = ""
    @Published private(set) var confidence: Float?
    @Published private(set) var processedFrameCount = 0
    @Published private(set) var isShowingStylePreview = false

    @Published var sourceLanguage: SubtitleSourceLanguage {
        didSet {
            UserDefaults.standard.set(sourceLanguage.rawValue, forKey: Keys.sourceLanguage)
            guard oldValue != sourceLanguage else { return }
            cancelTranslationTasks()
            currentSourceKey = ""
            currentObservation = nil
            currentCueDetectedAt = nil
            lastObservationAt = nil
            presentedCues = []
            sourceText = ""
            translatedText = ""
            confidence = nil
            refreshOverlay()
            warmUpTranslationConnection()
        }
    }

    @Published var targetLanguage: TranslationTarget {
        didSet {
            UserDefaults.standard.set(targetLanguage.rawValue, forKey: Keys.targetLanguage)
            guard oldValue != targetLanguage else { return }
            cancelTranslationTasks()
            warmUpTranslationConnection()
            guard let observation = currentObservation else { return }
            requestTranslation(for: observation, force: true)
        }
    }

    @Published var scanSpeed: ScanSpeed {
        didSet {
            UserDefaults.standard.set(scanSpeed.rawValue, forKey: Keys.scanSpeed)
        }
    }

    @Published var showGuide: Bool {
        didSet {
            UserDefaults.standard.set(showGuide, forKey: Keys.showGuide)
            refreshOverlay()
        }
    }

    @Published var stylePreset: SubtitleStylePreset {
        didSet {
            UserDefaults.standard.set(stylePreset.rawValue, forKey: Keys.stylePreset)
            refreshOverlay()
        }
    }

    @Published var subtitleScale: Double {
        didSet {
            UserDefaults.standard.set(subtitleScale, forKey: Keys.subtitleScale)
            refreshOverlay()
        }
    }

    @Published var subtitleBackgroundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(subtitleBackgroundEnabled, forKey: Keys.subtitleBackgroundEnabled)
            refreshOverlay()
        }
    }

    private enum Keys {
        static let sourceLanguage = "sourceLanguage"
        static let targetLanguage = "targetLanguage"
        static let scanSpeed = "scanSpeed.v2"
        static let showGuide = "showGuide"
        static let stylePreset = "stylePreset"
        static let subtitleScale = "subtitleScale"
        static let subtitleBackgroundEnabled = "subtitleBackgroundEnabled"
    }

    private let captureService = ScreenCaptureService()
    private let ocrService = OCRService()
    private let translateService = GoogleTranslateService()
    private let selectionController = RegionSelectionController()
    private let overlayController = SubtitleOverlayController()

    private var captureTask: Task<Void, Never>?
    private var translationTasks: [Int: Task<Void, Never>] = [:]
    private var translationRequestOrder: [Int] = []
    private var translationRequestBySource: [String: Int] = [:]
    private var nextTranslationRequestID = 0
    private var currentObservation: OCRObservation?
    private var currentSourceKey = ""
    private var currentCueDetectedAt: Date?
    private var lastObservationAt: Date?
    private var presentedCues: [PresentedCue] = []
    private var translationEpoch = 0
    private var translationRetryAfter = Date.distantPast

    private struct PresentedCue {
        let sourceKey: String
        let observation: OCRObservation
        let translation: String
        let detectedAt: Date
        let presentedAt: Date
    }

    init() {
        sourceLanguage = SubtitleSourceLanguage(
            rawValue: UserDefaults.standard.string(forKey: Keys.sourceLanguage) ?? ""
        ) ?? .english
        targetLanguage = TranslationTarget(
            rawValue: UserDefaults.standard.string(forKey: Keys.targetLanguage) ?? ""
        ) ?? .simplifiedChinese

        let storedSpeed = UserDefaults.standard.double(forKey: Keys.scanSpeed)
        scanSpeed = ScanSpeed(rawValue: storedSpeed) ?? .responsive
        showGuide = UserDefaults.standard.bool(forKey: Keys.showGuide)
        stylePreset = SubtitleStylePreset(
            rawValue: UserDefaults.standard.string(forKey: Keys.stylePreset) ?? ""
        ) ?? .appleTV
        let storedScale = UserDefaults.standard.double(forKey: Keys.subtitleScale)
        subtitleScale = storedScale > 0 ? storedScale : 1.0
        subtitleBackgroundEnabled = (
            UserDefaults.standard.object(forKey: Keys.subtitleBackgroundEnabled) as? Bool
        ) ?? true
        warmUpTranslationConnection()
    }

    func selectRegion(startWhenFinished: Bool = false) {
        let shouldRestart = startWhenFinished || isRunning
        stop(clearStatus: false)
        status = .selecting

        selectionController.beginSelection { [weak self] selectedRegion in
            guard let self else { return }
            guard let selectedRegion else {
                self.status = .idle
                return
            }

            self.apply(region: selectedRegion)

            if shouldRestart { self.start() }
        }
    }

    func useAppleTVFullScreenPreset(startWhenFinished: Bool = false) {
        let shouldRestart = startWhenFinished || isRunning
        stop(clearStatus: false)

        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen,
              let presetRegion = CaptureRegion.appleTVFullScreenPreset(for: screen) else {
            status = .failed("找不到 Apple TV 所在的显示器，请改用手动框选。")
            return
        }

        apply(region: presetRegion)
        if shouldRestart { start() }
    }

    func start() {
        guard !isRunning else { return }
        guard let region else {
            useAppleTVFullScreenPreset(startWhenFinished: true)
            return
        }

        status = .preparing
        isShowingStylePreview = false
        captureTask = Task { [weak self] in
            guard let self else { return }
            let permissionGranted = await self.captureService.requestPermissionIfNeeded()
            guard !Task.isCancelled else { return }
            guard permissionGranted else {
                self.status = .permissionRequired
                self.isRunning = false
                return
            }

            self.isRunning = true
            self.status = .scanning
            self.refreshOverlay()
            await self.runCaptureLoop(region: region)
        }
    }

    func stop() {
        stop(clearStatus: true)
    }

    func openScreenRecordingSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func toggleStylePreview() {
        guard region != nil else {
            selectRegion()
            return
        }
        guard !isRunning else { return }
        isShowingStylePreview.toggle()
        refreshOverlay()
    }

    private func stop(clearStatus: Bool) {
        captureTask?.cancel()
        captureTask = nil
        cancelTranslationTasks()
        currentObservation = nil
        currentSourceKey = ""
        currentCueDetectedAt = nil
        lastObservationAt = nil
        presentedCues = []
        isRunning = false
        if clearStatus { status = .idle }

        if let region {
            overlayController.update(
                subtitle: nil,
                region: region,
                showGuide: showGuide,
                appearance: appearance
            )
        } else {
            overlayController.hide()
        }
    }

    private func apply(region: CaptureRegion) {
        self.region = region
        currentObservation = nil
        currentSourceKey = ""
        currentCueDetectedAt = nil
        lastObservationAt = nil
        presentedCues = []
        sourceText = ""
        translatedText = ""
        confidence = nil
        processedFrameCount = 0
        isShowingStylePreview = false
        status = .idle
        refreshOverlay()
        Task { await captureService.invalidate() }
    }

    private func runCaptureLoop(region: CaptureRegion) async {
        while !Task.isCancelled {
            guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.TV" else {
                status = .waitingForAppleTV
                do {
                    try await Task.sleep(
                        nanoseconds: UInt64(scanSpeed.rawValue * 1_000_000_000)
                    )
                } catch {
                    break
                }
                continue
            }

            if status == .waitingForAppleTV {
                status = .scanning
            }

            do {
                let image = try await captureService.capture(region: region)
                guard !Task.isCancelled else { break }
                let observation = try await ocrService.recognize(
                    image,
                    sourceLanguage: sourceLanguage,
                    sampleSourceColor: stylePreset == .matchSource
                )
                guard !Task.isCancelled else { break }
                processedFrameCount += 1
                consume(observation)
            } catch is CancellationError {
                break
            } catch ScreenCaptureServiceError.permissionDenied {
                status = .permissionRequired
                break
            } catch {
                status = .failed(error.localizedDescription)
            }

            do {
                try await Task.sleep(nanoseconds: UInt64(scanSpeed.rawValue * 1_000_000_000))
            } catch {
                break
            }
        }
        isRunning = false
        captureTask = nil
    }

    private func consume(_ observation: OCRObservation?) {
        let now = Date()

        guard let observation else {
            if let lastObservationAt,
               now.timeIntervalSince(lastObservationAt) >= SubtitlePresentationPolicy.blankGraceDuration {
                currentObservation = nil
            }

            if SubtitlePresentationPolicy.shouldClear(
                lastObservationAt: lastObservationAt,
                newestPresentedAt: presentedCues.last?.presentedAt,
                now: now
            ) {
                clearCurrentSubtitle()
                status = .noText
            } else {
                refreshOverlay()
            }
            return
        }

        lastObservationAt = now
        confidence = observation.confidence

        if observation.comparisonKey != currentSourceKey {
            currentSourceKey = observation.comparisonKey
            currentObservation = observation
            currentCueDetectedAt = now
            sourceText = observation.sourceText
            translationRetryAfter = .distantPast
            // Do not blank the old translation while the next network request
            // is in flight. The new translated cue is handed off atomically.
            refreshOverlay()
            requestTranslation(for: observation, force: true)
            return
        }

        // Freeze the geometry for a cue. OCR bounds naturally jitter between
        // frames; updating them continuously makes the overlay drift even when
        // the recognized text has not changed.
        if currentObservation == nil {
            currentObservation = observation
        }
        refreshOverlay()
        let hasTranslationForCurrentCue = presentedCues.contains {
            $0.sourceKey == currentSourceKey
        }
        if !hasTranslationForCurrentCue,
           translationRequestBySource[currentSourceKey] == nil,
           Date() >= translationRetryAfter {
            requestTranslation(for: observation, force: false)
        } else if translationRequestBySource[currentSourceKey] == nil {
            status = .scanning
        }
    }

    private func requestTranslation(for observation: OCRObservation, force: Bool) {
        let sourceKey = observation.comparisonKey
        if let existingID = translationRequestBySource[sourceKey] {
            guard force else { return }
            cancelTranslationRequest(existingID)
        } else if !force && Date() < translationRetryAfter {
            return
        }

        while translationRequestOrder.count >= 2,
              let oldestID = translationRequestOrder.first {
            cancelTranslationRequest(oldestID)
        }

        nextTranslationRequestID += 1
        let requestID = nextTranslationRequestID
        let epoch = translationEpoch
        let detectedAt = currentCueDetectedAt ?? Date()
        let source = sourceLanguage
        let target = targetLanguage
        status = .translating

        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let translation = try await self.translateService.translate(
                    observation.sourceText,
                    source: source,
                    target: target
                )
                try Task.checkCancellation()
                guard epoch == self.translationEpoch else {
                    return
                }
                self.finishTranslationRequest(requestID, sourceKey: sourceKey)

                let isCurrentCue = sourceKey == self.currentSourceKey
                let currentPresentedCue = self.presentedCues.last(where: {
                    $0.sourceKey == self.currentSourceKey
                })
                let isRapidPreviousCue: Bool
                if let currentDetectedAt = self.currentCueDetectedAt {
                    let currentCueCanStillPair = currentPresentedCue.map {
                        SubtitlePresentationPolicy.shouldAcceptLatePreviousCue(
                            newestPresentedAt: $0.presentedAt,
                            now: Date()
                        )
                    } ?? true
                    isRapidPreviousCue = currentCueCanStillPair
                        && SubtitlePresentationPolicy.shouldStack(
                            previousCueAt: detectedAt,
                            currentCueAt: currentDetectedAt
                        )
                } else {
                    isRapidPreviousCue = false
                }
                guard isCurrentCue || isRapidPreviousCue else { return }

                self.present(
                    translation: translation,
                    for: observation,
                    sourceKey: sourceKey,
                    detectedAt: detectedAt
                )
                self.status = self.translationRequestBySource[self.currentSourceKey] == nil
                    ? .scanning
                    : .translating
                self.refreshOverlay()
            } catch is CancellationError {
                if epoch == self.translationEpoch {
                    self.finishTranslationRequest(requestID, sourceKey: sourceKey)
                }
            } catch {
                guard epoch == self.translationEpoch else { return }
                self.finishTranslationRequest(requestID, sourceKey: sourceKey)
                guard sourceKey == self.currentSourceKey else { return }
                self.translationRetryAfter = Date().addingTimeInterval(4)
                self.status = .failed(error.localizedDescription)
            }
        }
        translationTasks[requestID] = task
        translationRequestOrder.append(requestID)
        translationRequestBySource[sourceKey] = requestID
    }

    private func cancelTranslationRequest(_ requestID: Int) {
        translationTasks.removeValue(forKey: requestID)?.cancel()
        translationRequestOrder.removeAll { $0 == requestID }
        if let sourceKey = translationRequestBySource.first(where: { $0.value == requestID })?.key {
            translationRequestBySource.removeValue(forKey: sourceKey)
        }
    }

    private func finishTranslationRequest(_ requestID: Int, sourceKey: String) {
        translationTasks.removeValue(forKey: requestID)
        translationRequestOrder.removeAll { $0 == requestID }
        if translationRequestBySource[sourceKey] == requestID {
            translationRequestBySource.removeValue(forKey: sourceKey)
        }
    }

    private func cancelTranslationTasks() {
        translationEpoch += 1
        for task in translationTasks.values {
            task.cancel()
        }
        translationTasks.removeAll()
        translationRequestOrder.removeAll()
        translationRequestBySource.removeAll()
    }

    private func warmUpTranslationConnection() {
        let service = translateService
        let source = sourceLanguage
        let target = targetLanguage
        Task {
            await service.warmUp(source: source, target: target)
        }
    }

    private func clearCurrentSubtitle() {
        cancelTranslationTasks()
        currentSourceKey = ""
        currentObservation = nil
        currentCueDetectedAt = nil
        lastObservationAt = nil
        presentedCues = []
        confidence = nil
        refreshOverlay()
    }

    private func present(
        translation: String,
        for observation: OCRObservation,
        sourceKey: String,
        detectedAt: Date
    ) {
        let now = Date()

        let cue = PresentedCue(
            sourceKey: sourceKey,
            observation: observation,
            translation: translation,
            detectedAt: detectedAt,
            presentedAt: now
        )

        let translationKey = SubtitleTextNormalizer.comparisonKey(translation)
        var candidates = presentedCues.filter {
            $0.sourceKey != sourceKey
                && SubtitleTextNormalizer.comparisonKey($0.translation) != translationKey
        }
        candidates.append(cue)
        candidates.sort {
            if $0.detectedAt == $1.detectedAt {
                return $0.presentedAt < $1.presentedAt
            }
            return $0.detectedAt < $1.detectedAt
        }
        let visibleCandidates = Array(
            candidates.suffix(SubtitlePresentationPolicy.maximumVisibleCueCount)
        )

        if visibleCandidates.count > 1,
           let newest = visibleCandidates.last {
            let previous = visibleCandidates[visibleCandidates.count - 2]
            if SubtitlePresentationPolicy.shouldStack(
                previousCueAt: previous.detectedAt,
                currentCueAt: newest.detectedAt
            ) {
                // Translation requests can finish out of order. Sort by the
                // OCR detection time, then retain the newest rolling pair.
                presentedCues = [previous, newest]
            } else {
                presentedCues = [newest]
            }
        } else {
            presentedCues = visibleCandidates
        }

        translatedText = presentedCues.map(\.translation).joined(separator: "\n")
    }

    private func refreshOverlay() {
        guard let region else {
            overlayController.hide()
            return
        }

        let subtitle: OverlaySubtitle?
        if isShowingStylePreview {
            subtitle = OverlaySubtitle(
                translatedText: "这是一条清晰度测试字幕",
                normalizedSourceBounds: CGRect(x: 0.12, y: 0.58, width: 0.76, height: 0.20),
                sourceLineHeightFraction: 0.18,
                sourceLineCount: 1,
                color: .white
            )
        } else if let newestCue = presentedCues.last {
            subtitle = OverlaySubtitle(
                translatedText: presentedCues.map(\.translation).joined(separator: "\n"),
                normalizedSourceBounds: newestCue.observation.normalizedBounds,
                sourceLineHeightFraction: newestCue.observation.lineHeightFraction,
                sourceLineCount: newestCue.observation.sourceLineCount,
                color: newestCue.observation.color
            )
        } else {
            subtitle = nil
        }
        overlayController.update(
            subtitle: subtitle,
            region: region,
            showGuide: showGuide && !isRunning,
            appearance: appearance
        )
    }

    private var appearance: SubtitleAppearance {
        SubtitleAppearance(
            preset: stylePreset,
            fontScale: CGFloat(subtitleScale),
            backgroundEnabled: subtitleBackgroundEnabled
        )
    }
}
