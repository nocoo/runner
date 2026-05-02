import { describe, test, expect } from "vitest";
import { render } from "@testing-library/react";
import { RunTimeline } from "../RunTimeline";
import type { RunSummary } from "@/models/types";

function makeRecentRun(
  taskName: string,
  durationMin: number,
  exitCode: number | null = 0,
  minutesAgo: number = 30,
): RunSummary {
  const finished = exitCode !== null ? Date.now() - minutesAgo * 60 * 1000 : null;
  const started = (finished ?? Date.now()) - durationMin * 60 * 1000;
  return {
    id: `run-${Math.random().toString(36).slice(2)}`,
    task: taskName,
    exit_code: exitCode,
    started_at: new Date(started).toISOString(),
    finished_at: finished ? new Date(finished).toISOString() : null,
  };
}

describe("RunTimeline", () => {
  test("renders with empty runs", () => {
    const { container } = render(<RunTimeline runs={[]} />);
    expect(container.textContent).toContain("Timeline");
    expect(container.textContent).toContain("No runs in the last 24 hours");
  });

  test("renders title and subtitle", () => {
    const { container } = render(<RunTimeline runs={[]} />);
    expect(container.textContent).toContain("Timeline");
    expect(container.textContent).toContain("24h");
  });

  test("renders entries for recent runs", () => {
    const runs = [
      makeRecentRun("backup", 5, 0, 10),
      makeRecentRun("sync", 3, 1, 60),
    ];
    const { container } = render(<RunTimeline runs={runs} />);
    // Should have timeline entry divs with title attributes
    const entries = container.querySelectorAll("[title]");
    expect(entries.length).toBeGreaterThanOrEqual(2);
  });

  test("shows task name in entry title attribute", () => {
    const runs = [makeRecentRun("daily-backup", 5, 0, 10)];
    const { container } = render(<RunTimeline runs={runs} />);
    const entry = container.querySelector('[title*="daily-backup"]');
    expect(entry).toBeTruthy();
  });

  test("shows status in entry title attribute", () => {
    const runs = [makeRecentRun("task-a", 5, 0, 10)];
    const { container } = render(<RunTimeline runs={runs} />);
    const entry = container.querySelector('[title*="ok"]');
    expect(entry).toBeTruthy();
  });

  test("handles running tasks", () => {
    const runs = [makeRecentRun("active-task", 5, null, 0)];
    const { container } = render(<RunTimeline runs={runs} />);
    const entry = container.querySelector('[title*="running"]');
    expect(entry).toBeTruthy();
  });

  test("excludes runs older than 24h", () => {
    const oldRun: RunSummary = {
      id: "old-run",
      task: "old-task",
      exit_code: 0,
      started_at: new Date(Date.now() - 48 * 60 * 60 * 1000).toISOString(),
      finished_at: new Date(Date.now() - 47 * 60 * 60 * 1000).toISOString(),
    };
    const { container } = render(<RunTimeline runs={[oldRun]} />);
    expect(container.textContent).toContain("No runs in the last 24 hours");
  });

  test("renders hour labels", () => {
    const runs = [makeRecentRun("task", 5, 0, 10)];
    const { container } = render(<RunTimeline runs={runs} />);
    // Should have hour labels like 00, 04, 08, etc.
    const labels = container.querySelectorAll(".text-\\[9px\\]");
    expect(labels.length).toBeGreaterThan(0);
  });
});
