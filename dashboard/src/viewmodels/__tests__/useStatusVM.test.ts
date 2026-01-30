import { describe, test, expect, beforeEach, afterEach } from "bun:test";
import { renderHook, waitFor, act } from "@testing-library/react";
import { useStatusVM } from "../useStatusVM";

describe("useStatusVM", () => {
  const originalFetch = globalThis.fetch;
  
  const mockStatusData = {
    version: "1.0.0",
    last_run: {
      id: "test-id",
      task: "heartbeat",
      exit_code: 0,
      finished_at: "2026-01-23T22:30:08Z",
    },
    next_scheduled: null,
    total_runs_today: 10,
    success_rate_today: 0.9,
  };

  beforeEach(() => {
    globalThis.fetch = (async () => {
      return new Response(JSON.stringify(mockStatusData));
    }) as unknown as typeof fetch;
  });

  afterEach(() => {
    globalThis.fetch = originalFetch;
  });

  test("initial state is loading", () => {
    const { result } = renderHook(() => useStatusVM({ watchData: false, autoRefresh: false }));
    result.current.refresh();
    
    expect(result.current.state).toBe("loading");
    expect(result.current.data).toBe(null);
    expect(result.current.error).toBe(null);
  });

  test("fetches status on mount", async () => {
    const { result } = renderHook(() => useStatusVM({ watchData: false, autoRefresh: false }));
    result.current.refresh();
    
    await waitFor(() => {
      expect(result.current.state).toBe("success");
    });
    
    expect(result.current.data?.version).toBe("1.0.0");
    expect(result.current.data?.last_run?.task).toBe("heartbeat");
  });

  test("provides formatted values", async () => {
    const { result } = renderHook(() => useStatusVM({ watchData: false, autoRefresh: false }));
    result.current.refresh();
    
    await waitFor(() => {
      expect(result.current.state).toBe("success");
    });
    
    expect(result.current.successRatePercent).toBe("90%");
    expect(result.current.lastRunStatus).toBe("OK");
  });

  test("handles error state", async () => {
    globalThis.fetch = (() => {
      return Promise.reject(new Error("Network error"));
    }) as unknown as typeof fetch;
    
    const { result } = renderHook(() => useStatusVM({ watchData: false, autoRefresh: false }));
    result.current.refresh();
    
    await waitFor(() => {
      expect(result.current.state).toBe("error");
    });
    
    expect(result.current.error).toBe("Network error");
  });

  test("refresh function refetches data", async () => {
    let callCount = 0;
    globalThis.fetch = (async () => {
      callCount++;
      return new Response(JSON.stringify(mockStatusData));
    }) as unknown as typeof fetch;

    const { result } = renderHook(() => useStatusVM({ watchData: false, autoRefresh: false }));
    result.current.refresh();

    await waitFor(() => {
      expect(result.current.state).toBe("success");
    });
    
    expect(callCount).toBe(1);
    
    await result.current.refresh();
    
    expect(callCount).toBe(2);
  });
});
