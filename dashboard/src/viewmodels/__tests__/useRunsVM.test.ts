import { describe, test, expect } from "vitest";
import { renderHook, waitFor, act } from "@testing-library/react";
import type { RunsIndex, RunDetail } from "@/models/types";
import { useRunsVM } from "../useRunsVM";

describe("useRunsVM", () => {
  test("initial state is loading", () => {
    const { result } = renderHook(() => useRunsVM(2, {
      fetchRuns: async () => ({ runs: [], total: 0, updated_at: "2026-01-30T00:00:00Z" }),
    }));

    expect(result.current.state).toBe("loading");
    expect(result.current.runs).toEqual([]);
    expect(result.current.error).toBe(null);
  });

  test("loads runs and sorts newest first", async () => {
    const runsIndex: RunsIndex = {
      runs: [
        { id: "1", task: "task", exit_code: 0, started_at: "2026-01-28T09:55:00Z", finished_at: "2026-01-28T10:00:00Z" },
        { id: "2", task: "task", exit_code: 0, started_at: "2026-01-29T09:55:00Z", finished_at: "2026-01-29T10:00:00Z" },
      ],
      total: 2,
      updated_at: "2026-01-30T00:00:00Z",
    };

    const { result } = renderHook(() => useRunsVM(1, {
      fetchRuns: async () => runsIndex,
      watchData: false,
      autoRefresh: false,
    }));

    await act(async () => {
      await result.current.refresh();
    });

    expect(result.current.runs[0].id).toBe("2");
    expect(result.current.pagedRuns.length).toBe(1);
  });

  test("refresh error sets error state", async () => {
    const { result } = renderHook(() => useRunsVM(2, {
      fetchRuns: async () => {
        throw new Error("fetch failed");
      },
      watchData: false,
      autoRefresh: false,
    }));

    await result.current.refresh();

    await waitFor(() => {
      expect(result.current.state).toBe("error");
      expect(result.current.error).toBe("fetch failed");
    });
  });

  test("selectRun loads detail and output", async () => {
    const runsIndex: RunsIndex = {
      runs: [{ id: "1", task: "task", exit_code: 0, started_at: "2026-01-29T09:55:00Z", finished_at: "2026-01-29T10:00:00Z" }],
      total: 1,
      updated_at: "2026-01-30T00:00:00Z",
    };

    const detail: RunDetail = {
      id: "1",
      task: "task",
      trigger: "auto",
      started_at: "2026-01-29T09:59:00Z",
      finished_at: "2026-01-29T10:00:00Z",
      duration_seconds: 60,
      exit_code: 0,
    };

    const { result } = renderHook(() => useRunsVM(10, {
      fetchRuns: async () => runsIndex,
      fetchRunDetail: async () => detail,
      fetchRunOutput: async () => "output",
      watchData: false,
      autoRefresh: false,
    }));

    await result.current.refresh();
    await waitFor(() => result.current.state === "success");

    await act(async () => {
      await result.current.selectRun("1");
    });

    await waitFor(() => {
      expect(result.current.selectedRun?.id).toBe("1");
      expect(result.current.selectedRunOutput).toBe("output");
    });
  });

  test("selectRun error sets selectedRunError", async () => {
    const runsIndex: RunsIndex = {
      runs: [{ id: "1", task: "task", exit_code: 0, started_at: "2026-01-29T09:55:00Z", finished_at: "2026-01-29T10:00:00Z" }],
      total: 1,
      updated_at: "2026-01-30T00:00:00Z",
    };

    const { result } = renderHook(() => useRunsVM(10, {
      fetchRuns: async () => runsIndex,
      fetchRunDetail: async () => {
        throw new Error("boom");
      },
      fetchRunOutput: async () => "output",
      watchData: false,
      autoRefresh: false,
    }));

    await result.current.refresh();
    await waitFor(() => result.current.state === "success");

    await result.current.selectRun("1");

    await waitFor(() => {
      expect(result.current.selectedRun).toBe(null);
      expect(result.current.selectedRunError).toBe("Failed to load run detail");
    });
  });

  test("output error sets selectedRunOutputError", async () => {
    const runsIndex: RunsIndex = {
      runs: [{ id: "1", task: "task", exit_code: 0, started_at: "2026-01-29T09:55:00Z", finished_at: "2026-01-29T10:00:00Z" }],
      total: 1,
      updated_at: "2026-01-30T00:00:00Z",
    };

    const detail: RunDetail = {
      id: "1",
      task: "task",
      trigger: "auto",
      started_at: "2026-01-29T09:59:00Z",
      finished_at: "2026-01-29T10:00:00Z",
      duration_seconds: 60,
      exit_code: 0,
    };

    const { result } = renderHook(() => useRunsVM(10, {
      fetchRuns: async () => runsIndex,
      fetchRunDetail: async () => detail,
      fetchRunOutput: async () => {
        throw new Error("nope");
      },
      watchData: false,
      autoRefresh: false,
    }));

    await result.current.refresh();
    await waitFor(() => result.current.state === "success");

    await act(async () => {
      await result.current.selectRun("1");
    });

    expect(result.current.selectedRunOutputError).toBe("Failed to load run output");
  });

  test("selectRun null resets selection", async () => {
    const runsIndex: RunsIndex = {
      runs: [{ id: "1", task: "task", exit_code: 0, started_at: "2026-01-29T09:55:00Z", finished_at: "2026-01-29T10:00:00Z" }],
      total: 1,
      updated_at: "2026-01-30T00:00:00Z",
    };

    const detail: RunDetail = {
      id: "1",
      task: "task",
      trigger: "auto",
      started_at: "2026-01-29T09:59:00Z",
      finished_at: "2026-01-29T10:00:00Z",
      duration_seconds: 60,
      exit_code: 0,
    };

    const { result } = renderHook(() => useRunsVM(10, {
      fetchRuns: async () => runsIndex,
      fetchRunDetail: async () => detail,
      fetchRunOutput: async () => "output",
      watchData: false,
      autoRefresh: false,
    }));

    await result.current.refresh();
    await waitFor(() => result.current.state === "success");

    await act(async () => {
      await result.current.selectRun("1");
    });

    await act(async () => {
      await result.current.selectRun(null);
    });

    expect(result.current.selectedRun).toBe(null);
    expect(result.current.selectedRunOutput).toBe(null);
    expect(result.current.selectedRunOutputError).toBe(null);
    expect(result.current.selectedRunOutputLoading).toBe(false);
  });
});
