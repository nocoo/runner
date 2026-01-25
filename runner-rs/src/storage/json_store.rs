use std::fs::{self, OpenOptions};
use std::io::Write;
use std::path::{Path, PathBuf};
use anyhow::{Context, Result};
use fs2::FileExt;
use chrono::Utc;

use crate::config::{RunSummary, RunDetail, SystemState, LastRun};

/// Thread-safe JSON storage with file locking
pub struct Storage {
    data_dir: PathBuf,
}

impl Storage {
    pub fn new(data_dir: impl AsRef<Path>) -> Self {
        Self {
            data_dir: data_dir.as_ref().to_path_buf(),
        }
    }
    
    pub fn data_dir(&self) -> &Path {
        &self.data_dir
    }
    
    /// Get timestamp in ISO 8601 format
    fn timestamp() -> String {
        Utc::now().format("%Y-%m-%dT%H:%M:%SZ").to_string()
    }
    
    /// Ensure data directories exist
    pub fn init(&self) -> Result<()> {
        fs::create_dir_all(self.data_dir.join("runs"))?;
        
        // Create index.json if not exists
        let index_path = self.data_dir.join("runs/index.json");
        if !index_path.exists() {
            let index = serde_json::json!({
                "runs": [],
                "total": 0,
                "updated_at": Self::timestamp()
            });
            fs::write(&index_path, serde_json::to_string_pretty(&index)?)?;
        }
        
        // Create state.json if not exists
        let state_path = self.data_dir.join("state.json");
        if !state_path.exists() {
            let state = SystemState::default();
            fs::write(&state_path, serde_json::to_string_pretty(&state)?)?;
        }
        
        Ok(())
    }
    
    /// Add a new run to index.json (thread-safe with file locking)
    pub fn add_run(&self, run: &RunSummary) -> Result<()> {
        let index_path = self.data_dir.join("runs/index.json");
        let lock_path = self.data_dir.join("runs/.index.lock");
        
        // Create lock file and acquire exclusive lock
        let lock_file = OpenOptions::new()
            .create(true)
            .write(true)
            .open(&lock_path)
            .context("Failed to open lock file")?;
        
        lock_file.lock_exclusive().context("Failed to acquire lock")?;
        
        // Read current index
        let content = fs::read_to_string(&index_path)
            .unwrap_or_else(|_| r#"{"runs":[],"total":0,"updated_at":""}"#.to_string());
        let mut index: serde_json::Value = serde_json::from_str(&content)
            .context("Failed to parse index.json")?;
        
        // Add new run
        let runs = index["runs"].as_array_mut()
            .context("Invalid index.json: runs is not an array")?;
        runs.push(serde_json::to_value(run)?);
        
        // Update metadata
        index["total"] = serde_json::json!(runs.len());
        index["updated_at"] = serde_json::json!(Self::timestamp());
        
        // Write atomically (write to temp, then rename)
        let temp_path = index_path.with_extension("json.tmp");
        fs::write(&temp_path, serde_json::to_string_pretty(&index)?)?;
        fs::rename(&temp_path, &index_path)?;
        
        // Lock released when lock_file is dropped
        Ok(())
    }
    
    /// Update an existing run in index.json (thread-safe)
    pub fn update_run(&self, id: &str, exit_code: Option<i32>, finished_at: Option<&str>) -> Result<()> {
        let index_path = self.data_dir.join("runs/index.json");
        let lock_path = self.data_dir.join("runs/.index.lock");
        
        let lock_file = OpenOptions::new()
            .create(true)
            .write(true)
            .open(&lock_path)?;
        lock_file.lock_exclusive()?;
        
        let content = fs::read_to_string(&index_path)?;
        let mut index: serde_json::Value = serde_json::from_str(&content)?;
        
        let runs = index["runs"].as_array_mut()
            .context("Invalid index.json")?;
        
        for run in runs.iter_mut() {
            if run["id"] == id {
                if let Some(code) = exit_code {
                    run["exit_code"] = serde_json::json!(code);
                }
                if let Some(finished) = finished_at {
                    run["finished_at"] = serde_json::json!(finished);
                }
                run["pid"] = serde_json::Value::Null;
                break;
            }
        }
        
        index["updated_at"] = serde_json::json!(Self::timestamp());
        
        let temp_path = index_path.with_extension("json.tmp");
        fs::write(&temp_path, serde_json::to_string_pretty(&index)?)?;
        fs::rename(&temp_path, &index_path)?;
        
        Ok(())
    }
    
    /// Mark a run as interrupted
    pub fn mark_interrupted(&self, id: &str) -> Result<()> {
        self.update_run(id, Some(-1), Some(&Self::timestamp()))
    }
    
    /// Write run detail to <id>.json
    pub fn write_run_detail(&self, detail: &RunDetail) -> Result<()> {
        let path = self.data_dir.join(format!("runs/{}.json", detail.id));
        fs::write(&path, serde_json::to_string_pretty(detail)?)?;
        Ok(())
    }
    
    /// Write output to <id>.output
    pub fn write_output(&self, id: &str, output: &str) -> Result<()> {
        let path = self.data_dir.join(format!("runs/{}.output", id));
        fs::write(&path, output)?;
        Ok(())
    }
    
    /// Append to output file
    pub fn append_output(&self, id: &str, content: &str) -> Result<()> {
        let path = self.data_dir.join(format!("runs/{}.output", id));
        let mut file = OpenOptions::new()
            .create(true)
            .append(true)
            .open(&path)?;
        file.write_all(content.as_bytes())?;
        Ok(())
    }
    
    /// Update state.json (thread-safe)
    pub fn update_state(&self, last_run: Option<LastRun>, total_today: u32, success_rate: f64) -> Result<()> {
        let state_path = self.data_dir.join("state.json");
        let lock_path = self.data_dir.join(".state.lock");
        
        let lock_file = OpenOptions::new()
            .create(true)
            .write(true)
            .open(&lock_path)?;
        lock_file.lock_exclusive()?;
        
        let content = fs::read_to_string(&state_path)
            .unwrap_or_else(|_| "{}".to_string());
        let mut state: serde_json::Value = serde_json::from_str(&content)?;
        
        if let Some(run) = last_run {
            state["last_run"] = serde_json::to_value(&run)?;
        }
        state["total_runs_today"] = serde_json::json!(total_today);
        state["success_rate_today"] = serde_json::json!(success_rate);
        state["version"] = serde_json::json!(env!("CARGO_PKG_VERSION"));
        
        let temp_path = state_path.with_extension("json.tmp");
        fs::write(&temp_path, serde_json::to_string_pretty(&state)?)?;
        fs::rename(&temp_path, &state_path)?;
        
        Ok(())
    }
    
    /// Get running tasks (exit_code is null and has pid)
    pub fn get_running_tasks(&self) -> Result<Vec<RunSummary>> {
        let index_path = self.data_dir.join("runs/index.json");
        let content = fs::read_to_string(&index_path)?;
        let index: serde_json::Value = serde_json::from_str(&content)?;
        
        let runs = index["runs"].as_array()
            .context("Invalid index.json")?;
        
        let mut running = Vec::new();
        for run in runs {
            if run["exit_code"].is_null() && run["pid"].is_number() {
                let summary: RunSummary = serde_json::from_value(run.clone())?;
                running.push(summary);
            }
        }
        
        Ok(running)
    }
    
    /// Calculate today's stats
    pub fn calculate_today_stats(&self) -> Result<(u32, f64)> {
        let today = Utc::now().format("%Y-%m-%d").to_string();
        let index_path = self.data_dir.join("runs/index.json");
        let content = fs::read_to_string(&index_path)?;
        let index: serde_json::Value = serde_json::from_str(&content)?;
        
        let runs = index["runs"].as_array()
            .context("Invalid index.json")?;
        
        let mut total = 0u32;
        let mut success = 0u32;
        
        for run in runs {
            if let Some(started) = run["started_at"].as_str() {
                if started.starts_with(&today) {
                    total += 1;
                    if run["exit_code"] == 0 {
                        success += 1;
                    }
                }
            }
        }
        
        let rate = if total > 0 { success as f64 / total as f64 } else { 0.0 };
        Ok((total, rate))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;
    use std::thread;
    use std::sync::Arc;

    fn setup() -> (TempDir, Storage) {
        let dir = TempDir::new().unwrap();
        let storage = Storage::new(dir.path());
        storage.init().unwrap();
        (dir, storage)
    }

    #[test]
    fn test_init_creates_directories() {
        let dir = TempDir::new().unwrap();
        let storage = Storage::new(dir.path());
        storage.init().unwrap();
        
        assert!(dir.path().join("runs").exists());
        assert!(dir.path().join("runs/index.json").exists());
        assert!(dir.path().join("state.json").exists());
    }

    #[test]
    fn test_add_run() {
        let (_dir, storage) = setup();
        
        let run = RunSummary {
            id: "test-123".to_string(),
            task: "heartbeat".to_string(),
            exit_code: None,
            started_at: "2026-01-25T08:00:00Z".to_string(),
            finished_at: None,
            pid: Some(12345),
            started_at_epoch: Some(1769306400),
        };
        
        storage.add_run(&run).unwrap();
        
        let running = storage.get_running_tasks().unwrap();
        assert_eq!(running.len(), 1);
        assert_eq!(running[0].id, "test-123");
    }

    #[test]
    fn test_update_run() {
        let (_dir, storage) = setup();
        
        let run = RunSummary {
            id: "test-123".to_string(),
            task: "heartbeat".to_string(),
            exit_code: None,
            started_at: "2026-01-25T08:00:00Z".to_string(),
            finished_at: None,
            pid: Some(12345),
            started_at_epoch: Some(1769306400),
        };
        storage.add_run(&run).unwrap();
        
        storage.update_run("test-123", Some(0), Some("2026-01-25T08:00:01Z")).unwrap();
        
        // Should no longer be in running tasks
        let running = storage.get_running_tasks().unwrap();
        assert!(running.is_empty());
    }

    #[test]
    fn test_mark_interrupted() {
        let (_dir, storage) = setup();
        
        let run = RunSummary {
            id: "test-123".to_string(),
            task: "heartbeat".to_string(),
            exit_code: None,
            started_at: "2026-01-25T08:00:00Z".to_string(),
            finished_at: None,
            pid: Some(12345),
            started_at_epoch: None,
        };
        storage.add_run(&run).unwrap();
        
        storage.mark_interrupted("test-123").unwrap();
        
        let running = storage.get_running_tasks().unwrap();
        assert!(running.is_empty());
    }

    #[test]
    fn test_concurrent_writes() {
        let (dir, _) = setup();
        let storage = Arc::new(Storage::new(dir.path()));
        
        let mut handles = vec![];
        
        // Spawn 10 threads that each add a run
        for i in 0..10 {
            let s = Arc::clone(&storage);
            let handle = thread::spawn(move || {
                let run = RunSummary {
                    id: format!("test-{}", i),
                    task: "task".to_string(),
                    exit_code: Some(0),
                    started_at: "2026-01-25T08:00:00Z".to_string(),
                    finished_at: Some("2026-01-25T08:00:01Z".to_string()),
                    pid: None,
                    started_at_epoch: None,
                };
                s.add_run(&run).unwrap();
            });
            handles.push(handle);
        }
        
        // Wait for all threads
        for handle in handles {
            handle.join().unwrap();
        }
        
        // Verify all 10 runs were added
        let index_path = dir.path().join("runs/index.json");
        let content = fs::read_to_string(&index_path).unwrap();
        let index: serde_json::Value = serde_json::from_str(&content).unwrap();
        let runs = index["runs"].as_array().unwrap();
        
        assert_eq!(runs.len(), 10);
    }

    #[test]
    fn test_write_output() {
        let (dir, storage) = setup();
        
        storage.write_output("test-123", "Hello, World!").unwrap();
        
        let content = fs::read_to_string(dir.path().join("runs/test-123.output")).unwrap();
        assert_eq!(content, "Hello, World!");
    }

    #[test]
    fn test_append_output() {
        let (dir, storage) = setup();
        
        storage.write_output("test-123", "Line 1\n").unwrap();
        storage.append_output("test-123", "Line 2\n").unwrap();
        
        let content = fs::read_to_string(dir.path().join("runs/test-123.output")).unwrap();
        assert_eq!(content, "Line 1\nLine 2\n");
    }

    #[test]
    fn test_calculate_today_stats() {
        let (_dir, storage) = setup();
        
        // Add some runs with today's date
        let today = Utc::now().format("%Y-%m-%dT%H:%M:%SZ").to_string();
        
        for i in 0..5 {
            let run = RunSummary {
                id: format!("test-{}", i),
                task: "task".to_string(),
                exit_code: Some(if i < 3 { 0 } else { 1 }), // 3 success, 2 fail
                started_at: today.clone(),
                finished_at: Some(today.clone()),
                pid: None,
                started_at_epoch: None,
            };
            storage.add_run(&run).unwrap();
        }
        
        let (total, rate) = storage.calculate_today_stats().unwrap();
        assert_eq!(total, 5);
        assert!((rate - 0.6).abs() < 0.01); // 3/5 = 0.6
    }
}
