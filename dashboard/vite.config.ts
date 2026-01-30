import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { resolve } from "path";
import { apiPlugin } from "./src/api/vite-plugin-api";

export default defineConfig({
  plugins: [react(), apiPlugin()],
  resolve: {
    alias: {
      "@": resolve(__dirname, "src"),
    },
  },
  server: {
    port: 7009,
    allowedHosts: ["runner.dev.hexly.ai"],
  },
  preview: {
    port: 7009,
  },
});
