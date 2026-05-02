import { describe, test, expect } from "vitest";
import { renderHook } from "@testing-library/react";
import { useDataWatcher } from "../useDataWatcher";

describe("useDataWatcher", () => {
  test("registers and cleans up hot handlers when enabled", () => {
    let onCalls = 0;
    let offCalls = 0;
    const handlers = new Map<string, Set<() => void>>();

    const hot = {
      on: (event: string, cb: () => void) => {
        onCalls += 1;
        const set = handlers.get(event) ?? new Set();
        set.add(cb);
        handlers.set(event, set);
      },
      off: (event: string, cb: () => void) => {
        offCalls += 1;
        handlers.get(event)?.delete(cb);
      },
    };

    let refreshCalls = 0;
    const refresh = () => {
      refreshCalls += 1;
    };

    const { unmount } = renderHook(() => useDataWatcher(refresh, hot, true));

    expect(onCalls).toBe(1);

    const eventHandlers = handlers.get("runner:data-change");
    expect(eventHandlers?.size).toBe(1);
    eventHandlers?.forEach((cb) => cb());
    expect(refreshCalls).toBe(1);

    unmount();
    expect(offCalls).toBe(1);
  });

  test("does nothing when disabled", () => {
    let onCalls = 0;
    let offCalls = 0;
    const hot = {
      on: () => {
        onCalls += 1;
      },
      off: () => {
        offCalls += 1;
      },
    };

    const refresh = () => {};
    const { unmount } = renderHook(() => useDataWatcher(refresh, hot, false));

    expect(onCalls).toBe(0);
    unmount();
    expect(offCalls).toBe(0);
  });
});
