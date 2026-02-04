import { GlobalRegistrator } from "@happy-dom/global-registrator";
import { configure } from "@testing-library/react";

GlobalRegistrator.register();

// Mark as React act environment to suppress act() warnings
// This is a known compatibility issue with happy-dom + React Testing Library
declare global {
  var IS_REACT_ACT_ENVIRONMENT: boolean;
}
globalThis.IS_REACT_ACT_ENVIRONMENT = true;

// Suppress console.error for act() warnings in test environment
const originalError = console.error;
console.error = (...args: unknown[]) => {
  const message = args[0];
  if (typeof message === "string" && message.includes("not wrapped in act")) {
    return; // Suppress act() warnings
  }
  originalError.apply(console, args);
};

// Configure testing-library
configure({
  asyncUtilTimeout: 2000,
});
