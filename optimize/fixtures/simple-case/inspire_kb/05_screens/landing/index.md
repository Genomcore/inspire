---
id: landing.index
module: landing
screen: index
lifecycle: accepted
produced:
  skill: screens
  skill_sha: e7152c6
  refs_sha: bd26ed3
  inspire: 0.9.9
  at: "2026-09-18"
---

# OpenBIMS landing

**Features:** LND-01, LND-02, LND-03, LND-04, LND-05, LND-06, LND-07

## Purpose

A developer or IT lead at a hospital, health service or research centre comes here to
decide whether to install OpenBIMS. The first thing they see is the headline, the
subtitle and three calls to action, with the install snippet directly beneath. From
there they scroll through one long page, section by section, and leave toward the
docs, the repository or sales.

## Bindings

### Navigation

| Key | Target | Trigger |
|---|---|---|
| `demo` | [[samples.list]] | the "See live demo" action in `hero` |

### States

| Key | When | Presentation |
|---|---|---|
| `clipboard-denied` | the browser rejects the clipboard request from the `snippet` deviation | the "select and copy" hint on the copy control; the snippet text stays selectable |
| `capture-missing` | a row of the `tour` deviation has no capture file | a neutral placeholder box with the capture's aspect ratio |
| `capture-open` | the visitor clicks a capture in the `tour` deviation | the capture at natural size in an overlay; Escape or a click outside closes it |
| `reduced-motion` | the visitor's `prefers-reduced-motion` is `reduce`, in the `cora` deviation | the `cora` recordings show a poster frame and a play control; nothing autoplays |
| `media-error` | a recording in the `cora` deviation fails to load | the prompt and the poster frame; no error text |
| `editions-stacked` | the viewport is narrower than 768 px, in the `editions` deviation | `editions` renders three cards, one per edition, instead of the table |
| `faq-open` | the visitor expands a question in the `faq` deviation, or the URL fragment names one | that question's answer, with `aria-expanded="true"`; other questions keep their state |
| `lang-es` | the `language` deviation reads `/es` in the URL path, or `es` first in `Accept-Language` on a first visit | every section in Spanish; the `language` control marks Spanish |
| `tracking-failed` | the click endpoint of the `closing` deviation errors or times out | nothing; navigation proceeds |

## Module-specific deviations

The screen names no shared layout. It is one scrolling page with a fixed top bar and
eight sections in this order; the backticked name of each section is the anchor the
states above reference.

- `hero` — headline, subtitle, three calls to action (Deploy in 5 minutes, See live
  demo, Talk to Genomcore), then the trust strip with its four items.
- `snippet` — the three-line install block with a copy control, placed directly under
  the hero.
- `why` — three pain items (Silos, Lock-in, Showcase AI) followed by the four pillar
  cards; the CORA card uses the violet token, the other three the neutral and teal
  tokens.
- `tour` — nine module rows, each with name, description and a capture, in the order
  Datastore, Filesystem, Runtime, Automation, AI Agents, Auth, Audit, Messaging, Apps
  & Extensions.
- `cora` — headline, three demo cards, each with a prompt and a looping recording, closing
  sentence on the three server-side security levels; every accent in this section
  uses the violet token.
- `editions` — the five-row, three-column comparison table with no prices, one
  sentence beneath it, and one sales link in the Enterprise column.
- `faq` — four collapsed questions, each a button carrying `aria-expanded` and an id
  addressable by URL fragment.
- `closing` — one sentence and three actions (Get Started, GitHub, Contact sales);
  Get Started and GitHub emit one click event each, naming the action and the
  language, before navigation.

The top bar holds the logo and the `language` control (English, Spanish). The
control rewrites the URL path (`/` or `/en`, `/es`), keeps the vertical scroll
position within 50 px, and stores the choice in local storage. The page sets no
cookie and contains no form.

The calls to action in `hero` and `closing` target three external destinations:
the Getting Started documentation, the GitHub repository and the Genomcore contact
page. The "See live demo" action is the `demo` navigation.

## Current prototype

- **Target:** `prototype/` root (`/` and `/es`), run with `npm run dev` inside `prototype/`
- **Drift:**
  - gap — no capture files exist under `prototype/public/captures/`, so every `tour` row renders the `capture-missing` placeholder
  - gap — no CORA recordings exist, so every `cora` card renders its poster area only

## Notes

- The copy of every section, in both languages, omits the marketing words the brief
  bans ("revolutionary", "transform" and their translations).
- Logos, testimonials, patient counts and certification claims stay off the page
  until business supplies verified material.
