# Changelog

All notable changes to projects made from this template. Take a release with
`copier update`.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this
project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Before 1.0.0,
a breaking change bumps the minor version and anything else bumps the patch. Breaking
changes are marked **Breaking**.

## [Unreleased]

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

- The `check-yaml` hook no longer fails on `pnpm-lock.yaml`. pnpm 12 writes its own
  version into the lockfile as a second YAML document, which the hook rejected, so
  every TS project failed its `checks` workflow once the lockfile was committed.
- With both the Python and TS stacks and the `codecov` option, a pull request no longer
  gets a false coverage drop, with its comment, while the second stack's report is
  still on its way. `codecov.yml` now carries each stack's last numbers forward.
- The README's licence badge now shows a hyphenated licence such as BSD-3-Clause.
  Before, shields.io read each hyphen as a field separator, so the badge broke.
- The Apache-2.0 and BSD-3-Clause LICENSE files now end in one newline, not two, so the
  end-of-file-fixer hook no longer rewrites LICENSE on its first run in a new project.
- A `data-pipeline` project's `pyproject.toml` no longer explains its packaging as if
  it were a research project with notebooks.

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

[Unreleased]: https://github.com/simonvanlierde/project-templates/compare/v0.9.0...HEAD
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
