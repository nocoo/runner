import { describe, test, expect, beforeEach } from "bun:test";
import { render, fireEvent } from "@testing-library/react";
import { MemoryRouter } from "react-router";
import { SettingsPage } from "../SettingsPage";

// Mock useStatusVM
const mockStatusVM = {
  data: {
    version: "1.2.3",
    last_run: { id: "r1", task: "backup", exit_code: 0, finished_at: "2026-01-01T00:00:00Z" },
    next_scheduled: null,
    total_runs_today: 42,
    success_rate_today: 0.95,
  },
  state: "success" as const,
  error: null,
  refresh: async () => {},
  successRatePercent: "95%",
  lastRunStatus: "OK",
  lastRunTask: "backup",
  isOnline: true,
};

// We need to test with the real component since it uses useStatusVM internally.
// The component will make a fetch call that will fail in tests, but we can still
// test the rendering structure.

function renderSettings() {
  return render(
    <MemoryRouter>
      <SettingsPage />
    </MemoryRouter>
  );
}

describe("SettingsPage", () => {
  beforeEach(() => {
    try {
      localStorage.removeItem("runner:clockFormat");
    } catch {
      // no-op
    }
  });

  test("renders system info section", () => {
    const { container } = render(<SettingsPage />);
    expect(container.textContent).toContain("System Info");
  });

  test("renders display preferences section", () => {
    const { container } = render(<SettingsPage />);
    expect(container.textContent).toContain("Display");
    expect(container.textContent).toContain("Clock Format");
  });

  test("renders system info fields", () => {
    const { container } = render(<SettingsPage />);
    expect(container.textContent).toContain("Version");
    expect(container.textContent).toContain("Status");
    expect(container.textContent).toContain("Runs Today");
    expect(container.textContent).toContain("Success Rate");
    expect(container.textContent).toContain("Last Run Task");
    expect(container.textContent).toContain("Last Run Status");
  });

  test("renders clock format buttons", () => {
    const { getByText } = render(<SettingsPage />);
    expect(getByText("12H")).toBeTruthy();
    expect(getByText("24H")).toBeTruthy();
  });

  test("24H is selected by default", () => {
    const { getByText } = render(<SettingsPage />);
    const btn24 = getByText("24H");
    expect(btn24.className).toContain("bg-matrix-primary/20");
  });

  test("clicking 12H switches selection", () => {
    const { getByText } = render(<SettingsPage />);
    fireEvent.click(getByText("12H"));
    const btn12 = getByText("12H");
    expect(btn12.className).toContain("bg-matrix-primary/20");
  });

  test("persists clock format to localStorage", () => {
    const { getByText } = render(<SettingsPage />);
    fireEvent.click(getByText("12H"));
    expect(localStorage.getItem("runner:clockFormat")).toBe("12h");
  });

  test("reads clock format from localStorage", () => {
    localStorage.setItem("runner:clockFormat", "12h");
    const { getByText } = render(<SettingsPage />);
    const btn12 = getByText("12H");
    expect(btn12.className).toContain("bg-matrix-primary/20");
  });
});
