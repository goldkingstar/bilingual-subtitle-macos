import Foundation

@main
enum DirectTests {
    static func main() throws {
        let data = #"[[["你好，","Hello,",null,null,10],["世界！","world!",null,null,10]],null,"en"]"#.data(using: .utf8)!
        let translation = try GoogleTranslationParser.parse(data)
        precondition(translation == "你好，世界！", "Google response parsing failed")

        let left = SubtitleTextNormalizer.comparisonKey(" Hello,  WORLD! ")
        let right = SubtitleTextNormalizer.comparisonKey("hello world")
        precondition(left == right, "Subtitle comparison normalization failed")

        let cleaned = SubtitleTextNormalizer.clean(lines: ["  One   line ", "One line", "Second"])
        precondition(cleaned == "One line\nSecond", "Subtitle line cleaning failed")
        precondition(SubtitleTextNormalizer.containsEnglishLetter("[MUSIC]"))
        precondition(!SubtitleTextNormalizer.containsEnglishLetter("10)"))
        precondition(SubtitleTextNormalizer.containsSupportedText("こんにちは", language: .japanese))
        precondition(SubtitleTextNormalizer.containsSupportedText("繁體字幕", language: .traditionalChinese))
        precondition(SubtitleTextNormalizer.containsSupportedText("Ça va ?", language: .french))
        precondition(SubtitleTextNormalizer.containsSupportedText("Grüße", language: .german))
        precondition(SubtitleTextNormalizer.containsSupportedText("¿Qué tal?", language: .spanish))
        precondition(!SubtitleTextNormalizer.containsSupportedText("Hello", language: .japanese))
        precondition(ScanSpeed.responsive.rawValue == 0.12)
        precondition(ScanSpeed.responsive.rawValue < ScanSpeed.balanced.rawValue)

        let start = Date(timeIntervalSince1970: 1_000)
        precondition(SubtitlePresentationPolicy.shouldStack(
            previousCueAt: start,
            currentCueAt: start.addingTimeInterval(0.99)
        ))
        precondition(!SubtitlePresentationPolicy.shouldStack(
            previousCueAt: start,
            currentCueAt: start.addingTimeInterval(1.0)
        ))
        precondition(!SubtitlePresentationPolicy.shouldStack(
            previousCueAt: start,
            currentCueAt: start.addingTimeInterval(-0.1)
        ))
        precondition(SubtitlePresentationPolicy.shouldAcceptLatePreviousCue(
            newestPresentedAt: start,
            now: start.addingTimeInterval(0.99)
        ))
        precondition(!SubtitlePresentationPolicy.shouldAcceptLatePreviousCue(
            newestPresentedAt: start,
            now: start.addingTimeInterval(1.0)
        ))
        precondition(!SubtitlePresentationPolicy.shouldClear(
            lastObservationAt: start,
            newestPresentedAt: start.addingTimeInterval(0.4),
            now: start.addingTimeInterval(1.39)
        ))
        precondition(SubtitlePresentationPolicy.shouldClear(
            lastObservationAt: start,
            newestPresentedAt: start.addingTimeInterval(0.4),
            now: start.addingTimeInterval(1.4)
        ))
        print("Direct tests passed")
    }
}
