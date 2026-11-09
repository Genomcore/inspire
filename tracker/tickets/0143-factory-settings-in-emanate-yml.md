---
id: 0143-factory-settings-in-emanate-yml
title: "0143 — the Factory's settings move into emanate.yml and /inspire-config follows"
created: 2026-11-09
updated: 2026-11-09
reporter: "@joaquim.ballester"
closed_by: null
closed_at: null
epic: follow-up
size: S
importance: High
skills: []
status: Open
blocked_by: []
related_to: [B1-config-replaces-bootstrap]
---

## Description

INSPIRE Factory keeps its own settings in a second file, `.inspire/emanate.json`, beside the
project file `.inspire/emanate.yml` that `/inspire-config` writes. The Factory merges the two.
The settings become a top-level `factory:` section of `emanate.yml`, with the same key names:
`kb_root`, `spec_root`, `model`, `review_model`, `subagent_models`, `concurrency`,
`max_tries`, `base_branch`, `viewer_port` and `sandbox` (with `memory`). `emanate.json`
disappears, and so does its `schema` key: nothing writes it and nothing checks it. The other
keys of `emanate.yml` (`image`, `services`, `env`, `setup`, `phases`) do not change.

The change is incompatible. A Factory that has the merge refuses a project that still has
`.inspire/emanate.json` and asks the operator to move its keys under `factory`. It also reads
`emanate.yml` from the working tree, no longer from the base branch's last commit.

**This ships when the Factory publishes its 0.13.0 version.** Until then the Factory in use
still reads `emanate.json`, and the skill must keep describing what that Factory does.

Today `/inspire-config` says that `emanate.json` is not its file, reads `base_branch` and
`kb_root` from it, and tells the operator that the Factory reads only the committed file on
the base branch.

## Acceptance criteria

- [ ] `/inspire-config` writes and validates the `factory` section of `emanate.yml`, and no
      longer creates or describes `emanate.json`. Its format reference lists the section's
      keys and the Factory's errors for them.
- [ ] When `/inspire-config init` finds an `emanate.json`, it offers to move its keys under
      `factory`, drops `schema`, and deletes the old file once the operator approves.
- [ ] The skill no longer says the Factory reads the committed file on the base branch.
- [ ] The template names `emanate.json` only where `/inspire-config` detects and migrates
      it, in the changelog entry for this change, and in this ticket.
- [ ] The changelog entry for the release says that a project with an `emanate.json` must
      move its keys before it runs the new Factory.

## Notes

- Close this ticket when the plugin version that carries the change is released. The
  Factory's version decides when that is, not the date of the merge.
- `B1-config-replaces-bootstrap` described the Factory's old settings file in its section on
  what the Factory does; that sentence was updated with this change.
