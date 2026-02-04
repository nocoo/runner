// ============================================
// Add Task Modal
// Form dialog for creating new tasks
// ============================================

import { useEffect } from "react";
import { AsciiBox, MatrixButton, MatrixInput } from "@/ui/foundation";
import { useAddTaskVM } from "@/viewmodels";
import type { CreateTaskResponse } from "@/models/api";

interface AddTaskModalProps {
  open: boolean;
  onClose: () => void;
  onSuccess?: (response: CreateTaskResponse) => void;
}

export function AddTaskModal({ open, onClose, onSuccess }: AddTaskModalProps) {
  const vm = useAddTaskVM({
    onSuccess: (response) => {
      onSuccess?.(response);
      onClose();
    },
  });

  // Close on Escape key
  useEffect(() => {
    if (!open) return;
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [open, onClose]);

  // Reset form when modal opens
  useEffect(() => {
    if (open) {
      vm.reset();
    }
  }, [open]); // eslint-disable-line react-hooks/exhaustive-deps

  if (!open) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    await vm.submit();
  };

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm"
      onClick={onClose}
    >
      <div
        className="w-full max-w-xl max-h-[90vh] overflow-y-auto m-4"
        onClick={(e) => e.stopPropagation()}
      >
        <AsciiBox title="Add Task" subtitle="Create new task">
          <form onSubmit={handleSubmit} className="space-y-4">
            {/* Task ID */}
            <div>
              <MatrixInput
                label="Task ID"
                value={vm.formData.id}
                onChange={(e) => vm.updateField("id", e.target.value)}
                placeholder="my_task_name"
                autoFocus
              />
              {vm.errors.id && (
                <p className="text-caption text-red-400 mt-1">{vm.errors.id}</p>
              )}
            </div>

            {/* Executor Type */}
            <div className="flex flex-col gap-2">
              <span className="text-caption text-matrix-muted uppercase font-bold">
                Executor
              </span>
              <div className="flex gap-2">
                {(["shell", "opencode", "http"] as const).map((type) => (
                  <button
                    key={type}
                    type="button"
                    onClick={() => vm.updateField("executor", type)}
                    className={`px-3 py-2 text-caption font-bold uppercase border transition-colors ${
                      vm.formData.executor === type
                        ? "bg-matrix-primary/20 text-matrix-primary border-matrix-primary"
                        : "bg-matrix-panel text-matrix-dim border-matrix-ghost hover:border-matrix-dim"
                    }`}
                  >
                    {type}
                  </button>
                ))}
              </div>
            </div>

            {/* Description */}
            <div>
              <MatrixInput
                label="Description"
                value={vm.formData.description}
                onChange={(e) => vm.updateField("description", e.target.value)}
                placeholder="What does this task do?"
              />
              {vm.errors.description && (
                <p className="text-caption text-red-400 mt-1">
                  {vm.errors.description}
                </p>
              )}
            </div>

            {/* Timeout */}
            <div>
              <MatrixInput
                label="Timeout (seconds)"
                type="number"
                value={vm.formData.timeout}
                onChange={(e) =>
                  vm.updateField("timeout", parseInt(e.target.value) || 300)
                }
                min={1}
                max={86400}
              />
            </div>

            {/* Shell-specific fields */}
            {vm.formData.executor === "shell" && (
              <div>
                <label className="flex flex-col gap-2">
                  <span className="text-caption text-matrix-muted uppercase font-bold">
                    Command
                  </span>
                  <textarea
                    className="h-24 bg-matrix-panel border border-matrix-ghost px-3 py-2 text-body text-matrix-bright font-mono outline-none focus:border-matrix-primary focus:ring-2 focus:ring-matrix-primary/20 resize-none"
                    value={vm.formData.command}
                    onChange={(e) => vm.updateField("command", e.target.value)}
                    placeholder="echo 'Hello World'"
                  />
                </label>
                {vm.errors.command && (
                  <p className="text-caption text-red-400 mt-1">
                    {vm.errors.command}
                  </p>
                )}
              </div>
            )}

            {/* Opencode-specific fields */}
            {vm.formData.executor === "opencode" && (
              <div>
                <label className="flex flex-col gap-2">
                  <span className="text-caption text-matrix-muted uppercase font-bold">
                    Prompt
                  </span>
                  <textarea
                    className="h-24 bg-matrix-panel border border-matrix-ghost px-3 py-2 text-body text-matrix-bright font-mono outline-none focus:border-matrix-primary focus:ring-2 focus:ring-matrix-primary/20 resize-none"
                    value={vm.formData.prompt}
                    onChange={(e) => vm.updateField("prompt", e.target.value)}
                    placeholder="Analyze the codebase and..."
                  />
                </label>
                {vm.errors.prompt && (
                  <p className="text-caption text-red-400 mt-1">
                    {vm.errors.prompt}
                  </p>
                )}
              </div>
            )}

            {/* HTTP-specific fields */}
            {vm.formData.executor === "http" && (
              <>
                <div className="flex gap-4">
                  <div className="w-28">
                    <label className="flex flex-col gap-2">
                      <span className="text-caption text-matrix-muted uppercase font-bold">
                        Method
                      </span>
                      <select
                        className="h-10 bg-matrix-panel border border-matrix-ghost px-3 text-body text-matrix-bright outline-none focus:border-matrix-primary"
                        value={vm.formData.method}
                        onChange={(e) =>
                          vm.updateField("method", e.target.value)
                        }
                      >
                        <option value="GET">GET</option>
                        <option value="POST">POST</option>
                        <option value="PUT">PUT</option>
                        <option value="PATCH">PATCH</option>
                        <option value="DELETE">DELETE</option>
                      </select>
                    </label>
                  </div>
                  <div className="flex-1">
                    <MatrixInput
                      label="URL"
                      value={vm.formData.url}
                      onChange={(e) => vm.updateField("url", e.target.value)}
                      placeholder="https://api.example.com/webhook"
                    />
                    {vm.errors.url && (
                      <p className="text-caption text-red-400 mt-1">
                        {vm.errors.url}
                      </p>
                    )}
                  </div>
                </div>

                <div>
                  <label className="flex flex-col gap-2">
                    <span className="text-caption text-matrix-muted uppercase font-bold">
                      Headers (JSON)
                    </span>
                    <textarea
                      className="h-20 bg-matrix-panel border border-matrix-ghost px-3 py-2 text-body text-matrix-bright font-mono outline-none focus:border-matrix-primary focus:ring-2 focus:ring-matrix-primary/20 resize-none"
                      value={vm.formData.headers}
                      onChange={(e) =>
                        vm.updateField("headers", e.target.value)
                      }
                      placeholder='{"Content-Type": "application/json"}'
                    />
                  </label>
                  {vm.errors.headers && (
                    <p className="text-caption text-red-400 mt-1">
                      {vm.errors.headers}
                    </p>
                  )}
                </div>

                <div>
                  <label className="flex flex-col gap-2">
                    <span className="text-caption text-matrix-muted uppercase font-bold">
                      Body
                    </span>
                    <textarea
                      className="h-20 bg-matrix-panel border border-matrix-ghost px-3 py-2 text-body text-matrix-bright font-mono outline-none focus:border-matrix-primary focus:ring-2 focus:ring-matrix-primary/20 resize-none"
                      value={vm.formData.body}
                      onChange={(e) => vm.updateField("body", e.target.value)}
                      placeholder='{"key": "value"}'
                    />
                  </label>
                </div>
              </>
            )}

            {/* Workdir (optional, for shell and opencode) */}
            {(vm.formData.executor === "shell" ||
              vm.formData.executor === "opencode") && (
              <div>
                <MatrixInput
                  label="Working Directory (optional)"
                  value={vm.formData.workdir}
                  onChange={(e) => vm.updateField("workdir", e.target.value)}
                  placeholder="/path/to/directory"
                />
              </div>
            )}

            {/* Error message */}
            {vm.error && (
              <div className="p-3 bg-red-500/10 border border-red-500/30 text-red-400 text-caption">
                {vm.error}
              </div>
            )}

            {/* Actions */}
            <div className="flex justify-end gap-3 pt-2">
              <MatrixButton type="button" onClick={onClose}>
                Cancel
              </MatrixButton>
              <MatrixButton
                type="submit"
                loading={vm.state === "loading"}
                disabled={vm.state === "loading"}
              >
                Create Task
              </MatrixButton>
            </div>
          </form>
        </AsciiBox>
      </div>
    </div>
  );
}
