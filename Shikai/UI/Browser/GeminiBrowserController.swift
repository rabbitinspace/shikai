import AppKit
import WebKit

final class GeminiBrowserController: NSViewController {
    private var webView: WKWebView {
        view as! WKWebView
    }

    override func loadView() {
        let view = WKWebView(frame: .zero, configuration: .gemini)
        view.navigationDelegate = self
        self.view = view
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let request = URLRequest(url: URL(string: "gemini://gemini.circumlunar.space")!)
        webView.load(request)
    }
}

extension GeminiBrowserController: WKNavigationDelegate {
    func webView(_: WKWebView, didFinish navigation: WKNavigation!) {
        print(navigation)
    }

    func webView(_: WKWebView, didFail _: WKNavigation!, withError error: Error) {
        print(error)
    }

    func webView(_: WKWebView, didCommit navigation: WKNavigation!) {
        print(navigation)
    }

    func webView(_: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print(navigation)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        print(webView)
    }

    func webView(_: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        print(navigation)
    }

    func webView(_: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError error: Error) {
        print(error)
    }
}

private extension WKWebViewConfiguration {
    static var gemini: WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.applicationNameForUserAgent = Localizable.App.name
        GeminiSchemeHandler.register(for: config)
        return config
    }
}
