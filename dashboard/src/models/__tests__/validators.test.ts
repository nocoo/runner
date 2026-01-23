import { describe, test, expect } from "bun:test";
import {
  isValidUUID,
  isValidISODate,
  isValidExitCode,
  isValidSystemState,
  isValidTask,
  isValidSchedule,
  isValidRunSummary,
  isValidRunDetail,
} from "../validators";

describe("validators", () => {
  describe("isValidUUID", () => {
    test("returns true for valid UUID", () => {
      expect(isValidUUID("123e4567-e89b-12d3-a456-426614174000")).toBe(true);
      expect(isValidUUID("819585c4-03ba-4966-9b10-b0afd33b4d4f")).toBe(true);
    });

    test("returns false for invalid UUID", () => {
      expect(isValidUUID("")).toBe(false);
      expect(isValidUUID("not-a-uuid")).toBe(false);
      expect(isValidUUID("123e4567-e89b-12d3-a456")).toBe(false);
      expect(isValidUUID(null as unknown as string)).toBe(false);
      expect(isValidUUID(undefined as unknown as string)).toBe(false);
    });
  });

  describe("isValidISODate", () => {
    test("returns true for valid ISO date", () => {
      expect(isValidISODate("2026-01-23T22:30:08Z")).toBe(true);
      expect(isValidISODate("2026-01-23T22:30:08.123Z")).toBe(true);
      expect(isValidISODate("2026-01-23T22:30:08+00:00")).toBe(true);
    });

    test("returns false for invalid date", () => {
      expect(isValidISODate("")).toBe(false);
      expect(isValidISODate("not-a-date")).toBe(false);
      expect(isValidISODate("2026-13-45")).toBe(false);
      expect(isValidISODate(null as unknown as string)).toBe(false);
    });
  });

  describe("isValidExitCode", () => {
    test("returns true for valid exit codes", () => {
      expect(isValidExitCode(0)).toBe(true);
      expect(isValidExitCode(1)).toBe(true);
      expect(isValidExitCode(255)).toBe(true);
    });

    test("returns false for invalid exit codes", () => {
      expect(isValidExitCode(-1)).toBe(false);
      expect(isValidExitCode(256)).toBe(false);
      expect(isValidExitCode(1.5)).toBe(false);
      expect(isValidExitCode(NaN)).toBe(false);
      expect(isValidExitCode(null as unknown as number)).toBe(false);
    });
  });

  describe("isValidSystemState", () => {
    test("returns true for valid state", () => {
      const validState = {
        version: "1.0.0",
        last_run: {
          id: "123e4567-e89b-12d3-a456-426614174000",
          task: "heartbeat",
          exit_code: 0,
          finished_at: "2026-01-23T22:30:08Z",
        },
        next_scheduled: null,
        total_runs_today: 10,
        success_rate_today: 0.8,
      };
      expect(isValidSystemState(validState)).toBe(true);
    });

    test("returns true for state with null last_run", () => {
      const validState = {
        version: "1.0.0",
        last_run: null,
        next_scheduled: null,
        total_runs_today: 0,
        success_rate_today: 0,
      };
      expect(isValidSystemState(validState)).toBe(true);
    });

    test("returns false for invalid state", () => {
      expect(isValidSystemState(null)).toBe(false);
      expect(isValidSystemState({})).toBe(false);
      expect(isValidSystemState({ version: "1.0.0" })).toBe(false);
    });
  });

  describe("isValidTask", () => {
    test("returns true for valid task", () => {
      const validTask = {
        id: "heartbeat",
        description: "Heartbeat check",
        prompt_file: "tasks/heartbeat.md",
        timeout: 300,
      };
      expect(isValidTask(validTask)).toBe(true);
    });

    test("returns false for invalid task", () => {
      expect(isValidTask(null)).toBe(false);
      expect(isValidTask({})).toBe(false);
      expect(isValidTask({ id: "test" })).toBe(false);
    });
  });

  describe("isValidSchedule", () => {
    test("returns true for valid schedule with numeric values", () => {
      const validSchedule = {
        task: "heartbeat",
        hour: 9,
        minute: 0,
        weekday: 1,
      };
      expect(isValidSchedule(validSchedule)).toBe(true);
    });

    test("returns true for schedule with wildcard hour", () => {
      const validSchedule = {
        task: "heartbeat",
        hour: "*",
        minute: 20,
        weekday: "*",
      };
      expect(isValidSchedule(validSchedule)).toBe(true);
    });

    test("returns false for invalid schedule", () => {
      expect(isValidSchedule(null)).toBe(false);
      expect(isValidSchedule({ task: "test" })).toBe(false);
      expect(isValidSchedule({ task: "test", hour: 25, minute: 0, weekday: 0 })).toBe(false);
      expect(isValidSchedule({ task: "test", hour: 9, minute: 60, weekday: 0 })).toBe(false);
    });
  });

  describe("isValidRunSummary", () => {
    test("returns true for valid run summary", () => {
      const validRun = {
        id: "819585c4-03ba-4966-9b10-b0afd33b4d4f",
        task: "heartbeat",
        exit_code: 0,
        finished_at: "2026-01-23T01:21:22Z",
      };
      expect(isValidRunSummary(validRun)).toBe(true);
    });

    test("returns false for invalid run summary", () => {
      expect(isValidRunSummary(null)).toBe(false);
      expect(isValidRunSummary({ id: "invalid-uuid", task: "test", exit_code: 0, finished_at: "2026-01-23T01:21:22Z" })).toBe(false);
    });
  });

  describe("isValidRunDetail", () => {
    test("returns true for valid run detail", () => {
      const validRun = {
        id: "819585c4-03ba-4966-9b10-b0afd33b4d4f",
        task: "heartbeat",
        trigger: "auto",
        started_at: "2026-01-23T01:20:00Z",
        finished_at: "2026-01-23T01:21:22Z",
        duration_seconds: 82,
        exit_code: 0,
        output_preview: "Task completed",
      };
      expect(isValidRunDetail(validRun)).toBe(true);
    });

    test("returns true for minimal valid run detail", () => {
      const validRun = {
        id: "819585c4-03ba-4966-9b10-b0afd33b4d4f",
        task: "heartbeat",
        trigger: "manual",
        started_at: "2026-01-23T01:20:00Z",
        exit_code: 0,
      };
      expect(isValidRunDetail(validRun)).toBe(true);
    });

    test("returns false for invalid trigger", () => {
      const invalidRun = {
        id: "819585c4-03ba-4966-9b10-b0afd33b4d4f",
        task: "heartbeat",
        trigger: "invalid",
        started_at: "2026-01-23T01:20:00Z",
        exit_code: 0,
      };
      expect(isValidRunDetail(invalidRun)).toBe(false);
    });
  });
});
