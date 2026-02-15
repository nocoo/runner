// ============================================
// History Page - Run History & Visualizations
// ============================================

import { useRunsVM } from "@/viewmodels";
import {
  RunHistory,
  RunHeatmap,
  TrendChart,
  RunDetailModal,
} from "@/ui/runner";

export function HistoryPage() {
  const runsVM = useRunsVM(24);

  return (
    <>
      {/* Heatmap + Trend row */}
      <div className="grid grid-cols-12 gap-4 mb-4">
        <div className="col-span-12 lg:col-span-6">
          <RunHeatmap data={runsVM.heatmapData} />
        </div>
        <div className="col-span-12 lg:col-span-6">
          <TrendChart data={runsVM.trendData} />
        </div>
      </div>

      {/* Visualizations row — placeholder, will be filled with 4 new viz components */}
      <div className="grid grid-cols-12 gap-4 mb-4">
        {/* SuccessRateDonut, DurationDistribution, TaskStatsChart, RunTimeline go here */}
      </div>

      {/* Run History table */}
      <RunHistory
        runs={runsVM.pagedRuns}
        loading={runsVM.state === "loading"}
        page={runsVM.page}
        totalPages={runsVM.totalPages}
        onPageChange={runsVM.setPage}
        onSelectRun={runsVM.selectRun}
      />

      {/* Run Detail Modal */}
      <RunDetailModal
        run={runsVM.selectedRun}
        loading={runsVM.selectedRunLoading}
        output={runsVM.selectedRunOutput}
        outputLoading={runsVM.selectedRunOutputLoading}
        outputError={runsVM.selectedRunOutputError}
        onClose={() => runsVM.selectRun(null)}
      />
    </>
  );
}
