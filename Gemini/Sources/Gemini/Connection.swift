import Foundation
import Network

extension ConnectionTask {
    public enum Error: Swift.Error {
        public typealias ConnectionError = Network.NWError

        case connection(ConnectionError)
        case badRequestEncoding(Request)
        case sendRequestFailed(ConnectionError)
    }
}

public final class ConnectionTask {
    public typealias Completion = (Result<Response, Error>) -> Void

    private let connection: NWConnection
    private let request: Request
    private let completion: Completion

    init(connection: NWConnection, request: Request, completion: @escaping Completion) {
        self.connection = connection
        self.request = request
        self.completion = completion
    }

    func start(on _: DispatchQueue) {}

    public func cancel() {}
}

final class ConnectionBuilder {
    // MARK: Properties

    let url: URL

    var ipFamily: GeminiClient.IPFamily?
    var connectionTimeout: Int?
    var connectionDropTime: Int?

    // MARK: Init & deinit

    init(url: URL, configuration: GeminiClient.Configuration? = nil) {
        self.url = url

        if let configuration = configuration {
            ipFamily = configuration.ipFamily
            connectionTimeout = configuration.connectionTimeout
            connectionDropTime = configuration.connectionDropTime
        }
    }

    // MARK: Methods

    func build() -> NWConnection {
        let endpoint = NWEndpoint.url(url)
        let parameters = NWParameters.tls
        setTLSOptions(parameters: parameters)
        setTCPOptions(parameters: parameters)
        setIPOptions(parameters: parameters)

        return NWConnection(to: endpoint, using: parameters)
    }

    // MARK: Private configuration

    private func setTLSOptions(parameters: NWParameters) {
        let options = parameters.defaultProtocolStack.applicationProtocols.compactMap { $0 as? NWProtocolTLS.Options }
        guard !options.isEmpty else { return }

        let tls = options[0].securityProtocolOptions
        sec_protocol_options_set_min_tls_protocol_version(tls, .TLSv12)
        sec_protocol_options_set_max_tls_protocol_version(tls, .TLSv13)

        if let host = url.host {
            host.utf8CString.withUnsafeBufferPointer { buf in
                if let ptr = buf.baseAddress {
                    // TODO: will the func copy the string?
                    sec_protocol_options_set_tls_server_name(tls, ptr)
                }
            }
        }
    }

    private func setTCPOptions(parameters: NWParameters) {
        guard let options = parameters.defaultProtocolStack.transportProtocol as? NWProtocolTCP.Options else {
            return
        }

        if let connectionTimeout = connectionTimeout {
            options.connectionTimeout = connectionTimeout
        }

        if let connectionDropTime = connectionDropTime {
            options.connectionDropTime = connectionDropTime
        }
    }

    private func setIPOptions(parameters: NWParameters) {
        guard let options = parameters.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options else {
            return
        }

        if let ipFamily = ipFamily {
            options.version = ipFamily
        }
    }
}

final class RequestWriter {
    private let connection: NWConnection

    init(connection: NWConnection) {
        self.connection = connection
    }

    func writeRequest(
        _ request: Request,
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
    private let connection: NWConnection
    private let request: Request

    init(connection: NWConnection, request: Request) {
        self.connection = connection
        self.request = request
    }
}
