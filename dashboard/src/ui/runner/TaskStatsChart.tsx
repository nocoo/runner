// ============================================
// Task Stats Chart - Horizontal Bar Chart Per-Task
// ============================================

import { useMemo } from "react";
import { AsciiBox } from "@/ui/foundation";
import type { RunSummary } from "@/models/types";
import { groupRunsByTask } from "@/models/transforms";

interface TaskStatsChartProps {
  runs: RunSummary[];
}

interface TaskStat {
  task: string;
  total: number;
  success: number;
  failed: number;
  rate: number;
}

export function TaskStatsChart({ runs }: TaskStatsChartProps) {
  const stats = useMemo((): TaskStat[] => {
    const grouped = groupRunsByTask(runs);
    const result: TaskStat[] = [];

    for (const [task, taskRuns] of Object.entries(grouped)) {
      const completedRuns = taskRuns.filter((r) => r.exit_code !== null);
      const success = completedRuns.filter((r) => r.exit_code === 0).length;
      const failed = completedRuns.length - success;
      result.push({
        task,
        total: completedRuns.length,
        success,
        failed,
        rate: completedRuns.length > 0 ? success / completedRuns.length : 0,
      });
    }

    // Sort by total runs descending
    result.sort((a, b) => b.total - a.total);
    return result;
  }, [runs]);

  const maxTotal = Math.max(1, ...stats.map((s) => s.total));

  if (stats.length === 0) {
    return (
      <AsciiBox title="Per-Task Stats" subtitle="runs">
        <p className="text-caption text-matrix-dim font-mono text-center py-4">
          No task data available
        </p>
      </AsciiBox>
    );
  }

  return (
    <AsciiBox title="Per-Task Stats" subtitle="runs">
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-x-6 gap-y-2.5">
        {stats.map((stat) => {
          const successPct = (stat.success / maxTotal) * 100;
          const failedPct = (stat.failed / maxTotal) * 100;
          return (
            <div key={stat.task}>
              <div className="flex items-center justify-between mb-0.5">
                <span className="text-[11px] text-matrix-primary font-mono truncate max-w-[60%]">
                  {stat.task}
                </span>
                <span className="text-[10px] text-matrix-dim font-mono">
                  {stat.total} runs · {Math.round(stat.rate * 100)}%
                </span>
              </div>
              <div className="flex h-3 bg-matrix-primary/5">
                {stat.success > 0 && (
                  <div
                    className="h-full bg-matrix-primary/40"
                    style={{ width: `${successPct}%` }}
                  />
                )}
                {stat.failed > 0 && (
                  <div
                    className="h-full bg-error/40"
                    style={{ width: `${failedPct}%` }}
                  />
                )}
              </div>
            </div>
          );
        })}
      </div>
    </AsciiBox>
  );
}
