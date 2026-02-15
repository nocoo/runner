// ============================================
// Run Timeline - Time-Axis Visualization
// ============================================

import { useMemo } from "react";
import { AsciiBox } from "@/ui/foundation";
import type { RunSummary } from "@/models/types";

interface RunTimelineProps {
  runs: RunSummary[];
}

interface TimelineEntry {
  id: string;
  task: string;
  startPct: number;   // percentage position on the 24h axis
  widthPct: number;    // percentage width on the 24h axis
  exitCode: number | null;
  row: number;         // stacking row for concurrency
}

const HOURS_WINDOW = 24;
const HOUR_LABELS = [0, 4, 8, 12, 16, 20];

function exitCodeToColor(exitCode: number | null): string {
  if (exitCode === null) return "rgba(0, 255, 65, 0.7)"; // running — bright pulse
  if (exitCode === 0) return "rgba(0, 255, 65, 0.4)";    // success
  if (exitCode === -1) return "rgba(255, 215, 0, 0.4)";  // interrupted
  return "rgba(255, 65, 65, 0.4)";                       // failed
}

export function RunTimeline({ runs }: RunTimelineProps) {
  const { entries, rowCount } = useMemo(() => {
    const now = Date.now();
    const windowStart = now - HOURS_WINDOW * 60 * 60 * 1000;
    const windowMs = HOURS_WINDOW * 60 * 60 * 1000;

    // Include runs that started within the window, or are still running
    const recent = runs.filter((run) => {
      const start = new Date(run.started_at).getTime();
      const end = run.finished_at ? new Date(run.finished_at).getTime() : now;
      return end >= windowStart && start <= now;
    });

    // Build raw entries
    const raw: Omit<TimelineEntry, "row">[] = [];
    for (const run of recent) {
      const start = new Date(run.started_at).getTime();
      const end = run.finished_at ? new Date(run.finished_at).getTime() : now;

      // Clamp to window
      const clampedStart = Math.max(start, windowStart);
      const clampedEnd = Math.min(end, now);
      if (clampedEnd <= clampedStart) continue;

      const startPct = ((clampedStart - windowStart) / windowMs) * 100;
      const widthPct = Math.max(0.5, ((clampedEnd - clampedStart) / windowMs) * 100);

      raw.push({
        id: run.id,
        task: run.task,
        startPct,
        widthPct,
        exitCode: run.exit_code,
      });
    }

    // Sort by start position
    raw.sort((a, b) => a.startPct - b.startPct);

    // Assign rows for concurrency (greedy lane allocation)
    const lanes: number[] = []; // end position of each lane
    const entries: TimelineEntry[] = raw.map((entry) => {
      const endPct = entry.startPct + entry.widthPct;
      let row = 0;
      let placed = false;

      for (let i = 0; i < lanes.length; i++) {
        if (entry.startPct >= lanes[i]) {
          lanes[i] = endPct;
          row = i;
          placed = true;
          break;
        }
      }

      if (!placed) {
        row = lanes.length;
        lanes.push(endPct);
      }

      return { ...entry, row };
    });

    return { entries, rowCount: Math.max(1, lanes.length) };
  }, [runs]);

  const rowHeight = 14;
  const chartHeight = rowCount * (rowHeight + 2) + 20;

  return (
    <AsciiBox title="Timeline" subtitle="24h">
      <div className="relative" style={{ height: `${chartHeight}px` }}>
        {/* Hour grid lines + labels */}
        {HOUR_LABELS.map((hour) => {
          const now = new Date();
          const windowStart = Date.now() - HOURS_WINDOW * 60 * 60 * 1000;
          const hourDate = new Date(now);
          hourDate.setHours(hour, 0, 0, 0);
          // If hour is in the future relative to now, subtract a day
          let ts = hourDate.getTime();
          if (ts > Date.now()) ts -= 24 * 60 * 60 * 1000;
          if (ts < windowStart) ts += 24 * 60 * 60 * 1000;
          const pct = ((ts - windowStart) / (HOURS_WINDOW * 60 * 60 * 1000)) * 100;
          if (pct < 0 || pct > 100) return null;

          return (
            <div
              key={hour}
              className="absolute top-0 bottom-0"
              style={{ left: `${pct}%` }}
            >
              <div className="h-full border-l border-matrix-primary/10" />
              <span className="absolute bottom-0 -translate-x-1/2 text-[9px] text-matrix-dim font-mono">
                {hour.toString().padStart(2, "0")}
              </span>
            </div>
          );
        })}

        {/* Timeline entries */}
        {entries.map((entry) => (
          <div
            key={entry.id}
            className="absolute transition-opacity hover:opacity-100"
            title={`${entry.task} (${entry.exitCode === null ? "running" : entry.exitCode === 0 ? "ok" : "fail"})`}
            style={{
              left: `${entry.startPct}%`,
              width: `${entry.widthPct}%`,
              top: `${entry.row * (rowHeight + 2)}px`,
              height: `${rowHeight}px`,
              background: exitCodeToColor(entry.exitCode),
              opacity: 0.85,
              minWidth: "3px",
            }}
          >
            <span className="text-[8px] text-matrix-dark font-mono truncate block px-0.5 leading-[14px]">
              {entry.widthPct > 5 ? entry.task : ""}
            </span>
          </div>
        ))}

        {/* Empty state */}
        {entries.length === 0 && (
          <p className="text-caption text-matrix-dim font-mono text-center py-6">
            No runs in the last 24 hours
          </p>
        )}
      </div>
    </AsciiBox>
  );
}
