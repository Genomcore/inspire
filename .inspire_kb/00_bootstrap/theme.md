---
kind: bootstrap-theme
status: template         # the default theme template; copied to 05_screens/design-system.md at install
---

# Design system (theme) — default template

The **default design-system template**: theme, typography, color, density and
layout. This is a *seed*, not the live source of truth — at install
(`.inspire/install.sh`) it is **copied to
[`05_screens/design-system.md`](../05_screens)**, which becomes the project's
working design system. From then on edit the live one with
`/inspire_bootstrap design-system`; re-seed this default with
`/inspire_bootstrap theme`.

> **Default**, abstracted from the OpenBIMS mockup's CSS (`@theme` tokens +
> design-system spec). Swap the values for your brand — the token *roles* below are
> what the skills rely on.

## Theme mode

- **Light mode** as the default and only supported theme in v1.
- Background `white`; surfaces `slate-50`; cards white with `border-slate-200`,
  `rounded-lg`. Text: primary `slate-900`, secondary `slate-700`, tertiary
  `slate-500`. Dividers `slate-200`. Hover `slate-50` / `slate-100`.

## Typography

- **Sans (body):** `Geist`, `system-ui`, sans-serif.
- **Mono (IDs, code, endpoints, paths):** `Geist Mono`, `ui-monospace`, monospace.
- **Scale:** page title `text-xl` `font-semibold`; page subtitle `text-sm`
  `slate-600`; section header `text-xs uppercase tracking-wide font-medium
  slate-500`; body `text-sm`; meta `text-xs`.

## Color

### Core tokens (from the mockup `@theme`)

| Role | Token | Value |
|------|-------|-------|
| Primary — actions, active state | `--color-primary` | `#0d9488` (teal-600) |
| AI / accent — assistant, agents | `--color-cora` | `#8b5cf6` (violet) |
| Healthy / success | `--color-healthy` | `#22c55e` (green-500) |
| Degraded / warning | `--color-degraded` | `#eab308` (amber-500) |
| Down / error | `--color-down` | `#ef4444` (red-500) |
| Neutral | slate scale | `#f8fafc`…`#94a3b8` |

### Semantic palette (Tailwind scale)

| Use | Token |
|-----|-------|
| Primary actions, active | `teal-600` / `teal-700` hover |
| AI / assistant / agents | `violet-600` / `violet-50` bg |
| Success / healthy / active | `green-600` / `green-50` bg |
| Warning / degraded / pending | `amber-600` / `amber-50` bg |
| Error / failed / critical | `red-600` / `red-50` bg |
| Info / secondary | `blue-600` / `blue-50` bg |
| Neutral / draft / inactive | `slate-500` / `slate-100` bg |

### Canonical status map

The status keys a status indicator supports; anything outside is a candidate to
add or a symptom of local over-specialization.

| Keys | Dot | Tone |
|------|-----|------|
| `active` · `healthy` · `running` · `ready` · `passed` | green-500 | green-50 / green-700 |
| `building` · `pending` · `indexing` · `syncing` · `in-progress` | blue-500 (pulse) | blue-50 / blue-700 |
| `warn` · `degraded` · `draft` · `expiring` · `stale` | amber-500 | amber-50 / amber-700 |
| `error` · `failed` · `down` · `expired` · `revoked` | red-500 | red-50 / red-700 |
| `idle` · `disabled` · `archived` · `deprecated` · `resolved` | slate-400 | slate-100 / slate-600 |
| `ai` · `agent` · `assistant` | violet-500 | violet-50 / violet-700 |

## Density

- Table rows **44px** (compact, Linear/Airtable feel); sidebar items **36px**.
- Card padding `p-4` (or `p-6` for primary content); section gap `gap-6`; list-item
  gap `gap-3`.

## Global layout

- Top bar `h-14`, `border-b border-slate-200` (launcher + logo left; search ⌘K +
  avatar right).
- Content max-width and page scaffold are defined per pattern in
  [`05_screens/patterns/`](../05_screens/patterns); screens don't redefine them.
