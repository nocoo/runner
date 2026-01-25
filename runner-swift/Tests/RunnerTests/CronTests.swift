import XCTest
@testable import runner

final class CronTests: XCTestCase {
    
    // MARK: - Parsing Tests
    
    func testParseAny() {
        XCTAssertEqual(CronExpr.parse("*", min: 0, max: 59), .any)
    }
    
    func testParseExact() {
        XCTAssertEqual(CronExpr.parse(5, min: 0, max: 59), .exact(5))
        XCTAssertEqual(CronExpr.parse("5", min: 0, max: 59), .exact(5))
    }
    
    func testParseRange() {
        XCTAssertEqual(CronExpr.parse("1-5", min: 0, max: 6), .range(1, 5))
        XCTAssertEqual(CronExpr.parse("9-17", min: 0, max: 23), .range(9, 17))
    }
    
    func testParseList() {
        XCTAssertEqual(CronExpr.parse("0,15,30,45", min: 0, max: 59), .list([0, 15, 30, 45]))
    }
    
    func testParseStep() {
        XCTAssertEqual(CronExpr.parse("*/10", min: 0, max: 59), .step(10))
        XCTAssertEqual(CronExpr.parse("*/15", min: 0, max: 59), .step(15))
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
    
    func testMatchesRange() {
        let expr = CronExpr.range(9, 17)
        XCTAssertFalse(expr.matches(8))
        XCTAssertTrue(expr.matches(9))
        XCTAssertTrue(expr.matches(13))
        XCTAssertTrue(expr.matches(17))
        XCTAssertFalse(expr.matches(18))
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
}
