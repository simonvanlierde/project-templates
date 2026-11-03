# Using the template

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
| `docker_stacks` | `docker` stack selected | Selects which packages receive a Dockerfile and Compose service |

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
| `openssf_badge` | None ([OpenSSF Best Practices badge](#openssf-best-practices-badge)) |
| `module_name`, `go_module` | Derived from project name and GitHub user |
| `python_version`, `python_min`, `node_version`, `rust_version`, `go_version` | Current stable releases; `python_min` defaults two minor versions below |
| `publish_to_pypi`, `publish_to_npm`, `publish_to_ghcr` | Disabled ([Publishing](#publishing)) |
| `test_extras` | None ([Test extras](#test-extras)) |
| `app_port` | 8000 |
| `site_url` | `https://<project>.<github_user>.workers.dev` (the Worker's workers.dev address, if the account's subdomain is the GitHub user) |

During `copier update`, previously configured answers are preserved even when `customise` is `no`. Change an individual setting with `copier update --data <key>=<value>` or prompt for a single setting with `copier update --ask <key>`.

To bypass prompts during initial generation, supply values via `--data-file answers.yml` or pass flags with `--data`.

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

## Licenses

Available code licenses:

- **MIT** (default): permissive reuse with attribution.
- **Apache-2.0**: permissive reuse with an explicit patent grant.
- **BSD-3-Clause**: permissive reuse prohibiting endorsement without permission.
- **GPL-3.0-or-later**: copyleft requiring derivative works to remain GPL-licensed.
- **AGPL-3.0-or-later**: network copyleft covering hosted network services.

`data-pipeline` and `research` projects configure `data_license` for files under `data/`. Research data defaults to CC-BY-4.0. Data pipelines default to CC0-1.0 because they commit only fetch logs; pipeline outputs inherit their respective source licenses.

Licensed projects follow the [REUSE specification](https://reuse.software). `REUSE.toml` declares copyright and licensing rules, full texts reside in `LICENSES/`, and the `reuse` git hook checks compliance. External files copied into the repository must include `SPDX-FileCopyrightText` and `SPDX-License-Identifier` headers or corresponding entries in `REUSE.toml`.

## Protecting main

`just repo-settings` applies `.github/rulesets/main.json` using the GitHub CLI:

- Blocks force-pushes and branch deletions.
- Enforces linear history and squash merges.
- Requires pull requests with passing checks: `git hooks`, `pull request title`, `dependency review`, and `DCO sign-off`.
- In public repositories, requires one approving review submitted after the latest push. Required checks reside in `.github/rulesets/main-checks.json`, which also requires each stack's own check (`ts: lint, types, tests` and so on) for a stack at the repo root. A nested stack's workflow runs only when its folder changes, so its check is not required.
- With `dependency_bot=renovate`, permits the Renovate app to bypass review for minor and patch updates once required checks pass.
- Applies `.github/rulesets/tags.json` to restrict `v*` tag creation to repository administrators.
- Enables Dependabot security alerts (`gh api -X PUT repos/OWNER/REPO/vulnerability-alerts`).

Execute `just repo-settings` once after creating the repository and again whenever ruleset templates change. Requires administrative permissions.

## The GitHub About box

`just repo-about` syncs repository metadata with `gh repo edit`:

- Updates repository description from `project_description`.
- Sets homepage URL from `site_url` for web apps.
- Adds stack topics (`python`, `typescript`, `rust`, `go`, `docker`). Existing manual topics are preserved.

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

### Documentation rules

- **Full URLs in package READMEs:** PyPI, npm, and crates.io render the project's `README.md` on their package pages. Relative links break when viewed on registry sites, so links to repository files and directories use absolute GitHub URLs (`https://github.com/<owner>/<repo>/...`). A render with `publish_to_pypi` or `publish_to_npm` writes its README links this way.
- **Stable links to documentation on `main`:** When documentation or CLI error messages link to rules or guides, point to `main`. Rule identifiers are permanent; if a rule is deprecated or removed, keep a stub heading so historical links continue to resolve.
- **Single source of truth:** The README holds the overview and quickstart; code comments and docstrings define API contracts; `docs/` holds extended guides and references.

## Choosing your stacks

Select any combination of stacks:

| Stack | Features added |
| --- | --- |
| `python` | Python package with `pyproject.toml`, `src/`, `tests/`, and uv tooling |
| `ts` | TypeScript package or Vite web app ([kinds](#typescript-kinds)) |
| `rust` | Rust crate (library or binary) with strict clippy rules |
| `go` | Go module (library or binary) with golangci-lint |
| `docker` | Dockerfile for Python or TypeScript packages and root `compose.yaml` |

Each stack includes a CI workflow in `.github/workflows/` and recipes in `just/<stack>.just`. All projects receive `README.md`, `CHANGELOG.md`, `LICENSE`, `REUSE.toml`, `.gitignore`, `.editorconfig`, dependency bot configuration, git hooks, and `AGENTS.md`. Python projects select a [kind](python-kinds.md).

CLI binaries (Rust, Go, or Python `data-pipeline`) include `docs/accessibility.md`, documenting terminal output standards (`NO_COLOR` support, plain output redirection, error formats). Review and edit these claims to reflect your application.

When projects record architectural choices, store them in `docs/decisions/`.

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
- Cloudflare Worker configuration: `public/_headers` (security headers) and `wrangler.jsonc` (static assets, no Worker script).
- A `production` job in `.github/workflows/ts.yml` that deploys `main`.
- `just ts-shots`: full-page screenshots of every route at 390 and 1440 px, light and dark, in `shots/`, to attach to a pull request that changes the UI.
- Pull request previews: a `preview` job in `.github/workflows/ts.yml`, `.github/workflows/preview-retire.yml` and `.github/scripts/preview-retire.sh`.
- Bundle size budget in `scripts/checkBundleBudget.mjs`: 100 KiB of gzipped JavaScript in the largest file. It catches a heavy dependency or a broken chunk split, not ordinary features, so keep it at least 25% above the build rather than just above it.

### Production

Every push to `main` runs the `production` job after the checks pass. It deploys the build the checks ran on to the Worker `<slug>`, with the pinned wrangler, at `https://<slug>.<subdomain>.workers.dev`. Static-asset requests are free and unlimited on the Workers Free plan. The job runs in the `production` GitHub environment, which `just repo-settings` limits to `main`. One deploy runs at a time, and a deploy in flight is never cancelled by the next. Without `CLOUDFLARE_API_TOKEN`, the job skips with a notice. For a custom domain, add it under the Worker's Settings > Domains & Routes. The domain needs a zone on Cloudflare.

#### Moving an app off Cloudflare Pages

An app made before this template deployed from CI was deployed by Cloudflare Pages. To move it:

1. Merge the `copier update`, then run `just repo-settings` and add both secrets to the new `production` environment.
2. The next push to `main` deploys the Worker. Check the app at its workers.dev address.
3. Move the custom domain from the Pages project to the Worker (Worker > Settings > Domains & Routes).
4. Delete the Pages project, now that the Worker serves production.

Without a custom domain, the app's address changes: set the new one with `copier update --data site_url=https://<slug>.<subdomain>.workers.dev`.

### Pull request previews

Each pull request that is open, not a draft and not opened by a bot such as Renovate gets its own Cloudflare Worker, `<slug>-pr-<number>`, at `https://<slug>-pr-<number>.<subdomain>.workers.dev`. The `preview` job deploys `wrangler.jsonc` under that name. The job summary and the pull request's deployment show the link. Previews are public, and they send `X-Robots-Tag: noindex`. The job adds that header to the deployed copy of the build only, so `public/_headers` and production never carry it. The job reads the pull request again right before deploying, in case it closed while the job was queued.

When a pull request closes or turns draft, `preview-retire.yml` deletes its Worker through the Cloudflare API. It then fetches the address and fails unless it answers 404, which shows the Worker is gone. A daily run lists the account's `<slug>-pr-<number>` Workers and deletes those whose pull request is not open and ready, in case an event was missed. When it cannot read a pull request, it keeps that Worker and fails. To retire previews by hand, run that workflow with a list of pull request numbers, or with the list empty to run the sweep. The workflow runs `.github/scripts/preview-retire.sh`.

Fork pull requests and repos without `CLOUDFLARE_API_TOKEN` skip the job with a notice. One-time setup:

1. Run `just repo-settings`. It creates the `preview` and `production` environments in GitHub (or create them under Settings > Environments, with `production` limited to `main`).
2. Create a custom Cloudflare API token with the permission Account > Workers Scripts: Edit. Add it to both environments as the secret `CLOUDFLARE_API_TOKEN`, and add your account ID as `CLOUDFLARE_ACCOUNT_ID`.

The first deploy creates each Worker, so there is nothing to set up in Cloudflare except the token. The account needs a workers.dev subdomain. The wrangler version is pinned in `ts.yml`, and `copier update` brings new versions.

Copier updates do not overwrite user-owned starter files: `src/App.tsx`, `src/App.test.tsx`, `src/main.tsx`, `src/app.css`, `index.html`, `tests/e2e/routes.ts`, and markdown files in `docs/`.

### Legal pages

Legal documents reside in `docs/` and compile to HTML at build time:

| Document | Route | Generation condition |
| --- | --- | --- |
| `docs/accessibility.md` | `/accessibility` | Always |
| `docs/privacy.md` | `/privacy` | Always (includes storage disclosure) |
| `docs/terms.md` | `/terms` | `user_data=accounts` |

`user_data` options: `nothing`, `browser` (local storage only), or `accounts` (server-side data). Playwright tests in `tests/e2e/` verify these pages render properly, contain required contact information, and introduce no undeclared storage or network requests. They also check that every route in `LEGAL_LINKED_FROM` links each page and that each page links back to `/`. The starter's `LEGAL_LINKED_FROM` in `tests/e2e/routes.ts` is all of `ROUTES`; an app that links the pages from one screen, such as its settings, sets it to that screen.
See [`docs/web-legal.md`](https://github.com/simonvanlierde/project-templates/blob/main/docs/web-legal.md) for compliance guidance.

### Adopting the template in an existing web app

1. On a clean branch, render over the repository:

   ```sh
   copier copy --vcs-ref=<tag> --overwrite gh:simonvanlierde/project-templates .
   ```

   Select `ts_kind=web-app`, your framework, and your `user_data` setting.
2. Review `git diff`:
   - Remove unused starter components.
   - Integrate legal page routes and footer links into your `src/App.tsx`, and add paths to `tests/e2e/routes.ts`.
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

## Adopting the template in an existing Python package

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

## One package or a monorepo

By default, packages reside at the repository root. To host multiple packages, enable `customise` and assign distinct directory paths (for example, `python_dir: apps/api` and `ts_dir: apps/web`):

```text
apps/api/{pyproject.toml,src,tests,Dockerfile,.dockerignore}
apps/web/{package.json,tsconfig.json,biome.json,src,Dockerfile,.dockerignore}
compose.yaml
.github/workflows/
justfile, just/, .pre-commit-config.yaml, .copier-answers.yml
```

Workflows and configuration files remain at the repository root. Two packages may share the root directory, but two Docker images cannot because both Dockerfiles would collide at `./Dockerfile`.

## Keeping your project up to date

`copier update` performs a three-way merge against the latest template release.

User-owned files are never overwritten: `README.md`, `CHANGELOG.md`, citation files (`CITATION.cff`, `codemeta.json`), silver-badge governance documents, web app starter code, `<package>.api.md`, and `go.mod`.

To relocate a package directory, execute `copier update` with the new path and delete the old directory manually.

If upgrading from pre-v0.12.0 projects with `docs/adr/`, move existing records to `docs/decisions/` and remove `docs/adr/`.

After updating, refresh and commit project lockfiles (`uv lock`, `pnpm install`, `just go-sync`).

### Hearing about new releases

- **Renovate:** Automatically opens update PRs using `copier update --skip-answered --defaults`. Inspect PR diffs for conflict markers before merging.
- **Dependabot:** The `.github/workflows/copier-update.yml` workflow runs weekly and on demand. When updates exist, it opens a PR on branch `chore/copier-update`.

To allow `copier-update.yml` to update workflow files in `.github/workflows/`, generate a fine-grained personal access token with Contents, Pull Requests, and Workflows write access, and save it as secret `COPIER_UPDATE_TOKEN`.

Without this secret, workflow changes open an issue requesting a manual local update.

## Test extras

Library kinds configure `test_extras` under `customise`:

| Option | Python | TypeScript | Rust | Go |
| --- | --- | --- | --- | --- |
| `property` | Hypothesis | fast-check | proptest | Native fuzz test (`FuzzAdd`) |
| `mutation` | mutmut (`just py-mutation`) | Stryker (`just ts-mutation`) | cargo-mutants (`just rs-mutation`) | gremlins (`just go-mutation`) |

Property tests run fast suites locally and in CI. Weekly scheduled jobs (`.github/workflows/property.yml`) execute extended runs (10,000 cases or 10 minutes of fuzzing).

Mutation testing runs weekly via `.github/workflows/mutation.yml` and on demand via `just <stack>-mutation`. The Python and Rust jobs fail on a surviving mutant. The TypeScript and Go tools exit 0 when a mutant survives, so those jobs only print survivors.

Python: `just py-mutation` fails on a survivor (a mutant the tests miss, or that no test reaches) that is not in `tests/mutation-baseline.txt`. It also fails on a listed mutant that no longer survives, so the list stays true. Each line is the mutant name, then the reason. List a mutant only when no test could see the change. Mutant numbers shift when their function changes, so recheck the lines then. `copier update` adds the file with no entries; run the recipe once and list what it reports.

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

## Publishing

To publish a release:

1. Set the version in `pyproject.toml` and `package.json` to `X.Y.Z` (only the one you publish). A citable project sets it in every manifest `citesync.toml` lists, or in every manifest at the root when it has no `citesync.toml`.
2. Run `just release X.Y.Z`. It checks that version and, in a citable project, runs the citesync hook, then cuts `## [Unreleased]` in `CHANGELOG.md` into `## [X.Y.Z] - date`, fixes the compare links and commits.
3. Merge that commit to `main`, then run `just release X.Y.Z` again on up-to-date `main`. It signs the annotated tag `vX.Y.Z` on `origin/main`, checks it with `git verify-tag` and pushes it. The release workflow refuses a tag GitHub cannot verify, so set `user.signingkey` first (an ssh key works with `gpg.format ssh`).

A render has no "Releasing" section in its README: the maintainer is the only reader, so the steps live here and in the rendered CONTRIBUTING.

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

`codspeed` (Python and Rust) adds `.github/workflows/benchmarks.yml` and starter benchmarks (`tests/test_benchmarks.py` or `benches/codspeed.rs`). CodSpeed measures CPU instruction counts in simulation on PRs and pushes to `main`.

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

## OpenSSF Best Practices badge

`openssf_badge` configures documentation for the [OpenSSF Best Practices badge](https://www.bestpractices.dev):

- `passing`: adds testing and style sections to `.github/CONTRIBUTING.md`.
- `silver`: adds `GOVERNANCE.md`, `docs/roadmap.md`, and `docs/assurance-case.md`. Enforces DCO sign-offs on all commits (`git commit -s`) via the commit-msg hook.

Submit the questionnaire on bestpractices.dev and add the resulting markdown badge to `README.md`.

## Dependency updates

`dependency_bot` selects your automated update tool:

- **Dependabot** (default): built into GitHub; updates dependencies, workflows, and hook SHAs without external apps.
- **Renovate:** install the [Renovate GitHub App](https://github.com/apps/renovate), then run:

  ```sh
  copier update --data dependency_bot=renovate
  ```

  Disable Dependabot automated security fixes (`gh api -X DELETE repos/OWNER/REPO/automated-security-fixes`) while leaving security alerts active.
