import Testing
@testable import Sample

struct AgeSwiftTests {
    @Test func adultAt18() {
        #expect(isAdult(age: 18))
    }
}
