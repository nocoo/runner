import { describe, test, expect } from "vitest";
import { render } from "@testing-library/react";
import { TaskStatsChart } from "../TaskStatsChart";
import type { RunSummary } from "@/models/types";

function makeRun(task: string, exitCode: number): RunSummary {
  return {
    id: `run-${Math.random().toString(36).slice(2)}`,
    task,
    exit_code: exitCode,
    started_at: new Date(Date.now() - 60_000).toISOString(),
    finished_at: new Date().toISOString(),
  };
}

describe("TaskStatsChart", () => {
  test("renders with empty runs", () => {
    const { container } = render(<TaskStatsChart runs={[]} />);
    expect(container.textContent).toContain("Per-Task Stats");
    expect(container.textContent).toContain("No task data available");
  });

  test("renders task names", () => {
    const runs = [makeRun("backup", 0), makeRun("sync", 1)];
    const { getByText } = render(<TaskStatsChart runs={runs} />);
    expect(getByText("backup")).toBeTruthy();
    expect(getByText("sync")).toBeTruthy();
  });

  test("shows correct run counts", () => {
    const runs = [
      makeRun("backup", 0),
      makeRun("backup", 0),
      makeRun("backup", 1),
    ];
    const { container } = render(<TaskStatsChart runs={runs} />);
    expect(container.textContent).toContain("3 runs");
  });

  test("calculates success rate per task", () => {
    const runs = [
      makeRun("backup", 0),
      makeRun("backup", 0),
      makeRun("backup", 1),
    ];
    const { container } = render(<TaskStatsChart runs={runs} />);
    expect(container.textContent).toContain("67%");
  });

  test("sorts tasks by total runs descending", () => {
    const runs = [
      makeRun("rare", 0),
      makeRun("frequent", 0),
      makeRun("frequent", 0),
      makeRun("frequent", 0),
    ];
    const { container } = render(<TaskStatsChart runs={runs} />);
    const taskLabels = container.querySelectorAll(".truncate");
    expect(taskLabels[0]?.textContent).toBe("frequent");
    expect(taskLabels[1]?.textContent).toBe("rare");
  });

  test("excludes running tasks from stats", () => {
    const runs: RunSummary[] = [
      makeRun("backup", 0),
      {
        id: "running-1",
        task: "backup",
        exit_code: null,
        started_at: new Date().toISOString(),
        finished_at: null,
      },
    ];
    const { container } = render(<TaskStatsChart runs={runs} />);
    // Only 1 completed run
    expect(container.textContent).toContain("1 runs");
    expect(container.textContent).toContain("100%");
  });

  test("renders success and failed bar segments", () => {
    const runs = [
      makeRun("task-a", 0),
      makeRun("task-a", 1),
    ];
    const { container } = render(<TaskStatsChart runs={runs} />);
    // Should have both green (success) and red (error) bars
    const successBar = container.querySelector(".bg-matrix-primary\\/40");
    const failedBar = container.querySelector(".bg-error\\/40");
    expect(successBar).toBeTruthy();
    expect(failedBar).toBeTruthy();
  });
});
