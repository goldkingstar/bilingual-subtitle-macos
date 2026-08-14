import CoreGraphics
import Vision

enum OCRServiceError: LocalizedError {
    case recognitionFailed

    var errorDescription: String? {
        switch self {
        case .recognitionFailed: "Vision 无法完成这一帧的文字识别。"
        }
    }
}

actor OCRService {
    func recognize(
        _ image: CGImage,
        sourceLanguage: SubtitleSourceLanguage,
        sampleSourceColor: Bool = true
    ) throws -> OCRObservation? {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = sourceLanguage.visionRecognitionLanguages
        request.minimumTextHeight = 0.012

        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        try handler.perform([request])

        guard let results = request.results else {
            throw OCRServiceError.recognitionFailed
        }

        let candidates = results.compactMap { observation -> (String, CGRect, Float)? in
            guard let candidate = observation.topCandidates(1).first,
                  candidate.confidence >= 0.45 else {
                return nil
            }
            let text = SubtitleTextNormalizer.cleanLine(candidate.string)
            guard SubtitleTextNormalizer.containsReadableContent(text),
                  SubtitleTextNormalizer.containsSupportedText(
                    text,
                    language: sourceLanguage
                  ) else {
                return nil
            }
            return (text, observation.boundingBox, candidate.confidence)
        }
        .sorted {
            if abs($0.1.midY - $1.1.midY) > 0.025 {
                return $0.1.midY > $1.1.midY
            }
            return $0.1.minX < $1.1.minX
        }

        guard !candidates.isEmpty else { return nil }
        let text = SubtitleTextNormalizer.clean(lines: candidates.map(\.0))
        let key = SubtitleTextNormalizer.comparisonKey(text)
        guard !key.isEmpty else { return nil }

        let union = candidates.dropFirst().reduce(candidates[0].1) { $0.union($1.1) }
        let heights = candidates.map { $0.1.height }.sorted()
        let medianHeight = heights[heights.count / 2]
        let averageConfidence = candidates.map(\.2).reduce(0, +) / Float(candidates.count)
        let color = sampleSourceColor
            ? SubtitleStyleEstimator.estimateColor(in: image, normalizedBounds: union)
            : .white

        return OCRObservation(
            sourceText: text,
            comparisonKey: key,
            normalizedBounds: union,
            lineHeightFraction: medianHeight,
            sourceLineCount: candidates.count,
            confidence: averageConfidence,
            color: color
        )
    }
}
