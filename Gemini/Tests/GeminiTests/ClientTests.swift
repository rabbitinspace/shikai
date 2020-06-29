@testable import Gemini
import XCTest

final class ClientTests: XCTestCase {
    func testExample() {
        let client = GeminiClient()
        let request = Request(url: URL(string: "gemini://tilde.space")!)
        client.send(request, completion: nil)
    }
}
