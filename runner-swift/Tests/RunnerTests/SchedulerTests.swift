import XCTest
@testable import runner

final class SchedulerTests: XCTestCase {
    
    func makeSchedule(_ task: String, hour: Any, minute: Any, weekday: Any) -> Schedule {
        Schedule(
            task: task,
            hour: AnyCodable(hour),
            minute: AnyCodable(minute),
            weekday: AnyCodable(weekday)
        )
    }
    
    func makeTask(_ id: String) -> Task {
        Task(
            id: id,
            type: .simple,
            description: "Test",
            timeout: 60,
            command: "echo test",
            prompt: nil,
            workdir: nil,
            model: nil
        )
    }
    
    // MARK: - Schedule Matching Tests
    
    func testExactHourAndMinuteMatch() {
        let schedule = makeSchedule("task1", hour: 9, minute: 0, weekday: "*")
        XCTAssertTrue(Scheduler.matchesSchedule(schedule, hour: 9, minute: 0, weekday: 1))
        XCTAssertFalse(Scheduler.matchesSchedule(schedule, hour: 9, minute: 1, weekday: 1))
        XCTAssertFalse(Scheduler.matchesSchedule(schedule, hour: 10, minute: 0, weekday: 1))
    }
    
    func testWildcardHour() {
        let schedule = makeSchedule("task1", hour: "*", minute: 30, weekday: "*")
        XCTAssertTrue(Scheduler.matchesSchedule(schedule, hour: 0, minute: 30, weekday: 1))
        XCTAssertTrue(Scheduler.matchesSchedule(schedule, hour: 12, minute: 30, weekday: 1))
        XCTAssertTrue(Scheduler.matchesSchedule(schedule, hour: 23, minute: 30, weekday: 1))
        XCTAssertFalse(Scheduler.matchesSchedule(schedule, hour: 12, minute: 0, weekday: 1))
    }
    
    func testWildcardMinute() {
        let schedule = makeSchedule("task1", hour: 9, minute: "*", weekday: "*")
        XCTAssertTrue(Scheduler.matchesSchedule(schedule, hour: 9, minute: 0, weekday: 1))
        XCTAssertTrue(Scheduler.matchesSchedule(schedule, hour: 9, minute: 30, weekday: 1))
        XCTAssertTrue(Scheduler.matchesSchedule(schedule, hour: 9, minute: 59, weekday: 1))
        XCTAssertFalse(Scheduler.matchesSchedule(schedule, hour: 10, minute: 0, weekday: 1))
    }
    
    func testSpecificWeekday() {
        let schedule = makeSchedule("task1", hour: 9, minute: 0, weekday: 1) // Monday
        XCTAssertTrue(Scheduler.matchesSchedule(schedule, hour: 9, minute: 0, weekday: 1))
        XCTAssertFalse(Scheduler.matchesSchedule(schedule, hour: 9, minute: 0, weekday: 0))
        XCTAssertFalse(Scheduler.matchesSchedule(schedule, hour: 9, minute: 0, weekday: 2))
    }
    
    func testWeekdayRange() {
        let schedule = makeSchedule("task1", hour: 9, minute: 0, weekday: "1-5") // Mon-Fri
        XCTAssertFalse(Scheduler.matchesSchedule(schedule, hour: 9, minute: 0, weekday: 0)) // Sun
        XCTAssertTrue(Scheduler.matchesSchedule(schedule, hour: 9, minute: 0, weekday: 1))  // Mon
        XCTAssertTrue(Scheduler.matchesSchedule(schedule, hour: 9, minute: 0, weekday: 3))  // Wed
        XCTAssertTrue(Scheduler.matchesSchedule(schedule, hour: 9, minute: 0, weekday: 5))  // Fri
        XCTAssertFalse(Scheduler.matchesSchedule(schedule, hour: 9, minute: 0, weekday: 6)) // Sat
    }
    
    func testMinuteList() {
        let schedule = makeSchedule("task1", hour: "*", minute: "0,15,30,45", weekday: "*")
        XCTAssertTrue(Scheduler.matchesSchedule(schedule, hour: 9, minute: 0, weekday: 1))
        XCTAssertTrue(Scheduler.matchesSchedule(schedule, hour: 9, minute: 15, weekday: 1))
        XCTAssertTrue(Scheduler.matchesSchedule(schedule, hour: 9, minute: 30, weekday: 1))
        XCTAssertTrue(Scheduler.matchesSchedule(schedule, hour: 9, minute: 45, weekday: 1))
        XCTAssertFalse(Scheduler.matchesSchedule(schedule, hour: 9, minute: 10, weekday: 1))
    }
    
    func testMinuteStep() {
        let schedule = makeSchedule("task1", hour: "*", minute: "*/10", weekday: "*")
        XCTAssertTrue(Scheduler.matchesSchedule(schedule, hour: 9, minute: 0, weekday: 1))
        XCTAssertTrue(Scheduler.matchesSchedule(schedule, hour: 9, minute: 10, weekday: 1))
        XCTAssertTrue(Scheduler.matchesSchedule(schedule, hour: 9, minute: 20, weekday: 1))
        XCTAssertFalse(Scheduler.matchesSchedule(schedule, hour: 9, minute: 5, weekday: 1))
    }
    
    func testHourStep() {
        let schedule = makeSchedule("task1", hour: "*/2", minute: 0, weekday: "*")
        XCTAssertTrue(Scheduler.matchesSchedule(schedule, hour: 0, minute: 0, weekday: 1))
        XCTAssertTrue(Scheduler.matchesSchedule(schedule, hour: 2, minute: 0, weekday: 1))
        XCTAssertTrue(Scheduler.matchesSchedule(schedule, hour: 4, minute: 0, weekday: 1))
        XCTAssertFalse(Scheduler.matchesSchedule(schedule, hour: 1, minute: 0, weekday: 1))
        XCTAssertFalse(Scheduler.matchesSchedule(schedule, hour: 3, minute: 0, weekday: 1))
    }
    
    func testMidnight() {
        let schedule = makeSchedule("task1", hour: 0, minute: 0, weekday: "*")
        XCTAssertTrue(Scheduler.matchesSchedule(schedule, hour: 0, minute: 0, weekday: 1))
    }
    
    func testLastMinuteOfDay() {
        let schedule = makeSchedule("task1", hour: 23, minute: 59, weekday: "*")
        XCTAssertTrue(Scheduler.matchesSchedule(schedule, hour: 23, minute: 59, weekday: 1))
    }
    
    // MARK: - Find Scheduled Tasks Tests
    
    func testFindScheduledTasks() {
        let tasks = [makeTask("task1"), makeTask("task2"), makeTask("task3")]
        let schedules = [
            makeSchedule("task1", hour: 9, minute: 0, weekday: "*"),
            makeSchedule("task2", hour: 9, minute: 0, weekday: "*"),
            makeSchedule("task3", hour: 10, minute: 0, weekday: "*"),
        ]
        
        let matched = Scheduler.findScheduledTasks(schedules: schedules, tasks: tasks, hour: 9, minute: 0, weekday: 1)
        XCTAssertEqual(Set(matched), Set(["task1", "task2"]))
        
        let matched2 = Scheduler.findScheduledTasks(schedules: schedules, tasks: tasks, hour: 10, minute: 0, weekday: 1)
        XCTAssertEqual(matched2, ["task3"])
        
        let matched3 = Scheduler.findScheduledTasks(schedules: schedules, tasks: tasks, hour: 11, minute: 0, weekday: 1)
        XCTAssertTrue(matched3.isEmpty)
    }
    
    func testFindScheduledTasksDeduplicates() {
        let tasks = [makeTask("task1")]
        let schedules = [
            makeSchedule("task1", hour: "*", minute: 0, weekday: "*"),
            makeSchedule("task1", hour: "*", minute: 0, weekday: "*"), // Duplicate
        ]
        
        let matched = Scheduler.findScheduledTasks(schedules: schedules, tasks: tasks, hour: 9, minute: 0, weekday: 1)
        XCTAssertEqual(matched, ["task1"]) // Should only appear once
    }
    
    func testFindScheduledTasksIgnoresUnknownTask() {
        let tasks = [makeTask("task1")]
        let schedules = [
            makeSchedule("task1", hour: 9, minute: 0, weekday: "*"),
            makeSchedule("unknown", hour: 9, minute: 0, weekday: "*"),
        ]
        
        let matched = Scheduler.findScheduledTasks(schedules: schedules, tasks: tasks, hour: 9, minute: 0, weekday: 1)
        XCTAssertEqual(matched, ["task1"])
    }
}
