---
status: accepted
date: 2026-11-10
---

# Three audiences in order

## Context and Problem Statement

The template had no stated audience, so every structural choice argued from a different
one. Some reviews asked to remove options that none of my own repos set, and others asked
for docs and presets that only an outside user would read. The README led with the
data-pipeline kind, although the template starts five stacks.

## Considered Options

* Me only: a personal toolkit, trimmed to what my repos use
* Public Copier users from the start
* Three audiences in order: my repos, then CML colleagues, then public users, each opened by a gate

## Decision Outcome

Chosen: three audiences in order. The template is lean for my own repos first, then
becomes the golden path for CML repos, then a public template.

* Gate 1: for one release, every repo on the previous version updates through its weekly
  PR, and each merges with at most one fix commit.
* Gate 2: three CML repos render from the template and update through their weekly PR. It
  also opens the public stage, without waiting for outside demand.

A feature or doc is trimmed only when none of the three audiences needs it. The
off-by-default options stay, because each one serves at least one audience.

The README leads with the promise that holds for every kind: a secure repo, kept current
by a weekly update PR. Citation, Zenodo and Software Heritage are named for research code,
the kinds that render `CITATION.cff`.

### Consequences

* Good: a review can test a removal against three named readers instead of my own usage.
* Good: the gates are counted from merged update PRs, not judged.
* Bad: options that only a later audience uses keep costing render cases now.

### Confirmation

None yet. The gates are counted by hand from `gh pr list` in each rendered repo.
