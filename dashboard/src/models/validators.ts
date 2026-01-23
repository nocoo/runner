// ============================================
// Runner Dashboard - Data Validators
// ============================================

import type {
  SystemState,
  Task,
  Schedule,
  RunSummary,
  RunDetail,
  LastRun,
} from "./types";

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * Validate UUID format
 */
export function isValidUUID(value: unknown): value is string {
  if (typeof value !== "string") return false;
  return UUID_REGEX.test(value);
}

/**
 * Validate ISO 8601 date string
 */
export function isValidISODate(value: unknown): value is string {
  if (typeof value !== "string" || value === "") return false;
  const date = new Date(value);
  return !isNaN(date.getTime());
}

/**
 * Validate exit code (0-255)
 */
export function isValidExitCode(value: unknown): value is number {
  if (typeof value !== "number") return false;
  if (!Number.isInteger(value)) return false;
  return value >= 0 && value <= 255;
}

/**
 * Validate hour value (0-23 or "*")
 */
export function isValidHour(value: unknown): value is number | "*" {
  if (value === "*") return true;
  if (typeof value !== "number") return false;
  if (!Number.isInteger(value)) return false;
  return value >= 0 && value <= 23;
}

/**
 * Validate minute value (0-59)
 */
export function isValidMinute(value: unknown): value is number {
  if (typeof value !== "number") return false;
  if (!Number.isInteger(value)) return false;
  return value >= 0 && value <= 59;
}

/**
 * Validate weekday value (0-6 or "*")
 */
export function isValidWeekday(value: unknown): value is number | "*" {
  if (value === "*") return true;
  if (typeof value !== "number") return false;
  if (!Number.isInteger(value)) return false;
  return value >= 0 && value <= 6;
}

/**
 * Validate LastRun object
 */
export function isValidLastRun(value: unknown): value is LastRun {
  if (value === null) return false;
  if (typeof value !== "object") return false;
  
  const obj = value as Record<string, unknown>;
  return (
    isValidUUID(obj.id) &&
    typeof obj.task === "string" &&
    isValidExitCode(obj.exit_code) &&
    isValidISODate(obj.finished_at)
  );
}

/**
 * Validate SystemState object
 */
export function isValidSystemState(value: unknown): value is SystemState {
  if (value === null || typeof value !== "object") return false;
  
  const obj = value as Record<string, unknown>;
  
  if (typeof obj.version !== "string") return false;
  if (obj.last_run !== null && !isValidLastRun(obj.last_run)) return false;
  // next_scheduled can be null or an object - simplified validation
  if (typeof obj.total_runs_today !== "number") return false;
  if (typeof obj.success_rate_today !== "number") return false;
  
  return true;
}

/**
 * Validate Task object
 */
export function isValidTask(value: unknown): value is Task {
  if (value === null || typeof value !== "object") return false;
  
  const obj = value as Record<string, unknown>;
  return (
    typeof obj.id === "string" &&
    typeof obj.description === "string" &&
    typeof obj.prompt_file === "string" &&
    typeof obj.timeout === "number"
  );
}

/**
 * Validate Schedule object
 */
export function isValidSchedule(value: unknown): value is Schedule {
  if (value === null || typeof value !== "object") return false;
  
  const obj = value as Record<string, unknown>;
  return (
    typeof obj.task === "string" &&
    isValidHour(obj.hour) &&
    isValidMinute(obj.minute) &&
    isValidWeekday(obj.weekday)
  );
}

/**
 * Validate RunSummary object
 */
export function isValidRunSummary(value: unknown): value is RunSummary {
  if (value === null || typeof value !== "object") return false;
  
  const obj = value as Record<string, unknown>;
  return (
    isValidUUID(obj.id) &&
    typeof obj.task === "string" &&
    isValidExitCode(obj.exit_code) &&
    isValidISODate(obj.finished_at)
  );
}

/**
 * Validate RunDetail object
 */
export function isValidRunDetail(value: unknown): value is RunDetail {
  if (value === null || typeof value !== "object") return false;
  
  const obj = value as Record<string, unknown>;
  
  // Required fields
  if (!isValidUUID(obj.id)) return false;
  if (typeof obj.task !== "string") return false;
  if (obj.trigger !== "auto" && obj.trigger !== "manual") return false;
  if (!isValidISODate(obj.started_at)) return false;
  if (!isValidExitCode(obj.exit_code)) return false;
  
  // Optional fields
  if (obj.finished_at !== undefined && !isValidISODate(obj.finished_at)) return false;
  if (obj.duration_seconds !== undefined && typeof obj.duration_seconds !== "number") return false;
  if (obj.output_preview !== undefined && typeof obj.output_preview !== "string") return false;
  
  return true;
}
