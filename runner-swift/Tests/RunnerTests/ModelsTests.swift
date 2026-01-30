import Testing
import Foundation
@testable import RunnerLib

@Suite("Models Tests")
struct ModelsTests {
    
    // MARK: - Task Tests
    
    @Test("Task decoding - simple type")
    func taskDecodingSimple() throws {
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
        #expect(task.id == "heartbeat")
        #expect(task.type == .simple)
        #expect(task.description == "Test task")
        #expect(task.timeout == 60)
        #expect(task.command == "echo hello")
        #expect(task.prompt == nil)
        #expect(task.workdir == nil)
    }
    
    @Test("Task decoding - agent type with prompt")
    func taskDecodingAgent() throws {
        let json = """
        {
            "id": "clock",
            "type": "agent",
            "description": "Clock chime",
            "timeout": 60,
            "prompt": "Announce the time"
        }
        """.data(using: .utf8)!
        
        let task = try JSONDecoder().decode(Task.self, from: json)
        #expect(task.id == "clock")
        #expect(task.type == .agent)
        #expect(task.prompt == "Announce the time")
        #expect(task.command == nil)
    }
    
    @Test("Task with workdir")
    func taskWithWorkdir() throws {
        let json = """
        {
            "id": "task",
            "type": "simple",
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
    
    @Test("RunsIndex decoding with missing total and updated_at")
    func runsIndexDecodingMissingFields() throws {
        // This tests the fallback behavior when total and updated_at are missing
        // (e.g., after data corruption or manual rebuild from detail files)
        let json = """
        {
            "runs": [
                {
                    "id": "run-1",
                    "task": "heartbeat",
                    "exit_code": 0,
                    "started_at": "2026-01-25T08:00:00Z"
                }
            ]
        }
        """.data(using: .utf8)!
        
        let index = try JSONDecoder().decode(RunsIndex.self, from: json)
        #expect(index.runs.count == 1)
        #expect(index.total == 1)  // Fallback: computed from runs.count
        #expect(index.updatedAt == "")  // Fallback: empty string
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
    
    @Test("RunsIndex decoding with empty runs array")
    func runsIndexDecodingEmptyRuns() throws {
        let json = """
        {
            "runs": []
        }
        """.data(using: .utf8)!
        
        let index = try JSONDecoder().decode(RunsIndex.self, from: json)
        #expect(index.runs.count == 0)
        #expect(index.total == 0)
    }
    
    @Test("RunsIndex encoding preserves all fields")
    func runsIndexEncoding() throws {
        let index = RunsIndex(
            runs: [],
            total: 5,
            updatedAt: "2026-01-28T00:00:00Z"
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(index)
        let decoded = try JSONDecoder().decode(RunsIndex.self, from: data)
        
        #expect(decoded.total == 5)
        #expect(decoded.updatedAt == "2026-01-28T00:00:00Z")
    }
    
    // MARK: - RunSummary Compatibility Tests
    
    @Test("RunSummary ignores extra fields from detail.json format")
    func runSummaryIgnoresExtraFields() throws {
        // When index.json is rebuilt from detail.json files, extra fields may be present
        // RunSummary should ignore unknown fields (default Swift behavior)
        let json = """
        {
            "id": "abc-123",
            "task": "heartbeat",
            "trigger": "manual",
            "started_at": "2026-01-25T08:00:00Z",
            "finished_at": "2026-01-25T08:00:05Z",
            "duration_seconds": 5,
            "exit_code": 0
        }
        """.data(using: .utf8)!
        
        let run = try JSONDecoder().decode(RunSummary.self, from: json)
        #expect(run.id == "abc-123")
        #expect(run.exitCode == 0)
        // Extra fields (trigger, duration_seconds) are silently ignored
    }
    
    @Test("RunSummary with minimal fields")
    func runSummaryMinimalFields() throws {
        // Minimum required fields for RunSummary
        let json = """
        {
            "id": "abc-123",
            "task": "heartbeat",
            "started_at": "2026-01-25T08:00:00Z"
        }
        """.data(using: .utf8)!
        
        let run = try JSONDecoder().decode(RunSummary.self, from: json)
        #expect(run.id == "abc-123")
        #expect(run.task == "heartbeat")
        #expect(run.exitCode == nil)
        #expect(run.finishedAt == nil)
        #expect(run.pid == nil)
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

    // MARK: - SystemState Tests

    @Test("SystemState encoding and decoding")
    func systemStateEncodingDecoding() throws {
        let lastRun = LastRun(id: "run-1", task: "test", exitCode: 0, finishedAt: "2026-01-25T08:00:10Z")
        let state = SystemState(
            version: "1.2.3",
            lastRun: lastRun,
            totalRunsToday: 5,
            successRateToday: 0.8
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(SystemState.self, from: data)

        #expect(decoded.version == "1.2.3")
        #expect(decoded.lastRun?.id == "run-1")
        #expect(decoded.totalRunsToday == 5)
        #expect(decoded.successRateToday == 0.8)
    }

    @Test("LastRun decoding")
    func lastRunDecoding() throws {
        let json = """
        {
            "id": "run-2",
            "task": "clock",
            "exit_code": 1,
            "finished_at": "2026-01-25T08:00:10Z"
        }
        """.data(using: .utf8)!

        let lastRun = try JSONDecoder().decode(LastRun.self, from: json)
        #expect(lastRun.exitCode == 1)
        #expect(lastRun.finishedAt == "2026-01-25T08:00:10Z")
    }

    // MARK: - AnyCodable Tests

    @Test("AnyCodable decodes int")
    func anyCodableDecodesInt() throws {
        let json = """
        {"value": 5}
        """.data(using: .utf8)!

        struct Wrapper: Decodable {
            let value: AnyCodable
        }

        let decoded = try JSONDecoder().decode(Wrapper.self, from: json)
        #expect(decoded.value.value as? Int == 5)
    }

    @Test("AnyCodable decodes string")
    func anyCodableDecodesString() throws {
        let json = """
        {"value": "*/15"}
        """.data(using: .utf8)!

        struct Wrapper: Decodable {
            let value: AnyCodable
        }

        let decoded = try JSONDecoder().decode(Wrapper.self, from: json)
        #expect(decoded.value.value as? String == "*/15")
    }

    @Test("AnyCodable decodes fallback")
    func anyCodableDecodesFallback() throws {
        let json = """
        {"value": true}
        """.data(using: .utf8)!

        struct Wrapper: Decodable {
            let value: AnyCodable
        }

        let decoded = try JSONDecoder().decode(Wrapper.self, from: json)
        #expect(decoded.value.value as? String == "*")
    }

    @Test("AnyCodable encodes int")
    func anyCodableEncodesInt() throws {
        let wrapper = EncodedWrapper(value: AnyCodable(3))
        let data = try JSONEncoder().encode(wrapper)
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(decoded?["value"] as? Int == 3)
    }

    @Test("AnyCodable encodes string")
    func anyCodableEncodesString() throws {
        let wrapper = EncodedWrapper(value: AnyCodable("*/10"))
        let data = try JSONEncoder().encode(wrapper)
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(decoded?["value"] as? String == "*/10")
    }

    @Test("AnyCodable encodes fallback")
    func anyCodableEncodesFallback() throws {
        let wrapper = EncodedWrapper(value: AnyCodable(["a": 1]))
        let data = try JSONEncoder().encode(wrapper)
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(decoded?["value"] as? String == "*")
    }

    private struct EncodedWrapper: Encodable {
        let value: AnyCodable
    }
}
