# Tooling

What each stack generates, which tools it uses, and why the defaults are what they are.

## Files per stack

| Stack    | What it writes                                                                                                                                       |
| -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| always   | `README.md`, a Keep a Changelog `CHANGELOG.md`, `LICENSE`, `.gitignore`, `.editorconfig`, `.github/` with Dependabot and `SECURITY.md`, `.pre-commit-config.yaml`, `.vscode/` recommendations, and a `justfile` |
| `python` | A Python package in `<python_dir>`: `pyproject.toml`, `.python-version`, `src/`, `tests/`, plus extra files for the `research`, `data-pipeline` and `web-service` kinds ([python-kinds.md](python-kinds.md)) |
| `ts`     | A TypeScript package in `<ts_dir>`: `package.json`, `tsconfig.json`, `tsconfig.build.json`, `biome.json`, `pnpm-workspace.yaml`, `src/index.ts`, `src/index.test.ts` |
| `rust`   | A Rust crate in `<rust_dir>`: `Cargo.toml` with a strict lint policy, `clippy.toml`, `deny.toml`, and `src/lib.rs` or `src/main.rs`, depending on `rust_kind` |
| `go`     | A Go module in `<go_dir>`: `go.mod`, `.golangci.yml`, and, depending on `go_kind`, a library package with a table test and an Example, or a `main.go` with its test |
| `docker` | For each containerized stack: a `Dockerfile`, a `.dockerignore`, and a runnable `/health` entrypoint. Plus `compose.yaml` at the repository root |

Each stack also gets a CI workflow in `.github/workflows/` and a `just/<stack>.just`
recipe file. It gets a release workflow too, if its publish option is on. A Python
package in a subdirectory gets its own `README.md`.

## Tools per stack

|            | Lint and format                          | Types                        | Tests                                    | Packaging                            |
| ---------- | ---------------------------------------- | ---------------------------- | ---------------------------------------- | ------------------------------------ |
| Python     | `ruff`                                   | `ty`                         | `pytest`                                 | `uv`, locked, `uv_build` backend     |
| TypeScript | `biome`                                  | `tsc`                        | `vitest`                                 | `pnpm`                               |
| Rust       | `rustfmt`, `clippy`                      | `rustc`                      | `cargo nextest`, plus `cargo test --doc` | `cargo`, checked by `cargo-deny`     |
| Go         | `golangci-lint` (`gofumpt`, `goimports`) | `go vet`, via golangci-lint  | `go test -race`, Examples included       | Go modules, checked by `govulncheck` |

## Rust lints

The lints live in the `[lints]` table of the crate's `Cargo.toml`, because clippy has
no user-wide config. The policy is clippy's `pedantic` group plus restriction lints
that block shortcuts: `unwrap_used`, `expect_used`, `dbg_macro`, `todo`,
`unimplemented`, and `allow_attributes_without_reason`. `unsafe_code` is forbidden. A
library also warns on `missing_docs` and on printing to stdout or stderr.

`clippy.toml` allows `unwrap`, `expect` and `dbg!` in tests. `deny.toml` limits
dependencies to crates.io and to permissive licenses.

Install `cargo-nextest` and `cargo-deny` once per machine.

## Go lints

The lints live in the module's `.golangci.yml`, for golangci-lint v2. The policy is
the `standard` linters plus `bodyclose`, `errorlint`, `gocritic`, `gosec`, `misspell`,
`modernize`, `nilerr`, `noctx`, `revive`, `sloglint`, `unconvert`, `unparam` and
`usestdlibvars`. `gosec` and `noctx` are off in tests. `gofumpt` and `goimports`
format the code.

Install golangci-lint once per machine. The generated README has the install command.
The template sets its version, so `copier update` moves it. `govulncheck` is a `tool`
in `go.mod`, so it needs no install, and Dependabot keeps it current.

## Git hooks

Hooks run through [prek](https://prek.j178.dev), a drop-in replacement for pre-commit. One
`.pre-commit-config.yaml` covers every stack. Python projects install prek with
`uv tool install prek`. TypeScript-only projects get the same binary from the
`@j178/prek` devDependency. With the docker stack, the hadolint hook runs from its
image, so the hooks need a running Docker daemon.

## Tasks

Tasks run through [just](https://just.systems). The root `justfile` imports a
`just/<stack>.just` file for each stack. Those imports share one namespace, so recipes
carry a stack prefix: `py-`, `ts-`, `rs-` or `go-`. `just check` runs the checks for
every stack you picked.

Coverage is opt-in. `just py-cov` and `just ts-cov` print a summary. `just check`
doesn't run them. They set no threshold, and they write no report files until
something needs to upload them.

## Docker images

The Dockerfiles follow the upstream [uv](https://docs.astral.sh/uv/guides/integration/docker/)
and [pnpm](https://pnpm.io/docker) guides: multi-stage builds on `-slim` base images,
BuildKit cache mounts, a non-root runtime user, and Open Container Initiative labels.

## GitHub Actions

Every action is pinned to a commit digest, with its version in a trailing comment.
Every workflow declares least-privilege `permissions`.

Two git hooks audit `.github/`:

- [zizmor](https://docs.zizmor.sh) checks for template injection, credential leaks,
  cache poisoning and impostor commits.
- actionlint checks keys, expressions and shell scripts.

A `checks.yml` workflow runs the hooks in CI, so workflows you add later meet the same
standard. [ci-baseline.md](ci-baseline.md) lists every check, and what was left out
and why.

## Dependency updates

Generated projects use Dependabot. It needs no app to install, and it covers every
ecosystem this template generates. Version updates wait through a `cooldown` of one
week, or one month for major versions. A compromised release is usually yanked within
that time. Security updates skip the wait.

Neither Dependabot nor Renovate tracks the `FROM` base images in the Dockerfiles.
Those tags are Copier answers, so update them by hand.

This template repository uses Renovate instead of Dependabot, because its version pins
sit inside `.jinja` files that Dependabot can't parse.

## Dependency age and audits

The package managers wait a week too. uv's `exclude-newer = "1 week"` in
`pyproject.toml` and pnpm's `minimumReleaseAge` in `pnpm-workspace.yaml` skip any
release younger than a week. So `uv lock` or `pnpm install` can't pull in a release
that Dependabot would still hold back. Both settings live in the project, so every
machine writes the same lockfile. Go has no such setting. For a Go module,
Dependabot's cooldown is the only wait.

`just check` and CI also audit dependencies for known advisories:

- `uv audit` checks every locked Python dependency.
- `pnpm audit --prod` checks the TypeScript dependencies that ship.
- `cargo deny check` checks Rust dependencies and their licenses.
- `govulncheck` reports Go advisories whose code the module actually reaches.

Knip reports unused files, exports and dependencies in the TypeScript package.

## Licenses

The license options are `MIT`, `Apache-2.0`, `BSD-3-Clause` or none. The texts come
from the GitHub licenses API, with the copyright placeholders filled in.

## Release workflows

Each release workflow splits the build from the publish step:

1. The build job re-runs the checks, then tests the artifact itself. It installs the
   wheel into a clean environment and runs the tests, or it checks the npm tarball
   with `publint`.
2. The publish job downloads the artifact and uploads it. It is the only job with
   `id-token: write`, and it runs no project code.

Images pushed to the GitHub Container Registry carry a software bill of materials
(SBOM) and a provenance attestation.
