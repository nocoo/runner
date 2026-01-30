import Foundation

/// Schedule matching logic
public struct Scheduler {
    /// Find all tasks that should run at the given time
    public static func findScheduledTasks(
        schedules: [Schedule],
        tasks: [Task],
        hour: Int,
        minute: Int,
        weekday: Int  // 0 = Sunday
    ) -> [String] {
        let taskIds = Set(tasks.map { $0.id })
        var matched = Set<String>()
        
        for schedule in schedules where matchesSchedule(schedule, hour: hour, minute: minute, weekday: weekday) {
            if taskIds.contains(schedule.task) {
                matched.insert(schedule.task)
            }
        }
        
        return Array(matched).sorted()
    }
    
    /// Check if current time matches a schedule
    public static func matchesSchedule(_ schedule: Schedule, hour: Int, minute: Int, weekday: Int) -> Bool {
        let hourExpr = CronExpr.parse(schedule.hour.value, min: 0, max: 23)
        let minuteExpr = CronExpr.parse(schedule.minute.value, min: 0, max: 59)
        let weekdayExpr = CronExpr.parse(schedule.weekday.value, min: 0, max: 6)
        
        return hourExpr.matches(hour) && minuteExpr.matches(minute) && weekdayExpr.matches(weekday)
    }
}
