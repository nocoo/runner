// ============================================
// Runner Dashboard - Date Utilities
// ============================================

const WEEKDAY_NAMES = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

/**
 * Extract date key (YYYY-MM-DD) from ISO string or Date
 */
export function getDateKey(date: string | Date): string {
  const d = typeof date === "string" ? new Date(date) : date;
  const year = d.getUTCFullYear();
  const month = String(d.getUTCMonth() + 1).padStart(2, "0");
  const day = String(d.getUTCDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

/**
 * Get number of days ago from now
 */
export function getDaysAgo(isoDate: string): number {
  const date = new Date(isoDate);
  const now = new Date();
  
  // Compare date keys to handle timezone correctly
  const dateKey = getDateKey(date);
  const todayKey = getDateKey(now);
  
  const dateTime = new Date(dateKey).getTime();
  const todayTime = new Date(todayKey).getTime();
  
  return Math.floor((todayTime - dateTime) / (24 * 60 * 60 * 1000));
}

/**
 * Check if date is today
 */
export function isToday(isoDate: string): boolean {
  return getDaysAgo(isoDate) === 0;
}

/**
 * Get weekday name
 */
export function getWeekday(weekday: number | "*"): string {
  if (weekday === "*") return "Daily";
  return WEEKDAY_NAMES[weekday] || "?";
}

/**
 * Format schedule time
 */
export function formatScheduleTime(hour: number | "*", minute: number): string {
  const h = hour === "*" ? "*" : String(hour).padStart(2, "0");
  const m = String(minute).padStart(2, "0");
  return `${h}:${m}`;
}

/**
 * Get array of date keys between start and end (inclusive)
 */
export function getDateRange(startDate: string, endDate: string): string[] {
  const start = new Date(startDate);
  const end = new Date(endDate);
  const result: string[] = [];

  const cursor = new Date(start);
  while (cursor <= end) {
    result.push(getDateKey(cursor));
    cursor.setUTCDate(cursor.getUTCDate() + 1);
  }

  return result;
}

/**
 * Get date N days ago
 */
export function getDateNDaysAgo(days: number): string {
  const date = new Date();
  date.setUTCDate(date.getUTCDate() - days);
  return getDateKey(date);
}

/**
 * Get today's date key
 */
export function getTodayKey(): string {
  return getDateKey(new Date());
}
