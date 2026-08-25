# Screens — propagation
> Part of [inspire-screens](../SKILL.md). Read when the entry's index routes here.

## After modifying a screen spec — propagation check

Whenever a `create` / `validate` / `extract` changes a screen in a way
that affects the UI (a new pattern, a new or removed binding, a changed dispatch
outcome, a new state, an added or removed tab), the skill MUST ask the user whether
to propagate the change to the prototype before ending the turn. A binding row is
the unit here: adding one is a UI change, and editing a dispatch's `On success` is
one too.

1. **Detect the prototype target** from the screen's `## Current prototype` section.
2. **Classify the change** — structural (propagation strongly recommended),
   cosmetic (mention, don't insist), or no-prototype-yet (skip, note it's ready).
3. **Ask, don't assume.** Close the turn with a clear question, e.g.:

   > The screen spec for `{module}/{screen}` has changed: {summary}. The prototype is
   > now misaligned on: {drift}. Shall I propagate now with `/inspire_prototype`, or
   > in another turn?

4. **If confirmed:** invoke `/inspire_prototype` with a concrete prompt (the
   updated screen + the drift items to resolve).
5. **If declined:** create a tracker ticket via `/inspire_task create` so
   it isn't lost.
