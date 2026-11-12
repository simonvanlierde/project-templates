---
status: accepted
date: 2026-11-11
---

# Optional features share one extras answer

## Context and Problem Statement

The 2026-11-10 decision kept the optional features because each serves one of the
[three audiences](0008-three-audiences-in-order.md). Separate yes/no questions made
`customise` longer, and library tests already used another multiselect. Projects
also store those answers, so changing the questions must preserve their choices.

## Considered Options

* Keep the separate questions and the library-test multiselect
* Remove features that current projects do not use
* Store the optional features in one `extras` multiselect under `customise`

## Decision Outcome

Chosen: one `extras` answer in v0.15.0, marked **Breaking**. It holds `codecov`,
`codspeed`, `profiling`, `cold_install`, `python_windows`, `docs_site`, `property`
and `mutation`. Publishing and hosting keep their own questions because they
configure external services and deployment contracts.

Updates seed `extras` from the old booleans and `test_extras` before computed
questions discard them. The next answers file stores only `extras`. An explicit
list replaces the selection; scripts must list every feature they want to keep.

New public, licensed projects at `standard` or `community` start with
`cold_install`. An existing project's explicit `false` keeps it disabled.
Templates use computed booleans and a computed test list from the one answer.

### Consequences

* Good: one prompt selects the optional features without removing any of them.
* Good: a v0.14.0 update preserves enabled and disabled features automatically.
* Bad: scripts that pass the old question names must switch to `extras`.

### Confirmation

`scripts/render/cases.sh` covers the feature selections, incompatible stacks,
Pages conflicts and level defaults. The update regression in
`scripts/render/update.sh` renders v0.14.0 with all features, only Windows tests,
and no features. It updates each project, checks the stored answers and generated
files, then clears the full selection in a second update.
