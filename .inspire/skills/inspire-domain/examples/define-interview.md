# Example — defining `auth::user::create` (interview cadence in motion)

This is the canonical illustration of the cadence `/inspire_domain define` expects. Read it to feel the rhythm: one question at a time, show-then-approve, in-line iteration, consolidation by default. The drift this skill exists to prevent is the opposite of this — proposing a field-list structure after a single question.

```
operator: /inspire_domain define auth::user::create

agent:    [Step 0 — authoring context: fresh authoring of an action.
           Step 1 — reads references/interview-prompts-action.md.
           Grounds: reads .inspire_kb/02_features/auth/_index.md, finds the feature
           row; reads adr-auth-01]
          "Got it — this is the user-provisioning entry point. Looking at the
           feature it sources from [[adr-auth-01-identity-model]] and the
           Account provisioning section. Quick question before I draft anything:
           the action takes an email + password, but should it also accept a
           pre-set role, or is role assignment a separate action?"

operator: "Separate action — keep this one minimal."

agent:    "OK. So inputs are email + password. The action writes a new
           auth::user row — that's the entity it touches. One more thing:
           the public signup flow we need allow-list checks, but this is the
           admin-side create — no allow-list, right?"

operator: "Right. Signup is a separate orchestrator."

agent:    [proposes a descriptor draft — frontmatter + body — and shows it
           to the operator]
          "Draft below. The Entities block has one entity
           (auth::user) with id/email/password/created_at as written fields.
           Anything to change?"

operator: "Add a created_by field; admin actor."

agent:    [updates the descriptor, showing the change as a unified diff]
          "Updated. created_by reads from current_user (the calling admin).
           Looks good?"

operator: "Yes, write it."

agent:    [writes .inspire_kb/04_domain/auth/user/auth.user.create.md]
          "Done. Now reconciling the auth::user entity document —
           refreshing its Fields + Touched by tables from every action
           that touches it. Show you the diff before writing?"

operator: "Yes."

agent:    [shows the auth.user.md diff, waits for ok, writes]
          "Consolidated. The descriptor + entity document are staged."
```

## What's happening

- **One focused question at a time.** When the agent had two ambiguities to resolve (role assignment? allow-list?), it asked them one by one and let the operator's answer to the first shape the second.
- **No decision trees, no numbered options.** Even when the answer could have been a closed set, the agent left it open until the operator's framing made the choice obvious.
- **Show-then-approve, not propose-then-explain.** The descriptor draft was shown directly. Justification only when the operator pushed back.
- **Iteration is in-line.** "Add a created_by field" was handled as a small edit, not as a "want me to revise?" gate.
- **Consolidation runs by default after approval**, with a show-then-approve gate on the reconciled `{module}.{entity}.md` entity document (Fields + Touched by tables refreshed; operator-authored sections preserved) before it lands.

## Cross-document capture in action

```
operator: "Also track the last successful login on the user."

agent:    [updates .inspire_kb/04_domain/auth/user/auth.user.create.md — adds a
           `last_login_at` row to its ## Entities field-touch table with
           effect: written, mapping `null` (set later by sign-in flow)]
          [updates .inspire_kb/04_domain/auth/user/auth.user.md — adds `last_login_at`
           to ## Fields and surfaces the rationale prompt]
          "Added `last_login_at` (timestamp, nullable) to both files. The
           entity doc's rationale needs a line on why this lives on
           auth::user vs auth::session — quick thought?"

operator: "Per-user dashboard widget needs it; session-grained is too noisy."

agent:    [folds the rationale into auth.user.md ## Rationale]
          "Captured."
```

The agent did not pause to ask "want me to update the entity doc too?" — it did both writes in one turn, then loud-reflected only on the genuinely ambiguous part (the rationale).
