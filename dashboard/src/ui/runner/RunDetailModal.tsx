// ============================================
// Run Detail Modal
// ============================================

import { useEffect, useState, useCallback } from "react";
import type { RunDetail } from "@/models/types";
import { fetchRunOutput } from "@/models/api";
import { formatDuration, formatDate, formatExitCode } from "@/lib/format";

interface RunDetailModalProps {
  run: RunDetail | null;
  loading: boolean;
  onClose: () => void;
}

export function RunDetailModal({ run, loading, onClose }: RunDetailModalProps) {
  const [output, setOutput] = useState<string | null>(null);
  const [outputLoading, setOutputLoading] = useState(false);
  const [outputError, setOutputError] = useState<string | null>(null);

  // Load full output when run changes
  useEffect(() => {
    if (!run?.id) {
      setOutput(null);
      setOutputError(null);
      return;
    }

    setOutputLoading(true);
    setOutputError(null);

    fetchRunOutput(run.id)
      .then(setOutput)
      .catch((err) => setOutputError(err.message))
      .finally(() => setOutputLoading(false));
  }, [run?.id]);

  // ESC key handler
  const handleKeyDown = useCallback(
    (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        onClose();
      }
    },
    [onClose]
  );

  useEffect(() => {
    if (run || loading) {
      document.addEventListener("keydown", handleKeyDown);
      return () => document.removeEventListener("keydown", handleKeyDown);
    }
  }, [run, loading, handleKeyDown]);

  if (!run && !loading) return null;

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/80"
      onClick={onClose}
    >
      <div
        className="matrix-panel p-6 max-w-4xl w-full mx-4 max-h-[90vh] overflow-y-auto"
        onClick={(e) => e.stopPropagation()}
      >
        {loading ? (
          <div className="py-8 text-center text-matrix-dim animate-pulse">
            Loading run details...
          </div>
        ) : run ? (
          <>
            {/* Header */}
            <div className="flex justify-between items-start mb-6">
              <div>
                <h2 className="text-xl font-bold text-matrix-primary glow-text">
                  {run.task}
                </h2>
                <p className="text-caption text-matrix-dim mt-1">
                  {run.id}
                </p>
              </div>
              <button
                onClick={onClose}
                className="text-matrix-dim hover:text-matrix-primary text-2xl leading-none"
                title="Close (Esc)"
              >
                ×
              </button>
            </div>

            {/* Details grid */}
            <div className="grid grid-cols-2 sm:grid-cols-3 gap-4 mb-6">
              <div>
                <span className="text-caption text-matrix-dim uppercase">Status</span>
                <p className={`font-bold ${run.exit_code == null ? "text-cyan-400" : run.exit_code === 0 ? "text-success" : "text-error"}`}>
                  {formatExitCode(run.exit_code)}
                </p>
              </div>
              <div>
                <span className="text-caption text-matrix-dim uppercase">Trigger</span>
                <p className="text-matrix-primary">{run.trigger}</p>
              </div>
              <div>
                <span className="text-caption text-matrix-dim uppercase">Exit Code</span>
                <p className={run.exit_code == null ? "text-cyan-400" : run.exit_code === 0 ? "text-success" : "text-error"}>
                  {run.exit_code ?? "-"}
                </p>
              </div>
              <div>
                <span className="text-caption text-matrix-dim uppercase">Started</span>
                <p className="text-matrix-primary text-sm">{formatDate(run.started_at)}</p>
              </div>
              <div>
                <span className="text-caption text-matrix-dim uppercase">Finished</span>
                <p className="text-matrix-primary text-sm">
                  {run.finished_at ? formatDate(run.finished_at) : "-"}
                </p>
              </div>
              <div>
                <span className="text-caption text-matrix-dim uppercase">Duration</span>
                <p className="text-matrix-primary">
                  {formatDuration(run.duration_seconds ?? 0)}
                </p>
              </div>
            </div>

            {/* Full Output */}
            <div>
              <span className="text-caption text-matrix-dim uppercase">Output</span>
              {outputLoading ? (
                <div className="mt-2 p-4 bg-black/50 border border-matrix-ghost text-matrix-dim animate-pulse">
                  Loading output...
                </div>
              ) : outputError ? (
                <div className="mt-2 p-4 bg-black/50 border border-error/30 text-error text-sm">
                  {outputError}
                </div>
              ) : output ? (
                <pre className="mt-2 p-4 bg-black/50 border border-matrix-ghost overflow-x-auto text-xs text-matrix-muted whitespace-pre-wrap font-mono max-h-[50vh] overflow-y-auto">
                  {output}
                </pre>
              ) : (
                <div className="mt-2 p-4 bg-black/50 border border-matrix-ghost text-matrix-dim text-sm">
                  No output available
                </div>
              )}
            </div>

            {/* Footer hint */}
            <div className="mt-4 text-right text-caption text-matrix-dim">
              Press <kbd className="px-1.5 py-0.5 bg-matrix-ghost/20 rounded text-xs">Esc</kbd> to close
            </div>
          </>
        ) : null}
      </div>
    </div>
  );
}
