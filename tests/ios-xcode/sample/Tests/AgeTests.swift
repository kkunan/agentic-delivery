import XCTest
@testable import Sample

final class AgeTests: XCTestCase {
    func testAdult() {
        XCTAssertTrue(isAdult(age: 30))
        XCTAssertFalse(isAdult(age: 5))
    }

    func testAdultAt18() {
        XCTAssertTrue(isAdult(age: 18))
    }

    func testSkipped() throws {
        throw XCTSkip("skipped on purpose")
    }
}
