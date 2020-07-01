import Foundation

public struct GeminiRequest {
    public let id = UUID()
    public private(set) var url: URL

    public init(url: URL) {
        self.url = url
    }

    func withURL(_ newURL: URL) -> GeminiRequest {
        var request = self
        var newURL = newURL

        // that should probably mean that url is relative
        if newURL.scheme == nil {
            newURL = URL(string: newURL.relativeString, relativeTo: request.url) ?? url
        }

        request.url = newURL
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
