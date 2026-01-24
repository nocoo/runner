// ============================================
// ErrorBoundary - React error boundary
// ============================================

import { Component, type ReactNode } from "react";

interface ErrorBoundaryProps {
  children: ReactNode;
  fallback?: ReactNode;
}

interface ErrorBoundaryState {
  error: Error | null;
}

export class ErrorBoundary extends Component<ErrorBoundaryProps, ErrorBoundaryState> {
  constructor(props: ErrorBoundaryProps) {
    super(props);
    this.state = { error: null };
    this.handleReload = this.handleReload.bind(this);
  }

  static getDerivedStateFromError(error: Error): ErrorBoundaryState {
    return { error };
  }

  componentDidCatch(error: Error, info: React.ErrorInfo): void {
    if (import.meta?.env?.DEV) {
      console.error("ErrorBoundary caught an error:", error, info);
    } else {
      console.error("ErrorBoundary caught an error:", error);
    }
  }

  handleReload(): void {
    if (typeof window === "undefined") return;
    window.location.reload();
  }

  render(): ReactNode {
    const { error } = this.state;
    if (!error) return this.props.children;

    if (this.props.fallback) {
      return this.props.fallback;
    }

    const errorMessage = String(error?.message || error || "");
    const errorLabel = errorMessage ? `Error: ${errorMessage}` : "No details available";

    return (
      <div className="min-h-screen bg-black text-matrix-primary font-mono flex items-center justify-center p-6">
        <div className="w-full max-w-xl border border-matrix-dim bg-black/70 p-6 text-center space-y-4">
          <div className="text-caption uppercase tracking-[0.6em] opacity-60">
            SYSTEM ERROR
          </div>
          <div className="text-2xl font-black text-white">
            Something went wrong
          </div>
          <div className="text-caption opacity-60">
            An unexpected error occurred. Please try refreshing the page.
          </div>
          <div className="text-caption text-matrix-primary/80 break-words">
            {errorLabel}
          </div>
          <button
            type="button"
            onClick={this.handleReload}
            className="inline-flex items-center justify-center px-4 py-2 border border-matrix-primary text-caption font-black uppercase tracking-[0.4em] text-matrix-primary hover:bg-matrix-primary hover:text-black transition-colors"
          >
            RELOAD
          </button>
        </div>
      </div>
    );
  }
}
