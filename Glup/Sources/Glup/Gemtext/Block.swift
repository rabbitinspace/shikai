import Foundation

enum GemtextBlock {
    case empty
    case text(Text)
    case link(Link)
    case preformatted(Preformatted)
    case header(Header)
    case list(List)
    case quote(Quote)
}

protocol ContentBlock {
    static func matches(_ data: Data, encoding: TextEncoding) -> Bool
    static func make(from data: Data, encoding: TextEncoding) -> Result<Self, Error>
}

final class UTF8ContentBlockIterator: IteratorProtocol {
    private let data: Data
    private var cursor: Int
    
    init(data: Data) {
        self.data = data
        cursor = 0
    }
    
    func next() -> ContentBlock? {
        nil
    }
    
    private func nextBlock() -> GemtextBlock {
        guard cursor < data.count else {
            return .empty
        }
        
        let nextLineCursor = readLine(from: cursor)
        defer { cursor = nextLineCursor }
        
        let rawBlock = Data(data[cursor..<nextLineCursor])
        
    }
    
    private func readLine(from startCursor: Int) -> Int {
        var endCursor = startCursor
        while endCursor < data.count {
            let (isLineFeed, lineCursor) = self.isLineFeed(at: endCursor)
            endCursor = lineCursor + 1
            
            if isLineFeed {
                break
            }
        }
        
        return endCursor
    }
    
    private func isLineFeed(at cursor: Int) -> (Bool, Int) {
        let cr = 13
        let lf = 10
        
        guard data[cursor] != lf else {
            return (true, cursor)
        }
        
        guard data[cursor] == cr, cursor < data.count - 1 else {
            return (false, cursor)
        }
        
        let isLineFeed = data[cursor + 1] == lf
        return (isLineFeed, isLineFeed ? cursor + 1 : cursor)
    }
}

extension GemtextBlock {
    struct Text {
        let content: Data
    }

    struct Link {
        let url: Data
        let name: Data?
    }

    struct Preformatted {
        let content: Data
        let altContent: Data?
    }

    struct Header {
        let name: Data
        let level: Int
    }

    struct List {
        struct Item {
            let content: Data
        }
        
        let items: [Item]
    }

    struct Quote {
        let content: Data
    }
}

extension GemtextBlock.Text: ContentBlock {
    static func matches(_ data: Data, encoding: TextEncoding) -> Bool {
        return !data.isEmpty && encoding == .utf8
    }
    
    static func make(from data: Data, encoding: TextEncoding) -> Result<GemtextBlock.Text, Error> {
        precondition(matches(data, encoding: encoding), "no matching block")
        return .success(GemtextBlock.Text(content: data))
    }
}

extension GemtextBlock.Link: ContentBlock {
    static func matches(_ data: Data, encoding: TextEncoding) -> Bool {
        guard data.count > 2, encoding == .utf8 else {
            return false
        }
        
        // 61 is "=" and 62 is ">"
        return data[0] == 61 && data[1] == 62
    }
    
    static func make(from data: Data, encoding: TextEncoding) -> Result<GemtextBlock.Link, Error> {
        precondition(matches(data, encoding: encoding), "no matching block")
        
        var iterator = UnicodeScalarsIterator(data: data.dropFirst(2))
        
    }
    
    
}

private func decodeScalars(from data: Data) -> Result<[Unicode.Scalar], DecodingError> {
    var iterator = data.makeIterator()
    var decoder = UTF8()
    var scalars = [Unicode.Scalar]()
    scalars.reserveCapacity(data.count)
    
    while true {
        switch decoder.decode(&iterator) {
        case .scalarValue(let scalar):
            scalars.append(scalar)
            
        case .emptyInput:
            break
        
        case .error:
            return .failure(.badEncoding)
        }
    }
    
    return scalars
}
