// ============================================
// Data Watcher Hook
// ============================================
// Listens for data folder changes via Vite HMR WebSocket
// and automatically triggers refresh

import { useEffect } from "react";

/**
 * Watch for data file changes and auto-refresh
 * Only works in dev mode (Vite HMR)
 */
export function useDataWatcher(refresh: () => void) {
  useEffect(() => {
    if (import.meta.hot) {
      const handler = () => {
        refresh();
      };
      import.meta.hot.on("runner:data-change", handler);

      return () => {
        import.meta.hot?.off("runner:data-change", handler);
      };
    }
  }, [refresh]);
}
