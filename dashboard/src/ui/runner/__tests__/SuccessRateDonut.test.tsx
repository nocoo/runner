import { describe, test, expect } from "vitest";
import { render } from "@testing-library/react";
import { SuccessRateDonut } from "../SuccessRateDonut";
import type { RunSummary } from "@/models/types";

function makeRun(overrides: Partial<RunSummary> = {}): RunSummary {
  return {
    id: `run-${Math.random().toString(36).slice(2)}`,
    task: "test-task",
    exit_code: 0,
    started_at: new Date(Date.now() - 60_000).toISOString(),
    finished_at: new Date().toISOString(),
    ...overrides,
  };
}

describe("SuccessRateDonut", () => {
  test("renders with empty runs", () => {
    const { container } = render(<SuccessRateDonut runs={[]} />);
    expect(container.textContent).toContain("Success Rate");
    // Should show dash for all three periods
    const svgs = container.querySelectorAll("svg");
    expect(svgs.length).toBe(3);
  });

  test("renders three period labels", () => {
    const { getByText } = render(<SuccessRateDonut runs={[]} />);
    expect(getByText("Today")).toBeTruthy();
    expect(getByText("7 Days")).toBeTruthy();
    expect(getByText("30 Days")).toBeTruthy();
  });

  test("shows 100% for all-success runs", () => {
    const runs = [makeRun(), makeRun(), makeRun()];
    const { container } = render(<SuccessRateDonut runs={runs} />);
    // All SVG text elements should show 100%
    const texts = container.querySelectorAll("svg text");
    const percentages = Array.from(texts).map((t) => t.textContent);
    expect(percentages.filter((p) => p === "100%").length).toBe(3);
  });

  test("shows 0% for all-failed runs", () => {
    const runs = [
      makeRun({ exit_code: 1 }),
      makeRun({ exit_code: 2 }),
    ];
    const { container } = render(<SuccessRateDonut runs={runs} />);
    const texts = container.querySelectorAll("svg text");
    const percentages = Array.from(texts).map((t) => t.textContent);
    expect(percentages.filter((p) => p === "0%").length).toBe(3);
  });

  test("calculates mixed success rate correctly", () => {
    const runs = [
      makeRun({ exit_code: 0 }),
      makeRun({ exit_code: 1 }),
    ];
    const { container } = render(<SuccessRateDonut runs={runs} />);
    const texts = container.querySelectorAll("svg text");
    const percentages = Array.from(texts).map((t) => t.textContent);
    expect(percentages.filter((p) => p === "50%").length).toBe(3);
  });

  test("renders correct run counts", () => {
    const runs = [
      makeRun({ exit_code: 0 }),
      makeRun({ exit_code: 0 }),
      makeRun({ exit_code: 1 }),
    ];
    const { container } = render(<SuccessRateDonut runs={runs} />);
    expect(container.textContent).toContain("2/3 runs");
  });

  test("excludes runs older than period", () => {
    const oldRun = makeRun({
      finished_at: new Date(Date.now() - 8 * 24 * 60 * 60 * 1000).toISOString(),
      started_at: new Date(Date.now() - 8 * 24 * 60 * 60 * 1000 - 60_000).toISOString(),
      exit_code: 1,
    });
    const recentRun = makeRun({ exit_code: 0 });
    const { container } = render(<SuccessRateDonut runs={[oldRun, recentRun]} />);
    // Today should show 100% (only the recent run)
    const texts = container.querySelectorAll("svg text");
    const todayText = texts[0]?.textContent;
    expect(todayText).toBe("100%");
  });

  test("renders SVG circles for donut arcs", () => {
    const runs = [makeRun({ exit_code: 0 })];
    const { container } = render(<SuccessRateDonut runs={runs} />);
    const circles = container.querySelectorAll("circle");
    // Each donut has bg circle + success arc = 2 per donut, 3 donuts = 6
    expect(circles.length).toBeGreaterThanOrEqual(6);
  });
});
