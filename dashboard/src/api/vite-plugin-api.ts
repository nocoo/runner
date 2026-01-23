import type { Plugin, ViteDevServer } from "vite";
import { resolve } from "path";
import { spawn } from "child_process";
import { readFile } from "fs/promises";
import { existsSync } from "fs";

const DATA_DIR = resolve(__dirname, "../../../data");
const RUNNER_SCRIPT = resolve(__dirname, "../../../runner.sh");

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
          const runMatch = url.match(/^\/api\/runs\/([a-f0-9-]{36})$/);
          if (runMatch && req.method === "GET") {
            const id = runMatch[1];
            const data = await readJsonFile(resolve(DATA_DIR, `runs/${id}.json`));
            if (data) {
              res.end(JSON.stringify(data));
            } else {
              res.statusCode = 404;
              res.end(JSON.stringify({ error: "Run not found" }));
            }
            return;
          }

          // POST /api/trigger/:task - trigger task execution
          const triggerMatch = url.match(/^\/api\/trigger\/([a-z_]+)$/);
          if (triggerMatch && req.method === "POST") {
            const task = triggerMatch[1];
            
            // Execute runner.sh with the task
            const child = spawn(RUNNER_SCRIPT, [task], {
              cwd: resolve(__dirname, "../../.."),
              stdio: ["ignore", "pipe", "pipe"],
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
