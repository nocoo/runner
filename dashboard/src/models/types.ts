// ============================================
// Runner Dashboard - Type Definitions
// ============================================

/**
 * System state from data/state.json
 */
export interface SystemState {
  version: string;
  last_run: LastRun | null;
  next_scheduled: NextScheduled | null;
  total_runs_today: number;
  success_rate_today: number;
}

export interface LastRun {
  id: string;
  task: string;
  exit_code: number;
  finished_at: string;
}

export interface NextScheduled {
  task: string;
  scheduled_at: string;
}

/**
 * Task definition from data/tasks.json
 */
export interface Task {
  id: string;
  type: "simple" | "agent";
  description: string;
  timeout: number;
  command?: string | null;
  prompt?: string | null;
  workdir?: string | null;
}

/**
 * Schedule rule from data/schedules.json
 */
export interface Schedule {
  task: string;
  hour: number | "*";
  minute: number;
  weekday: number | "*";
}

/**
 * Run summary (from runs/index.json)
 */
export interface RunSummary {
  id: string;
  task: string;
  exit_code: number;
  finished_at: string;
  duration_ms?: number;
}

/**
 * Runs index from data/runs/index.json
 */
export interface RunsIndex {
  runs: RunSummary[];
  total: number;
  updated_at: string;
}

/**
 * Full run detail from data/runs/<id>.json
 */
export interface RunDetail {
  id: string;
  task: string;
  trigger: "auto" | "manual";
  started_at: string;
  finished_at?: string;
  duration_seconds?: number;
  exit_code: number;
  output_preview?: string;
}

/**
 * Trigger response from POST /api/trigger/:task
 */
export interface TriggerResponse {
  task: string;
  exit_code: number;
  stdout: string;
  stderr: string;
}

// ============================================
// ViewModel Types
// ============================================

/**
 * Status for async operations
 */
export type LoadingState = "idle" | "loading" | "success" | "error";

/**
 * Generic async data wrapper
 */
export interface AsyncData<T> {
  data: T | null;
  state: LoadingState;
  error: string | null;
}

/**
 * Heatmap data point
 */
export interface HeatmapCell {
  date: string;
  count: number;
  success: number;
  failed: number;
}

/**
 * Trend data point
 */
export interface TrendPoint {
  date: string;
  total: number;
  success: number;
  successRate: number;
}

/**
 * Task with schedule info combined
 */
export interface TaskWithSchedule extends Task {
  schedules: Schedule[];
}

// ============================================
// UI Component Props
// ============================================

export interface StatusCardProps {
  state: SystemState | null;
  loading: boolean;
}

export interface RunTableProps {
  runs: RunSummary[];
  loading: boolean;
  onSelectRun: (id: string) => void;
}

export interface HeatmapProps {
  data: HeatmapCell[];
  weeks: number;
}

export interface TrendChartProps {
  data: TrendPoint[];
  days: number;
}
