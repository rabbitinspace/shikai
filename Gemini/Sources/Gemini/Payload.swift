import Foundation

public struct GeminiRequest {
    public let id = UUID()
    public private(set) var url: URL

    public init(url: URL) {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            preconditionFailure("not a url: \(url)")
        }

//        if components.scheme == nil {
//            components.scheme = "gemini"
//        }
//
//        if components.port == nil {
//            components.port = 1965
//        }
//
//        precondition(components.scheme == "gemini", "only gemini scheme is supported")
//        precondition(components.host?.isEmpty == false, "host is required")
        self.url = components.url!
    }

    func withURL(_ url: URL) -> GeminiRequest {
        var request = self
        request.url = url
        return request
    }

    func encoded() -> Data? {
        var url = self.url.absoluteString
        url.append("\r\n")
        return url.data(using: .utf8)
    }
}

public struct GeminiResponse {
    public struct Header {
        public let status: GeminiStatus
        public let meta: String
    }

    public let header: Header
    public let data: Data
}
