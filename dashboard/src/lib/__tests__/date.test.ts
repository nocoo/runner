import { describe, test, expect } from "bun:test";
import { 
  getDateKey, 
  getDaysAgo, 
  isToday, 
  getWeekday,
  formatScheduleTime,
  getDateRange,
} from "../date";

describe("date", () => {
  describe("getDateKey", () => {
    test("extracts date key from ISO string", () => {
      expect(getDateKey("2026-01-23T22:30:08Z")).toBe("2026-01-23");
    });

    test("extracts date key from Date object", () => {
      expect(getDateKey(new Date("2026-01-23T22:30:08Z"))).toBe("2026-01-23");
    });
  });

  describe("getDaysAgo", () => {
    test("returns 0 for today", () => {
      const today = new Date().toISOString();
      expect(getDaysAgo(today)).toBe(0);
    });

    test("returns 1 for yesterday", () => {
      const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
      expect(getDaysAgo(yesterday)).toBe(1);
    });
  });

  describe("isToday", () => {
    test("returns true for today", () => {
      const today = new Date().toISOString();
      expect(isToday(today)).toBe(true);
    });

    test("returns false for yesterday", () => {
      const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
      expect(isToday(yesterday)).toBe(false);
    });
  });

  describe("getWeekday", () => {
    test("returns weekday name", () => {
      // 2026-01-23 is a Friday
      expect(getWeekday(5)).toBe("Fri");
      expect(getWeekday(0)).toBe("Sun");
      expect(getWeekday(1)).toBe("Mon");
    });

    test("handles wildcard", () => {
      expect(getWeekday("*")).toBe("Daily");
    });
  });

  describe("formatScheduleTime", () => {
    test("formats numeric hour and minute", () => {
      expect(formatScheduleTime(9, 0)).toBe("09:00");
      expect(formatScheduleTime(21, 30)).toBe("21:30");
    });

    test("formats wildcard hour", () => {
      expect(formatScheduleTime("*", 20)).toBe("*:20");
    });
  });

  describe("getDateRange", () => {
    test("returns array of date keys", () => {
      const result = getDateRange("2026-01-20", "2026-01-23");
      expect(result).toEqual(["2026-01-20", "2026-01-21", "2026-01-22", "2026-01-23"]);
    });

    test("returns single date for same start and end", () => {
      const result = getDateRange("2026-01-20", "2026-01-20");
      expect(result).toEqual(["2026-01-20"]);
    });
  });
});
