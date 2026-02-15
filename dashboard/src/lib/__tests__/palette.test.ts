import { describe, test, expect } from "bun:test";
import {
  CHART_COLORS,
  withAlpha,
  chartPositive,
  chartNegative,
  chartPrimary,
  chartAxis,
} from "../palette";

describe("palette", () => {
  describe("CHART_COLORS", () => {
    test("is a non-empty array", () => {
      expect(CHART_COLORS.length).toBeGreaterThan(0);
    });

    test("contains valid hex color strings", () => {
      for (const color of CHART_COLORS) {
        expect(color).toMatch(/^#[0-9A-Fa-f]{6}$/);
      }
    });

    test("first color is matrix primary green", () => {
      expect(CHART_COLORS[0]).toBe("#00FF41");
    });
  });

  describe("withAlpha", () => {
    test("converts hex to rgba with alpha", () => {
      expect(withAlpha("#00FF41", 0.5)).toBe("rgba(0, 255, 65, 0.5)");
    });

    test("handles full opacity", () => {
      expect(withAlpha("#FF0000", 1)).toBe("rgba(255, 0, 0, 1)");
    });

    test("handles zero opacity", () => {
      expect(withAlpha("#000000", 0)).toBe("rgba(0, 0, 0, 0)");
    });

    test("handles white color", () => {
      expect(withAlpha("#FFFFFF", 0.8)).toBe("rgba(255, 255, 255, 0.8)");
    });

    test("handles lowercase hex", () => {
      expect(withAlpha("#ff3366", 0.5)).toBe("rgba(255, 51, 102, 0.5)");
    });
  });

  describe("semantic aliases", () => {
    test("chartPositive is matrix green", () => {
      expect(chartPositive).toBe("#00FF41");
    });

    test("chartNegative is red", () => {
      expect(chartNegative).toBe("#FF3366");
    });

    test("chartPrimary is matrix green", () => {
      expect(chartPrimary).toBe("#00FF41");
    });

    test("chartAxis is rgba green with low opacity", () => {
      expect(chartAxis).toContain("rgba");
      expect(chartAxis).toContain("0, 255, 65");
    });
  });
});
