# Tooling

Tools used by each stack, default configurations, and release mechanics.
[usage.md](usage.md#choosing-your-stacks) lists files created by each stack, and
[ci-baseline.md](ci-baseline.md) documents every workflow check.

## Tools per stack

|            | Lint and format                          | Types                       | Tests                                    | Packaging                            |
| ---------- | ---------------------------------------- | --------------------------- | ---------------------------------------- | ------------------------------------ |
| Python     | `ruff`                                   | `ty`                        | `pytest`                                 | `uv`, locked, `uv_build` backend     |
| TypeScript | `biome`                                  | `tsc`                       | `vitest`, plus Playwright and axe for a `web-app` | `pnpm`, plus Vite for a `web-app` |
| Rust       | `rustfmt`, `clippy`                      | `rustc`                     | `cargo nextest`, plus `cargo test --doc` | `cargo`, checked by `cargo-deny`     |
| Go         | `golangci-lint` (`gofumpt`, `goimports`) | `go vet`, via golangci-lint | `go test -race`, Examples included       | Go modules, checked by `govulncheck` |

## Rust lints

Clippy lints live in `[lints]` in `Cargo.toml`. The policy enables clippy's `pedantic` group plus restriction lints against shortcuts: `unwrap_used`, `expect_used`, `dbg_macro`, `todo`, `unimplemented`, and `allow_attributes_without_reason`. `unsafe_code` is forbidden. Libraries also warn on `missing_docs` and prints to standard output or error.

`clippy.toml` permits `unwrap`, `expect`, and `dbg!` in tests. `deny.toml` limits dependencies to crates.io and permissive licenses.

Install `cargo-nextest` and `cargo-deny` once per machine.

## Go lints

Lints live in `.golangci.yml` for golangci-lint v2. The policy enables `standard` linters plus `bodyclose`, `errorlint`, `gocritic`, `gosec`, `misspell`, `modernize`, `nilerr`, `noctx`, `revive`, `sloglint`, `unconvert`, `unparam`, and `usestdlibvars`. `gosec` and `noctx` are disabled in tests. `gofumpt` and `goimports` handle formatting.

Install golangci-lint once per machine. The template pins the golangci-lint version, which `copier update` bumps. `govulncheck` is configured as a `tool` dependency in `go.mod` and requires no separate installation.

## Git hooks

Hooks run via [prek](https://prek.j178.dev), a drop-in pre-commit replacement. A single `.pre-commit-config.yaml` covers all stacks. Python projects install prek with `uv tool install prek`; TypeScript projects install the `@j178/prek` devDependency. With the `docker` stack, the hadolint hook requires a running Docker daemon.

## Tasks

Tasks run via [just](https://just.systems). The root `justfile` imports stack-specific `just/<stack>.just` modules. Recipes use a stack prefix (`py-`, `ts-`, `rs-`, `go-`), except for kind-specific tasks: `fetch`, `build`, `validate`, and `pipeline` (data-pipeline), `serve` (web-service), and `up` (docker). `just check` runs the checks across all enabled stacks.

Coverage is opt-in. `just py-cov` and `just ts-cov` print summaries without threshold gates. With the `codecov` option enabled, CI uploads coverage to Codecov, and `just check` runs TypeScript tests with coverage.

## Docker images

Dockerfiles follow upstream uv and pnpm patterns: multi-stage builds on `-slim` base images, BuildKit cache mounts, a non-root runtime user, and OCI labels.

## Dependencies

Generated projects use Dependabot by default. Setting `dependency_bot=renovate` writes equivalent rules to `renovate.json5`. Both bots share these policies:

- Weekly version updates grouped into three PRs: actions and hooks, dev tooling, and minor/patch runtime updates.
- Runtime major versions get separate individual PRs.
- Updates wait one week before opening (or one month for package major versions).
- Security updates bypass the cooldown.

Dependabot also combines npm security updates into one PR. Renovate refreshes lockfiles weekly on Monday.

uv's `exclude-newer = "1 week"` and pnpm's `minimumReleaseAge` hold back local installs to match the bot cooldown. Go has no equivalent cooldown.

To lock an urgent security patch before the cooldown expires, add a temporary exemption:

- **uv**: add the package under `[tool.uv]` in `pyproject.toml` with a timestamp after the patch release, then run `uv lock --upgrade-package <pkg>`:

  ```toml
  exclude-newer-package = { certifi = "2026-10-21T00:00:00Z" }
  ```

  Do not rely solely on `uv lock --exclude-newer-package <pkg>=<timestamp>`; later `uv sync` calls reset it. Remove the entry once the patch is a week old.

- **pnpm**: run `pnpm audit --fix=update`. This adds an entry under `minimumReleaseAgeExclude` in `pnpm-workspace.yaml`. You can also add it manually and run `pnpm install`:

  ```yaml
  minimumReleaseAgeExclude:
    - is-odd@3.0.1
  ```

  `minimumReleaseAgeExcludePrune` removes the entry automatically once the lockfile moves past that version.

Docker base image tags (`python_version`, `node_version`) are Copier answers. Rebuilds pull the latest security patches for that tag.

Fresh renders generate without lockfiles. The initial `uv lock` or `pnpm install` locks the newest versions past the one-week cooldown. Once committed, CI installs strictly from lockfiles.

Both `just check` and CI run dependency audits:

- `uv audit` for Python dependencies.
- `pnpm audit --prod` for production TypeScript packages.
- `cargo deny check` for Rust crates and licenses.
- `govulncheck` for Go code paths.
- Knip for unused TypeScript files, exports, and packages.

## Release workflows

Release workflows separate artifact build from artifact publication:

1. **Build**: re-runs checks and tests the packaged artifact directly. Installs the Python wheel into a clean environment to run tests, or verifies npm packages with `publint`.
2. **Publish**: downloads the built artifact and uploads it using OpenID Connect (`id-token: write`). This job runs no project code.

With PyPI publishing, a final job attaches wheels and provenance bundles to the GitHub release. Images pushed to GHCR include an SBOM and a signed provenance attestation.
