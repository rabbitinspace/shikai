import AppKit
import WebKit

final class GeminiBrowserController: NSViewController {
    private var webView: WKWebView {
        view as! WKWebView
    }

    override func loadView() {
        view = WKWebView(frame: .zero, configuration: .gemini)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let request = URLRequest(url: URL(string: "gemini://gemini.circumlunar.space")!)
        webView.load(request)
    }
}

private extension WKWebViewConfiguration {
    static var gemini: WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.applicationNameForUserAgent = Localizable.App.name
        return config
    }
}
