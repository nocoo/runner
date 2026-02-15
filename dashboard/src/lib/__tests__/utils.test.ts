import { describe, test, expect } from "bun:test";
import { cn } from "../utils";

describe("cn", () => {
  test("merges single class string", () => {
    expect(cn("text-red-500")).toBe("text-red-500");
  });

  test("merges multiple class strings", () => {
    expect(cn("px-2", "py-1")).toBe("px-2 py-1");
  });

  test("handles conditional classes", () => {
    expect(cn("px-2", false && "hidden", "py-1")).toBe("px-2 py-1");
  });

  test("handles undefined and null", () => {
    expect(cn("px-2", undefined, null, "py-1")).toBe("px-2 py-1");
  });

  test("deduplicates conflicting tailwind classes", () => {
    expect(cn("px-2", "px-4")).toBe("px-4");
  });

  test("deduplicates conflicting color classes", () => {
    expect(cn("text-red-500", "text-blue-500")).toBe("text-blue-500");
  });

  test("handles array input", () => {
    expect(cn(["px-2", "py-1"])).toBe("px-2 py-1");
  });

  test("handles object input", () => {
    expect(cn({ "px-2": true, hidden: false })).toBe("px-2");
  });

  test("returns empty string for no input", () => {
    expect(cn()).toBe("");
  });

  test("returns empty string for all falsy", () => {
    expect(cn(false, null, undefined, "")).toBe("");
  });
});
