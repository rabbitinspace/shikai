import Foundation
import Network

public final class ConnectionTask: Identifiable {
    public typealias Completion = (Result<GeminiResponse, Error>) -> Void
    public typealias TaskCompletion = () -> Void
    
    public var id: UUID {
        return request.id
    }

    let connection: NWConnection
    let request: GeminiRequest
    let completion: Completion

    private let lock = OSLock()
    private var state = State.ready
    private var writer: RequestWriter? // not thread-safe
    private var reader: ResponseReader? // not thread-safe
    
    private var taskCompletion: TaskCompletion?

    init(connection: NWConnection, request: GeminiRequest, completion: @escaping Completion) {
        self.connection = connection
        self.request = request
        self.completion = completion
    }

    func start(on queue: DispatchQueue) {
        connection.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }

            switch state {
            case .ready:
                self.proceedWithRequest()

            case let .failed(error):
                self.finish(with: .failure(.connection(error)))
                self.callTaskCompletion()
                
            case .cancelled:
                self.callTaskCompletion()

            default:
                break // don't handle other cases for now
            }
        }

        connection.start(queue: queue)
    }

    public func cancel() {
        lock.whileLocked { state = .cancelled }

        // cancelling will also call send/receive block with a cancelled posix error
        connection.cancel()
    }
    
    /// Sets a completion handler which will be called after the task has finished it job even if it was cancelled.
    func setTaskCompletion(_ completion: TaskCompletion?) {
        lock.whileLocked { taskCompletion = completion }
    }

    private func finish(with result: Result<GeminiResponse, Error>) {
        let currentState: State = lock.whileLocked {
            let currentState = state
            state = state == .ready ? .finished : state
            return currentState
        }

        guard currentState == .ready else { return }

        // we need to cancel a connection to clean up resources
        connection.cancel()
        completion(result)
    }

    private func proceedWithRequest() {
        guard lock.whileLocked(do: { state }) == .ready else { return }

        writer = RequestWriter(connection: connection)
        writer!.writeRequest(request) { [weak self] result in
            switch result {
            case let .success(reader):
                self?.proceedWithResponse(reader)

            case let .failure(error):
                self?.finish(with: .failure(error))
            }
        }
    }

    private func proceedWithResponse(_ reader: ResponseReader) {
        guard lock.whileLocked(do: { state }) == .ready else { return }

        self.reader = reader
        reader.readRequest { [weak self] result in
            switch result {
            case let .success(response):
                self?.finish(with: .success(response))

            case let .failure(error):
                self?.finish(with: .failure(error))
            }
        }
    }
    
    private func callTaskCompletion() {
        let completion: TaskCompletion? = lock.whileLocked {
            let completion = taskCompletion
            taskCompletion = nil
            
            if state == .ready {
                state = .finished
            }
            
            return completion
        }
        
        completion?()
    }
}

extension ConnectionTask {
    public enum Error: Swift.Error {
        public typealias ConnectionError = Network.NWError

        case connection(ConnectionError)
        case badRequestEncoding(GeminiRequest)
        case sendRequestFailed(ConnectionError)
        case receiveResponseFailed(ConnectionError)
        case incompleteResponse(Data?)
        case invalidStatusCode(Data)
        case badStatusCode(Int)
        case badHeaderMeta(Data)
    }

    private enum State {
        case ready
        case finished
        case cancelled
    }
}

final class RequestWriter {
    private let connection: NWConnection

    init(connection: NWConnection) {
        self.connection = connection
    }

    func writeRequest(
        _ request: GeminiRequest,
        completion: @escaping (Result<ResponseReader, ConnectionTask.Error>) -> Void
    ) {
        guard let content = request.encoded() else {
            completion(.failure(.badRequestEncoding(request)))
            return
        }

        let connection = self.connection
        connection.send(content: content, completion: .contentProcessed { error in
            if let error = error {
                completion(.failure(.sendRequestFailed(error)))
            } else {
                let reader = ResponseReader(connection: connection, request: request)
                completion(.success(reader))
            }
        })
    }
}

final class ResponseReader {
    typealias Completion = (Result<GeminiResponse, ConnectionTask.Error>) -> Void

    private let connection: NWConnection
    private let request: GeminiRequest

    init(connection: NWConnection, request: GeminiRequest) {
        self.connection = connection
        self.request = request
    }

    // TODO: for now read the whole response instead of parsing on-the-fly
    func readRequest(with completion: @escaping Completion) {
        connection.receiveMessage { [weak self] data, _, isComplete, error in
            guard let self = self else { return }

            guard error == nil else {
                completion(.failure(.receiveResponseFailed(error!)))
                return
            }

            assert(isComplete, "receiving should be finished now")
            guard let data = data else {
                completion(.failure(.incompleteResponse(nil)))
                return
            }

            completion(self.parseResponse(from: data))
        }
    }

    private func parseResponse(from data: Data) -> Result<GeminiResponse, ConnectionTask.Error> {
        var data = data

        let status: GeminiStatus
        switch parseStatusCode(from: data) {
        case let .success((s, consumed)):
            status = s
            // TODO: crashes without Data()
            data = Data(data.dropFirst(consumed))

        case let .failure(error):
            return .failure(error)
        }

        let meta: String
        switch parseMeta(from: data) {
        case let .success((m, consumed)):
            meta = m
            // TODO: crashes without Data()
            data = Data(data.dropFirst(consumed))

        case let .failure(error):
            return .failure(error)
        }

        let header = GeminiResponse.Header(status: status, meta: meta)
        return .success(GeminiResponse(header: header, data: data))
    }
}

// MARK: - Internal functions

func parseStatusCode(from data: Data) -> Result<(GeminiStatus, Int), ConnectionTask.Error> {
    guard data.count >= 3 else {
        return .failure(.invalidStatusCode(data))
    }

    // header is utf-8 encoded, so digits are in interval from 48 to 57 and space is 32
    let range: ClosedRange<UInt8> = 48 ... 57
    guard range ~= data[0], range ~= data[1], data[2] == 32 else {
        return .failure(.invalidStatusCode(data))
    }

    let code = Int((data[0] - range.lowerBound) * 10 + (data[1] - range.lowerBound))
    let status = GeminiStatus(rawValue: code)
    return status.map { .success(($0, 3)) } ?? .failure(.badStatusCode(code))
}

func parseMeta(from data: Data) -> Result<(String, Int), ConnectionTask.Error> {
    // max meta length is 1024 bytes
    let metaMax = 1024
    let cr = 13
    let lf = 10

    var metaEnd = 0
    while metaEnd <= metaMax, metaEnd < data.count {
        // we need to find a CRLF sequence
        guard data[metaEnd] == cr || data[metaEnd] == lf else {
            metaEnd += 2
            continue
        }

        if data[metaEnd] == cr, metaEnd + 1 < data.count, data[metaEnd + 1] == lf {
            metaEnd += 1
            break
        } else if data[metaEnd] == lf, metaEnd - 1 >= 0, data[metaEnd - 1] == cr {
            break
        } else {
            metaEnd += 2
        }
    }

    guard metaEnd >= 1, metaEnd <= metaMax else {
        return .failure(.badHeaderMeta(data))
    }

    if metaEnd == 1 {
        return .success(("", metaEnd + 1))
    }

    guard let meta = String(bytes: data[0 ... metaEnd - 2], encoding: .utf8) else {
        return .failure(.badHeaderMeta(data))
    }

    return .success((meta, metaEnd + 1))
}
