@testable import Gemini
import XCTest

final class ClientTests: XCTestCase {
    func testExample() {
        let client = GeminiClient()
        let session = GeminiSession(client: client)
        let request = GeminiRequest(url: URL(string: "gemini://gemini.circumlunar.space")!)

        let waiter = expectation(description: "request")
        session.send(request) { result in
            switch result {
            case let .success(response):
                print(response)

            case let .failure(error):
                XCTFail(error.localizedDescription)
            }

            waiter.fulfill()
        }

        wait(for: [waiter], timeout: .infinity)
    }
}
