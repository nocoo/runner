// ============================================
// System Status Panel
// ============================================

import type { SystemState } from "@/models/types";
import { AsciiBox } from "@/ui/foundation";
import { formatRelativeTime } from "@/lib/format";

interface SystemStatusProps {
  data: SystemState | null;
  loading: boolean;
  successRatePercent: string;
  lastRunStatus: string;
  onRefresh?: () => void;
}

export function SystemStatus({
  data,
  loading,
  successRatePercent,
  lastRunStatus,
  onRefresh,
}: SystemStatusProps) {
  if (loading && !data) {
    return (
      <AsciiBox title="System Status" subtitle="loading">
        <div className="animate-pulse space-y-3">
          <div className="h-4 bg-matrix-ghost rounded w-3/4"></div>
          <div className="h-4 bg-matrix-ghost rounded w-1/2"></div>
        </div>
      </AsciiBox>
    );
  }

  return (
    <AsciiBox title="System Status" subtitle={data?.version ?? "?"}>
      <div className="space-y-4">
        {/* Version */}
        <div className="flex justify-between items-center">
          <span className="text-matrix-muted uppercase text-caption">Version</span>
          <span className="text-matrix-primary font-bold">{data?.version ?? "-"}</span>
        </div>

        {/* Last Run */}
        <div className="flex justify-between items-center">
          <span className="text-matrix-muted uppercase text-caption">Last Run</span>
          <div className="text-right">
            <span className={`font-bold ${lastRunStatus === "success" ? "text-success" : "text-error"}`}>
              {data?.last_run?.task ?? "-"}
            </span>
            {data?.last_run && (
              <span className="text-matrix-dim text-caption ml-2">
                ({formatRelativeTime(data.last_run.finished_at)})
              </span>
            )}
          </div>
        </div>

        {/* Today Stats */}
        <div className="flex justify-between items-center">
          <span className="text-matrix-muted uppercase text-caption">Today</span>
          <div className="flex items-center gap-4">
            <span className="text-matrix-primary">
              <span className="font-bold">{data?.total_runs_today ?? 0}</span>
              <span className="text-matrix-dim text-caption ml-1">runs</span>
            </span>
            <span className={`font-bold ${
              (data?.success_rate_today ?? 0) >= 0.8 ? "text-success" : 
              (data?.success_rate_today ?? 0) >= 0.5 ? "text-warning" : "text-error"
            }`}>
              {successRatePercent}
            </span>
          </div>
        </div>

        {/* Next Scheduled */}
        <div className="flex justify-between items-center">
          <span className="text-matrix-muted uppercase text-caption">Next</span>
          <span className="text-matrix-dim">
            {data?.next_scheduled?.task ?? "No scheduled task"}
          </span>
        </div>

        {/* Refresh Button */}
        {onRefresh && (
          <button
            onClick={onRefresh}
            disabled={loading}
            className="w-full mt-2 py-2 border border-matrix-ghost text-caption uppercase font-bold hover:border-matrix-primary hover:bg-matrix-panelStrong transition-colors disabled:opacity-50"
          >
            {loading ? "Refreshing..." : "Refresh"}
          </button>
        )}
      </div>
    </AsciiBox>
  );
}
