import { describe, test, expect, afterEach } from "bun:test";
import { 
  fetchStatus, 
  fetchTasks, 
  fetchSchedules, 
  fetchRuns,
  fetchRunDetail,
  fetchRunOutput,
  triggerTask,
} from "../api";

describe("api", () => {
  const originalFetch = globalThis.fetch;

  afterEach(() => {
    globalThis.fetch = originalFetch;
  });

  describe("fetchStatus", () => {
    test("calls correct endpoint", async () => {
      let calledUrl = "";
      globalThis.fetch = (async (url: string) => {
        calledUrl = url;
        return new Response(JSON.stringify({ version: "1.0.0" }));
      }) as unknown as typeof fetch;

      const result = await fetchStatus();
      
      expect(calledUrl).toBe("/api/status");
      expect(result.version).toBe("1.0.0");
    });

    test("throws on network error", async () => {
      globalThis.fetch = (() => {
        return Promise.reject(new Error("Network error"));
      }) as unknown as typeof fetch;

      await expect(fetchStatus()).rejects.toThrow("Network error");
    });

    test("throws on non-ok response", async () => {
      globalThis.fetch = (async () => {
        return new Response("Server error", { status: 500 });
      }) as unknown as typeof fetch;

      await expect(fetchStatus()).rejects.toThrow("API Error");
    });
  });

  describe("fetchTasks", () => {
    test("calls correct endpoint and returns array", async () => {
      const mockTasks = [
        { id: "heartbeat", executor: "shell" as const, description: "Test", timeout: 60, command: "echo test" },
        { id: "webhook", executor: "http" as const, description: "Webhook", timeout: 30, url: "https://example.com/hook", method: "POST" },
      ];
      let calledUrl = "";
      globalThis.fetch = (async (url: string) => {
        calledUrl = url;
        return new Response(JSON.stringify(mockTasks));
      }) as unknown as typeof fetch;

      const result = await fetchTasks();
      
      expect(calledUrl).toBe("/api/tasks");
      expect(result).toEqual(mockTasks);
    });
  });

  describe("fetchSchedules", () => {
    test("calls correct endpoint and returns array", async () => {
      const mockSchedules = [{ task: "heartbeat", hour: 9, minute: 0, weekday: "*" as const }];
      let calledUrl = "";
      globalThis.fetch = (async (url: string) => {
        calledUrl = url;
        return new Response(JSON.stringify(mockSchedules));
      }) as unknown as typeof fetch;

      const result = await fetchSchedules();
      
      expect(calledUrl).toBe("/api/schedules");
      expect(result).toEqual(mockSchedules);
    });
  });

  describe("fetchRuns", () => {
    test("calls correct endpoint and returns runs index", async () => {
      const mockRuns = { runs: [], total: 0, updated_at: "2026-01-23T00:00:00Z" };
      let calledUrl = "";
      globalThis.fetch = (async (url: string) => {
        calledUrl = url;
        return new Response(JSON.stringify(mockRuns));
      }) as unknown as typeof fetch;

      const result = await fetchRuns();
      
      expect(calledUrl).toBe("/api/runs");
      expect(result).toEqual(mockRuns);
    });
  });

  describe("fetchRunDetail", () => {
    test("calls correct endpoint with id", async () => {
      const mockRun = { 
        id: "abc-123", 
        task: "heartbeat", 
        trigger: "auto" as const,
        started_at: "2026-01-23T00:00:00Z",
        exit_code: 0,
      };
      let calledUrl = "";
      globalThis.fetch = (async (url: string) => {
        calledUrl = url;
        return new Response(JSON.stringify(mockRun));
      }) as unknown as typeof fetch;

      const result = await fetchRunDetail("abc-123");
      
      expect(calledUrl).toBe("/api/runs/abc-123");
      expect(result).toEqual(mockRun);
    });
  });

  describe("fetchRunOutput", () => {
    test("calls correct endpoint and returns output", async () => {
      const mockOutput = { output: "hello" };
      let calledUrl = "";
      globalThis.fetch = (async (url: string) => {
        calledUrl = url;
        return new Response(JSON.stringify(mockOutput));
      }) as unknown as typeof fetch;

      const result = await fetchRunOutput("abc-123");

      expect(calledUrl).toBe("/api/runs/abc-123/output");
      expect(result).toBe("hello");
    });
  });

  describe("triggerTask", () => {
    test("calls correct endpoint with POST method", async () => {
      const mockResponse = { task: "heartbeat", exit_code: 0, stdout: "", stderr: "" };
      let calledUrl = "";
      let calledOptions: RequestInit | undefined;
      globalThis.fetch = (async (url: string, options?: RequestInit) => {
        calledUrl = url;
        calledOptions = options;
        return new Response(JSON.stringify(mockResponse));
      }) as unknown as typeof fetch;

      const result = await triggerTask("heartbeat");
      
      expect(calledUrl).toBe("/api/trigger/heartbeat");
      expect(calledOptions?.method).toBe("POST");
      expect(result).toEqual(mockResponse);
    });
  });
});
