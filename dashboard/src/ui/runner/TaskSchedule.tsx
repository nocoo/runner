// ============================================
// Task Schedule Panel
// ============================================

import type { TaskWithSchedule } from "@/models/types";
import { AsciiBox, MatrixButton } from "@/ui/foundation";
import { formatScheduleTime, getWeekday } from "@/lib/date";

interface TaskScheduleProps {
  tasks: TaskWithSchedule[];
  loading: boolean;
  onTrigger: (taskId: string) => void;
  triggerLoading: boolean;
  onSelectTask?: (task: TaskWithSchedule) => void;
}

export function TaskSchedule({
  tasks,
  loading,
  onTrigger,
  triggerLoading,
  onSelectTask,
}: TaskScheduleProps) {
  return (
    <AsciiBox title="Tasks" subtitle={`${tasks.length} tasks`}>
      <div className="space-y-4">
        {/* Loading state */}
        {loading && tasks.length === 0 && (
          <div className="py-8 text-center text-matrix-dim animate-pulse">
            Loading tasks...
          </div>
        )}

        {/* Tasks list */}
        {tasks.map((task) => (
          <div
            key={task.id}
            className={`border border-matrix-ghost p-3 transition-colors ${
              onSelectTask
                ? "hover:border-matrix-dim cursor-pointer"
                : "hover:border-matrix-dim"
            }`}
            onClick={() => onSelectTask?.(task)}
          >
            <div className="flex justify-between items-start mb-2">
              <div className="flex-1">
                <div className="flex items-center gap-2">
                  <span className="font-bold text-matrix-primary">{task.id}</span>
                  <span
                    className={`px-1.5 py-0.5 text-[10px] font-bold uppercase ${
                      task.type === "manual"
                        ? "bg-amber-500/20 text-amber-400 border border-amber-500/30"
                        : "bg-emerald-500/20 text-emerald-400 border border-emerald-500/30"
                    }`}
                  >
                    {task.type}
                  </span>
                </div>
                <p className="text-caption text-matrix-dim mt-1">
                  {task.description}
                </p>
              </div>
              <MatrixButton
                size="small"
                onClick={(e) => {
                  e.stopPropagation();
                  onTrigger(task.id);
                }}
                disabled={triggerLoading}
                loading={triggerLoading}
              >
                Run
              </MatrixButton>
            </div>

            {/* Schedules */}
            {task.schedules.length > 0 && (
              <div className="flex flex-wrap gap-2 mt-3">
                {task.schedules.map((schedule, idx) => (
                  <span
                    key={idx}
                    className="inline-flex items-center gap-1 px-2 py-1 bg-matrix-ghost/30 border border-matrix-ghost text-caption"
                  >
                    <span className="text-matrix-primary font-bold">
                      {formatScheduleTime(schedule.hour, schedule.minute)}
                    </span>
                    <span className="text-matrix-dim">
                      {getWeekday(schedule.weekday)}
                    </span>
                  </span>
                ))}
              </div>
            )}
          </div>
        ))}
      </div>
    </AsciiBox>
  );
}
