// ============================================
// Matrix Clock - Animated digital clock
// ============================================

import { useState, useEffect } from "react";

// Generate random matrix character for glitch effect
function randomMatrixChar(): string {
  const chars = "01アイウエオカキクケコサシスセソタチツテト";
  return chars[Math.floor(Math.random() * chars.length)];
}

// Single digit with flip animation
function ClockDigit({ value, prevValue }: { value: string; prevValue: string }) {
  const [isFlipping, setIsFlipping] = useState(false);
  const [glitchChar, setGlitchChar] = useState<string | null>(null);

  useEffect(() => {
    if (value !== prevValue) {
      setIsFlipping(true);
      // Brief glitch effect during transition
      setGlitchChar(randomMatrixChar());
      const glitchTimer = setTimeout(() => setGlitchChar(null), 50);
      const flipTimer = setTimeout(() => setIsFlipping(false), 150);
      return () => {
        clearTimeout(glitchTimer);
        clearTimeout(flipTimer);
      };
    }
  }, [value, prevValue]);

  return (
    <span
      className={`
        inline-block w-[0.65em] text-center
        transition-all duration-150
        ${isFlipping ? "scale-y-0 text-matrix-bright" : "scale-y-100"}
      `}
      style={{ transformOrigin: "center" }}
    >
      {glitchChar ?? value}
    </span>
  );
}

// Blinking colon separator
function ClockSeparator() {
  const [visible, setVisible] = useState(true);

  useEffect(() => {
    const interval = setInterval(() => {
      setVisible((v) => !v);
    }, 500);
    return () => clearInterval(interval);
  }, []);

  return (
    <span
      className={`
        inline-block w-[0.6em] text-center mx-0.5
        transition-opacity duration-100
        ${visible ? "opacity-100" : "opacity-30"}
      `}
    >
      :
    </span>
  );
}

interface MatrixClockProps {
  /** Optional label to display above the clock (e.g. "北京时间") */
  label?: string;
}

export function MatrixClock({ label }: MatrixClockProps) {
  const [time, setTime] = useState(() => new Date());
  const [prevTime, setPrevTime] = useState(() => new Date());

  useEffect(() => {
    const interval = setInterval(() => {
      setPrevTime(time);
      setTime(new Date());
    }, 1000);
    return () => clearInterval(interval);
  }, [time]);

  const format = (date: Date) => ({
    h1: String(date.getHours()).padStart(2, "0")[0],
    h2: String(date.getHours()).padStart(2, "0")[1],
    m1: String(date.getMinutes()).padStart(2, "0")[0],
    m2: String(date.getMinutes()).padStart(2, "0")[1],
    s1: String(date.getSeconds()).padStart(2, "0")[0],
    s2: String(date.getSeconds()).padStart(2, "0")[1],
  });

  const curr = format(time);
  const prev = format(prevTime);

  return (
    <div className="flex flex-col items-center gap-1">
      {label && (
        <span className="text-caption uppercase tracking-[0.3em] text-matrix-muted font-bold">
          {label}
        </span>
      )}
      <div className="font-mono text-3xl md:text-4xl font-black text-white tracking-[-0.06em] tabular-nums leading-none glow-text-white select-none">
        <span className="inline-flex items-center">
          <ClockDigit value={curr.h1} prevValue={prev.h1} />
          <ClockDigit value={curr.h2} prevValue={prev.h2} />
          <ClockSeparator />
          <ClockDigit value={curr.m1} prevValue={prev.m1} />
          <ClockDigit value={curr.m2} prevValue={prev.m2} />
          <ClockSeparator />
          <ClockDigit value={curr.s1} prevValue={prev.s1} />
          <ClockDigit value={curr.s2} prevValue={prev.s2} />
        </span>
      </div>
    </div>
  );
}
