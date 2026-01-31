import { describe, test, expect } from "bun:test";
import { renderHook, waitFor } from "@testing-library/react";
import type { Schedule, Task } from "@/models/types";
import { useTasksVM } from "../useTasksVM";

describe("useTasksVM", () => {
  test("initial state is loading", () => {
    const { result } = renderHook(() => useTasksVM({
      fetchTasks: async () => [],
      fetchSchedules: async () => [],
      timeProvider: () => new Date("2026-01-30T10:00:00Z"),
      tickMs: 10_000,
      watchData: false,
      autoRefresh: false,
    }));

    expect(result.current.state).toBe("loading");
    expect(result.current.error).toBe(null);
  });

  test("loads tasks and schedules", async () => {
      const tasks: Task[] = [
        { id: "heartbeat", executor: "shell", description: "Heartbeat", timeout: 60, command: "echo hi" },
        { id: "webhook", executor: "http", description: "Webhook", timeout: 30, url: "https://example.com" },
      ];
    const schedules: Schedule[] = [
      { task: "heartbeat", hour: 9, minute: 0, weekday: "*" },
    ];

    const { result } = renderHook(() => useTasksVM({
      fetchTasks: async () => tasks,
      fetchSchedules: async () => schedules,
      timeProvider: () => new Date("2026-01-30T10:00:00Z"),
      tickMs: 10_000,
      watchData: false,
      autoRefresh: false,
    }));

    await result.current.refresh();

    await waitFor(() => result.current.state === "success");

    expect(result.current.tasks.length).toBe(2);
    expect(result.current.schedules.length).toBe(1);
  });

  test("trigger sets success state", async () => {
    const { result } = renderHook(() => useTasksVM({
      fetchTasks: async () => [],
      fetchSchedules: async () => [],
      triggerTask: async () => ({ task: "heartbeat", exit_code: 0, stdout: "", stderr: "" }),
      timeProvider: () => new Date("2026-01-30T10:00:00Z"),
      tickMs: 10_000,
      watchData: false,
      autoRefresh: false,
    }));

    await result.current.trigger("heartbeat");

    await waitFor(() => {
      expect(result.current.triggerState).toBe("success");
      expect(result.current.triggerResult?.task).toBe("heartbeat");
    });
  });

  test("trigger sets error state", async () => {
    const { result } = renderHook(() => useTasksVM({
      fetchTasks: async () => [],
      fetchSchedules: async () => [],
      triggerTask: async () => {
        throw new Error("boom");
      },
      timeProvider: () => new Date("2026-01-30T10:00:00Z"),
      tickMs: 10_000,
      watchData: false,
      autoRefresh: false,
    }));

    await result.current.trigger("heartbeat");

    await waitFor(() => {
      expect(result.current.triggerState).toBe("error");
      expect(result.current.triggerError).toBe("boom");
    });
  });

  test("refresh error sets error state", async () => {
    const { result } = renderHook(() => useTasksVM({
      fetchTasks: async () => {
        throw new Error("fetch fail");
      },
      fetchSchedules: async () => [],
      timeProvider: () => new Date("2026-01-30T10:00:00Z"),
      tickMs: 10_000,
      watchData: false,
      autoRefresh: false,
    }));

    await result.current.refresh();

    await waitFor(() => {
      expect(result.current.state).toBe("error");
      expect(result.current.error).toBe("fetch fail");
    });
  });

  test("clearTriggerResult resets trigger state", async () => {
    const { result } = renderHook(() => useTasksVM({
      fetchTasks: async () => [],
      fetchSchedules: async () => [],
      triggerTask: async () => ({ task: "heartbeat", exit_code: 0, stdout: "", stderr: "" }),
      timeProvider: () => new Date("2026-01-30T10:00:00Z"),
      tickMs: 10_000,
      watchData: false,
      autoRefresh: false,
    }));

    await result.current.trigger("heartbeat");
    await waitFor(() => result.current.triggerState === "success");

    result.current.clearTriggerResult();

    await waitFor(() => {
      expect(result.current.triggerState).toBe("idle");
      expect(result.current.triggerResult).toBe(null);
      expect(result.current.triggerError).toBe(null);
    });
  });

  test("interval updates countdown over time", async () => {
    const tasks: Task[] = [
      { id: "heartbeat", executor: "shell", description: "Heartbeat", timeout: 60, command: "echo hi" },
    ];
    const schedules: Schedule[] = [
      { task: "heartbeat", hour: "*", minute: "*/10", weekday: "*" },
    ];

    let current = Date.parse("2026-01-30T08:50:00Z");
    const timeProvider = () => {
      current += 1000;
      return new Date(current);
    };

    const { result } = renderHook(() => useTasksVM({
      fetchTasks: async () => tasks,
      fetchSchedules: async () => schedules,
      timeProvider,
      tickMs: 5,
      watchData: false,
      autoRefresh: false,
    }));

    await result.current.refresh();
    await waitFor(() => result.current.state === "success");

    const firstCountdown = result.current.upcomingTasks[0]?.countdown ?? 0;

    await new Promise((resolve) => setTimeout(resolve, 20));

    const nextCountdown = result.current.upcomingTasks[0]?.countdown ?? 0;
    expect(nextCountdown).toBeLessThan(firstCountdown);
  });

  test("computes upcoming tasks with countdown", async () => {
    const tasks: Task[] = [
      { id: "heartbeat", executor: "shell", description: "Heartbeat", timeout: 60, command: "echo hi" },
    ];
    const schedules: Schedule[] = [
      { task: "heartbeat", hour: 9, minute: 0, weekday: "*" },
    ];

    const now = new Date("2026-01-30T08:50:00Z");

    const { result } = renderHook(() => useTasksVM({
      fetchTasks: async () => tasks,
      fetchSchedules: async () => schedules,
      timeProvider: () => now,
      tickMs: 10_000,
      upcomingCount: 2,
      watchData: false,
      autoRefresh: false,
    }));

    await result.current.refresh();

    await waitFor(() => result.current.state === "success");

    expect(result.current.upcomingTasks.length).toBeGreaterThan(0);
    expect(result.current.upcomingTasks[0].countdown).toBeGreaterThan(0);
  });
});
