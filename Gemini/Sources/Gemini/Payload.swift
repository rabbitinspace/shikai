import Foundation

public struct GeminiRequest {
    public let id = UUID()
    public private(set) var url: URL

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
        precondition(components.host?.isEmpty == false, "host is required")
        self.url = components.url!
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
    public let mime: MIME?
    public let data: Data

    public init(header: Header, data: Data) {
        self.header = header
        self.data = data

        if header.status.type == .success, !header.meta.isEmpty {
            mime = MIME(stringLiteral: header.meta)
        } else {
            mime = nil
        }
    }
}

public struct MIME: Equatable {
    public struct Parameters: Equatable {
        public let name: String
        public let value: String
    }

    public let name: String
    public let parameters: [Parameters]
}

extension MIME: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = parseMIME(from: value)
    }
}

private func parseMIME(from string: String) -> MIME {
    var (name, remaining) = parseMIMEName(from: string)
    var parameters = [MIME.Parameters]()

    while !remaining.isEmpty {
        let (parsed, more) = nextMIMEParameter(from: remaining)
        if let parsed = parsed {
            parameters.append(parsed)
            remaining = more
            continue
        }

        break
    }
    
    // default mime type is gemini in utf8
    if name.isEmpty {
        name = "text/gemini"
        parameters.append(MIME.Parameters(name: "charset", value: "utf-8"))
    }

    return MIME(name: name, parameters: parameters)
}

private func parseMIMEName(from string: String) -> (String, String) {
    var cursor = string.startIndex
    while cursor != string.endIndex, string[cursor] != ";" {
        cursor = string.index(after: cursor)
    }

    return (String(string[string.startIndex ..< cursor]), String(string[cursor ..< string.endIndex]))
}

private func nextMIMEParameter(from string: String) -> (MIME.Parameters?, String) {
    var startCursor = string.startIndex
    while startCursor != string.endIndex, string[startCursor].isWhitespace || string[startCursor] == ";" {
        startCursor = string.index(after: startCursor)
    }

    guard startCursor != string.endIndex else {
        return (nil, string)
    }

    var separatorCursor = startCursor
    while separatorCursor != string.endIndex, string[separatorCursor] != "=" {
        separatorCursor = string.index(after: separatorCursor)
    }

    guard separatorCursor != string.endIndex else {
        return (nil, string)
    }

    let valueCursor = string.index(after: separatorCursor)
    var endCursor = valueCursor
    while endCursor != string.endIndex, string[endCursor] != ";" {
        endCursor = string.index(after: endCursor)
    }

    guard separatorCursor != endCursor else {
        return (nil, string)
    }

    let name = String(string[startCursor ..< separatorCursor])
    let value = String(string[valueCursor ..< endCursor])

    return (MIME.Parameters(name: name, value: value), String(string[endCursor ..< string.endIndex]))
}
