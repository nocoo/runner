use anyhow::Result;
use nix::sys::signal::kill;
use nix::unistd::Pid;

use crate::storage::Storage;

/// Monitor running processes and detect stale/interrupted tasks
pub struct ProcessMonitor {
    storage: Storage,
    verbose: bool,
}

impl ProcessMonitor {
    pub fn new(storage: Storage, verbose: bool) -> Self {
        Self { storage, verbose }
    }
    
    fn log(&self, msg: &str) {
        if self.verbose {
            eprintln!("[MONITOR DEBUG] {}", msg);
        }
    }
    
    /// Check if a process is running
    pub fn is_process_running(pid: u32) -> bool {
        // Send signal 0 to check if process exists
        kill(Pid::from_raw(pid as i32), None).is_ok()
    }
    
    /// Get process start time (on macOS, using ps)
    #[cfg(target_os = "macos")]
    pub fn get_process_start_time(pid: u32) -> Option<i64> {
        use std::process::Command;
        
        let output = Command::new("ps")
            .args(["-o", "lstart=", "-p", &pid.to_string()])
            .output()
            .ok()?;
        
        if !output.status.success() {
            return None;
        }
        
        let lstart = String::from_utf8_lossy(&output.stdout);
        let lstart = lstart.trim();
        
        // Parse "Mon Jan 25 08:00:00 2026" format
        use chrono::NaiveDateTime;
        let dt = NaiveDateTime::parse_from_str(lstart, "%a %b %d %H:%M:%S %Y").ok()?;
        Some(dt.and_utc().timestamp())
    }
    
    #[cfg(not(target_os = "macos"))]
    pub fn get_process_start_time(_pid: u32) -> Option<i64> {
        // Linux: could read /proc/{pid}/stat
        None
    }
    
    /// Check if a PID has been reused (started at different time)
    pub fn is_pid_reused(pid: u32, recorded_start: Option<i64>) -> bool {
        if let Some(recorded) = recorded_start {
            if let Some(current) = Self::get_process_start_time(pid) {
                // If process started more than 5 seconds after recorded time,
                // it's likely a different process
                return (current - recorded).abs() > 5;
            }
        }
        false
    }
    
    /// Check all running tasks and mark interrupted ones
    pub fn check_running_tasks(&self) -> Result<Vec<String>> {
        self.log("Checking running tasks...");
        
        let running = self.storage.get_running_tasks()?;
        let mut interrupted = Vec::new();
        
        for run in running {
            if let Some(pid) = run.pid {
                self.log(&format!(
                    "Checking task {} (pid={}, started_epoch={:?})",
                    run.id, pid, run.started_at_epoch
                ));
                
                if !Self::is_process_running(pid) {
                    self.log(&format!("Process {} not running, marking as interrupted", pid));
                    self.storage.mark_interrupted(&run.id)?;
                    interrupted.push(run.id.clone());
                } else if Self::is_pid_reused(pid, run.started_at_epoch) {
                    self.log(&format!("PID {} reused, marking as interrupted", pid));
                    self.storage.mark_interrupted(&run.id)?;
                    interrupted.push(run.id.clone());
                } else {
                    self.log(&format!("Task {} still running", run.id));
                }
            } else {
                // No PID recorded but not finished - should be interrupted
                self.log(&format!("Task {} has no PID, marking as interrupted", run.id));
                self.storage.mark_interrupted(&run.id)?;
                interrupted.push(run.id.clone());
            }
        }
        
        Ok(interrupted)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::config::RunSummary;
    use tempfile::TempDir;
    use std::process::Command;

    fn setup() -> (TempDir, ProcessMonitor) {
        let dir = TempDir::new().unwrap();
        let storage = Storage::new(dir.path());
        storage.init().unwrap();
        let monitor = ProcessMonitor::new(storage, true);
        (dir, monitor)
    }

    #[test]
    fn test_is_process_running_current() {
        // Current process should be running
        let pid = std::process::id();
        assert!(ProcessMonitor::is_process_running(pid));
    }

    #[test]
    fn test_is_process_running_invalid() {
        // PID 1 is always init/launchd, but very high PIDs are unlikely to exist
        assert!(!ProcessMonitor::is_process_running(999999999));
    }

    #[test]
    fn test_check_running_tasks_empty() {
        let (_dir, monitor) = setup();
        let interrupted = monitor.check_running_tasks().unwrap();
        assert!(interrupted.is_empty());
    }

    #[test]
    fn test_check_running_tasks_marks_dead_process() {
        let (dir, _) = setup();
        let storage = Storage::new(dir.path());
        
        // Spawn a process and immediately kill it
        let mut child = Command::new("sleep")
            .arg("1000")
            .spawn()
            .unwrap();
        let pid = child.id();
        
        // Add it as a running task
        let run = RunSummary {
            id: "test-123".to_string(),
            task: "test".to_string(),
            exit_code: None,
            started_at: "2026-01-25T08:00:00Z".to_string(),
            finished_at: None,
            pid: Some(pid),
            started_at_epoch: Some(chrono::Utc::now().timestamp()),
        };
        storage.add_run(&run).unwrap();
        
        // Kill the process
        child.kill().unwrap();
        child.wait().unwrap();
        
        // Now check - should detect it as interrupted
        let monitor = ProcessMonitor::new(storage, true);
        let interrupted = monitor.check_running_tasks().unwrap();
        assert_eq!(interrupted, vec!["test-123"]);
    }

    #[test]
    fn test_check_running_tasks_no_pid_not_detected() {
        let (dir, _) = setup();
        let storage = Storage::new(dir.path());
        
        // Add a run with no PID - this should NOT be detected as running
        // because get_running_tasks() only returns tasks with a PID
        let run = RunSummary {
            id: "test-456".to_string(),
            task: "test".to_string(),
            exit_code: None,
            started_at: "2026-01-25T08:00:00Z".to_string(),
            finished_at: None,
            pid: None,
            started_at_epoch: None,
        };
        storage.add_run(&run).unwrap();
        
        let monitor = ProcessMonitor::new(storage, true);
        let interrupted = monitor.check_running_tasks().unwrap();
        // No PID means it won't be checked by monitor
        assert!(interrupted.is_empty());
    }
}
