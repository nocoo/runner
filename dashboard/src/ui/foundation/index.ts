// ============================================
// UI Foundation Components
// ============================================

export { AsciiBox, ASCII_CHARS } from "./AsciiBox";
export { MatrixButton } from "./MatrixButton";
export { MatrixShell } from "./MatrixShell";

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

// Business components from VibeComponents
export {
  BackendStatus,
  SystemHeader,
  IdentityPanel,
  IdentityCard,
  TopModelsPanel,
  LeaderboardPanel,
  UsagePanel,
  NeuralAdaptiveFleet,
  NeuralDivergenceMap,
  LandingExtras,
  GithubStar,
  UpgradeAlertModal,
  CostAnalysisModal,
} from "./VibeComponents";

// Data visualization components
export {
  TrendMonitor,
  TrendChart,
  ActivityHeatmap,
  ArchiveHeatmap,
  // Motion preference utilities
  shouldFetchGithubStars,
  shouldRunLiveSniffer,
  shouldScrambleText,
} from "./DataVizComponents";

// Layout examples (ported from vibeusage)
export {
  DashboardViewExample,
  LandingViewExample,
} from "./LayoutExamples";
