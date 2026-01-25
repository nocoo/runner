use serde::{Deserialize, Serialize};
use serde_json::Value;

/// Task type: simple (shell command) or agent (opencode)
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum TaskType {
    Simple,
    Agent,
    Manual,
}

/// Task definition from tasks.json
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Task {
    pub id: String,
    #[serde(rename = "type")]
    pub task_type: TaskType,
    pub description: String,
    pub timeout: u32,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub command: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub prompt: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub workdir: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub model: Option<String>,
}

/// Schedule rule from schedules.json
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Schedule {
    pub task: String,
    pub hour: Value,   // Can be number or string like "*", "*/2", "9-17"
    pub minute: Value, // Can be number or string like "*", "*/10", "0,15,30,45"
    pub weekday: Value, // Can be number or string like "*", "1-5"
}

/// Full configuration (tasks + schedules)
#[derive(Debug, Clone)]
pub struct Config {
    pub tasks: Vec<Task>,
    pub schedules: Vec<Schedule>,
}

/// System state from state.json
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SystemState {
    pub version: String,
    pub last_run: Option<LastRun>,
    pub next_scheduled: Option<Value>,
    pub total_runs_today: u32,
    pub success_rate_today: f64,
}

/// Last run info
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LastRun {
    pub id: String,
    pub task: String,
    pub exit_code: i32,
    pub finished_at: String,
}

/// Run summary in index.json
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RunSummary {
    pub id: String,
    pub task: String,
    pub exit_code: Option<i32>, // null = running
    pub started_at: String,
    pub finished_at: Option<String>, // null = running
    #[serde(skip_serializing_if = "Option::is_none")]
    pub pid: Option<u32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub started_at_epoch: Option<i64>,
}

/// Runs index from index.json
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RunsIndex {
    pub runs: Vec<RunSummary>,
    pub total: usize,
    pub updated_at: String,
}

/// Full run detail from <id>.json
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RunDetail {
    pub id: String,
    pub task: String,
    pub trigger: String,
    pub started_at: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub finished_at: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub duration_seconds: Option<u64>,
    pub exit_code: i32,
}

impl Default for SystemState {
    fn default() -> Self {
        Self {
            version: env!("CARGO_PKG_VERSION").to_string(),
            last_run: None,
            next_scheduled: None,
            total_runs_today: 0,
            success_rate_today: 0.0,
        }
    }
}

impl Default for RunsIndex {
    fn default() -> Self {
        Self {
            runs: Vec::new(),
            total: 0,
            updated_at: chrono::Utc::now().format("%Y-%m-%dT%H:%M:%SZ").to_string(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn test_task_type_serialization() {
        let task = Task {
            id: "test".to_string(),
            task_type: TaskType::Simple,
            description: "Test task".to_string(),
            timeout: 60,
            command: Some("echo hello".to_string()),
            prompt: None,
            workdir: None,
            model: None,
        };
        
        let json = serde_json::to_value(&task).unwrap();
        assert_eq!(json["type"], "simple");
    }

    #[test]
    fn test_task_deserialization() {
        let json = json!({
            "id": "test",
            "type": "agent",
            "description": "Test",
            "timeout": 300,
            "prompt": "Do something"
        });
        
        let task: Task = serde_json::from_value(json).unwrap();
        assert_eq!(task.id, "test");
        assert_eq!(task.task_type, TaskType::Agent);
        assert_eq!(task.prompt, Some("Do something".to_string()));
        assert!(task.command.is_none());
    }

    #[test]
    fn test_schedule_with_wildcards() {
        let json = json!({
            "task": "heartbeat",
            "hour": "*",
            "minute": "*/10",
            "weekday": "*"
        });
        
        let schedule: Schedule = serde_json::from_value(json).unwrap();
        assert_eq!(schedule.task, "heartbeat");
        assert_eq!(schedule.hour, json!("*"));
        assert_eq!(schedule.minute, json!("*/10"));
    }

    #[test]
    fn test_schedule_with_numbers() {
        let json = json!({
            "task": "morning",
            "hour": 9,
            "minute": 0,
            "weekday": 1
        });
        
        let schedule: Schedule = serde_json::from_value(json).unwrap();
        assert_eq!(schedule.hour, json!(9));
        assert_eq!(schedule.minute, json!(0));
        assert_eq!(schedule.weekday, json!(1));
    }

    #[test]
    fn test_run_summary_running() {
        let run = RunSummary {
            id: "abc-123".to_string(),
            task: "test".to_string(),
            exit_code: None,
            started_at: "2026-01-25T08:00:00Z".to_string(),
            finished_at: None,
            pid: Some(12345),
            started_at_epoch: Some(1769306400),
        };
        
        let json = serde_json::to_value(&run).unwrap();
        assert!(json["exit_code"].is_null());
        assert!(json["finished_at"].is_null());
        assert_eq!(json["pid"], 12345);
    }

    #[test]
    fn test_run_summary_completed() {
        let run = RunSummary {
            id: "abc-123".to_string(),
            task: "test".to_string(),
            exit_code: Some(0),
            started_at: "2026-01-25T08:00:00Z".to_string(),
            finished_at: Some("2026-01-25T08:00:10Z".to_string()),
            pid: None,
            started_at_epoch: None,
        };
        
        let json = serde_json::to_value(&run).unwrap();
        assert_eq!(json["exit_code"], 0);
        assert!(!json.get("pid").is_some_and(|v| !v.is_null())); // pid should be null or absent
    }
}
