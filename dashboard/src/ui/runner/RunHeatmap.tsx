// ============================================
// Activity Heatmap - 30 days x 8 time slots (4am-8pm, 2-hour buckets)
// Layout: columns = days, rows = time slots (Chinese traditional hours)
// ============================================

import { useMemo, useRef, useEffect } from "react";
import type { HeatmapCell } from "@/models/types";
import { AsciiBox } from "@/ui/foundation";
import { getDateKey } from "@/lib/date";

const OPACITY_BY_LEVEL = [0.08, 0.32, 0.5, 0.7, 1];
const CELL_SIZE = 14;
const CELL_GAP = 3;
const DAYS_TO_SHOW = 30;

// 2-hour slots from 4am to 8pm with Chinese hour names (时辰)
const TIME_SLOTS = [4, 6, 8, 10, 12, 14, 16, 18];
const CHINESE_HOURS: Record<number, string> = {
  4: "卯",
  6: "辰",
  8: "巳",
  10: "午",
  12: "未",
  14: "申",
  16: "酉",
  18: "戌",
};

interface RunHeatmapProps {
  data: HeatmapCell[];
}

function getLevel(count: number): number {
  if (count === 0) return 0;
  if (count <= 2) return 1;
  if (count <= 5) return 2;
  if (count <= 10) return 3;
  return 4;
}

function formatSlotRange(slot: number): string {
  const end = slot + 2;
  return `${slot.toString().padStart(2, "0")}:00-${end.toString().padStart(2, "0")}:00`;
}

function formatDayLabel(dateStr: string): string {
  const date = new Date(dateStr);
  return date.getDate().toString();
}

export function RunHeatmap({ data }: RunHeatmapProps) {
  const scrollRef = useRef<HTMLDivElement>(null);

  // Scroll to right on mount
  useEffect(() => {
    const el = scrollRef.current;
    if (el) {
      el.scrollLeft = el.scrollWidth;
    }
  }, []);

  // Build grid: 8 rows (time slots) x 30 columns (days)
  const { grid, dayLabels } = useMemo(() => {
    const now = new Date();

    // Generate date strings for last 30 days (oldest first) using local time
    const dates: string[] = [];
    for (let i = DAYS_TO_SHOW - 1; i >= 0; i--) {
      const date = new Date(now);
      date.setDate(date.getDate() - i);
      dates.push(getDateKey(date));
    }

    // Create lookup map: "YYYY-MM-DD:HH" -> cell
    const dataMap = new Map<string, HeatmapCell>();
    for (const cell of data) {
      const datePart = cell.date.split("T")[0];
      const hourPart = cell.date.split("T")[1]?.substring(0, 2) || "00";
      const key = `${datePart}:${hourPart}`;
      dataMap.set(key, cell);
    }

    // Build grid: rows = time slots, columns = days
    const rows: (HeatmapCell | null)[][] = [];

    for (const slot of TIME_SLOTS) {
      const row: (HeatmapCell | null)[] = [];
      const slotStr = slot.toString().padStart(2, "0");

      for (const dateStr of dates) {
        const key = `${dateStr}:${slotStr}`;
        const cell = dataMap.get(key);

        if (cell) {
          row.push(cell);
        } else {
          row.push({
            date: `${dateStr}T${slotStr}:00:00`,
            count: 0,
            success: 0,
            failed: 0,
          });
        }
      }
      rows.push(row);
    }

    const labels = dates.map(formatDayLabel);
    return { grid: rows, dayLabels: labels };
  }, [data]);

  const gridWidth = 20 + DAYS_TO_SHOW * CELL_SIZE + (DAYS_TO_SHOW - 1) * CELL_GAP + CELL_GAP + 20;

  return (
    <AsciiBox title="Activity" subtitle="last 30 days">
      <div className="flex flex-col gap-2">
        <div
          ref={scrollRef}
          className="overflow-x-auto no-scrollbar"
          style={{ scrollbarWidth: "none" }}
        >
          <div style={{ minWidth: gridWidth }}>
            {/* Day headers */}
            <div
              className="grid text-caption text-matrix-muted mb-2"
              style={{
                gridTemplateColumns: `20px repeat(${DAYS_TO_SHOW}, ${CELL_SIZE}px) 20px`,
                gap: `${CELL_GAP}px`,
              }}
            >
              <span></span>
              {dayLabels.map((label, idx) => (
                <span key={idx} className="text-center">
                  {label}
                </span>
              ))}
              <span></span>
            </div>

            {/* Grid rows (time slots) */}
            <div className="flex flex-col" style={{ gap: `${CELL_GAP}px` }}>
              {grid.map((row, rowIdx) => {
                const slot = TIME_SLOTS[rowIdx];
                return (
                  <div
                    key={rowIdx}
                    className="grid items-center"
                  style={{
                    gridTemplateColumns: `20px repeat(${DAYS_TO_SHOW}, ${CELL_SIZE}px) 20px`,
                    gap: `${CELL_GAP}px`,
                  }}
                  >
                    {/* Time slot label (Chinese hour) */}
                    <span className="text-caption text-matrix-muted text-right pr-1">
                      {CHINESE_HOURS[slot]}
                    </span>

                    {/* Cells for each day */}
                    {row.map((cell, colIdx) => {
                      const key = cell?.date || `empty-${rowIdx}-${colIdx}`;

                      if (!cell) {
                        return (
                          <span
                            key={key}
                            className="border border-transparent"
                            style={{ width: CELL_SIZE, height: CELL_SIZE }}
                          />
                        );
                      }

                      const level = getLevel(cell.count);
                      const opacity = OPACITY_BY_LEVEL[level] ?? 0.08;
                      const color = `rgba(0,255,65,${opacity})`;

                      return (
                        <span
                          key={key}
                          title={`${dayLabels[colIdx]}日 ${CHINESE_HOURS[slot]}时 (${formatSlotRange(slot)}): ${cell.count} runs (${cell.success} ✓, ${cell.failed} ✗)`}
                          className="border border-matrix-ghost cursor-default"
                          style={{
                            width: CELL_SIZE,
                            height: CELL_SIZE,
                            background: color,
                          }}
                        />
                      );
                    })}

                    {/* Time slot label right side */}
                    <span className="text-caption text-matrix-muted text-left pl-1">
                      {CHINESE_HOURS[slot]}
                    </span>
                  </div>
                );
              })}
            </div>
          </div>
        </div>

        {/* Legend */}
        <div className="flex justify-between items-center text-caption border-t border-matrix-ghost pt-2 text-matrix-muted font-bold uppercase">
          <div className="flex items-center gap-2">
            <span>Less</span>
            <div className="flex gap-1">
              {[0, 1, 2, 3, 4].map((level) => (
                <span
                  key={level}
                  className="border border-matrix-ghost"
                  style={{
                    width: 10,
                    height: 10,
                    background: `rgba(0,255,65,${OPACITY_BY_LEVEL[level]})`,
                  }}
                />
              ))}
            </div>
            <span>More</span>
          </div>
        </div>
      </div>
    </AsciiBox>
  );
}
