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
  UpcomingTask,
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
 * Note: Only completed runs (with finished_at) are included
 */
export function runsToHeatmap(runs: RunSummary[]): HeatmapCell[] {
  if (runs.length === 0) return [];

  const byDateSlot = new Map<string, { count: number; success: number; failed: number }>();

  for (const run of runs) {
    // Skip running tasks (no finished_at)
    if (!run.finished_at) continue;
    
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
 * Get 10-minute slot key from date: "YYYY-MM-DDTHH:M0" where M0 is 00, 10, 20, 30, 40, 50
 */
function get10MinSlotKey(date: Date): string {
  const year = date.getFullYear();
  const month = (date.getMonth() + 1).toString().padStart(2, "0");
  const day = date.getDate().toString().padStart(2, "0");
  const hour = date.getHours().toString().padStart(2, "0");
  const minute10 = Math.floor(date.getMinutes() / 10) * 10;
  const minuteStr = minute10.toString().padStart(2, "0");
  return `${year}-${month}-${day}T${hour}:${minuteStr}`;
}

/**
 * Convert runs to trend points for 10-minute intervals (last 24 hours)
 * Note: Only completed runs (with finished_at) are included
 */
export function runsToTrend(runs: RunSummary[]): TrendPoint[] {
  const now = new Date();
  const oneDayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);

  const bySlot = new Map<string, { total: number; success: number }>();

  for (const run of runs) {
    // Skip running tasks (no finished_at)
    if (!run.finished_at) continue;
    
    const runTime = new Date(run.finished_at);

    // Only include runs from the last 24 hours
    if (runTime < oneDayAgo) continue;

    const slotKey = get10MinSlotKey(runTime);
    const existing = bySlot.get(slotKey) || { total: 0, success: 0 };

    existing.total += 1;
    if (run.exit_code === 0) {
      existing.success += 1;
    }

    bySlot.set(slotKey, existing);
  }

  // Generate all 10-minute slots for the last 24 hours (144 slots)
  const result: TrendPoint[] = [];
  const slotMs = 10 * 60 * 1000; // 10 minutes
  // Round down to nearest 10-minute slot
  const startSlot = new Date(Math.floor(oneDayAgo.getTime() / slotMs) * slotMs);
  
  for (let i = 0; i < 144; i++) {
    const slotTime = new Date(startSlot.getTime() + i * slotMs);
    const slotKey = get10MinSlotKey(slotTime);
    const stats = bySlot.get(slotKey) || { total: 0, success: 0 };

    result.push({
      date: slotKey,
      total: stats.total,
      success: stats.success,
      successRate: stats.total > 0 ? stats.success / stats.total : 0,
    });
  }

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
 * Sort runs by finished_at date (running tasks without finished_at go to top)
 */
export function sortRunsByDate(
  runs: RunSummary[],
  order: "asc" | "desc" = "desc"
): RunSummary[] {
  const sorted = [...runs];
  
  sorted.sort((a, b) => {
    // Running tasks (no finished_at) go to top when desc, bottom when asc
    if (!a.finished_at && !b.finished_at) return 0;
    if (!a.finished_at) return order === "desc" ? -1 : 1;
    if (!b.finished_at) return order === "desc" ? 1 : -1;
    
    const diff = new Date(a.finished_at).getTime() - new Date(b.finished_at).getTime();
    return order === "asc" ? diff : -diff;
  });

  return sorted;
}

/**
 * Filter runs to a specific date range
 * Note: Running tasks (no finished_at) are excluded
 */
export function filterRunsByDateRange(
  runs: RunSummary[],
  startDate: string,
  endDate: string
): RunSummary[] {
  const start = new Date(startDate).getTime();
  const end = new Date(endDate).getTime();

  return runs.filter((run) => {
    if (!run.finished_at) return false;
    const time = new Date(run.finished_at).getTime();
    return time >= start && time <= end;
  });
}

/**
 * Get runs from the last N days
 * Note: Running tasks (no finished_at) are excluded
 */
export function getRunsLastNDays(runs: RunSummary[], days: number): RunSummary[] {
  const now = new Date();
  const cutoff = new Date(now.getTime() - days * 24 * 60 * 60 * 1000);

  return runs.filter((run) => {
    if (!run.finished_at) return false;
    return new Date(run.finished_at) >= cutoff;
  });
}

// ============================================
// Crontab Expression Matching
// ============================================

/**
 * Check if a value matches a crontab expression
 * Supports: *, N, N-M (range), N,M,O (list), * /N (step)
 */
function cronMatch(expr: string | number, value: number): boolean {
  const exprStr = String(expr);

  // Wildcard: matches everything
  if (exprStr === "*") {
    return true;
  }

  // Step expression: */N
  const stepMatch = exprStr.match(/^\*\/(\d+)$/);
  if (stepMatch) {
    const step = parseInt(stepMatch[1], 10);
    if (step === 0) return false;
    return value % step === 0;
  }

  // Range expression: N-M
  const rangeMatch = exprStr.match(/^(\d+)-(\d+)$/);
  if (rangeMatch) {
    const start = parseInt(rangeMatch[1], 10);
    const end = parseInt(rangeMatch[2], 10);
    return value >= start && value <= end;
  }

  // List expression: N,M,O
  if (exprStr.includes(",")) {
    const values = exprStr.split(",").map((v) => parseInt(v.trim(), 10));
    return values.includes(value);
  }

  // Exact value: N
  const numMatch = exprStr.match(/^\d+$/);
  if (numMatch) {
    return parseInt(exprStr, 10) === value;
  }

  return false;
}

/**
 * Get all matching values for a crontab expression within a range
 */
function getMatchingValues(expr: string | number, min: number, max: number): number[] {
  const result: number[] = [];
  for (let i = min; i <= max; i++) {
    if (cronMatch(expr, i)) {
      result.push(i);
    }
  }
  return result;
}

/**
 * Calculate next run time for a schedule starting from a given time
 */
function calculateNextRun(schedule: Schedule, from: Date): Date | null {
  const { hour, minute, weekday } = schedule;

  // Get all matching hours and minutes
  const matchingHours = getMatchingValues(hour, 0, 23);
  const matchingMinutes = getMatchingValues(minute, 0, 59);
  const matchingWeekdays = getMatchingValues(weekday, 0, 6);

  if (matchingHours.length === 0 || matchingMinutes.length === 0 || matchingWeekdays.length === 0) {
    return null;
  }

  // Start searching from current time
  const candidate = new Date(from);
  candidate.setSeconds(0, 0);

  // Search up to 7 days ahead
  for (let dayOffset = 0; dayOffset < 8; dayOffset++) {
    const checkDate = new Date(candidate);
    checkDate.setDate(checkDate.getDate() + dayOffset);

    // Check if weekday matches
    if (!matchingWeekdays.includes(checkDate.getDay())) {
      continue;
    }

    for (const h of matchingHours) {
      for (const m of matchingMinutes) {
        const checkTime = new Date(checkDate);
        checkTime.setHours(h, m, 0, 0);

        // Must be in the future
        if (checkTime > from) {
          return checkTime;
        }
      }
    }
  }

  return null;
}

/**
 * Calculate upcoming tasks sorted by next run time
 */
export function calculateUpcomingTasks(
  tasks: Task[],
  schedules: Schedule[],
  count: number = 8
): UpcomingTask[] {
  const now = new Date();
  const upcoming: UpcomingTask[] = [];

  for (const schedule of schedules) {
    const task = tasks.find((t) => t.id === schedule.task);
    if (!task) continue;

    const nextRun = calculateNextRun(schedule, now);
    if (!nextRun) continue;

    upcoming.push({
      task,
      schedule,
      nextRun,
      countdown: nextRun.getTime() - now.getTime(),
    });
  }

  // Sort by next run time (soonest first)
  upcoming.sort((a, b) => a.nextRun.getTime() - b.nextRun.getTime());

  // Return top N unique tasks (avoid duplicates if same task has multiple schedules)
  const seen = new Set<string>();
  const result: UpcomingTask[] = [];

  for (const item of upcoming) {
    // Create unique key for task + time slot
    const timeKey = `${item.task.id}-${item.nextRun.getTime()}`;
    if (!seen.has(timeKey)) {
      seen.add(timeKey);
      result.push(item);
      if (result.length >= count) break;
    }
  }

  return result;
}
