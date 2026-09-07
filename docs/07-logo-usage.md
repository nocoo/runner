# Runner logo usage

The identity is emerald enamel mechanical stopwatch. It follows the reviewed Hexly material study `2026-09-07-01`, finishing `01`.

## Asset roles

- `logo.png`: exact 2048 × 2048 transparent foreground, free of the backdrop and cast shadow.
- `assets/brand/icon.png`: square presentation for large cards and platforms that apply their own mask.
- `assets/brand/icon-rounded.png`: large README and gallery presentation.
- `assets/brand/background.png`: independent scheduled minutes field.

Small header/sidebar marks and favicons use the transparent foreground without an extra tile or circular CSS mask. Touch/PWA icons use the opaque square presentation. Source hashes and provenance live in `assets/brand/source.json`. Regenerate application sizes with `uv run --with pillow python assets/brand/generate.py`; roles are recorded in `usage.json` and checksums in `derivatives.json`.

## Consumers

- dashboard/src/components/DashboardLayout.tsx: sidebar header and project mark
- dashboard/index.html: transparent favicon sizes and square touch icon
- dashboard/public/site.webmanifest: opaque platform icons

## Study

[Individual comparison](https://hexly.ai/logos/runner) · [Complete generation archive](https://github.com/nocoo/hexly.ai/tree/main/artwork/logo-family/runner/2026-09-07-01) · [Shared usage SOP](https://github.com/nocoo/hexly.ai/blob/main/docs/07-logo-usage-sop.md)
