---
id: 090-emanate-turn-liveness
title: "090 — emanate: the loop dies when a turn ends with nothing in flight"
created: 2026-09-09
updated: 2026-09-09
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: follow-up
size: S
importance: Very High
skills: [code]
status: Open
blocked_by: []
related_to: [090-emanate-report-shape, 090-emanate-brief-paraphrase]
---

## Description

The first field run of `/inspire-emanate` (governed project `gs`, 2026-09-08, run
`20260908-102102-qcpd`, goal `workspace.login`) did not finish and did not fail. It went
**idle**. At 11:02 UTC the orchestrator had just stalled the second of two entity units,
had `form` harvested at its contracter boundary with both overseers approving, wrote a
status update ending in "form continues to tester, implementer, gate, drill and promote —
I'll keep going and report when it lands", and ended its turn. Nothing was in flight, so
nothing woke it. The tester for `form` was never spawned. The operator found the session
quiet an hour later.

The mechanism is the harness, and the doctrine never names it. In an interactive session
the orchestrator resumes only when a background agent finishes and posts its task
notification. The run ended nine turns: the first eight each had at least one persona or
overseer running, so the loop kept re-entering by accident; the ninth had none. SKILL.md
§ The loop contract says *"zero human turns between t=0 and the report — never a waiting
prompt, whatever happens"*, and `run.md` never says what a waiting prompt **is** in this
harness: an ended turn with non-terminal units.

A second, smaller miss made the first one bite. `form` had both approvals at 10:57 and
was harvested in the same minute. Its tester should have spawned then. Instead the
orchestrator spent five minutes on the sibling's stall analysis and a vault-wide
measurement, then wrote prose to the operator. Chat prose at the end of a turn is exactly
what ends a turn.

## Acceptance criteria

- [x] `run.md` § The wave schedule (or a new § Liveness beside it) states the rule in
      one sentence: **a turn may end in exactly two states — an agent is in flight whose
      completion re-enters this loop, or the run report is written and the run is over.**
      Any other ended turn is the waiting prompt the loop contract forbids.
- [x] After a harvest, a rework hand-back or a stall decision, **the next spawn precedes
      any operator-facing text in the same turn.** Progress belongs in the log
      (`090-emanate-report-shape`); the chat gets the report once.
- [x] A unit proceeds to its next phase the moment its own gate clears, independently of
      its wave siblings. The wave still closes only when every unit is terminal, but no
      unit waits between phases for the slowest sibling.
- [x] `SKILL.md` § The loop contract links to the rule, and the worked example shows it
      at one handoff (harvest → spawn → then the log line).
- [x] `unattended.md` § The headless call says what happens to in-flight agents when a
      `claude -p` turn ends, or names it as unverified so nobody schedules a run on an
      assumption.

## Notes

Evidence: session `c4a447f6-57b2-47c5-a41e-bc91f989d358` in the `gs` project's transcript
directory; the turn boundaries are the `turn_duration` system events at 10:28, 10:37,
10:42, 10:47, 10:52, 10:56, 10:59 and 11:02 UTC. The thirteen spawns were three
contracters and ten overseers — no tester, no implementer.

The rule costs nothing mechanically. It does not assume a scheduler, a wake-up tool or a
cron; it only tells the orchestrator which of its own actions ends the run. A version of
the same rule already exists for the epic orchestration in this repo's memory ("stall
means stall"): an ended turn is a stop, so it has to be a deliberate one.
