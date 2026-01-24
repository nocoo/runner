// ============================================
// Run History Table
// Based on vibeusage DETAILS table pattern
// ============================================

import { useState, useMemo } from "react";
import type { RunSummary } from "@/models/types";
import { AsciiBox, MatrixButton } from "@/ui/foundation";
import { formatRelativeTime, formatDuration } from "@/lib/format";

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
  { key: "finished_at", label: "Finished", title: "Sort by finish time" },
];

function getSortIcon(key: SortKey, sortKey: SortKey, sortDir: SortDir): string {
  if (key !== sortKey) return "↕";
  return sortDir === "asc" ? "↑" : "↓";
}

function getAriaSortValue(key: SortKey, sortKey: SortKey, sortDir: SortDir): "ascending" | "descending" | "none" {
  if (key !== sortKey) return "none";
  return sortDir === "asc" ? "ascending" : "descending";
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
          cmp = a.exit_code - b.exit_code;
          break;
        case "duration":
          cmp = (a.duration_ms ?? 0) - (b.duration_ms ?? 0);
          break;
        case "finished_at":
          cmp = new Date(a.finished_at).getTime() - new Date(b.finished_at).getTime();
          break;
      }
      return sortDir === "asc" ? cmp : -cmp;
    });
    return sorted;
  }, [runs, sortKey, sortDir]);

  return (
    <AsciiBox title="Run History" subtitle={`${runs.length} runs`}>
      <div
        className="overflow-auto max-h-[520px] border border-[#00FF41]/10"
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
            {sortedRuns.map((run) => (
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
                    className={`inline-flex items-center gap-1.5 ${
                      run.exit_code === 0 ? "text-success" : "text-error"
                    }`}
                  >
                    <span className="w-1.5 h-1.5 rounded-full bg-current"></span>
                    {run.exit_code === 0 ? "OK" : `ERR ${run.exit_code}`}
                  </span>
                </td>
                <td className="px-3 py-2 text-[12px] font-mono opacity-80">
                  {run.duration_ms ? formatDuration(run.duration_ms) : "—"}
                </td>
                <td className="px-3 py-2 text-[12px] font-mono opacity-80">
                  {formatRelativeTime(run.finished_at)}
                </td>
                <td className="px-3 py-2 text-[12px] font-mono opacity-40 text-right">
                  →
                </td>
              </tr>
            ))}
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
