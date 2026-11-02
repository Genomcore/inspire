---
produced:
  skill: feature
  skill_sha: 7aff836
  refs_sha: bd26ed3
  inspire: 0.9.9
  at: "2026-09-18"
---
# LND-07: Act and switch language

> Source: [[../../02_modules/landing]]

The visitor ends the page with a closing line and three final actions: Get Started,
GitHub, Contact sales. Across the whole page the visitor can switch between English,
the primary language, and Spanish for the regional health services. The page records
clicks on Get Started and on GitHub, which are the success metrics; it collects no
form and sets no tracking cookie.

**State:** 🟡 Planned
**Priority:** Core
**Depends on:** [[LND-01]]

## Actor
Any visitor who has finished reading.

## Preconditions
None.

## Main flow
1. `B1` — The visitor reads the closing line: install it this afternoon, decide with
   data, not demos.
2. `B2` — The visitor clicks Get Started, GitHub or Contact sales and reaches the
   target.
3. `B3` — The page records a click event naming the action before the navigation
   leaves the page.

## Alternative flows
### AF-1: Switch language
The visitor selects Spanish in the language control. Every section renders its
Spanish copy at the same scroll position, the URL reflects the language, and the
choice persists on reload.

### AF-2: Browser language
On a first visit, the page reads the language preference of the browser. A
preference for Spanish renders Spanish; any other preference renders English.

## Error flows
### EF-1: Analytics endpoint unreachable
The click event fails to send. The navigation proceeds without delay and the page
shows no error.

## Postconditions
- `Q1` — The visitor has left toward the docs, the repository or sales, and one
  click event names which.

## Acceptance criteria
- [ ] AC-1: The closing section renders one sentence and three actions labelled "Get Started", "GitHub" and "Contact sales", each resolving to a non-empty URL.
- [ ] AC-2: Clicking Get Started or GitHub emits one click event whose payload names the action and the current language, and the target opens whether or not the endpoint received the event.
- [ ] AC-3: When the analytics endpoint returns an error or times out, navigation completes within the same click and no error surfaces in the page.
- [ ] AC-4: Selecting Spanish rewrites every visible text node of every section into Spanish and leaves the vertical scroll position within 50 px of where it was.
- [ ] AC-5: The URL path carries the language (`/` or `/en` for English, `/es` for Spanish) and reloading the page renders the language the URL names.
- [ ] AC-6: A first visit with `Accept-Language` preferring `es` renders Spanish; any other value renders English.
- [ ] AC-7: The page sets no cookie and stores nothing beyond the language preference in local storage.
- [ ] AC-8: The page contains no form element.
