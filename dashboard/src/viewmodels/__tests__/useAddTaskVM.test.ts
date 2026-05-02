import { describe, test, expect, vi } from "vitest";
import { renderHook, act, waitFor } from "@testing-library/react";
import { useAddTaskVM } from "../useAddTaskVM";

describe("useAddTaskVM", () => {
  test("initial state is idle with empty form", () => {
    const { result } = renderHook(() => useAddTaskVM());

    expect(result.current.state).toBe("idle");
    expect(result.current.error).toBe(null);
    expect(result.current.formData.id).toBe("");
    expect(result.current.formData.executor).toBe("shell");
    expect(result.current.formData.timeout).toBe(300);
  });

  test("updateField updates form data and clears field error", () => {
    const { result } = renderHook(() => useAddTaskVM());

    // Set an error first
    act(() => {
      result.current.validate();
    });
    expect(result.current.errors.id).toBeDefined();

    // Update field should clear the error
    act(() => {
      result.current.updateField("id", "my_task");
    });

    expect(result.current.formData.id).toBe("my_task");
    expect(result.current.errors.id).toBeUndefined();
  });

  test("validate returns false for empty required fields", () => {
    const { result } = renderHook(() => useAddTaskVM());

    let isValid = false;
    act(() => {
      isValid = result.current.validate();
    });

    expect(isValid).toBe(false);
    expect(result.current.errors.id).toBe("Task ID is required");
    expect(result.current.errors.description).toBe("Description is required");
  });

  test("validate returns false for invalid ID format", () => {
    const { result } = renderHook(() => useAddTaskVM());

    act(() => {
      result.current.updateField("id", "123invalid");
      result.current.updateField("description", "Test task");
      result.current.updateField("command", "echo hi");
    });

    let isValid = false;
    act(() => {
      isValid = result.current.validate();
    });

    expect(isValid).toBe(false);
    expect(result.current.errors.id).toContain("must start with letter");
  });

  test("validate requires command for shell executor", () => {
    const { result } = renderHook(() => useAddTaskVM());

    act(() => {
      result.current.updateField("id", "my_task");
      result.current.updateField("description", "Test task");
      result.current.updateField("executor", "shell");
    });

    let isValid = false;
    act(() => {
      isValid = result.current.validate();
    });

    expect(isValid).toBe(false);
    expect(result.current.errors.command).toBe("Command is required for shell executor");
  });

  test("validate requires prompt for opencode executor", () => {
    const { result } = renderHook(() => useAddTaskVM());

    act(() => {
      result.current.updateField("id", "my_task");
      result.current.updateField("description", "Test task");
      result.current.updateField("executor", "opencode");
    });

    let isValid = false;
    act(() => {
      isValid = result.current.validate();
    });

    expect(isValid).toBe(false);
    expect(result.current.errors.prompt).toBe("Prompt is required for opencode executor");
  });

  test("validate requires valid URL for http executor", () => {
    const { result } = renderHook(() => useAddTaskVM());

    act(() => {
      result.current.updateField("id", "my_task");
      result.current.updateField("description", "Test task");
      result.current.updateField("executor", "http");
      result.current.updateField("url", "not-a-url");
    });

    let isValid = false;
    act(() => {
      isValid = result.current.validate();
    });

    expect(isValid).toBe(false);
    expect(result.current.errors.url).toBe("Invalid URL format");
  });

  test("validate requires URL for http executor (empty URL)", () => {
    const { result } = renderHook(() => useAddTaskVM());

    act(() => {
      result.current.updateField("id", "my_task");
      result.current.updateField("description", "Test task");
      result.current.updateField("executor", "http");
      // Don't set URL - leave it empty
    });

    let isValid = false;
    act(() => {
      isValid = result.current.validate();
    });

    expect(isValid).toBe(false);
    expect(result.current.errors.url).toBe("URL is required for http executor");
  });

  test("validate checks headers JSON format", () => {
    const { result } = renderHook(() => useAddTaskVM());

    act(() => {
      result.current.updateField("id", "my_task");
      result.current.updateField("description", "Test task");
      result.current.updateField("executor", "http");
      result.current.updateField("url", "https://example.com");
      result.current.updateField("headers", "not json");
    });

    let isValid = false;
    act(() => {
      isValid = result.current.validate();
    });

    expect(isValid).toBe(false);
    expect(result.current.errors.headers).toBe("Headers must be valid JSON");
  });

  test("validate returns true for valid shell task", () => {
    const { result } = renderHook(() => useAddTaskVM());

    act(() => {
      result.current.updateField("id", "my_task");
      result.current.updateField("description", "Test task");
      result.current.updateField("command", "echo hello");
    });

    let isValid = false;
    act(() => {
      isValid = result.current.validate();
    });

    expect(isValid).toBe(true);
    expect(Object.keys(result.current.errors).length).toBe(0);
  });

  test("submit calls createTask and onSuccess on success", async () => {
    const mockCreateTask = vi.fn(async () => ({ success: true, id: "my_task" }));
    const mockOnSuccess = vi.fn(() => {});

    const { result } = renderHook(() =>
      useAddTaskVM({
        createTask: mockCreateTask,
        onSuccess: mockOnSuccess,
      })
    );

    act(() => {
      result.current.updateField("id", "my_task");
      result.current.updateField("description", "Test task");
      result.current.updateField("command", "echo hello");
    });

    await act(async () => {
      await result.current.submit();
    });

    await waitFor(() => {
      expect(result.current.state).toBe("success");
    });

    expect(mockCreateTask).toHaveBeenCalled();
    expect(mockOnSuccess).toHaveBeenCalled();
  });

  test("submit sets error state on failure", async () => {
    const mockCreateTask = vi.fn(async () => {
      throw new Error("API error");
    });

    const { result } = renderHook(() =>
      useAddTaskVM({
        createTask: mockCreateTask,
      })
    );

    act(() => {
      result.current.updateField("id", "my_task");
      result.current.updateField("description", "Test task");
      result.current.updateField("command", "echo hello");
    });

    await act(async () => {
      await result.current.submit();
    });

    await waitFor(() => {
      expect(result.current.state).toBe("error");
      expect(result.current.error).toBe("API error");
    });
  });

  test("submit returns false without calling API when validation fails", async () => {
    const mockCreateTask = vi.fn(async () => ({ success: true, id: "x" }));

    const { result } = renderHook(() =>
      useAddTaskVM({
        createTask: mockCreateTask,
      })
    );

    let success = false;
    await act(async () => {
      success = await result.current.submit();
    });

    expect(success).toBe(false);
    expect(mockCreateTask).not.toHaveBeenCalled();
  });

  test("reset clears all form data and state", async () => {
    const mockCreateTask = vi.fn(async () => {
      throw new Error("fail");
    });

    const { result } = renderHook(() =>
      useAddTaskVM({ createTask: mockCreateTask })
    );

    act(() => {
      result.current.updateField("id", "my_task");
      result.current.updateField("description", "Test");
      result.current.updateField("command", "echo");
    });

    await act(async () => {
      await result.current.submit();
    });

    expect(result.current.state).toBe("error");

    act(() => {
      result.current.reset();
    });

    expect(result.current.formData.id).toBe("");
    expect(result.current.state).toBe("idle");
    expect(result.current.error).toBe(null);
    expect(Object.keys(result.current.errors).length).toBe(0);
  });

  test("submit builds correct task object for http executor", async () => {
    let capturedTask: unknown = null;
    const mockCreateTask = vi.fn(async (task: unknown) => {
      capturedTask = task;
      return { success: true, id: "http_task" };
    });

    const { result } = renderHook(() =>
      useAddTaskVM({ createTask: mockCreateTask })
    );

    act(() => {
      result.current.updateField("id", "http_task");
      result.current.updateField("description", "HTTP task");
      result.current.updateField("executor", "http");
      result.current.updateField("url", "https://example.com/api");
      result.current.updateField("method", "POST");
      result.current.updateField("headers", '{"Content-Type": "application/json"}');
      result.current.updateField("body", '{"key": "value"}');
    });

    await act(async () => {
      await result.current.submit();
    });

    expect(capturedTask).toMatchObject({
      id: "http_task",
      executor: "http",
      description: "HTTP task",
      url: "https://example.com/api",
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: '{"key": "value"}',
    });
  });

  test("submit builds correct task object for opencode executor", async () => {
    let capturedTask: unknown = null;
    const mockCreateTask = vi.fn(async (task: unknown) => {
      capturedTask = task;
      return { success: true, id: "opencode_task" };
    });

    const { result } = renderHook(() =>
      useAddTaskVM({ createTask: mockCreateTask })
    );

    act(() => {
      result.current.updateField("id", "opencode_task");
      result.current.updateField("description", "Opencode task");
      result.current.updateField("executor", "opencode");
      result.current.updateField("prompt", "Analyze the code");
      result.current.updateField("workdir", "/path/to/project");
    });

    await act(async () => {
      await result.current.submit();
    });

    expect(capturedTask).toMatchObject({
      id: "opencode_task",
      executor: "opencode",
      description: "Opencode task",
      prompt: "Analyze the code",
      workdir: "/path/to/project",
    });
  });
});
