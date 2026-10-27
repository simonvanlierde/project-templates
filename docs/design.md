# Design: actors, render and update

Who acts on a project made from this template, what each one can change, and which
workflows hold a token that can publish.

## Actors

| Actor | What it does | What it can change |
| --- | --- | --- |
| The copier user | Answers the questions and runs `copier copy` or `copier update` on their own machine | Every file in their project, through their own git push |
| This repository's CI | Renders answer combinations and runs each generated project's checks | Nothing outside its own runner; it publishes only this template's releases |
| The generated project's CI | Runs the stack workflows on pull requests, on pushes to main and weekly | Read-only by default: each workflow sets `contents: read` or no permissions at all, and a job asks for more only where it needs it |
| The dependency bot (Renovate or Dependabot) | Opens pull requests that bump dependencies, lockfiles and pinned actions | A branch and a pull request; it can't merge unless the project turns on auto-merge |
| The `copier update` workflow (Dependabot projects) | Weekly, renders the newest template release and opens a pull request | Its token can push to any branch without protection; the script pushes only `chore/copier-update` and opens that pull request, or, when it can't push a workflow change, opens an issue and closes that pull request |
| The maintainer | Reviews and merges pull requests, pushes `vX.Y.Z` tags | `main`, and what a tag publishes |

## Render

`copier copy` reads `copier.yml` from the newest tagged release, asks the questions, and
writes the files in `template/` with the answers filled in. It runs no commands: the
template has no copier tasks or migrations. The answers go to `.copier-answers.yml`,
together with the template version. Nothing reaches the network apart from copier fetching
the template.

## Update

`copier update` renders the version in `.copier-answers.yml` and the newest release with
the same answers, and applies the difference to the project as a three-way merge. Where the
project changed the same lines, it leaves conflict markers to resolve by hand. Files listed
in `_skip_if_exists` (the changelog, README, citation files, legal pages, API report and starter code) are never touched
again. A plain `copier update` asks the questions again, with the stored answers as
defaults, and asks a new question like any other. With `--defaults`, as the weekly
workflow runs it, a new answer takes its default, or stops the update if it has none,
unless `--data` passes it.

The weekly workflow runs Copier in a read-only job. It passes a binary patch and PR
text to a fresh job, which applies the patch and opens the update PR. That job never
runs files from the update or imports its Git configuration or hooks. The push token
is available only there, away from Copier and its dependencies.

## Workflows that can publish

These rendered workflows ask for `id-token: write`, an OpenID Connect token that an outside
service trusts in place of a stored secret. The risk is code that runs in the same job and
takes the token.

| Workflow | Renders with | Runs on | What the token can do | What limits it |
| --- | --- | --- | --- | --- |
| `python-release.yml` | `publish_to_pypi` | a pushed `vX.Y.Z` tag | Upload to PyPI (trusted publishing), sign attestations, then publish a GitHub release with distributions and provenance | The OIDC token is only in `publish`; a separate `release` job has only `contents: write`. Neither runs project code; the `pypi` environment should be limited to `v*` tags |
| `ts-release.yml` | `publish_to_npm` | a pushed `vX.Y.Z` tag | Publish to npm | The same split: `publish` only uploads the tarball `build` made; the `npm` environment should be limited to `v*` tags |
| `docker.yml`, `push` job | `publish_to_ghcr` | pushes to main and tags, and manual runs | Sign the image's provenance, with `packages: write` to push to GHCR | Pull requests run only the `build` job, which has no write scope; the `ghcr` environment should be limited and need a reviewer |
| `benchmarks.yml` | `codspeed` | pull requests, pushes to main and manual runs | Upload benchmark results to CodSpeed | GitHub gives pull requests from forks no OIDC token. A branch in the repo itself can still upload false results, which affects the benchmark report only |
| `scorecard.yml` | `public` | pushes to main, weekly and branch protection changes | Publish the Scorecard result | Runs only approved actions on main; no pull request reaches it |

None of these run on `pull_request_target` or `workflow_run`, so no workflow runs code from
a fork with write access. Actions are pinned to full commit SHAs, and checkouts don't keep
the token (`persist-credentials: false`).

The environment rules in the table are repository settings a render can't create. The
comment at the top of each release workflow says what to set.

## Security assessment

Reviewed 2026-10-27 for release 0.11.0. The most likely and most harmful problems, and
what limits each one:

| Threat | Impact | What limits it |
| --- | --- | --- |
| A pull request title, branch name or other event data runs as shell in a rendered workflow | Code runs with the workflow's token | No `run:` step expands event data directly, and CI runs zizmor and jactionlint on every rendered workflow |
| Code in a release job takes the publishing token | A malicious package or image is published under the project's name | The OIDC token is only in the upload job, which runs no project code; the release environments should be limited to `v*` tags |
| Copier or one of its dependencies alters the weekly update job | It pushes to the project with the job's token | Copier runs in a read-only job; a fresh job applies the patch and alone holds the push token (fixed in 0.11.0) |
| A compromised action or package version | Its code runs in CI or in the project | Actions are pinned to commit SHAs. Generated projects commit their lockfiles, and Renovate, uv and pnpm skip versions younger than a week |
| A crafted copier answer breaks out of a generated file | A broken or unsafe render | The 21 validators in `copier.yml` check each free-text answer before rendering |
| A secret is committed to this repository | The secret leaks | betterleaks runs as a hook, and GitHub secret scanning with push protection is on |
