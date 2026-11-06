# Using the template

The [README](../README.md#quick-start) shows how to start a project. This page is the
reference for what comes after, in the order you are likely to need it:

- **Render:** [the questions](#the-questions) and [presets](#presets), [stacks](#choosing-your-stacks) and
  [kinds](python-kinds.md), [Compose-only repos](#compose-only-repos),
  [monorepos](#one-package-or-a-monorepo), [licenses](#licenses) and
  [public repos](#public-repos).
- **After the first push:** [protect `main`](#protecting-main) and
  [fill in the About box](#the-github-about-box).
- **Later:** [pull in template updates](#keeping-your-project-up-to-date).
- **Optional features**, which you can turn on at any time with `copier update --data`:
  [publishing](#publishing), [Codecov](#coverage-on-codecov),
  [CodSpeed](#benchmarks-on-codspeed), [profiling](#profiling),
  [test extras](#test-extras), a [static site](#static-site),
  [Workers hosting](#workers-hosting), the
  [OpenSSF badge](#openssf-best-practices-badge) and the
  [dependency bot](#dependency-updates).
- **Existing code:** [adopt the template](#adopting-the-template-in-an-existing-repo) in a
  repo you already have.

## The questions

A new project asks at most ten questions for a single stack (eleven for a web app):

| Question | Prompted when | Effect |
| --- | --- | --- |
| `project_name` | Always | Repository, directory, package, crate, and image names |
| `project_description` | Always | One-line summary for README, package metadata, and citation files |
| `stacks` | Always | Selected packages, CI workflows, and `just` recipes |
| `kind`, `ts_kind`, `rust_kind`, `go_kind` | Respective stack selected | Package architecture, directory layout, and CI configuration |
| `web_framework` | `ts_kind=web-app` | React, or Preact for reduced bundle size |
| `user_data` | `ts_kind=web-app` | Configures privacy statement content and terms page ([legal pages](#legal-pages)) |
| `public` | Always | Adds `.github/` community files and sets default license |
| `github_user`, `author_name`, `author_email` | Always | Repository URLs, badges, licenses, and package metadata |
| `customise` | Always | `yes` prompts for advanced settings; `no` accepts defaults |
| `author_orcid` | Licensed `library`, or Python `research`/`data-pipeline` | Citation metadata |
| `docker_image` | `docker` and `python` stacks selected | Builds the Python package into an image with a Dockerfile and Compose service; no for a [Compose-only repo](#compose-only-repos) |

Identity answers have no defaults.

When `customise` is `no`, advanced questions take these defaults:

| Question | Default |
| --- | --- |
| `license`, `copyright_year` | MIT if `public`, otherwise none; current calendar year |
| `data_license` | CC-BY-4.0 for `research`, CC0-1.0 for `data-pipeline`; none without a license ([Licenses](#licenses)) |
| `python_dir`, `ts_dir`, `rust_dir`, `go_dir` | `.` (package located at repository root) |
| `python_layout` | `src` (`src/<module>`); choose `flat` when [adopting in existing packages](#adopting-the-template-in-an-existing-python-package) |
| `dependency_bot` | Dependabot |
| `codecov` | Disabled |
| `codspeed` | Disabled ([Benchmarks on CodSpeed](#benchmarks-on-codspeed)) |
| `profiling` | Disabled ([Profiling](#profiling)) |
| `cold_install` | Disabled ([CI baseline](ci-baseline.md)) |
| `site` | None ([Static site](#static-site)) |
| `site_host` | GitHub Pages; `cloudflare` deploys the site to a Worker ([Static site](#static-site)) |
| `worker` | Disabled; a Worker script for `/api/*` in a web app or a site on Cloudflare ([Workers hosting](#workers-hosting)) |
| `openssf_badge` | None ([OpenSSF Best Practices badge](#openssf-best-practices-badge)) |
| `decision_records` | On for `web-service`, `data-pipeline`, `web-app`, Compose-only and Silver-badge projects ([Decision records](#decision-records)) |
| `module_name`, `go_module` | Derived from project name and GitHub user |
| `python_version`, `python_min`, `node_version`, `rust_version`, `go_version` | Current stable releases; `python_min` defaults two minor versions below |
| `python_api` | Enabled ([API-break check](#api-break-check)) |
| `publish_to_pypi`, `publish_to_npm`, `publish_to_ghcr` | Disabled ([Publishing](#publishing)) |
| `test_extras` | None ([Test extras](#test-extras)) |
| `app_port` | 8000 |
| `site_url` | `https://<project>.<github_user>.workers.dev`, or `<project>-site` for a site on Cloudflare (the Worker's workers.dev address, if the account's subdomain is the GitHub user). Another host is a custom domain ([Workers hosting](#workers-hosting)) |

During `copier update`, previously configured answers are preserved even when `customise` is `no`. Change an individual setting with `copier update --data <key>=<value>` or prompt for a single setting with `copier update --ask <key>`.

To bypass prompts during initial generation, supply values via `--data-file answers.yml` or pass flags with `--data`.

### Presets

`presets/` holds the answers for repo kinds that come up again and again. A preset fills
the project-kind questions; Copier still asks the identity ones.

| Preset | Repo |
| --- | --- |
| `rust-cli.yml` | A Rust command-line tool |
| `uv-research.yml` | A Python research package with notebooks, data and citation files |
| `compose-deploy.yml` | A [Compose-only](#compose-only-repos) deploy repo with decision records |

Pass one with `--data-file`, which reads a local path:

```sh
curl -fsSLo /tmp/preset.yml https://raw.githubusercontent.com/simonvanlierde/project-templates/main/presets/rust-cli.yml
copier copy --data-file /tmp/preset.yml gh:simonvanlierde/project-templates my-tool
```

`--data` flags after it override single answers. A preset is a starting point, not a
second template: `copier update` reads the answers file, not the preset.

### Layering another template

Copier applies several templates to one repo when each keeps its own answers file. An
organisation's own files (telemetry, contacts, org defaults) belong in a separate template
applied after this one, with `_answers_file: .copier-answers.<name>.yml` in its `copier.yml`.
Update each layer on its own: `copier update --answers-file .copier-answers.<name>.yml`.
This template stays free of any one organisation's setup.

## Choosing your stacks

Select any combination of stacks:

| Stack | Features added |
| --- | --- |
| `python` | Python package with `pyproject.toml`, `src/`, `tests/`, and uv tooling |
| `ts` | TypeScript package or Vite web app ([kinds](#typescript-kinds)) |
| `rust` | Rust crate (library or binary) with strict clippy rules |
| `go` | Go module (library or binary) with golangci-lint |
| `docker` | Dockerfile for the Python package and root `compose.yaml`; without `python`, a [Compose-only repo](#compose-only-repos) |

Each stack includes a CI workflow in `.github/workflows/` and recipes in `just/<stack>.just`. All projects receive `README.md`, `CHANGELOG.md`, `.gitignore`, `.editorconfig`, dependency bot configuration, git hooks, and `AGENTS.md`. Projects with a license also get `LICENSE` and `REUSE.toml`. Python projects select a [kind](python-kinds.md).

CLI binaries (Rust, Go, or Python `data-pipeline`) include `docs/accessibility.md`, documenting terminal output standards (`NO_COLOR` support, plain output redirection, error formats). Review and edit these claims to reflect your application.

With `decision_records` on, a project keeps its architectural choices in `docs/decisions/` ([Decision records](#decision-records)).

## TypeScript kinds

`ts_kind` configures the package target:

| Kind | Target |
| --- | --- |
| `library` | ES module compiled by `tsc` to `dist/`, publishable to npm |
| `app` | Node application compiled to `dist/`, not published |
| `web-app` | Single-page application built with Vite, served by a Cloudflare Worker |

`web-app` prompts for `web_framework` (React or Preact) and `user_data` ([legal pages](#legal-pages)). Web apps include:

- Single-page application entry points (`index.html`, `src/main.tsx`, `src/App.tsx`) and Vitest setup.
- Playwright end-to-end tests in `tests/e2e/`: axe accessibility scans in light/dark modes and Content-Security-Policy enforcement.
- Mandatory legal pages, linked from the footer in the starter app.
- Cloudflare Worker configuration: `public/_headers` (security headers) and `wrangler.jsonc` (static assets, and with `worker` a Worker script for `/api/*`: [Workers hosting](#workers-hosting)).
- A `production` job in `.github/workflows/ts.yml` that deploys `main`.
- `just ts-shots`: full-page screenshots of every route at 390 and 1440 px, light and dark, in `shots/`, to attach to a pull request that changes the UI.
- Pull request previews: a `preview` job in `.github/workflows/ts.yml`, `.github/workflows/preview-retire.yml` and `.github/scripts/preview-retire.sh`.
- Bundle size budget in `scripts/checkBundleBudget.mjs`: 100 KiB of gzipped JavaScript in the largest file. It catches a heavy dependency or a broken chunk split, not ordinary features, so keep it at least 25% above the build rather than just above it.

### Production

Every push to `main` runs the `production` job after the checks pass. It deploys the build the checks ran on to the Worker `<slug>`, with the pinned wrangler, at `https://<slug>.<subdomain>.workers.dev`. Static-asset requests are free and unlimited on the Workers Free plan. The job runs in the `production` GitHub environment, which `just repo-settings` limits to `main`. A preview job that holds the same Cloudflare token can still deploy to `<slug>` (see [Pull request previews](#pull-request-previews)). Without `CLOUDFLARE_API_TOKEN` or `CLOUDFLARE_ACCOUNT_ID`, the job skips with a notice. For a custom domain, set `site_url` to it ([Workers hosting](#workers-hosting)).

#### Moving an app off Cloudflare Pages

An app made before this template deployed from CI was deployed by Cloudflare Pages. To move it:

1. Merge the `copier update`, then run `just repo-settings` and add both secrets to the new `production` environment.
2. The next push to `main` deploys the Worker. Check the app at its workers.dev address.
3. Remove the custom domain from the Pages project. With `site_url` set to it, the next production deploy attaches it to the Worker.
4. Delete the Pages project, now that the Worker serves production.

Before step 2, check that the account has no Worker named `<slug>`: the first deploy overwrites it. Expect a short gap while the domain moves from Pages to the Worker.

Without a custom domain, the app's address changes: set the new one with `copier update --data site_url=https://<slug>.<subdomain>.workers.dev`.

### Pull request previews

Each pull request that is open, not a draft and not opened by a bot such as Renovate gets its own Cloudflare Worker, `<slug>-pr-<number>`, at `https://<slug>-pr-<number>.<subdomain>.workers.dev`. The `preview` job deploys `wrangler.jsonc` under that name. The job summary and the pull request's deployment show the link. Previews are public, and they send `X-Robots-Tag: noindex`. Production never sends that header.

When a pull request closes or turns draft, `preview-retire.yml` deletes its Worker through the Cloudflare API. A daily run lists the account's `<slug>-pr-<number>` Workers and deletes those whose pull request is not open and ready, in case an event was missed. When it cannot read a pull request, it keeps that Worker and fails. To retire previews by hand, run that workflow with a list of pull request numbers, or with the list empty to run the sweep.

Fork pull requests and repos without `CLOUDFLARE_API_TOKEN` or `CLOUDFLARE_ACCOUNT_ID` skip the job with a notice. One-time setup:

1. Run `just repo-settings`. It creates the `preview` and `production` environments in GitHub (or create them under Settings > Environments, with `production` limited to `main`).
2. Create a custom Cloudflare API token with the permission Account > Workers Scripts: Edit. Add it to both environments as the secret `CLOUDFLARE_API_TOKEN`, and add your account ID as `CLOUDFLARE_ACCOUNT_ID`.

The `preview` job runs the pull request's code with the `preview` environment's Cloudflare token. If both environments hold one account-wide token, anyone who can push a branch can deploy over the production Worker. To keep them apart, give previews a token from a second Cloudflare account.

The first deploy creates each Worker, so there is nothing to set up in Cloudflare except the token. The account needs a workers.dev subdomain. wrangler is an exact devDependency in `package.json` ([why](decisions/0002-wrangler-is-an-exact-dev-dependency.md)), and the dependency bot bumps it.

Copier updates do not overwrite user-owned starter files: `src/App.tsx`, `src/App.test.tsx`, `src/main.tsx`, `src/app.css`, `index.html`, `tests/e2e/routes.ts`, and markdown files in `docs/`.

The web app's folder also gets `PRODUCT.md` and `DESIGN.md`, stubs to fill in. They name who uses the app and how it looks, and are yours to edit: an update leaves them alone.

### Legal pages

Legal documents reside in `docs/` and compile to HTML at build time:

| Document | Route | Generation condition |
| --- | --- | --- |
| `docs/accessibility.md` | `/accessibility` | Always |
| `docs/privacy.md` | `/privacy` | Always (includes storage disclosure) |
| `docs/terms.md` | `/terms` | `user_data=accounts` |

`user_data` options: `nothing`, `browser` (local storage only), or `accounts` (server-side data). Playwright tests in `tests/e2e/` verify these pages render properly, contain required contact information, and introduce no undeclared storage or network requests. They also check that every route in `LEGAL_LINKED_FROM` links each page and that each page links back to `/`. The starter's `LEGAL_LINKED_FROM` in `tests/e2e/routes.ts` is all of `ROUTES`; an app that links the pages from one screen, such as its settings, sets it to that screen.
[Legal pages: tips](web-legal.md) says how to fill them in.

## Compose-only repos

A repo that only composes upstream images, with shell scripts and Compose files but no
Dockerfile of its own, answers `stacks=[docker]`. Any `stacks` with `docker` but not
`python` renders a Compose-only repo, because the only image the template builds is the Python one. With
the python stack, answer no to `docker_image` (`--data docker_image=false`) to keep the
package without an image.

The render has no Dockerfile, no image build and no `docker.yml`. It gets:

- `compose.yaml`: one example service with its image pinned by digest, a healthcheck and a
  port bound to `127.0.0.1`. Replace it with your own services: it and `.env.example` are
  yours after the first render, and `copier update` leaves them alone.
- `.env.example`, which `compose.yaml` reads through an optional `.env`.
- `just check`, which runs `docker compose --env-file .env.example config -q` (CI has no
  `.env`), then shellcheck and shfmt (2-space indent, from images pinned by digest) over
  every tracked script that starts with a shell shebang, then the `local-check` recipe if
  `just/local.just` has one. It needs a Docker daemon.
- `.github/workflows/compose.yml`, which runs `just docker-check` (not `local-check`) with no token scopes beyond
  `contents: read`, and is a required check on `main` when `public` is on.
- The `docker-compose` ecosystem in the dependency bot, so image tags and digests get update
  pull requests.

The shellcheck and shfmt images in `just/docker.just` are pinned by digest, and no bot
bumps them: update the tags and digests by hand now and then. `just docker-fmt` applies
shfmt's formatting (`.editorconfig` sets 2-space indent for `*.sh`), and `just fmt` runs it.
Shell files are the `*.sh` files and files whose first line is an sh, bash, dash or ksh
shebang. A zsh or fish script, or a shebang inside a Markdown code block, is not linted.

The git hooks, license and REUSE files, community files and the other CI workflows come
from the same questions as in any other project. `app_port` and `publish_to_ghcr` are not
asked: there is no image to expose or push.

## One package or a monorepo

By default, packages reside at the repository root. To host multiple packages, enable `customise` and assign distinct directory paths (for example, `python_dir: apps/api` and `ts_dir: apps/web`):

```text
apps/api/{pyproject.toml,src,tests,Dockerfile,.dockerignore}
apps/web/{package.json,tsconfig.json,biome.json,src}
compose.yaml
.github/workflows/
justfile, just/, .pre-commit-config.yaml, .copier-answers.yml
```

Workflows and configuration files remain at the repository root. Two packages may share the root directory.

## Licenses

Available code licenses:

- **MIT** (default): permissive reuse with attribution.
- **Apache-2.0**: permissive reuse with an explicit patent grant.
- **BSD-3-Clause**: permissive reuse prohibiting endorsement without permission.
- **GPL-3.0-or-later**: copyleft requiring derivative works to remain GPL-licensed.
- **AGPL-3.0-or-later**: network copyleft covering hosted network services.

`data-pipeline` and `research` projects configure `data_license` for files under `data/`. Research data defaults to CC-BY-4.0. Data pipelines default to CC0-1.0 because they commit only fetch logs; pipeline outputs inherit their respective source licenses.

Licensed projects follow the [REUSE specification](https://reuse.software). `REUSE.toml` declares copyright and licensing rules, full texts reside in `LICENSES/`, and the `reuse` git hook checks compliance. External files copied into the repository must include `SPDX-FileCopyrightText` and `SPDX-License-Identifier` headers or corresponding entries in `REUSE.toml`.

## Public repos

`public` defaults to `yes`. Choosing `no` for private repositories omits `.github/SECURITY.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `pull_request_template.md`, issue forms, and the DCO sign-off check.

Public repositories also receive `.github/workflows/scorecard.yml` to publish [OpenSSF Scorecard](https://scorecard.dev) results for the README badge.

### Making a repo public

Before switching a private repository to public:

1. Scan git history for committed secrets:

   ```sh
   betterleaks git --log-opts=--all .
   ```

   Revoke any detected credentials and rewrite history before publishing.
2. Confirm package name availability on target registries ([PyPI](https://pypi.org/search/), [crates.io](https://crates.io), [npm](https://www.npmjs.com)).
3. Review open issues and pull requests to ensure internal notes or identifiers are removed.
4. Verify the status statement in `README.md`.

Update the repository configuration with Copier:

```sh
copier update --data public=true --data license=MIT
```

## Protecting main

`just repo-settings` applies `.github/rulesets/main.json` using the GitHub CLI:

- Blocks force-pushes and branch deletions.
- Enforces linear history and squash merges.
- Requires pull requests. A required check blocks every PR that skips CI, because a skipped workflow leaves its check pending. If some PRs in your repo skip CI, drop `required_status_checks` from the ruleset or make that check always report. In private repositories, the checks `git hooks`, `pull request title` and `dependency review` must pass.
- In public repositories, requires one approving review submitted after the latest push. Required checks reside in `.github/rulesets/main-checks.json`, which requires the same three, `DCO sign-off`, and each stack's own check (`ts: lint, types, tests` and so on) for a stack at the repo root, `compose` in a Compose-only repo, plus `site: build` when the project has a site. A nested stack's workflow runs only when its folder changes, so its check is not required.
- With `dependency_bot=renovate`, permits the Renovate app to bypass review for minor and patch updates once required checks pass.
- Applies `.github/rulesets/tags.json` to restrict `v*` tag creation to repository administrators.
- Enables Dependabot security alerts (`gh api -X PUT repos/OWNER/REPO/vulnerability-alerts`).

It leaves one setting to you: refusing any action not pinned to a full commit SHA. The template's workflows pin every action, but the setting also stops a workflow added later from using a tag. Turn it on once the repo's own workflows pin too, since an unpinned action then fails its run:

```sh
gh api -X PUT repos/OWNER/REPO/actions/permissions -F enabled=true -f allowed_actions=all -F sha_pinning_required=true
```

This call also resets `allowed_actions` to `all`; check the current value first with `gh api repos/OWNER/REPO/actions/permissions`.

Execute `just repo-settings` once after creating the repository and again whenever ruleset templates change. Requires administrative permissions.

## The GitHub About box

`just repo-about` syncs repository metadata with `gh repo edit`:

- Updates repository description from `project_description`.
- Sets homepage URL from `site_url` for web apps.
- Adds stack topics (`python`, `typescript`, `rust`, `go`, `docker`). Existing manual topics are preserved.

## Keeping your project up to date

`copier update` performs a three-way merge against the latest template release.

User-owned files are never overwritten: `README.md`, `CHANGELOG.md`, citation files (`CITATION.cff`, `codemeta.json`), silver-badge governance documents, web app starter code, `<package>.api.md`, and `go.mod`.

To relocate a package directory, execute `copier update` with the new path and delete the old directory manually.

If upgrading from pre-v0.12.0 projects with `docs/adr/`, move existing records to `docs/decisions/` and remove `docs/adr/`.

After updating, refresh and commit project lockfiles (`uv lock`, `pnpm install`, `just go-sync`).

### Hearing about new releases

- **Renovate:** Automatically opens update PRs using `copier update --skip-answered --defaults`. Inspect PR diffs for conflict markers before merging.
- **Dependabot:** The `.github/workflows/copier-update.yml` workflow runs weekly and on demand. When updates exist, it opens a PR on branch `chore/copier-update`. It updates each `.copier-answers*.yml` in turn, so a [layered template](#layering-another-template) lands in the same PR.

To allow `copier-update.yml` to update workflow files in `.github/workflows/`, generate a fine-grained personal access token with Contents, Pull Requests, and Workflows write access, and save it as secret `COPIER_UPDATE_TOKEN`.

Without this secret, workflow changes open an issue requesting a manual local update.

A PR opened without this secret starts no checks, because `GITHUB_TOKEN` events trigger no workflows. Close and reopen the PR to run them; its body says so.

## Publishing

To publish a release:

1. Set the version in `pyproject.toml` and `package.json` to `X.Y.Z` (only the one you publish). A citable project sets it in every manifest `citesync.toml` lists, or in every manifest at the root when it has no `citesync.toml`. `CITATION.cff` starts with no `version`, so citesync skips it; once you add one, after the first release, set it there too, or citesync fails with `version-mismatch`.
2. Run `just release X.Y.Z`. It checks that version and, in a citable project, runs the citesync hook, then cuts `## [Unreleased]` in `CHANGELOG.md` into `## [X.Y.Z] - date`, fixes the compare links and commits.
3. Merge that commit to `main`, then run `just release X.Y.Z` again on up-to-date `main`. It signs the annotated tag `vX.Y.Z` on `origin/main`, checks it with `git verify-tag` and pushes it. The release workflow refuses a tag GitHub cannot verify, so set `user.signingkey` first (an ssh key works with `gpg.format ssh`).

With `publish_to_pypi`, `python-release.yml` publishes to PyPI and attaches distributions and Sigstore provenance to the GitHub release. Other configurations publish using `release.yml`.

If a publishing job fails before artifacts upload to the registry, re-run the failed CI job on the existing tag. If the release artifact is already published to the registry, do not move the git tag; bump the patch version and publish a new release.

Publishing controls:

| Option | Disabled | Enabled |
| --- | --- | --- |
| `publish_to_pypi` | Package marked `Private :: Do Not Upload` | `python-release.yml` publishes to PyPI |
| `publish_to_npm` | Package set to `"private": true` | `ts-release.yml` publishes to npm |
| `publish_to_ghcr` | Images built and tested; no push | Images pushed to GitHub Container Registry |

Setting up trusted publishing (OIDC):

1. Configure trusted publishers on [pypi.org](https://pypi.org/manage/account/publishing/) or [npmjs.com](https://docs.npmjs.com/trusted-publishers/). For npm, manually publish version 0.1.0 before enabling trusted publishing.
2. Run `just repo-settings` to create required environments (`pypi`, `npm`, `ghcr`) with yourself as required reviewer and a `v*` tag policy (`ghcr` also on `main`).
3. Enable publishing via Copier:

   ```sh
   copier update --data publish_to_pypi=true
   ```

## API-break check

With `publish_to_pypi`, a Python library gets an `api` job in `python.yml`. It runs griffe against the last git tag and fails when a public name loses or changes a parameter. Every name without a leading underscore counts as public.

A package used only through its command line has no Python API to protect. Answer `python_api=false` to drop the job:

```sh
copier update --data python_api=false
```

To keep the job and mark a module internal instead, start its name with an underscore (`_check.py`).

## Coverage on Codecov

`codecov` (Python and TypeScript) uploads coverage reports to [Codecov](https://codecov.io). Pull requests fail only if overall coverage drops by more than 2 percentage points.

Setup:

1. Register the repository on Codecov and retrieve the upload token.
2. Save it as repository secret `CODECOV_TOKEN` (`gh secret set CODECOV_TOKEN`).
3. Enable Codecov:

   ```sh
   copier update --data codecov=true
   ```

## Benchmarks on CodSpeed

`codspeed` (Python and Rust) adds `.github/workflows/benchmarks.yml` and starter benchmarks (`tests/test_benchmarks.py` or `benches/codspeed.rs`). CodSpeed measures CPU instruction counts in simulation on PRs that touch benchmarked code and on every push to `main`.

Setup:

1. Import the repository on [codspeed.io](https://codspeed.io).
2. Set Pull Request comments to "On Change" in CodSpeed repository settings.
3. Enable CodSpeed:

   ```sh
   copier update --data codspeed=true
   ```

## Profiling

`profiling` (Python and Rust) adds profiling recipes:

- **Python:** `just py-profile <script or -m module> <args>` runs pyinstrument on demand via `uv run --with` without modifying dependencies.
- **Rust:** `Cargo.toml` adds a `[profile.profiling]` profile. `just rs-profile <command>` records performance profiles using [samply](https://github.com/mstange/samply); `just rs-counters <command>` executes `perf stat` five times to measure CPU cycles and branch misses. Requires local kernel perf event support.

Enable with:

```sh
copier update --data profiling=true
```

## Test extras

Library kinds configure `test_extras` under `customise`:

| Option | Python | TypeScript | Rust | Go |
| --- | --- | --- | --- | --- |
| `property` | Hypothesis | fast-check | proptest | Native fuzz test (`FuzzAdd`) |
| `mutation` | mutmut (`just py-mutation`) | Stryker (`just ts-mutation`) | cargo-mutants (`just rs-mutation`) | gremlins (`just go-mutation`) |

Property tests run fast suites locally and in CI. Weekly scheduled jobs (`.github/workflows/property.yml`) execute extended runs (10,000 cases or 10 minutes of fuzzing).

Mutation testing runs weekly via `.github/workflows/mutation.yml` and on demand via `just <stack>-mutation`. The Python and Rust jobs fail on a surviving mutant. The TypeScript and Go tools exit 0 when a mutant survives, so those jobs only print survivors.

Python: `just py-mutation` fails on a survivor (a mutant the tests miss, or that no test reaches) that is not in `tests/mutation-baseline.txt`. It also fails on a listed mutant that no longer survives, so the list stays true. Each line is the mutant name, then the reason. List a mutant only when no test could see the change. Mutant numbers shift when their function changes, so recheck the lines then. `copier update` adds the file with no entries; run the recipe once and list what it reports. Give it mutmut patterns, e.g. `just py-mutation 'mypkg.core.x_parse__mutmut_*'`, to run only those mutants; that run skips the check for listed ones that no longer survive.

A full run takes minutes to hours, so check each change with the diff recipe instead and keep the full run for the weekly job and before a release:

| Stack | Per-change recipe | What it runs |
| --- | --- | --- |
| Python | `just py-mutation-diff` | the mutants of functions and methods the branch changed since it split off `origin/main`, in the mutated modules (`just/mutation_diff.py` finds them) |
| Rust | `just rs-mutation-diff` | `cargo mutants --in-diff` on the branch's changes since it split off `origin/main` |
| Go | `just go-mutation-diff` | `gremlins unleash --diff` against the commit where the branch split off `origin/main` |
| TypeScript | none | Stryker has no diff mode. Its `--incremental` reuses the results file of an earlier run, which needs a stored file between runs, so the template adds no recipe |

Each takes another git ref, e.g. `just py-mutation-diff main`.

To add extras to an existing project:

```sh
copier update --data 'test_extras=[property]'
```

## Static site

Answer `site` (under `customise`) to give any project a static page beside its code: a playground, a demo or a report. GitHub Pages serves it from `main`, or a Cloudflare Worker with `site_host=cloudflare`, and each pull request gets a preview. The page's readers are the project's users, so it stays small: the tool in the first screen, details in disclosures.

The two choices differ only in what is in `site/` and how `just site` builds it:

- `site=plain`: `site/index.html`, `site/style.css` and `site/main.mjs`, a starter page with a header, a main area with a TODO for the tool, and a footer with the licence and a privacy line. Plain HTML, CSS and an ES module, no build step or framework. It works at 320 px and in dark mode. `just site` copies `site/` to `_site/`. For a page that needs a build, replace the recipe's body with yours, such as `uv run site/build.py --out _site`, and add the setup it needs (uv, Rust, Node) before `just site` in the `build` job of `site.yml`.
- `site=astro`: a small Astro project. `package.json` has astro at the version `copier.yml` pins, `src/layouts/Base.astro` has the same header and footer, and `src/pages/` holds `index.astro` and a Markdown page, `about.md`. Run `just site-sync` once to write `site/pnpm-lock.yaml`, and commit it. `just site` installs from that lockfile and runs `astro build` into `site/dist/`. The `build` job sets up Node and pnpm from `site/package.json`, so the repo needs no TypeScript stack. Pages serves the site at `https://<user>.github.io/<repo>/`, so `site` and `base` in `astro.config.mjs` match it. On a Worker (`site_host=cloudflare`), the site is served from `/`: `site` is the Worker's address and there is no `base`.

The starter files are yours: an update leaves them alone. An Astro site's `package.json` stays the template's, and Dependabot or Renovate bumps it. Both choices also render:

- `.github/workflows/site.yml`. The `build` job runs `just site` on every pull request and push to `main` and uploads the result, which is gitignored. The `deploy` job publishes that build to GitHub Pages on a push to `main`. It is the only job with `pages: write`. [On a Worker](#hosting-on-a-worker), it deploys to the Worker instead.
- The `preview` job in `site.yml`, with `wrangler.site.jsonc`, `.github/scripts/deploy-worker.sh`, `preview-retire.yml` and `preview-retire.sh`. These are the web app's own preview pieces, with the same lifecycle ([Pull request previews](#pull-request-previews)): a pull request that is open, not a draft and not opened by a bot gets the Worker `<slug>-site-pr-<number>`, and it comes down when the pull request closes or turns draft. The `-site` in the name keeps it apart from a web app's `<slug>-pr-<number>` in a repo that has both. The job deploys the build job's artifact, not a fresh build, under `/<repo>/` as Pages does, with a redirect from `/` (from `/` itself on a Worker), and sends `X-Robots-Tag: noindex`.

One-time setup:

1. Run `just repo-settings`. It creates the `preview` environment and sets GitHub Pages to deploy from Actions (Settings > Pages > Source: GitHub Actions).
2. Add the Cloudflare API token (Account > Workers Scripts: Edit) to the `preview` environment as `CLOUDFLARE_API_TOKEN`, and your account ID as `CLOUDFLARE_ACCOUNT_ID`. Without either secret, the preview job skips with a notice, and Pages still deploys.

A GitHub Pages site is public even when the repo is private, and a private repo needs a paid GitHub plan for Pages. Until Pages is on, the `deploy` job skips with a notice, and `just repo-settings` warns and goes on where GitHub refuses Pages.

The daily sweep finds preview Workers by name alone. In one Cloudflare account, a repo `foo` with a site and a repo `foo-site` with a web app would share the names `foo-site-pr-<number>`: rename one of them if that happens.

### Hosting on a Worker

`site_host=cloudflare` replaces Pages with the Worker `<slug>-site`, from the same `wrangler.site.jsonc` the previews use. The `deploy` job deploys the build job's artifact on every push to `main`, in the `production` environment, one at a time, and skips with a notice without the Cloudflare secrets. Previews serve the build from `/`, as production does, with no redirect. `site_url` is the site's address, and can be a custom domain; with `worker`, a Worker script answers `/api/*` ([Workers hosting](#workers-hosting)). A repo with a web app keeps `site_url` for the app, and the site stays at its workers.dev address.

The starter `astro.config.mjs` is the project's, so switching an existing Astro site from Pages leaves it alone: set `site` to the new address and delete `base`.

One-time setup: `just repo-settings` creates the `preview` and `production` environments instead of setting up Pages. Add both Cloudflare secrets to each.

## Workers hosting

What deploys to a Cloudflare Worker (a web app, or a site with `site_host=cloudflare`) shares two answers.

`site_url` is its public address. Give a host alone, without a path: a Worker serves a whole host. When the host is not `*.workers.dev`, it is a custom domain: the production job runs `wrangler deploy --domain <host>`, which attaches it to the Worker and creates its DNS record. The domain needs a zone in the same Cloudflare account, without a CNAME record for that host, and the production token needs Zone > Workers Routes: Edit for that zone. The domain is not in the wrangler config, because previews deploy that config under their own names and must not take it. `just repo-about` sets it as the repo's homepage.

`worker` adds a Worker script in front of the static assets, for server code such as an API. `main` in the wrangler config points at it, the `ASSETS` binding lets it hand a request to the files, and `run_worker_first: ["/api/*"]` sends only `/api/*` to it first. Every other request is served from the files without running the script, so it stays free; each request the script handles counts against the Workers plan. The starter has one route, `/api/health`, answers 404 for the rest of `/api/`, and passes anything else to the files.

- A web app gets `worker/index.ts`, with its own `worker/tsconfig.json` that swaps the DOM types for `@cloudflare/workers-types`. `pnpm run typecheck` checks both, and Vitest runs `worker/index.test.ts` in Node against a stub `ASSETS`. `pnpm dev` runs Vite alone; `pnpm exec wrangler dev` serves the last build and the script together.
- A site gets `site/worker/index.mjs`, plain JavaScript with no TypeScript stack needed. `just site` runs `site/worker/index.test.mjs` with `node --test` first, and a plain site's build leaves `worker/` out. wrangler bundles the script on every preview and production deploy, so a script that does not bundle fails the pull request's preview.

The script and its test are the project's after the first render. A binding beyond `ASSETS` (KV, D1, a secret) also reaches every preview: read [decision 0001](decisions/0001-pr-previews-use-the-production-cloudflare-account.md) first.

## OpenSSF Best Practices badge

`openssf_badge` configures documentation for the [OpenSSF Best Practices badge](https://www.bestpractices.dev):

- `passing`: adds testing and style sections to `.github/CONTRIBUTING.md`, and a `## Usage` section to `README.md` that links the releases and the package registry, with a TODO for what the software does and how to use it.
- `silver`: adds `GOVERNANCE.md`, `docs/roadmap.md`, and `docs/assurance-case.md`, and the `dco` workflow checks every pull request, not only fork ones. The `dco-signoff` commit-msg hook (`git commit -s`) comes with every public render.

A public render with `passing` meets every MUST criterion of the passing level that a file or a repository setting can meet. The rest depend on you, or on the project's history.

### Before you register

1. Push the repository to GitHub and run `just repo-settings`. It protects `main` against direct pushes and deletion, and turns on secret scanning with push protection, private vulnerability reporting and CodeQL default setup.
2. Replace the TODO in the README's `## Usage` section. Say what the software does and the problem it solves, then show its basic use.
3. Write doc comments for the public API. They are its reference documentation. In Python, ruff's `D` rules ask for them.
4. Turn on two-factor authentication for your GitHub account. For a repository in an organization, also require it under the organization's Settings > Authentication security.
5. Make a release with `just release X.Y.Z`. Its notes are the CHANGELOG section for that version.

### Register

1. Open <https://www.bestpractices.dev/en/projects/new> and log in with GitHub.
2. Under "Select a GitHub repository", pick the repository. Both URL fields take `https://github.com/OWNER/REPO`, unless the project has a home page of its own.
3. Under "Badge series", pick "metal" for passing and silver, or "baseline" for OSPS Baseline level 1. Then select "Submit Project".
4. Answer the criteria. bestpractices.dev fills in some from the repository. Give the file as the URL where a criterion asks for one.

The render cannot answer these for you:

- `know_secure_design` and `know_common_errors`: a primary developer knows secure design and the common kinds of vulnerability for this kind of software.
- `maintained`, `report_responses` and `enhancement_responses`: you reply to issues. `.github/CONTRIBUTING.md` promises a reply within about two weeks.
- `vulnerability_report_response`: you reply to a vulnerability report within 14 days, as `.github/SECURITY.md` promises.
- `tests_are_added`, `warnings_fixed`, `static_analysis_fixed`, `vulnerabilities_fixed_60_days` and `dynamic_analysis_fixed`: the project's history shows it.
- `dynamic_analysis` (suggested): `test_extras=[property]` adds property tests.

Add the badge to `README.md` once bestpractices.dev awards it.

### OSPS Baseline level 1

Where a public render meets each level 1 control of [OSPS Baseline v2026.08.28](https://baseline.openssf.org/versions/2026-08-28) (level 1 is the same set of controls as in v2026.02.19):

| Control | Met by |
|---|---|
| AC-01.01 | You: two-factor authentication, step 4 above |
| AC-02.01 | GitHub: a new collaborator gets the permission you assign |
| AC-03.01, AC-03.02 | `.github/rulesets/main.json`, applied by `just repo-settings` |
| BR-01.01, BR-01.03 | No `pull_request_target` workflows; untrusted input reaches `run:` only through `env:`; the zizmor hook checks both |
| BR-03.01, BR-03.02 | GitHub and the package registries serve HTTPS only |
| BR-07.01 | The `betterleaks` hook, and push protection from `just repo-settings` |
| DO-01.01 | You: the README's `## Usage` section, step 2 above |
| DO-02.01, GV-02.01, GV-03.01 | `.github/CONTRIBUTING.md` and GitHub issues |
| LE-02.01 to LE-03.02 | `LICENSE` and `LICENSES/` in the repository, so each release's source archive has them too |
| QA-01.01, QA-01.02 | The public GitHub repository and its git history |
| QA-02.01 | The stack's manifest and lockfile, such as `pyproject.toml` and `uv.lock` |
| QA-04.01 | Not applicable to a single repository |
| QA-05.01, QA-05.02 | `.gitignore` and the `check-added-large-files` hook |
| VM-02.01 | `.github/SECURITY.md` |

## Dependency updates

`dependency_bot` selects your automated update tool:

- **Dependabot** (default): built into GitHub; updates dependencies, workflows, and hook SHAs without external apps.
- **Renovate:** install the [Renovate GitHub App](https://github.com/apps/renovate), then run:

  ```sh
  copier update --data dependency_bot=renovate
  ```

  Disable Dependabot automated security fixes (`gh api -X DELETE repos/OWNER/REPO/automated-security-fixes`) while leaving security alerts active.

## Spelling and link checks

Two git hooks validate prose:

- `typos`: detects spelling errors in code, comments, and documentation. Add project-specific terms to `_typos.toml` at the repository root:

  ```toml
  [default.extend-words]
  ue = "ue"
  ```

- `lychee`: validates links. The local git hook runs offline and checks relative paths. The weekly workflow `.github/workflows/links.yml` checks both internal and external web links.

## How much documentation

The amount of documentation depends on the project's audience, not the size of its codebase:

| Tier | Audience | What it has |
| --- | --- | --- |
| 0: README only | Apps, tools, and experiments with no outside users | What the project is, its status line, and how to run or develop it. |
| 1: README plus `docs/` | Anything others install: published packages, libraries, or CLIs | A README under about 1,000 words serving as the front page (overview, install, quickstart, and links into `docs/`). `docs/` in Markdown, split following [Diátaxis](https://diataxis.fr/) (tutorials, how-to guides, reference, and explanation). The reference (CLI flags, configuration, schema) is generated or tested against the code. |
| 2: A documentation site | A tier-1 repository with extensive reference material | A search-indexed site built from the same Markdown files in `docs/`, never maintained as separate copy. |

### Moving up a tier

- **0 to 1:** The first release to a package registry (such as PyPI, npm, or crates.io), or when someone other than the author begins using the project.
- **1 to 2:** The reference is too large to browse comfortably as repository files; outside users need search or versioned documentation; or outside users file issues requesting documentation improvements. Automatic API documentation on docs.rs does not count toward this trigger.

### Decision records

`decision_records` adds `docs/decisions/`: a [MADR 4.0.0](https://adr.github.io/madr/) index and a
first record that says the project starts from this template. It is on for kinds whose choices are
costly to reverse, and off for small tools, which never get an empty folder. The index and the first
record are the project's after the first render.

### Documentation rules

- **Full URLs in package READMEs:** PyPI, npm, and crates.io render the project's `README.md` on their package pages. Relative links break when viewed on registry sites, so links to repository files and directories use absolute GitHub URLs (`https://github.com/<owner>/<repo>/...`). A render with `publish_to_pypi` or `publish_to_npm` writes its README links this way.
- **Stable links to documentation on `main`:** When documentation or CLI error messages link to rules or guides, point to `main`. Rule identifiers are permanent; if a rule is deprecated or removed, keep a stub heading so historical links continue to resolve.
- **Single source of truth:** The README holds the overview and quickstart; code comments and docstrings define API contracts; `docs/` holds extended guides and references.

## Adopting the template in an existing repo

Each guide renders over the repo on a clean branch with `copier copy --overwrite`, then has
you review `git diff` and restore what was yours.

### Adopting the template in an existing Python package

1. On a clean branch, render the template:

   ```sh
   copier copy --vcs-ref=<tag> --overwrite gh:simonvanlierde/project-templates .
   ```

   Enable `customise`, specify `module_name`, and select `python_layout=flat` if code resides at repository root rather than under `src/`.
2. Review `git diff` for `pyproject.toml`. Restore dependencies, authors, and version numbers, then run `just py-sync`.
3. Format with `uv run ruff format`. For existing lint or type check findings, record baseline exceptions rather than disabling rules:
   - Ruff: add existing violation codes to `ignore` in `pyproject.toml` under a `# NOTE: baseline at adoption` comment.
   - ty: configure existing violations as `"warn"` under `[tool.ty.rules]`.
4. If `uv audit` flags patches under a week old, add temporary exemptions under `[tool.uv]` in `pyproject.toml` ([tooling](tooling.md#dependencies)).
5. Remove obsolete workflows, run `just check` and `just hooks`, and commit.
6. Ensure `CHANGELOG.md` contains Keep a Changelog `## [X.Y.Z]` headings for release tagging.

### Adopting the template in an existing web app

1. On a clean branch, render over the repository:

   ```sh
   copier copy --vcs-ref=<tag> --overwrite gh:simonvanlierde/project-templates .
   ```

   Select `ts_kind=web-app`, your framework, and your `user_data` setting.
2. Review `git diff`:
   - Remove unused starter components.
   - Integrate the legal page routes and links into your `src/App.tsx`. Add the paths to `tests/e2e/routes.ts`, and set its `LEGAL_LINKED_FROM` to the routes that link the legal pages.
   - Restore custom configurations in `vite.config.ts` and `vitest.config.ts`. Retain the template's `markdown()` plugin.
   - Restore custom package names in `package.json` and `wrangler.jsonc`.
   - Fill in all TODO markers in `docs/`.
3. Run `pnpm install`. If dependencies are newer than the one-week cooldown, exempt them in `pnpm-workspace.yaml`:

   ```yaml
   minimumReleaseAgeExclude:
     - vite@8.3.5
   ```

4. Move inline scripts from `index.html` into files under `public/` to satisfy `script-src 'self'`.
5. Run `just check` and `just ts-e2e`. Remove legacy workflows replaced by `ts.yml` and commit.

### Adopting the template in an existing Compose-only repo

1. On a clean branch, render over the repo:

   ```sh
   copier copy --vcs-ref=<tag> --overwrite --data 'stacks=[docker]' gh:simonvanlierde/project-templates .
   ```

2. The render keeps an existing `compose.yaml` and `.env.example`, and replaces the justfile.
   `just check` reads `.env.example` in place of `.env`, so give every variable a `${VAR:?}`
   needs there.
3. Move your own recipes into `just/local.just`, which updates never touch. Name the checks
   you add `local-check`: `just check` runs that recipe last.
4. The `docker-compose` entry in `.github/dependabot.yml` reads `compose.yaml` and the
   directories one level below it, where an `include:` usually points. A deeper Compose file
   needs its directory added there. `copier update` keeps that edit unless the template
   changes the same lines, which shows up as a conflict.
5. Run `just check` and `just hooks`. Add the words typos flags in your own files to
   `_typos.toml`, which is yours from then on. Then commit.
