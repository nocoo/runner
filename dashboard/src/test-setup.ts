import { afterEach, vi } from "vitest";
import { cleanup, configure } from "@testing-library/react";

declare global {
  // eslint-disable-next-line no-var
  var IS_REACT_ACT_ENVIRONMENT: boolean;
}
globalThis.IS_REACT_ACT_ENVIRONMENT = true;

// Node 22+ ships an experimental WebStorage that shadows happy-dom's localStorage
// with a non-functional stub (no getItem/setItem methods). Replace it with a
// real in-memory Storage so tests work without requiring --no-experimental-webstorage.
function installMemoryStorage(key: "localStorage" | "sessionStorage"): void {
  const existing = (globalThis as Record<string, unknown>)[key];
  if (existing && typeof (existing as Storage).getItem === "function") return;
  const store = new Map<string, string>();
  const storage: Storage = {
    get length() {
      return store.size;
    },
    clear: () => store.clear(),
    getItem: (k) => (store.has(k) ? store.get(k)! : null),
    key: (i) => Array.from(store.keys())[i] ?? null,
    removeItem: (k) => {
      store.delete(k);
    },
    setItem: (k, v) => {
      store.set(k, String(v));
    },
  };
  Object.defineProperty(globalThis, key, { value: storage, writable: true, configurable: true });
  if (typeof window !== "undefined") {
    Object.defineProperty(window, key, { value: storage, writable: true, configurable: true });
  }
}
installMemoryStorage("localStorage");
installMemoryStorage("sessionStorage");

// Block real network requests in tests; tests that need fetch should mock per-test.
if (typeof globalThis.fetch === "function") {
  vi.stubGlobal(
    "fetch",
    vi.fn(() => Promise.reject(new Error("network disabled in tests; mock fetch per-test"))),
  );
}

const originalError = console.error;
console.error = (...args: unknown[]) => {
  const message = args[0];
  if (typeof message === "string" && message.includes("not wrapped in act")) {
    return;
  }
  originalError.apply(console, args);
};

configure({
  asyncUtilTimeout: 2000,
});

afterEach(() => {
  cleanup();
});
