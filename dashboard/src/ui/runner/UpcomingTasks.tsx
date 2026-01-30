// ============================================
// Upcoming Tasks - Shows next scheduled tasks with countdown
// ============================================

import type { UpcomingTask } from "@/models/types";
import { AsciiBox } from "@/ui/foundation";

interface UpcomingTasksProps {
  items: UpcomingTask[];
  count?: number;
}

/**
 * Format countdown to human readable string
 */
function formatCountdown(ms: number): string {
  if (ms <= 0) return "now";

  const seconds = Math.floor(ms / 1000);
  const minutes = Math.floor(seconds / 60);
  const hours = Math.floor(minutes / 60);

  if (hours > 0) {
    const remainingMinutes = minutes % 60;
    return `${hours}h ${remainingMinutes}m`;
  }

  if (minutes > 0) {
    const remainingSeconds = seconds % 60;
    return `${minutes}m ${remainingSeconds}s`;
  }

  return `${seconds}s`;
}

/**
 * Format time as HH:MM
 */
function formatTime(date: Date): string {
  const hours = date.getHours().toString().padStart(2, "0");
  const minutes = date.getMinutes().toString().padStart(2, "0");
  return `${hours}:${minutes}`;
}

/**
 * Format relative day label
 */
function formatDayLabel(date: Date): string {
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const targetDay = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  const diffDays = Math.floor((targetDay.getTime() - today.getTime()) / (24 * 60 * 60 * 1000));

  if (diffDays === 0) return "Today";
  if (diffDays === 1) return "Tomorrow";

  const weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
  return weekdays[date.getDay()];
}

/**
 * Get countdown color based on urgency
 */
function getCountdownColor(ms: number): string {
  const minutes = ms / 1000 / 60;
  if (minutes <= 5) return "text-warning animate-pulse";
  if (minutes <= 15) return "text-matrix-bright";
  return "text-matrix-muted";
}

export function UpcomingTasks({ items, count = 8 }: UpcomingTasksProps) {
  const upcomingWithCountdown = items.slice(0, count);

  if (upcomingWithCountdown.length === 0) {
    return (
      <AsciiBox title="Upcoming" subtitle="no data">
        <div className="h-32 flex items-center justify-center text-matrix-dim">
          No scheduled tasks
        </div>
      </AsciiBox>
    );
  }

  return (
    <AsciiBox title="Upcoming" subtitle={`next ${upcomingWithCountdown.length}`}>
      <div className="space-y-1">
        {upcomingWithCountdown.map((item, index) => (
          <UpcomingTaskRow
            key={`${item.task.id}-${item.nextRun.getTime()}-${index}`}
            item={item}
            isFirst={index === 0}
          />
        ))}
      </div>
    </AsciiBox>
  );
}

interface UpcomingTaskRowProps {
  item: UpcomingTask;
  isFirst: boolean;
}

function UpcomingTaskRow({ item, isFirst }: UpcomingTaskRowProps) {
  const { task, nextRun, countdown } = item;

  return (
    <div
      className={`flex items-center gap-3 py-2 px-2 rounded ${
        isFirst
          ? "bg-matrix-panelStrong border border-matrix-ghost"
          : "hover:bg-matrix-panel/50"
      }`}
    >
      {/* Time indicator */}
      <div className="w-14 shrink-0 text-right">
        <div className="text-body font-mono text-matrix-bright">
          {formatTime(nextRun)}
        </div>
        <div className="text-caption text-matrix-dim">
          {formatDayLabel(nextRun)}
        </div>
      </div>

      {/* Separator */}
      <div className={`w-px h-8 ${isFirst ? "bg-success" : "bg-matrix-ghost"}`} />

      {/* Task info */}
      <div className="flex-1 min-w-0">
        <div className="text-body text-matrix-primary truncate font-mono">
          {task.id}
        </div>
        <div className="text-caption text-matrix-dim truncate">
          {task.description}
        </div>
      </div>

      {/* Countdown */}
      <div className={`shrink-0 text-right font-mono ${getCountdownColor(countdown)}`}>
        <div className="text-body tabular-nums">
          {formatCountdown(countdown)}
        </div>
        {isFirst && (
          <div className="text-caption text-success uppercase tracking-wider">
            Next
          </div>
        )}
      </div>
    </div>
  );
}
