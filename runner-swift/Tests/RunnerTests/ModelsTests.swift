import Testing
@testable import RunnerLib

@Suite("Models Tests")
struct ModelsTests {
    
    // MARK: - Task Tests
    
    @Test("Task decoding")
    func taskDecoding() throws {
        let json = """
        {
            "id": "heartbeat",
            "description": "Test task",
            "timeout": 60,
            "command": "echo hello"
        }
        """.data(using: .utf8)!
        
        let task = try JSONDecoder().decode(Task.self, from: json)
        #expect(task.id == "heartbeat")
        #expect(task.description == "Test task")
        #expect(task.timeout == 60)
        #expect(task.command == "echo hello")
        #expect(task.workdir == nil)
    }
    
    @Test("Task with workdir")
    func taskWithWorkdir() throws {
        let json = """
        {
            "id": "task",
            "description": "Task with workdir",
            "timeout": 300,
            "command": "pwd",
            "workdir": "/tmp"
        }
        """.data(using: .utf8)!
        
        let task = try JSONDecoder().decode(Task.self, from: json)
        #expect(task.id == "task")
        #expect(task.workdir == "/tmp")
    }
    
    // MARK: - Schedule Tests
    
    @Test("Schedule with numbers")
    func scheduleWithNumbers() throws {
        let json = """
        {
            "task": "morning",
            "hour": 9,
            "minute": 0,
            "weekday": 1
        }
        """.data(using: .utf8)!
        
        let schedule = try JSONDecoder().decode(Schedule.self, from: json)
        #expect(schedule.task == "morning")
        #expect(schedule.hour.value as? Int == 9)
        #expect(schedule.minute.value as? Int == 0)
        #expect(schedule.weekday.value as? Int == 1)
    }
    
    @Test("Schedule with wildcards")
    func scheduleWithWildcards() throws {
        let json = """
        {
            "task": "heartbeat",
            "hour": "*",
            "minute": "*/10",
            "weekday": "*"
        }
        """.data(using: .utf8)!
        
        let schedule = try JSONDecoder().decode(Schedule.self, from: json)
        #expect(schedule.hour.value as? String == "*")
        #expect(schedule.minute.value as? String == "*/10")
        #expect(schedule.weekday.value as? String == "*")
    }
    
    // MARK: - RunSummary Tests
    
    @Test("RunSummary running")
    func runSummaryRunning() throws {
        let json = """
        {
            "id": "abc-123",
            "task": "test",
            "exit_code": null,
            "started_at": "2026-01-25T08:00:00Z",
            "finished_at": null,
            "pid": 12345,
            "started_at_epoch": 1769306400
        }
        """.data(using: .utf8)!
        
        let run = try JSONDecoder().decode(RunSummary.self, from: json)
        #expect(run.id == "abc-123")
        #expect(run.task == "test")
        #expect(run.exitCode == nil)
        #expect(run.finishedAt == nil)
        #expect(run.pid == 12345)
        #expect(run.startedAtEpoch == 1769306400)
    }
    
    @Test("RunSummary completed")
    func runSummaryCompleted() throws {
        let json = """
        {
            "id": "abc-123",
            "task": "test",
            "exit_code": 0,
            "started_at": "2026-01-25T08:00:00Z",
            "finished_at": "2026-01-25T08:00:10Z"
        }
        """.data(using: .utf8)!
        
        let run = try JSONDecoder().decode(RunSummary.self, from: json)
        #expect(run.exitCode == 0)
        #expect(run.finishedAt == "2026-01-25T08:00:10Z")
        #expect(run.pid == nil)
    }
    
    @Test("RunSummary failed")
    func runSummaryFailed() throws {
        let json = """
        {
            "id": "abc-123",
            "task": "test",
            "exit_code": 1,
            "started_at": "2026-01-25T08:00:00Z",
            "finished_at": "2026-01-25T08:00:10Z"
        }
        """.data(using: .utf8)!
        
        let run = try JSONDecoder().decode(RunSummary.self, from: json)
        #expect(run.exitCode == 1)
    }
    
    @Test("RunSummary interrupted")
    func runSummaryInterrupted() throws {
        let json = """
        {
            "id": "abc-123",
            "task": "test",
            "exit_code": -1,
            "started_at": "2026-01-25T08:00:00Z",
            "finished_at": "2026-01-25T08:00:10Z"
        }
        """.data(using: .utf8)!
        
        let run = try JSONDecoder().decode(RunSummary.self, from: json)
        #expect(run.exitCode == -1)
    }
    
    // MARK: - RunsIndex Tests
    
    @Test("RunsIndex decoding")
    func runsIndexDecoding() throws {
        let json = """
        {
            "runs": [
                {
                    "id": "run-1",
                    "task": "heartbeat",
                    "exit_code": 0,
                    "started_at": "2026-01-25T08:00:00Z",
                    "finished_at": "2026-01-25T08:00:01Z"
                },
                {
                    "id": "run-2",
                    "task": "clock",
                    "exit_code": null,
                    "started_at": "2026-01-25T08:01:00Z",
                    "finished_at": null,
                    "pid": 1234
                }
            ],
            "total": 2,
            "updated_at": "2026-01-25T08:01:00Z"
        }
        """.data(using: .utf8)!
        
        let index = try JSONDecoder().decode(RunsIndex.self, from: json)
        #expect(index.runs.count == 2)
        #expect(index.total == 2)
        #expect(index.runs[0].exitCode == 0)
        #expect(index.runs[1].exitCode == nil)
    }
    
    // MARK: - RunDetail Tests
    
    @Test("RunDetail decoding")
    func runDetailDecoding() throws {
        let json = """
        {
            "id": "abc-123",
            "task": "heartbeat",
            "trigger": "scheduled",
            "started_at": "2026-01-25T08:00:00Z",
            "finished_at": "2026-01-25T08:00:05Z",
            "duration_seconds": 5,
            "exit_code": 0
        }
        """.data(using: .utf8)!
        
        let detail = try JSONDecoder().decode(RunDetail.self, from: json)
        #expect(detail.id == "abc-123")
        #expect(detail.task == "heartbeat")
        #expect(detail.trigger == "scheduled")
        #expect(detail.durationSeconds == 5)
        #expect(detail.exitCode == 0)
    }
    
    // MARK: - Encoding Tests
    
    @Test("RunSummary encoding")
    func runSummaryEncoding() throws {
        let run = RunSummary(
            id: "test-123",
            task: "heartbeat",
            exitCode: 0,
            startedAt: "2026-01-25T08:00:00Z",
            finishedAt: "2026-01-25T08:00:01Z",
            pid: nil,
            startedAtEpoch: nil
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(run)
        let decoded = try JSONDecoder().decode(RunSummary.self, from: data)
        
        #expect(decoded.id == run.id)
        #expect(decoded.task == run.task)
        #expect(decoded.exitCode == run.exitCode)
    }
}
