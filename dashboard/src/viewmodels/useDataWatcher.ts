// ============================================
// Data Watcher Hook
// ============================================
// Listens for data folder changes via Vite HMR WebSocket
// and automatically triggers refresh

import { useEffect } from "react";

export type HotModuleApi = {
  on: (event: string, cb: () => void) => void;
  off: (event: string, cb: () => void) => void;
};

/**
 * Watch for data file changes and auto-refresh
 * Only works in dev mode (Vite HMR)
 */
export function useDataWatcher(refresh: () => void, hot?: HotModuleApi | null, enabled: boolean = true) {
  useEffect(() => {
    if (!enabled) return;
    const hmr = hot === undefined ? import.meta.hot : hot;
    if (hmr) {
      const handler = () => {
        refresh();
      };
      hmr.on("runner:data-change", handler);

      return () => {
        hmr.off("runner:data-change", handler);
      };
    }
  }, [refresh, hot, enabled]);
}
