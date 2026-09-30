# Changelog

What changes for a project rendered from this template. Run `copier update` to take a
release. Dependency bumps and this repo's own CI are left out; `git log` has them.

## v0.6.0

### Added

- Python `web-service` kind: FastAPI with `/health` and OpenTelemetry, shipped as a container.
- Python `data-pipeline` kind: `sources.toml`, a standard-library `fetch`, `build` and
  `validate` pipeline that records a checksum for every download, and `ATTRIBUTION.md`.
- `CITATION.cff` for the `research` and `data-pipeline` kinds, with an optional ORCID iD.
- `hygiene.yml` workflow: runs the git hooks in CI and reviews new dependencies on PRs.
- actionlint hook, and default VS Code formatters for Markdown, TOML and YAML.
- The `data-pipeline` workflow runs weekly with `TRIPWIRE=1`, which runs the literal-value
  tests that every other run skips.
- Copier rejects answers that used to render a broken project: a name with no leading
  ASCII letter or digit, a `module_name` that isn't an identifier (such as `2048_game`),
  a `python_dir` or `ts_dir` with `./`, `/` or `..`, Python older than 3.12, and the
  docker stack with no image picked.

### Changed

- The secret-scan hook is Betterleaks, gitleaks' successor from the same authors, in place of
  gitleaks, which now takes security fixes only. A `SKIP` list naming `gitleaks` names
  `betterleaks` now.
- `.copier-answers.yml` records `gh:simonvanlierde/project-templates` for a tagged render
  from a local checkout, not the checkout's path.
- The release workflows say to limit the `pypi` and `npm` environments to `v*` tags with a
  required reviewer.
- The vale hook is pinned to the v3.23.0 release instead of an old short commit.
- `fetch` fails a download larger than 200 MiB instead of reading it whole.

### Fixed

- PyPI publishing from a nested `python_dir` failed: the wheels landed where the publish
  action doesn't look.
- A project name ending in `!` or other punctuation no longer fails rumdl and vale on the
  generated README heading.
- Both Dockerfiles pass hadolint 2.15.
- A project name with quotes now renders.
- yamllint skips `pnpm-lock.yaml`.

## v0.5.0 and earlier

The first releases, July 2026: one template with Python (`library`, `app`, `research`),
TypeScript and Docker stacks, pinned GitHub Actions audited by zizmor, PyPI and npm
release workflows, Dependabot with a cooldown, and vale, yamllint and rumdl linting.
`git log v0.5.0` has the detail.
