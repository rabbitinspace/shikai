import Foundation

public struct Header {
    public internal(set) var status: Status
    public internal(set) var meta: String
}

public struct Request {
    public let url: URL

    public init(url: URL) {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            preconditionFailure("not a url: \(url)")
        }

        if components.scheme == nil {
            components.scheme = "gemini"
        }

        if components.port == nil {
            components.port = 1965
        }

        precondition(components.scheme == "gemini", "only gemini scheme is supported")
        precondition(components.host != nil, "host is required")
        self.url = components.url!
    }

    func encoded() -> Data? {
        var url = self.url.absoluteString
        url.append("\r\n")
        return url.data(using: .utf8)
    }
}

public struct Response {
    public let header: Header
    public let data: Data
}
