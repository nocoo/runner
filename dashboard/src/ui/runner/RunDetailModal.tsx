// ============================================
// Run Detail Modal
// ============================================

import type { RunDetail } from "@/models/types";
import { formatDuration, formatDate, formatExitCode } from "@/lib/format";

interface RunDetailModalProps {
  run: RunDetail | null;
  loading: boolean;
  onClose: () => void;
}

export function RunDetailModal({ run, loading, onClose }: RunDetailModalProps) {
  if (!run && !loading) return null;

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/80"
      onClick={onClose}
    >
      <div
        className="matrix-panel p-6 max-w-2xl w-full mx-4 max-h-[80vh] overflow-y-auto"
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
              >
                ×
              </button>
            </div>

            {/* Details grid */}
            <div className="grid grid-cols-2 gap-4 mb-6">
              <div>
                <span className="text-caption text-matrix-dim uppercase">Status</span>
                <p className={`font-bold ${run.exit_code === 0 ? "text-success" : "text-error"}`}>
                  {formatExitCode(run.exit_code)}
                </p>
              </div>
              <div>
                <span className="text-caption text-matrix-dim uppercase">Trigger</span>
                <p className="text-matrix-primary">{run.trigger}</p>
              </div>
              <div>
                <span className="text-caption text-matrix-dim uppercase">Started</span>
                <p className="text-matrix-primary">{formatDate(run.started_at)}</p>
              </div>
              <div>
                <span className="text-caption text-matrix-dim uppercase">Finished</span>
                <p className="text-matrix-primary">
                  {run.finished_at ? formatDate(run.finished_at) : "-"}
                </p>
              </div>
              <div>
                <span className="text-caption text-matrix-dim uppercase">Duration</span>
                <p className="text-matrix-primary">
                  {formatDuration(run.duration_seconds ?? 0)}
                </p>
              </div>
              <div>
                <span className="text-caption text-matrix-dim uppercase">Exit Code</span>
                <p className={run.exit_code === 0 ? "text-success" : "text-error"}>
                  {run.exit_code}
                </p>
              </div>
            </div>

            {/* Output preview */}
            {run.output_preview && (
              <div>
                <span className="text-caption text-matrix-dim uppercase">Output Preview</span>
                <pre className="mt-2 p-4 bg-black/50 border border-matrix-ghost overflow-x-auto text-caption text-matrix-muted whitespace-pre-wrap">
                  {run.output_preview}
                </pre>
              </div>
            )}
          </>
        ) : null}
      </div>
    </div>
  );
}
