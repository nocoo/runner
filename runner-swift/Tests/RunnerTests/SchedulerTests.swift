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
    
    func makeTask(_ id: String, type: TaskType = .simple) -> Task {
        Task(
            id: id,
            type: type,
            description: "Test task",
            timeout: 60,
            command: type == .simple ? "echo test" : nil,
            prompt: type == .agent ? "Do something" : nil,
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
            makeSchedule("unknown", hour: 9, minute: 0, weekday: "*"), // Unknown task
        ]
        
        let matched = Scheduler.findScheduledTasks(schedules: schedules, tasks: tasks, hour: 9, minute: 0, weekday: 1)
        XCTAssertEqual(matched, ["task1"])
    }
    
    func testFindScheduledTasksEmptySchedules() {
        let tasks = [makeTask("task1")]
        let schedules: [Schedule] = []
        
        let matched = Scheduler.findScheduledTasks(schedules: schedules, tasks: tasks, hour: 9, minute: 0, weekday: 1)
        XCTAssertTrue(matched.isEmpty)
    }
    
    func testFindScheduledTasksEmptyTasks() {
        let tasks: [Task] = []
        let schedules = [makeSchedule("task1", hour: 9, minute: 0, weekday: "*")]
        
        let matched = Scheduler.findScheduledTasks(schedules: schedules, tasks: tasks, hour: 9, minute: 0, weekday: 1)
        XCTAssertTrue(matched.isEmpty)
    }
    
    func testFindScheduledTasksMultipleMatchingSchedules() {
        let tasks = [makeTask("task1")]
        let schedules = [
            makeSchedule("task1", hour: "*", minute: 0, weekday: "*"),  // Matches every hour at :00
            makeSchedule("task1", hour: "*", minute: 30, weekday: "*"), // Matches every hour at :30
        ]
        
        let matchedAt0 = Scheduler.findScheduledTasks(schedules: schedules, tasks: tasks, hour: 9, minute: 0, weekday: 1)
        XCTAssertEqual(matchedAt0, ["task1"])
        
        let matchedAt30 = Scheduler.findScheduledTasks(schedules: schedules, tasks: tasks, hour: 9, minute: 30, weekday: 1)
        XCTAssertEqual(matchedAt30, ["task1"])
        
        let matchedAt15 = Scheduler.findScheduledTasks(schedules: schedules, tasks: tasks, hour: 9, minute: 15, weekday: 1)
        XCTAssertTrue(matchedAt15.isEmpty)
    }
    
    func testFindScheduledTasksAllWeekdays() {
        let tasks = [makeTask("task1")]
        let schedule = makeSchedule("task1", hour: 9, minute: 0, weekday: "*")
        let schedules = [schedule]
        
        // Should match all weekdays
        for weekday in 0..<7 {
            let matched = Scheduler.findScheduledTasks(schedules: schedules, tasks: tasks, hour: 9, minute: 0, weekday: weekday)
            XCTAssertEqual(matched, ["task1"], "Should match weekday \(weekday)")
        }
    }
    
    func testFindScheduledTasksSorted() {
        let tasks = [makeTask("zebra"), makeTask("alpha"), makeTask("beta")]
        let schedules = [
            makeSchedule("zebra", hour: 9, minute: 0, weekday: "*"),
            makeSchedule("alpha", hour: 9, minute: 0, weekday: "*"),
            makeSchedule("beta", hour: 9, minute: 0, weekday: "*"),
        ]
        
        let matched = Scheduler.findScheduledTasks(schedules: schedules, tasks: tasks, hour: 9, minute: 0, weekday: 1)
        XCTAssertEqual(matched, ["alpha", "beta", "zebra"]) // Sorted alphabetically
    }
}
