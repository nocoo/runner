// ============================================
// Dashboard Page - Main Entry
// ============================================

import { useState } from "react";
import { LayoutGrid, RefreshCw } from "lucide-react";
import { MatrixShell } from "@/ui/foundation";
import { Toast } from "@/ui/feedback";
import { useStatusVM, useRunsVM, useTasksVM } from "@/viewmodels";
import {
  RunHistory,
  TaskSchedule,
  TaskDetailModal,
  AddTaskModal,
  RunHeatmap,
  TrendChart,
  RunDetailModal,
  MatrixClock,
  UpcomingTasks,
} from "@/ui/runner";
import type { TaskWithSchedule } from "@/models/types";

export function DashboardPage() {
  const statusVM = useStatusVM();
  const runsVM = useRunsVM(24);
  const tasksVM = useTasksVM();
  const [selectedTask, setSelectedTask] = useState<TaskWithSchedule | null>(null);
  const [showAddTaskModal, setShowAddTaskModal] = useState(false);


  const handleRefreshAll = () => {
    statusVM.refresh();
    runsVM.refresh();
    tasksVM.refresh();
  };

  return (
    <MatrixShell
      title="Runner"
      showRain
      showAvatar
      avatarName="runner"
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
        <div className="flex items-center gap-4">
          <a
            href="#library"
            className="matrix-header-chip matrix-header-action text-caption uppercase font-bold tracking-[0.2em] inline-flex items-center gap-1.5"
          >
            <LayoutGrid size={14} /> Library
          </a>
          <button
            onClick={handleRefreshAll}
            className="matrix-header-chip matrix-header-action text-caption uppercase font-bold tracking-[0.2em] inline-flex items-center gap-1.5"
          >
            <RefreshCw size={14} /> Refresh
          </button>
        </div>
      }
    >
      <div className="grid grid-cols-12 gap-6">
        {/* Left Column - 4/12 */}
        <div className="col-span-12 lg:col-span-4 space-y-6">
          {/* Matrix Clock */}
          <div 
            className="matrix-panel p-6 flex justify-center relative overflow-hidden"
            style={{
              backgroundImage: `
                radial-gradient(circle at 20% 80%, rgba(0, 255, 65, 0.03) 0%, transparent 50%),
                radial-gradient(circle at 80% 20%, rgba(0, 255, 65, 0.02) 0%, transparent 50%),
                linear-gradient(180deg, rgba(0, 255, 65, 0.02) 0%, transparent 2px, transparent 4px, rgba(0, 255, 65, 0.02) 4px),
                repeating-linear-gradient(0deg, transparent, transparent 2px, rgba(0, 255, 65, 0.015) 2px, rgba(0, 255, 65, 0.015) 4px)
              `,
            }}
          >
            {/* Scanline overlay */}
            <div 
              className="absolute inset-0 pointer-events-none opacity-30"
              style={{
                backgroundImage: `repeating-linear-gradient(
                  0deg,
                  transparent,
                  transparent 2px,
                  rgba(0, 0, 0, 0.3) 2px,
                  rgba(0, 0, 0, 0.3) 4px
                )`,
              }}
            />
            <MatrixClock label="北京时间" />
          </div>

          {/* Activity Heatmap */}
          <RunHeatmap data={runsVM.heatmapData} />

          {/* Trend Chart */}
          <TrendChart data={runsVM.trendData} />

          {/* Upcoming Tasks */}
          <UpcomingTasks
            items={tasksVM.upcomingTasks}
            count={8}
          />
        </div>

        {/* Right Column - 8/12 */}
        <div className="col-span-12 lg:col-span-8 space-y-6">
          {/* Tasks & Schedules */}
          <TaskSchedule
            tasks={tasksVM.tasks}
            loading={tasksVM.state === "loading"}
            onTrigger={tasksVM.trigger}
            triggerLoading={tasksVM.triggerState === "loading"}
            onSelectTask={setSelectedTask}
            onAddTask={() => setShowAddTaskModal(true)}
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
        output={runsVM.selectedRunOutput}
        outputLoading={runsVM.selectedRunOutputLoading}
        outputError={runsVM.selectedRunOutputError}
        onClose={() => runsVM.selectRun(null)}
      />

      {/* Task Detail Modal */}
      <TaskDetailModal
        task={selectedTask}
        onClose={() => setSelectedTask(null)}
      />

      {/* Add Task Modal */}
      <AddTaskModal
        open={showAddTaskModal}
        onClose={() => setShowAddTaskModal(false)}
        onSuccess={() => {
          tasksVM.refresh();
        }}
      />

      {/* Trigger Result Toast */}
      {tasksVM.triggerState === "success" && tasksVM.triggerResult && (
        <Toast
          tone={tasksVM.triggerResult.exit_code === 0 ? "success" : "error"}
          message={tasksVM.triggerResult.task}
          detail={`Exit code: ${tasksVM.triggerResult.exit_code}`}
          durationMs={3000}
          onClose={tasksVM.clearTriggerResult}
          className="animate-pulse"
        />
      )}

      {tasksVM.triggerState === "error" && (
        <Toast
          tone="error"
          message="Trigger Failed"
          detail={tasksVM.triggerError}
          durationMs={5000}
          onClose={tasksVM.clearTriggerResult}
          className="border-error"
        />
      )}
    </MatrixShell>
  );
}
