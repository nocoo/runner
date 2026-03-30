import { defineConfig } from "vite";
import react from "@vitejs/plugin-react-swc";
import tailwindcss from "@tailwindcss/vite";
import { resolve } from "path";
import { apiPlugin } from "./src/api/vite-plugin-api";

export default defineConfig({
  plugins: [tailwindcss(), react(), apiPlugin()],
  resolve: {
    alias: {
      "@": resolve(__dirname, "src"),
    },
  },
  server: {
    port: 7008,
    allowedHosts: ["runner.dev.hexly.ai"],
  },
  preview: {
    port: 7008,
  },
});
