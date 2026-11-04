---
status: accepted, not built
date: 2026-11-04
---

# Decision records in rendered projects

## Context and Problem Statement

A small tool does not need a decision log, and an empty `docs/decisions/` folder is
clutter. A flagship project does need one, because its choices are costly to reverse.

## Considered Options

* Every project gets `docs/decisions/`
* No project gets it
* A copier question, on for flagship kinds and off for small tools

## Decision Outcome

Chosen: a copier question. It defaults on for flagship kinds and off for small tools. A
rendered project never gets an empty folder: it starts with a first real record.

This lands in a later pull request. Nothing in the template asks the question yet.

### Consequences

* Good: records only where they earn their place.
* Bad: one more question to maintain, and a kind-to-default mapping to keep current.

### Confirmation

None yet.
