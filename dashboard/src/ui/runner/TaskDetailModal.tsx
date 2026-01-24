// ============================================
// Task Detail Modal
// Shows full JSON configuration for a task
// ============================================

import { useEffect } from "react";
import type { TaskWithSchedule } from "@/models/types";
import { AsciiBox, MatrixButton } from "@/ui/foundation";
import { formatScheduleTime, getWeekday } from "@/lib/date";

interface TaskDetailModalProps {
  task: TaskWithSchedule | null;
  onClose: () => void;
}

export function TaskDetailModal({ task, onClose }: TaskDetailModalProps) {
  // Close on Escape key
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [onClose]);

  if (!task) return null;

  // Generate JSON representation
  const generateJsonConfig = () => {
    const config: Record<string, unknown> = {
      id: task.id,
      type: task.type,
      description: task.description,
      timeout: task.timeout,
    };
    
    if (task.workdir) {
      config.workdir = task.workdir;
    }
    
    if (task.type === "simple" && task.command) {
      config.command = task.command;
    }
    
    if (task.type === "agent" && task.prompt) {
      config.prompt = task.prompt;
    }
    
    return JSON.stringify(config, null, 2);
  };

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm"
      onClick={onClose}
    >
      <div
        className="w-full max-w-2xl max-h-[90vh] overflow-auto m-4"
        onClick={(e) => e.stopPropagation()}
      >
        <AsciiBox
          title={task.id}
          subtitle={task.type === "simple" ? "CLI Task" : "Agent Task"}
        >
          <div className="space-y-4">
            {/* Type Badge */}
            <div className="flex items-center gap-2">
              <span
                className={`px-2 py-1 text-caption font-bold uppercase ${
                  task.type === "simple"
                    ? "bg-emerald-500/20 text-emerald-400 border border-emerald-500/30"
                    : "bg-emerald-500/20 text-emerald-400 border border-emerald-500/30"
                }`}
              >
                {task.type}
              </span>
              <span className="text-matrix-dim text-caption">
                Timeout: {task.timeout}s
              </span>
            </div>

            {/* Description */}
            <div>
              <h4 className="text-caption text-matrix-ghost uppercase mb-1">
                Description
              </h4>
              <p className="text-matrix-primary">{task.description}</p>
            </div>

            {/* Schedules */}
            {task.schedules.length > 0 && (
              <div>
                <h4 className="text-caption text-matrix-ghost uppercase mb-2">
                  Schedules ({task.schedules.length})
                </h4>
                <div className="flex flex-wrap gap-2">
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
              </div>
            )}

            {/* Command (for simple type) */}
            {task.type === "simple" && task.command && (
              <div>
                <h4 className="text-caption text-matrix-ghost uppercase mb-1">
                  Command
                </h4>
                <pre className="bg-black/50 border border-matrix-ghost p-3 text-body font-mono text-cyan-400 overflow-x-auto">
                  $ {task.command}
                </pre>
              </div>
            )}

            {/* Prompt (for agent type) */}
            {task.type === "agent" && task.prompt && (
              <div>
                <h4 className="text-caption text-matrix-ghost uppercase mb-1">
                  Prompt
                </h4>
                <pre className="bg-black/50 border border-matrix-ghost p-3 text-body font-mono text-purple-300 overflow-x-auto whitespace-pre-wrap max-h-48 overflow-y-auto">
                  {task.prompt}
                </pre>
              </div>
            )}

            {/* Workdir */}
            {task.workdir && (
              <div>
                <h4 className="text-caption text-matrix-ghost uppercase mb-1">
                  Working Directory
                </h4>
                <code className="text-matrix-primary">{task.workdir}</code>
              </div>
            )}

            {/* JSON Config */}
            <div>
              <h4 className="text-caption text-matrix-ghost uppercase mb-1">
                JSON Configuration
              </h4>
              <pre className="bg-black/50 border border-matrix-ghost p-3 text-body font-mono text-matrix-dim overflow-x-auto">
                {generateJsonConfig()}
              </pre>
            </div>

            {/* Close button */}
            <div className="flex justify-end pt-2">
              <MatrixButton onClick={onClose}>Close</MatrixButton>
            </div>
          </div>
        </AsciiBox>
      </div>
    </div>
  );
}
