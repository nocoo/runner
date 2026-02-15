README.md

## Retrospective

- **bun test + `screen` singleton**: `@testing-library/dom`'s `screen` binds to `document.body` at import time. With bun test's preload-based happy-dom registration, the global DOM may not be ready when `screen` initializes. **Fix**: use destructured queries from `render()` instead of `screen`.
- **React 19 + happy-dom `fireEvent.change`**: `fireEvent.change(input, { target: { value } })` does NOT trigger React 19's `onChange` handler under happy-dom. This is a known interop gap. Input state tests that depend on controlled-input updates cannot use `fireEvent` in this stack. Workaround: test filtering logic as pure functions separately, or wait for happy-dom updates.
- **Tailwind v4 `@theme` kebab-case**: CSS custom properties in `@theme {}` use kebab-case (`--color-matrix-panel-strong`), so Tailwind class names must also be kebab-case (`bg-matrix-panel-strong`), not camelCase (`bg-matrix-panelStrong`). This bit us across 6 files.
- **`waitFor()` assertion pattern**: `waitFor(() => value === expected)` returns a boolean and never throws, so it resolves immediately without actually waiting. **Fix**: `waitFor(() => { expect(value).toBe(expected); })`.
- **ESLint `no-constant-binary-expression`**: `false && "hidden"` in test code triggers this rule. Use a variable (`const isHidden = false`) to express the intent while keeping the linter happy.
