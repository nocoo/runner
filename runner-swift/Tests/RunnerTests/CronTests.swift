import XCTest
@testable import runner

final class CronTests: XCTestCase {
    
    // MARK: - Parsing Tests
    
    func testParseAny() {
        XCTAssertEqual(CronExpr.parse("*", min: 0, max: 59), .any)
    }
    
    func testParseExactFromInt() {
        XCTAssertEqual(CronExpr.parse(5, min: 0, max: 59), .exact(5))
        XCTAssertEqual(CronExpr.parse(0, min: 0, max: 23), .exact(0))
        XCTAssertEqual(CronExpr.parse(23, min: 0, max: 23), .exact(23))
    }
    
    func testParseExactFromString() {
        XCTAssertEqual(CronExpr.parse("5", min: 0, max: 59), .exact(5))
        XCTAssertEqual(CronExpr.parse("0", min: 0, max: 23), .exact(0))
        XCTAssertEqual(CronExpr.parse("59", min: 0, max: 59), .exact(59))
    }
    
    func testParseRange() {
        XCTAssertEqual(CronExpr.parse("1-5", min: 0, max: 6), .range(1, 5))
        XCTAssertEqual(CronExpr.parse("9-17", min: 0, max: 23), .range(9, 17))
        XCTAssertEqual(CronExpr.parse("0-6", min: 0, max: 6), .range(0, 6))
    }
    
    func testParseRangeInvalid() {
        // Invalid range (start > end) should return .any
        XCTAssertEqual(CronExpr.parse("5-1", min: 0, max: 6), .any)
    }
    
    func testParseList() {
        XCTAssertEqual(CronExpr.parse("0,15,30,45", min: 0, max: 59), .list([0, 15, 30, 45]))
        XCTAssertEqual(CronExpr.parse("1,3,5", min: 0, max: 6), .list([1, 3, 5]))
    }
    
    func testParseListWithSpaces() {
        XCTAssertEqual(CronExpr.parse("0, 15, 30, 45", min: 0, max: 59), .list([0, 15, 30, 45]))
    }
    
    func testParseStep() {
        XCTAssertEqual(CronExpr.parse("*/10", min: 0, max: 59), .step(10))
        XCTAssertEqual(CronExpr.parse("*/15", min: 0, max: 59), .step(15))
        XCTAssertEqual(CronExpr.parse("*/2", min: 0, max: 23), .step(2))
    }
    
    func testParseStepZero() {
        // Step 0 is invalid, should return .any
        XCTAssertEqual(CronExpr.parse("*/0", min: 0, max: 59), .any)
    }
    
    func testParseInvalidString() {
        XCTAssertEqual(CronExpr.parse("invalid", min: 0, max: 59), .any)
        XCTAssertEqual(CronExpr.parse("", min: 0, max: 59), .any)
    }
    
    func testParseNilValue() {
        XCTAssertEqual(CronExpr.parse(nil as Any?, min: 0, max: 59), .any)
    }
    
    // MARK: - Matching Tests
    
    func testMatchesAny() {
        let expr = CronExpr.any
        XCTAssertTrue(expr.matches(0))
        XCTAssertTrue(expr.matches(30))
        XCTAssertTrue(expr.matches(59))
    }
    
    func testMatchesExact() {
        let expr = CronExpr.exact(15)
        XCTAssertFalse(expr.matches(0))
        XCTAssertTrue(expr.matches(15))
        XCTAssertFalse(expr.matches(30))
    }
    
    func testMatchesExactBoundary() {
        XCTAssertTrue(CronExpr.exact(0).matches(0))
        XCTAssertTrue(CronExpr.exact(59).matches(59))
        XCTAssertTrue(CronExpr.exact(23).matches(23))
    }
    
    func testMatchesRange() {
        let expr = CronExpr.range(9, 17)
        XCTAssertFalse(expr.matches(8))
        XCTAssertTrue(expr.matches(9))
        XCTAssertTrue(expr.matches(13))
        XCTAssertTrue(expr.matches(17))
        XCTAssertFalse(expr.matches(18))
    }
    
    func testMatchesRangeSingleValue() {
        let expr = CronExpr.range(5, 5)
        XCTAssertFalse(expr.matches(4))
        XCTAssertTrue(expr.matches(5))
        XCTAssertFalse(expr.matches(6))
    }
    
    func testMatchesList() {
        let expr = CronExpr.list([0, 15, 30, 45])
        XCTAssertTrue(expr.matches(0))
        XCTAssertFalse(expr.matches(10))
        XCTAssertTrue(expr.matches(15))
        XCTAssertTrue(expr.matches(30))
        XCTAssertTrue(expr.matches(45))
        XCTAssertFalse(expr.matches(50))
    }
    
    func testMatchesListEmpty() {
        let expr = CronExpr.list([])
        XCTAssertFalse(expr.matches(0))
        XCTAssertFalse(expr.matches(30))
    }
    
    func testMatchesStep() {
        let expr = CronExpr.step(10)
        XCTAssertTrue(expr.matches(0))
        XCTAssertFalse(expr.matches(5))
        XCTAssertTrue(expr.matches(10))
        XCTAssertFalse(expr.matches(15))
        XCTAssertTrue(expr.matches(20))
        XCTAssertTrue(expr.matches(50))
    }
    
    func testMatchesStep15() {
        let expr = CronExpr.step(15)
        XCTAssertTrue(expr.matches(0))
        XCTAssertTrue(expr.matches(15))
        XCTAssertTrue(expr.matches(30))
        XCTAssertTrue(expr.matches(45))
        XCTAssertFalse(expr.matches(10))
        XCTAssertFalse(expr.matches(20))
    }
    
    func testMatchesStep2ForHours() {
        let expr = CronExpr.step(2)
        XCTAssertTrue(expr.matches(0))
        XCTAssertFalse(expr.matches(1))
        XCTAssertTrue(expr.matches(2))
        XCTAssertFalse(expr.matches(3))
        XCTAssertTrue(expr.matches(22))
        XCTAssertFalse(expr.matches(23))
    }
}
