import Foundation
import Gemini

final class GeminiURLProtocol: URLProtocol {
    /// This property must have value before the protocol can be registered.
    static var sessionFactory: (() -> GeminiSession)!

    override class func canInit(with task: URLSessionTask) -> Bool {
        guard let scheme = task.originalRequest?.url?.scheme else {
            return false
        }

        return scheme == "gemini" && sessionFactory != nil
    }

    private let session: GeminiSession

    private var lock = OSLock()
    private var geminiTask: GeminiSession.Task?

    override init(request: URLRequest, cachedResponse: CachedURLResponse?, client: URLProtocolClient?) {
        session = Self.sessionFactory()
        super.init(request: request, cachedResponse: cachedResponse, client: client)
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        var request = request
        request.url = request.url?.absoluteURL
        return request
    }

    // TODO: report redirects to client
    override func startLoading() {
        guard let client = client, let url = request.url else {
            assertionFailure("There should be an URL")
            return
        }

        let policy = session.client.configuration.requiresFlushingCaches
            ? URLCache.StoragePolicy.notAllowed
            : URLCache.StoragePolicy.allowedInMemoryOnly

        let request = GeminiRequest(url: url)
        let task = session.send(request) { result in
            switch result {
            case let .success(response):
                assert(response.header.status.type == .success)

                let nativeResponse = HTTPURLResponse(
                    url: url,
                    mimeType: response.mime?.name,
                    expectedContentLength: response.data.count,
                    textEncodingName: response.mime?.parameters.first?.value
                )

                client.urlProtocol(self, didReceive: nativeResponse, cacheStoragePolicy: policy)
                client.urlProtocol(self, didLoad: response.data)
                client.urlProtocolDidFinishLoading(self)

            case let .failure(error):
                client.urlProtocol(self, didFailWithError: error)
            }
        }

        lock.whileLocked { self.geminiTask = task }
    }

    override func stopLoading() {
        lock.whileLocked { geminiTask?.cancel(); geminiTask = nil }
    }
}
