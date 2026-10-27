# Tooling

Which tools each stack uses, and why the defaults are what they are.
[usage.md](usage.md#choosing-your-stacks) lists the files each stack writes, and
[ci-baseline.md](ci-baseline.md) every workflow check.

## Tools per stack

|            | Lint and format                          | Types                        | Tests                                    | Packaging                            |
| ---------- | ---------------------------------------- | ---------------------------- | ---------------------------------------- | ------------------------------------ |
| Python     | `ruff`                                   | `ty`                         | `pytest`                                 | `uv`, locked, `uv_build` backend     |
| TypeScript | `biome`                                  | `tsc`                        | `vitest`, plus Playwright and axe for a `web-app` | `pnpm`, plus Vite for a `web-app` |
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
The template pins the golangci-lint version, so `copier update` bumps it. `govulncheck`
is a `tool` in `go.mod`, so it needs no install, and Dependabot keeps it current.

## Git hooks

Hooks run through [prek](https://prek.j178.dev), a drop-in replacement for pre-commit. One
`.pre-commit-config.yaml` covers every stack. Python projects install prek with
`uv tool install prek`. TypeScript-only projects get the same binary from the
`@j178/prek` devDependency. With the docker stack, the hadolint hook runs from its
image, so the hooks need a running Docker daemon.

## Tasks

Tasks run through [just](https://just.systems). The root `justfile` imports a
`just/<stack>.just` file for each stack. Those imports share one namespace, so recipes
carry a stack prefix: `py-`, `ts-`, `rs-` or `go-`. The exceptions are a few recipes only
one kind has: `fetch`, `build`, `validate` and `pipeline` (data-pipeline), `serve`
(web-service) and `up` (docker). `just check` runs the checks for every stack you picked.

Coverage is opt-in. `just py-cov` and `just ts-cov` print a summary. They set no
threshold and write no report files. With the `codecov` option, CI writes its own report
and uploads it to Codecov. `just check` then runs the TypeScript tests with coverage too,
as CI does, so a threshold you add to `vitest.config.ts` fails locally as well.

## Docker images

The Dockerfiles follow the upstream [uv](https://docs.astral.sh/uv/guides/integration/docker/)
and [pnpm](https://pnpm.io/docker) guides: multi-stage builds on `-slim` base images,
BuildKit cache mounts, a non-root runtime user, and Open Container Initiative labels.

## Dependencies

Generated projects use Dependabot by default, which needs no app and covers every
ecosystem here. The `dependency_bot` answer switches to Renovate, with the same rules in
`renovate.json5`. Either way:

- Version updates come weekly, in three grouped PRs: actions and hooks together, dev
  tooling, and minor and patch bumps of runtime dependencies.
- A runtime major gets a PR of its own.
- Updates wait a week, or a month for a major version of a package dependency.
- The bot's security PRs skip the wait.

The one difference: Dependabot also groups npm security updates into a single PR, and
the Renovate config has no such group.

Renovate also refreshes the uv, pnpm and Cargo lockfiles every Monday. Its security PRs
cover only the dependencies a manifest names, so a fix in a dependency of a dependency
arrives with that refresh, once the fix is a week old.

uv's `exclude-newer = "1 week"` and pnpm's `minimumReleaseAge` hold back the same
releases, so `uv lock` or `pnpm install` can't pull in one that the bot is still waiting
on. Go has no such setting. These two settings have no security exception. A fix released
within the last week can't be locked, and `uv audit` keeps failing until the week passes.

To lock one fixed package early, exempt it by name and delete the exemption after a week:

- uv: add the package to `[tool.uv]` in `pyproject.toml`, with a timestamp after the
  fix's release, then run `uv lock --upgrade-package <pkg>`:

  ```toml
  exclude-newer-package = { certifi = "2026-10-21T00:00:00Z" }
  ```

  The flag `uv lock --exclude-newer-package <pkg>=<timestamp>` alone doesn't last:
  the next `uv sync` relocks without it and moves the package back. uv has no
  environment variable for this setting.
- pnpm: `pnpm audit --fix=update` does it for you. It adds each patched version to
  `minimumReleaseAgeExclude` in `pnpm-workspace.yaml` and locks it. By hand, list the
  package there and run `pnpm install`. It matches by name, or by `name@version`.
  `minimumReleaseAgeExcludePrune` drops an entry once the lockfile moves past that
  version, so a `name@version` entry needs no clean-up.

  ```yaml
  minimumReleaseAgeExclude:
    - is-odd@3.0.1
  ```

Dependabot doesn't read `exclude-newer`
([dependabot-core#13816](https://github.com/dependabot/dependabot-core/issues/13816)), and
uv applies it whenever it relocks, so a Dependabot security PR can't lock a fix that is
less than a week old either. Use the exemption above.

Nothing tracks the `FROM` base images in the Dockerfiles. Those tags are Copier
answers, so update them by hand. They are pinned by tag only. Each rebuild takes the
tag's latest security fixes, so a build isn't reproducible byte for byte. This template
repository uses Renovate, because Dependabot can't parse `.jinja` files.

The same template version and the same answers render the same files, with one exception:
a web app's legal pages start from the date of the render. The copyright year is an answer,
so it stays the same. This repository's CI renders with one pinned copier version. The
installs are not repeatable byte for byte. A fresh render has no lockfiles, and its first
`uv lock` or `pnpm install` picks the newest releases that are at least a week old on that
day. Once you commit the lockfiles, CI installs exactly what they list.

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

With PyPI publishing, a final job attaches the distributions and their provenance bundle
to a draft GitHub release, then publishes it. This job has only `contents: write` and
runs no project code. Other projects keep the separate `release.yml` workflow.

Images pushed to the GitHub Container Registry carry a software bill of materials
(SBOM) and a provenance attestation.
