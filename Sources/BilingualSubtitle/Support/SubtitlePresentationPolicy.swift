import Foundation

enum SubtitlePresentationPolicy {
    /// Only cues arriving inside this window are treated as rapid dialogue and
    /// shown as a rolling two-row pair.
    static let rapidCueWindow: TimeInterval = 1.0

    /// Vision can miss one or more frames between Apple TV caption cues.
    static let blankGraceDuration: TimeInterval = 1.0

    static let maximumVisibleCueCount = 2

    static func shouldStack(previousCueAt: Date, currentCueAt: Date) -> Bool {
        let interval = currentCueAt.timeIntervalSince(previousCueAt)
        return interval >= 0 && interval < rapidCueWindow
    }

    static func shouldAcceptLatePreviousCue(newestPresentedAt: Date, now: Date) -> Bool {
        let interval = now.timeIntervalSince(newestPresentedAt)
        return interval >= 0 && interval < rapidCueWindow
    }

    static func shouldClear(
        lastObservationAt: Date?,
        newestPresentedAt: Date?,
        now: Date
    ) -> Bool {
        guard let latestActivity = [lastObservationAt, newestPresentedAt]
            .compactMap({ $0 })
            .max() else {
            return true
        }
        return now.timeIntervalSince(latestActivity) >= blankGraceDuration
    }

}
