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

## Assurance case

Why this template, and a project made from it, meet their security requirements. The
requirements: a render runs no code and writes only inside the project; a token that can
push or publish reaches only the job that needs it, never code from a pull request or a
dependency; and a crafted answer can't turn a render into a broken or unsafe project. Each
claim below names the file or check that backs it. How to report a problem is in
[SECURITY.md](../SECURITY.md).

### Threat model

We defend against:

- someone who opens a pull request, and so picks its title, branch name and code, on this
  repository or on a generated project;
- a compromised action, package or tool release, Copier included, that runs in CI or on
  the copier user's machine;
- code in a release job that tries to take the publishing token;
- a copier answer that breaks out of the file it is written into;
- a secret committed by mistake.

We don't defend against a maintainer account that is taken over, a project that edits
its rendered workflows to weaken them, or GitHub itself. Environment rules and secret
scanning are repository settings a render can't make; the project sets them.

### Trust boundaries

| Boundary | What crosses it | Controls |
| --- | --- | --- |
| The copier user's machine | The template, fetched by Copier, and the user's answers | No Copier tasks or migrations in [`copier.yml`](../copier.yml), so a render runs nothing; validators check the answers ([Render](#render)) |
| This repository's CI | Pull request code and titles | Only `pull_request` triggers; `contents: read` in [`ci.yml`](../.github/workflows/ci.yml), [`dco.yml`](../.github/workflows/dco.yml) and [`pr-title.yml`](../.github/workflows/pr-title.yml); `ci ok` is the required check on main |
| This repository's release | A pushed `vX.Y.Z` tag | [`release.yml`](../.github/workflows/release.yml) has only `contents: write`, holds no OIDC token, refuses a tag GitHub can't verify as signed, and runs only the release-notes script and `gh release create` |
| The generated project's CI | Pull request code and titles | Each workflow under `template/.github/workflows/` sets `contents: read` or `permissions: {}`; none runs on `pull_request_target` or `workflow_run`; `persist-credentials: false` on all 37 checkouts |
| Release jobs with an OIDC token | Built packages and images | The token is only in the upload job, which runs no project code ([Workflows that can publish](#workflows-that-can-publish)); the rendered `tags` ruleset lets only admins create `v*` tags |
| The weekly `copier update` workflow | A new template release and its dependencies | `copier-update.yml` runs Copier in a read-only `update` job and passes a patch to a fresh `push` job that alone holds the push token ([Update](#update)) |
| The dependency bot | New versions of actions, packages and lockfiles | A pull request only, through the same required checks; Renovate and Dependabot wait 7 days before a version update, and uv and pnpm do the same at install |

### Secure design principles

- **Least privilege.** Every workflow, here and rendered, starts at `contents: read` or
  `permissions: {}`, and a job asks for more only where it needs it. `check-render.sh`
  asserts it for the release and update jobs.
- **Separation of privilege.** Building and publishing are separate jobs in
  `python-release.yml`, `ts-release.yml` and `docker.yml`. `copier-update.yml` renders in
  one job and pushes in another.
- **Fail-safe defaults.** Every `publish_to_*` answer and `codspeed` default to false, so a
  workflow with an OIDC token renders only when asked for. `user_data` has no default, so
  `--defaults` stops rather than claim a web app keeps nothing. Without a token that can
  push workflow changes, `copier-update.yml` opens an issue instead of a partial update.
- **Complete mediation.** Every change to a generated project's main goes through a pull
  request and its required checks: the `main` ruleset in
  `template/.github/rulesets/main.json.jinja`, which `just repo-settings` applies.
- **Economy of mechanism.** A render runs no commands, and the update workflow applies a
  plain `git apply` patch: no hooks, no Git configuration from the update.
- **Open design.** The template, its checks and this case are public. Nothing rests on a
  secret but the tokens.

### Countering common weaknesses

- **Shell injection in workflows.** No `run:` step expands event data directly; it goes
  through `env:`. CI runs zizmor and jactionlint (shellcheck on every `run:`) over renders
  a to d and m, which together cover every rendered workflow
  ([`ci.yml`](../.github/workflows/ci.yml)). Generated projects run both as git hooks.
- **Token theft.** OIDC and push tokens stay in jobs that run no project or dependency
  code (above). Checkouts drop the token. `check-render.sh` feeds the update job a patch
  to `.git/config` and a symlinked artifact, and both must be refused.
- **Dependency compromise.** Actions are pinned to full commit SHAs. Generated projects
  commit their lockfiles, and CI installs exactly what they list. The 7-day
  wait gives a hijacked release time to be caught. This repository's Renovate config
  extends `config:best-practices`, which keeps digests pinned.
- **Unvalidated answers.** The 22 validators in [`copier.yml`](../copier.yml) check the
  answers that become names, paths, versions, URLs, ports and identities, and the
  description, which lands unescaped in a docstring and in code comments: it must be one
  line without `"""` or `*/`. `check-render.sh` asserts that 23 crafted answers are refused
  with the validator's own message. Free text reaches JSON, YAML and TOML through `to_json`,
  which render b tests with quotes. The copyright year and the Node and Go versions have no
  validator: the copier user is their only author, so a bad one breaks only their own render.
- **Untested template files.** `check-render.sh` fails when a file in `template/` lands
  in no render, so every file is rendered and checked at least once.

### Security assessment

Reviewed 2026-10-27 for release 0.11.0. The most likely and most harmful problems, and
what limits each one:

| Threat | Impact | What limits it |
| --- | --- | --- |
| A pull request title, branch name or other event data runs as shell in a rendered workflow | Code runs with the workflow's token | No `run:` step expands event data directly, and CI runs zizmor and jactionlint on every rendered workflow |
| Code in a release job takes the publishing token | A malicious package or image is published under the project's name | The OIDC token is only in the upload job, which runs no project code; the release environments should be limited to `v*` tags |
| Copier or one of its dependencies alters the weekly update job | It pushes to the project with the job's token | Copier runs in a read-only job; a fresh job applies the patch and alone holds the push token (fixed in 0.11.0) |
| A compromised action or package version | Its code runs in CI or in the project | Actions are pinned to commit SHAs. Generated projects commit their lockfiles, and Renovate, uv and pnpm skip versions younger than a week |
| A crafted copier answer breaks out of a generated file | A broken or unsafe render | The 22 validators in `copier.yml` check the answers that become names, paths, versions and identities, and the description, before rendering |
| A secret is committed to this repository | The secret leaks | betterleaks runs as a hook, and GitHub secret scanning with push protection is on |
