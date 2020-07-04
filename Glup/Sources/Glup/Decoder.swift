import Foundation

public enum DecodingError: Error {
    case badEncoding
}

final class UTF8ScalarsIterator: IteratorProtocol {
    
    private(set) var dataOffset = 0
    
    private let data: Data
    private var dataIterator: Data.Iterator
    private var decoder = UTF8()
    private var isFinished = false
    
    init(data: Data) {
        self.data = data
        dataIterator = data.makeIterator()
    }
    
    func next() -> Result<Unicode.Scalar, Error>? {
        guard !isFinished else {
            return nil
        }
        
        switch decoder.decode(&dataIterator) {
        case .scalarValue(let scalar):
            dataOffset += scalar.utf8.count
            return .success(scalar)

        case .emptyInput:
            isFinished = true
            return nil

        case .error:
            isFinished = true
            return .failure(DecodingError.badEncoding)
        }
    }
    
    
    
}
