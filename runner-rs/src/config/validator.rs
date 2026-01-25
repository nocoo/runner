use super::types::{Task, TaskType, Schedule, Config};
use thiserror::Error;

#[derive(Debug, Error)]
pub enum ValidationError {
    #[error("Task '{0}' has no command (required for simple type)")]
    MissingCommand(String),
    #[error("Task '{0}' has no prompt (required for agent type)")]
    MissingPrompt(String),
    #[error("Schedule references unknown task '{0}'")]
    UnknownTask(String),
    #[error("Duplicate task ID: '{0}'")]
    DuplicateTask(String),
    #[error("Task '{0}' has invalid timeout: {1}")]
    InvalidTimeout(String, u32),
}

pub struct ConfigValidator;

impl ConfigValidator {
    /// Validate a single task
    pub fn validate_task(task: &Task) -> Result<(), ValidationError> {
        match task.task_type {
            TaskType::Simple => {
                if task.command.is_none() || task.command.as_ref().map(|s| s.is_empty()).unwrap_or(true) {
                    return Err(ValidationError::MissingCommand(task.id.clone()));
                }
            }
            TaskType::Agent => {
                if task.prompt.is_none() || task.prompt.as_ref().map(|s| s.is_empty()).unwrap_or(true) {
                    return Err(ValidationError::MissingPrompt(task.id.clone()));
                }
            }
            TaskType::Manual => {
                // Manual tasks don't require command or prompt
            }
        }
        
        if task.timeout == 0 {
            return Err(ValidationError::InvalidTimeout(task.id.clone(), task.timeout));
        }
        
        Ok(())
    }
    
    /// Validate all tasks
    pub fn validate_tasks(tasks: &[Task]) -> Result<(), ValidationError> {
        let mut seen_ids = std::collections::HashSet::new();
        
        for task in tasks {
            // Check for duplicates
            if !seen_ids.insert(&task.id) {
                return Err(ValidationError::DuplicateTask(task.id.clone()));
            }
            
            Self::validate_task(task)?;
        }
        
        Ok(())
    }
    
    /// Validate schedules against tasks
    pub fn validate_schedules(schedules: &[Schedule], tasks: &[Task]) -> Result<(), ValidationError> {
        let task_ids: std::collections::HashSet<_> = tasks.iter().map(|t| &t.id).collect();
        
        for schedule in schedules {
            if !task_ids.contains(&schedule.task) {
                return Err(ValidationError::UnknownTask(schedule.task.clone()));
            }
        }
        
        Ok(())
    }
    
    /// Validate full config
    pub fn validate_config(config: &Config) -> Result<(), ValidationError> {
        Self::validate_tasks(&config.tasks)?;
        Self::validate_schedules(&config.schedules, &config.tasks)?;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn make_simple_task(id: &str, command: Option<&str>) -> Task {
        Task {
            id: id.to_string(),
            task_type: TaskType::Simple,
            description: "Test".to_string(),
            timeout: 60,
            command: command.map(String::from),
            prompt: None,
            workdir: None,
            model: None,
        }
    }

    fn make_agent_task(id: &str, prompt: Option<&str>) -> Task {
        Task {
            id: id.to_string(),
            task_type: TaskType::Agent,
            description: "Test".to_string(),
            timeout: 300,
            command: None,
            prompt: prompt.map(String::from),
            workdir: None,
            model: None,
        }
    }

    fn make_schedule(task: &str) -> Schedule {
        Schedule {
            task: task.to_string(),
            hour: json!("*"),
            minute: json!(0),
            weekday: json!("*"),
        }
    }

    #[test]
    fn test_valid_simple_task() {
        let task = make_simple_task("test", Some("echo hello"));
        assert!(ConfigValidator::validate_task(&task).is_ok());
    }

    #[test]
    fn test_simple_task_missing_command() {
        let task = make_simple_task("test", None);
        let result = ConfigValidator::validate_task(&task);
        assert!(matches!(result, Err(ValidationError::MissingCommand(_))));
    }

    #[test]
    fn test_simple_task_empty_command() {
        let task = make_simple_task("test", Some(""));
        let result = ConfigValidator::validate_task(&task);
        assert!(matches!(result, Err(ValidationError::MissingCommand(_))));
    }

    #[test]
    fn test_valid_agent_task() {
        let task = make_agent_task("test", Some("Do something"));
        assert!(ConfigValidator::validate_task(&task).is_ok());
    }

    #[test]
    fn test_agent_task_missing_prompt() {
        let task = make_agent_task("test", None);
        let result = ConfigValidator::validate_task(&task);
        assert!(matches!(result, Err(ValidationError::MissingPrompt(_))));
    }

    #[test]
    fn test_agent_task_empty_prompt() {
        let task = make_agent_task("test", Some(""));
        let result = ConfigValidator::validate_task(&task);
        assert!(matches!(result, Err(ValidationError::MissingPrompt(_))));
    }

    #[test]
    fn test_task_zero_timeout() {
        let mut task = make_simple_task("test", Some("echo hello"));
        task.timeout = 0;
        let result = ConfigValidator::validate_task(&task);
        assert!(matches!(result, Err(ValidationError::InvalidTimeout(_, 0))));
    }

    #[test]
    fn test_duplicate_task_ids() {
        let tasks = vec![
            make_simple_task("task1", Some("echo 1")),
            make_simple_task("task1", Some("echo 2")), // Duplicate
        ];
        let result = ConfigValidator::validate_tasks(&tasks);
        assert!(matches!(result, Err(ValidationError::DuplicateTask(_))));
    }

    #[test]
    fn test_valid_schedules() {
        let tasks = vec![make_simple_task("task1", Some("echo 1"))];
        let schedules = vec![make_schedule("task1")];
        assert!(ConfigValidator::validate_schedules(&schedules, &tasks).is_ok());
    }

    #[test]
    fn test_schedule_unknown_task() {
        let tasks = vec![make_simple_task("task1", Some("echo 1"))];
        let schedules = vec![make_schedule("unknown")];
        let result = ConfigValidator::validate_schedules(&schedules, &tasks);
        assert!(matches!(result, Err(ValidationError::UnknownTask(_))));
    }

    #[test]
    fn test_valid_config() {
        let config = Config {
            tasks: vec![
                make_simple_task("task1", Some("echo 1")),
                make_agent_task("task2", Some("Do something")),
            ],
            schedules: vec![
                make_schedule("task1"),
                make_schedule("task2"),
            ],
        };
        assert!(ConfigValidator::validate_config(&config).is_ok());
    }

    #[test]
    fn test_manual_task_no_command_or_prompt() {
        let task = Task {
            id: "manual".to_string(),
            task_type: TaskType::Manual,
            description: "Manual task".to_string(),
            timeout: 60,
            command: None,
            prompt: None,
            workdir: None,
            model: None,
        };
        assert!(ConfigValidator::validate_task(&task).is_ok());
    }
}
