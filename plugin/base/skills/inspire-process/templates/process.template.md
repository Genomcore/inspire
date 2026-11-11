---
id: {scope}.{process}
lifecycle: draft
---

# Process: {Title}

{One paragraph: what this process does and why nobody has to ask for it.}

## Trigger

{What starts it: a schedule (`every day at 02:00 UTC`), an event (`[[module.entity.action|module::entity::action]] succeeded`), start-up, or another process.}

## Requires

- [[{module}.{entity}.{action}|{module}::{entity}::{action}]]

## Before

- {A pre-action, in order — or `None.`}

## Behaviour

- B1: {one step, in the order it runs}

## After

- {A post-action, in order — or `None.`}

## Affects

- [[{module}.{entity}|{module}::{entity}]]
