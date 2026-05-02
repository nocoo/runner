import { afterEach } from "vitest";
import { cleanup, configure } from "@testing-library/react";

declare global {
  // eslint-disable-next-line no-var
  var IS_REACT_ACT_ENVIRONMENT: boolean;
}
globalThis.IS_REACT_ACT_ENVIRONMENT = true;

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
