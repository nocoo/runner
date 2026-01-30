import Testing
@testable import RunnerLib

@Suite("Cron Expression Tests")
struct CronTests {
    
    // MARK: - Parsing Tests
    
    @Test("Parse any")
    func parseAny() {
        #expect(CronExpr.parse("*", min: 0, max: 59) == .any)
    }
    
    @Test("Parse exact from Int")
    func parseExactFromInt() {
        #expect(CronExpr.parse(5, min: 0, max: 59) == .exact(5))
        #expect(CronExpr.parse(0, min: 0, max: 23) == .exact(0))
        #expect(CronExpr.parse(23, min: 0, max: 23) == .exact(23))
    }
    
    @Test("Parse exact from String")
    func parseExactFromString() {
        #expect(CronExpr.parse("5", min: 0, max: 59) == .exact(5))
        #expect(CronExpr.parse("0", min: 0, max: 23) == .exact(0))
        #expect(CronExpr.parse("59", min: 0, max: 59) == .exact(59))
    }
    
    @Test("Parse range")
    func parseRange() {
        #expect(CronExpr.parse("1-5", min: 0, max: 6) == .range(1, 5))
        #expect(CronExpr.parse("9-17", min: 0, max: 23) == .range(9, 17))
        #expect(CronExpr.parse("0-6", min: 0, max: 6) == .range(0, 6))
    }
    
    @Test("Parse invalid range returns any")
    func parseRangeInvalid() {
        #expect(CronExpr.parse("5-1", min: 0, max: 6) == .any)
    }
    
    @Test("Parse list")
    func parseList() {
        #expect(CronExpr.parse("0,15,30,45", min: 0, max: 59) == .list([0, 15, 30, 45]))
        #expect(CronExpr.parse("1,3,5", min: 0, max: 6) == .list([1, 3, 5]))
    }
    
    @Test("Parse list with spaces")
    func parseListWithSpaces() {
        #expect(CronExpr.parse("0, 15, 30, 45", min: 0, max: 59) == .list([0, 15, 30, 45]))
    }
    
    @Test("Parse step")
    func parseStep() {
        #expect(CronExpr.parse("*/10", min: 0, max: 59) == .step(10))
        #expect(CronExpr.parse("*/15", min: 0, max: 59) == .step(15))
        #expect(CronExpr.parse("*/2", min: 0, max: 23) == .step(2))
    }
    
    @Test("Parse step zero returns any")
    func parseStepZero() {
        #expect(CronExpr.parse("*/0", min: 0, max: 59) == .any)
    }
    
    @Test("Parse invalid string returns any")
    func parseInvalidString() {
        #expect(CronExpr.parse("invalid", min: 0, max: 59) == .any)
        #expect(CronExpr.parse("", min: 0, max: 59) == .any)
    }
    
    @Test("Parse nil returns any")
    func parseNilValue() {
        #expect(CronExpr.parse(NSNull(), min: 0, max: 59) == .any)
    }
    
    // MARK: - Matching Tests
    
    @Test("Matches any")
    func matchesAny() {
        let expr = CronExpr.any
        #expect(expr.matches(0))
        #expect(expr.matches(30))
        #expect(expr.matches(59))
    }
    
    @Test("Matches exact")
    func matchesExact() {
        let expr = CronExpr.exact(15)
        #expect(!expr.matches(0))
        #expect(expr.matches(15))
        #expect(!expr.matches(30))
    }
    
    @Test("Matches exact boundary")
    func matchesExactBoundary() {
        #expect(CronExpr.exact(0).matches(0))
        #expect(CronExpr.exact(59).matches(59))
        #expect(CronExpr.exact(23).matches(23))
    }
    
    @Test("Matches range")
    func matchesRange() {
        let expr = CronExpr.range(9, 17)
        #expect(!expr.matches(8))
        #expect(expr.matches(9))
        #expect(expr.matches(13))
        #expect(expr.matches(17))
        #expect(!expr.matches(18))
    }
    
    @Test("Matches range single value")
    func matchesRangeSingleValue() {
        let expr = CronExpr.range(5, 5)
        #expect(!expr.matches(4))
        #expect(expr.matches(5))
        #expect(!expr.matches(6))
    }
    
    @Test("Matches list")
    func matchesList() {
        let expr = CronExpr.list([0, 15, 30, 45])
        #expect(expr.matches(0))
        #expect(!expr.matches(10))
        #expect(expr.matches(15))
        #expect(expr.matches(30))
        #expect(expr.matches(45))
        #expect(!expr.matches(50))
    }
    
    @Test("Matches empty list")
    func matchesListEmpty() {
        let expr = CronExpr.list([])
        #expect(!expr.matches(0))
        #expect(!expr.matches(30))
    }
    
    @Test("Matches step")
    func matchesStep() {
        let expr = CronExpr.step(10)
        #expect(expr.matches(0))
        #expect(!expr.matches(5))
        #expect(expr.matches(10))
        #expect(!expr.matches(15))
        #expect(expr.matches(20))
        #expect(expr.matches(50))
    }
    
    @Test("Matches step 15")
    func matchesStep15() {
        let expr = CronExpr.step(15)
        #expect(expr.matches(0))
        #expect(expr.matches(15))
        #expect(expr.matches(30))
        #expect(expr.matches(45))
        #expect(!expr.matches(10))
        #expect(!expr.matches(20))
    }
    
    @Test("Matches step 2 for hours")
    func matchesStep2ForHours() {
        let expr = CronExpr.step(2)
        #expect(expr.matches(0))
        #expect(!expr.matches(1))
        #expect(expr.matches(2))
        #expect(!expr.matches(3))
        #expect(expr.matches(22))
        #expect(!expr.matches(23))
    }
}
