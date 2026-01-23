// ============================================
// Run History Table
// ============================================

import type { RunSummary } from "@/models/types";
import { AsciiBox, MatrixButton } from "@/ui/foundation";
import { formatRelativeTime } from "@/lib/format";

interface RunHistoryProps {
  runs: RunSummary[];
  loading: boolean;
  page: number;
  totalPages: number;
  onPageChange: (page: number) => void;
  onSelectRun: (id: string) => void;
}

export function RunHistory({
  runs,
  loading,
  page,
  totalPages,
  onPageChange,
  onSelectRun,
}: RunHistoryProps) {
  return (
    <AsciiBox title="Run History" subtitle={`page ${page}/${totalPages || 1}`}>
      <div className="space-y-2">
        {/* Header */}
        <div className="grid grid-cols-12 gap-2 text-caption uppercase text-matrix-dim font-bold border-b border-matrix-ghost pb-2">
          <div className="col-span-4">Task</div>
          <div className="col-span-3">Status</div>
          <div className="col-span-4">Finished</div>
          <div className="col-span-1"></div>
        </div>

        {/* Loading state */}
        {loading && runs.length === 0 && (
          <div className="py-8 text-center text-matrix-dim animate-pulse">
            Loading runs...
          </div>
        )}

        {/* Empty state */}
        {!loading && runs.length === 0 && (
          <div className="py-8 text-center text-matrix-dim">
            No runs recorded yet
          </div>
        )}

        {/* Runs list */}
        {runs.map((run) => (
          <div
            key={run.id}
            className="grid grid-cols-12 gap-2 py-2 border-b border-matrix-ghost/50 hover:bg-matrix-ghost/20 cursor-pointer transition-colors"
            onClick={() => onSelectRun(run.id)}
          >
            <div className="col-span-4 font-bold truncate">{run.task}</div>
            <div className="col-span-3">
              <span
                className={`inline-flex items-center gap-1 ${
                  run.exit_code === 0 ? "text-success" : "text-error"
                }`}
              >
                <span className="w-1.5 h-1.5 rounded-full bg-current"></span>
                {run.exit_code === 0 ? "OK" : `ERR ${run.exit_code}`}
              </span>
            </div>
            <div className="col-span-4 text-matrix-dim text-caption">
              {formatRelativeTime(run.finished_at)}
            </div>
            <div className="col-span-1 text-matrix-dim">→</div>
          </div>
        ))}

        {/* Pagination */}
        {totalPages > 1 && (
          <div className="flex justify-between items-center pt-4">
            <MatrixButton
              size="small"
              disabled={page <= 1}
              onClick={() => onPageChange(page - 1)}
            >
              ← Prev
            </MatrixButton>
            <span className="text-caption text-matrix-dim">
              {page} / {totalPages}
            </span>
            <MatrixButton
              size="small"
              disabled={page >= totalPages}
              onClick={() => onPageChange(page + 1)}
            >
              Next →
            </MatrixButton>
          </div>
        )}
      </div>
    </AsciiBox>
  );
}
