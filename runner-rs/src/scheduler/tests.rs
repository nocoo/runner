// Integration tests for scheduler module
// These tests mirror the existing bats tests

use super::*;
use crate::config::{Schedule, Task, TaskType};
use serde_json::json;

fn make_schedule(task: &str, hour: serde_json::Value, minute: serde_json::Value, weekday: serde_json::Value) -> Schedule {
    Schedule {
        task: task.to_string(),
        hour,
        minute,
        weekday,
    }
}

fn make_agent_task(id: &str) -> Task {
    Task {
        id: id.to_string(),
        task_type: TaskType::Agent,
        description: format!("{} task", id),
        timeout: 300,
        command: None,
        prompt: Some("Test prompt".to_string()),
        workdir: None,
        model: None,
    }
}

/// Tests from routing.bats
mod routing_tests {
    use super::*;

    #[test]
    fn test_exact_hour_and_minute_match() {
        // @test "exact hour and minute match"
        let schedule = make_schedule("morning_briefing", json!(9), json!(0), json!("*"));
        assert!(Scheduler::matches_schedule(&schedule, 9, 0, 1));
    }

    #[test]
    fn test_exact_match_fails_when_hour_differs() {
        let schedule = make_schedule("morning_briefing", json!(9), json!(0), json!("*"));
        assert!(!Scheduler::matches_schedule(&schedule, 10, 0, 1));
    }

    #[test]
    fn test_exact_match_fails_when_minute_differs() {
        let schedule = make_schedule("morning_briefing", json!(9), json!(0), json!("*"));
        assert!(!Scheduler::matches_schedule(&schedule, 9, 1, 1));
    }

    #[test]
    fn test_hour_wildcard_matches_any_hour() {
        let schedule = make_schedule("heartbeat", json!("*"), json!(10), json!("*"));
        assert!(Scheduler::matches_schedule(&schedule, 0, 10, 1));
        assert!(Scheduler::matches_schedule(&schedule, 12, 10, 1));
        assert!(Scheduler::matches_schedule(&schedule, 23, 10, 1));
    }

    #[test]
    fn test_minute_wildcard_matches_any_minute() {
        let schedule = make_schedule("task", json!(9), json!("*"), json!("*"));
        assert!(Scheduler::matches_schedule(&schedule, 9, 0, 1));
        assert!(Scheduler::matches_schedule(&schedule, 9, 30, 1));
        assert!(Scheduler::matches_schedule(&schedule, 9, 59, 1));
    }

    #[test]
    fn test_weekday_wildcard_matches_any_day() {
        let schedule = make_schedule("task", json!(9), json!(0), json!("*"));
        for day in 0..7 {
            assert!(Scheduler::matches_schedule(&schedule, 9, 0, day));
        }
    }

    #[test]
    fn test_specific_weekday_only_matches_that_day() {
        let schedule = make_schedule("weekly", json!(20), json!(0), json!(0)); // Sunday
        assert!(Scheduler::matches_schedule(&schedule, 20, 0, 0));
    }

    #[test]
    fn test_specific_weekday_does_not_match_other_days() {
        let schedule = make_schedule("weekly", json!(20), json!(0), json!(0)); // Sunday
        assert!(!Scheduler::matches_schedule(&schedule, 20, 0, 1)); // Monday
        assert!(!Scheduler::matches_schedule(&schedule, 20, 0, 6)); // Saturday
    }

    #[test]
    fn test_minute_list_matches() {
        let schedule = make_schedule("heartbeat", json!("*"), json!("10,20,40,50"), json!("*"));
        assert!(Scheduler::matches_schedule(&schedule, 9, 10, 1));
        assert!(Scheduler::matches_schedule(&schedule, 9, 20, 1));
        assert!(Scheduler::matches_schedule(&schedule, 9, 40, 1));
        assert!(Scheduler::matches_schedule(&schedule, 9, 50, 1));
        assert!(!Scheduler::matches_schedule(&schedule, 9, 30, 1));
    }

    #[test]
    fn test_hour_range_matches() {
        let schedule = make_schedule("work", json!("9-17"), json!(0), json!("*"));
        assert!(!Scheduler::matches_schedule(&schedule, 8, 0, 1));
        assert!(Scheduler::matches_schedule(&schedule, 9, 0, 1));
        assert!(Scheduler::matches_schedule(&schedule, 13, 0, 1));
        assert!(Scheduler::matches_schedule(&schedule, 17, 0, 1));
        assert!(!Scheduler::matches_schedule(&schedule, 18, 0, 1));
    }

    #[test]
    fn test_minute_step_10() {
        let schedule = make_schedule("task", json!("*"), json!("*/10"), json!("*"));
        assert!(Scheduler::matches_schedule(&schedule, 9, 0, 1));
        assert!(Scheduler::matches_schedule(&schedule, 9, 10, 1));
        assert!(Scheduler::matches_schedule(&schedule, 9, 50, 1));
        assert!(!Scheduler::matches_schedule(&schedule, 9, 5, 1));
    }

    #[test]
    fn test_minute_step_15() {
        let schedule = make_schedule("task", json!("*"), json!("*/15"), json!("*"));
        assert!(Scheduler::matches_schedule(&schedule, 9, 0, 1));
        assert!(Scheduler::matches_schedule(&schedule, 9, 15, 1));
        assert!(Scheduler::matches_schedule(&schedule, 9, 30, 1));
        assert!(Scheduler::matches_schedule(&schedule, 9, 45, 1));
    }

    #[test]
    fn test_hour_step_2() {
        let schedule = make_schedule("task", json!("*/2"), json!(0), json!("*"));
        assert!(Scheduler::matches_schedule(&schedule, 0, 0, 1));
        assert!(Scheduler::matches_schedule(&schedule, 2, 0, 1));
        assert!(Scheduler::matches_schedule(&schedule, 22, 0, 1));
        assert!(!Scheduler::matches_schedule(&schedule, 1, 0, 1));
        assert!(!Scheduler::matches_schedule(&schedule, 3, 0, 1));
    }

    #[test]
    fn test_midnight() {
        let schedule = make_schedule("midnight", json!(0), json!(0), json!("*"));
        assert!(Scheduler::matches_schedule(&schedule, 0, 0, 1));
    }

    #[test]
    fn test_last_minute_of_day() {
        let schedule = make_schedule("late", json!(23), json!(59), json!("*"));
        assert!(Scheduler::matches_schedule(&schedule, 23, 59, 1));
    }

    #[test]
    fn test_weekday_range() {
        let schedule = make_schedule("workday", json!(9), json!(0), json!("1-5")); // Mon-Fri
        assert!(!Scheduler::matches_schedule(&schedule, 9, 0, 0)); // Sunday
        assert!(Scheduler::matches_schedule(&schedule, 9, 0, 1)); // Monday
        assert!(Scheduler::matches_schedule(&schedule, 9, 0, 5)); // Friday
        assert!(!Scheduler::matches_schedule(&schedule, 9, 0, 6)); // Saturday
    }
}
