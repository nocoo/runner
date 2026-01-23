// ============================================
// Dashboard Page - Main Entry
// ============================================

import { MatrixShell } from "@/ui/foundation";
import { useStatusVM, useRunsVM, useTasksVM } from "@/viewmodels";
import {
  SystemStatus,
  RunHistory,
  TaskSchedule,
  RunHeatmap,
  TrendChart,
  RunDetailModal,
} from "@/ui/runner";

export function DashboardPage() {
  const statusVM = useStatusVM();
  const runsVM = useRunsVM();
  const tasksVM = useTasksVM();

  const handleRefreshAll = () => {
    statusVM.refresh();
    runsVM.refresh();
    tasksVM.refresh();
  };

  return (
    <MatrixShell
      title="Runner"
      headerStatus={
        statusVM.isOnline ? (
          <span className="flex items-center">
            <span className="w-1.5 h-1.5 bg-success rounded-full mr-2 animate-pulse"></span>
            System Online
          </span>
        ) : (
          <span className="flex items-center text-error">
            <span className="w-1.5 h-1.5 bg-error rounded-full mr-2"></span>
            {statusVM.error || "Offline"}
          </span>
        )
      }
      headerRight={
        <button
          onClick={handleRefreshAll}
          className="matrix-header-chip matrix-header-action text-caption uppercase font-bold tracking-[0.2em]"
        >
          ↻ Refresh
        </button>
      }
    >
      <div className="grid grid-cols-12 gap-6">
        {/* Left Column - 4/12 */}
        <div className="col-span-12 lg:col-span-4 space-y-6">
          {/* System Status */}
          <SystemStatus
            data={statusVM.data}
            loading={statusVM.state === "loading"}
            successRatePercent={statusVM.successRatePercent}
            lastRunStatus={statusVM.lastRunStatus}
            onRefresh={statusVM.refresh}
          />

          {/* Activity Heatmap */}
          <RunHeatmap data={runsVM.heatmapData} weeks={8} />

          {/* Trend Chart */}
          <TrendChart data={runsVM.trendData} />
        </div>

        {/* Right Column - 8/12 */}
        <div className="col-span-12 lg:col-span-8 space-y-6">
          {/* Tasks & Schedules */}
          <TaskSchedule
            tasks={tasksVM.tasks}
            loading={tasksVM.state === "loading"}
            onTrigger={tasksVM.trigger}
            triggerLoading={tasksVM.triggerState === "loading"}
          />

          {/* Run History */}
          <RunHistory
            runs={runsVM.pagedRuns}
            loading={runsVM.state === "loading"}
            page={runsVM.page}
            totalPages={runsVM.totalPages}
            onPageChange={runsVM.setPage}
            onSelectRun={runsVM.selectRun}
          />
        </div>
      </div>

      {/* Run Detail Modal */}
      <RunDetailModal
        run={runsVM.selectedRun}
        loading={runsVM.selectedRunLoading}
        onClose={() => runsVM.selectRun(null)}
      />

      {/* Trigger Result Toast */}
      {tasksVM.triggerState === "success" && tasksVM.triggerResult && (
        <div
          className="fixed bottom-8 right-8 z-50 matrix-panel p-4 max-w-sm animate-pulse cursor-pointer"
          onClick={tasksVM.clearTriggerResult}
        >
          <div className="flex items-center gap-3">
            <span
              className={`w-3 h-3 rounded-full ${
                tasksVM.triggerResult.exit_code === 0 ? "bg-success" : "bg-error"
              }`}
            ></span>
            <div>
              <p className="font-bold text-matrix-primary">
                {tasksVM.triggerResult.task}
              </p>
              <p className="text-caption text-matrix-dim">
                Exit code: {tasksVM.triggerResult.exit_code}
              </p>
            </div>
          </div>
        </div>
      )}

      {tasksVM.triggerState === "error" && (
        <div
          className="fixed bottom-8 right-8 z-50 matrix-panel p-4 max-w-sm border-error cursor-pointer"
          onClick={tasksVM.clearTriggerResult}
        >
          <p className="text-error font-bold">Trigger Failed</p>
          <p className="text-caption text-matrix-dim">{tasksVM.triggerError}</p>
        </div>
      )}
    </MatrixShell>
  );
}
