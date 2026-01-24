// ============================================
// Layout Examples - Ported from vibeusage
// DashboardView and LandingView showcase layouts
// All data is replaced with mock data for demonstration
// ============================================

import { useState, Suspense } from "react";
import { AsciiBox } from "./AsciiBox";
import { MatrixButton } from "./MatrixButton";
import { MatrixShell } from "./MatrixShell";
import {
  DecodingText,
  MatrixRain,
} from "./MatrixExtras";
import {
  IdentityCard,
  TopModelsPanel,
  UsagePanel,
  NeuralDivergenceMap,
  LandingExtras,
  GithubStar,
  CostAnalysisModal,
} from "./VibeComponents";
import { TrendMonitor, ActivityHeatmap } from "./DataVizComponents";

// ============================================
// Mock Data for Layout Examples
// ============================================

const MOCK_TOP_MODELS = [
  { id: "1", name: "claude-4-sonnet", percent: "45" },
  { id: "2", name: "gpt-4o", percent: "32" },
  { id: "3", name: "claude-4-haiku", percent: "23" },
];

const MOCK_TREND_ROWS = Array.from({ length: 24 }, (_, i) => ({
  hour: `${String(i).padStart(2, "0")}:00`,
  total_tokens: Math.floor(Math.random() * 50000) + 10000,
  missing: false,
  future: i > 18,
}));

const MOCK_USAGE_METRICS = [
  { label: "Total Tokens", value: "1.25M" },
  { label: "Input Tokens", value: "750K" },
  { label: "Output Tokens", value: "500K" },
  { label: "Cache Hits", value: "45%" },
];

const MOCK_FLEET_DATA = [
  {
    label: "ANTHROPIC",
    totalPercent: 65,
    usage: 812500,
    models: [
      { id: "1", name: "claude-4-sonnet", share: 45 },
      { id: "2", name: "claude-4-haiku", share: 20 },
    ],
  },
  {
    label: "OPENAI",
    totalPercent: 35,
    usage: 437500,
    models: [
      { id: "3", name: "gpt-4o", share: 25 },
      { id: "4", name: "gpt-4o-mini", share: 10 },
    ],
  },
];

const MOCK_ACTIVITY_HEATMAP = {
  weeks: Array.from({ length: 12 }, (_, weekIdx) =>
    Array.from({ length: 7 }, (_, dayIdx) => ({
      day: `2026-01-${String(weekIdx * 7 + dayIdx + 1).padStart(2, "0")}`,
      value: Math.floor(Math.random() * 100),
      level: Math.floor(Math.random() * 5),
    }))
  ),
  to: "2026-01-24",
  week_starts_on: "mon" as const,
};

const MOCK_DETAILS_DATA = [
  { day: "2026-01-24", total_tokens: 125000, input_tokens: 75000, output_tokens: 50000, cached_input_tokens: 15000, reasoning_output_tokens: 8000 },
  { day: "2026-01-23", total_tokens: 98000, input_tokens: 58000, output_tokens: 40000, cached_input_tokens: 12000, reasoning_output_tokens: 6000 },
  { day: "2026-01-22", total_tokens: 145000, input_tokens: 85000, output_tokens: 60000, cached_input_tokens: 20000, reasoning_output_tokens: 10000 },
  { day: "2026-01-21", total_tokens: 87000, input_tokens: 52000, output_tokens: 35000, cached_input_tokens: 8000, reasoning_output_tokens: 5000 },
  { day: "2026-01-20", total_tokens: 112000, input_tokens: 67000, output_tokens: 45000, cached_input_tokens: 14000, reasoning_output_tokens: 7000 },
];

// ============================================
// DashboardView - Full dashboard layout example
// ============================================

interface DashboardViewExampleProps {
  className?: string;
}

export function DashboardViewExample({ className = "" }: DashboardViewExampleProps) {
  const [costModalOpen, setCostModalOpen] = useState(false);
  const [period, setPeriod] = useState<"day" | "week" | "month" | "total">("day");

  const periods = [
    { key: "day", label: "TODAY" },
    { key: "week", label: "WEEK" },
    { key: "month", label: "MONTH" },
    { key: "total", label: "ALL TIME" },
  ];

  return (
    <div className={className}>
      <MatrixShell
        hideHeader={false}
        headerStatus={<span className="text-success animate-pulse">CONNECTED</span>}
        headerRight={
          <span className="text-caption text-matrix-muted uppercase">
            Dashboard Example
          </span>
        }
        footerLeft={<span>SYSTEM OPERATIONAL</span>}
        footerRight={<span className="font-bold">vibeusage</span>}
      >
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
          {/* Left Column - 4 cols */}
          <div className="lg:col-span-4 flex flex-col gap-6 min-w-0">
            <IdentityCard
              title="IDENTITY"
              subtitle="authenticated"
              name="NEO"
              avatarUrl={undefined}
              isPublic
              rankLabel="2026-01-01"
              streakDays={42}
              animateTitle={false}
            />

            <TopModelsPanel rows={MOCK_TOP_MODELS} />

            <TrendMonitor
              rows={MOCK_TREND_ROWS}
              from="00:00"
              to="23:00"
              period={period}
              timeZoneLabel="UTC+8"
              showTimeZoneLabel={false}
              className="h-auto min-h-[280px]"
            />

            <AsciiBox title="ACTIVITY" subtitle="heatmap">
              <ActivityHeatmap
                heatmap={MOCK_ACTIVITY_HEATMAP}
                timeZoneLabel="UTC+8"
                timeZoneShortLabel="CST"
              />
            </AsciiBox>
          </div>

          {/* Right Column - 8 cols */}
          <div className="lg:col-span-8 flex flex-col gap-6 min-w-0">
            <UsagePanel
              title="USAGE STATS"
              period={period}
              periods={periods}
              onPeriodChange={(p) => setPeriod(p as typeof period)}
              metrics={MOCK_USAGE_METRICS}
              showSummary={period === "total"}
              useSummaryLayout
              summaryLabel="TOTAL OUTPUT"
              summaryValue="1,250,000"
              summaryCostValue="$279.80"
              onCostInfo={() => setCostModalOpen(true)}
              loading={false}
            />

            <NeuralDivergenceMap
              fleetData={MOCK_FLEET_DATA}
              className="min-w-0"
              footer={undefined}
            />

            <AsciiBox title="DAILY BREAKDOWN" subtitle="detailed">
              <div className="overflow-auto max-h-[320px] border border-matrix-ghost/10">
                <table className="w-full border-collapse">
                  <thead className="sticky top-0 bg-black/90">
                    <tr className="border-b border-matrix-ghost/10">
                      <th className="text-left px-3 py-2 text-caption uppercase tracking-widest font-black opacity-70">Date</th>
                      <th className="text-left px-3 py-2 text-caption uppercase tracking-widest font-black opacity-70">Total</th>
                      <th className="text-left px-3 py-2 text-caption uppercase tracking-widest font-black opacity-70">Input</th>
                      <th className="text-left px-3 py-2 text-caption uppercase tracking-widest font-black opacity-70">Output</th>
                      <th className="text-left px-3 py-2 text-caption uppercase tracking-widest font-black opacity-70">Cached</th>
                      <th className="text-left px-3 py-2 text-caption uppercase tracking-widest font-black opacity-70">Reasoning</th>
                    </tr>
                  </thead>
                  <tbody>
                    {MOCK_DETAILS_DATA.map((row) => (
                      <tr key={row.day} className="border-b border-matrix-ghost/5 hover:bg-matrix-ghost/5">
                        <td className="px-3 py-2 text-body opacity-80 font-mono">{row.day}</td>
                        <td className="px-3 py-2 text-body font-mono">{row.total_tokens.toLocaleString()}</td>
                        <td className="px-3 py-2 text-body font-mono">{row.input_tokens.toLocaleString()}</td>
                        <td className="px-3 py-2 text-body font-mono">{row.output_tokens.toLocaleString()}</td>
                        <td className="px-3 py-2 text-body font-mono">{row.cached_input_tokens.toLocaleString()}</td>
                        <td className="px-3 py-2 text-body font-mono">{row.reasoning_output_tokens.toLocaleString()}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              <div className="flex items-center justify-between mt-3 text-caption uppercase tracking-widest font-black">
                <MatrixButton type="button" disabled>PREV</MatrixButton>
                <span className="opacity-50">Page 1 of 1</span>
                <MatrixButton type="button" disabled>NEXT</MatrixButton>
              </div>
            </AsciiBox>
          </div>
        </div>
      </MatrixShell>

      <CostAnalysisModal
        isOpen={costModalOpen}
        onClose={() => setCostModalOpen(false)}
        fleetData={MOCK_FLEET_DATA.map((f) => ({
          label: f.label,
          usd: f.usage * 0.00025,
          models: f.models.map((m) => ({
            id: m.id,
            name: m.name,
            share: m.share,
            calc: "API",
          })),
        }))}
      />
    </div>
  );
}

// ============================================
// LandingView - Landing page layout example
// ============================================

interface LandingViewExampleProps {
  className?: string;
}

export function LandingViewExample({ className = "" }: LandingViewExampleProps) {
  const [handle, setHandle] = useState("NEO");
  const [effectsReady] = useState(true);

  return (
    <div className={`min-h-[600px] bg-matrix-dark font-matrix text-matrix-primary text-body flex flex-col items-center justify-center p-6 relative overflow-hidden ${className}`}>
      {/* Matrix Rain Background */}
      {effectsReady && (
        <div className="absolute inset-0 pointer-events-none opacity-30">
          <Suspense fallback={null}>
            <MatrixRain />
          </Suspense>
        </div>
      )}

      {/* Header Actions */}
      <div className="absolute top-6 right-6 z-[70] flex flex-col items-end space-y-3 sm:flex-row sm:items-center sm:space-y-0 sm:space-x-3">
        <GithubStar isFixed={false} size="header" repo="example/vibeusage" />
        <MatrixButton
          as="a"
          href="#"
          size="header"
          className="matrix-header-action--ghost"
        >
          <span className="font-matrix font-black text-caption tracking-[0.12em] text-matrix-primary">
            LOGIN
          </span>
        </MatrixButton>
        <MatrixButton
          as="a"
          href="#"
          size="header"
          className="matrix-header-chip--solid"
        >
          <span className="font-matrix font-black text-caption tracking-[0.12em] text-black">
            SIGN UP
          </span>
        </MatrixButton>
      </div>

      {/* Scanline Overlay */}
      <div className="pointer-events-none absolute inset-0 z-50 bg-[linear-gradient(rgba(18,16,16,0)_50%,rgba(0,0,0,0.1)_50%)] bg-[length:100%_4px]"></div>

      {/* Main Content */}
      <main className="w-full max-w-4xl relative z-10 flex flex-col items-center space-y-12 py-10">
        {/* Hero Section */}
        <div className="text-center space-y-6">
          <h1 className="text-5xl md:text-8xl font-black text-white tracking-tighter leading-none glow-text select-none">
            <DecodingText text="TRACK YOUR" /> <br />
            <span className="text-matrix-primary">
              <DecodingText text="TOKEN USAGE" />
            </span>
          </h1>

          <div className="flex flex-col items-center space-y-2">
            <div className="px-6 py-3 border border-matrix-ghost bg-matrix-panel relative group">
              <div className="absolute top-0 left-0 w-2 h-2 border-t border-l border-matrix-primary"></div>
              <div className="absolute bottom-0 right-0 w-2 h-2 border-b border-r border-matrix-primary"></div>
              <p className="text-caption uppercase font-bold text-matrix-bright">
                Real-time AI usage monitoring
              </p>
            </div>
            <p className="text-caption text-matrix-muted uppercase">
              Claude, GPT-4, and more
            </p>
          </div>
        </div>

        {/* Demo Section */}
        <LandingExtras
          handle={handle}
          onHandleChange={(e) => setHandle(e.target.value)}
          specialHandle="NEO"
          handlePlaceholder="Enter handle..."
          rankLabel="Rank: #42 of 1,247"
        />

        {/* Screenshot Section */}
        <section className="w-full max-w-4xl border border-matrix-ghost bg-matrix-panel p-4">
          <div className="relative overflow-hidden border border-matrix-dim bg-black/60 shadow-[0_0_30px_rgba(0,255,65,0.15)]">
            <div className="w-full h-48 bg-matrix-panelStrong flex items-center justify-center">
              <span className="text-matrix-muted text-caption uppercase">
                [Dashboard Screenshot Placeholder]
              </span>
            </div>
            <div className="pointer-events-none absolute inset-0 bg-[linear-gradient(120deg,rgba(0,255,65,0.08),rgba(0,0,0,0)_40%)]"></div>
          </div>
        </section>

        {/* Features Section */}
        <section className="w-full max-w-3xl border border-matrix-ghost bg-matrix-panel px-6 py-6 space-y-4">
          <h2 className="text-2xl md:text-3xl font-bold text-matrix-bright tracking-tight">
            Why VibeUsage?
          </h2>
          <p className="text-body text-matrix-muted">
            Monitor your AI token consumption across all major providers in one dashboard.
          </p>
          <ul className="space-y-2 text-body text-matrix-muted">
            <li className="flex gap-2">
              <span className="text-matrix-primary">-</span>
              <span>Real-time usage tracking</span>
            </li>
            <li className="flex gap-2">
              <span className="text-matrix-primary">-</span>
              <span>Cost estimation and alerts</span>
            </li>
            <li className="flex gap-2">
              <span className="text-matrix-primary">-</span>
              <span>Multi-provider support</span>
            </li>
          </ul>
          <p className="text-caption text-matrix-dim uppercase">
            More features coming soon
          </p>
        </section>

        {/* CTA Section */}
        <div className="w-full max-w-sm flex flex-col items-center space-y-4">
          <a
            href="#"
            className="w-full text-center text-black bg-matrix-primary font-black uppercase tracking-[0.3em] py-4 hover:bg-white transition-colors"
          >
            GET STARTED
          </a>
          <a
            href="#"
            className="w-full text-center text-matrix-primary border border-matrix-primary font-black uppercase tracking-[0.3em] py-4 hover:bg-matrix-primary/10 transition-colors"
          >
            SIGN IN
          </a>
        </div>
      </main>
    </div>
  );
}
