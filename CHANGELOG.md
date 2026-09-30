# Changelog

What changed for projects rendered from this template. Take a release with
`copier update`. Dependency bumps and this repo's own CI are not listed; `git log` has them.

## v0.6.0

### Updating from v0.5.0

1. Run `copier update`. If you added dependencies, it reports a conflict in
   `pyproject.toml` at `dependencies`, because the comment below that line changed. Keep
   your `dependencies` list and take the new comment.
2. Run `uv lock` and `pnpm install`, then commit both lockfiles. This release adds a
   one-week release age and knip, so the old lockfiles no longer match. `uv lock` can
   downgrade packages released in the last week.

### Added

- `rust` stack: a library or binary crate in `rust_dir`. It has a strict clippy policy in
  `Cargo.toml`'s `[lints]` table, `clippy.toml`, a `deny.toml` for cargo-deny, `rust.yml`,
  `just rs-check`, cargo hooks and a Dependabot cargo entry.
- `go` stack: a library or binary module in `go_dir`. It has a golangci-lint v2 policy in
  `.golangci.yml`, a table-driven test and an Example, `go.yml`, `just go-check`
  (golangci-lint, `go test -race` and govulncheck), golangci-lint hooks and a Dependabot
  gomod entry.
- Python `web-service` kind: FastAPI with `/health` and OpenTelemetry, shipped as a container.
- Python `data-pipeline` kind: a `sources.toml` manifest, a standard-library `fetch`,
  `build` and `validate` pipeline that records a checksum for every download, and
  `ATTRIBUTION.md`. Its workflow also runs weekly with `TRIPWIRE=1`, the only run that
  checks published values against literal numbers.
- `CITATION.cff` for the `research` and `data-pipeline` kinds, with an optional ORCID iD.
- Dependency audits in `just check` and CI: `uv audit` for Python, `pnpm audit --prod` for
  TypeScript and `cargo deny check` for Rust.
- A one-week minimum release age, to match Dependabot's cooldown: `exclude-newer = "1 week"`
  under `[tool.uv]`, and `minimumReleaseAge` in a new `pnpm-workspace.yaml`.
- Knip in the TypeScript `check` script, for unused files, exports and dependencies.
- `hygiene.yml` workflow: it runs the git hooks in CI and reviews new dependencies on PRs.
- An actionlint hook, and default VS Code formatters for Markdown, TOML and YAML.
- Copier rejects answers that used to render a broken project:
  - a project name that does not start with an ASCII letter or digit;
  - a `module_name` that is not a Python identifier, such as `2048_game`;
  - a Rust crate name that starts with a digit, or a library crate named after a Rust keyword;
  - a Go package name that is not an identifier or is a Go keyword;
  - a `python_dir`, `ts_dir`, `rust_dir` or `go_dir` with a leading `./` or `/`, a trailing
    `/`, or `..`;
  - Python older than 3.12;
  - the docker stack with no image picked.

### Changed

- The secret-scan hook is Betterleaks instead of gitleaks. Betterleaks comes from the same
  authors; gitleaks now gets security fixes only. Rename `gitleaks` to `betterleaks` in any
  `SKIP` list.
- The `web-service` kind uses zero-code OpenTelemetry. The entrypoint calls the distro's
  `initialize()` when `OTEL_EXPORTER_OTLP_ENDPOINT` is set. `config.py` and `telemetry.py`
  are gone, and `app.py` exports a plain `app`.
- `fetch` fails a download larger than 200 MiB instead of reading it whole.
- The vale hook is pinned to the v3.23.0 release instead of an old short commit.
- The release workflows tell you to limit the `pypi` and `npm` environments to `v*` tags,
  with a required reviewer.
- `SECURITY.md` notes that its advisories link works only when private vulnerability
  reporting is on.
- A tagged render from a local checkout records `gh:simonvanlierde/project-templates` in
  `.copier-answers.yml`, not the checkout's path.

### Fixed

- PyPI publishing failed for a nested `python_dir`: the wheels landed where the publish
  action does not look.
- A project name that ends in `!` or other punctuation no longer fails rumdl and vale on
  the README heading.
- A project name with quotes renders.
- Both Dockerfiles pass hadolint 2.15.
- yamllint skips `pnpm-lock.yaml`.

## v0.5.0 and earlier

v0.1.0 to v0.5.0 came out between 24 and 30 July 2026. At v0.5.0 the template had:

- Three stacks, in any mix: `python`, `ts` and `docker`.
- Python kinds `library`, `app` and `research`, and TypeScript kinds `library` and `app`.
- Each package at the repo root or nested, set by `python_dir` and `ts_dir`.
- A CI workflow per stack, with GitHub Actions pinned to commit SHAs. Optional release
  workflows publish to PyPI and npm with trusted publishing, and push images to GHCR.
- Dependabot for actions, hooks, uv and npm, with a 7-day cooldown.
- prek hooks: ruff, ty, biome, tsc, gitleaks, zizmor, hadolint, nbstripout, a JSON5 check,
  yamllint, vale and rumdl.

v0.1.0 shipped four separate Copier templates, which v0.2.0 merged into one. A project
scaffolded from v0.1.0 keeps its answers under `.copier/*.yml` and cannot `copier update`
across that change. `git log v0.5.0` has the detail.
