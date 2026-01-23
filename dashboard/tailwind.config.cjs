const defaultTheme = require("tailwindcss/defaultTheme");

/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
  theme: {
    extend: {
      colors: {
        matrix: {
          primary: "#00FF41",
          bright: "#E8FFE9",
          muted: "rgba(0,255,65,0.6)",
          dim: "rgba(0,255,65,0.35)",
          ghost: "rgba(0,255,65,0.18)",
          panel: "rgba(0,10,0,0.7)",
          panelStrong: "rgba(0,10,0,0.82)",
          dark: "#050505",
        },
        success: "#00FF41",
        error: "#FF4141",
        warning: "#FFD700",
      },
      fontFamily: {
        matrix: ['"Geist Mono"', "ui-monospace", "SFMono-Regular", ...defaultTheme.fontFamily.mono],
        mono: ['"Geist Mono"', ...defaultTheme.fontFamily.mono],
      },
      fontSize: {
        display: ["clamp(48px, 6vw, 72px)", { lineHeight: "1.1" }],
        heading: ["14px", { lineHeight: "1.4", letterSpacing: "0.05em" }],
        body: ["16px", { lineHeight: "1.6" }],
        caption: ["12px", { lineHeight: "1.4" }],
      },
    },
  },
  plugins: [],
};
