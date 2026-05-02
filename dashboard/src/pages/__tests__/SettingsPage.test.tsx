import { describe, test, expect, beforeEach } from "vitest";
import { render, fireEvent } from "@testing-library/react";
import { SettingsPage } from "../SettingsPage";

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
