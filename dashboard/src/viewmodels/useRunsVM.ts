// ============================================
// Runs ViewModel
// ============================================

import { useState, useEffect, useCallback, useMemo } from "react";
import type { RunsIndex, RunSummary, RunDetail, LoadingState } from "@/models/types";
import { fetchRuns as fetchRunsDefault, fetchRunDetail as fetchRunDetailDefault } from "@/models/api";
import { sortRunsByDate, runsToHeatmap, runsToTrend } from "@/models/transforms";
import { useDataWatcher, type HotModuleApi } from "./useDataWatcher";

interface RunsVM {
  runs: RunSummary[];
  total: number;
  state: LoadingState;
  error: string | null;
  refresh: () => Promise<void>;
  // Pagination
  page: number;
  pageSize: number;
  totalPages: number;
  setPage: (page: number) => void;
  pagedRuns: RunSummary[];
  // Selected run detail
  selectedRun: RunDetail | null;
  selectedRunLoading: boolean;
  selectedRunError: string | null;
  selectRun: (id: string | null) => Promise<void>;
  // Derived data
  heatmapData: ReturnType<typeof runsToHeatmap>;
  trendData: ReturnType<typeof runsToTrend>;
}

export type RunsVMDeps = {
  fetchRuns?: typeof fetchRunsDefault;
  fetchRunDetail?: typeof fetchRunDetailDefault;
  hot?: HotModuleApi;
};

export function useRunsVM(pageSize = 30, deps: RunsVMDeps = {}): RunsVM {
  const [runsIndex, setRunsIndex] = useState<RunsIndex | null>(null);
  const [state, setState] = useState<LoadingState>("loading");
  const [error, setError] = useState<string | null>(null);
  const [page, setPage] = useState(1);
  const [selectedRun, setSelectedRun] = useState<RunDetail | null>(null);
  const [selectedRunLoading, setSelectedRunLoading] = useState(false);
  const [selectedRunError, setSelectedRunError] = useState<string | null>(null);

  const fetchRuns = deps.fetchRuns ?? fetchRunsDefault;
  const fetchRunDetail = deps.fetchRunDetail ?? fetchRunDetailDefault;

  const refresh = useCallback(async () => {
    setState("loading");
    setError(null);

    try {
      const result = await fetchRuns();
      setRunsIndex(result);
      setState("success");
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
      setState("error");
    }
  }, [fetchRuns]);

  // Auto-refresh when data files change
  useDataWatcher(refresh, deps.hot);

  useEffect(() => {
    refresh();
  }, [refresh]);

  // Sorted runs (newest first)
  const runs = useMemo(() => {
    if (!runsIndex?.runs) return [];
    return sortRunsByDate(runsIndex.runs, "desc");
  }, [runsIndex]);

  const total = runsIndex?.total ?? 0;
  const totalPages = Math.ceil(runs.length / pageSize);

  // Paginated runs
  const pagedRuns = useMemo(() => {
    const start = (page - 1) * pageSize;
    return runs.slice(start, start + pageSize);
  }, [runs, page, pageSize]);

  // Select run detail
  const selectRun = useCallback(async (id: string | null) => {
    if (!id) {
      setSelectedRun(null);
      return;
    }

    setSelectedRunLoading(true);
    setSelectedRunError(null);
    try {
      const detail = await fetchRunDetail(id);
      setSelectedRun(detail);
    } catch {
      setSelectedRun(null);
      setSelectedRunError("Failed to load run detail");
    } finally {
      setSelectedRunLoading(false);
    }
  }, []);

  // Derived data for visualizations
  const heatmapData = useMemo(() => runsToHeatmap(runs), [runs]);
  const trendData = useMemo(() => runsToTrend(runs), [runs]);

  return {
    runs,
    total,
    state,
    error,
    refresh,
    page,
    pageSize,
    totalPages,
    setPage,
    pagedRuns,
    selectedRun,
    selectedRunLoading,
    selectedRunError,
    selectRun,
    heatmapData,
    trendData,
  };
}
