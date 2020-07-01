import Foundation
import Network

/// A client that can send requests via Gemini protocol.
public class GeminiClient {
    // MARK: Public properties

    /// Configuration for the current client.
    public let configuration: Configuration

    // MARK: Init & deinit

    /// Creates new reusable client with provided `configuration`.
    public init(configuration: Configuration = .default) {
        self.configuration = configuration
    }

    /// Sends a `request` via Gemini protocol and returns an in-progress connection task.
    /// - Parameters:
    ///   - request: the request to send.
    ///   - completion: closure to call on response or on request error.
    /// - Returns: an in-progress task that manages a connection on behalf of the `request`.
    @discardableResult
    public func send(_ request: GeminiRequest, completion: @escaping SendCompletion) -> ConnectionTask {
        let builder = makeConnectionBuilder(for: request, configuration: configuration)
        let connection = builder.build()
        
        // get privacy context to flush caches if needed
        let context = builder.privacyContext
        let shouldFlushCaches = configuration.requiresFlushingCaches

        let task = ConnectionTask(connection: connection, request: request, completion: completion)
        task.setTaskCompletion { [task] in
            if let context = context, shouldFlushCaches {
                context.flushCache()
            }
            
            // TODO: check retain cycle
            // release the task.
            task.setTaskCompletion(nil)
        }
        
        task.start(on: configuration.queue)
        return task
    }
    
    // MARK: Internal methods
    
    /// Creates and returns a new builder object which can create and configure a `NWConnection` for the given `request` and client `configuration`.
    func makeConnectionBuilder(for request: GeminiRequest, configuration: Configuration) -> ConnectionBuilder {
        ConnectionBuilder(url: request.url, configuration: configuration)
    }
}

// MARK: - Client extensions

extension GeminiClient {
    /// IP family to use when making a connection.
    public typealias IPFamily = Network.NWProtocolIP.Options.Version

    /// Completion block which will be called on server response.
    public typealias SendCompletion = ConnectionTask.Completion

    /// Configuration of a Gemini client.
    public struct Configuration {
        /// Creates and returns a default client configuration.
        public static var `default`: Configuration {
            Configuration()
        }

        /// IP family which client can use to establish a connection.
        public var ipFamily = IPFamily.any

        /// Timeout for a new connection before marking it as failed to connect.
        public var connectionTimeout: TimeInterval = 30

        /// Timeout for TCP retransmission attempt before marking a packet as failed to send.
        public var connectionDropTime: TimeInterval = 30

        /// A queue to use for sending a request and receiving a response.
        public var queue = DispatchQueue(label: "gemini.client", qos: .userInitiated, attributes: .concurrent)
        
        /// Indicates that system logging for a TCP connection must be disabled.
        ///
        /// Set this value to `false` to leave a default behaviour.
        public var requiresDisablingLogging = false
        
        /// Indicates that TCP connection caches must be flushed after connection is closed.
        ///
        /// Set this value to `false` to leave a default behaviour.
        public var requiresFlushingCaches = false
    }
}

// MARK: - Internal types

/// Creates a NWConnection instances based on Gemini client configuration.
final class ConnectionBuilder {
    // MARK: Properties

    /// URL where to send a request.
    let url: URL

    /// Supported IP families.
    var ipFamily: GeminiClient.IPFamily?

    /// Client connection timeout.
    var connectionTimeout: Int?

    /// TCP packet retransmission timeout.
    var connectionDropTime: Int?
    
    /// Disables TCP connection logging.
    var disableLogging: Bool?
    
    /// A privacy context used to create last connection.
    private(set) var privacyContext: NWParameters.PrivacyContext?

    // MARK: Init & deinit

    /// Creates new connection builder object for the request `url` and with the provided `configuration`.
    init(url: URL, configuration: GeminiClient.Configuration? = nil) {
        self.url = url

        if let configuration = configuration {
            ipFamily = configuration.ipFamily
            connectionTimeout = Int(configuration.connectionTimeout)
            connectionDropTime = Int(configuration.connectionDropTime)
            disableLogging = configuration.requiresDisablingLogging
        }
    }

    // MARK: Methods

    /// Creates and returns a new `NWConnection` instance with builder's configuration.
    func build() -> NWConnection {
        let endpoint = NWEndpoint.url(url)
        let parameters = NWParameters.tls
        setTLSOptions(parameters: parameters)
        setTCPOptions(parameters: parameters)
        setIPOptions(parameters: parameters)
        setPrivacyOptions(parameters: parameters)

        return NWConnection(to: endpoint, using: parameters)
    }

    // MARK: Private configuration

    /// Sets required TLS options in the `parameters` object.
    private func setTLSOptions(parameters: NWParameters) {
        let options = parameters.defaultProtocolStack.applicationProtocols.compactMap { $0 as? NWProtocolTLS.Options }
        guard !options.isEmpty else { return }

        // as per spec, only tls1.2 and tls1.3 should be supported
        let tls = options[0].securityProtocolOptions
        sec_protocol_options_set_min_tls_protocol_version(tls, .TLSv12)
        sec_protocol_options_set_max_tls_protocol_version(tls, .TLSv13)

        // we also need to indicate server name we're trying to connect to
        if let host = url.host {
            host.utf8CString.withUnsafeBufferPointer { buf in
                if let ptr = buf.baseAddress {
                    sec_protocol_options_set_tls_server_name(tls, ptr)
                }
            }
        }
    }

    /// Sets required TCP options in the `parameters` object.
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

    /// Sets required IP options in the `parameters` object.
    private func setIPOptions(parameters: NWParameters) {
        guard let options = parameters.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options else {
            return
        }

        if let ipFamily = ipFamily {
            options.version = ipFamily
        }
    }
    
    /// Sets required privacy options in the `parameters` object.
    private func setPrivacyOptions(parameters: NWParameters) {
        let context = NWParameters.PrivacyContext(description: "Gemini Request")
        if disableLogging == true {
            context.disableLogging()
        }
        
        parameters.setPrivacyContext(context)
        privacyContext = context
    }
}
