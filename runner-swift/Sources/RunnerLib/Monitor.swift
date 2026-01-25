import Foundation

/// Process monitor to detect stale/interrupted tasks
public struct Monitor {
    public let storage: Storage
    public let verbose: Bool
    
    public init(storage: Storage, verbose: Bool) {
        self.storage = storage
        self.verbose = verbose
    }
    
    public func log(_ message: String) {
        if verbose {
            FileHandle.standardError.write("[MONITOR DEBUG] \(message)\n".data(using: .utf8)!)
        }
    }
    
    /// Check all running tasks and mark interrupted ones
    public func checkRunningTasks() async throws -> [String] {
        log("Checking running tasks...")
        
        let running = try await storage.getRunningTasks()
        var interrupted: [String] = []
        let now = Int64(Date().timeIntervalSince1970)
        
        // Grace period: 2 minutes
        let gracePeriod: Int64 = 120
        
        for run in running {
            guard let pid = run.pid else {
                log("Task \(run.id) has no PID, checking detail file...")
                if try await syncFromDetail(id: run.id) {
                    log("Task \(run.id) synced from detail file")
                } else {
                    log("Task \(run.id) has no detail, marking as interrupted")
                    try await storage.markInterrupted(id: run.id)
                    interrupted.append(run.id)
                }
                continue
            }
            
            log("Checking task \(run.id) (pid=\(pid), started_epoch=\(run.startedAtEpoch ?? 0))")
            
            // Check grace period
            if let started = run.startedAtEpoch {
                let age = now - started
                if age < gracePeriod {
                    log("Task \(run.id) within grace period (\(age)s old), skipping")
                    continue
                }
            }
            
            if !isProcessRunning(pid: pid) {
                log("Process \(pid) not running, checking detail file...")
                if try await syncFromDetail(id: run.id) {
                    log("Task \(run.id) synced from detail file")
                } else {
                    log("Task \(run.id) has no detail, marking as interrupted")
                    try await storage.markInterrupted(id: run.id)
                    interrupted.append(run.id)
                }
            } else if isPidReused(pid: pid, recordedStart: run.startedAtEpoch) {
                log("PID \(pid) reused, checking detail file...")
                if try await syncFromDetail(id: run.id) {
                    log("Task \(run.id) synced from detail file")
                } else {
                    log("Task \(run.id) has no detail, marking as interrupted")
                    try await storage.markInterrupted(id: run.id)
                    interrupted.append(run.id)
                }
            } else {
                log("Task \(run.id) still running")
            }
        }
        
        return interrupted
    }
    
    /// Try to sync index from detail file (returns true if synced)
    private func syncFromDetail(id: String) async throws -> Bool {
        if let detail = try await storage.loadRunDetail(id: id) {
            // Detail exists with exit_code, sync to index
            try await storage.updateRun(id: id, exitCode: detail.exitCode, finishedAt: detail.finishedAt)
            return true
        }
        return false
    }
    
    /// Check if a process is running
    private func isProcessRunning(pid: Int) -> Bool {
        // Send signal 0 to check if process exists
        return kill(Int32(pid), 0) == 0
    }
    
    /// Check if a PID has been reused
    private func isPidReused(pid: Int, recordedStart: Int64?) -> Bool {
        guard let recorded = recordedStart else { return false }
        guard let current = getProcessStartTime(pid: pid) else { return false }
        
        // If process started more than 5 seconds after recorded time, it's likely reused
        return abs(current - recorded) > 5
    }
    
    /// Get process start time using ps
    private func getProcessStartTime(pid: Int) -> Int64? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-o", "lstart=", "-p", String(pid)]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0 else { return nil }
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let lstart = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !lstart.isEmpty else { return nil }
            
            // Parse "Mon Jan 25 08:00:00 2026" format
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE MMM dd HH:mm:ss yyyy"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            
            if let date = formatter.date(from: lstart) {
                return Int64(date.timeIntervalSince1970)
            }
        } catch {
            return nil
        }
        
        return nil
    }
}
