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
    test("converts runs to heatmap cells grouped by date and 2-hour slot", () => {
      const result = runsToHeatmap(sampleRuns);
      
      // Runs at 10:00, 11:00 -> slot 10; 12:00 -> slot 12; 09:00 -> slot 08; 10:00 -> slot 10
      // So: 2026-01-20T10 (2 runs), 2026-01-20T12 (1 run), 2026-01-21T08 (1 run), 2026-01-21T10 (1 run)
      expect(result.length).toBe(4);
      
      const jan20_10 = result.find(c => c.date === "2026-01-20T10:00:00");
      expect(jan20_10).toBeDefined();
      expect(jan20_10!.count).toBe(2); // 10:00 and 11:00 both map to slot 10
      expect(jan20_10!.success).toBe(2);
      expect(jan20_10!.failed).toBe(0);
      
      const jan20_12 = result.find(c => c.date === "2026-01-20T12:00:00");
      expect(jan20_12).toBeDefined();
      expect(jan20_12!.count).toBe(1);
      expect(jan20_12!.success).toBe(0);
      expect(jan20_12!.failed).toBe(1);
    });

    test("aggregates multiple runs in same 2-hour slot", () => {
      const runsInSameSlot: RunSummary[] = [
        { id: "1", task: "heartbeat", exit_code: 0, finished_at: "2026-01-20T10:05:00Z" },
        { id: "2", task: "heartbeat", exit_code: 0, finished_at: "2026-01-20T10:15:00Z" },
        { id: "3", task: "heartbeat", exit_code: 1, finished_at: "2026-01-20T11:25:00Z" },
      ];
      const result = runsToHeatmap(runsInSameSlot);
      
      expect(result.length).toBe(1);
      expect(result[0].date).toBe("2026-01-20T10:00:00");
      expect(result[0].count).toBe(3);
      expect(result[0].success).toBe(2);
      expect(result[0].failed).toBe(1);
    });

    test("excludes runs outside 4am-8pm range", () => {
      const nightRuns: RunSummary[] = [
        { id: "1", task: "heartbeat", exit_code: 0, finished_at: "2026-01-20T03:00:00Z" }, // before 4am
        { id: "2", task: "heartbeat", exit_code: 0, finished_at: "2026-01-20T10:00:00Z" }, // within range
        { id: "3", task: "heartbeat", exit_code: 0, finished_at: "2026-01-20T21:00:00Z" }, // after 8pm
      ];
      const result = runsToHeatmap(nightRuns);
      
      expect(result.length).toBe(1);
      expect(result[0].date).toBe("2026-01-20T10:00:00");
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
      { id: "heartbeat", type: "simple", description: "Heartbeat", timeout: 60, command: "afplay /System/Library/Sounds/Pop.aiff" },
      { id: "morning_briefing", type: "agent", description: "Morning Briefing", timeout: 300, prompt: "Generate morning briefing" },
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
        { id: "orphan", type: "agent", description: "Orphan Task", timeout: 60, prompt: "Orphan prompt" },
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
