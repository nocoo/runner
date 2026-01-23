// ============================================
// Activity Heatmap (GitHub-style)
// ============================================

import type { HeatmapCell } from "@/models/types";
import { AsciiBox } from "@/ui/foundation";

interface RunHeatmapProps {
  data: HeatmapCell[];
  weeks?: number;
}

function getIntensity(count: number): string {
  if (count === 0) return "bg-matrix-ghost/30";
  if (count <= 2) return "bg-matrix-dim";
  if (count <= 5) return "bg-matrix-muted";
  if (count <= 10) return "bg-matrix-primary";
  return "bg-matrix-bright";
}

function getTitle(cell: HeatmapCell): string {
  return `${cell.date}: ${cell.count} runs (${cell.success} success, ${cell.failed} failed)`;
}

export function RunHeatmap({ data, weeks = 12 }: RunHeatmapProps) {
  // Group data by week (7 days per column)
  // For simplicity, show last N weeks
  const daysToShow = weeks * 7;
  
  // Create a map for quick lookup
  const dataMap = new Map(data.map((d) => [d.date, d]));
  
  // Generate date grid
  const today = new Date();
  const grid: (HeatmapCell | null)[][] = [];
  
  for (let w = weeks - 1; w >= 0; w--) {
    const week: (HeatmapCell | null)[] = [];
    for (let d = 0; d < 7; d++) {
      const daysAgo = w * 7 + (6 - d);
      if (daysAgo < 0 || daysAgo >= daysToShow) {
        week.push(null);
        continue;
      }
      
      const date = new Date(today);
      date.setUTCDate(date.getUTCDate() - daysAgo);
      const dateKey = date.toISOString().split("T")[0];
      
      const cell = dataMap.get(dateKey) || {
        date: dateKey,
        count: 0,
        success: 0,
        failed: 0,
      };
      week.push(cell);
    }
    grid.push(week);
  }

  const weekLabels = ["S", "M", "T", "W", "T", "F", "S"];

  return (
    <AsciiBox title="Activity" subtitle={`last ${weeks} weeks`}>
      <div className="flex gap-1">
        {/* Day labels */}
        <div className="flex flex-col gap-1 mr-1 text-caption text-matrix-dim">
          {weekLabels.map((label, i) => (
            <div key={i} className="w-3 h-3 flex items-center justify-center">
              {i % 2 === 1 ? label : ""}
            </div>
          ))}
        </div>

        {/* Heatmap grid */}
        <div className="flex gap-1 overflow-x-auto no-scrollbar">
          {grid.map((week, weekIdx) => (
            <div key={weekIdx} className="flex flex-col gap-1">
              {week.map((cell, dayIdx) => (
                <div
                  key={dayIdx}
                  className={`w-3 h-3 rounded-sm ${
                    cell ? getIntensity(cell.count) : "bg-transparent"
                  }`}
                  title={cell ? getTitle(cell) : undefined}
                />
              ))}
            </div>
          ))}
        </div>
      </div>

      {/* Legend */}
      <div className="flex items-center justify-end gap-2 mt-4 text-caption text-matrix-dim">
        <span>Less</span>
        <div className="flex gap-1">
          <div className="w-3 h-3 rounded-sm bg-matrix-ghost/30"></div>
          <div className="w-3 h-3 rounded-sm bg-matrix-dim"></div>
          <div className="w-3 h-3 rounded-sm bg-matrix-muted"></div>
          <div className="w-3 h-3 rounded-sm bg-matrix-primary"></div>
          <div className="w-3 h-3 rounded-sm bg-matrix-bright"></div>
        </div>
        <span>More</span>
      </div>
    </AsciiBox>
  );
}
