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
}

export function TaskSchedule({
  tasks,
  loading,
  onTrigger,
  triggerLoading,
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
            className="border border-matrix-ghost p-3 hover:border-matrix-dim transition-colors"
          >
            <div className="flex justify-between items-start mb-2">
              <div>
                <span className="font-bold text-matrix-primary">{task.id}</span>
                <p className="text-caption text-matrix-dim mt-1">
                  {task.description}
                </p>
              </div>
              <MatrixButton
                size="small"
                onClick={() => onTrigger(task.id)}
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

            {/* Timeout info */}
            <div className="mt-2 text-caption text-matrix-ghost">
              Timeout: {task.timeout}s
            </div>
          </div>
        ))}
      </div>
    </AsciiBox>
  );
}
