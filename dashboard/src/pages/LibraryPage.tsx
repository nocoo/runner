// ============================================
// Library Page - Component Showcase with Mock Data
// ============================================

import { useState } from "react";
import {
  MatrixShell,
  AsciiBox,
  MatrixButton,
  MatrixAvatar,
  ScrambleText,
  DecodingText,
  SignalBox,
  MatrixInput,
  TypewriterText,
  ConnectionStatus,
  DataRow,
  LeaderboardRow,
  LiveSniffer,
  Sparkline,
  MatrixRain,
  BootScreen,
  // New components from VibeComponents
  ErrorBoundary,
  BackendStatus,
  SystemHeader,
  IdentityPanel,
  IdentityCard,
  TopModelsPanel,
  LeaderboardPanel,
  UsagePanel,
  NeuralAdaptiveFleet,
  NeuralDivergenceMap,
  GithubStar,
  UpgradeAlertModal,
  CostAnalysisModal,
  // Data visualization
  TrendMonitor,
  TrendChart as SimpleTrendChart,
  ActivityHeatmap,
  // Layout examples
  DashboardViewExample,
  LandingViewExample,
} from "@/ui/foundation";
import {
  RunHistory,
  TaskSchedule,
  RunHeatmap,
  TrendChart,
  RunDetailModal,
  MatrixClock,
} from "@/ui/runner";
import type { RunSummary, RunDetail, HeatmapCell, TrendPoint, TaskWithSchedule } from "@/models/types";

// ============================================
// Mock Data
// ============================================

const MOCK_RUNS: RunSummary[] = [
  { id: "run-001", task: "morning_briefing", exit_code: 0, started_at: "2026-01-24T09:00:00Z", finished_at: "2026-01-24T09:05:00+08:00" },
  { id: "run-002", task: "heartbeat", exit_code: 0, started_at: "2026-01-24T09:00:00Z", finished_at: "2026-01-24T09:10:00+08:00" },
  { id: "run-003", task: "heartbeat", exit_code: 1, started_at: "2026-01-24T09:00:00Z", finished_at: "2026-01-24T09:20:00+08:00" },
  { id: "run-004", task: "twitter_collect", exit_code: 0, started_at: "2026-01-24T09:00:00Z", finished_at: "2026-01-24T10:00:00+08:00" },
  { id: "run-005", task: "heartbeat", exit_code: 0, started_at: "2026-01-24T09:00:00Z", finished_at: "2026-01-24T10:10:00+08:00" },
  { id: "run-006", task: "heartbeat", exit_code: 0, started_at: "2026-01-24T09:00:00Z", finished_at: "2026-01-24T10:20:00+08:00" },
  { id: "run-007", task: "clock", exit_code: 0, started_at: "2026-01-24T09:00:00Z", finished_at: "2026-01-24T11:00:00+08:00" },
  { id: "run-008", task: "heartbeat", exit_code: 0, started_at: "2026-01-24T09:00:00Z", finished_at: "2026-01-24T11:10:00+08:00" },
  { id: "run-009", task: "heartbeat", exit_code: 1, started_at: "2026-01-24T09:00:00Z", finished_at: "2026-01-24T11:20:00+08:00" },
  { id: "run-010", task: "clock", exit_code: 0, started_at: "2026-01-24T09:00:00Z", finished_at: "2026-01-24T12:00:00+08:00" },
];

const MOCK_RUN_DETAIL: RunDetail = {
  id: "run-001",
  task: "morning_briefing",
  trigger: "auto",
  started_at: "2026-01-24T09:04:15+08:00",
  finished_at: "2026-01-24T09:05:00+08:00",
  duration_seconds: 45,
  exit_code: 0,
  output_preview: "Good morning! Here's your briefing for today...\n\n✓ Weather: Sunny, 22°C\n✓ Calendar: 3 meetings\n✓ Tasks: 5 pending items\n\nHave a productive day!",
};

const MOCK_TASKS: TaskWithSchedule[] = [
  {
    id: "morning_briefing",
    executor: "opencode",
    description: "Daily morning briefing with weather, calendar, and tasks",
    timeout: 300,
    prompt: "Generate a morning briefing summary with weather, calendar events, and pending tasks.",
    schedules: [{ task: "morning_briefing", hour: 9, minute: 0, weekday: "*" }],
  },
  {
    id: "heartbeat",
    executor: "shell",
    description: "System heartbeat check every 10 minutes",
    timeout: 60,
    command: "afplay /System/Library/Sounds/Pop.aiff",
    schedules: [
      { task: "heartbeat", hour: "*", minute: 10, weekday: "*" },
      { task: "heartbeat", hour: "*", minute: 20, weekday: "*" },
      { task: "heartbeat", hour: "*", minute: 40, weekday: "*" },
      { task: "heartbeat", hour: "*", minute: 50, weekday: "*" },
    ],
  },
  {
    id: "clock",
    executor: "opencode",
    description: "Hourly chime with time announcement",
    timeout: 60,
    prompt: "Announce the current time using the say command.",
    schedules: [
      { task: "clock", hour: "*", minute: 0, weekday: "*" },
      { task: "clock", hour: "*", minute: 30, weekday: "*" },
    ],
  },
  {
    id: "webhook_ping",
    executor: "http",
    description: "Notify external webhook on schedule",
    timeout: 30,
    url: "https://hooks.example.com/runner/ping",
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Runner-Token": "demo-token",
    },
    body: "{\"status\":\"ok\"}",
    schedules: [{ task: "webhook_ping", hour: 10, minute: 15, weekday: "*" }],
  },
  {
    id: "twitter_collect",
    executor: "opencode",
    description: "Collect and summarize Twitter feed",
    timeout: 180,
    prompt: "Collect relevant tweets from the timeline and generate a summary.",
    schedules: [{ task: "twitter_collect", hour: 10, minute: 0, weekday: "*" }],
  },
];

// Generate mock heatmap data for last 30 days
function generateMockHeatmap(): HeatmapCell[] {
  const cells: HeatmapCell[] = [];
  const now = new Date();
  const slots = [4, 6, 8, 10, 12, 14, 16, 18];

  for (let d = 29; d >= 0; d--) {
    const date = new Date(now);
    date.setDate(date.getDate() - d);
    const dateStr = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;

    for (const slot of slots) {
      // Random activity with some patterns
      const isWeekend = date.getDay() === 0 || date.getDay() === 6;
      const baseChance = isWeekend ? 0.3 : 0.7;
      const isActiveHour = slot >= 8 && slot <= 18;
      const chance = isActiveHour ? baseChance : baseChance * 0.3;

      if (Math.random() < chance) {
        const count = Math.floor(Math.random() * 8) + 1;
        const failed = Math.random() < 0.1 ? Math.floor(Math.random() * 2) : 0;
        cells.push({
          date: `${dateStr}T${String(slot).padStart(2, "0")}:00:00`,
          count,
          success: count - failed,
          failed,
        });
      }
    }
  }

  return cells;
}

// Generate mock trend data
function generateMockTrend(): TrendPoint[] {
  const points: TrendPoint[] = [];
  const now = new Date();

  for (let d = 13; d >= 0; d--) {
    const date = new Date(now);
    date.setDate(date.getDate() - d);
    const dateStr = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;

    const isWeekend = date.getDay() === 0 || date.getDay() === 6;
    const baseTotal = isWeekend ? 20 : 50;
    const total = baseTotal + Math.floor(Math.random() * 20) - 10;
    const successRate = 0.85 + Math.random() * 0.15;
    const success = Math.floor(total * successRate);

    points.push({
      date: dateStr,
      total,
      success,
      successRate,
    });
  }

  return points;
}

const MOCK_HEATMAP = generateMockHeatmap();
const MOCK_TREND = generateMockTrend();

// Mock data for new VibeComponents
const MOCK_IDENTITY = {
  name: "NEO",
  avatarUrl: undefined,
  isTheOne: true,
};

const MOCK_MODELS = [
  { model: "claude-4-sonnet", cost: 125.50, percent: 45 },
  { model: "gpt-4o", cost: 89.20, percent: 32 },
  { model: "claude-4-haiku", cost: 45.30, percent: 16 },
  { model: "gpt-4o-mini", cost: 19.80, percent: 7 },
];

const MOCK_LEADERBOARD = [
  { rank: 1, name: "ARCHITECT", value: 15420, isTheOne: true },
  { rank: 2, name: "ORACLE", value: 12850 },
  { rank: 3, name: "MORPHEUS", value: 11200 },
  { rank: 4, name: "YOU", value: 8750, isSelf: true },
  { rank: 5, name: "ANON_7734", value: 7200, isAnon: true },
];

const MOCK_USAGE_STATS = {
  totalCost: 279.80,
  totalTokens: 1_250_000,
  totalRequests: 842,
  avgLatency: 1.2,
};

const MOCK_FLEET_DATA = [
  {
    label: "Primary Fleet",
    usd: 180.50,
    models: [
      { id: "claude-4-sonnet", name: "Claude 4 Sonnet", share: 0.45, calc: "450 req × $0.40" },
      { id: "gpt-4o", name: "GPT-4o", share: 0.35, calc: "320 req × $0.35" },
    ],
  },
  {
    label: "Secondary Fleet",
    usd: 99.30,
    models: [
      { id: "claude-4-haiku", name: "Claude 4 Haiku", share: 0.6, calc: "160 req × $0.25" },
      { id: "gpt-4o-mini", name: "GPT-4o Mini", share: 0.4, calc: "70 req × $0.15" },
    ],
  },
];

// Mock trend data for TrendMonitor
const MOCK_TREND_MONITOR_DATA = Array.from({ length: 30 }, (_, i) => ({
  label: `Day ${i + 1}`,
  value: Math.floor(Math.random() * 100) + 20,
}));

// ============================================
// Library Page Component
// ============================================

export function LibraryPage() {
  const [selectedRun, setSelectedRun] = useState<RunDetail | null>(null);
  const [page, setPage] = useState(1);
  const [showCostModal, setShowCostModal] = useState(false);

  return (
    <MatrixShell
      title="Library"
      headerStatus={
        <span className="flex items-center">
          <span className="w-1.5 h-1.5 bg-warning rounded-full mr-2"></span>
          Component Showcase
        </span>
      }
      headerRight={
        <a
          href="/"
          className="matrix-header-chip matrix-header-action text-caption uppercase font-bold tracking-[0.2em]"
        >
          ← Dashboard
        </a>
      }
    >
      <div className="space-y-8">
        {/* Section: Foundation Components */}
        <section>
          <h2 className="text-lg uppercase font-bold text-matrix-bright mb-4 border-b border-matrix-ghost pb-2">
            Foundation Components
          </h2>

          <div className="grid grid-cols-12 gap-6">
            {/* AsciiBox */}
            <div className="col-span-12 lg:col-span-6">
              <AsciiBox title="AsciiBox" subtitle="container">
                <p className="text-matrix-muted mb-4">
                  The primary container component with ASCII art borders.
                  Supports title, subtitle, and custom body content.
                </p>
                <div className="flex gap-2">
                  <span className="px-2 py-1 bg-matrix-panelStrong border border-matrix-ghost text-caption">
                    Nested content
                  </span>
                </div>
              </AsciiBox>
            </div>

            {/* MatrixButton */}
            <div className="col-span-12 lg:col-span-6">
              <AsciiBox title="MatrixButton" subtitle="actions">
                <div className="space-y-4">
                  <div className="flex flex-wrap gap-3">
                    <MatrixButton>Default</MatrixButton>
                    <MatrixButton primary>Primary</MatrixButton>
                    <MatrixButton size="small">Small</MatrixButton>
                    <MatrixButton disabled>Disabled</MatrixButton>
                    <MatrixButton loading>Loading</MatrixButton>
                  </div>
                  <p className="text-caption text-matrix-muted">
                    Variants: default, primary, small, disabled, loading
                  </p>
                </div>
              </AsciiBox>
            </div>
          </div>
        </section>

        {/* Section: Clock */}
        <section>
          <h2 className="text-lg uppercase font-bold text-matrix-bright mb-4 border-b border-matrix-ghost pb-2">
            Matrix Clock
          </h2>

          <div className="grid grid-cols-12 gap-6">
            <div className="col-span-12 lg:col-span-4">
              <div
                className="matrix-panel p-6 flex justify-center relative overflow-hidden"
                style={{
                  backgroundImage: `
                    radial-gradient(circle at 20% 80%, rgba(0, 255, 65, 0.03) 0%, transparent 50%),
                    radial-gradient(circle at 80% 20%, rgba(0, 255, 65, 0.02) 0%, transparent 50%)
                  `,
                }}
              >
                <MatrixClock />
              </div>
            </div>
            <div className="col-span-12 lg:col-span-8">
              <AsciiBox title="Clock" subtitle="live">
                <p className="text-matrix-muted">
                  Real-time digital clock with Matrix styling. Features white glowing digits,
                  flip animation effect, and scanline texture overlay.
                </p>
              </AsciiBox>
            </div>
          </div>
        </section>

        {/* Section: Data Visualization */}
        <section>
          <h2 className="text-lg uppercase font-bold text-matrix-bright mb-4 border-b border-matrix-ghost pb-2">
            Data Visualization
          </h2>

          <div className="grid grid-cols-12 gap-6">
            {/* Heatmap */}
            <div className="col-span-12 lg:col-span-6">
              <RunHeatmap data={MOCK_HEATMAP} />
            </div>

            {/* Trend Chart */}
            <div className="col-span-12 lg:col-span-6">
              <TrendChart data={MOCK_TREND} />
            </div>
          </div>
        </section>

        {/* Section: Tables */}
        <section>
          <h2 className="text-lg uppercase font-bold text-matrix-bright mb-4 border-b border-matrix-ghost pb-2">
            Tables & Lists
          </h2>

          <div className="grid grid-cols-12 gap-6">
            {/* Task Schedule */}
            <div className="col-span-12 lg:col-span-5">
              <TaskSchedule
                tasks={MOCK_TASKS}
                loading={false}
                onTrigger={() => {}}
                triggerLoading={false}
              />
            </div>

            {/* Run History */}
            <div className="col-span-12 lg:col-span-7">
              <RunHistory
                runs={MOCK_RUNS}
                loading={false}
                page={page}
                totalPages={3}
                onPageChange={setPage}
                onSelectRun={(id) => {
                  if (id) setSelectedRun(MOCK_RUN_DETAIL);
                }}
              />
            </div>
          </div>
        </section>

        {/* Section: Colors & Typography */}
        <section>
          <h2 className="text-lg uppercase font-bold text-matrix-bright mb-4 border-b border-matrix-ghost pb-2">
            Colors & Typography
          </h2>

          <div className="grid grid-cols-12 gap-6">
            {/* Colors */}
            <div className="col-span-12 lg:col-span-6">
              <AsciiBox title="Colors" subtitle="palette">
                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-2">
                    <div className="flex items-center gap-2">
                      <span className="w-4 h-4 bg-matrix-primary rounded-sm"></span>
                      <span className="text-caption">Primary #00FF41</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <span className="w-4 h-4 bg-matrix-bright rounded-sm"></span>
                      <span className="text-caption">Bright #B0FFB0</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <span className="w-4 h-4 bg-matrix-muted rounded-sm"></span>
                      <span className="text-caption">Muted #00CC33</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <span className="w-4 h-4 bg-matrix-dim rounded-sm"></span>
                      <span className="text-caption">Dim #008822</span>
                    </div>
                  </div>
                  <div className="space-y-2">
                    <div className="flex items-center gap-2">
                      <span className="w-4 h-4 bg-success rounded-sm"></span>
                      <span className="text-caption">Success</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <span className="w-4 h-4 bg-error rounded-sm"></span>
                      <span className="text-caption">Error</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <span className="w-4 h-4 bg-warning rounded-sm"></span>
                      <span className="text-caption">Warning</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <span className="w-4 h-4 bg-matrix-panel border border-matrix-ghost rounded-sm"></span>
                      <span className="text-caption">Panel</span>
                    </div>
                  </div>
                </div>
              </AsciiBox>
            </div>

            {/* Typography */}
            <div className="col-span-12 lg:col-span-6">
              <AsciiBox title="Typography" subtitle="text styles">
                <div className="space-y-3">
                  <p className="text-2xl text-matrix-bright">Heading Large</p>
                  <p className="text-heading text-matrix-primary">Heading Default</p>
                  <p className="text-body text-matrix-primary">Body Text</p>
                  <p className="text-caption text-matrix-muted uppercase">Caption Uppercase</p>
                  <p className="text-caption text-matrix-dim">Caption Dim</p>
                  <p className="font-mono text-caption">Monospace: 0123456789</p>
                </div>
              </AsciiBox>
            </div>
          </div>
        </section>

        {/* Section: Status Indicators */}
        <section>
          <h2 className="text-lg uppercase font-bold text-matrix-bright mb-4 border-b border-matrix-ghost pb-2">
            Status Indicators
          </h2>

          <AsciiBox title="Status" subtitle="states">
            <div className="flex flex-wrap gap-6">
              <div className="flex items-center gap-2">
                <span className="w-2 h-2 bg-success rounded-full animate-pulse"></span>
                <span className="text-caption uppercase">Online</span>
              </div>
              <div className="flex items-center gap-2">
                <span className="w-2 h-2 bg-error rounded-full"></span>
                <span className="text-caption uppercase">Error</span>
              </div>
              <div className="flex items-center gap-2">
                <span className="w-2 h-2 bg-warning rounded-full"></span>
                <span className="text-caption uppercase">Warning</span>
              </div>
              <div className="flex items-center gap-2">
                <span className="w-2 h-2 bg-matrix-dim rounded-full"></span>
                <span className="text-caption uppercase">Offline</span>
              </div>
              <div className="flex items-center gap-2">
                <span className="animate-pulse text-matrix-primary">●</span>
                <span className="text-caption uppercase">Loading</span>
              </div>
              <div className="flex items-center gap-2">
                <span className="text-success">✓</span>
                <span className="text-caption uppercase">Success</span>
              </div>
              <div className="flex items-center gap-2">
                <span className="text-error">✗</span>
                <span className="text-caption uppercase">Failed</span>
              </div>
            </div>
          </AsciiBox>
        </section>

        {/* Section: Matrix Avatars */}
        <section>
          <h2 className="text-lg uppercase font-bold text-matrix-bright mb-4 border-b border-matrix-ghost pb-2">
            Matrix Avatars
          </h2>

          <AsciiBox title="MatrixAvatar" subtitle="procedural">
            <div className="flex flex-wrap gap-6 items-end">
              <div className="flex flex-col items-center gap-2">
                <MatrixAvatar name="neo" size={48} />
                <span className="text-caption text-matrix-muted">Normal</span>
              </div>
              <div className="flex flex-col items-center gap-2">
                <MatrixAvatar name="morpheus" size={48} />
                <span className="text-caption text-matrix-muted">morpheus</span>
              </div>
              <div className="flex flex-col items-center gap-2">
                <MatrixAvatar name="trinity" size={48} />
                <span className="text-caption text-matrix-muted">trinity</span>
              </div>
              <div className="flex flex-col items-center gap-2">
                <MatrixAvatar isAnon size={48} />
                <span className="text-caption text-matrix-muted">Anonymous</span>
              </div>
              <div className="flex flex-col items-center gap-2">
                <MatrixAvatar name="the_one" isTheOne size={48} />
                <span className="text-caption text-matrix-muted">The One</span>
              </div>
              <div className="flex flex-col items-center gap-2">
                <MatrixAvatar name="agent_smith" size={32} />
                <span className="text-caption text-matrix-muted">32px</span>
              </div>
              <div className="flex flex-col items-center gap-2">
                <MatrixAvatar name="oracle" size={64} />
                <span className="text-caption text-matrix-muted">64px</span>
              </div>
            </div>
          </AsciiBox>
        </section>

        {/* Section: Text Animations */}
        <section>
          <h2 className="text-lg uppercase font-bold text-matrix-bright mb-4 border-b border-matrix-ghost pb-2">
            Text Animations
          </h2>

          <div className="grid grid-cols-12 gap-6">
            <div className="col-span-12 lg:col-span-4">
              <AsciiBox title="ScrambleText" subtitle="effect">
                <div className="space-y-4">
                  <div className="text-matrix-primary text-heading">
                    <ScrambleText text="SYSTEM ONLINE" durationMs={1500} loop loopDelayMs={3000} />
                  </div>
                  <p className="text-caption text-matrix-muted">
                    Scrambles characters and reveals text progressively
                  </p>
                </div>
              </AsciiBox>
            </div>

            <div className="col-span-12 lg:col-span-4">
              <AsciiBox title="DecodingText" subtitle="effect">
                <div className="space-y-4">
                  <div className="text-matrix-primary text-heading">
                    <DecodingText text="ACCESS GRANTED" />
                  </div>
                  <p className="text-caption text-matrix-muted">
                    Simpler decode effect with random characters
                  </p>
                </div>
              </AsciiBox>
            </div>

            <div className="col-span-12 lg:col-span-4">
              <AsciiBox title="TypewriterText" subtitle="effect">
                <div className="space-y-4">
                  <div className="text-matrix-primary text-heading">
                    <TypewriterText text="WAKE UP, NEO..." speedMs={80} loop loopDelayMs={2000} />
                  </div>
                  <p className="text-caption text-matrix-muted">
                    Classic typewriter effect with cursor
                  </p>
                </div>
              </AsciiBox>
            </div>
          </div>
        </section>

        {/* Section: SignalBox & Input */}
        <section>
          <h2 className="text-lg uppercase font-bold text-matrix-bright mb-4 border-b border-matrix-ghost pb-2">
            Containers & Inputs
          </h2>

          <div className="grid grid-cols-12 gap-6">
            <div className="col-span-12 lg:col-span-6">
              <SignalBox title="TRANSMISSION">
                <p className="text-matrix-muted mb-4">
                  SignalBox is an alternative container with a decode title effect and dashed line decoration.
                </p>
                <div className="flex gap-2">
                  <MatrixButton size="small">Accept</MatrixButton>
                  <MatrixButton size="small">Decline</MatrixButton>
                </div>
              </SignalBox>
            </div>

            <div className="col-span-12 lg:col-span-6">
              <AsciiBox title="MatrixInput" subtitle="form">
                <div className="space-y-4">
                  <MatrixInput label="Username" placeholder="Enter your alias..." />
                  <MatrixInput label="Access Code" type="password" placeholder="••••••••" />
                  <p className="text-caption text-matrix-muted">
                    Styled input fields with labels
                  </p>
                </div>
              </AsciiBox>
            </div>
          </div>
        </section>

        {/* Section: Connection Status */}
        <section>
          <h2 className="text-lg uppercase font-bold text-matrix-bright mb-4 border-b border-matrix-ghost pb-2">
            Connection Status
          </h2>

          <AsciiBox title="ConnectionStatus" subtitle="indicator">
            <div className="flex flex-wrap gap-8">
              <div className="flex flex-col items-center gap-2">
                <ConnectionStatus status="STABLE" />
                <span className="text-caption text-matrix-muted">STABLE</span>
              </div>
              <div className="flex flex-col items-center gap-2">
                <ConnectionStatus status="UNSTABLE" />
                <span className="text-caption text-matrix-muted">UNSTABLE</span>
              </div>
              <div className="flex flex-col items-center gap-2">
                <ConnectionStatus status="LOST" />
                <span className="text-caption text-matrix-muted">LOST</span>
              </div>
            </div>
            <p className="text-caption text-matrix-muted mt-4">
              Binary indicator [0]/[1] for stable, [!] for unstable, [×] for lost
            </p>
          </AsciiBox>
        </section>

        {/* Section: Data Display */}
        <section>
          <h2 className="text-lg uppercase font-bold text-matrix-bright mb-4 border-b border-matrix-ghost pb-2">
            Data Display
          </h2>

          <div className="grid grid-cols-12 gap-6">
            <div className="col-span-12 lg:col-span-6">
              <AsciiBox title="DataRow" subtitle="key-value">
                <div className="space-y-0">
                  <DataRow label="Total Runs" value="1,247" />
                  <DataRow label="Success Rate" value="94.2%" valueClassName="text-success" />
                  <DataRow label="Avg Duration" value="45s" subValue="±12s" />
                  <DataRow label="Failed Today" value="3" valueClassName="text-error" />
                </div>
              </AsciiBox>
            </div>

            <div className="col-span-12 lg:col-span-6">
              <AsciiBox title="Sparkline" subtitle="mini chart">
                <div className="space-y-4">
                  <div className="flex items-center gap-4">
                    <span className="text-caption text-matrix-muted w-20">7 days:</span>
                    <Sparkline values={[12, 19, 15, 25, 22, 30, 28]} width={200} height={40} />
                  </div>
                  <div className="flex items-center gap-4">
                    <span className="text-caption text-matrix-muted w-20">Volatile:</span>
                    <Sparkline values={[5, 45, 12, 38, 8, 42, 15, 35]} width={200} height={40} />
                  </div>
                  <div className="flex items-center gap-4">
                    <span className="text-caption text-matrix-muted w-20">Trending:</span>
                    <Sparkline values={[10, 15, 18, 25, 30, 38, 45, 52]} width={200} height={40} />
                  </div>
                </div>
              </AsciiBox>
            </div>
          </div>
        </section>

        {/* Section: Leaderboard */}
        <section>
          <h2 className="text-lg uppercase font-bold text-matrix-bright mb-4 border-b border-matrix-ghost pb-2">
            Leaderboard
          </h2>

          <AsciiBox title="LeaderboardRow" subtitle="ranking">
            <div className="space-y-0">
              <LeaderboardRow rank={1} name="NEO" value={9999} isTheOne />
              <LeaderboardRow rank={2} name="MORPHEUS" value={8750} />
              <LeaderboardRow rank={3} name="TRINITY" value={8200} />
              <LeaderboardRow rank={4} name="TANK" value={6540} isSelf />
              <LeaderboardRow rank={5} name="UNKNOWN" value={5000} isAnon />
            </div>
          </AsciiBox>
        </section>

        {/* Section: Live Sniffer */}
        <section>
          <h2 className="text-lg uppercase font-bold text-matrix-bright mb-4 border-b border-matrix-ghost pb-2">
            Live Sniffer
          </h2>

          <AsciiBox title="LiveSniffer" subtitle="log stream">
            <div className="h-40">
              <LiveSniffer />
            </div>
            <p className="text-caption text-matrix-muted mt-4">
              Animated log stream with rotating messages
            </p>
          </AsciiBox>
        </section>

        {/* Section: Matrix Rain */}
        <section>
          <h2 className="text-lg uppercase font-bold text-matrix-bright mb-4 border-b border-matrix-ghost pb-2">
            Matrix Rain
          </h2>

          <AsciiBox title="MatrixRain" subtitle="background">
            <div className="relative h-48 overflow-hidden border border-matrix-ghost bg-matrix-dark">
              <MatrixRain />
              <div className="absolute inset-0 flex items-center justify-center">
                <span className="text-matrix-bright text-heading bg-matrix-dark/80 px-4 py-2">
                  CANVAS BACKGROUND EFFECT
                </span>
              </div>
            </div>
            <p className="text-caption text-matrix-muted mt-4">
              Falling digital rain effect rendered on canvas. Use as background overlay.
            </p>
          </AsciiBox>
        </section>

        {/* Section: Boot Screen */}
        <section>
          <h2 className="text-lg uppercase font-bold text-matrix-bright mb-4 border-b border-matrix-ghost pb-2">
            Boot Screen
          </h2>

          <AsciiBox title="BootScreen" subtitle="loading">
            <div className="h-64 overflow-hidden border border-matrix-ghost">
              <BootScreen />
            </div>
            <p className="text-caption text-matrix-muted mt-4">
              Full-screen boot/loading animation with ASCII art logo
            </p>
          </AsciiBox>
        </section>

        {/* ================================================================ */}
        {/* NEW COMPONENTS FROM VIBEUSAGE */}
        {/* ================================================================ */}

        {/* Section: Error Boundary */}
        <section>
          <h2 className="text-lg uppercase font-bold text-matrix-bright mb-4 border-b border-matrix-ghost pb-2">
            Error Boundary
          </h2>

          <AsciiBox title="ErrorBoundary" subtitle="safety">
            <div className="space-y-4">
              <p className="text-matrix-muted">
                React error boundary with Matrix styling. Catches render errors and displays a fallback UI.
              </p>
              <ErrorBoundary>
                <div className="p-4 border border-matrix-ghost">
                  <span className="text-success">✓</span> Protected content renders safely
                </div>
              </ErrorBoundary>
            </div>
          </AsciiBox>
        </section>

        {/* Section: Backend Status */}
        <section>
          <h2 className="text-lg uppercase font-bold text-matrix-bright mb-4 border-b border-matrix-ghost pb-2">
            Backend Status
          </h2>

          <AsciiBox title="BackendStatus" subtitle="indicator">
            <div className="flex flex-wrap gap-8">
              <div className="flex flex-col items-center gap-2">
                <BackendStatus status="active" />
                <span className="text-caption text-matrix-muted">ACTIVE</span>
              </div>
              <div className="flex flex-col items-center gap-2">
                <BackendStatus status="checking" />
                <span className="text-caption text-matrix-muted">CHECKING</span>
              </div>
              <div className="flex flex-col items-center gap-2">
                <BackendStatus status="down" />
                <span className="text-caption text-matrix-muted">DOWN</span>
              </div>
            </div>
            <p className="text-caption text-matrix-muted mt-4">
              Backend health indicator with color-coded status
            </p>
          </AsciiBox>
        </section>

        {/* Section: System Header */}
        <section>
          <h2 className="text-lg uppercase font-bold text-matrix-bright mb-4 border-b border-matrix-ghost pb-2">
            System Header
          </h2>

          <AsciiBox title="SystemHeader" subtitle="layout">
            <div className="space-y-4 border border-matrix-ghost p-4">
              <SystemHeader
                title="NEURAL MATRIX"
                signalLabel="v2.0.1"
                time="09:41:23"
              />
            </div>
            <p className="text-caption text-matrix-muted mt-4">
              System header with title, signal label, and time display
            </p>
          </AsciiBox>
        </section>

        {/* Section: Identity Components */}
        <section>
          <h2 className="text-lg uppercase font-bold text-matrix-bright mb-4 border-b border-matrix-ghost pb-2">
            Identity Components
          </h2>

          <div className="grid grid-cols-12 gap-6">
            <div className="col-span-12 lg:col-span-6">
              <AsciiBox title="IdentityPanel" subtitle="full">
                <IdentityPanel
                  name={MOCK_IDENTITY.name}
                  streakDays={42}
                  rankLabel="#7"
                />
              </AsciiBox>
            </div>

            <div className="col-span-12 lg:col-span-6">
              <AsciiBox title="IdentityCard" subtitle="compact">
                <div className="space-y-4">
                  <IdentityCard
                    name="MORPHEUS"
                    subtitle="Operator"
                    isPublic
                  />
                  <IdentityCard
                    name="TRINITY"
                    subtitle="Pilot"
                    isPublic
                  />
                  <IdentityCard
                    name="NEO"
                    subtitle="The One"
                    isPublic
                  />
                </div>
              </AsciiBox>
            </div>
          </div>
        </section>

        {/* Section: Top Models Panel */}
        <section>
          <h2 className="text-lg uppercase font-bold text-matrix-bright mb-4 border-b border-matrix-ghost pb-2">
            Top Models Panel
          </h2>

          <div className="grid grid-cols-12 gap-6">
            <div className="col-span-12 lg:col-span-6">
              <TopModelsPanel rows={MOCK_MODELS.map(m => ({ name: m.model, percent: String(m.percent) }))} />
            </div>

            <div className="col-span-12 lg:col-span-6">
              <AsciiBox title="Usage" subtitle="info">
                <p className="text-matrix-muted">
                  Displays AI model usage rankings with cost breakdown and percentage bars.
                  Perfect for showing which models consume the most resources.
                </p>
              </AsciiBox>
            </div>
          </div>
        </section>

        {/* Section: Leaderboard Panel */}
        <section>
          <h2 className="text-lg uppercase font-bold text-matrix-bright mb-4 border-b border-matrix-ghost pb-2">
            Leaderboard Panel
          </h2>

          <div className="grid grid-cols-12 gap-6">
            <div className="col-span-12 lg:col-span-6">
              <LeaderboardPanel
                title="TOP OPERATORS"
                rows={MOCK_LEADERBOARD}
              />
            </div>

            <div className="col-span-12 lg:col-span-6">
              <AsciiBox title="Features" subtitle="info">
                <ul className="space-y-2 text-matrix-muted">
                  <li>- Rank medals for top 3 positions</li>
                  <li>- "The One" special styling</li>
                  <li>- Self-highlight for current user</li>
                  <li>- Anonymous user display</li>
                </ul>
              </AsciiBox>
            </div>
          </div>
        </section>

        {/* Section: Usage Panel */}
        <section>
          <h2 className="text-lg uppercase font-bold text-matrix-bright mb-4 border-b border-matrix-ghost pb-2">
            Usage Panel
          </h2>

          <div className="grid grid-cols-12 gap-6">
            <div className="col-span-12 lg:col-span-8">
              <UsagePanel
                title="USAGE STATS"
                summaryLabel="TOTAL COST"
                summaryValue={`$${MOCK_USAGE_STATS.totalCost}`}
                useSummaryLayout
              />
            </div>

            <div className="col-span-12 lg:col-span-4">
              <AsciiBox title="Stats" subtitle="metrics">
                <p className="text-matrix-muted">
                  Displays key usage metrics: cost, tokens, requests, and latency.
                </p>
              </AsciiBox>
            </div>
          </div>
        </section>

        {/* Section: Neural Fleet & Divergence Map */}
        <section>
          <h2 className="text-lg uppercase font-bold text-matrix-bright mb-4 border-b border-matrix-ghost pb-2">
            Neural Fleet Visualization
          </h2>

          <div className="grid grid-cols-12 gap-6">
            <div className="col-span-12 lg:col-span-6">
              <AsciiBox title="NeuralAdaptiveFleet" subtitle="bar chart">
                <NeuralAdaptiveFleet
                  label="ANTHROPIC"
                  totalPercent={65}
                  usage={812500}
                  models={[
                    { name: "claude-4-sonnet", share: 45 },
                    { name: "claude-4-haiku", share: 20 },
                  ]}
                />
              </AsciiBox>
            </div>

            <div className="col-span-12 lg:col-span-6">
              <NeuralDivergenceMap
                fleetData={[
                  {
                    label: "ANTHROPIC",
                    totalPercent: 65,
                    usage: 812500,
                    models: [
                      { name: "claude-4-sonnet", share: 45 },
                      { name: "claude-4-haiku", share: 20 },
                    ],
                  },
                  {
                    label: "OPENAI",
                    totalPercent: 35,
                    usage: 437500,
                    models: [
                      { name: "gpt-4o", share: 25 },
                      { name: "gpt-4o-mini", share: 10 },
                    ],
                  },
                ]}
              />
            </div>
          </div>
        </section>

        {/* Section: TrendMonitor */}
        <section>
          <h2 className="text-lg uppercase font-bold text-matrix-bright mb-4 border-b border-matrix-ghost pb-2">
            Trend Monitor
          </h2>

          <div className="grid grid-cols-12 gap-6">
            <div className="col-span-12">
              <TrendMonitor
                label="DAILY OPERATIONS"
                data={MOCK_TREND_MONITOR_DATA.map(d => d.value)}
              />
            </div>
          </div>
        </section>

        {/* Section: Activity Heatmap */}
        <section>
          <h2 className="text-lg uppercase font-bold text-matrix-bright mb-4 border-b border-matrix-ghost pb-2">
            Activity Heatmap
          </h2>

          <div className="grid grid-cols-12 gap-6">
            <div className="col-span-12">
              <AsciiBox title="ActivityHeatmap" subtitle="yearly">
                <ActivityHeatmap
                  heatmap={{
                    weeks: Array.from({ length: 12 }, (_, weekIdx) =>
                      Array.from({ length: 7 }, (_, dayIdx) => ({
                        day: `2026-01-${String(weekIdx * 7 + dayIdx + 1).padStart(2, "0")}`,
                        value: Math.floor(Math.random() * 100),
                        level: Math.floor(Math.random() * 5),
                      }))
                    ),
                    to: "2026-01-24",
                    week_starts_on: "mon",
                  }}
                />
                <p className="text-caption text-matrix-muted mt-4">
                  GitHub-style yearly activity heatmap (52 weeks × 7 days)
                </p>
              </AsciiBox>
            </div>
          </div>
        </section>

        {/* Section: GitHub Star & Upgrade Alert */}
        <section>
          <h2 className="text-lg uppercase font-bold text-matrix-bright mb-4 border-b border-matrix-ghost pb-2">
            Misc Components
          </h2>

          <div className="grid grid-cols-12 gap-6">
            <div className="col-span-12 lg:col-span-4">
              <AsciiBox title="GithubStar" subtitle="button">
                <div className="flex justify-center py-4">
                  <GithubStar repo="anomalyco/runner" />
                </div>
              </AsciiBox>
            </div>

            <div className="col-span-12 lg:col-span-8">
              <AsciiBox title="UpgradeAlertModal" subtitle="banner">
                <UpgradeAlertModal
                  requiredVersion="2.1.0"
                  installCommand="npm install -g runner@latest"
                  onClose={() => {}}
                />
              </AsciiBox>
            </div>
          </div>
        </section>

        {/* Section: Cost Analysis Modal */}
        <section>
          <h2 className="text-lg uppercase font-bold text-matrix-bright mb-4 border-b border-matrix-ghost pb-2">
            Cost Analysis Modal
          </h2>

          <AsciiBox title="CostAnalysisModal" subtitle="breakdown">
            <div className="space-y-4">
              <p className="text-matrix-muted">
                Modal for displaying detailed cost breakdown by category.
              </p>
              <MatrixButton onClick={() => setShowCostModal(true)}>
                Open Cost Analysis
              </MatrixButton>
            </div>
          </AsciiBox>
        </section>

        {/* ================================================================ */}
        {/* LAYOUT EXAMPLES FROM VIBEUSAGE */}
        {/* ================================================================ */}

        {/* Section: TrendChart (Simple Bar Chart) */}
        <section>
          <h2 className="text-lg uppercase font-bold text-matrix-bright mb-4 border-b border-matrix-ghost pb-2">
            Trend Chart (Simple)
          </h2>

          <div className="grid grid-cols-12 gap-6">
            <div className="col-span-12 lg:col-span-8">
              <AsciiBox title="SimpleTrendChart" subtitle="bar chart">
                <SimpleTrendChart
                  data={[20, 45, 32, 67, 89, 54, 42, 78, 65, 91, 38, 55]}
                  unitLabel="tokens"
                  leftLabel="12 DAYS AGO"
                  rightLabel="TODAY"
                />
              </AsciiBox>
            </div>

            <div className="col-span-12 lg:col-span-4">
              <AsciiBox title="Usage" subtitle="info">
                <p className="text-matrix-muted">
                  Simple bar chart for trend visualization. Shows values over time with peak detection.
                </p>
              </AsciiBox>
            </div>
          </div>
        </section>

        {/* Section: Dashboard Layout Example */}
        <section>
          <h2 className="text-lg uppercase font-bold text-matrix-bright mb-4 border-b border-matrix-ghost pb-2">
            Dashboard Layout Example
          </h2>

          <AsciiBox title="DashboardViewExample" subtitle="full layout">
            <p className="text-matrix-muted mb-4">
              Complete dashboard layout ported from vibeusage. Features 12-column grid with
              sidebar (4 cols) and main content (8 cols). Includes identity card, top models,
              trend monitor, usage panel, and detailed breakdown table.
            </p>
            <div className="border border-matrix-ghost overflow-hidden">
              <DashboardViewExample />
            </div>
          </AsciiBox>
        </section>

        {/* Section: Landing Layout Example */}
        <section>
          <h2 className="text-lg uppercase font-bold text-matrix-bright mb-4 border-b border-matrix-ghost pb-2">
            Landing Layout Example
          </h2>

          <AsciiBox title="LandingViewExample" subtitle="full layout">
            <p className="text-matrix-muted mb-4">
              Landing page layout ported from vibeusage. Features hero section with animated text,
              identity probe demo, live sniffer, feature highlights, and CTA buttons.
            </p>
            <div className="border border-matrix-ghost overflow-hidden">
              <LandingViewExample />
            </div>
          </AsciiBox>
        </section>
      </div>

      {/* Run Detail Modal */}
      <RunDetailModal
        run={selectedRun}
        loading={false}
        output={selectedRun ? "Sample output for demo purposes" : null}
        outputLoading={false}
        outputError={null}
        onClose={() => setSelectedRun(null)}
      />

      {/* Cost Analysis Modal */}
      <CostAnalysisModal
        isOpen={showCostModal}
        onClose={() => setShowCostModal(false)}
        fleetData={MOCK_FLEET_DATA}
      />
    </MatrixShell>
  );
}
