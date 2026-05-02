import { describe, test, expect } from "vitest";
import { render } from "@testing-library/react";
import { DurationDistribution } from "../DurationDistribution";
import type { RunSummary } from "@/models/types";

function makeRun(durationSec: number, overrides: Partial<RunSummary> = {}): RunSummary {
  const finished = Date.now();
  const started = finished - durationSec * 1000;
  return {
    id: `run-${Math.random().toString(36).slice(2)}`,
    task: "test-task",
    exit_code: 0,
    started_at: new Date(started).toISOString(),
    finished_at: new Date(finished).toISOString(),
    ...overrides,
  };
}

describe("DurationDistribution", () => {
  test("renders with empty runs", () => {
    const { container } = render(<DurationDistribution runs={[]} />);
    expect(container.textContent).toContain("Duration");
  });

  test("renders all bucket labels", () => {
    const { getByText } = render(<DurationDistribution runs={[]} />);
    expect(getByText("<5s")).toBeTruthy();
    expect(getByText("5-15s")).toBeTruthy();
    expect(getByText("15-30s")).toBeTruthy();
    expect(getByText("30-60s")).toBeTruthy();
    expect(getByText("1-5m")).toBeTruthy();
    expect(getByText(">5m")).toBeTruthy();
  });

  test("shows zero counts for empty runs", () => {
    const { container } = render(<DurationDistribution runs={[]} />);
    // All 6 buckets should show count 0
    const countElements = container.querySelectorAll(".w-6");
    const counts = Array.from(countElements).map((el) => el.textContent?.trim());
    expect(counts.every((c) => c === "0")).toBe(true);
  });

  test("buckets a 2s run into <5s", () => {
    const runs = [makeRun(2)];
    const { container } = render(<DurationDistribution runs={runs} />);
    const countElements = container.querySelectorAll(".w-6");
    const counts = Array.from(countElements).map((el) => el.textContent?.trim());
    // First bucket (<5s) should have 1
    expect(counts[0]).toBe("1");
  });

  test("buckets a 10s run into 5-15s", () => {
    const runs = [makeRun(10)];
    const { container } = render(<DurationDistribution runs={runs} />);
    const countElements = container.querySelectorAll(".w-6");
    const counts = Array.from(countElements).map((el) => el.textContent?.trim());
    expect(counts[1]).toBe("1");
  });

  test("buckets a 600s run into >5m", () => {
    const runs = [makeRun(600)];
    const { container } = render(<DurationDistribution runs={runs} />);
    const countElements = container.querySelectorAll(".w-6");
    const counts = Array.from(countElements).map((el) => el.textContent?.trim());
    expect(counts[5]).toBe("1");
  });

  test("skips running tasks (no finished_at)", () => {
    const run = makeRun(10, { finished_at: null });
    const { container } = render(<DurationDistribution runs={[run]} />);
    const countElements = container.querySelectorAll(".w-6");
    const counts = Array.from(countElements).map((el) => el.textContent?.trim());
    expect(counts.every((c) => c === "0")).toBe(true);
  });

  test("distributes multiple runs into correct buckets", () => {
    const runs = [
      makeRun(1),   // <5s
      makeRun(3),   // <5s
      makeRun(10),  // 5-15s
      makeRun(45),  // 30-60s
      makeRun(120), // 1-5m
    ];
    const { container } = render(<DurationDistribution runs={runs} />);
    const countElements = container.querySelectorAll(".w-6");
    const counts = Array.from(countElements).map((el) => el.textContent?.trim());
    expect(counts[0]).toBe("2"); // <5s
    expect(counts[1]).toBe("1"); // 5-15s
    expect(counts[2]).toBe("0"); // 15-30s
    expect(counts[3]).toBe("1"); // 30-60s
    expect(counts[4]).toBe("1"); // 1-5m
    expect(counts[5]).toBe("0"); // >5m
  });
});
