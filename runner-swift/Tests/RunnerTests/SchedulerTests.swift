import Testing
@testable import RunnerLib

@Suite("Scheduler Tests")
struct SchedulerTests {
    
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
            executor: .shell,
            description: "Test task",
            timeout: 60,
            command: "echo test",
            prompt: nil,
            workdir: nil
        )
    }
    
    // MARK: - Schedule Matching Tests
    
    @Test("Exact hour and minute match")
    func exactHourAndMinuteMatch() {
        let schedule = makeSchedule("task1", hour: 9, minute: 0, weekday: "*")
        #expect(Scheduler.matchesSchedule(schedule, hour: 9, minute: 0, weekday: 1))
        #expect(!Scheduler.matchesSchedule(schedule, hour: 9, minute: 1, weekday: 1))
        #expect(!Scheduler.matchesSchedule(schedule, hour: 10, minute: 0, weekday: 1))
    }
    
    @Test("Wildcard hour")
    func wildcardHour() {
        let schedule = makeSchedule("task1", hour: "*", minute: 30, weekday: "*")
        #expect(Scheduler.matchesSchedule(schedule, hour: 0, minute: 30, weekday: 1))
        #expect(Scheduler.matchesSchedule(schedule, hour: 12, minute: 30, weekday: 1))
        #expect(Scheduler.matchesSchedule(schedule, hour: 23, minute: 30, weekday: 1))
        #expect(!Scheduler.matchesSchedule(schedule, hour: 12, minute: 0, weekday: 1))
    }
    
    @Test("Wildcard minute")
    func wildcardMinute() {
        let schedule = makeSchedule("task1", hour: 9, minute: "*", weekday: "*")
        #expect(Scheduler.matchesSchedule(schedule, hour: 9, minute: 0, weekday: 1))
        #expect(Scheduler.matchesSchedule(schedule, hour: 9, minute: 30, weekday: 1))
        #expect(Scheduler.matchesSchedule(schedule, hour: 9, minute: 59, weekday: 1))
        #expect(!Scheduler.matchesSchedule(schedule, hour: 10, minute: 0, weekday: 1))
    }
    
    @Test("Specific weekday")
    func specificWeekday() {
        let schedule = makeSchedule("task1", hour: 9, minute: 0, weekday: 1) // Monday
        #expect(Scheduler.matchesSchedule(schedule, hour: 9, minute: 0, weekday: 1))
        #expect(!Scheduler.matchesSchedule(schedule, hour: 9, minute: 0, weekday: 0))
        #expect(!Scheduler.matchesSchedule(schedule, hour: 9, minute: 0, weekday: 2))
    }
    
    @Test("Weekday range")
    func weekdayRange() {
        let schedule = makeSchedule("task1", hour: 9, minute: 0, weekday: "1-5") // Mon-Fri
        #expect(!Scheduler.matchesSchedule(schedule, hour: 9, minute: 0, weekday: 0)) // Sun
        #expect(Scheduler.matchesSchedule(schedule, hour: 9, minute: 0, weekday: 1))  // Mon
        #expect(Scheduler.matchesSchedule(schedule, hour: 9, minute: 0, weekday: 3))  // Wed
        #expect(Scheduler.matchesSchedule(schedule, hour: 9, minute: 0, weekday: 5))  // Fri
        #expect(!Scheduler.matchesSchedule(schedule, hour: 9, minute: 0, weekday: 6)) // Sat
    }
    
    @Test("Minute list")
    func minuteList() {
        let schedule = makeSchedule("task1", hour: "*", minute: "0,15,30,45", weekday: "*")
        #expect(Scheduler.matchesSchedule(schedule, hour: 9, minute: 0, weekday: 1))
        #expect(Scheduler.matchesSchedule(schedule, hour: 9, minute: 15, weekday: 1))
        #expect(Scheduler.matchesSchedule(schedule, hour: 9, minute: 30, weekday: 1))
        #expect(Scheduler.matchesSchedule(schedule, hour: 9, minute: 45, weekday: 1))
        #expect(!Scheduler.matchesSchedule(schedule, hour: 9, minute: 10, weekday: 1))
    }
    
    @Test("Minute step")
    func minuteStep() {
        let schedule = makeSchedule("task1", hour: "*", minute: "*/10", weekday: "*")
        #expect(Scheduler.matchesSchedule(schedule, hour: 9, minute: 0, weekday: 1))
        #expect(Scheduler.matchesSchedule(schedule, hour: 9, minute: 10, weekday: 1))
        #expect(Scheduler.matchesSchedule(schedule, hour: 9, minute: 20, weekday: 1))
        #expect(!Scheduler.matchesSchedule(schedule, hour: 9, minute: 5, weekday: 1))
    }
    
    @Test("Hour step")
    func hourStep() {
        let schedule = makeSchedule("task1", hour: "*/2", minute: 0, weekday: "*")
        #expect(Scheduler.matchesSchedule(schedule, hour: 0, minute: 0, weekday: 1))
        #expect(Scheduler.matchesSchedule(schedule, hour: 2, minute: 0, weekday: 1))
        #expect(Scheduler.matchesSchedule(schedule, hour: 4, minute: 0, weekday: 1))
        #expect(!Scheduler.matchesSchedule(schedule, hour: 1, minute: 0, weekday: 1))
        #expect(!Scheduler.matchesSchedule(schedule, hour: 3, minute: 0, weekday: 1))
    }
    
    @Test("Midnight")
    func midnight() {
        let schedule = makeSchedule("task1", hour: 0, minute: 0, weekday: "*")
        #expect(Scheduler.matchesSchedule(schedule, hour: 0, minute: 0, weekday: 1))
    }
    
    @Test("Last minute of day")
    func lastMinuteOfDay() {
        let schedule = makeSchedule("task1", hour: 23, minute: 59, weekday: "*")
        #expect(Scheduler.matchesSchedule(schedule, hour: 23, minute: 59, weekday: 1))
    }
    
    // MARK: - Find Scheduled Tasks Tests
    
    @Test("Find scheduled tasks")
    func findScheduledTasks() {
        let tasks = [makeTask("task1"), makeTask("task2"), makeTask("task3")]
        let schedules = [
            makeSchedule("task1", hour: 9, minute: 0, weekday: "*"),
            makeSchedule("task2", hour: 9, minute: 0, weekday: "*"),
            makeSchedule("task3", hour: 10, minute: 0, weekday: "*"),
        ]
        
        let matched = Scheduler.findScheduledTasks(schedules: schedules, tasks: tasks, hour: 9, minute: 0, weekday: 1)
        #expect(Set(matched) == Set(["task1", "task2"]))
        
        let matched2 = Scheduler.findScheduledTasks(schedules: schedules, tasks: tasks, hour: 10, minute: 0, weekday: 1)
        #expect(matched2 == ["task3"])
        
        let matched3 = Scheduler.findScheduledTasks(schedules: schedules, tasks: tasks, hour: 11, minute: 0, weekday: 1)
        #expect(matched3.isEmpty)
    }
    
    @Test("Find scheduled tasks deduplicates")
    func findScheduledTasksDeduplicates() {
        let tasks = [makeTask("task1")]
        let schedules = [
            makeSchedule("task1", hour: "*", minute: 0, weekday: "*"),
            makeSchedule("task1", hour: "*", minute: 0, weekday: "*"), // Duplicate
        ]
        
        let matched = Scheduler.findScheduledTasks(schedules: schedules, tasks: tasks, hour: 9, minute: 0, weekday: 1)
        #expect(matched == ["task1"]) // Should only appear once
    }
    
    @Test("Find scheduled tasks ignores unknown task")
    func findScheduledTasksIgnoresUnknownTask() {
        let tasks = [makeTask("task1")]
        let schedules = [
            makeSchedule("task1", hour: 9, minute: 0, weekday: "*"),
            makeSchedule("unknown", hour: 9, minute: 0, weekday: "*"), // Unknown task
        ]
        
        let matched = Scheduler.findScheduledTasks(schedules: schedules, tasks: tasks, hour: 9, minute: 0, weekday: 1)
        #expect(matched == ["task1"])
    }
    
    @Test("Find scheduled tasks empty schedules")
    func findScheduledTasksEmptySchedules() {
        let tasks = [makeTask("task1")]
        let schedules: [Schedule] = []
        
        let matched = Scheduler.findScheduledTasks(schedules: schedules, tasks: tasks, hour: 9, minute: 0, weekday: 1)
        #expect(matched.isEmpty)
    }
    
    @Test("Find scheduled tasks empty tasks")
    func findScheduledTasksEmptyTasks() {
        let tasks: [Task] = []
        let schedules = [makeSchedule("task1", hour: 9, minute: 0, weekday: "*")]
        
        let matched = Scheduler.findScheduledTasks(schedules: schedules, tasks: tasks, hour: 9, minute: 0, weekday: 1)
        #expect(matched.isEmpty)
    }
    
    @Test("Find scheduled tasks multiple matching schedules")
    func findScheduledTasksMultipleMatchingSchedules() {
        let tasks = [makeTask("task1")]
        let schedules = [
            makeSchedule("task1", hour: "*", minute: 0, weekday: "*"),  // Matches every hour at :00
            makeSchedule("task1", hour: "*", minute: 30, weekday: "*"), // Matches every hour at :30
        ]
        
        let matchedAt0 = Scheduler.findScheduledTasks(schedules: schedules, tasks: tasks, hour: 9, minute: 0, weekday: 1)
        #expect(matchedAt0 == ["task1"])
        
        let matchedAt30 = Scheduler.findScheduledTasks(schedules: schedules, tasks: tasks, hour: 9, minute: 30, weekday: 1)
        #expect(matchedAt30 == ["task1"])
        
        let matchedAt15 = Scheduler.findScheduledTasks(schedules: schedules, tasks: tasks, hour: 9, minute: 15, weekday: 1)
        #expect(matchedAt15.isEmpty)
    }
    
    @Test("Find scheduled tasks all weekdays")
    func findScheduledTasksAllWeekdays() {
        let tasks = [makeTask("task1")]
        let schedule = makeSchedule("task1", hour: 9, minute: 0, weekday: "*")
        let schedules = [schedule]
        
        // Should match all weekdays
        for weekday in 0..<7 {
            let matched = Scheduler.findScheduledTasks(schedules: schedules, tasks: tasks, hour: 9, minute: 0, weekday: weekday)
            #expect(matched == ["task1"], "Should match weekday \(weekday)")
        }
    }
    
    @Test("Find scheduled tasks sorted")
    func findScheduledTasksSorted() {
        let tasks = [makeTask("zebra"), makeTask("alpha"), makeTask("beta")]
        let schedules = [
            makeSchedule("zebra", hour: 9, minute: 0, weekday: "*"),
            makeSchedule("alpha", hour: 9, minute: 0, weekday: "*"),
            makeSchedule("beta", hour: 9, minute: 0, weekday: "*"),
        ]
        
        let matched = Scheduler.findScheduledTasks(schedules: schedules, tasks: tasks, hour: 9, minute: 0, weekday: 1)
        #expect(matched == ["alpha", "beta", "zebra"]) // Sorted alphabetically
    }
}
