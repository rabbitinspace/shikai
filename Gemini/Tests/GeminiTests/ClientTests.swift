@testable import Gemini
import XCTest

final class ClientTests: XCTestCase {
    func testExample() {
        let client = GeminiClient()
        let request = Request(url: URL(string: "gemini://gemini.circumlunar.space:1965/")!)
        
        let waiter = expectation(description: "request")
        let task = client.send(request) { result in
            switch result {
            case .success(let response):
                print(response)
                
            case .failure(let error):
                XCTFail(error.localizedDescription)
            }
            
            waiter.fulfill()
        }
        
        wait(for: [waiter], timeout: .infinity)
    }
}
