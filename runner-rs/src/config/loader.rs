use std::path::Path;
use anyhow::{Context, Result};
use super::types::{Task, Schedule, Config, SystemState, RunsIndex};

/// Load configuration from JSON files
pub struct ConfigLoader;

impl ConfigLoader {
    /// Load tasks from tasks.json
    pub fn load_tasks(data_dir: &Path) -> Result<Vec<Task>> {
        let path = data_dir.join("tasks.json");
        let content = std::fs::read_to_string(&path)
            .with_context(|| format!("Failed to read {}", path.display()))?;
        let tasks: Vec<Task> = serde_json::from_str(&content)
            .with_context(|| format!("Failed to parse {}", path.display()))?;
        Ok(tasks)
    }
    
    /// Load schedules from schedules.json
    pub fn load_schedules(data_dir: &Path) -> Result<Vec<Schedule>> {
        let path = data_dir.join("schedules.json");
        let content = std::fs::read_to_string(&path)
            .with_context(|| format!("Failed to read {}", path.display()))?;
        let schedules: Vec<Schedule> = serde_json::from_str(&content)
            .with_context(|| format!("Failed to parse {}", path.display()))?;
        Ok(schedules)
    }
    
    /// Load full config (tasks + schedules)
    pub fn load_config(data_dir: &Path) -> Result<Config> {
        let tasks = Self::load_tasks(data_dir)?;
        let schedules = Self::load_schedules(data_dir)?;
        Ok(Config { tasks, schedules })
    }
    
    /// Load system state from state.json
    pub fn load_state(data_dir: &Path) -> Result<SystemState> {
        let path = data_dir.join("state.json");
        if !path.exists() {
            return Ok(SystemState::default());
        }
        let content = std::fs::read_to_string(&path)
            .with_context(|| format!("Failed to read {}", path.display()))?;
        let state: SystemState = serde_json::from_str(&content)
            .with_context(|| format!("Failed to parse {}", path.display()))?;
        Ok(state)
    }
    
    /// Load runs index from runs/index.json
    pub fn load_runs_index(data_dir: &Path) -> Result<RunsIndex> {
        let path = data_dir.join("runs/index.json");
        if !path.exists() {
            return Ok(RunsIndex::default());
        }
        let content = std::fs::read_to_string(&path)
            .with_context(|| format!("Failed to read {}", path.display()))?;
        let index: RunsIndex = serde_json::from_str(&content)
            .with_context(|| format!("Failed to parse {}", path.display()))?;
        Ok(index)
    }
    
    /// Get task by ID
    pub fn get_task<'a>(tasks: &'a [Task], id: &str) -> Option<&'a Task> {
        tasks.iter().find(|t| t.id == id)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;
    use std::fs;

    fn setup_test_dir() -> TempDir {
        let dir = TempDir::new().unwrap();
        fs::create_dir_all(dir.path().join("runs")).unwrap();
        dir
    }

    #[test]
    fn test_load_tasks() {
        let dir = setup_test_dir();
        let tasks_json = r#"[
            {
                "id": "heartbeat",
                "type": "simple",
                "description": "Heartbeat sound",
                "timeout": 10,
                "command": "afplay /System/Library/Sounds/Pop.aiff"
            },
            {
                "id": "clock",
                "type": "agent",
                "description": "Announce time",
                "timeout": 60,
                "prompt": "Say the current time"
            }
        ]"#;
        fs::write(dir.path().join("tasks.json"), tasks_json).unwrap();
        
        let tasks = ConfigLoader::load_tasks(dir.path()).unwrap();
        assert_eq!(tasks.len(), 2);
        assert_eq!(tasks[0].id, "heartbeat");
        assert_eq!(tasks[1].id, "clock");
    }

    #[test]
    fn test_load_schedules() {
        let dir = setup_test_dir();
        let schedules_json = r#"[
            {"task": "heartbeat", "hour": "*", "minute": "*/10", "weekday": "*"},
            {"task": "clock", "hour": "*", "minute": 0, "weekday": "*"}
        ]"#;
        fs::write(dir.path().join("schedules.json"), schedules_json).unwrap();
        
        let schedules = ConfigLoader::load_schedules(dir.path()).unwrap();
        assert_eq!(schedules.len(), 2);
        assert_eq!(schedules[0].task, "heartbeat");
    }

    #[test]
    fn test_load_state_default() {
        let dir = setup_test_dir();
        // No state.json exists
        
        let state = ConfigLoader::load_state(dir.path()).unwrap();
        assert!(state.last_run.is_none());
        assert_eq!(state.total_runs_today, 0);
    }

    #[test]
    fn test_load_runs_index_default() {
        let dir = setup_test_dir();
        // No index.json exists
        
        let index = ConfigLoader::load_runs_index(dir.path()).unwrap();
        assert!(index.runs.is_empty());
        assert_eq!(index.total, 0);
    }

    #[test]
    fn test_load_runs_index() {
        let dir = setup_test_dir();
        let index_json = r#"{
            "runs": [
                {
                    "id": "abc-123",
                    "task": "heartbeat",
                    "exit_code": 0,
                    "started_at": "2026-01-25T08:00:00Z",
                    "finished_at": "2026-01-25T08:00:01Z"
                }
            ],
            "total": 1,
            "updated_at": "2026-01-25T08:00:01Z"
        }"#;
        fs::write(dir.path().join("runs/index.json"), index_json).unwrap();
        
        let index = ConfigLoader::load_runs_index(dir.path()).unwrap();
        assert_eq!(index.runs.len(), 1);
        assert_eq!(index.runs[0].task, "heartbeat");
    }

    #[test]
    fn test_get_task() {
        let tasks = vec![
            Task {
                id: "task1".to_string(),
                task_type: super::super::types::TaskType::Simple,
                description: "Task 1".to_string(),
                timeout: 60,
                command: Some("echo 1".to_string()),
                prompt: None,
                workdir: None,
                model: None,
            },
            Task {
                id: "task2".to_string(),
                task_type: super::super::types::TaskType::Agent,
                description: "Task 2".to_string(),
                timeout: 300,
                command: None,
                prompt: Some("Do something".to_string()),
                workdir: None,
                model: None,
            },
        ];
        
        assert!(ConfigLoader::get_task(&tasks, "task1").is_some());
        assert!(ConfigLoader::get_task(&tasks, "task2").is_some());
        assert!(ConfigLoader::get_task(&tasks, "task3").is_none());
    }
}
