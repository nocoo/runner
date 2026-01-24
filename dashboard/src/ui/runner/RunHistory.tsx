// ============================================
// Run History Table
// Based on vibeusage DETAILS table pattern
// ============================================

import { useState, useMemo } from "react";
import type { RunSummary, RunStatus } from "@/models/types";
import { AsciiBox, MatrixButton } from "@/ui/foundation";
import { formatRelativeTime, formatDurationMs } from "@/lib/format";

interface RunHistoryProps {
  runs: RunSummary[];
  loading: boolean;
  page: number;
  totalPages: number;
  onPageChange: (page: number) => void;
  onSelectRun: (id: string) => void;
}

type SortKey = "task" | "status" | "duration" | "finished_at";
type SortDir = "asc" | "desc";

interface Column {
  key: SortKey;
  label: string;
  title: string;
}

const COLUMNS: Column[] = [
  { key: "task", label: "Task", title: "Sort by task name" },
  { key: "status", label: "Status", title: "Sort by status" },
  { key: "duration", label: "Duration", title: "Sort by duration" },
  { key: "finished_at", label: "Time", title: "Sort by time" },
];

function getSortIcon(key: SortKey, sortKey: SortKey, sortDir: SortDir): string {
  if (key !== sortKey) return "↕";
  return sortDir === "asc" ? "↑" : "↓";
}

function getAriaSortValue(key: SortKey, sortKey: SortKey, sortDir: SortDir): "ascending" | "descending" | "none" {
  if (key !== sortKey) return "none";
  return sortDir === "asc" ? "ascending" : "descending";
}

/**
 * Derive status from run data (supports backward compatibility)
 */
function getRunStatus(run: RunSummary): RunStatus {
  // Use explicit status if available
  if (run.status) return run.status;
  // Backward compatibility: derive from exit_code
  if (run.exit_code === null || run.exit_code === undefined) return "running";
  return run.exit_code === 0 ? "success" : "failed";
}

/**
 * Get status display config
 */
function getStatusConfig(status: RunStatus): { label: string; className: string; dot: string } {
  switch (status) {
    case "running":
      return { label: "RUNNING", className: "text-cyan-400", dot: "animate-pulse" };
    case "success":
      return { label: "OK", className: "text-success", dot: "" };
    case "failed":
      return { label: "FAILED", className: "text-error", dot: "" };
    case "skipped":
      return { label: "SKIP", className: "text-matrix-dim", dot: "" };
    default:
      return { label: "?", className: "text-matrix-dim", dot: "" };
  }
}

/**
 * Get status sort priority (for sorting)
 */
function getStatusPriority(status: RunStatus): number {
  switch (status) {
    case "running": return 0;  // Running first
    case "failed": return 1;   // Failed second
    case "skipped": return 2;  // Skipped third
    case "success": return 3;  // Success last
    default: return 4;
  }
}

export function RunHistory({
  runs,
  loading,
  page,
  totalPages,
  onPageChange,
  onSelectRun,
}: RunHistoryProps) {
  const [sortKey, setSortKey] = useState<SortKey>("finished_at");
  const [sortDir, setSortDir] = useState<SortDir>("desc");

  const toggleSort = (key: SortKey) => {
    if (sortKey === key) {
      setSortDir((prev) => (prev === "asc" ? "desc" : "asc"));
    } else {
      setSortKey(key);
      setSortDir("desc");
    }
  };

  const sortedRuns = useMemo(() => {
    const sorted = [...runs];
    sorted.sort((a, b) => {
      let cmp = 0;
      switch (sortKey) {
        case "task":
          cmp = a.task.localeCompare(b.task);
          break;
        case "status":
          cmp = getStatusPriority(getRunStatus(a)) - getStatusPriority(getRunStatus(b));
          break;
        case "duration":
          cmp = (a.duration_ms ?? 0) - (b.duration_ms ?? 0);
          break;
        case "finished_at": {
          // For running tasks, use started_at; otherwise use finished_at
          const timeA = a.finished_at || a.started_at || "";
          const timeB = b.finished_at || b.started_at || "";
          cmp = new Date(timeA).getTime() - new Date(timeB).getTime();
          break;
        }
      }
      return sortDir === "asc" ? cmp : -cmp;
    });
    return sorted;
  }, [runs, sortKey, sortDir]);

  return (
    <AsciiBox title="Run History" subtitle={`${runs.length} runs`}>
      <div
        className="border border-[#00FF41]/10"
        role="region"
        aria-label="Run history table"
        tabIndex={0}
      >
        <table className="w-full border-collapse">
          <thead className="sticky top-0 bg-black/90">
            <tr className="border-b border-[#00FF41]/10">
              {COLUMNS.map((c) => (
                <th
                  key={c.key}
                  aria-sort={getAriaSortValue(c.key, sortKey, sortDir)}
                  className="text-left p-0"
                >
                  <button
                    type="button"
                    onClick={() => toggleSort(c.key)}
                    title={c.title}
                    className="w-full px-3 py-2 text-left text-[9px] uppercase tracking-widest font-black opacity-70 hover:opacity-100 hover:bg-[#00FF41]/5 focus:outline-none focus-visible:ring-2 focus-visible:ring-[#00FF41]/30 flex items-center justify-start"
                  >
                    <span className="inline-flex items-center gap-2">
                      <span>{c.label}</span>
                      <span className="opacity-40">
                        {getSortIcon(c.key, sortKey, sortDir)}
                      </span>
                    </span>
                  </button>
                </th>
              ))}
              <th className="w-8"></th>
            </tr>
          </thead>
          <tbody>
            {/* Loading state */}
            {loading && runs.length === 0 && (
              <tr>
                <td colSpan={5} className="px-3 py-8 text-center text-matrix-dim animate-pulse">
                  Loading runs...
                </td>
              </tr>
            )}

            {/* Empty state */}
            {!loading && runs.length === 0 && (
              <tr>
                <td colSpan={5} className="px-3 py-8 text-center text-matrix-dim">
                  No runs recorded yet
                </td>
              </tr>
            )}

            {/* Runs list */}
            {sortedRuns.map((run) => {
              const status = getRunStatus(run);
              const statusConfig = getStatusConfig(status);
              const displayTime = run.finished_at || run.started_at;
              
              return (
                <tr
                  key={run.id}
                  className="border-b border-[#00FF41]/5 hover:bg-[#00FF41]/5 cursor-pointer transition-colors"
                  onClick={() => onSelectRun(run.id)}
                >
                  <td className="px-3 py-2 text-[12px] font-mono font-bold">
                    {run.task}
                  </td>
                  <td className="px-3 py-2 text-[12px] font-mono">
                    <span
                      className={`inline-flex items-center gap-1.5 ${statusConfig.className}`}
                    >
                      <span className={`w-1.5 h-1.5 rounded-full bg-current ${statusConfig.dot}`}></span>
                      {statusConfig.label}
                      {status === "failed" && run.exit_code !== null && (
                        <span className="opacity-60 text-[10px]">({run.exit_code})</span>
                      )}
                    </span>
                  </td>
                  <td className="px-3 py-2 text-[12px] font-mono opacity-80">
                    {status === "running" ? (
                      <span className="text-cyan-400 animate-pulse">...</span>
                    ) : run.duration_ms ? (
                      formatDurationMs(run.duration_ms)
                    ) : (
                      "—"
                    )}
                  </td>
                  <td className="px-3 py-2 text-[12px] font-mono opacity-80">
                    {displayTime ? formatRelativeTime(displayTime) : "—"}
                  </td>
                  <td className="px-3 py-2 text-[12px] font-mono opacity-40 text-right">
                    →
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="flex items-center justify-between mt-3 text-[9px] uppercase tracking-widest font-black">
          <MatrixButton
            size="small"
            disabled={page <= 1}
            onClick={() => onPageChange(page - 1)}
          >
            ← Prev
          </MatrixButton>
          <span className="opacity-50">
            Page {page} / {totalPages}
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
    </AsciiBox>
  );
}
