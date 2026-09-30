# Changelog

What changed for projects made from this template. Run `copier update` to take a release.
The README has the details of each feature.

## v0.6.0

### Updating from v0.5.0

1. Run `copier update`. If you added dependencies, you get one conflict in
   `pyproject.toml`. Keep your dependencies and take the new comment below them.
2. Run `uv lock` and `pnpm install`, then commit the lockfiles. `uv lock` can downgrade
   packages released in the last week.
3. If a `SKIP` list names `gitleaks`, change it to `betterleaks`.

### Added

- A `rust` stack and a `go` stack, each as a library or a binary, with strict linting.
- Two Python kinds: `web-service` (FastAPI in a container) and `data-pipeline` (downloads
  third-party data and records a checksum for each file).
- Dependency audits in `just check` and CI for Python, TypeScript and Rust.
- A one-week wait before uv and pnpm install a new release, the same as Dependabot.
- A `hygiene.yml` workflow that runs the git hooks in CI.
- `CITATION.cff` for research and data-pipeline projects.
- Knip for TypeScript, and an actionlint hook.
- Copier now rejects answers that would build a broken project, such as a name that
  starts with a digit or a directory with a trailing `/`.

### Changed

- Secret scanning uses Betterleaks instead of gitleaks.
- The web service turns on OpenTelemetry only when `OTEL_EXPORTER_OTLP_ENDPOINT` is set.
  `config.py` and `telemetry.py` are gone.
- Data-pipeline downloads stop at 200 MiB.
- The release workflows and `SECURITY.md` list the GitHub settings to turn on.

### Fixed

- PyPI releases failed when the Python package was in a subdirectory.
- A project name with quotes or a trailing `!` broke the render or the README checks.
- Both Dockerfiles pass hadolint.
- yamllint skips `pnpm-lock.yaml`.

## v0.5.0 and earlier

Released 24 to 30 July 2026. At v0.5.0 the template offered:

- Python, TypeScript and Docker, in any mix.
- Python library, app and research projects, and TypeScript library and app projects.
- Packages at the repo root or in subdirectories.
- CI for each stack, and optional releases to PyPI, npm and GitHub Container Registry.
- Dependabot, and git hooks for linting, formatting and secret scanning.

A project made from v0.1.0 cannot update past v0.2.0, which merged four templates into
one. `git log v0.5.0` has the full history.
