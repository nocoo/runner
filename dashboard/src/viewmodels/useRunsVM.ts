// ============================================
// Runs ViewModel
// ============================================

import { useState, useEffect, useCallback, useMemo } from "react";
import type { RunsIndex, RunSummary, RunDetail, LoadingState } from "@/models/types";
import { fetchRuns as fetchRunsDefault, fetchRunDetail as fetchRunDetailDefault, fetchRunOutput as fetchRunOutputDefault } from "@/models/api";
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
  selectedRunOutput: string | null;
  selectedRunOutputLoading: boolean;
  selectedRunOutputError: string | null;
  selectRun: (id: string | null) => Promise<void>;
  // Derived data
  heatmapData: ReturnType<typeof runsToHeatmap>;
  trendData: ReturnType<typeof runsToTrend>;
}

export type RunsVMDeps = {
  fetchRuns?: typeof fetchRunsDefault;
  fetchRunDetail?: typeof fetchRunDetailDefault;
  fetchRunOutput?: typeof fetchRunOutputDefault;
  hot?: HotModuleApi;
  watchData?: boolean;
  autoRefresh?: boolean;
};

export function useRunsVM(pageSize = 30, deps: RunsVMDeps = {}): RunsVM {
  const [runsIndex, setRunsIndex] = useState<RunsIndex | null>(null);
  const [state, setState] = useState<LoadingState>("loading");
  const [error, setError] = useState<string | null>(null);
  const [page, setPage] = useState(1);
  const [selectedRun, setSelectedRun] = useState<RunDetail | null>(null);
  const [selectedRunLoading, setSelectedRunLoading] = useState(false);
  const [selectedRunError, setSelectedRunError] = useState<string | null>(null);
  const [selectedRunOutput, setSelectedRunOutput] = useState<string | null>(null);
  const [selectedRunOutputLoading, setSelectedRunOutputLoading] = useState(false);
  const [selectedRunOutputError, setSelectedRunOutputError] = useState<string | null>(null);

  const fetchRuns = deps.fetchRuns ?? fetchRunsDefault;
  const fetchRunDetail = deps.fetchRunDetail ?? fetchRunDetailDefault;
  const fetchRunOutput = deps.fetchRunOutput ?? fetchRunOutputDefault;

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
  useDataWatcher(refresh, deps.hot, deps.watchData ?? true);

  useEffect(() => {
    if (deps.autoRefresh === false) return;
    refresh();
  }, [refresh, deps.autoRefresh]);

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
      setSelectedRunOutput(null);
      setSelectedRunOutputError(null);
      setSelectedRunOutputLoading(false);
      return;
    }

    setSelectedRunLoading(true);
    setSelectedRunError(null);
    setSelectedRunOutput(null);
    setSelectedRunOutputError(null);
    setSelectedRunOutputLoading(false);
    try {
      const detail = await fetchRunDetail(id);
      setSelectedRun(detail);

      setSelectedRunOutputLoading(true);
      try {
        const output = await fetchRunOutput(id);
        setSelectedRunOutput(output);
      } catch {
        setSelectedRunOutput(null);
        setSelectedRunOutputError("Failed to load run output");
      } finally {
        setSelectedRunOutputLoading(false);
      }
    } catch {
      setSelectedRun(null);
      setSelectedRunError("Failed to load run detail");
    } finally {
      setSelectedRunLoading(false);
    }
  }, [fetchRunDetail, fetchRunOutput]);

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
    selectedRunOutput,
    selectedRunOutputLoading,
    selectedRunOutputError,
    selectRun,
    heatmapData,
    trendData,
  };
}
