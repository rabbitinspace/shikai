@testable import Gemini
import XCTest

final class MIMETests: XCTestCase {
    func testTextMIME() {
        let mime: MIME = "text/plain"
        XCTAssertEqual(mime.name, "text/plain")
        XCTAssertTrue(mime.parameters.isEmpty)
    }

    func testTextWithCharset() {
        let mime: MIME = "text/plain; charset=UTF-8"
        XCTAssertEqual(mime.name, "text/plain")
        XCTAssertEqual(mime.parameters.count, 1)
        XCTAssertEqual(mime.parameters[0], MIME.Parameters(name: "charset", value: "UTF-8"))
    }

    func testTextWithCharsetAndSpaces() {
        let mime: MIME = "text/plain;            charset=UTF-8  "
        XCTAssertEqual(mime.name, "text/plain")
        XCTAssertEqual(mime.parameters.count, 1)
        XCTAssertEqual(mime.parameters[0], MIME.Parameters(name: "charset", value: "UTF-8  "))
    }

    func testMultipleParameters() {
        let mime: MIME = "image/png; quality=cool; meme=dank"
        XCTAssertEqual(mime.name, "image/png")
        XCTAssertEqual(mime.parameters.count, 2)
        XCTAssertEqual(mime.parameters[0], MIME.Parameters(name: "quality", value: "cool"))
        XCTAssertEqual(mime.parameters[1], MIME.Parameters(name: "meme", value: "dank"))
    }

    func testEmpty() {
        let mime: MIME = ""
        XCTAssertTrue(mime.name.isEmpty)
        XCTAssertTrue(mime.parameters.isEmpty)
    }
}
