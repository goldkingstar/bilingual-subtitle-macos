import Foundation

@main
enum MultilingualTranslationSmokeTests {
    static func main() async throws {
        let service = GoogleTranslateService()
        let samples: [(SubtitleSourceLanguage, String)] = [
            (.english, "How are you?"),
            (.japanese, "こんにちは"),
            (.traditionalChinese, "繁體字幕測試"),
            (.french, "Comment allez-vous ?"),
            (.german, "Wie geht es Ihnen?"),
            (.spanish, "¿Cómo estás?")
        ]

        for (language, text) in samples {
            let translation = try await service.translate(
                text,
                source: language,
                target: .simplifiedChinese
            )
            precondition(!translation.isEmpty, "Empty translation for \(language.title)")
            print("\(language.title): \(text) -> \(translation)")
        }
    }
}
