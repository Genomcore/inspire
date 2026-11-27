---
id: 0144-face-wide-behaviour
title: "0144 — A face cannot state what happens when its session ends"
created: 2026-11-27
updated: 2026-11-27
reporter: "@djessy.czaplicki"
closed_by: null
closed_at: null
epic: follow-up
size: L
importance: High
skills: [domain, screens, workspace]
status: Open
blocked_by: []
related_to: [B3-entry-points]
---

## Description

Met by the Genomics Studio team in run 9 (Factory 0.12.0, INSPIRE 0.14.0) and again in run
13b (10 and 11 November, Factory 0.13.0, INSPIRE 0.14.4). Filed as finding I9 of their Factory
run findings, "stack.md rules are never claims":
https://claude.ai/artifact/G2pMLju5AQJUDbrBCHDgSC#I9

Their request, with the behaviours they need:
https://claude.ai/artifact/XuYu9mfiyhHKsr91dLXCwm

### What happened

The project's `stack.md` § Frontend says that the app sends its token on every call, and
renews it with `auth::session::renew` before it expires. Run 9's scaffold built the first rule
and missed the second. Nothing tested either. A token lives fifteen minutes, so after that
every call answers `401` and every screen is empty. Nothing sends the user to sign-in, except
change-password, whose own screen says so. Run 13b built the same app: it still never calls
renewal.

The team has not chosen its session model yet: a short-lived token with a rotating refresh
token, or a server-side session in an httpOnly cookie. Both need two behaviours, and the first
model needs a third:

1. **Sign-in when the session ends.** A call is refused because the session ended. The app
   opens sign-in from any screen, carrying the screen the user was on. Every open tab does the
   same.
2. **Inactivity warning.** One minute before the inactivity limit, the app warns the user. At
   the limit, it signs out in every tab.
3. **Token renewal.** The app renews about one minute before `expires_at`. A call refused as
   expired triggers one renewal and is sent again once. One tab renews at a time, because a
   spent refresh token presented again ends the whole session.

Writing a signed-out state on each of about sixty screens repeats one rule, and renewal and
the warning belong to no screen. The team asks for a place for behaviour that applies to the
whole app, built and tested.

### What happens today

The face, not `stack.md`, is already where most of this can go:

- **Processes** (INSPIRE 0.15.0). A face-level process runs inside one application, and
  `inspire-process` names "a token refresh" and "an interceptor" as examples. The Factory
  derives a claim for the trigger and one per step (Factory 0.14.0). The team has not run
  them yet.
- **The face store** (INSPIRE 0.21.0). `## STO4: On error` sets a default per error class.
  `unauthenticated → [sign-in](…)` sends a failed load to sign-in.
- **The shell's bindings** (INSPIRE 0.21.0, `## LAY8`). The shell takes `### Dispatches` and
  `### States` in a screen's format, which is what the team's request proposed.

What is still missing:

- **Three triggers.** `## Trigger` takes a schedule, an event ("an action succeeding, a message
  arriving"), start-up or another process. None of them is "a time relative to a value the
  face keeps" (one minute before `expires_at`), "an action refused with an error class" (a
  call answers `401` as expired), or "the person has been inactive for a while". The shell's
  `Trigger` column names a control, and its `States` name a data key that fails.
- **Every call, not only loads.** `STO4` covers "what a failed load does". A dispatch refused
  with `unauthenticated` follows only its own `On error` cell, so the rule is written again
  on every screen that dispatches.
- **Coming back.** The navigate outcome names its target. It cannot carry the screen the user
  was on.
- **Tabs.** Nothing says whether a face process runs once per tab or once per device, or that
  an outcome reaches every tab.
- **`stack.md` builds nothing.** Its prose is no claim, and unit agents are not told to read
  it. Road to 1.0 names only its `## Bindings` in their prompt (D-BIND-9). The scaffold, which
  reads all of it once when `source/` is empty, is being removed
  (`091-remove-scaffold` in the Factory's tracker). A behaviour written there is silently
  never built, and nothing tells the author.

### What the field team proposes

1. The shell takes `### Dispatches` and `### States`, with triggers that are not a control
   (shipped in 0.21.0, without those triggers).
2. Or the Factory derives claims from `stack.md` rules.

### Review

- **No claims from `stack.md` prose.** A claim needs a form whose rows can be hashed and
  tested. `stack.md` holds the project's stack choices, and the one rule it holds as rows is
  `## Bindings` (D-BIND-1). Deriving claims from free prose would make every rewording a
  drift. The team's first ask is the right direction.
- **The behaviours are face processes.** Each one starts on its own, with no person behind it,
  inside one application, and calls actions. That is the definition of a face-level process,
  and the toolchain of its face already builds and tests it (D-ENV-19). Written that way:

  | Process | Trigger | Steps |
  |---|---|---|
  | `renew-before-expiry` | one minute before store key `expires_at` | call `auth::session::renew`, set `expires_at` |
  | `renew-on-expired` | a call refused with the expired code | call `auth::session::renew`, send the call again once |
  | `sign-in-on-session-end` | a call refused as `unauthenticated`, or a refused renewal | clear the session, open sign-in with the current screen |
  | `idle-warning` | the person inactive for the limit minus one minute | show the warning |
  | `idle-sign-out` | the person inactive for the limit | as `sign-in-on-session-end` |

  "Exactly one trigger" holds: renewal is two processes.
- **What has to be added** is what the table needs and the format lacks: the three trigger
  kinds, a navigate outcome that carries the current screen, and a way to say per tab or
  per device. Each trigger has to be testable the way a schedule is today. A relative time and
  inactivity run against a clock the test controls. A refused call names its error class or
  code.
- **`STO4` over every call** is the smaller alternative for sign-in, and it changes what an
  existing `STO4` row means. A project that has one would see its dispatches start following
  it. If it is chosen, an upgrade states that change. Otherwise the process is the only home,
  and `STO4` keeps its meaning.
- **`stack.md` should say when it is ignored.** A sentence in `stack.md` outside
  `## Bindings` that names an action is behaviour no unit builds. The review can warn and point
  at `inspire-process`. That warning is the whole fix for the "stack.md rules" half of the
  finding.
- **`B3-entry-points` is near, and does not hold this.** That ticket is how a call reaches an
  action, and decides its exposure. These triggers start a process inside a face, whose steps
  call actions that already have their routes. If `B3-entry-points` makes processes an entry
  point kind, the triggers move with them.

## Acceptance criteria

- [ ] `inspire-process` and its template accept three more triggers: a time relative to a
      key of the face's store, an action refused with an error class or code, and the
      person's inactivity for a stated time. The skill's "Is the trigger testable?" question
      covers each one.
- [ ] A face process states whether it runs once per tab or once per device, and an outcome
      can reach every tab. Or the ticket's close note says why that stays out of the format.
- [ ] The navigate outcome can carry the screen the user was on, wherever it is accepted.
- [ ] `STO4` states whether its defaults cover dispatches. If they do, the upgrade notes the
      change for projects that already have rows there.
- [ ] The review warns when `stack.md` names an action outside `## Bindings`, and points at
      `inspire-process`. It has fixtures and a row in `plugin/base/bin/README.md`.
- [ ] A complete fixture KB writes the three behaviours as face processes and passes every
      validator.

## Notes

- **Factory.** The Factory derives a process's trigger claim from the text of `## Trigger`
  today, so the new triggers derive with no change. Testing them needs a fake clock and a way
  to make a call fail in the face's toolchain. That work, and the per-tab rule if it lands,
  are filed in the Factory's tracker when this ticket's format lands.
- **For the team, today.** Renewal can already be written as a face process on INSPIRE 0.15.0
  and Factory 0.14.0 or later. Its trigger would be prose that the review asks to sharpen.
  Trying it before this ticket lands shows which of the gaps above stop the build.
