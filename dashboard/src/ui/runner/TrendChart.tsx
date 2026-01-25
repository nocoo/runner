// ============================================
// Trend Chart - Smooth curve visualization
// Based on vibeusage TrendMonitor pattern
// ============================================

import { useMemo, useRef, useState, useEffect } from "react";
import type { TrendPoint } from "@/models/types";
import { AsciiBox } from "@/ui/foundation";

interface TrendChartProps {
  data: TrendPoint[];
}

const COLOR = "#00FF41";

// 中文时辰对照表
const SHICHEN: Record<number, string> = {
  23: "子", 0: "子",
  1: "丑", 2: "丑",
  3: "寅", 4: "寅",
  5: "卯", 6: "卯",
  7: "辰", 8: "辰",
  9: "巳", 10: "巳",
  11: "午", 12: "午",
  13: "未", 14: "未",
  15: "申", 16: "申",
  17: "酉", 18: "酉",
  19: "戌", 20: "戌",
  21: "亥", 22: "亥",
};

function getShichen(hour: number): string {
  return SHICHEN[hour] || "";
}

function formatTime(dateStr: string): string {
  const match = dateStr.match(/(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})/);
  if (match) {
    return `${match[4]}:${match[5]}`;
  }
  return dateStr;
}

function getHourFromDate(dateStr: string): number {
  const match = dateStr.match(/T(\d{2}):/);
  return match ? parseInt(match[1], 10) : 0;
}

export function TrendChart({ data }: TrendChartProps) {
  const plotRef = useRef<HTMLDivElement>(null);

  const [hover, setHover] = useState<{
    index: number;
    value: number;
    successRate: number;
    label: string;
    x: number;
    y: number;
  } | null>(null);

  const width = 100;
  const height = 100;
  const plotTop = 8;
  const plotBottom = 8;
  const plotHeight = height - plotTop - plotBottom;
  const pointCount = Math.max(data.length, 1);
  const xPadding = pointCount > 1 ? width * 0.02 : width / 2;
  const plotSpan = Math.max(width - xPadding * 2, 0);
  const step = pointCount > 1 ? plotSpan / (pointCount - 1) : 0;

  const values = data.map((d) => d.total);
  const max = Math.max(...values, 1);
  const avg = values.length ? values.reduce((a, b) => a + b, 0) / values.length : 0;
  const total = values.reduce((a, b) => a + b, 0);

  // Build points for curve
  const points = useMemo(() => {
    return data.map((point, i) => {
      const x = pointCount > 1 ? xPadding + i * step : width / 2;
      const normalizedVal = max > 0 ? point.total / max : 0;
      const y = plotTop + (1 - normalizedVal) * plotHeight;
      return { x, y, index: i, value: point.total };
    });
  }, [data, max, plotHeight, plotTop, pointCount, step, xPadding]);

  // Smooth Bezier path
  function solveSmoothPath(pts: Array<{ x: number; y: number }>): string {
    if (!pts.length) return "";
    if (pts.length === 1) return `M ${pts[0].x},${pts[0].y}`;
    if (pts.length === 2) return `M ${pts[0].x},${pts[0].y} L ${pts[1].x},${pts[1].y}`;

    let d = `M ${pts[0].x},${pts[0].y}`;
    for (let i = 0; i < pts.length - 1; i++) {
      const p0 = pts[Math.max(i - 1, 0)];
      const p1 = pts[i];
      const p2 = pts[i + 1];
      const p3 = pts[Math.min(i + 2, pts.length - 1)];

      const cp1x = p1.x + (p2.x - p0.x) * 0.16;
      const cp1y = p1.y + (p2.y - p0.y) * 0.16;
      const cp2x = p2.x - (p3.x - p1.x) * 0.16;
      const cp2y = p2.y - (p3.y - p1.y) * 0.16;

      d += ` C ${cp1x},${cp1y} ${cp2x},${cp2y} ${p2.x},${p2.y}`;
    }
    return d;
  }

  const linePath = useMemo(() => solveSmoothPath(points), [points]);
  const fillPath = useMemo(() => {
    if (points.length < 2) return "";
    const first = points[0];
    const last = points[points.length - 1];
    return `${linePath} L ${last.x},${height - plotBottom} L ${first.x},${height - plotBottom} Z`;
  }, [linePath, points, height, plotBottom]);

  // X-axis labels - Chinese 时辰
  const xLabels = useMemo(() => {
    if (data.length === 0) return [];
    const labels: string[] = [];
    const seenShichen = new Set<string>();
    
    for (let i = 0; i < data.length; i += 12) {
      const hour = getHourFromDate(data[i].date);
      const shichen = getShichen(hour);
      if (shichen && !seenShichen.has(shichen)) {
        labels.push(shichen);
        seenShichen.add(shichen);
      }
    }
    return labels;
  }, [data]);

  // Mouse move handler
  function handleMove(e: React.MouseEvent) {
    const el = plotRef.current;
    if (!el || data.length === 0) return;
    const rect = el.getBoundingClientRect();
    const rawX = Math.min(Math.max(e.clientX - rect.left, 0), rect.width);
    const xPaddingPx = (xPadding / width) * rect.width;
    const plotSpanPx = rect.width - xPaddingPx * 2;
    const denom = Math.max(data.length - 1, 1);
    const clamped = Math.min(Math.max(rawX - xPaddingPx, 0), plotSpanPx);
    const ratio = plotSpanPx > 0 ? clamped / plotSpanPx : 0;
    const index = Math.round(ratio * denom);
    
    const point = data[index];
    if (!point) return;
    
    const snappedX = denom > 0 ? xPaddingPx + (index / denom) * plotSpanPx : rect.width / 2;
    const yRatio = max > 0 ? 1 - point.total / max : 1;
    const yPx = (plotTop / height) * rect.height + yRatio * (plotHeight / height) * rect.height;

    setHover({
      index,
      value: point.total,
      successRate: point.successRate,
      label: formatTime(point.date),
      x: snappedX,
      y: yPx,
    });
  }

  if (data.length === 0) {
    return (
      <AsciiBox title="Trend" subtitle="no data">
        <div className="h-32 flex items-center justify-center text-matrix-dim">
          No trend data available
        </div>
      </AsciiBox>
    );
  }

  return (
    <AsciiBox title="Trend" subtitle="24h">
      {/* Stats header */}
      <div className="flex items-center justify-between text-caption text-matrix-muted px-1 mb-3">
        <div className="flex gap-3">
          <span>TOTAL: {total}</span>
          <span>MAX: {Math.round(max)}</span>
          <span>AVG: {avg.toFixed(1)}</span>
        </div>
      </div>

      {/* Chart area */}
      <div className="relative overflow-hidden border border-matrix-ghost bg-matrix-panel h-40">
        {/* Grid background */}
        <div
          className="absolute inset-0 opacity-10 pointer-events-none"
          style={{
            backgroundImage: `
              linear-gradient(to right, ${COLOR} 1px, transparent 1px),
              linear-gradient(to bottom, ${COLOR} 1px, transparent 1px)
            `,
            backgroundSize: "20px 20px",
          }}
        />

        {/* Scan animation */}
        <div 
          className="absolute inset-0 pointer-events-none mix-blend-screen"
          style={{
            background: `linear-gradient(to right, transparent, rgba(0,255,65,0.1), transparent)`,
            animation: "scan-x 3s linear infinite",
          }}
        />

        {/* SVG Chart */}
        <svg
          viewBox={`0 0 ${width} ${height}`}
          className="w-full h-full absolute inset-0 z-10"
          preserveAspectRatio="none"
        >
          <defs>
            <linearGradient id="trend-grad" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor={COLOR} stopOpacity="0.5" />
              <stop offset="100%" stopColor={COLOR} stopOpacity="0" />
            </linearGradient>
          </defs>

          {/* Fill area */}
          {fillPath && <path d={fillPath} fill="url(#trend-grad)" />}
          
          {/* Line */}
          {linePath && (
            <path
              d={linePath}
              fill="none"
              stroke={COLOR}
              strokeWidth="1.5"
              vectorEffect="non-scaling-stroke"
              className="drop-shadow-[0_0_5px_rgba(0,255,65,0.8)]"
            />
          )}
        </svg>

        {/* Hover interaction layer */}
        <div
          ref={plotRef}
          className="absolute inset-0 z-20"
          onMouseMove={handleMove}
          onMouseLeave={() => setHover(null)}
        />

        {/* Hover tooltip */}
        {hover && (
          <>
            {/* Vertical line */}
            <div className="absolute inset-y-0 left-0 pointer-events-none z-25">
              <div
                className="absolute top-0 bottom-0 w-px bg-[#00FF41]/40 shadow-[0_0_6px_rgba(0,255,65,0.35)]"
                style={{ left: hover.x }}
              />
              <div
                className="absolute w-2 h-2 rounded-full bg-[#00FF41] shadow-[0_0_6px_rgba(0,255,65,0.8)]"
                style={{ left: hover.x - 4, top: hover.y - 4 }}
              />
            </div>

            {/* Tooltip */}
            <div
              className="absolute z-30 px-3 py-2 text-caption bg-matrix-panelStrong border border-matrix-ghost text-matrix-bright pointer-events-none"
              style={{
                left: Math.min(hover.x + 10, plotRef.current?.clientWidth ? plotRef.current.clientWidth - 100 : hover.x),
                top: Math.max(hover.y - 24, 6),
              }}
            >
              <div className="text-matrix-muted">{hover.label}</div>
              <div className="font-bold">{hover.value} runs</div>
              <div className="text-matrix-dim">{Math.round(hover.successRate * 100)}% success</div>
            </div>
          </>
        )}
      </div>

      {/* X-axis labels */}
      <div className="h-5 flex justify-between items-center px-1 text-caption text-matrix-muted border-t border-matrix-ghost pt-2 mt-2">
        {xLabels.map((label, idx) => (
          <span key={`${label}-${idx}`}>{label}</span>
        ))}
      </div>

      {/* Scan animation keyframes */}
      <style>{`
        @keyframes scan-x {
          0% { transform: translateX(-100%); }
          100% { transform: translateX(200%); }
        }
      `}</style>
    </AsciiBox>
  );
}
