// ============================================
// Tasks ViewModel
// ============================================

import { useState, useEffect, useCallback, useMemo } from "react";
import type { Task, Schedule, TaskWithSchedule, LoadingState, TriggerResponse } from "@/models/types";
import { fetchTasks as fetchTasksDefault, fetchSchedules as fetchSchedulesDefault, triggerTask as triggerTaskDefault } from "@/models/api";
import { combineTasksWithSchedules } from "@/models/transforms";
import { useDataWatcher, type HotModuleApi } from "./useDataWatcher";

interface TasksVM {
  tasks: TaskWithSchedule[];
  rawTasks: Task[];
  schedules: Schedule[];
  state: LoadingState;
  error: string | null;
  refresh: () => Promise<void>;
  // Trigger
  triggerState: LoadingState;
  triggerResult: TriggerResponse | null;
  triggerError: string | null;
  trigger: (taskId: string) => Promise<void>;
  clearTriggerResult: () => void;
}

export type TasksVMDeps = {
  fetchTasks?: typeof fetchTasksDefault;
  fetchSchedules?: typeof fetchSchedulesDefault;
  triggerTask?: typeof triggerTaskDefault;
  hot?: HotModuleApi;
};

export function useTasksVM(deps: TasksVMDeps = {}): TasksVM {
  const [tasks, setTasks] = useState<Task[]>([]);
  const [schedules, setSchedules] = useState<Schedule[]>([]);
  const [state, setState] = useState<LoadingState>("loading");
  const [error, setError] = useState<string | null>(null);

  const [triggerState, setTriggerState] = useState<LoadingState>("idle");
  const [triggerResult, setTriggerResult] = useState<TriggerResponse | null>(null);
  const [triggerError, setTriggerError] = useState<string | null>(null);

  const fetchTasks = deps.fetchTasks ?? fetchTasksDefault;
  const fetchSchedules = deps.fetchSchedules ?? fetchSchedulesDefault;
  const triggerTask = deps.triggerTask ?? triggerTaskDefault;

  const refresh = useCallback(async () => {
    setState("loading");
    setError(null);

    try {
      const [tasksResult, schedulesResult] = await Promise.all([
        fetchTasks(),
        fetchSchedules(),
      ]);
      setTasks(tasksResult);
      setSchedules(schedulesResult);
      setState("success");
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
      setState("error");
    }
  }, [fetchTasks, fetchSchedules]);

  // Auto-refresh when data files change
  useDataWatcher(refresh, deps.hot);

  useEffect(() => {
    refresh();
  }, [refresh]);

  // Combined tasks with schedules
  const combinedTasks = useMemo(
    () => combineTasksWithSchedules(tasks, schedules),
    [tasks, schedules]
  );

  // Trigger a task
  const trigger = useCallback(async (taskId: string) => {
    setTriggerState("loading");
    setTriggerResult(null);
    setTriggerError(null);

    try {
      const result = await triggerTask(taskId);
      setTriggerResult(result);
      setTriggerState("success");
    } catch (err) {
      setTriggerError(err instanceof Error ? err.message : String(err));
      setTriggerState("error");
    }
  }, [triggerTask]);

  const clearTriggerResult = useCallback(() => {
    setTriggerState("idle");
    setTriggerResult(null);
    setTriggerError(null);
  }, []);

  return {
    tasks: combinedTasks,
    rawTasks: tasks,
    schedules,
    state,
    error,
    refresh,
    triggerState,
    triggerResult,
    triggerError,
    trigger,
    clearTriggerResult,
  };
}
