// ============================================
// Add Task ViewModel
// ============================================

import { useState, useCallback } from "react";
import type { Task, LoadingState } from "@/models/types";
import {
  createTask as createTaskDefault,
  type CreateTaskResponse,
} from "@/models/api";

export interface TaskFormData {
  id: string;
  executor: "shell" | "opencode" | "http";
  description: string;
  timeout: number;
  command: string;
  prompt: string;
  workdir: string;
  url: string;
  method: string;
  headers: string;
  body: string;
}

export interface TaskFormErrors {
  id?: string;
  description?: string;
  command?: string;
  prompt?: string;
  url?: string;
  headers?: string;
}

export interface AddTaskVM {
  formData: TaskFormData;
  errors: TaskFormErrors;
  state: LoadingState;
  error: string | null;
  updateField: <K extends keyof TaskFormData>(
    field: K,
    value: TaskFormData[K]
  ) => void;
  validate: () => boolean;
  submit: () => Promise<boolean>;
  reset: () => void;
}

export type AddTaskVMDeps = {
  createTask?: typeof createTaskDefault;
  onSuccess?: (response: CreateTaskResponse) => void;
};

const initialFormData: TaskFormData = {
  id: "",
  executor: "shell",
  description: "",
  timeout: 300,
  command: "",
  prompt: "",
  workdir: "",
  url: "",
  method: "GET",
  headers: "",
  body: "",
};

export function useAddTaskVM(deps: AddTaskVMDeps = {}): AddTaskVM {
  const [formData, setFormData] = useState<TaskFormData>(initialFormData);
  const [errors, setErrors] = useState<TaskFormErrors>({});
  const [state, setState] = useState<LoadingState>("idle");
  const [error, setError] = useState<string | null>(null);

  const createTask = deps.createTask ?? createTaskDefault;

  const updateField = useCallback(
    <K extends keyof TaskFormData>(field: K, value: TaskFormData[K]) => {
      setFormData((prev) => ({ ...prev, [field]: value }));
      // Clear error for this field when user types
      setErrors((prev) => ({ ...prev, [field]: undefined }));
    },
    []
  );

  const validate = useCallback((): boolean => {
    const newErrors: TaskFormErrors = {};

    // ID validation
    if (!formData.id.trim()) {
      newErrors.id = "Task ID is required";
    } else if (!/^[a-z][a-z0-9_]*$/.test(formData.id)) {
      newErrors.id = "ID must start with letter, contain only lowercase, numbers, underscores";
    }

    // Description validation
    if (!formData.description.trim()) {
      newErrors.description = "Description is required";
    }

    // Executor-specific validation
    if (formData.executor === "shell") {
      if (!formData.command.trim()) {
        newErrors.command = "Command is required for shell executor";
      }
    } else if (formData.executor === "opencode") {
      if (!formData.prompt.trim()) {
        newErrors.prompt = "Prompt is required for opencode executor";
      }
    } else if (formData.executor === "http") {
      if (!formData.url.trim()) {
        newErrors.url = "URL is required for http executor";
      } else {
        try {
          new URL(formData.url);
        } catch {
          newErrors.url = "Invalid URL format";
        }
      }
    }

    // Headers JSON validation
    if (formData.headers.trim()) {
      try {
        JSON.parse(formData.headers);
      } catch {
        newErrors.headers = "Headers must be valid JSON";
      }
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  }, [formData]);

  const submit = useCallback(async (): Promise<boolean> => {
    if (!validate()) {
      return false;
    }

    setState("loading");
    setError(null);

    try {
      // Build task object
      const task: Task = {
        id: formData.id.trim(),
        executor: formData.executor,
        description: formData.description.trim(),
        timeout: formData.timeout,
      };

      // Add executor-specific fields
      if (formData.executor === "shell") {
        task.command = formData.command.trim();
      } else if (formData.executor === "opencode") {
        task.prompt = formData.prompt.trim();
      } else if (formData.executor === "http") {
        task.url = formData.url.trim();
        task.method = formData.method || "GET";
        if (formData.body.trim()) {
          task.body = formData.body.trim();
        }
      }

      // Add optional fields
      if (formData.workdir.trim()) {
        task.workdir = formData.workdir.trim();
      }

      if (formData.headers.trim()) {
        try {
          task.headers = JSON.parse(formData.headers);
        } catch {
          // Already validated, shouldn't happen
        }
      }

      const response = await createTask(task);
      setState("success");
      deps.onSuccess?.(response);
      return true;
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
      setState("error");
      return false;
    }
  }, [formData, validate, createTask, deps]);

  const reset = useCallback(() => {
    setFormData(initialFormData);
    setErrors({});
    setState("idle");
    setError(null);
  }, []);

  return {
    formData,
    errors,
    state,
    error,
    updateField,
    validate,
    submit,
    reset,
  };
}
