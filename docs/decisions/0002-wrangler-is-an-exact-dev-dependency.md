---
status: accepted
date: 2026-11-04
---

# wrangler is an exact dev dependency

## Context and Problem Statement

The production and preview deploy jobs run wrangler. `pnpm dlx` fetched whatever version
was current at each run, so a new wrangler release could break a deploy with no change in
the project.

## Considered Options

* `pnpm dlx wrangler` in each job
* wrangler as an exact `devDependency` that both jobs install

## Decision Outcome

Chosen: an exact `devDependency` in a web app's `package.json`, installed by both deploy
jobs (#237). Renovate bumps it like any other package, and the lockfile records it. The
version comes from `wrangler_version` in `copier.yml`.

### Consequences

* Good: a deploy runs the same wrangler as a local build, and a bump is a reviewed pull request.
* Bad: an existing web app has to run `pnpm install` and commit `pnpm-lock.yaml` after the update.

### Confirmation

`scripts/check-render.sh` checks that a rendered `package.json` lists wrangler at exactly
the version `wrangler_version` pins.
