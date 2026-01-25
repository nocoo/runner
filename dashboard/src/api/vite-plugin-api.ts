import type { Plugin, ViteDevServer } from "vite";
import { resolve } from "path";
import { spawn } from "child_process";
import { readFile } from "fs/promises";
import { existsSync } from "fs";
import { watch } from "chokidar";

const DATA_DIR = resolve(__dirname, "../../../data");
// Use Swift binary (runner) instead of Bash script (runner.sh)
// Swift version has native file locking, no dependency on Linux flock command
const RUNNER_BINARY = resolve(__dirname, "../../../runner");

async function readJsonFile(path: string): Promise<unknown> {
  try {
    if (!existsSync(path)) {
      return null;
    }
    const content = await readFile(path, "utf-8");
    return JSON.parse(content);
  } catch {
    return null;
  }
}

export function apiPlugin(): Plugin {
  return {
    name: "runner-api",
    configureServer(server: ViteDevServer) {
      // Watch data folder for changes and notify frontend via WebSocket
      const watcher = watch(DATA_DIR, {
        ignoreInitial: true,
        ignored: /\.DS_Store/,
      });

      watcher.on("all", (event, filePath) => {
        console.log(`[runner-api] ${event}: ${filePath}`);
        server.ws.send({
          type: "custom",
          event: "runner:data-change",
          data: { event, path: filePath },
        });
      });

      // Cleanup watcher on server close
      server.httpServer?.on("close", () => watcher.close());

      server.middlewares.use(async (req, res, next) => {
        const url = req.url || "";

        // Only handle /api routes
        if (!url.startsWith("/api/")) {
          return next();
        }

        res.setHeader("Content-Type", "application/json");

        try {
          // GET /api/status
          if (url === "/api/status" && req.method === "GET") {
            const data = await readJsonFile(resolve(DATA_DIR, "state.json"));
            res.end(JSON.stringify(data ?? { error: "Not found" }));
            return;
          }

          // GET /api/tasks
          if (url === "/api/tasks" && req.method === "GET") {
            const data = await readJsonFile(resolve(DATA_DIR, "tasks.json"));
            res.end(JSON.stringify(data ?? []));
            return;
          }

          // GET /api/schedules
          if (url === "/api/schedules" && req.method === "GET") {
            const data = await readJsonFile(resolve(DATA_DIR, "schedules.json"));
            res.end(JSON.stringify(data ?? []));
            return;
          }

          // GET /api/runs
          if (url === "/api/runs" && req.method === "GET") {
            const data = await readJsonFile(resolve(DATA_DIR, "runs/index.json"));
            res.end(JSON.stringify(data ?? { runs: [], total: 0 }));
            return;
          }

          // GET /api/runs/:id
          const runMatch = url.match(/^\/api\/runs\/([a-fA-F0-9-]{36})$/i);
          if (runMatch && req.method === "GET") {
            const id = runMatch[1];
            // Try to read individual .json file first
            const data = await readJsonFile(resolve(DATA_DIR, `runs/${id}.json`));
            if (data) {
              res.end(JSON.stringify(data));
              return;
            }
            // Fall back to index.json for basic info (e.g., interrupted tasks without .json)
            const indexData = await readJsonFile(resolve(DATA_DIR, "runs/index.json")) as { runs?: Array<{ id: string; task: string; exit_code: number | null; started_at?: string; finished_at?: string | null }> } | null;
            if (indexData?.runs) {
              const runFromIndex = indexData.runs.find(r => r.id === id);
              if (runFromIndex) {
                // Calculate duration if both timestamps exist
                let duration_seconds: number | undefined;
                if (runFromIndex.started_at && runFromIndex.finished_at) {
                  duration_seconds = Math.round((new Date(runFromIndex.finished_at).getTime() - new Date(runFromIndex.started_at).getTime()) / 1000);
                }
                res.end(JSON.stringify({
                  id: runFromIndex.id,
                  task: runFromIndex.task,
                  trigger: "auto",
                  started_at: runFromIndex.started_at || "",
                  finished_at: runFromIndex.finished_at || undefined,
                  duration_seconds,
                  exit_code: runFromIndex.exit_code ?? -1,
                }));
                return;
              }
            }
            res.statusCode = 404;
            res.end(JSON.stringify({ error: "Run not found" }));
            return;
          }

          // GET /api/runs/:id/output - get full task output
          const outputMatch = url.match(/^\/api\/runs\/([a-fA-F0-9-]{36})\/output$/i);
          if (outputMatch && req.method === "GET") {
            const id = outputMatch[1];
            const outputPath = resolve(DATA_DIR, `runs/${id}.output`);
            try {
              if (!existsSync(outputPath)) {
                res.statusCode = 404;
                res.end(JSON.stringify({ error: "Output file not found" }));
                return;
              }
              const content = await readFile(outputPath, "utf-8");
              res.end(JSON.stringify({ output: content }));
            } catch {
              res.statusCode = 500;
              res.end(JSON.stringify({ error: "Failed to read output file" }));
            }
            return;
          }

          // POST /api/trigger/:task - trigger task execution
          const triggerMatch = url.match(/^\/api\/trigger\/([a-z_]+)$/);
          if (triggerMatch && req.method === "POST") {
            const task = triggerMatch[1];
            
            // Execute Swift runner binary: `runner run <task>`
            // Include common paths where opencode/homebrew binaries are installed
            const extendedPath = [
              "/opt/homebrew/bin",
              "/opt/homebrew/sbin",
              "/usr/local/bin",
              process.env.HOME + "/.local/bin",
              process.env.PATH,
            ].filter(Boolean).join(":");
            
            const child = spawn(RUNNER_BINARY, ["run", task], {
              cwd: resolve(__dirname, "../../.."),
              stdio: ["ignore", "pipe", "pipe"],
              env: { ...process.env, PATH: extendedPath },
            });

            let stdout = "";
            let stderr = "";

            child.stdout.on("data", (data) => {
              stdout += data.toString();
            });

            child.stderr.on("data", (data) => {
              stderr += data.toString();
            });

            child.on("close", (code) => {
              res.end(
                JSON.stringify({
                  task,
                  exit_code: code,
                  stdout: stdout.slice(0, 1000),
                  stderr: stderr.slice(0, 1000),
                })
              );
            });

            child.on("error", (err) => {
              res.statusCode = 500;
              res.end(JSON.stringify({ error: err.message }));
            });

            return;
          }

          // Not found
          res.statusCode = 404;
          res.end(JSON.stringify({ error: "Not found" }));
        } catch (err) {
          res.statusCode = 500;
          res.end(JSON.stringify({ error: String(err) }));
        }
      });
    },
  };
}
