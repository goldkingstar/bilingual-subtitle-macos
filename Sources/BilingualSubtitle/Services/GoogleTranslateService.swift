import Foundation

enum GoogleTranslateError: LocalizedError, Equatable {
    case invalidRequest
    case unexpectedResponse
    case http(Int)
    case emptyTranslation

    var errorDescription: String? {
        switch self {
        case .invalidRequest: "无法创建 Google 翻译请求。"
        case .unexpectedResponse: "Google 返回了无法识别的数据。"
        case let .http(code): "Google 翻译暂时不可用（HTTP \(code)）。"
        case .emptyTranslation: "Google 没有返回译文。"
        }
    }
}

enum GoogleTranslationParser {
    static func parse(_ data: Data) throws -> String {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let root = object as? [Any],
              let segments = root.first as? [Any] else {
            throw GoogleTranslateError.unexpectedResponse
        }

        let translation = segments.compactMap { segment -> String? in
            guard let values = segment as? [Any],
                  let text = values.first as? String else {
                return nil
            }
            return text
        }.joined()
        .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !translation.isEmpty else {
            throw GoogleTranslateError.emptyTranslation
        }
        return translation
    }
}

actor GoogleTranslateService {
    private let session: URLSession
    private var cache: [String: String] = [:]
    private var warmedPairs = Set<String>()

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 12
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpMaximumConnectionsPerHost = 4
        session = URLSession(configuration: configuration)
    }

    func warmUp(source: SubtitleSourceLanguage, target: TranslationTarget) async {
        let pair = "\(source.rawValue)|\(target.rawValue)"
        guard warmedPairs.insert(pair).inserted else { return }
        do {
            // A fixed punctuation-only request establishes DNS, TLS and the
            // reusable HTTP connection without sending any user subtitle.
            _ = try await translate(".", source: source, target: target)
        } catch {
            warmedPairs.remove(pair)
        }
    }

    func translate(
        _ text: String,
        source: SubtitleSourceLanguage,
        target: TranslationTarget
    ) async throws -> String {
        let key = "\(source.rawValue)|\(target.rawValue)|\(text)"
        if let cached = cache[key] { return cached }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "translate.googleapis.com"
        components.path = "/translate_a/single"
        components.queryItems = [
            URLQueryItem(name: "client", value: "gtx"),
            URLQueryItem(name: "sl", value: source.rawValue),
            URLQueryItem(name: "tl", value: target.rawValue),
            URLQueryItem(name: "dt", value: "t"),
            URLQueryItem(name: "q", value: text)
        ]
        guard let url = components.url else { throw GoogleTranslateError.invalidRequest }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json,text/plain,*/*", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GoogleTranslateError.unexpectedResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw GoogleTranslateError.http(http.statusCode)
        }

        let translation = try GoogleTranslationParser.parse(data)
        cache[key] = translation
        if cache.count > 500 {
            cache.removeAll(keepingCapacity: true)
            cache[key] = translation
        }
        return translation
    }
}
