import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react-swc";
import { resolve } from "path";

const stripImportMetaHot = {
  name: "strip-import-meta-hot",
  enforce: "pre" as const,
  transform(code: string, id: string) {
    if (!/\.(ts|tsx|js|jsx)$/.test(id)) return null;
    if (!code.includes("import.meta.hot")) return null;
    return code.replace(/import\.meta\.hot/g, "undefined");
  },
};

export default defineConfig({
  plugins: [stripImportMetaHot, react()],
  resolve: {
    alias: {
      "@": resolve(__dirname, "src"),
    },
  },
  test: {
    environment: "happy-dom",
    setupFiles: ["./src/test-setup.ts"],
    globals: false,
    include: ["src/**/__tests__/**/*.{test,spec}.{ts,tsx}"],
    env: {
      TZ: "UTC",
    },
    coverage: {
      provider: "v8",
      reporter: ["text", "html", "lcov"],
      include: ["src/**/*.{ts,tsx}"],
      exclude: [
        "src/**/__tests__/**",
        "src/**/*.test.{ts,tsx}",
        "src/test-setup.ts",
        "src/main.tsx",
        "src/App.tsx",
        "src/api/**",
        "src/models/types.ts",
        "src/pages/index.ts",
        "src/pages/DashboardPage.tsx",
        "src/pages/HistoryPage.tsx",
        "src/ui/**/*.tsx",
        "src/ui/**/index.ts",
        "src/components/DashboardLayout.tsx",
        "src/viewmodels/index.ts",
      ],
      thresholds: {
        lines: 95,
        functions: 95,
        branches: 95,
        statements: 95,
      },
    },
  },
});
