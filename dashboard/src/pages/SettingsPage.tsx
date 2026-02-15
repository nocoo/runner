// ============================================
// Settings Page - System Info & Display Preferences
// ============================================

import { useState, useEffect } from "react";
import { AsciiBox } from "@/ui/foundation";
import { useStatusVM } from "@/viewmodels";
import { formatPercent } from "@/lib/format";

type ClockFormat = "12h" | "24h";

function getStoredClockFormat(): ClockFormat {
  try {
    const stored = localStorage.getItem("runner:clockFormat");
    if (stored === "12h" || stored === "24h") return stored;
  } catch {
    // localStorage unavailable
  }
  return "24h";
}

function setStoredClockFormat(format: ClockFormat): void {
  try {
    localStorage.setItem("runner:clockFormat", format);
  } catch {
    // localStorage unavailable
  }
}

export function SettingsPage() {
  const statusVM = useStatusVM();
  const [clockFormat, setClockFormat] = useState<ClockFormat>(getStoredClockFormat);

  useEffect(() => {
    setStoredClockFormat(clockFormat);
  }, [clockFormat]);

  return (
    <div className="space-y-4">
      {/* System Info */}
      <AsciiBox title="System Info" subtitle="runtime">
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <InfoRow label="Version" value={statusVM.data?.version ?? "-"} />
          <InfoRow label="Status" value={statusVM.isOnline ? "Online" : "Offline"} />
          <InfoRow label="Runs Today" value={String(statusVM.data?.total_runs_today ?? "-")} />
          <InfoRow
            label="Success Rate"
            value={statusVM.data ? formatPercent(statusVM.data.success_rate_today) : "-"}
          />
          <InfoRow label="Last Run Task" value={statusVM.lastRunTask} />
          <InfoRow label="Last Run Status" value={statusVM.lastRunStatus} />
        </div>
      </AsciiBox>

      {/* Display Preferences */}
      <AsciiBox title="Display" subtitle="preferences">
        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-matrix-primary font-mono uppercase">Clock Format</p>
              <p className="text-caption text-matrix-dim">Choose 12-hour or 24-hour display</p>
            </div>
            <div className="flex gap-1">
              <button
                onClick={() => setClockFormat("12h")}
                className={`px-3 py-1.5 text-caption font-mono uppercase border transition-colors ${
                  clockFormat === "12h"
                    ? "bg-matrix-primary/20 border-matrix-primary text-matrix-primary"
                    : "border-matrix-primary/20 text-matrix-dim hover:text-matrix-muted"
                }`}
              >
                12H
              </button>
              <button
                onClick={() => setClockFormat("24h")}
                className={`px-3 py-1.5 text-caption font-mono uppercase border transition-colors ${
                  clockFormat === "24h"
                    ? "bg-matrix-primary/20 border-matrix-primary text-matrix-primary"
                    : "border-matrix-primary/20 text-matrix-dim hover:text-matrix-muted"
                }`}
              >
                24H
              </button>
            </div>
          </div>
        </div>
      </AsciiBox>
    </div>
  );
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between py-1.5 border-b border-matrix-primary/10">
      <span className="text-caption text-matrix-dim font-mono uppercase">{label}</span>
      <span className="text-caption text-matrix-primary font-mono">{value}</span>
    </div>
  );
}
