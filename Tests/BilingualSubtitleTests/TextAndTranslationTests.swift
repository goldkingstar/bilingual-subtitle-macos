import XCTest
@testable import BilingualSubtitle

final class TextAndTranslationTests: XCTestCase {
    func testGoogleResponseParsingJoinsSegments() throws {
        let data = #"[[["你好，","Hello,",null,null,10],["世界！","world!",null,null,10]],null,"en"]"#.data(using: .utf8)!
        XCTAssertEqual(try GoogleTranslationParser.parse(data), "你好，世界！")
    }

    func testComparisonKeyIgnoresPunctuationWhitespaceAndCase() {
        XCTAssertEqual(
            SubtitleTextNormalizer.comparisonKey(" Hello,  WORLD! "),
            SubtitleTextNormalizer.comparisonKey("hello world")
        )
    }

    func testCleanLinesRemovesExactDuplicates() {
        XCTAssertEqual(
            SubtitleTextNormalizer.clean(lines: ["  One   line ", "One line", "Second"]),
            "One line\nSecond"
        )
    }

    func testSourceLanguageCharacterFilters() {
        XCTAssertTrue(SubtitleTextNormalizer.containsSupportedText("こんにちは", language: .japanese))
        XCTAssertTrue(SubtitleTextNormalizer.containsSupportedText("繁體字幕", language: .traditionalChinese))
        XCTAssertTrue(SubtitleTextNormalizer.containsSupportedText("Ça va ?", language: .french))
        XCTAssertTrue(SubtitleTextNormalizer.containsSupportedText("Grüße", language: .german))
        XCTAssertTrue(SubtitleTextNormalizer.containsSupportedText("¿Qué tal?", language: .spanish))
        XCTAssertFalse(SubtitleTextNormalizer.containsSupportedText("Hello", language: .japanese))
    }
}
