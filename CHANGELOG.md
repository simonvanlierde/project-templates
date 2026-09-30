# Changelog

What changes for a project rendered from this template. Run `copier update` to take a
release. Dependency bumps and this repo's own CI are left out; `git log` has them.

## Unreleased

### Changed

- The secret-scan hook is Betterleaks, gitleaks' successor from the same authors, in place of
  gitleaks, which now takes security fixes only. A `SKIP` list naming `gitleaks` names
  `betterleaks` now.

## v0.6.0

### Added

- Python `web-service` kind: FastAPI with `/health` and OpenTelemetry, shipped as a container.
- Python `data-pipeline` kind: `sources.toml`, a standard-library `fetch`, `build` and
  `validate` pipeline that records a checksum for every download, and `ATTRIBUTION.md`.
- `CITATION.cff` for the `research` and `data-pipeline` kinds, with an optional ORCID iD.
- `hygiene.yml` workflow: runs the git hooks in CI and reviews new dependencies on PRs.
- actionlint hook, and default VS Code formatters for Markdown, TOML and YAML.

### Changed

- `.copier-answers.yml` records `gh:simonvanlierde/project-templates` for a tagged render
  from a local checkout, not the checkout's path.

### Fixed

- Both Dockerfiles pass hadolint 2.15.
- A project name with quotes now renders, and `module_name` is always a valid identifier.
- yamllint skips `pnpm-lock.yaml`.

## v0.5.0 and earlier

The first releases, July 2026: one template with Python (`library`, `app`, `research`),
TypeScript and Docker stacks, pinned GitHub Actions audited by zizmor, PyPI and npm
release workflows, Dependabot with a cooldown, and vale, yamllint and rumdl linting.
`git log v0.5.0` has the detail.
