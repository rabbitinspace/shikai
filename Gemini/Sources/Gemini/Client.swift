import Foundation
import Network

public final class GeminiClient {
    public let configuration: Configuration

    public init(configuration: Configuration = .default) {
        self.configuration = configuration
    }

    public func send(_ request: Request, completion: @escaping SendCompletion) -> ConnectionTask {
        let builder = ConnectionBuilder(url: request.url, configuration: configuration)
        let connection = builder.build()

        let task = ConnectionTask(connection: connection, request: request, completion: completion)
        task.start(on: configuration.queue)
        return task
    }
}

extension GeminiClient {
    public typealias IPFamily = Network.NWProtocolIP.Options.Version
    public typealias SendCompletion = ConnectionTask.Completion

    public struct Configuration {
        public static var `default`: Configuration {
            return Configuration()
        }
        
        public var ipFamily = IPFamily.any

        public var connectionTimeout = 30
        public var connectionDropTime = 30

        public var queue = DispatchQueue(label: "gemini.client", qos: .userInitiated, attributes: .concurrent)
    }

    // TODO: add progress reporting
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
