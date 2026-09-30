# Changelog

What changes for a project rendered from this template. Run `copier update` to take a
release. Dependency bumps and this repo's own CI are left out; `git log` has them.

## Unreleased

### Added

- `rust` stack: a crate in `rust_dir`, library or binary, with a strict clippy lint policy
  in `Cargo.toml`'s `[lints]` table, `clippy.toml`, a `deny.toml` for cargo-deny, `rust.yml`,
  `just rs-check`, cargo hooks, and a Dependabot cargo entry.
- `go` stack: a module in `go_dir`, library or binary, with a golangci-lint v2 policy in
  `.golangci.yml`, a table-driven test and an Example, `go.yml`, `just go-check`
  (golangci-lint, `go test -race`, govulncheck), golangci-lint hooks, and a Dependabot
  gomod entry.
- Dependency audits in `just check` and CI: `uv audit` for Python, `pnpm audit --prod` for
  TypeScript, `cargo deny check` for Rust.
- Knip in the TypeScript `check` script, for unused files, exports and dependencies.
- A one-week minimum release age: `exclude-newer = "1 week"` under `[tool.uv]`, and
  `minimumReleaseAge` in a new `pnpm-workspace.yaml`. It matches Dependabot's cooldown.

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
