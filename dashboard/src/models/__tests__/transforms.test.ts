import { describe, test, expect } from "bun:test";
import {
  runsToHeatmap,
  runsToTrend,
  groupRunsByTask,
  combineTasksWithSchedules,
  calculateSuccessRate,
  sortRunsByDate,
  filterRunsByDateRange,
  getRunsLastNDays,
  calculateUpcomingTasks,
} from "../transforms";
import type { RunSummary, Task, Schedule } from "../types";

describe("transforms", () => {
  const sampleRuns: RunSummary[] = [
    { id: "1", task: "heartbeat", exit_code: 0, started_at: "2026-01-24T09:00:00Z", finished_at: "2026-01-20T10:00:00Z" },
    { id: "2", task: "heartbeat", exit_code: 0, started_at: "2026-01-24T09:00:00Z", finished_at: "2026-01-20T11:00:00Z" },
    { id: "3", task: "heartbeat", exit_code: 1, started_at: "2026-01-24T09:00:00Z", finished_at: "2026-01-20T12:00:00Z" },
    { id: "4", task: "morning_briefing", exit_code: 0, started_at: "2026-01-24T09:00:00Z", finished_at: "2026-01-21T09:00:00Z" },
    { id: "5", task: "heartbeat", exit_code: 0, started_at: "2026-01-24T09:00:00Z", finished_at: "2026-01-21T10:00:00Z" },
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
        { id: "1", task: "heartbeat", exit_code: 0, started_at: "2026-01-24T09:00:00Z", finished_at: "2026-01-20T10:05:00Z" },
        { id: "2", task: "heartbeat", exit_code: 0, started_at: "2026-01-24T09:00:00Z", finished_at: "2026-01-20T10:15:00Z" },
        { id: "3", task: "heartbeat", exit_code: 1, started_at: "2026-01-24T09:00:00Z", finished_at: "2026-01-20T11:25:00Z" },
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
        { id: "1", task: "heartbeat", exit_code: 0, started_at: "2026-01-24T09:00:00Z", finished_at: "2026-01-20T03:00:00Z" }, // before 4am
        { id: "2", task: "heartbeat", exit_code: 0, started_at: "2026-01-24T09:00:00Z", finished_at: "2026-01-20T10:00:00Z" }, // within range
        { id: "3", task: "heartbeat", exit_code: 0, started_at: "2026-01-24T09:00:00Z", finished_at: "2026-01-20T21:00:00Z" }, // after 8pm
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
    test("converts runs to 10-minute trend points for last 48 hours", () => {
      // Create runs within the last 48 hours using relative timestamps
      const now = new Date();
      // Create a base time that is exactly 2 hours ago at the start of a 10-min slot
      const twoHoursAgoBase = new Date(now.getTime() - 2 * 60 * 60 * 1000);
      twoHoursAgoBase.setMinutes(Math.floor(twoHoursAgoBase.getMinutes() / 10) * 10, 0, 0);
      
      const fiveHoursAgoBase = new Date(now.getTime() - 5 * 60 * 60 * 1000);
      fiveHoursAgoBase.setMinutes(Math.floor(fiveHoursAgoBase.getMinutes() / 10) * 10, 0, 0);

      const makeTimeInSlot = (baseDate: Date, minuteOffset: number) => {
        const d = new Date(baseDate.getTime() + minuteOffset * 60 * 1000);
        return d.toISOString();
      };

      const recentRuns: RunSummary[] = [
        { id: "1", task: "heartbeat", exit_code: 0, started_at: "2026-01-24T09:00:00Z", finished_at: makeTimeInSlot(twoHoursAgoBase, 2) },  // same 10-min slot
        { id: "2", task: "heartbeat", exit_code: 0, started_at: "2026-01-24T09:00:00Z", finished_at: makeTimeInSlot(twoHoursAgoBase, 5) },  // same 10-min slot
        { id: "3", task: "heartbeat", exit_code: 1, started_at: "2026-01-24T09:00:00Z", finished_at: makeTimeInSlot(twoHoursAgoBase, 8) },  // same 10-min slot
        { id: "4", task: "morning_briefing", exit_code: 0, started_at: "2026-01-24T09:00:00Z", finished_at: makeTimeInSlot(fiveHoursAgoBase, 0) },
        { id: "5", task: "heartbeat", exit_code: 0, started_at: "2026-01-24T09:00:00Z", finished_at: makeTimeInSlot(fiveHoursAgoBase, 5) },
      ];

      const result = runsToTrend(recentRuns);

      // Should return 144 slots (24 hours * 6 slots per hour)
      expect(result.length).toBe(144);

      // Check that some slot has runs
      const slotsWithData = result.filter(p => p.total > 0);
      expect(slotsWithData.length).toBeGreaterThan(0);
    });

    test("excludes runs older than 24 hours", () => {
      const oldRuns: RunSummary[] = [
        { id: "1", task: "heartbeat", exit_code: 0, started_at: "2026-01-24T09:00:00Z", finished_at: "2020-01-20T10:00:00Z" },
      ];
      const result = runsToTrend(oldRuns);

      // Should still return 144 slots but all with 0 counts
      expect(result.length).toBe(144);
      expect(result.every(p => p.total === 0)).toBe(true);
    });

    test("returns 144 empty slots for empty runs", () => {
      const result = runsToTrend([]);
      expect(result.length).toBe(144);
      expect(result.every(p => p.total === 0)).toBe(true);
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
        { id: "1", task: "test", exit_code: 0, started_at: "2026-01-24T09:00:00Z", finished_at: "2026-01-20T10:00:00Z" },
        { id: "2", task: "test", exit_code: 0, started_at: "2026-01-24T09:00:00Z", finished_at: "2026-01-20T11:00:00Z" },
      ];
      expect(calculateSuccessRate(allSuccess)).toBe(1);
    });

    test("returns 0 for all failed runs", () => {
      const allFailed: RunSummary[] = [
        { id: "1", task: "test", exit_code: 1, started_at: "2026-01-24T09:00:00Z", finished_at: "2026-01-20T10:00:00Z" },
        { id: "2", task: "test", exit_code: 2, started_at: "2026-01-24T09:00:00Z", finished_at: "2026-01-20T11:00:00Z" },
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

  describe("filterRunsByDateRange", () => {
    test("filters runs within date range", () => {
      const result = filterRunsByDateRange(sampleRuns, "2026-01-20T00:00:00Z", "2026-01-20T23:59:59Z");
      
      expect(result.length).toBe(3);
      expect(result.every(r => r.finished_at?.startsWith("2026-01-20"))).toBe(true);
    });

    test("returns empty array when no runs match range", () => {
      const result = filterRunsByDateRange(sampleRuns, "2025-01-01T00:00:00Z", "2025-01-01T23:59:59Z");
      expect(result.length).toBe(0);
    });

    test("includes runs at range boundaries", () => {
      const result = filterRunsByDateRange(sampleRuns, "2026-01-20T10:00:00Z", "2026-01-20T11:00:00Z");
      expect(result.length).toBe(2);
    });

    test("returns empty array for empty runs", () => {
      expect(filterRunsByDateRange([], "2026-01-20T00:00:00Z", "2026-01-20T23:59:59Z")).toEqual([]);
    });
  });

  describe("getRunsLastNDays", () => {
    test("returns runs from last N days", () => {
      // Create runs with relative dates
      const now = new Date();
      const yesterday = new Date(now.getTime() - 24 * 60 * 60 * 1000);
      const twoDaysAgo = new Date(now.getTime() - 2 * 24 * 60 * 60 * 1000);
      const fiveDaysAgo = new Date(now.getTime() - 5 * 24 * 60 * 60 * 1000);

      const recentRuns: RunSummary[] = [
        { id: "1", task: "test", exit_code: 0, started_at: "2026-01-24T09:00:00Z", finished_at: now.toISOString() },
        { id: "2", task: "test", exit_code: 0, started_at: "2026-01-24T09:00:00Z", finished_at: yesterday.toISOString() },
        { id: "3", task: "test", exit_code: 0, started_at: "2026-01-24T09:00:00Z", finished_at: twoDaysAgo.toISOString() },
        { id: "4", task: "test", exit_code: 0, started_at: "2026-01-24T09:00:00Z", finished_at: fiveDaysAgo.toISOString() },
      ];

      const result = getRunsLastNDays(recentRuns, 3);
      expect(result.length).toBe(3);
      expect(result.map(r => r.id)).toContain("1");
      expect(result.map(r => r.id)).toContain("2");
      expect(result.map(r => r.id)).toContain("3");
    });

    test("returns empty array for empty runs", () => {
      expect(getRunsLastNDays([], 7)).toEqual([]);
    });
  });

  describe("calculateUpcomingTasks", () => {
    const tasks: Task[] = [
      { id: "heartbeat", type: "simple", description: "System heartbeat", timeout: 60, command: "echo heartbeat" },
      { id: "morning_briefing", type: "agent", description: "Morning briefing", timeout: 300, prompt: "Morning" },
      { id: "cleanup", type: "simple", description: "Cleanup task", timeout: 60, command: "echo cleanup" },
    ];

    test("calculates upcoming tasks with wildcard hour/minute", () => {
      const schedules: Schedule[] = [
        { task: "heartbeat", hour: "*", minute: 10, weekday: "*" },
        { task: "heartbeat", hour: "*", minute: 40, weekday: "*" },
      ];

      const result = calculateUpcomingTasks(tasks, schedules, 4);
      
      expect(result.length).toBeGreaterThan(0);
      expect(result.length).toBeLessThanOrEqual(4);
      expect(result[0].task.id).toBe("heartbeat");
      expect(result[0].nextRun).toBeInstanceOf(Date);
      expect(result[0].countdown).toBeGreaterThan(0);
    });

    test("calculates upcoming tasks with specific hour", () => {
      const schedules: Schedule[] = [
        { task: "morning_briefing", hour: 9, minute: 0, weekday: "*" },
      ];

      const result = calculateUpcomingTasks(tasks, schedules, 2);
      
      expect(result.length).toBeGreaterThan(0);
      expect(result[0].task.id).toBe("morning_briefing");
      expect(result[0].nextRun.getHours()).toBe(9);
      expect(result[0].nextRun.getMinutes()).toBe(0);
    });

    test("handles range expressions in weekday", () => {
      const schedules: Schedule[] = [
        { task: "cleanup", hour: 18, minute: 0, weekday: "1-5" }, // Mon-Fri
      ];

      const result = calculateUpcomingTasks(tasks, schedules, 2);
      
      // Should find next weekday match
      expect(result.length).toBeGreaterThan(0);
      const nextRunDay = result[0].nextRun.getDay();
      expect(nextRunDay).toBeGreaterThanOrEqual(1);
      expect(nextRunDay).toBeLessThanOrEqual(5);
    });

    test("handles list expressions in minute", () => {
      const schedules: Schedule[] = [
        { task: "heartbeat", hour: "*", minute: "0,15,30,45", weekday: "*" },
      ];

      const result = calculateUpcomingTasks(tasks, schedules, 4);
      
      expect(result.length).toBeGreaterThan(0);
      const minutes = result.map(r => r.nextRun.getMinutes());
      expect(minutes.every(m => [0, 15, 30, 45].includes(m))).toBe(true);
    });

    test("handles step expressions", () => {
      const schedules: Schedule[] = [
        { task: "heartbeat", hour: "*/2", minute: 0, weekday: "*" }, // Every 2 hours
      ];

      const result = calculateUpcomingTasks(tasks, schedules, 4);
      
      expect(result.length).toBeGreaterThan(0);
      const hours = result.map(r => r.nextRun.getHours());
      expect(hours.every(h => h % 2 === 0)).toBe(true);
    });

    test("skips schedules for unknown tasks", () => {
      const schedules: Schedule[] = [
        { task: "nonexistent", hour: 10, minute: 0, weekday: "*" },
      ];

      const result = calculateUpcomingTasks(tasks, schedules, 2);
      expect(result.length).toBe(0);
    });

    test("returns empty array for empty schedules", () => {
      expect(calculateUpcomingTasks(tasks, [], 4)).toEqual([]);
    });

    test("returns empty array for empty tasks", () => {
      const schedules: Schedule[] = [
        { task: "heartbeat", hour: "*", minute: 10, weekday: "*" },
      ];
      expect(calculateUpcomingTasks([], schedules, 4)).toEqual([]);
    });

    test("limits results to requested count", () => {
      const schedules: Schedule[] = [
        { task: "heartbeat", hour: "*", minute: 10, weekday: "*" },
        { task: "heartbeat", hour: "*", minute: 20, weekday: "*" },
        { task: "heartbeat", hour: "*", minute: 30, weekday: "*" },
        { task: "heartbeat", hour: "*", minute: 40, weekday: "*" },
        { task: "heartbeat", hour: "*", minute: 50, weekday: "*" },
      ];

      const result = calculateUpcomingTasks(tasks, schedules, 3);
      expect(result.length).toBeLessThanOrEqual(3);
    });

    test("sorts results by next run time (soonest first)", () => {
      const schedules: Schedule[] = [
        { task: "heartbeat", hour: "*", minute: 10, weekday: "*" },
        { task: "heartbeat", hour: "*", minute: 50, weekday: "*" },
        { task: "heartbeat", hour: "*", minute: 30, weekday: "*" },
      ];

      const result = calculateUpcomingTasks(tasks, schedules, 10);
      
      for (let i = 1; i < result.length; i++) {
        expect(result[i].nextRun.getTime()).toBeGreaterThanOrEqual(result[i - 1].nextRun.getTime());
      }
    });
  });
});
