use crate::config::{Schedule, Task};
use super::cron::CronExpr;
use chrono::{Datelike, Timelike};

/// Scheduler for matching tasks to current time
pub struct Scheduler;

impl Scheduler {
    /// Find all tasks that should run at the given time
    pub fn find_scheduled_tasks<'a>(
        schedules: &'a [Schedule],
        tasks: &'a [Task],
        hour: u32,
        minute: u32,
        weekday: u32, // 0 = Sunday, 6 = Saturday
    ) -> Vec<&'a str> {
        let mut matched_tasks = Vec::new();
        
        for schedule in schedules {
            if Self::matches_schedule(schedule, hour, minute, weekday) {
                // Verify task exists
                if tasks.iter().any(|t| t.id == schedule.task) {
                    matched_tasks.push(schedule.task.as_str());
                }
            }
        }
        
        // Deduplicate (same task may match multiple schedules)
        matched_tasks.sort();
        matched_tasks.dedup();
        
        matched_tasks
    }
    
    /// Check if current time matches a schedule
    pub fn matches_schedule(schedule: &Schedule, hour: u32, minute: u32, weekday: u32) -> bool {
        let hour_expr = Self::parse_field(&schedule.hour, 0, 23);
        let minute_expr = Self::parse_field(&schedule.minute, 0, 59);
        let weekday_expr = Self::parse_field(&schedule.weekday, 0, 6);
        
        hour_expr.matches(hour) && minute_expr.matches(minute) && weekday_expr.matches(weekday)
    }
    
    /// Parse a schedule field (can be number or string)
    fn parse_field(value: &serde_json::Value, min: u32, max: u32) -> CronExpr {
        match value {
            serde_json::Value::Number(n) => {
                if let Some(v) = n.as_u64() {
                    CronExpr::Exact(v as u32)
                } else {
                    CronExpr::Any
                }
            }
            serde_json::Value::String(s) => {
                CronExpr::parse(s, min, max).unwrap_or(CronExpr::Any)
            }
            _ => CronExpr::Any,
        }
    }
    
    /// Get current time components from a chrono DateTime
    pub fn get_time_components<Tz: chrono::TimeZone>(dt: &chrono::DateTime<Tz>) -> (u32, u32, u32) {
        let hour = dt.hour();
        let minute = dt.minute();
        let weekday = dt.weekday().num_days_from_sunday(); // 0 = Sunday
        (hour, minute, weekday)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::config::TaskType;
    use serde_json::json;

    fn make_schedule(task: &str, hour: serde_json::Value, minute: serde_json::Value, weekday: serde_json::Value) -> Schedule {
        Schedule {
            task: task.to_string(),
            hour,
            minute,
            weekday,
        }
    }

    fn make_task(id: &str) -> Task {
        Task {
            id: id.to_string(),
            task_type: TaskType::Simple,
            description: "Test".to_string(),
            timeout: 60,
            command: Some("echo test".to_string()),
            prompt: None,
            workdir: None,
            model: None,
        }
    }

    #[test]
    fn test_exact_hour_and_minute_match() {
        let schedule = make_schedule("task1", json!(9), json!(0), json!("*"));
        assert!(Scheduler::matches_schedule(&schedule, 9, 0, 1));
        assert!(!Scheduler::matches_schedule(&schedule, 9, 1, 1));
        assert!(!Scheduler::matches_schedule(&schedule, 10, 0, 1));
    }

    #[test]
    fn test_wildcard_hour() {
        let schedule = make_schedule("task1", json!("*"), json!(30), json!("*"));
        assert!(Scheduler::matches_schedule(&schedule, 0, 30, 1));
        assert!(Scheduler::matches_schedule(&schedule, 12, 30, 1));
        assert!(Scheduler::matches_schedule(&schedule, 23, 30, 1));
        assert!(!Scheduler::matches_schedule(&schedule, 12, 0, 1));
    }

    #[test]
    fn test_wildcard_minute() {
        let schedule = make_schedule("task1", json!(9), json!("*"), json!("*"));
        assert!(Scheduler::matches_schedule(&schedule, 9, 0, 1));
        assert!(Scheduler::matches_schedule(&schedule, 9, 30, 1));
        assert!(Scheduler::matches_schedule(&schedule, 9, 59, 1));
        assert!(!Scheduler::matches_schedule(&schedule, 10, 0, 1));
    }

    #[test]
    fn test_specific_weekday() {
        let schedule = make_schedule("task1", json!(9), json!(0), json!(1)); // Monday
        assert!(Scheduler::matches_schedule(&schedule, 9, 0, 1));
        assert!(!Scheduler::matches_schedule(&schedule, 9, 0, 0)); // Sunday
        assert!(!Scheduler::matches_schedule(&schedule, 9, 0, 2)); // Tuesday
    }

    #[test]
    fn test_weekday_range() {
        let schedule = make_schedule("task1", json!(9), json!(0), json!("1-5")); // Mon-Fri
        assert!(!Scheduler::matches_schedule(&schedule, 9, 0, 0)); // Sunday
        assert!(Scheduler::matches_schedule(&schedule, 9, 0, 1)); // Monday
        assert!(Scheduler::matches_schedule(&schedule, 9, 0, 3)); // Wednesday
        assert!(Scheduler::matches_schedule(&schedule, 9, 0, 5)); // Friday
        assert!(!Scheduler::matches_schedule(&schedule, 9, 0, 6)); // Saturday
    }

    #[test]
    fn test_minute_list() {
        let schedule = make_schedule("task1", json!("*"), json!("0,15,30,45"), json!("*"));
        assert!(Scheduler::matches_schedule(&schedule, 9, 0, 1));
        assert!(Scheduler::matches_schedule(&schedule, 9, 15, 1));
        assert!(Scheduler::matches_schedule(&schedule, 9, 30, 1));
        assert!(Scheduler::matches_schedule(&schedule, 9, 45, 1));
        assert!(!Scheduler::matches_schedule(&schedule, 9, 10, 1));
        assert!(!Scheduler::matches_schedule(&schedule, 9, 20, 1));
    }

    #[test]
    fn test_minute_step() {
        let schedule = make_schedule("task1", json!("*"), json!("*/10"), json!("*"));
        assert!(Scheduler::matches_schedule(&schedule, 9, 0, 1));
        assert!(Scheduler::matches_schedule(&schedule, 9, 10, 1));
        assert!(Scheduler::matches_schedule(&schedule, 9, 20, 1));
        assert!(Scheduler::matches_schedule(&schedule, 9, 50, 1));
        assert!(!Scheduler::matches_schedule(&schedule, 9, 5, 1));
        assert!(!Scheduler::matches_schedule(&schedule, 9, 15, 1));
    }

    #[test]
    fn test_hour_step() {
        let schedule = make_schedule("task1", json!("*/2"), json!(0), json!("*"));
        assert!(Scheduler::matches_schedule(&schedule, 0, 0, 1));
        assert!(Scheduler::matches_schedule(&schedule, 2, 0, 1));
        assert!(Scheduler::matches_schedule(&schedule, 4, 0, 1));
        assert!(!Scheduler::matches_schedule(&schedule, 1, 0, 1));
        assert!(!Scheduler::matches_schedule(&schedule, 3, 0, 1));
    }

    #[test]
    fn test_find_scheduled_tasks() {
        let tasks = vec![
            make_task("task1"),
            make_task("task2"),
            make_task("task3"),
        ];
        let schedules = vec![
            make_schedule("task1", json!(9), json!(0), json!("*")),
            make_schedule("task2", json!(9), json!(0), json!("*")),
            make_schedule("task3", json!(10), json!(0), json!("*")),
        ];
        
        let matched = Scheduler::find_scheduled_tasks(&schedules, &tasks, 9, 0, 1);
        assert_eq!(matched, vec!["task1", "task2"]);
        
        let matched = Scheduler::find_scheduled_tasks(&schedules, &tasks, 10, 0, 1);
        assert_eq!(matched, vec!["task3"]);
        
        let matched = Scheduler::find_scheduled_tasks(&schedules, &tasks, 11, 0, 1);
        assert!(matched.is_empty());
    }

    #[test]
    fn test_find_scheduled_tasks_deduplicates() {
        let tasks = vec![make_task("task1")];
        let schedules = vec![
            make_schedule("task1", json!("*"), json!(0), json!("*")),
            make_schedule("task1", json!("*"), json!(0), json!("*")), // Duplicate
        ];
        
        let matched = Scheduler::find_scheduled_tasks(&schedules, &tasks, 9, 0, 1);
        assert_eq!(matched, vec!["task1"]); // Should only appear once
    }

    #[test]
    fn test_find_scheduled_tasks_ignores_unknown_task() {
        let tasks = vec![make_task("task1")];
        let schedules = vec![
            make_schedule("task1", json!(9), json!(0), json!("*")),
            make_schedule("unknown", json!(9), json!(0), json!("*")), // Task doesn't exist
        ];
        
        let matched = Scheduler::find_scheduled_tasks(&schedules, &tasks, 9, 0, 1);
        assert_eq!(matched, vec!["task1"]);
    }

    #[test]
    fn test_midnight() {
        let schedule = make_schedule("task1", json!(0), json!(0), json!("*"));
        assert!(Scheduler::matches_schedule(&schedule, 0, 0, 1));
    }

    #[test]
    fn test_last_minute_of_day() {
        let schedule = make_schedule("task1", json!(23), json!(59), json!("*"));
        assert!(Scheduler::matches_schedule(&schedule, 23, 59, 1));
    }
}
