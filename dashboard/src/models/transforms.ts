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
 * Extract local date string (YYYY-MM-DD) from ISO datetime
 */
function extractLocalDate(isoDate: string): string {
  const date = new Date(isoDate);
  const year = date.getFullYear();
  const month = (date.getMonth() + 1).toString().padStart(2, "0");
  const day = date.getDate().toString().padStart(2, "0");
  return `${year}-${month}-${day}`;
}

/**
 * Extract local hour as number from ISO datetime
 */
function extractLocalHour(isoDate: string): number {
  const date = new Date(isoDate);
  return date.getHours();
}

/**
 * Get 2-hour slot start (4, 6, 8, 10, 12, 14, 16, 18)
 * Only for hours 4-19 (4am-8pm range)
 */
function get2HourSlot(hour: number): number | null {
  if (hour < 4 || hour >= 20) return null;
  return Math.floor(hour / 2) * 2;
}

/**
 * Convert runs to heatmap cells grouped by date and 2-hour slot
 * Only includes runs from 4am-8pm, aggregated into 2-hour buckets
 * Returns cells with date format: "YYYY-MM-DDTHH:00:00" where HH is slot start (04, 06, 08, ...)
 */
export function runsToHeatmap(runs: RunSummary[]): HeatmapCell[] {
  if (runs.length === 0) return [];

  const byDateSlot = new Map<string, { count: number; success: number; failed: number }>();

  for (const run of runs) {
    const date = extractLocalDate(run.finished_at);
    const hour = extractLocalHour(run.finished_at);
    const slot = get2HourSlot(hour);
    
    // Skip runs outside 4am-8pm
    if (slot === null) continue;
    
    const slotStr = slot.toString().padStart(2, "0");
    const key = `${date}T${slotStr}:00:00`;
    const existing = byDateSlot.get(key) || { count: 0, success: 0, failed: 0 };
    
    existing.count += 1;
    if (run.exit_code === 0) {
      existing.success += 1;
    } else {
      existing.failed += 1;
    }
    
    byDateSlot.set(key, existing);
  }

  const result: HeatmapCell[] = [];
  for (const [date, stats] of byDateSlot) {
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
    const date = extractLocalDate(run.finished_at);
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
