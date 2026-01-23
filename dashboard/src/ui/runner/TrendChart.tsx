// ============================================
// Trend Chart (Simple SVG)
// ============================================

import type { TrendPoint } from "@/models/types";
import { AsciiBox } from "@/ui/foundation";

interface TrendChartProps {
  data: TrendPoint[];
  height?: number;
}

export function TrendChart({ data, height = 120 }: TrendChartProps) {
  if (data.length === 0) {
    return (
      <AsciiBox title="Trend" subtitle="no data">
        <div className="h-32 flex items-center justify-center text-matrix-dim">
          No trend data available
        </div>
      </AsciiBox>
    );
  }

  const padding = { top: 10, right: 10, bottom: 20, left: 30 };
  const chartHeight = height - padding.top - padding.bottom;

  const maxTotal = Math.max(...data.map((d) => d.total), 1);

  // Generate path for total runs
  const points = data.map((d, i) => ({
    x: (i / (data.length - 1 || 1)) * 100,
    y: chartHeight - (d.total / maxTotal) * chartHeight,
    ...d,
  }));

  const linePath = points
    .map((p, i) => `${i === 0 ? "M" : "L"} ${p.x}% ${p.y + padding.top}`)
    .join(" ");

  // Generate path for success rate (0-100%)
  const successPoints = data.map((d, i) => ({
    x: (i / (data.length - 1 || 1)) * 100,
    y: chartHeight - d.successRate * chartHeight,
    ...d,
  }));

  const successPath = successPoints
    .map((p, i) => `${i === 0 ? "M" : "L"} ${p.x}% ${p.y + padding.top}`)
    .join(" ");

  return (
    <AsciiBox title="Trend" subtitle={`${data.length} days`}>
      <div className="relative" style={{ height }}>
        <svg
          viewBox={`0 0 100 ${height}`}
          preserveAspectRatio="none"
          className="w-full h-full"
        >
          {/* Grid lines */}
          <line
            x1="0"
            y1={padding.top}
            x2="100%"
            y2={padding.top}
            stroke="rgba(0,255,65,0.1)"
            strokeDasharray="2,2"
          />
          <line
            x1="0"
            y1={height / 2}
            x2="100%"
            y2={height / 2}
            stroke="rgba(0,255,65,0.1)"
            strokeDasharray="2,2"
          />
          <line
            x1="0"
            y1={height - padding.bottom}
            x2="100%"
            y2={height - padding.bottom}
            stroke="rgba(0,255,65,0.2)"
          />

          {/* Success rate line (dimmer) */}
          <path
            d={successPath}
            fill="none"
            stroke="rgba(0,255,65,0.3)"
            strokeWidth="1"
            vectorEffect="non-scaling-stroke"
          />

          {/* Total runs line */}
          <path
            d={linePath}
            fill="none"
            stroke="#00FF41"
            strokeWidth="2"
            vectorEffect="non-scaling-stroke"
          />

          {/* Data points */}
          {points.map((p, i) => (
            <circle
              key={i}
              cx={`${p.x}%`}
              cy={p.y + padding.top}
              r="3"
              fill="#00FF41"
              className="hover:r-4"
            >
              <title>
                {p.date}: {p.total} runs ({Math.round(p.successRate * 100)}%
                success)
              </title>
            </circle>
          ))}
        </svg>

        {/* Y-axis labels */}
        <div className="absolute left-0 top-0 h-full flex flex-col justify-between text-caption text-matrix-dim py-2">
          <span>{maxTotal}</span>
          <span>{Math.round(maxTotal / 2)}</span>
          <span>0</span>
        </div>
      </div>

      {/* Legend */}
      <div className="flex items-center justify-center gap-6 mt-2 text-caption">
        <span className="flex items-center gap-1">
          <span className="w-4 h-0.5 bg-matrix-primary"></span>
          <span className="text-matrix-dim">Runs</span>
        </span>
        <span className="flex items-center gap-1">
          <span className="w-4 h-0.5 bg-matrix-dim"></span>
          <span className="text-matrix-dim">Success Rate</span>
        </span>
      </div>
    </AsciiBox>
  );
}
