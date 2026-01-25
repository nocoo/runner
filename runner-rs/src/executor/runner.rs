use std::process::{Command, Stdio};
use std::time::{Duration, Instant};
use std::io::{BufRead, BufReader};
use anyhow::{Context, Result};
use chrono::Utc;
use uuid::Uuid;

use crate::config::{Task, TaskType, RunSummary, RunDetail};
use crate::storage::Storage;

/// Execute tasks (simple or agent)
pub struct TaskExecutor {
    storage: Storage,
    dry_run: bool,
    verbose: bool,
}

pub struct ExecutionResult {
    pub id: String,
    pub exit_code: i32,
    pub duration: Duration,
    pub output: String,
}

impl TaskExecutor {
    pub fn new(storage: Storage, dry_run: bool, verbose: bool) -> Self {
        Self { storage, dry_run, verbose }
    }
    
    fn log(&self, msg: &str) {
        if self.verbose {
            eprintln!("[DEBUG] {}", msg);
        }
    }
    
    /// Execute a task
    pub fn execute(&self, task: &Task, trigger: &str) -> Result<ExecutionResult> {
        let run_id = Uuid::new_v4().to_string();
        let started_at = Utc::now();
        let started_at_str = started_at.format("%Y-%m-%dT%H:%M:%SZ").to_string();
        let start_epoch = started_at.timestamp();
        
        self.log(&format!("Run ID: {}", run_id));
        self.log(&format!("Started at: {}", started_at_str));
        
        if self.dry_run {
            return Ok(ExecutionResult {
                id: run_id,
                exit_code: 0,
                duration: Duration::from_secs(0),
                output: format!("[DRY RUN] Would execute task: {}", task.id),
            });
        }
        
        match task.task_type {
            TaskType::Simple => self.execute_simple(task, &run_id, &started_at_str, trigger),
            TaskType::Agent => self.execute_agent(task, &run_id, &started_at_str, start_epoch, trigger),
            TaskType::Manual => {
                Ok(ExecutionResult {
                    id: run_id,
                    exit_code: 0,
                    duration: Duration::from_secs(0),
                    output: "Manual task - not executed".to_string(),
                })
            }
        }
    }
    
    /// Execute a simple (shell command) task synchronously
    fn execute_simple(&self, task: &Task, run_id: &str, started_at: &str, trigger: &str) -> Result<ExecutionResult> {
        let command = task.command.as_ref()
            .context("Simple task must have a command")?;
        
        self.log(&format!("Task type: simple"));
        self.log(&format!("Command: {}", command));
        
        // Add to index as running
        let summary = RunSummary {
            id: run_id.to_string(),
            task: task.id.clone(),
            exit_code: None,
            started_at: started_at.to_string(),
            finished_at: None,
            pid: None,
            started_at_epoch: None,
        };
        self.storage.add_run(&summary)?;
        
        // Create output file with header
        let header = format!(
            "Task: {}\nTrigger: {}\nStarted: {}\nCommand: {}\n{}\n",
            task.id, trigger, started_at, command,
            "=".repeat(50)
        );
        self.storage.write_output(run_id, &header)?;
        
        let start = Instant::now();
        
        // Execute command
        let output = Command::new("sh")
            .args(["-c", command])
            .current_dir(task.workdir.as_deref().unwrap_or("."))
            .output()
            .context("Failed to execute command")?;
        
        let duration = start.elapsed();
        let exit_code = output.status.code().unwrap_or(-1);
        
        let stdout = String::from_utf8_lossy(&output.stdout);
        let stderr = String::from_utf8_lossy(&output.stderr);
        let full_output = format!("{}{}", stdout, stderr);
        
        // Append output
        self.storage.append_output(run_id, &full_output)?;
        
        let finished_at = Utc::now().format("%Y-%m-%dT%H:%M:%SZ").to_string();
        
        // Update index
        self.storage.update_run(run_id, Some(exit_code), Some(&finished_at))?;
        
        // Write run detail
        let detail = RunDetail {
            id: run_id.to_string(),
            task: task.id.clone(),
            trigger: trigger.to_string(),
            started_at: started_at.to_string(),
            finished_at: Some(finished_at.clone()),
            duration_seconds: Some(duration.as_secs()),
            exit_code,
        };
        self.storage.write_run_detail(&detail)?;
        
        self.log(&format!("Duration: {}s, Exit code: {}", duration.as_secs(), exit_code));
        
        Ok(ExecutionResult {
            id: run_id.to_string(),
            exit_code,
            duration,
            output: full_output,
        })
    }
    
    /// Execute an agent (opencode) task
    /// This spawns the task in background and returns immediately
    fn execute_agent(&self, task: &Task, run_id: &str, started_at: &str, start_epoch: i64, trigger: &str) -> Result<ExecutionResult> {
        let prompt = task.prompt.as_ref()
            .context("Agent task must have a prompt")?;
        
        self.log(&format!("Task type: agent"));
        self.log(&format!("Prompt length: {} chars", prompt.len()));
        
        // Create output file with header
        // Truncate prompt safely at char boundary
        let prompt_preview: String = prompt.chars().take(100).collect();
        let header = format!(
            "Task: {}\nTrigger: {}\nStarted: {}\nPrompt: {}\n{}\n",
            task.id, trigger, started_at, prompt_preview,
            "=".repeat(50)
        );
        self.storage.write_output(run_id, &header)?;
        
        // Spawn background process
        let workdir = task.workdir.as_deref().unwrap_or(".");
        let model = task.model.as_deref().unwrap_or("sonnet");
        
        let mut child = Command::new("opencode")
            .args(["run", "--agent", model])
            .current_dir(workdir)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .context("Failed to spawn opencode")?;
        
        let pid = child.id();
        self.log(&format!("Background PID: {}", pid));
        
        // Write prompt to stdin
        if let Some(mut stdin) = child.stdin.take() {
            use std::io::Write;
            stdin.write_all(prompt.as_bytes())?;
        }
        
        // Add to index as running
        let summary = RunSummary {
            id: run_id.to_string(),
            task: task.id.clone(),
            exit_code: None,
            started_at: started_at.to_string(),
            finished_at: None,
            pid: Some(pid),
            started_at_epoch: Some(start_epoch),
        };
        self.storage.add_run(&summary)?;
        
        // Spawn a thread to wait for completion and capture output
        let storage = Storage::new(self.storage.data_dir());
        let run_id_owned = run_id.to_string();
        let task_id = task.id.clone();
        let trigger_owned = trigger.to_string();
        let started_at_owned = started_at.to_string();
        
        std::thread::spawn(move || {
            let start = Instant::now();
            
            // Capture stdout/stderr
            let stdout = child.stdout.take();
            let _stderr = child.stderr.take();
            
            if let Some(stdout) = stdout {
                let reader = BufReader::new(stdout);
                for line in reader.lines() {
                    if let Ok(line) = line {
                        let _ = storage.append_output(&run_id_owned, &format!("{}\n", line));
                    }
                }
            }
            
            // Wait for process
            let status = child.wait();
            let duration = start.elapsed();
            
            let exit_code = status
                .map(|s| s.code().unwrap_or(-1))
                .unwrap_or(-1);
            
            let finished_at = Utc::now().format("%Y-%m-%dT%H:%M:%SZ").to_string();
            
            // Update index
            let _ = storage.update_run(&run_id_owned, Some(exit_code), Some(&finished_at));
            
            // Write run detail
            let detail = RunDetail {
                id: run_id_owned.clone(),
                task: task_id,
                trigger: trigger_owned,
                started_at: started_at_owned,
                finished_at: Some(finished_at),
                duration_seconds: Some(duration.as_secs()),
                exit_code,
            };
            let _ = storage.write_run_detail(&detail);
        });
        
        // Return immediately (task runs in background)
        Ok(ExecutionResult {
            id: run_id.to_string(),
            exit_code: 0, // Will be updated when task completes
            duration: Duration::from_secs(0),
            output: "Task started in background".to_string(),
        })
    }
}



#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    fn setup() -> (TempDir, TaskExecutor) {
        let dir = TempDir::new().unwrap();
        let storage = Storage::new(dir.path());
        storage.init().unwrap();
        let executor = TaskExecutor::new(storage, false, true);
        (dir, executor)
    }

    #[test]
    fn test_execute_simple_task() {
        let (dir, executor) = setup();
        
        let task = Task {
            id: "test".to_string(),
            task_type: TaskType::Simple,
            description: "Test".to_string(),
            timeout: 10,
            command: Some("echo hello".to_string()),
            prompt: None,
            workdir: None,
            model: None,
        };
        
        let result = executor.execute(&task, "test").unwrap();
        assert_eq!(result.exit_code, 0);
        assert!(result.output.contains("hello"));
        
        // Check output file exists
        assert!(dir.path().join(format!("runs/{}.output", result.id)).exists());
    }

    #[test]
    fn test_execute_simple_task_failure() {
        let (_dir, executor) = setup();
        
        let task = Task {
            id: "test".to_string(),
            task_type: TaskType::Simple,
            description: "Test".to_string(),
            timeout: 10,
            command: Some("exit 1".to_string()),
            prompt: None,
            workdir: None,
            model: None,
        };
        
        let result = executor.execute(&task, "test").unwrap();
        assert_eq!(result.exit_code, 1);
    }

    #[test]
    fn test_dry_run() {
        let (_dir, _) = setup();
        let dir = TempDir::new().unwrap();
        let storage = Storage::new(dir.path());
        storage.init().unwrap();
        let executor = TaskExecutor::new(storage, true, false); // dry_run = true
        
        let task = Task {
            id: "test".to_string(),
            task_type: TaskType::Simple,
            description: "Test".to_string(),
            timeout: 10,
            command: Some("rm -rf /".to_string()), // Dangerous but won't run
            prompt: None,
            workdir: None,
            model: None,
        };
        
        let result = executor.execute(&task, "test").unwrap();
        assert_eq!(result.exit_code, 0);
        assert!(result.output.contains("DRY RUN"));
    }

    #[test]
    fn test_manual_task_not_executed() {
        let (_dir, executor) = setup();
        
        let task = Task {
            id: "manual".to_string(),
            task_type: TaskType::Manual,
            description: "Manual".to_string(),
            timeout: 10,
            command: None,
            prompt: None,
            workdir: None,
            model: None,
        };
        
        let result = executor.execute(&task, "manual").unwrap();
        assert_eq!(result.exit_code, 0);
        assert!(result.output.contains("not executed"));
    }

    #[test]
    fn test_execute_with_workdir() {
        let (_dir, executor) = setup();
        
        let task = Task {
            id: "test".to_string(),
            task_type: TaskType::Simple,
            description: "Test".to_string(),
            timeout: 10,
            command: Some("pwd".to_string()),
            prompt: None,
            workdir: Some("/tmp".to_string()),
            model: None,
        };
        
        let result = executor.execute(&task, "test").unwrap();
        assert_eq!(result.exit_code, 0);
        assert!(result.output.contains("/tmp") || result.output.contains("/private/tmp"));
    }
}
