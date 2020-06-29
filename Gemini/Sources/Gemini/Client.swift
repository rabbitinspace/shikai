import Foundation
import Network

extension GeminiClient {
    public typealias IPFamily = Network.NWProtocolIP.Options.Version
    public typealias SendCompletion = ConnectionTask.Completion

    public struct Configuration {
        public var ipFamily = IPFamily.any

        public var connectionTimeout = 30
        public var connectionDropTime = 30

        public var queue = DispatchQueue(label: "gemini.client", qos: .userInitiated, attributes: .concurrent)
    }

    // TODO: add progress reporting
}

public final class GeminiClient {
    public let configuration: Configuration

    public init(configuration: Configuration) {
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
