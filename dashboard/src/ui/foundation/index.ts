// ============================================
// UI Foundation Components
// ============================================

export { AsciiBox, ASCII_CHARS } from "./AsciiBox";
export { MatrixButton } from "./MatrixButton";

// Additional components from MatrixExtras
export {
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
} from "./MatrixExtras";

// Error handling
export { ErrorBoundary } from "./ErrorBoundary";

// Data visualization components
export {
  TrendMonitor,
  TrendChart,
  ActivityHeatmap,
  ArchiveHeatmap,
  shouldFetchGithubStars,
  shouldRunLiveSniffer,
  shouldScrambleText,
} from "./DataVizComponents";
