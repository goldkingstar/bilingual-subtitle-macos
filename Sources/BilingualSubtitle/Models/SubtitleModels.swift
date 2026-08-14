import AppKit
import CoreGraphics

struct SubtitleColor: Equatable {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    static let white = SubtitleColor(red: 1, green: 1, blue: 1, alpha: 1)

    var nsColor: NSColor {
        NSColor(deviceRed: red, green: green, blue: blue, alpha: alpha)
    }
}

struct OCRObservation: Equatable {
    let sourceText: String
    let comparisonKey: String
    let normalizedBounds: CGRect
    let lineHeightFraction: CGFloat
    let sourceLineCount: Int
    let confidence: Float
    let color: SubtitleColor
}

struct OverlaySubtitle: Equatable {
    let translatedText: String
    let normalizedSourceBounds: CGRect
    let sourceLineHeightFraction: CGFloat
    let sourceLineCount: Int
    let color: SubtitleColor
}

enum SubtitleStylePreset: String, CaseIterable, Identifiable {
    case highContrast
    case appleTV
    case matchSource

    var id: String { rawValue }

    var title: String {
        switch self {
        case .highContrast: "高对比（推荐）"
        case .appleTV: "Apple TV（默认）"
        case .matchSource: "跟随原字幕颜色"
        }
    }
}

struct SubtitleAppearance: Equatable {
    let preset: SubtitleStylePreset
    let fontScale: CGFloat
    let backgroundEnabled: Bool

    static let readableDefault = SubtitleAppearance(
        preset: .appleTV,
        fontScale: 1.0,
        backgroundEnabled: true
    )

    func foregroundColor(sampledColor: SubtitleColor) -> NSColor {
        switch preset {
        case .matchSource: sampledColor.nsColor
        case .highContrast, .appleTV: .white
        }
    }

    var fontWeight: NSFont.Weight {
        switch preset {
        case .highContrast: .bold
        case .appleTV, .matchSource: .semibold
        }
    }

    var outerStrokeWidth: CGFloat {
        switch preset {
        case .highContrast: -11
        case .appleTV: -1.8
        case .matchSource: -6.5
        }
    }

    var innerStrokeWidth: CGFloat {
        switch preset {
        case .highContrast: -4
        case .appleTV: 0
        case .matchSource: -2.5
        }
    }

    var backgroundOpacity: CGFloat {
        guard backgroundEnabled else { return 0 }
        return switch preset {
        case .highContrast: 0.80
        case .appleTV: 0.72
        case .matchSource: 0.72
        }
    }
}

enum SubtitleSourceLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case japanese = "ja"
    case traditionalChinese = "zh-TW"
    case french = "fr"
    case german = "de"
    case spanish = "es"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .english: "英语"
        case .japanese: "日语"
        case .traditionalChinese: "繁体中文"
        case .french: "法语"
        case .german: "德语"
        case .spanish: "西班牙语"
        }
    }

    var visionRecognitionLanguages: [String] {
        switch self {
        case .english: ["en-US"]
        case .japanese: ["ja-JP"]
        case .traditionalChinese: ["zh-Hant"]
        case .french: ["fr-FR"]
        case .german: ["de-DE"]
        case .spanish: ["es-ES"]
        }
    }

}

enum TranslationTarget: String, CaseIterable, Identifiable {
    case simplifiedChinese = "zh-CN"
    case traditionalChinese = "zh-TW"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        }
    }
}

enum ScanSpeed: Double, CaseIterable, Identifiable {
    case responsive = 0.12
    case balanced = 0.55
    case efficient = 0.90

    var id: Double { rawValue }

    var title: String {
        switch self {
        case .responsive: "响应优先"
        case .balanced: "均衡"
        case .efficient: "省电"
        }
    }
}

enum CoordinatorStatus: Equatable {
    case idle
    case selecting
    case preparing
    case waitingForAppleTV
    case scanning
    case translating
    case noText
    case permissionRequired
    case failed(String)

    var title: String {
        switch self {
        case .idle: "尚未开始"
        case .selecting: "请框选字幕区域"
        case .preparing: "正在准备屏幕读取"
        case .waitingForAppleTV: "请切回 Apple TV"
        case .scanning: "正在识别字幕"
        case .translating: "正在翻译"
        case .noText: "区域内暂未发现字幕"
        case .permissionRequired: "需要屏幕录制权限"
        case .failed: "出现问题"
        }
    }

    var detail: String? {
        if case let .failed(message) = self { return message }
        return nil
    }
}
