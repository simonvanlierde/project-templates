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
| `openssf_badge` | None ([OpenSSF Best Practices badge](#openssf-best-practices-badge)) |
| `module_name`, `go_module` | Derived from project name and GitHub user |
| `python_version`, `python_min`, `node_version`, `rust_version`, `go_version` | Current stable releases; `python_min` defaults two minor versions below |
| `publish_to_pypi`, `publish_to_npm`, `publish_to_ghcr` | Disabled ([Publishing](#publishing)) |
| `test_extras` | None ([Test extras](#test-extras)) |
| `app_port` | 8000 |
| `site_url` | `https://<project>.pages.dev` (Cloudflare Pages default) |

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
- In public repositories, requires one approving review submitted after the latest push. Required checks reside in `.github/rulesets/main-checks.json`.
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

Decision records reside in `docs/decisions/`. Copy `0000-template.md` to record architectural choices and list new records in `README.md`.

## TypeScript kinds

`ts_kind` configures the package target:

| Kind | Target |
| --- | --- |
| `library` | ES module compiled by `tsc` to `dist/`, publishable to npm |
| `app` | Node application compiled to `dist/`, not published |
| `web-app` | Single-page application built with Vite for Cloudflare Pages |

`web-app` prompts for `web_framework` (React or Preact) and `user_data` ([legal pages](#legal-pages)). Web apps include:

- Single-page application entry points (`index.html`, `src/main.tsx`, `src/App.tsx`) and Vitest setup.
- Playwright end-to-end tests in `tests/e2e/`: axe accessibility scans in light/dark modes and Content-Security-Policy enforcement.
- Mandatory legal pages linked from the footer.
- Cloudflare Pages configuration: `public/_headers` (security headers) and `wrangler.jsonc`.
- Bundle size budget in `scripts/checkBundleBudget.mjs`.

Cloudflare Pages deploys via Git integration: configure build command `pnpm build`, output directory `dist`, and set the root directory to `ts_dir` for nested apps.

Copier updates do not overwrite user-owned starter files: `src/App.tsx`, `src/App.test.tsx`, `src/main.tsx`, `src/app.css`, `index.html`, `tests/e2e/routes.ts`, and markdown files in `docs/`.

### Legal pages

Legal documents reside in `docs/` and compile to HTML at build time:

| Document | Route | Generation condition |
| --- | --- | --- |
| `docs/accessibility.md` | `/accessibility` | Always |
| `docs/privacy.md` | `/privacy` | Always (includes storage disclosure) |
| `docs/terms.md` | `/terms` | `user_data=accounts` |

`user_data` options: `nothing`, `browser` (local storage only), or `accounts` (server-side data). Playwright tests in `tests/e2e/` verify these pages render without TODO markers, contain required contact information, and introduce no undeclared storage or network requests.
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

User-owned files are never overwritten: `README.md`, `CHANGELOG.md`, citation files (`CITATION.cff`, `codemeta.json`), `docs/decisions/README.md`, silver-badge governance documents, web app starter code, `<package>.api.md`, and `go.mod`.

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

Mutation testing runs weekly via `.github/workflows/mutation.yml` and on demand via `just <stack>-mutation`. Surviving mutants fail the Rust job; other stacks report survivors in the job summary.

To add extras to an existing project:

```sh
copier update --data 'test_extras=[property]'
```

## Publishing

To publish a release:

1. Add a `## [X.Y.Z]` heading with notes to `CHANGELOG.md`.
2. Update versions in `pyproject.toml` and `package.json` to match `X.Y.Z`.
3. Commit and push tag `vX.Y.Z`.

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
2. In repository Settings > Environments, create required environments (`pypi`, `npm`, `ghcr`). Restrict deployment to tags matching `v*` and require manual review.
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
