# Changelog

All notable changes to projects made from this template. Take a release with
`copier update`.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this
project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Before 1.0.0,
a breaking change bumps the minor version and anything else bumps the patch. Breaking
changes are marked **Breaking**.

## [Unreleased]

### Added

- A `data-pipeline` source can pin a `sha256`. `fetch` refuses a download that
  doesn't match it.

### Changed

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

### Removed

- `workflow_dispatch` from the release workflows: a manual run could publish any
  branch.

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

[Unreleased]: https://github.com/simonvanlierde/project-templates/compare/v0.7.1...HEAD
[0.7.1]: https://github.com/simonvanlierde/project-templates/compare/v0.7.0...v0.7.1
[0.7.0]: https://github.com/simonvanlierde/project-templates/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/simonvanlierde/project-templates/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/simonvanlierde/project-templates/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/simonvanlierde/project-templates/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/simonvanlierde/project-templates/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/simonvanlierde/project-templates/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/simonvanlierde/project-templates/releases/tag/v0.1.0
