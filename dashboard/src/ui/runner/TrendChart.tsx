// ============================================
// Trend Monitor - Industrial TUI style chart
// Based on vibeusage TrendMonitor pattern
// ============================================

import { useMemo, useRef, useState, useEffect } from "react";
import type { TrendPoint } from "@/models/types";
import { AsciiBox } from "@/ui/foundation";

interface TrendChartProps {
  data: TrendPoint[];
}

const COLOR = "#00FF41";

function formatCompact(value: number): string {
  const abs = Math.abs(value);
  if (abs >= 1000) {
    return `${(value / 1000).toFixed(1)}K`;
  }
  return String(Math.round(value));
}

function formatDate(dateStr: string): string {
  // Check if it's an hour format (HH:00)
  if (/^\d{2}:00$/.test(dateStr)) {
    return dateStr;
  }
  const date = new Date(dateStr);
  const month = (date.getMonth() + 1).toString().padStart(2, "0");
  const day = date.getDate().toString().padStart(2, "0");
  return `${month}-${day}`;
}

export function TrendChart({ data }: TrendChartProps) {
  const plotRef = useRef<HTMLDivElement>(null);
  const axisRef = useRef<HTMLDivElement>(null);

  const [hover, setHover] = useState<{
    index: number;
    value: number;
    successRate: number;
    label: string;
    x: number;
    y: number;
    rectWidth: number;
    axisWidthPx: number;
  } | null>(null);

  const [axisWidthView, setAxisWidthView] = useState(8);

  const width = 100;
  const height = 100;
  const plotWidth = width - axisWidthView;
  const pointCount = Math.max(data.length, 1);
  const xPadding = pointCount > 1 ? plotWidth * 0.05 : plotWidth / 2;
  const plotSpan = Math.max(plotWidth - xPadding * 2, 0);
  const stepWithPadding = pointCount > 1 ? plotSpan / (pointCount - 1) : 0;
  const plotTop = 8;
  const plotBottom = 8;
  const plotHeight = height - plotTop - plotBottom;

  const values = data.map((d) => d.total);
  const max = Math.max(...values, 1);
  const avg = values.length ? values.reduce((a, b) => a + b, 0) / values.length : 0;

  // Build line segments
  const lineSegments = useMemo(() => {
    const segments: Array<Array<{ x: number; y: number; index: number; value: number }>> = [];
    let current: Array<{ x: number; y: number; index: number; value: number }> = [];

    data.forEach((point, i) => {
      const val = point.total;
      const x = pointCount > 1 ? xPadding + i * stepWithPadding : plotWidth / 2;
      const normalizedVal = max > 0 ? val / max : 0;
      const y = plotTop + (1 - normalizedVal) * plotHeight;
      current.push({ x, y, index: i, value: val });
    });

    if (current.length) segments.push(current);
    return segments;
  }, [data, max, plotHeight, plotTop, plotWidth, pointCount, stepWithPadding, xPadding]);

  // Smooth Bezier path
  function solveSmoothPath(points: Array<{ x: number; y: number }>): string {
    if (!points.length) return "";
    if (points.length === 1) {
      return `M ${points[0].x},${points[0].y}`;
    }
    if (points.length === 2) {
      return `M ${points[0].x},${points[0].y} L ${points[1].x},${points[1].y}`;
    }

    let d = `M ${points[0].x},${points[0].y}`;
    for (let i = 0; i < points.length - 1; i++) {
      const p0 = points[Math.max(i - 1, 0)];
      const p1 = points[i];
      const p2 = points[i + 1];
      const p3 = points[Math.min(i + 2, points.length - 1)];

      const cp1x = p1.x + (p2.x - p0.x) * 0.16;
      const cp1y = p1.y + (p2.y - p0.y) * 0.16;
      const cp2x = p2.x - (p3.x - p1.x) * 0.16;
      const cp2y = p2.y - (p3.y - p1.y) * 0.16;

      d += ` C ${cp1x},${cp1y} ${cp2x},${cp2y} ${p2.x},${p2.y}`;
    }
    return d;
  }

  // X-axis labels
  const xLabels = useMemo(() => {
    if (data.length === 0) return [];
    if (data.length <= 5) return data.map((d) => formatDate(d.date));
    
    const indices = [0, Math.floor(data.length / 4), Math.floor(data.length / 2), Math.floor(data.length * 3 / 4), data.length - 1];
    return indices.map((i) => formatDate(data[i].date));
  }, [data]);

  // Measure axis width
  useEffect(() => {
    const measure = () => {
      const plotEl = plotRef.current;
      const axisEl = axisRef.current;
      if (!plotEl || !axisEl) return;
      const plotRect = plotEl.getBoundingClientRect();
      const axisRect = axisEl.getBoundingClientRect();
      if (!plotRect.width) return;
      const next = (axisRect.width / plotRect.width) * width;
      const clamped = Math.max(4, Math.min(width - 1, next));
      setAxisWidthView((prev) => (Math.abs(prev - clamped) > 0.2 ? clamped : prev));
    };
    measure();

    if (typeof ResizeObserver !== "undefined") {
      const observer = new ResizeObserver(measure);
      if (plotRef.current) observer.observe(plotRef.current);
      if (axisRef.current) observer.observe(axisRef.current);
      return () => observer.disconnect();
    }
    window.addEventListener("resize", measure);
    return () => window.removeEventListener("resize", measure);
  }, []);

  // Mouse move handler
  function handleMove(e: React.MouseEvent) {
    const el = plotRef.current;
    if (!el || data.length === 0) return;
    const rect = el.getBoundingClientRect();
    const axisWidthPx = axisRef.current?.getBoundingClientRect().width ?? (axisWidthView / width) * rect.width;
    const plotWidthPx = rect.width - axisWidthPx;
    const rawX = Math.min(Math.max(e.clientX - rect.left, 0), plotWidthPx);
    const xPaddingPx = plotWidth > 0 ? (xPadding / plotWidth) * plotWidthPx : 0;
    const plotSpanPx = Math.max(plotWidthPx - xPaddingPx * 2, 0);
    const denom = Math.max(data.length - 1, 1);
    const clamped = Math.min(Math.max(rawX - xPaddingPx, 0), plotSpanPx);
    const ratio = plotSpanPx > 0 ? clamped / plotSpanPx : 0;
    const index = Math.round(ratio * denom);
    
    const point = data[index];
    if (!point) return;
    
    const value = point.total;
    const snappedX = denom > 0 ? xPaddingPx + (index / denom) * plotSpanPx : plotWidthPx / 2;
    const yRatio = max > 0 ? 1 - value / max : 1;
    const yPx = (plotTop / height) * rect.height + yRatio * (plotHeight / height) * rect.height;

    setHover({
      index,
      value,
      successRate: point.successRate,
      label: point.date,
      x: snappedX,
      y: yPx,
      rectWidth: rect.width,
      axisWidthPx,
    });
  }

  function handleLeave() {
    setHover(null);
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
    <AsciiBox
      title="Trend"
      subtitle={`${data.length} days`}
    >
      {/* Stats header */}
      <div className="flex items-center justify-between text-caption text-matrix-muted px-1 mb-3">
        <div className="flex gap-3">
          <span>MAX: {Math.round(max)}</span>
          <span>AVG: {Math.round(avg)}</span>
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

          {lineSegments.map((segment, idx) => {
            if (segment.length < 2) return null;
            const first = segment[0];
            const last = segment[segment.length - 1];
            const linePath = solveSmoothPath(segment);
            const fillPath = `${linePath} L ${last.x},${height - plotBottom} L ${first.x},${height - plotBottom} Z`;
            
            return (
              <g key={`seg-${idx}`}>
                {/* Fill area */}
                <path d={fillPath} fill="url(#trend-grad)" />
                {/* Line */}
                <path
                  d={linePath}
                  fill="none"
                  stroke={COLOR}
                  strokeWidth="1.5"
                  vectorEffect="non-scaling-stroke"
                  className="drop-shadow-[0_0_5px_rgba(0,255,65,0.8)]"
                />
              </g>
            );
          })}

          {/* Data points - rendered as small squares to avoid distortion */}
          {lineSegments.flat().map((pt, i) => (
            <rect
              key={`pt-${i}`}
              x={pt.x - 1}
              y={pt.y - 1}
              width="2"
              height="2"
              fill={COLOR}
              className="drop-shadow-[0_0_4px_rgba(0,255,65,0.6)]"
            />
          ))}
        </svg>

        {/* Y-axis */}
        <div
          ref={axisRef}
          className="absolute right-0 top-0 bottom-0 flex flex-col justify-between py-1 px-1 text-caption text-matrix-muted pointer-events-none bg-matrix-panelStrong border-l border-matrix-ghost w-10 text-right"
        >
          <span>{formatCompact(max)}</span>
          <span>{formatCompact(max * 0.75)}</span>
          <span>{formatCompact(max * 0.5)}</span>
          <span>{formatCompact(max * 0.25)}</span>
          <span>0</span>
        </div>

        {/* Hover interaction layer */}
        <div
          ref={plotRef}
          className="absolute inset-0 z-20"
          onMouseMove={handleMove}
          onMouseLeave={handleLeave}
        />

        {/* Hover tooltip */}
        {hover && (
          <>
            {/* Vertical line */}
            <div
              className="absolute inset-y-0 left-0 pointer-events-none z-25"
              style={{ right: hover.axisWidthPx }}
            >
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
                left: Math.min(hover.x + 10, hover.rectWidth - hover.axisWidthPx - 120),
                top: Math.max(hover.y - 24, 6),
              }}
            >
              <div className="text-matrix-muted">{formatDate(hover.label)}</div>
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
