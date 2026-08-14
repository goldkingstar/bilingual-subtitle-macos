import Foundation

enum SubtitleTextNormalizer {
    static func cleanLine(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func clean(lines: [String]) -> String {
        var seen = Set<String>()
        return lines
            .map(cleanLine)
            .filter { !$0.isEmpty }
            .filter { seen.insert($0).inserted }
            .joined(separator: "\n")
    }

    static func comparisonKey(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: "[\\s\\p{P}\\p{S}]+", with: "", options: .regularExpression)
            .lowercased()
    }

    static func containsReadableContent(_ text: String) -> Bool {
        text.unicodeScalars.contains { CharacterSet.alphanumerics.contains($0) }
    }

    static func containsEnglishLetter(_ text: String) -> Bool {
        containsLatinLetter(text)
    }

    static func containsSupportedText(_ text: String, language: SubtitleSourceLanguage) -> Bool {
        switch language {
        case .english, .french, .german, .spanish:
            containsLatinLetter(text)
        case .japanese:
            containsJapaneseCharacter(text)
        case .traditionalChinese:
            containsCJKCharacter(text)
        }
    }

    private static func containsLatinLetter(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x0041...0x005A, 0x0061...0x007A, 0x00C0...0x024F:
                true
            default:
                false
            }
        }
    }

    private static func containsJapaneseCharacter(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3040...0x30FF, 0x31F0...0x31FF, 0x3400...0x9FFF, 0xFF66...0xFF9D:
                true
            default:
                false
            }
        }
    }

    private static func containsCJKCharacter(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3400...0x9FFF, 0xF900...0xFAFF:
                true
            default:
                false
            }
        }
    }
}
