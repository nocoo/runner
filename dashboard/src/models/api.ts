// ============================================
// Runner Dashboard - API Layer
// ============================================

import type {
  SystemState,
  Task,
  Schedule,
  RunsIndex,
  RunDetail,
  TriggerResponse,
} from "./types";

/**
 * Base fetch wrapper with error handling
 */
async function apiFetch<T>(url: string, options?: RequestInit): Promise<T> {
  const response = await fetch(url, options);
  
  if (!response.ok) {
    const error = await response.text().catch(() => "Unknown error");
    throw new Error(`API Error (${response.status}): ${error}`);
  }
  
  return response.json();
}

/**
 * Fetch system status
 */
export async function fetchStatus(): Promise<SystemState> {
  return apiFetch<SystemState>("/api/status");
}

/**
 * Fetch task list
 */
export async function fetchTasks(): Promise<Task[]> {
  return apiFetch<Task[]>("/api/tasks");
}

/**
 * Fetch schedule list
 */
export async function fetchSchedules(): Promise<Schedule[]> {
  return apiFetch<Schedule[]>("/api/schedules");
}

/**
 * Fetch runs index
 */
export async function fetchRuns(): Promise<RunsIndex> {
  return apiFetch<RunsIndex>("/api/runs");
}

/**
 * Fetch run detail by id
 */
export async function fetchRunDetail(id: string): Promise<RunDetail> {
  return apiFetch<RunDetail>(`/api/runs/${id}`);
}

/**
 * Trigger a task execution
 */
export async function triggerTask(taskId: string): Promise<TriggerResponse> {
  return apiFetch<TriggerResponse>(`/api/trigger/${taskId}`, {
    method: "POST",
  });
}
