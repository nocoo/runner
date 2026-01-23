// ============================================
// Runner Dashboard - Data Transforms
// ============================================

import type {
  RunSummary,
  Task,
  Schedule,
  HeatmapCell,
  TrendPoint,
  TaskWithSchedule,
} from "./types";

/**
 * Extract date string (YYYY-MM-DD) from ISO datetime
 */
function extractDate(isoDate: string): string {
  return isoDate.split("T")[0];
}

/**
 * Convert runs to heatmap cells grouped by date
 */
export function runsToHeatmap(runs: RunSummary[]): HeatmapCell[] {
  if (runs.length === 0) return [];

  const byDate = new Map<string, { count: number; success: number; failed: number }>();

  for (const run of runs) {
    const date = extractDate(run.finished_at);
    const existing = byDate.get(date) || { count: 0, success: 0, failed: 0 };
    
    existing.count += 1;
    if (run.exit_code === 0) {
      existing.success += 1;
    } else {
      existing.failed += 1;
    }
    
    byDate.set(date, existing);
  }

  const result: HeatmapCell[] = [];
  for (const [date, stats] of byDate) {
    result.push({ date, ...stats });
  }

  // Sort by date ascending
  result.sort((a, b) => a.date.localeCompare(b.date));

  return result;
}

/**
 * Convert runs to trend points for charting
 */
export function runsToTrend(runs: RunSummary[]): TrendPoint[] {
  if (runs.length === 0) return [];

  const byDate = new Map<string, { total: number; success: number }>();

  for (const run of runs) {
    const date = extractDate(run.finished_at);
    const existing = byDate.get(date) || { total: 0, success: 0 };
    
    existing.total += 1;
    if (run.exit_code === 0) {
      existing.success += 1;
    }
    
    byDate.set(date, existing);
  }

  const result: TrendPoint[] = [];
  for (const [date, stats] of byDate) {
    result.push({
      date,
      total: stats.total,
      success: stats.success,
      successRate: stats.total > 0 ? stats.success / stats.total : 0,
    });
  }

  // Sort by date ascending
  result.sort((a, b) => a.date.localeCompare(b.date));

  return result;
}

/**
 * Group runs by task name
 */
export function groupRunsByTask(runs: RunSummary[]): Record<string, RunSummary[]> {
  const result: Record<string, RunSummary[]> = {};

  for (const run of runs) {
    if (!result[run.task]) {
      result[run.task] = [];
    }
    result[run.task].push(run);
  }

  return result;
}

/**
 * Combine tasks with their schedules
 */
export function combineTasksWithSchedules(
  tasks: Task[],
  schedules: Schedule[]
): TaskWithSchedule[] {
  return tasks.map((task) => ({
    ...task,
    schedules: schedules.filter((s) => s.task === task.id),
  }));
}

/**
 * Calculate success rate from runs (0-1)
 */
export function calculateSuccessRate(runs: RunSummary[]): number {
  if (runs.length === 0) return 0;
  
  const successful = runs.filter((r) => r.exit_code === 0).length;
  return successful / runs.length;
}

/**
 * Sort runs by finished_at date
 */
export function sortRunsByDate(
  runs: RunSummary[],
  order: "asc" | "desc" = "desc"
): RunSummary[] {
  const sorted = [...runs];
  
  sorted.sort((a, b) => {
    const diff = new Date(a.finished_at).getTime() - new Date(b.finished_at).getTime();
    return order === "asc" ? diff : -diff;
  });

  return sorted;
}

/**
 * Filter runs to a specific date range
 */
export function filterRunsByDateRange(
  runs: RunSummary[],
  startDate: string,
  endDate: string
): RunSummary[] {
  const start = new Date(startDate).getTime();
  const end = new Date(endDate).getTime();

  return runs.filter((run) => {
    const time = new Date(run.finished_at).getTime();
    return time >= start && time <= end;
  });
}

/**
 * Get runs from the last N days
 */
export function getRunsLastNDays(runs: RunSummary[], days: number): RunSummary[] {
  const now = new Date();
  const cutoff = new Date(now.getTime() - days * 24 * 60 * 60 * 1000);

  return runs.filter((run) => new Date(run.finished_at) >= cutoff);
}
