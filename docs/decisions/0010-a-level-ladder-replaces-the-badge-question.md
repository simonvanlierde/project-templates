---
status: accepted
date: 2026-11-12
---

# A level ladder replaces the badge question

## Context and Problem Statement

`openssf_badge` (`none`, `passing`, `silver`) chose which documents a public, licensed
project got. It named one standard, though the template also follows OpenSSF Scorecard,
OSPS Baseline, Scientific Python's repo-review and its own practices. Requirements that
apply only to a web app, a package or a pipeline had no place in it, and nothing said
which requirement came from where or from which date it counts. Projects store the
answer, so replacing the question must keep what each project has.

## Considered Options

* Keep `openssf_badge` and describe the other standards in the usage guide
* Add a question per standard
* One `level` question (`minimal`, `standard`, `community`) over a requirements file

## Decision Outcome

Chosen: a `level` question in v0.15.0, marked **Breaking**, asked where `openssf_badge`
was (a public repo with a license). `levels.toml` lists each requirement with its level,
the traits it applies to, its source standard, whether a check or a person verifies it,
and the date it starts to count. `just levels-doc` writes the table in
[Levels](../levels.md) from it, and the file's `version` follows the template's releases,
so a repo can say which version of the ladder it meets.

`standard` takes over from `passing` and `community` from `silver`. A new project starts
at `standard`. An update carries the old answer over: `none` becomes `minimal`, `passing`
becomes `standard` and `silver` becomes `community`, so a project keeps the documents it
had. The next answers file stores only `level`.

### Consequences

* Good: one answer covers every standard the template follows, and a requirement can
  apply to some kinds of repo only.
* Good: a v0.14.0 update keeps the governance documents of a project that answered
  `silver`.
* Bad: scripts that pass `--data openssf_badge=...` must pass `--data level=...`.
* Bad: a new requirement needs an entry in `levels.toml` and a regenerated table, not
  only a template change.

### Confirmation

The `levels-doc` git hook fails when the table in `docs/levels.md` lags `levels.toml`
or the file's version lags the newest release in `CHANGELOG.md`. The update regression
in `scripts/render/update.sh` renders v0.14.0 at `openssf_badge=silver` with an edited
`GOVERNANCE.md` and at `none`, updates both to HEAD, and checks the stored level and
that the governance documents and the edit survive.
