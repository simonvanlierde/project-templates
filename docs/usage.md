# Using the template

The [README](https://github.com/simonvanlierde/project-templates/blob/main/README.md#quick-start) shows how to start a project. This page is the
reference for the render: [the questions](#the-questions) and [presets](#presets),
[stacks](#choosing-your-stacks) and [kinds](python-kinds.md),
[Compose-only repos](#compose-only-repos), [monorepos](#one-package-or-a-monorepo),
[licenses](#licenses) and the [optional features](#optional-features), which you can turn
on at any time with `copier update`.

The other jobs have their own pages, in the order you are likely to need them:

- [Setting up the repo](setup.md): [public repos](setup.md#public-repos),
  [protecting `main`](setup.md#protecting-main), [the About box](setup.md#the-github-about-box)
  and [publishing](setup.md#publishing).
- [Hosting](hosting.md): a [static site](hosting.md#static-site), web apps and sites on a
  [Cloudflare Worker](hosting.md#hosting-on-a-worker),
  [pull request previews](hosting.md#pull-request-previews) and the
  [social card](hosting.md#social-card).
- [Updates](updates.md): [template updates](updates.md#keeping-your-project-up-to-date),
  the [dependency bot](updates.md#dependency-updates), and
  [adopting the template](updates.md#adopting-the-template-in-an-existing-repo) in a repo
  you already have.
- [Levels](levels.md): what a public repo commits to, and the
  [OpenSSF badge](levels.md#openssf-best-practices-badge).

## The questions

A new project asks at most ten questions for a single stack (eleven for a web app). The
rest wait behind `customise`, and take the defaults below when you answer no:

| Question | Prompted when | Effect |
| --- | --- | --- |
| `project_name` | Always | Repository, directory, package, crate, and image names |
| `project_description` | Always | One-line summary for README, package metadata, and citation files |
| `stacks` | Always | Selected packages, CI workflows, and `just` recipes |
| `python_kind`, `ts_kind`, `rust_kind`, `go_kind` | Respective stack selected | Package architecture, directory layout, and CI configuration |
| `web_framework` | `ts_kind=web-app` | React, or Preact for reduced bundle size |
| `user_data` | `ts_kind=web-app` | Sets the content of the privacy statement and the terms page ([legal pages](#legal-pages)) |
| `public` | Always | Adds `.github/` community files and sets default license |
| `github_user`, `author_name`, `author_email` | Always | Repository URLs, badges, licenses, and package metadata |
| `customise` | Always | `yes` asks the advanced questions; `no` accepts their defaults |
| `author_orcid` | Licensed `library`, or Python `research`/`data-pipeline` | Citation metadata |
| `docker_image` | `docker` and `python` stacks selected | Builds the Python package into an image with a Dockerfile and Compose service; no for a [Compose-only repo](#compose-only-repos) |

Identity answers have no defaults. To skip the prompts, pass answers with `--data` or an
answers file. The command uses `kind`, which works before and after its rename to
`python_kind`:

```sh
copier copy --data 'stacks=[python]' --data kind=research gh:simonvanlierde/project-templates .
copier copy --data-file answers.yml gh:simonvanlierde/project-templates .
```

The advanced questions and their defaults:

| Question | Default |
| --- | --- |
| `license`, `copyright_year` | MIT if `public`, otherwise none; current calendar year |
| `data_license` | CC-BY-4.0 for `research`, CC0-1.0 for `data-pipeline`; none without a license ([Licenses](#licenses)) |
| `python_dir`, `ts_dir`, `rust_dir`, `go_dir` | `.` (package located at repository root) |
| `python_layout` | `src` (`src/<module>`); choose `flat` when [adopting in existing packages](updates.md#adopting-the-template-in-an-existing-python-package) |
| `dependency_bot` | Dependabot |
| `site` | None ([Static site](hosting.md#static-site)) |
| `site_host` | GitHub Pages; `cloudflare` deploys the site to a Worker ([Static site](hosting.md#static-site)) |
| `worker` | Disabled; a Worker script for `/api/*` in a web app or a site on Cloudflare ([Worker script](hosting.md#worker-script)) |
| `extras` | `cold_install` at `standard` and `community`; otherwise none ([Optional features](#optional-features)) |
| `level` | `standard` for a public repo with a license ([Levels](levels.md)) |
| `decision_records` | On for `web-service`, `data-pipeline`, `web-app`, Compose-only and `community`-level projects ([Decision records](#decision-records)) |
| `module_name`, `go_module` | Derived from project name and GitHub user |
| `python_version`, `python_min`, `node_version`, `go_version` | Current stable releases; `python_min` defaults two minor versions below |
| `rust_version` | The crate's minimum supported Rust version (`rust-version` in `Cargo.toml`), the current stable minor by default |
| `python_api` | Enabled ([API-break check](#api-break-check)) |
| `publish_to_pypi`, `publish_to_npm`, `publish_to_ghcr` | Disabled ([Publishing](setup.md#publishing)) |
| `app_port` | 8000 |
| `site_url` | `https://<project>.<github_user>.workers.dev` (`<project>-site` for a site on Cloudflare), which is right when the account's subdomain is the GitHub user. Another host is a custom domain ([Custom domains](hosting.md#custom-domains)) |

During `copier update`, earlier answers stay even when `customise` is `no`. Change one setting with `copier update --data <key>=<value>`, or be asked for one with `copier update --ask <key>`.

### Presets

`presets/` holds the answers for repo kinds that come up again and again. A preset fills
the project-kind questions; Copier still asks the identity ones.

| Preset | Repo |
| --- | --- |
| `rust-cli.yml` | A Rust command-line tool |
| `uv-research.yml` | A Python research package with notebooks, data and citation files |
| `compose-deploy.yml` | A [Compose-only](#compose-only-repos) deploy repo with decision records |

Pass one with `--data-file`, which reads a local path. Use the same release tag for
the preset and the template:

```sh
curl -fsSLo /tmp/preset.yml https://raw.githubusercontent.com/simonvanlierde/project-templates/v0.14.0/presets/rust-cli.yml
copier copy --vcs-ref=v0.14.0 --data-file /tmp/preset.yml gh:simonvanlierde/project-templates my-tool
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

Each stack adds a CI workflow in `.github/workflows/` and recipes in `just/<stack>.just`. Every project gets `README.md`, `CHANGELOG.md`, `.gitignore`, `.editorconfig`, dependency bot configuration, git hooks and `AGENTS.md`. A licensed project also gets `LICENSE` and `REUSE.toml`. A Python project picks a [kind](python-kinds.md).

A command-line binary (Rust, Go, or Python `data-pipeline`) gets `docs/accessibility.md`, which documents its terminal output (`NO_COLOR` support, plain output when redirected, error formats). Edit its claims to match your application.

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
- Cloudflare Worker configuration: `public/_headers` (security headers) and `wrangler.jsonc` (static assets, and with `worker` a Worker script for `/api/*`: [Worker script](hosting.md#worker-script)).
- A `production` job in `.github/workflows/ts.yml` that deploys `main`.
- `just ts-shots`: full-page screenshots of every route at 390 and 1440 px, light and dark, in `shots/`, to attach to a pull request that changes the UI.
- Pull request previews: a `preview` job in `.github/workflows/ts.yml`, `.github/workflows/preview-retire.yml` and `.github/scripts/preview-retire.sh`.
- Bundle size budget in `scripts/checkBundleBudget.mjs`: 100 KiB of gzipped JavaScript in the largest file. It catches a heavy dependency or a broken chunk split, not ordinary features, so keep it at least 25% above the build rather than just above it.

The starter app is yours after the first render. `copier update` never touches `src/App.tsx`, `src/App.test.tsx`, `src/main.tsx`, `src/app.css` or the Worker script, even to bring back one you deleted. It leaves `index.html`, `tests/e2e/routes.ts` and the Markdown files in `docs/` alone too, but re-creates one you delete.

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
Dockerfile of its own, answers `stacks=[docker]`. Any `stacks` with `docker` and without
`python` gives a Compose-only repo, since the template builds only a Python image. With the
python stack, answer no to `docker_image` (`--data docker_image=false`) to keep the package
without an image.

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

Packages sit at the repository root by default. To host several, answer yes to `customise` and give each stack its own directory, for example `python_dir: apps/api` and `ts_dir: apps/web`:

```text
apps/api/{pyproject.toml,src,tests,Dockerfile,.dockerignore}
apps/web/{package.json,tsconfig.json,biome.json,src}
compose.yaml
.github/workflows/
justfile, just/, .pre-commit-config.yaml, .copier-answers.yml
```

Workflows and configuration stay at the repository root. Two packages may share the root directory.

## Licenses

Available code licenses:

- **MIT** (default): permissive reuse with attribution.
- **Apache-2.0**: permissive reuse with an explicit patent grant.
- **BSD-3-Clause**: permissive reuse prohibiting endorsement without permission.
- **GPL-3.0-or-later**: copyleft requiring derivative works to remain GPL-licensed.
- **AGPL-3.0-or-later**: network copyleft covering hosted network services.

`data-pipeline` and `research` projects configure `data_license` for files under `data/`. Research data defaults to CC-BY-4.0. Data pipelines default to CC0-1.0 because they commit only fetch logs; pipeline outputs inherit their respective source licenses.

Licensed projects follow the [REUSE specification](https://reuse.software). `REUSE.toml` declares copyright and licensing rules, full texts reside in `LICENSES/`, and the `reuse` git hook checks compliance. External files copied into the repository must include `SPDX-FileCopyrightText` and `SPDX-License-Identifier` headers or corresponding entries in `REUSE.toml`.

## API-break check

With `publish_to_pypi`, a Python library gets an `api` job in `python.yml`. It runs griffe against the last git tag and fails when a public name loses or changes a parameter. Every name without a leading underscore counts as public.

A package used only through its command line has no Python API to protect. Answer `python_api=false` to drop the job:

```sh
copier update --data python_api=false
```

To keep the job and mark a module internal instead, start its name with an underscore (`_check.py`).

A Rust library always gets an `api` job in `rust.yml`, and `just rs-api` runs the same check locally. It runs [cargo-semver-checks](https://github.com/obi1kenobi/cargo-semver-checks) against the last `v*` tag and reads the version in `Cargo.toml`: a break passes only after a major bump, or a minor bump before 1.0. Before the first tag, it passes. `rs-check` leaves it out, so a deliberate break does not hold up the other checks.

## Decision records

`decision_records` adds `docs/decisions/`: a [MADR 4.0.0](https://adr.github.io/madr/) index and a
first record that says the project starts from this template. It is on for kinds whose choices are
costly to reverse, and off for small tools, which never get an empty folder. The index and the first
record are the project's after the first render.

## Optional features

`extras` is one multiselect under `customise`. Its values are `codecov`, `codspeed`,
`profiling`, `cold_install`, `python_windows`, `docs_site`, `property` and `mutation`.
Stack-specific values need their stack, and `property` and `mutation` need a library kind.
Publishing and hosting keep their own questions.

New public, licensed projects at `standard` or `community` start with `cold_install`.

To change the selection on an existing project:

- **Interactively:** run `copier update --ask extras`. The prompt starts from the current selection, so select what to add.
- **In a script:** pass the whole list. An explicit list replaces the selection, the `cold_install` default included.

  ```sh
  copier update --data 'extras=[cold_install,codecov,property]'
  ```

An update from v0.14.0 builds this list from the old yes/no answers and `test_extras`, and
keeps disabled features disabled, including `cold_install: false` at `standard`. The
answers file then stores only `extras`. Replace old `--data codecov=true` and
`--data 'test_extras=[...]'` arguments with the full `extras` list.

### Tests on Windows

`python_windows` adds a `windows` job to `python.yml`. It runs `uv run pytest` on `windows-latest` with `python_version`. A text file opened without `encoding="utf-8"`, a path built with `/`, or a POSIX-only module such as `fcntl` then fails CI, not a Windows user.

The job skips ruff and ty, which read the same code on every OS. It checks out the committed bytes, with no CRLF conversion, so a test that hashes a committed file passes. It costs one more job on every push and pull request, and Windows runners start slowly. With the Python package at the repo root, its check `python: tests (windows)` is required like the Linux ones.

Select `python_windows` in `extras` ([how](#optional-features)). Then run `just repo-settings`, so a public repo requires the new check.

### Coverage on Codecov

`codecov` (Python and TypeScript) uploads coverage reports to [Codecov](https://codecov.io). Pull requests fail only if overall coverage drops by more than 2 percentage points.

Setup:

1. Register the repository on Codecov and retrieve the upload token.
2. Save it as repository secret `CODECOV_TOKEN` (`gh secret set CODECOV_TOKEN`).
3. Select `codecov` in `extras` ([how](#optional-features)).

### Benchmarks on CodSpeed

`codspeed` (Python and Rust) adds `.github/workflows/benchmarks.yml` and starter benchmarks (`tests/test_benchmarks.py` or `benches/codspeed.rs`). CodSpeed measures CPU instruction counts in simulation on PRs that touch benchmarked code and on every push to `main`.

Setup:

1. Import the repository on [codspeed.io](https://codspeed.io).
2. Set Pull Request comments to "On Change" in CodSpeed repository settings.
3. Select `codspeed` in `extras` ([how](#optional-features)).

### Profiling

`profiling` (Python and Rust) adds profiling recipes:

- **Python:** `just py-profile <script or -m module> <args>` runs pyinstrument on demand via `uv run --with` without modifying dependencies.
- **Rust:** `Cargo.toml` adds a `[profile.profiling]` profile. `just rs-profile <command>` records performance profiles using [samply](https://github.com/mstange/samply); `just rs-counters <command>` executes `perf stat` five times to measure CPU cycles and branch misses. Requires local kernel perf event support.

Select `profiling` in `extras` ([how](#optional-features)).

### Test extras

A library kind can select `property` and `mutation` in `extras`:

| Option | Python | TypeScript | Rust | Go |
| --- | --- | --- | --- | --- |
| `property` | Hypothesis | fast-check | proptest | Native fuzz test (`FuzzAdd`) |
| `mutation` | mutmut (`just py-mutation`) | Stryker (`just ts-mutation`) | cargo-mutants (`just rs-mutation`) | gremlins (`just go-mutation`) |

Property tests run fast suites locally and in CI. Weekly scheduled jobs (`.github/workflows/property.yml`) execute extended runs (10,000 cases or 10 minutes of fuzzing).

Mutation testing runs weekly via `.github/workflows/mutation.yml` and on demand via `just <stack>-mutation`. The Python and Rust jobs fail on a surviving mutant. The TypeScript and Go tools exit 0 when a mutant survives, so those jobs only print survivors.

Python: `just py-mutation` fails on a survivor (a mutant the tests miss, or that no test reaches) that is not in `tests/mutation-baseline.txt`. It also fails on a listed mutant that no longer survives, so the list stays true. Each line is the mutant name, then the reason. List a mutant only when no test could see the change, and recheck the lines when a function changes, since mutant numbers shift. `copier update` adds the file with no entries: run the recipe once and list what it reports. To run only some mutants, give it mutmut patterns, such as `just py-mutation 'mypkg.core.x_parse__mutmut_*'`. That run skips the check for listed mutants that no longer survive.

A full run takes minutes to hours, so check each change with the diff recipe instead and keep the full run for the weekly job and before a release:

| Stack | Per-change recipe | What it runs |
| --- | --- | --- |
| Python | `just py-mutation-diff` | the mutants of functions and methods the branch changed since it split off `origin/main`, in the mutated modules (`just/mutation_diff.py` finds them) |
| Rust | `just rs-mutation-diff` | `cargo mutants --in-diff` on the branch's changes since it split off `origin/main` |
| Go | `just go-mutation-diff` | `gremlins unleash --diff` against the commit where the branch split off `origin/main` |
| TypeScript | none | Stryker has no diff mode. Its `--incremental` reuses the results file of an earlier run, which needs a stored file between runs, so the template adds no recipe |

Each takes another git ref, e.g. `just py-mutation-diff main`.

To add these tests to an existing project, select `property` or `mutation` in `extras` ([how](#optional-features)).

### Documentation site

Select `docs_site` in `extras` (under `customise`) when outside users need search or versioned docs (the `docs-site` requirement in [Levels](levels.md)): a search-indexed site built from the Markdown in `docs/`. [Zensical](https://zensical.org) builds it, and GitHub Pages serves it from `main` at `https://<user>.github.io/<repo>/`. The site reads the files in `docs/` as they are, so there is no second copy to keep in step. Without a `nav` in `zensical.toml`, the menu follows the files.

A render with `docs_site` gets:

- `zensical.toml` and `docs/index.md`, the home page. Both are yours: an update leaves them alone.
- `docs/og-card.html`, the social card, and `docs/assets/og.png` once you run `just og-card`. Commit the PNG.
- `docs/reference.md`, for a Python library with `python_api`. It holds one `::: <module>` line, which mkdocstrings expands into the API reference from the docstrings. It reads the source without importing the package.
- `just docs`, which builds into `_docs/` (gitignored), and `just docs-serve`, which serves the site on port 8000 and rebuilds it on each save. Both run the Zensical that `copier.yml` pins with `uvx`, so the project needs no docs dependencies. Like the project's own installs, uvx resolves only releases at least a week old. `copier update` brings a newer pin.
- `.github/workflows/docs.yml`. Every pull request and push to `main` runs `just docs`. In a public repo, `docs: build` is a required check. The `deploy` job publishes the build to Pages on a push to `main`. `just repo-settings` sets Pages to deploy from Actions.

The build is strict: a warning fails it. A link to a page that does not exist is a warning, and so is a link out of `docs/`, such as `../README.md`. Link to files outside `docs/` with their full GitHub URL instead.

TypeScript, Rust and Go projects get the site too, without an API reference. A Rust crate has one on docs.rs and a Go module on pkg.go.dev. The template has none for TypeScript yet.

The site uses system fonts and a plain repository link. It makes no font or repository-statistics requests to third parties. Search runs locally in the browser. `docs/assets/docs.css`, `docs/assets/docs.js` and `docs-overrides/partials/source.html` keep the theme's selected links readable and its mobile controls keyboard-accessible.

`docs-overrides/main.html` adds link-preview tags to every page: `og:title`, `og:description`, `og:image` (with size and alt text), `og:url` and `twitter:card`. The home page's title is the site name alone, and another page's is `<page> - <site name>`. A page's `description:` front matter replaces the site description. The tags read `site_url`, `site_description` and `og_image` from `zensical.toml` and are skipped when there is no `og_image`. Run `just og-card` to render the card ([Social card](hosting.md#social-card)).

An existing `zensical.toml` is yours, so updates leave it alone. To use these defaults after an update, add the assets under `[project]` and the theme settings under `[project.theme]`. Keep any other entries in those tables:

```toml
[project]
extra_css = ["assets/docs.css"]
extra_javascript = ["assets/docs.js"]

[project.theme]
font = false
custom_dir = "docs-overrides"

[project.extra]
og_image = "assets/og.png"
```

If you already list stylesheets or scripts, append the new paths instead of replacing those lists. If you use another `custom_dir`, copy the plain-link partial and `main.html` into that directory instead. Run `just docs` and check the menu and search with Tab, Enter, Space and Escape at a narrow browser width.

One repo has one Pages site, so the template refuses `docs_site` together with a `site` on Pages. A `site` [on a Worker](hosting.md#hosting-on-a-worker) leaves Pages to the docs. Otherwise, a playground page can go in `docs/` as Markdown or HTML.

The template also refuses `docs_site` for a web app at the repo root (`ts_dir` is `.`). The app keeps its privacy, terms and accessibility pages in `docs/`, so the docs site would publish a second copy that can drift from the one the app serves. A web app in a subfolder, such as `ts_dir=web` beside a Python package, keeps them in `web/docs/` and can have the site.

## Moved

These sections now live on their own pages. The anchors keep links from rendered projects working.

<!-- rumdl-disable MD033 -->
- <a id="static-site"></a>Static site: see [hosting](hosting.md#static-site).
- <a id="pull-request-previews"></a>Pull request previews: see [hosting](hosting.md#pull-request-previews).
- <a id="social-card"></a>Social card: see [hosting](hosting.md#social-card).
- <a id="publishing"></a>Publishing: see [setting up the repo](setup.md#publishing).
- <a id="the-update-app"></a>The update App: see [updates](updates.md#the-update-app).
- <a id="levels"></a>Levels: see [levels](levels.md).
<!-- rumdl-enable MD033 -->
