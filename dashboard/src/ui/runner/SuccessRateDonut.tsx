// ============================================
// Success Rate Donut Chart - SVG Donut
// ============================================

import { useMemo } from "react";
import { AsciiBox } from "@/ui/foundation";
import type { RunSummary } from "@/models/types";
import { calculateSuccessRate, getRunsLastNDays } from "@/models/transforms";

interface SuccessRateDonutProps {
  runs: RunSummary[];
}

interface DonutSegment {
  label: string;
  rate: number;
  count: number;
  total: number;
}

const DONUT_RADIUS = 40;
const DONUT_STROKE = 10;
const DONUT_CENTER = 50;
const DONUT_CIRCUMFERENCE = 2 * Math.PI * DONUT_RADIUS;

function DonutRing({
  rate,
  label,
  count,
  total,
}: DonutSegment & { className?: string }) {
  const successOffset = DONUT_CIRCUMFERENCE * (1 - rate);
  const failedRate = total > 0 ? 1 - rate : 0;
  const failedOffset = DONUT_CIRCUMFERENCE * (1 - failedRate);

  return (
    <div className="flex flex-col items-center gap-2">
      <svg viewBox="0 0 100 100" className="w-20 h-20">
        {/* Background ring */}
        <circle
          cx={DONUT_CENTER}
          cy={DONUT_CENTER}
          r={DONUT_RADIUS}
          fill="none"
          stroke="rgba(0, 255, 65, 0.08)"
          strokeWidth={DONUT_STROKE}
        />
        {/* Failed arc */}
        {failedRate > 0 && (
          <circle
            cx={DONUT_CENTER}
            cy={DONUT_CENTER}
            r={DONUT_RADIUS}
            fill="none"
            stroke="rgba(255, 65, 65, 0.5)"
            strokeWidth={DONUT_STROKE}
            strokeDasharray={DONUT_CIRCUMFERENCE}
            strokeDashoffset={failedOffset}
            transform={`rotate(-90 ${DONUT_CENTER} ${DONUT_CENTER})`}
            strokeLinecap="butt"
          />
        )}
        {/* Success arc */}
        {rate > 0 && (
          <circle
            cx={DONUT_CENTER}
            cy={DONUT_CENTER}
            r={DONUT_RADIUS}
            fill="none"
            stroke="#00FF41"
            strokeWidth={DONUT_STROKE}
            strokeDasharray={DONUT_CIRCUMFERENCE}
            strokeDashoffset={successOffset}
            transform={`rotate(-90 ${DONUT_CENTER} ${DONUT_CENTER})`}
            strokeLinecap="butt"
          />
        )}
        {/* Center text */}
        <text
          x={DONUT_CENTER}
          y={DONUT_CENTER}
          textAnchor="middle"
          dominantBaseline="central"
          fill="#00FF41"
          fontSize="14"
          fontFamily="monospace"
        >
          {total > 0 ? `${Math.round(rate * 100)}%` : "-"}
        </text>
      </svg>
      <div className="text-center">
        <p className="text-caption text-matrix-primary font-mono uppercase">{label}</p>
        <p className="text-[10px] text-matrix-dim font-mono">
          {count}/{total} runs
        </p>
      </div>
    </div>
  );
}

export function SuccessRateDonut({ runs }: SuccessRateDonutProps) {
  const segments = useMemo((): DonutSegment[] => {
    const today = getRunsLastNDays(runs, 1);
    const week = getRunsLastNDays(runs, 7);
    const month = getRunsLastNDays(runs, 30);

    return [
      {
        label: "Today",
        rate: calculateSuccessRate(today),
        count: today.filter((r) => r.exit_code === 0).length,
        total: today.length,
      },
      {
        label: "7 Days",
        rate: calculateSuccessRate(week),
        count: week.filter((r) => r.exit_code === 0).length,
        total: week.length,
      },
      {
        label: "30 Days",
        rate: calculateSuccessRate(month),
        count: month.filter((r) => r.exit_code === 0).length,
        total: month.length,
      },
    ];
  }, [runs]);

  return (
    <AsciiBox title="Success Rate" subtitle="donut">
      <div className="flex justify-around items-start">
        {segments.map((seg) => (
          <DonutRing key={seg.label} {...seg} />
        ))}
      </div>
    </AsciiBox>
  );
}
