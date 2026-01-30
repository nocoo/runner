// ============================================
// Tasks ViewModel
// ============================================

import { useState, useEffect, useCallback, useMemo } from "react";
import type { Task, Schedule, TaskWithSchedule, LoadingState, TriggerResponse, UpcomingTask } from "@/models/types";
import { fetchTasks as fetchTasksDefault, fetchSchedules as fetchSchedulesDefault, triggerTask as triggerTaskDefault } from "@/models/api";
import { combineTasksWithSchedules, calculateUpcomingTasks } from "@/models/transforms";
import { useDataWatcher, type HotModuleApi } from "./useDataWatcher";

export interface TasksVM {
  tasks: TaskWithSchedule[];
  rawTasks: Task[];
  schedules: Schedule[];
  upcomingTasks: UpcomingTask[];
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
  timeProvider?: () => Date;
  tickMs?: number;
  upcomingCount?: number;
  watchData?: boolean;
  autoRefresh?: boolean;
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
  const timeProvider = useMemo(
    () => deps.timeProvider ?? (() => new Date()),
    [deps.timeProvider]
  );
  const tickMs = deps.tickMs ?? 1000;
  const upcomingCount = deps.upcomingCount ?? 8;

  const [now, setNow] = useState<Date>(() => timeProvider());

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
  useDataWatcher(refresh, deps.hot, deps.watchData ?? true);

  useEffect(() => {
    if (deps.autoRefresh === false) return;
    refresh();
  }, [refresh, deps.autoRefresh]);

  // Combined tasks with schedules
  const combinedTasks = useMemo(
    () => combineTasksWithSchedules(tasks, schedules),
    [tasks, schedules]
  );

  // Upcoming tasks with countdown
  useEffect(() => {
    const interval = setInterval(() => {
      setNow(timeProvider());
    }, tickMs);

    return () => clearInterval(interval);
  }, [tickMs, timeProvider]);

  const upcomingTasks = useMemo(() => {
    return calculateUpcomingTasks(tasks, schedules, upcomingCount).map((item) => ({
      ...item,
      countdown: item.nextRun.getTime() - now.getTime(),
    }));
  }, [tasks, schedules, upcomingCount, now]);

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
    upcomingTasks,
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
