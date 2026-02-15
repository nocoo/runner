// ============================================
// Duration Distribution - Bar Chart
// ============================================

import { useMemo } from "react";
import { AsciiBox } from "@/ui/foundation";
import type { RunSummary } from "@/models/types";

interface DurationDistributionProps {
  runs: RunSummary[];
  className?: string;
}

interface DurationBucket {
  label: string;
  min: number; // seconds
  max: number; // seconds (Infinity for last bucket)
  count: number;
}

const BUCKET_DEFS: { label: string; min: number; max: number }[] = [
  { label: "<5s", min: 0, max: 5 },
  { label: "5-15s", min: 5, max: 15 },
  { label: "15-30s", min: 15, max: 30 },
  { label: "30-60s", min: 30, max: 60 },
  { label: "1-5m", min: 60, max: 300 },
  { label: ">5m", min: 300, max: Infinity },
];

function computeDuration(run: RunSummary): number | null {
  if (!run.started_at || !run.finished_at) return null;
  const start = new Date(run.started_at).getTime();
  const end = new Date(run.finished_at).getTime();
  if (isNaN(start) || isNaN(end)) return null;
  return (end - start) / 1000;
}

export function DurationDistribution({ runs, className }: DurationDistributionProps) {
  const buckets = useMemo((): DurationBucket[] => {
    const result: DurationBucket[] = BUCKET_DEFS.map((d) => ({
      ...d,
      count: 0,
    }));

    for (const run of runs) {
      const duration = computeDuration(run);
      if (duration === null) continue;

      for (const bucket of result) {
        if (duration >= bucket.min && duration < bucket.max) {
          bucket.count++;
          break;
        }
      }
    }

    return result;
  }, [runs]);

  const maxCount = Math.max(1, ...buckets.map((b) => b.count));

  return (
    <AsciiBox title="Duration" subtitle="distribution" className={className} bodyClassName="flex flex-col">
      <div className="flex-1 flex flex-col justify-center space-y-2">
        {buckets.map((bucket) => {
          const widthPct = (bucket.count / maxCount) * 100;
          return (
            <div key={bucket.label} className="flex items-center gap-2">
              <span className="text-[10px] text-matrix-dim font-mono w-12 text-right shrink-0">
                {bucket.label}
              </span>
              <div className="flex-1 h-4 bg-matrix-primary/5 relative">
                <div
                  className="h-full bg-matrix-primary/40 transition-all duration-300"
                  style={{ width: `${widthPct}%` }}
                />
              </div>
              <span className="text-[10px] text-matrix-muted font-mono w-6 text-right shrink-0">
                {bucket.count}
              </span>
            </div>
          );
        })}
      </div>
    </AsciiBox>
  );
}
