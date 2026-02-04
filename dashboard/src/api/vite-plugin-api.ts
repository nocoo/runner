import type { Plugin, ViteDevServer } from "vite";
import { resolve } from "path";
import { spawn, exec } from "child_process";
import { readFile } from "fs/promises";
import { existsSync } from "fs";
import { watch } from "chokidar";
import { promisify } from "util";

const execPromise = promisify(exec);

const DATA_DIR = resolve(__dirname, "../../../data");
// Use Swift binary (runner) instead of Bash script (runner.sh)
// Swift version has native file locking, no dependency on Linux flock command
const RUNNER_BINARY = resolve(__dirname, "../../../runner");

const ESC = String.fromCharCode(27);
const BEL = String.fromCharCode(7);
const ANSI_ESCAPE = new RegExp(`${ESC}[[0-?]*[ -/]*[@-~]`, "g");
const ANSI_OSC = new RegExp(`${ESC}][^${BEL}]*(?:${BEL}|${ESC}\\\\)`, "g");

function stripAnsi(input: string): string {
  return input.replace(ANSI_OSC, "").replace(ANSI_ESCAPE, "");
}

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

/**
 * Execute runner CLI command and return stdout
 */
async function runnerApi(query: string): Promise<string> {
  const { stdout } = await execPromise(`"${RUNNER_BINARY}" api --data-dir "${DATA_DIR}" ${query}`);
  return stdout;
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
          // GET /api/status - read from SQLite via runner CLI
          if (url === "/api/status" && req.method === "GET") {
            const data = await readJsonFile(resolve(DATA_DIR, "state.json"));
            res.end(JSON.stringify(data ?? { error: "Not found" }));
            return;
          }

          // GET /api/tasks - read from JSON (will migrate to SQLite in Phase 5)
          if (url === "/api/tasks" && req.method === "GET") {
            const data = await readJsonFile(resolve(DATA_DIR, "tasks.json"));
            res.end(JSON.stringify(data ?? []));
            return;
          }

          // GET /api/schedules - read from JSON (will migrate to SQLite in Phase 5)
          if (url === "/api/schedules" && req.method === "GET") {
            const data = await readJsonFile(resolve(DATA_DIR, "schedules.json"));
            res.end(JSON.stringify(data ?? []));
            return;
          }

          // GET /api/runs - read from SQLite via runner CLI
          if (url === "/api/runs" && req.method === "GET") {
            try {
              const output = await runnerApi("runs");
              res.end(output);
            } catch (err) {
              console.error("[runner-api] Failed to get runs:", err);
              res.end(JSON.stringify({ runs: [], total: 0 }));
            }
            return;
          }

          // GET /api/runs/:id - read from SQLite via runner CLI
          const runMatch = url.match(/^\/api\/runs\/([a-fA-F0-9-]{36})$/i);
          if (runMatch && req.method === "GET") {
            const id = runMatch[1];
            try {
              const output = await runnerApi(`run ${id}`);
              // Check if result is null (run not found or not completed)
              const parsed = JSON.parse(output);
              if (parsed === null) {
                res.statusCode = 404;
                res.end(JSON.stringify({ error: "Run not found" }));
                return;
              }
              res.end(output);
            } catch (err) {
              console.error("[runner-api] Failed to get run detail:", err);
              res.statusCode = 500;
              res.end(JSON.stringify({ error: "Failed to get run detail" }));
            }
            return;
          }

          // GET /api/runs/:id/output - get full task output from file system
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
              res.end(JSON.stringify({ output: stripAnsi(content) }));
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
