import { describe, test, expect } from "bun:test";
import { formatDuration, formatDurationMs, formatRelativeTime, formatDate, formatExitCode, formatNumber, formatPercent } from "../format";

describe("format", () => {
  describe("formatDuration", () => {
    test("formats seconds only", () => {
      expect(formatDuration(45)).toBe("45s");
    });

    test("formats minutes and seconds", () => {
      expect(formatDuration(125)).toBe("2m 5s");
    });

    test("formats hours, minutes, and seconds", () => {
      expect(formatDuration(3665)).toBe("1h 1m 5s");
    });

    test("handles zero", () => {
      expect(formatDuration(0)).toBe("0s");
    });

    test("handles undefined/null", () => {
      expect(formatDuration(undefined as unknown as number)).toBe("-");
      expect(formatDuration(null as unknown as number)).toBe("-");
    });
  });

  describe("formatDurationMs", () => {
    test("formats milliseconds to seconds", () => {
      expect(formatDurationMs(5000)).toBe("5s");
      expect(formatDurationMs(45000)).toBe("45s");
    });

    test("formats milliseconds to minutes and seconds", () => {
      expect(formatDurationMs(125000)).toBe("2m 5s");
    });

    test("handles zero", () => {
      expect(formatDurationMs(0)).toBe("0s");
    });

    test("handles undefined/null/NaN", () => {
      expect(formatDurationMs(undefined as unknown as number)).toBe("-");
      expect(formatDurationMs(null as unknown as number)).toBe("-");
      expect(formatDurationMs(NaN)).toBe("-");
    });
  });

  describe("formatRelativeTime", () => {
    test("formats seconds ago", () => {
      const now = new Date();
      const past = new Date(now.getTime() - 30 * 1000);
      expect(formatRelativeTime(past.toISOString())).toBe("30s ago");
    });

    test("formats minutes ago", () => {
      const now = new Date();
      const past = new Date(now.getTime() - 5 * 60 * 1000);
      expect(formatRelativeTime(past.toISOString())).toBe("5m ago");
    });

    test("formats hours ago", () => {
      const now = new Date();
      const past = new Date(now.getTime() - 2 * 60 * 60 * 1000);
      expect(formatRelativeTime(past.toISOString())).toBe("2h ago");
    });

    test("formats days ago", () => {
      const now = new Date();
      const past = new Date(now.getTime() - 3 * 24 * 60 * 60 * 1000);
      expect(formatRelativeTime(past.toISOString())).toBe("3d ago");
    });

    test("handles invalid date", () => {
      expect(formatRelativeTime("invalid")).toBe("-");
      expect(formatRelativeTime("")).toBe("-");
    });
  });

  describe("formatDate", () => {
    test("formats ISO date to readable format", () => {
      expect(formatDate("2026-01-23T22:30:08Z")).toMatch(/Jan 23/);
    });

    test("handles invalid date", () => {
      expect(formatDate("invalid")).toBe("-");
    });
  });

  describe("formatExitCode", () => {
    test("formats success exit code", () => {
      expect(formatExitCode(0)).toBe("OK");
    });

    test("formats failure exit code", () => {
      expect(formatExitCode(1)).toBe("FAILED");
      expect(formatExitCode(127)).toBe("FAILED");
    });
  });

  describe("formatNumber", () => {
    test("formats number with commas", () => {
      expect(formatNumber(1000)).toBe("1,000");
      expect(formatNumber(1000000)).toBe("1,000,000");
    });

    test("handles small numbers", () => {
      expect(formatNumber(42)).toBe("42");
      expect(formatNumber(0)).toBe("0");
    });
  });

  describe("formatPercent", () => {
    test("formats decimal to percentage", () => {
      expect(formatPercent(0.8)).toBe("80%");
      expect(formatPercent(1)).toBe("100%");
      expect(formatPercent(0.333)).toBe("33%");
    });

    test("handles zero", () => {
      expect(formatPercent(0)).toBe("0%");
    });
  });
});
