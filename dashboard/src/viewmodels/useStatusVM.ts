// ============================================
// Status ViewModel
// ============================================

import { useState, useEffect, useCallback } from "react";
import type { SystemState, LoadingState } from "@/models/types";
import { fetchStatus as fetchStatusDefault } from "@/models/api";
import { formatPercent, formatExitCode } from "@/lib/format";
import { useDataWatcher, type HotModuleApi } from "./useDataWatcher";

interface StatusVM {
  data: SystemState | null;
  state: LoadingState;
  error: string | null;
  refresh: () => Promise<void>;
  // Derived values
  successRatePercent: string;
  lastRunStatus: string;
  lastRunTask: string;
  isOnline: boolean;
}

export type StatusVMDeps = {
  fetchStatus?: typeof fetchStatusDefault;
  hot?: HotModuleApi;
};

export function useStatusVM(deps: StatusVMDeps = {}): StatusVM {
  const [data, setData] = useState<SystemState | null>(null);
  const [state, setState] = useState<LoadingState>("loading");
  const [error, setError] = useState<string | null>(null);

  const fetchStatus = deps.fetchStatus ?? fetchStatusDefault;

  const refresh = useCallback(async () => {
    setState("loading");
    setError(null);

    try {
      const result = await fetchStatus();
      setData(result);
      setState("success");
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
      setState("error");
    }
  }, [fetchStatus]);

  // Auto-refresh when data files change
  useDataWatcher(refresh, deps.hot);

  useEffect(() => {
    refresh();
  }, [refresh]);

  // Derived values
  const successRatePercent = data ? formatPercent(data.success_rate_today) : "-";
  const lastRunStatus = data?.last_run ? formatExitCode(data.last_run.exit_code) : "-";
  const lastRunTask = data?.last_run?.task ?? "-";
  const isOnline = state === "success";

  return {
    data,
    state,
    error,
    refresh,
    successRatePercent,
    lastRunStatus,
    lastRunTask,
    isOnline,
  };
}
