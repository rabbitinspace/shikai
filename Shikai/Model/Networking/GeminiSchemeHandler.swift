import Foundation
import WebKit

import Gemini

final class GeminiSchemeHandler: NSObject, WKURLSchemeHandler {
    static func register(for configuration: WKWebViewConfiguration) {
        // TODO: configure based on the webkit configuration
        let clientConfiguration = GeminiClient.Configuration.default
        let session = GeminiSession(client: GeminiClient(configuration: clientConfiguration))
        let handler = GeminiSchemeHandler(session: session)

        configuration.setURLSchemeHandler(handler, forURLScheme: "gemini")
    }

    enum SchemeError: Error {
        case badRequest
    }

    private let session: GeminiSession

    private var lock = OSLock()
    private var tasks = [ObjectIdentifier: GeminiSession.Task]()

    init(session: GeminiSession) {
        self.session = session
    }

    func webView(_: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url, url.scheme == "gemini" else {
            urlSchemeTask.didFailWithError(SchemeError.badRequest)
            return
        }

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

                urlSchemeTask.didReceive(nativeResponse)
                urlSchemeTask.didReceive(response.data)
                urlSchemeTask.didFinish()

            case let .failure(error):
                urlSchemeTask.didFailWithError(error)
            }
        }

        lock.whileLocked { tasks[ObjectIdentifier(urlSchemeTask)] = task }
    }

    func webView(_: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        let task = lock.whileLocked { tasks.removeValue(forKey: ObjectIdentifier(urlSchemeTask)) }
        task?.cancel()
    }
}
