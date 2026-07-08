import XCTest

final class DiceRollerTests: XCTestCase {
    func testRollsDExpressionWithDeterministicRandomness() throws {
        var values = [3, 4]
        let result = try DiceRoller.roll("2d6+3") { _ in values.removeFirst() }
        XCTAssertEqual(result.total, 10)
        XCTAssertEqual(result.rolls, [3, 4])
        XCTAssertTrue(result.detail.contains("2d6[3,4]"))
    }

    func testSupportsGermanWAndNegativeModifiers() throws {
        let result = try DiceRoller.roll("1W8-2") { _ in 5 }
        XCTAssertEqual(result.total, 3)
    }

    func testRejectsInvalidExpression() {
        XCTAssertThrowsError(try DiceRoller.roll("abc"))
    }
}
