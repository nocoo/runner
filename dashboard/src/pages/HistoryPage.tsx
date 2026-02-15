// ============================================
// History Page - Run History & Visualizations
// ============================================

import { useRunsVM } from "@/viewmodels";
import {
  RunHistory,
  RunHeatmap,
  TrendChart,
  RunDetailModal,
  SuccessRateDonut,
  DurationDistribution,
  TaskStatsChart,
  RunTimeline,
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

      {/* Visualizations row */}
      <div className="grid grid-cols-12 gap-4 mb-4">
        <div className="col-span-12 lg:col-span-4">
          <SuccessRateDonut runs={runsVM.runs} />
        </div>
        <div className="col-span-12 lg:col-span-4">
          <DurationDistribution runs={runsVM.runs} />
        </div>
        <div className="col-span-12 lg:col-span-4">
          <TaskStatsChart runs={runsVM.runs} />
        </div>
      </div>

      {/* Timeline */}
      <div className="mb-4">
        <RunTimeline runs={runsVM.runs} />
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
