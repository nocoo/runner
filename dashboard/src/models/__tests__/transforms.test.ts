import { describe, test, expect } from "bun:test";
import {
  runsToHeatmap,
  runsToTrend,
  groupRunsByTask,
  combineTasksWithSchedules,
  calculateSuccessRate,
  sortRunsByDate,
} from "../transforms";
import type { RunSummary, Task, Schedule } from "../types";

describe("transforms", () => {
  const sampleRuns: RunSummary[] = [
    { id: "1", task: "heartbeat", exit_code: 0, finished_at: "2026-01-20T10:00:00Z" },
    { id: "2", task: "heartbeat", exit_code: 0, finished_at: "2026-01-20T11:00:00Z" },
    { id: "3", task: "heartbeat", exit_code: 1, finished_at: "2026-01-20T12:00:00Z" },
    { id: "4", task: "morning_briefing", exit_code: 0, finished_at: "2026-01-21T09:00:00Z" },
    { id: "5", task: "heartbeat", exit_code: 0, finished_at: "2026-01-21T10:00:00Z" },
  ];

  describe("runsToHeatmap", () => {
    test("converts runs to heatmap cells grouped by date", () => {
      const result = runsToHeatmap(sampleRuns);
      
      expect(result.length).toBe(2);
      
      const jan20 = result.find(c => c.date === "2026-01-20");
      expect(jan20).toBeDefined();
      expect(jan20!.count).toBe(3);
      expect(jan20!.success).toBe(2);
      expect(jan20!.failed).toBe(1);
      
      const jan21 = result.find(c => c.date === "2026-01-21");
      expect(jan21).toBeDefined();
      expect(jan21!.count).toBe(2);
      expect(jan21!.success).toBe(2);
      expect(jan21!.failed).toBe(0);
    });

    test("returns empty array for empty runs", () => {
      expect(runsToHeatmap([])).toEqual([]);
    });
  });

  describe("runsToTrend", () => {
    test("converts runs to trend points", () => {
      const result = runsToTrend(sampleRuns);
      
      expect(result.length).toBe(2);
      
      const jan20 = result.find(p => p.date === "2026-01-20");
      expect(jan20).toBeDefined();
      expect(jan20!.total).toBe(3);
      expect(jan20!.success).toBe(2);
      expect(jan20!.successRate).toBeCloseTo(0.667, 2);
      
      const jan21 = result.find(p => p.date === "2026-01-21");
      expect(jan21).toBeDefined();
      expect(jan21!.total).toBe(2);
      expect(jan21!.success).toBe(2);
      expect(jan21!.successRate).toBe(1);
    });

    test("returns empty array for empty runs", () => {
      expect(runsToTrend([])).toEqual([]);
    });
  });

  describe("groupRunsByTask", () => {
    test("groups runs by task name", () => {
      const result = groupRunsByTask(sampleRuns);
      
      expect(result.heartbeat).toBeDefined();
      expect(result.heartbeat.length).toBe(4);
      
      expect(result.morning_briefing).toBeDefined();
      expect(result.morning_briefing.length).toBe(1);
    });

    test("returns empty object for empty runs", () => {
      expect(groupRunsByTask([])).toEqual({});
    });
  });

  describe("combineTasksWithSchedules", () => {
    const tasks: Task[] = [
      { id: "heartbeat", description: "Heartbeat", prompt_file: "tasks/heartbeat.md", timeout: 60 },
      { id: "morning_briefing", description: "Morning Briefing", prompt_file: "tasks/morning.md", timeout: 300 },
    ];

    const schedules: Schedule[] = [
      { task: "heartbeat", hour: "*", minute: 20, weekday: "*" },
      { task: "heartbeat", hour: "*", minute: 50, weekday: "*" },
      { task: "morning_briefing", hour: 9, minute: 0, weekday: "*" },
    ];

    test("combines tasks with their schedules", () => {
      const result = combineTasksWithSchedules(tasks, schedules);
      
      expect(result.length).toBe(2);
      
      const heartbeat = result.find(t => t.id === "heartbeat");
      expect(heartbeat).toBeDefined();
      expect(heartbeat!.schedules.length).toBe(2);
      
      const morning = result.find(t => t.id === "morning_briefing");
      expect(morning).toBeDefined();
      expect(morning!.schedules.length).toBe(1);
    });

    test("handles tasks with no schedules", () => {
      const tasksWithNoSchedule: Task[] = [
        { id: "orphan", description: "Orphan Task", prompt_file: "tasks/orphan.md", timeout: 60 },
      ];
      
      const result = combineTasksWithSchedules(tasksWithNoSchedule, schedules);
      
      expect(result.length).toBe(1);
      expect(result[0].schedules).toEqual([]);
    });
  });

  describe("calculateSuccessRate", () => {
    test("calculates success rate from runs", () => {
      expect(calculateSuccessRate(sampleRuns)).toBeCloseTo(0.8, 2);
    });

    test("returns 0 for empty runs", () => {
      expect(calculateSuccessRate([])).toBe(0);
    });

    test("returns 1 for all successful runs", () => {
      const allSuccess: RunSummary[] = [
        { id: "1", task: "test", exit_code: 0, finished_at: "2026-01-20T10:00:00Z" },
        { id: "2", task: "test", exit_code: 0, finished_at: "2026-01-20T11:00:00Z" },
      ];
      expect(calculateSuccessRate(allSuccess)).toBe(1);
    });

    test("returns 0 for all failed runs", () => {
      const allFailed: RunSummary[] = [
        { id: "1", task: "test", exit_code: 1, finished_at: "2026-01-20T10:00:00Z" },
        { id: "2", task: "test", exit_code: 2, finished_at: "2026-01-20T11:00:00Z" },
      ];
      expect(calculateSuccessRate(allFailed)).toBe(0);
    });
  });

  describe("sortRunsByDate", () => {
    test("sorts runs by finished_at descending (newest first)", () => {
      const result = sortRunsByDate(sampleRuns, "desc");
      
      expect(result[0].id).toBe("5");
      expect(result[4].id).toBe("1");
    });

    test("sorts runs by finished_at ascending (oldest first)", () => {
      const result = sortRunsByDate(sampleRuns, "asc");
      
      expect(result[0].id).toBe("1");
      expect(result[4].id).toBe("5");
    });

    test("does not mutate original array", () => {
      const original = [...sampleRuns];
      sortRunsByDate(sampleRuns, "desc");
      expect(sampleRuns).toEqual(original);
    });
  });
});
