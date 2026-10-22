# Changelog

All notable changes to projects made from this template. Take a release with
`copier update`.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this
project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Before 1.0.0,
a breaking change bumps the minor version and anything else bumps the patch. Breaking
changes are marked **Breaking**.

## [Unreleased]

Upgrade steps:

- **Breaking:** install Copier 9.19 or later (`uv tool upgrade copier`) before you run
  `copier update`. Renovate's copier manager installs the latest Copier.
- A private repo: answer no to the new `public` question, and `.github/SECURITY.md`
  goes. Your license answer stays as it is.
- After the update, refresh the lockfiles for your stacks and commit them: `uv lock`,
  `pnpm install`, `just go-sync`. This release bumps dev tools in every stack, and CI
  installs with `--locked` and `--frozen-lockfile`.
- **Breaking:** in a Go library made with v0.10.0 or earlier, `copier update` deletes
  `<package>_test.go` without asking, your changes to it included, and adds
  `add_test.go`. Before you commit the update, run `git checkout HEAD -- <package>_test.go`
  (after committing it, `git checkout HEAD~1 -- <package>_test.go`). Then delete
  `add_test.go`, or the two `TestAdd` functions stop the tests compiling. With
  `test_extras=[property]`, first copy `FuzzAdd` from `add_test.go` into your test file.
- In a Python or TypeScript library, the new sample `add` function arrives as a conflict
  in `src/<module>/__init__.py` or `src/index.ts`: keep your own side. Then delete
  `tests/test_add.py`, and the `add` import and test the update merged into
  `src/index.test.ts`, or those tests fail.
- In a `data-pipeline` project (see the two Breaking changes below):
  - `src/<module>/pipeline.py` becomes a short file that imports sourceledger. If you
    added readers to `parse`, keep only your own branches, end it with
    `return sourceledger.parse_source(source, payload)`, and keep the imports your
    branches need: the new file no longer imports `csv` or `io`.
  - Take the new `tests/test_pipeline.py`, and keep any tests of your own readers.
  - `pyproject.toml` gains the `sourceledger` dependency. Keep any dependencies of your
    own next to it, where `copier update` can't merge the two lists.
  - In `sources.toml`, rename `release` to `vintage` (the old key still works, with a
    warning). Give each implemented source a `license` (an SPDX id, or
    `LicenseRef-<name>`) and `redistribute = true` or `false`. Rename any source id with
    a non-ASCII letter: only ASCII letters, digits, `_` and `-` are accepted.
  - Run `just pipeline`. `just validate` reports a missing `datapackage.json` until
    `just build` has written one.

### Added

- A `public` question, yes by default. No leaves out `.github/SECURITY.md` and makes
  `none` the license default. See [Public repos](docs/usage.md#public-repos).
- A `customise` question, no by default, ahead of the advanced questions: license,
  directories, versions, module names, Codecov, the dependency bot, publishing, test
  extras and the port. A new Python library, TypeScript web app or data pipeline now
  asks 10 questions, down from 18, 14 and 15. Every question says what it changes.
  [The questions](docs/usage.md#the-questions) lists them with their defaults.
- `copier copy` says where your details can be saved before it asks, and lists the
  `just` commands to run after it.
- A `web-app` TypeScript kind: a Vite single-page app with React or Preact (the new
  `web_framework` question), deployed by Cloudflare Pages' Git integration. The docker
  stack builds no image for it, since it is static files.
  - Playwright specs run against the production build, in `ts.yml`'s `e2e` job and with
    `just ts-e2e`. They check every route with axe in light and dark mode (WCAG 2.2 AA
    and axe's best-practice rules) and at 320 px wide (reflow), and check that the app
    runs under the Content-Security-Policy in `public/_headers`, which allows no inline
    script. Removing any security header from that file fails the check.
  - `just check` and CI enforce a bundle budget, set in `scripts/checkBundleBudget.mjs`,
    and a pre-push hook runs the unit tests.
  - The e2e run always starts its own preview server, on port 4173, and fails if the
    port is taken, so it can't test another app's server instead.
  - [Adopting the template in an existing web app](docs/usage.md#adopting-the-template-in-an-existing-web-app)
    lists the files a first `copier copy --overwrite` adds or replaces, and how to
    install a lockfile resolved before the one-week release wait.
  - The starter files (`src/App.tsx`, `src/App.test.tsx`, `src/main.tsx`, `src/app.css`,
    `index.html` and `tests/e2e/routes.ts`) belong to the project once written:
    `copier update` never touches them again.
- A `test_extras` question for the library kinds, empty by default. `property` adds a
  property test of the sample `add` function: Hypothesis, fast-check, proptest, or a
  native Go `FuzzAdd`. `mutation` adds a `just <stack>-mutation` recipe to run by hand:
  mutmut, Stryker, cargo-mutants or gremlins. See [Test extras](docs/usage.md#test-extras).
  Python and TypeScript libraries now ship the sample `add`, as Rust and Go already did.
- With the `docker` stack, `docker.yml` scans each built image with Trivy for HIGH and
  CRITICAL vulnerabilities that have a fix, and rebuilds and scans the image every Monday
  without pushing it. Pull requests and pushes show the findings in the job log; only the
  weekly run fails on them. The job that pushes to GHCR runs no scan, so it reads no
  cache on a tag.
- In a `data-pipeline` project:
  - `data/fetches.jsonl` is committed and gets a line each time a source serves bytes it
    has not served before: the history of every version, as checksums, not values.
  - The weekly CI run comments on an open "Source data revised upstream" issue when a
    source in that file serves new bytes, with the old and new checksums. Only that job
    may write issues. `uv run <slug> revisions <older log>` prints the same list locally.
  - `just status` lists every source with its vintage, last fetch and licence, and
    `just attribution` prints the sources and their reuse terms as a Markdown table for
    `ATTRIBUTION.md`.
- `just fmt` runs each stack's fix-and-format recipe, the counterpart of `just check`.
- Dependabot groups npm security updates into one pull request instead of one per
  advisory.
- VS Code formats `.tsx`, `.jsx` and `.css` files with Biome, and the Biome hook also
  checks HTML.
- The README says how to lock a security fix that is less than a week old, which
  `exclude-newer` and `minimumReleaseAge` otherwise hold back.

### Changed

- **Breaking:** after updating, switch a ruleset or branch protection that requires the
  `lint, types, tests` check to the new names, or pull requests wait on a check that never
  reports. The TypeScript and Python check jobs are now `ts: lint, types, tests` and
  `python: lint, types, tests` (`python: lint, types, pipeline, tests` in a
  `data-pipeline` project). Both used to be `lint, types, tests`, so a ruleset could not
  require one without the other.
- With the `codecov` option, `just check` runs the TypeScript tests with coverage, as CI
  does, so a coverage threshold in the Vitest config fails locally as well as in CI.
- Dependabot and Renovate group minor and patch bumps of runtime dependencies into one
  weekly PR, instead of one PR each. A major still gets its own PR.
- GitHub Actions and pre-commit hook updates arrive as one weekly PR, instead of one
  each: a Dependabot multi-ecosystem group, and one Renovate group. Fewer PRs means fewer
  branches to bring up to date in turn where main requires it.
- With the `codecov` option, Codecov no longer comments on pull requests. Any line left
  untested drew a comment. A drop of over 2 points still fails the `codecov/project`
  check, which links to the report.
- **Breaking:** a `data-pipeline` project gets its fetch, build, validate and revisions
  stages from the [sourceledger](https://github.com/simonvanlierde/sourceledger)
  package instead of about 400 copied lines in `pipeline.py`. Fixes now arrive as a
  dependency bump, not a `copier update` merge. `pipeline.py` keeps only `parse`.
  - `parse` reads CSV, JSON and Excel sources, gzipped or not, by each source's `format`
    or its URL's extension. `just build` also writes a `datapackage.json`.
  - A fetch asks the server whether the file changed (`If-None-Match`,
    `If-Modified-Since`) and keeps the record on a 304, unless the raw file was edited or
    no longer matches its pinned `sha256`. It waits at most 2 minutes for a
    429's `Retry-After`, and a fetch that fails after its retries names the source and
    its URL.
  - The manifest names the edition `vintage`, as the fetch record and the output column
    already did. `sources.toml` has a schema line for editors, pinned to sourceledger
    v0.2.0, and its comments cover every key. The example source is pinned to a
    datasets/co2-ppm commit, so CI and the tripwire tests no longer follow a moving
    branch.
  - Until sourceledger 0.2.0 is a week old on PyPI, `pyproject.toml` pins its tag's
    source archive.
- **Breaking:** `just validate` in a `data-pipeline` project needs each implemented source
  to state `license` (an SPDX id) and `redistribute` (whether the raw file may be
  republished), beside `terms`. The free-text terms stay for people; these two are for a
  release step to check.
- `go.mod` is written once and then belongs to the project, like `CHANGELOG.md`. Before,
  every `copier update` conflicted with what `go mod tidy` had written there. To raise the
  minimum Go version, run `go mod edit -go=<version>`.
- `copier update` no longer touches `CITATION.cff`, `.zenodo.json` or `codemeta.json` once
  they exist, so a release that adds its version, date or DOI to them no longer conflicts
  with every update. Later template changes to these files reach existing projects only by
  hand.
- Web-service projects test with `httpx2`, which Starlette's test client now prefers,
  instead of `httpx`, and require Starlette 1.2.0 or later. The pytest filter that hid
  Starlette's deprecation warning is gone.
- A new Python release becomes the default `python_version` 90 days after it comes out,
  once the packages projects install have wheels for it.
- The generated README lists the tools the project needs (uv only where it's used), puts
  `just hooks` next to `just check`, says that `just check` doesn't build the Docker
  image, and, with a publish option, has a Releasing section on setting up the publishing
  environment first.
- The workflow linter hook runs jactionlint, a maintained fork of actionlint. It adds
  checks for releases, caches and concurrency, so a workflow you wrote yourself may get new
  findings.
- A library's release workflow runs its wheel tests with the test tools from `uv.lock`,
  hash-checked, and turns on uv's malware check as `python.yml` does.
- `python-release.yml` and `ts-release.yml` run one release per tag at a time.
- The docker workflow cancels a superseded run only on a pull request, so a push to `main`
  or a tag is never stopped halfway through pushing an image. A tag build doesn't restore
  the shared build cache, so a poisoned cache entry can't reach a release image; release
  builds take longer as a result. When every image builds from a subdirectory, the
  workflow runs only when a build context or the workflow changes, so a required build
  check stays pending on a pull request that touches neither.
- The Docker image of a `data-pipeline` project is documented as a stub: it has no
  `sources.toml` or `data/`, and it starts the `/health` placeholder.
- Python projects accept `uv_build` 0.13 as their build backend. The 0.12.19 floor stays,
  so older uv versions still build them.
- With `dependency_bot: renovate`, Renovate's copier manager opens a PR for each new
  template release. Before, the one-week release age held those PRs back for good, because
  template tags carry no release date. The docs say how Dependabot users hear about
  releases.

### Fixed

- The weekly scheduled run and a push to `main` no longer cancel each other in
  `python.yml` and `docker.yml`. A cancelled weekly run used to skip that week's tripwire
  tests in a `data-pipeline` project.
- Copier refuses answers that rendered a broken project: a project name that is a Go,
  Rust or Python keyword (such as `type`, `gen` or `lambda`), an empty `stacks` list, an
  empty `*_dir`, a `rust_version` below 1.85 (the template uses edition 2024), and an
  `app_port` outside 1 to 65535, or 65535 when two images publish ports. A Go binary no
  longer needs a project name that can be a Go package name.
- The `check-yaml` hook no longer fails on `pnpm-lock.yaml`. pnpm 12 writes its own
  version into the lockfile as a second YAML document, so every TS project failed its
  `checks` workflow once the lockfile was committed.
- A name or email with a quote in it, such as `Ada "X" Lovelace`, no longer breaks the
  generated `pyproject.toml`, `package.json` or `Cargo.toml`. A leading space in the
  author name no longer leaves the given name empty in the citation files.
- The `ts` and stdlib Python starter servers in the Docker image stop on SIGTERM. As PID 1
  they ignored it, so `docker stop` waited 10 seconds and then killed them.
- A Go library named `example` no longer loses its `TestAdd`: the unit test is now
  `add_test.go`, which can't share a path with `example_test.go`.
- The image `.dockerignore` files match `.env`, `.venv` and `node_modules` in any
  directory, so another stack's secrets stay out of the build context when a package sits
  at the repo root.
- `.gitignore` names a Go binary without a trailing major version, as `go build` does for
  a module path ending in `/v2`.
- With a Rust crate below the repo root, `.vscode/settings.json` sets
  `rust-analyzer.linkedProjects`, so the editor finds a crate two levels deep.

### Security

- With `publish_to_ghcr`, the image push job runs in a `ghcr` environment, as PyPI and npm
  releases already do. Limit it to `main` and `v*` tags with a required reviewer in the
  repository's settings (see the README's Releasing section); until then GitHub creates it
  unprotected and pushes as before.
- A library's PyPI release signs a GitHub build-provenance attestation for each file in
  `dist/`, so users can check where a wheel was built with `gh attestation verify`. It is
  made in the publish job, which runs no project code.
- The hooks job installs a set prek version, 0.5.5, instead of the newest one on each run,
  and gives the read-only GitHub token to the zizmor hook only.

## [0.10.0] - 2026-10-16

### Added

- A `dependency_bot` question: Dependabot (the default, as before) or Renovate. Renovate
  gets a `renovate.json5` with the same rules as the Dependabot config: weekly, a one-week
  cooldown, grouped actions, hooks and dev tooling, and no updates to the copier-owned
  `FROM` tags. It needs the Renovate GitHub App on the repository. Existing projects keep
  Dependabot unless they answer `renovate` on the next `copier update`.
- A `data-pipeline` source can set `max_bytes` in `sources.toml` to accept a download
  over the 200 MiB default cap.
- A `data-pipeline` fetch retries a server error, a 429 (waiting at least its
  `Retry-After`), a network error or a body shorter than its `Content-Length`, up to
  four attempts with 5, 10 and 20 s between them. A brief publisher outage no longer
  fails CI. Any other 4xx still fails at once.
- Fetch records also hold the server's `last_modified` and `etag`, empty when it sends
  none. Records written before keep working.

### Changed

- With the `codecov` option, Codecov comments only when a pull request adds lines no test
  runs. It used to comment on any drop in total coverage, however small, although the
  docs said it waited for the 2-point threshold. A drop of over 2 points still fails the
  pull request's Codecov check.

### Fixed

- With both the Python and TS stacks and the `codecov` option, a pull request no longer
  gets a false coverage drop, with its comment, while the second stack's report is
  still on its way. `codecov.yml` now carries each stack's last numbers forward.
- A `data-pipeline` project's `pyproject.toml` no longer explains its packaging as if
  it were a research project with notebooks.

## [0.9.1] - 2026-10-13

### Fixed

- The README's licence badge now shows a hyphenated licence such as BSD-3-Clause.
  Before, shields.io read each hyphen as a field separator, so the badge broke.
- The Apache-2.0 and BSD-3-Clause LICENSE files now end in one newline, not two, so the
  end-of-file-fixer hook no longer rewrites LICENSE on its first run in a new project.

## [0.9.0] - 2026-10-13

### Added

- A `codecov` option for the Python and TS stacks: CI uploads test coverage to Codecov,
  and a `codecov.yml` fails a pull request only when total coverage drops by more than
  2 points. Codecov comments only then. It needs a `CODECOV_TOKEN` repository secret
  (see the README).

## [0.8.1] - 2026-10-13

### Fixed

- The dependency review job is skipped in private repositories. GitHub supports it
  there only with Advanced Security, so it failed every pull request.

## [0.8.0] - 2026-10-13

Upgrade steps:

- `copier copy --defaults` now stops at the GitHub user, author name and email, which
  have no defaults any more. Pass them with `--data`, or save them once under
  `defaults:` in Copier's settings file (see the README). `copier update` keeps the
  answers you already gave.
- A `library` project is asked for `python_min`. Its `requires-python` drops to that
  version and CI tests every version from there up, so check the code still runs on
  the oldest one. If you added a dependency, `copier update` can't merge the new
  `requires-python` next to it: take the new floor and keep your `dependencies`.
- In a `data-pipeline` project, re-run `just pipeline` after updating (see the
  Breaking change below).

### Added

- The `library` kind gets a `CITATION.cff`, like `research` and `data-pipeline`.
- `library`, `research` and `data-pipeline` projects also get `.zenodo.json`, which
  Zenodo reads when it archives a release, and a CodeMeta 4.0 `codemeta.json`.
- A `library` project tests every Python from `python_min` to `python_version` in CI.
  `python_min` defaults to two minors below `python_version`, after SPEC 0.
- A `data-pipeline` source can pin a `sha256`. `fetch` refuses a download that
  doesn't match it.

### Changed

- **Breaking:** the GitHub user, author name, author email and ORCID iD have no
  defaults. They used to default to the template author's details, which a
  `--defaults` run published in the new project.
- The copyright year defaults to the current year instead of a fixed one.
- The generated README installs golangci-lint with `go install`, which checks the
  download against the Go checksum database, instead of piping a script into `sh`.
- **Breaking:** `data-pipeline` drops the `vintage_basis` column and the per-source
  `encoding` key. The vintage is the manifest's `release`, and every source is read
  as UTF-8. Re-run `just pipeline` after updating.
- `data-pipeline` rejects a row with fewer fields than the header, and an id repeated
  in a different case is no longer an error.
- The web-service's `/docs`, `/redoc` and `/openapi.json` are off unless `API_DOCS` is
  set.
- VS Code formats TOML with the Tombi extension (`tombi-toml.tombi`), which reads the
  shipped `.tombi.toml`. Even Better TOML ignored it. Install the new recommendation
  after updating.
- CI no longer runs on draft pull requests; it runs when a pull request is marked ready
  for review. This saves Actions minutes on private repositories.
- Plainer wording in the generated `README.md`, `data/README.md` and `ATTRIBUTION.md`.

### Removed

- `workflow_dispatch` from the release workflows: a manual run could publish any
  branch.

### Security

- The Python workflow sets `UV_MALWARE_CHECK`, so uv checks every package against
  OSV's malware advisories before its code runs. A CI run fails if OSV is unreachable.

## [0.7.1] - 2026-09-30

### Added

- `just rs-sync` downloads Rust dependencies and writes `Cargo.lock`, like `just py-sync`
  and `just go-sync` do for their stacks.
- A yamlfmt hook with a `.yamlfmt` config. yamllint now checks yamlfmt's output.

### Changed

- Hook revs are commit SHAs with a `# frozen:` tag comment, since tags are mutable.
  Dependabot moves both together.
- Flow mappings are written `{key: value}`, as yamlfmt formats them.
- Comments and docstrings in generated files are shorter and plainer. Two
  `.dockerignore` comments now describe the Docker layer cache correctly.

## [0.7.0] - 2026-09-30

### Upgrade notes

1. Run `copier update`. It replaces `hygiene.yml` with `checks.yml`, swaps
   `.taplo.toml` for `.tombi.toml`, and deletes the pull request template.
2. If something uploads `coverage.xml` or `coverage/lcov.info`, add the reporter flag
   back to `just py-cov` or `just ts-cov`.

### Changed

- The `hygiene.yml` workflow is now `checks.yml`. Its job names are unchanged, so
  required status checks still match.
- `.tombi.toml` replaces `.taplo.toml`, because tombi replaced taplo as the TOML
  formatter.
- `just py-cov` and `just ts-cov` print a coverage summary only. They no longer write
  report files.
- CI reads the Python version from `.python-version` instead of repeating it.

### Removed

- The pull request template.
- The `knip` script in `package.json`. `pnpm run check` already runs knip.
- The copier checks that rejected a project name that is a Rust or Go keyword.

## [0.6.0] - 2026-09-30

### Upgrade notes

1. Run `copier update`. If you added dependencies, you get one conflict in
   `pyproject.toml`. Keep your dependencies and take the new comment below them.
2. Run `uv lock` and `pnpm install`, then commit the lockfiles. `uv lock` can downgrade
   packages released in the last week.
3. If a `SKIP` list names `gitleaks`, change it to `betterleaks`.
4. Delete the `.vale/` folder. Vale is gone, and so is the `.gitignore` entry that hid it.

### Added

- `rust` and `go` stacks, each as a library or a binary, with strict linting.
- Python `web-service` kind: FastAPI in a container, with a `/health` endpoint.
- Python `data-pipeline` kind: downloads third-party data and records a checksum for each
  file.
- Dependency audits in `just check` and CI for Python, TypeScript and Rust.
- A `hygiene.yml` workflow that runs the git hooks in CI.
- `CITATION.cff` for research and data-pipeline projects.
- Knip for TypeScript, and an actionlint hook.
- A `CHANGELOG.md` in the Keep a Changelog format. `copier update` never overwrites it.
- Copier rejects answers that would build a broken project, such as a name that starts
  with a digit or a directory with a trailing `/`.

### Changed

- **Breaking:** secret scanning uses Betterleaks instead of gitleaks.
- **Breaking:** the web service turns on OpenTelemetry only when
  `OTEL_EXPORTER_OTLP_ENDPOINT` is set.
- CI installs a pinned uv, because `uv audit` is a preview command that can change
  between releases.
- `pnpm audit` fails on moderate and higher advisories only.

### Removed

- **Breaking:** the web service's `config.py` and `telemetry.py`.
- **Breaking:** the vale prose linter and its `.vale.ini`. rumdl still lints Markdown.

### Fixed

- PyPI releases failed when the Python package was in a subdirectory.
- A project name with quotes or a trailing `!` broke the render or the README checks.
- Both Dockerfiles pass hadolint.
- yamllint skips `pnpm-lock.yaml`.

### Security

- uv and pnpm install a release only after it is a week old, the same as Dependabot.
- Data-pipeline downloads stop at 200 MiB.
- The release workflows and `SECURITY.md` list the GitHub settings to turn on.

## [0.5.0] - 2026-07-30

### Added

- Markdown linting with rumdl, and YAML linting with yamllint.

## [0.4.0] - 2026-07-28

### Added

- A JSON5 check for config files such as `tsconfig.json`.

## [0.3.0] - 2026-07-28

### Added

- Prose linting with vale.

## [0.2.0] - 2026-07-24

### Changed

- **Breaking:** the four templates are one template. A project made from 0.1.0 cannot
  update to this release.

### Fixed

- The shipped `.gitignore` no longer hides template files.
- biome accepts the rendered `.vscode/` files.

## [0.1.0] - 2026-07-24

### Added

- Separate templates for a base repo and for Python, TypeScript and Docker, in any mix.
- Python library, app and research projects, and TypeScript library and app projects.
- CI for each stack, with GitHub Actions pinned to commits and audited by zizmor.
- Optional releases to PyPI, npm and GitHub Container Registry.
- Dependabot with a one-week cooldown.
- Coverage recipes for Python and TypeScript.

[Unreleased]: https://github.com/simonvanlierde/project-templates/compare/v0.10.0...HEAD
[0.10.0]: https://github.com/simonvanlierde/project-templates/compare/v0.9.1...v0.10.0
[0.9.1]: https://github.com/simonvanlierde/project-templates/compare/v0.9.0...v0.9.1
[0.9.0]: https://github.com/simonvanlierde/project-templates/compare/v0.8.1...v0.9.0
[0.8.1]: https://github.com/simonvanlierde/project-templates/compare/v0.8.0...v0.8.1
[0.8.0]: https://github.com/simonvanlierde/project-templates/compare/v0.7.1...v0.8.0
[0.7.1]: https://github.com/simonvanlierde/project-templates/compare/v0.7.0...v0.7.1
[0.7.0]: https://github.com/simonvanlierde/project-templates/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/simonvanlierde/project-templates/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/simonvanlierde/project-templates/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/simonvanlierde/project-templates/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/simonvanlierde/project-templates/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/simonvanlierde/project-templates/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/simonvanlierde/project-templates/releases/tag/v0.1.0
