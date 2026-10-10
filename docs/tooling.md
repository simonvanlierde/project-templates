# Tooling

Which tools each stack uses, and why the defaults are what they are. The
[README](../README.md#what-you-get) lists the files each stack writes.

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
The template pins the golangci-lint version, so `copier update` bumps it. `govulncheck` is a `tool`
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
doesn't run them. They set no threshold and write no report files, because nothing
uploads one yet.

## Docker images

The Dockerfiles follow the upstream [uv](https://docs.astral.sh/uv/guides/integration/docker/)
and [pnpm](https://pnpm.io/docker) guides: multi-stage builds on `-slim` base images,
BuildKit cache mounts, a non-root runtime user, and Open Container Initiative labels.

## GitHub Actions

[ci-baseline.md](ci-baseline.md) lists every workflow check, and what was left out.

## Dependencies

Generated projects use Dependabot, which needs no app and covers every ecosystem
here. Version updates wait a week, or a month for majors. Security updates skip the
wait. uv's `exclude-newer = "1 week"` and pnpm's `minimumReleaseAge` hold back the
same releases, so `uv lock` or `pnpm install` can't pull in one that Dependabot is
still waiting on. Go has no such setting.

Nothing tracks the `FROM` base images in the Dockerfiles. Those tags are Copier
answers, so update them by hand. This template repository uses Renovate instead,
because Dependabot can't parse `.jinja` files.

`just check` and CI audit dependencies for known advisories:

- `uv audit` checks every locked Python dependency.
- `pnpm audit --prod` checks the TypeScript dependencies that ship.
- `cargo deny check` checks Rust dependencies and their licenses.
- `govulncheck` reports Go advisories whose code the module actually reaches.

Knip reports unused files, exports and dependencies in the TypeScript package.

## Release workflows

Each release workflow splits the build from the publish step:

1. The build job re-runs the checks, then tests the artifact itself. It installs the
   wheel into a clean environment and runs the tests, or it checks the npm tarball
   with `publint`.
2. The publish job downloads the artifact and uploads it. It is the only job with
   `id-token: write`, and it runs no project code.

Images pushed to the GitHub Container Registry carry a software bill of materials
(SBOM) and a provenance attestation.
