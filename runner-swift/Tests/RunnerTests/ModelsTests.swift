import XCTest
@testable import runner

final class ModelsTests: XCTestCase {
    
    // MARK: - Task Tests
    
    func testTaskDecoding() throws {
        let json = """
        {
            "id": "heartbeat",
            "type": "simple",
            "description": "Test task",
            "timeout": 60,
            "command": "echo hello"
        }
        """.data(using: .utf8)!
        
        let task = try JSONDecoder().decode(Task.self, from: json)
        XCTAssertEqual(task.id, "heartbeat")
        XCTAssertEqual(task.type, .simple)
        XCTAssertEqual(task.description, "Test task")
        XCTAssertEqual(task.timeout, 60)
        XCTAssertEqual(task.command, "echo hello")
        XCTAssertNil(task.prompt)
    }
    
    func testAgentTaskDecoding() throws {
        let json = """
        {
            "id": "clock",
            "type": "agent",
            "description": "Agent task",
            "timeout": 300,
            "prompt": "Say hello",
            "model": "sonnet"
        }
        """.data(using: .utf8)!
        
        let task = try JSONDecoder().decode(Task.self, from: json)
        XCTAssertEqual(task.id, "clock")
        XCTAssertEqual(task.type, .agent)
        XCTAssertEqual(task.prompt, "Say hello")
        XCTAssertEqual(task.model, "sonnet")
        XCTAssertNil(task.command)
    }
    
    func testManualTaskDecoding() throws {
        let json = """
        {
            "id": "manual",
            "type": "manual",
            "description": "Manual task",
            "timeout": 60
        }
        """.data(using: .utf8)!
        
        let task = try JSONDecoder().decode(Task.self, from: json)
        XCTAssertEqual(task.type, .manual)
    }
    
    // MARK: - Schedule Tests
    
    func testScheduleWithNumbers() throws {
        let json = """
        {
            "task": "morning",
            "hour": 9,
            "minute": 0,
            "weekday": 1
        }
        """.data(using: .utf8)!
        
        let schedule = try JSONDecoder().decode(Schedule.self, from: json)
        XCTAssertEqual(schedule.task, "morning")
        XCTAssertEqual(schedule.hour.value as? Int, 9)
        XCTAssertEqual(schedule.minute.value as? Int, 0)
        XCTAssertEqual(schedule.weekday.value as? Int, 1)
    }
    
    func testScheduleWithWildcards() throws {
        let json = """
        {
            "task": "heartbeat",
            "hour": "*",
            "minute": "*/10",
            "weekday": "*"
        }
        """.data(using: .utf8)!
        
        let schedule = try JSONDecoder().decode(Schedule.self, from: json)
        XCTAssertEqual(schedule.hour.value as? String, "*")
        XCTAssertEqual(schedule.minute.value as? String, "*/10")
        XCTAssertEqual(schedule.weekday.value as? String, "*")
    }
    
    // MARK: - RunSummary Tests
    
    func testRunSummaryRunning() throws {
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
        XCTAssertEqual(run.id, "abc-123")
        XCTAssertEqual(run.task, "test")
        XCTAssertNil(run.exitCode)
        XCTAssertNil(run.finishedAt)
        XCTAssertEqual(run.pid, 12345)
        XCTAssertEqual(run.startedAtEpoch, 1769306400)
    }
    
    func testRunSummaryCompleted() throws {
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
        XCTAssertEqual(run.exitCode, 0)
        XCTAssertEqual(run.finishedAt, "2026-01-25T08:00:10Z")
        XCTAssertNil(run.pid)
    }
    
    func testRunSummaryFailed() throws {
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
        XCTAssertEqual(run.exitCode, 1)
    }
    
    func testRunSummaryInterrupted() throws {
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
        XCTAssertEqual(run.exitCode, -1)
    }
    
    // MARK: - RunsIndex Tests
    
    func testRunsIndexDecoding() throws {
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
        XCTAssertEqual(index.runs.count, 2)
        XCTAssertEqual(index.total, 2)
        XCTAssertEqual(index.runs[0].exitCode, 0)
        XCTAssertNil(index.runs[1].exitCode)
    }
    
    // MARK: - RunDetail Tests
    
    func testRunDetailDecoding() throws {
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
        XCTAssertEqual(detail.id, "abc-123")
        XCTAssertEqual(detail.task, "heartbeat")
        XCTAssertEqual(detail.trigger, "scheduled")
        XCTAssertEqual(detail.durationSeconds, 5)
        XCTAssertEqual(detail.exitCode, 0)
    }
    
    // MARK: - Encoding Tests
    
    func testRunSummaryEncoding() throws {
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
        
        XCTAssertEqual(decoded.id, run.id)
        XCTAssertEqual(decoded.task, run.task)
        XCTAssertEqual(decoded.exitCode, run.exitCode)
    }
}
