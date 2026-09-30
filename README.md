# project-templates

[![Copier](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/copier-org/copier/master/img/badge/badge-black.json)](https://github.com/copier-org/copier)
[![CI](https://github.com/simonvanlierde/project-templates/actions/workflows/ci.yml/badge.svg)](https://github.com/simonvanlierde/project-templates/actions/workflows/ci.yml)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A starter template for new projects, built with [Copier](https://copier.readthedocs.io).
One `copier copy` scaffolds any mix of `python`, `ts`, `rust`, `go` and `docker`, chosen by the `stacks` answer.

## Getting started

```sh
mkdir myproject && cd myproject && git init
copier copy gh:simonvanlierde/project-templates .
just py-sync   # python stack: installs and writes uv.lock
just ts-sync   # ts stack: installs and writes pnpm-lock.yaml
git add -A && git commit -m "chore: scaffold"
```

Copier downloads the template, so you don't need to clone this repo.

Commit the lockfile before your first push. CI runs `uv sync --locked`,
`pnpm install --frozen-lockfile` and `cargo clippy --locked`, all of which fail without one.

## Pulling in template fixes

```sh
copier update
```

The same command also changes answers: re-tick `stacks` to add a stack, or flip
a publish flag. Copier updates from the last tag, on a clean tree, so tag this
repo whenever it changes.

If you scaffolded a project before the layer merge, its answers are under
`.copier/*.yml`. You can't update it across the merge. Re-run `copier copy` on
top and reconcile with git.

## What you get

| Stack    | What it writes                                                                                                                                       |
| -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| always   | The repo furniture: `README.md`, `LICENSE`, `.gitignore`, `.editorconfig`, `.github/` with Dependabot, `SECURITY.md`, and a PR template; `.pre-commit-config.yaml`; `.vscode/` recommendations; and a `justfile` |
| `python` | A Python package in `<python_dir>`: `pyproject.toml`, `.python-version`, `src/`, `tests/`, plus extra files for the `research` and `data-pipeline` kinds (see below) |
| `ts`     | A TypeScript package in `<ts_dir>`: `package.json`, `tsconfig.json`, `tsconfig.build.json`, `biome.json`, `pnpm-workspace.yaml`, `src/index.ts`, `src/index.test.ts`        |
| `rust`   | A Rust crate in `<rust_dir>`: `Cargo.toml` with a strict lint policy (see below), `clippy.toml`, `deny.toml`, and `src/lib.rs` or `src/main.rs` by `rust_kind` |
| `go`     | A Go module in `<go_dir>`: `go.mod`, `.golangci.yml` (see below), and by `go_kind` either a library package with a table test and an Example, or a `main.go` with its test |
| `docker` | Per containerized stack: `Dockerfile`, `.dockerignore`, a runnable `/health` entrypoint. Plus `compose.yaml` at the repo root                        |

Each stack also gets a CI workflow in `.github/workflows/`, a `just/<stack>.just`
recipe file, and a release workflow if the matching publish answer is on. A Python package
nested below the repo root gets its own `README.md` too.

## Picking a Python `kind`

| `kind`          | Pick it when                                                                  | It adds                                          |
| --------------- | ----------------------------------------------------------------------------- | ------------------------------------------------ |
| `library`       | Other projects install and import the package                                 | Project URLs, and the option to publish to PyPI  |
| `app`           | You run the code, and nothing imports it                                      | Nothing beyond the package                       |
| `research`      | You analyse data in notebooks, and you manage the data files by hand          | `notebooks/`, `data/`, and JupyterLab            |
| `data-pipeline` | The repo rebuilds a dataset from third-party sources, and each value must trace back to a download | See below                    |
| `web-service`   | The package is an HTTP service that runs as a container (needs the `docker` stack) | See below                    |

A `data-pipeline` project gets:

- `sources.toml`, a manifest of every input. Each source has a URL, the publisher's
  reuse terms (`terms`, `terms_url`), and a `status`. A source marked
  `status = "unimplemented"` is one you know about but don't read yet.
- `data/raw/` and `data/processed/`, both gitignored, so the repo never
  redistributes source data.
- A small standard-library module with three stages. `fetch` writes each download
  atomically, with a record of its URL, retrieval time, SHA-256 and vintage. `build`
  refuses a download made for a different request than the manifest now makes, and
  verifies checksums before it parses. `validate` re-reads the published output and
  re-hashes the raw files.
- `just fetch`, `just build`, `just validate`, and `just pipeline` for all three.
- `ATTRIBUTION.md`, which states what the repo reuses and on what terms. The code
  license doesn't cover those.
- Tests that run the whole pipeline against a local file, with no network.
- A CI workflow that runs the pipeline for real on the manifest's URLs, then uploads
  only the fetch records. The tests that compare published values with literal
  numbers run only in its weekly scheduled run (`TRIPWIRE=1`), so a publisher
  revision fails that run, not your PRs.

The example source in `sources.toml` is about 1 kB. Replace it, and the tests that
read its output, with your own sources.

This kind comes from a rebuild of a published research database from its public
sources. That project started from `research` and added the manifest, the data
split, the recipes, the attribution file and the pipeline CI by hand. The generic
parts are now the template. The readers for each source stayed in that project.

A `web-service` project gets:

- A FastAPI app with one route: `GET /health`, a fixed `{"status": "ok"}` that the
  image's `HEALTHCHECK` probes.
- An entrypoint that reads `HOST` and `PORT`. It listens on `127.0.0.1` unless
  `HOST` says otherwise; the image sets `HOST=0.0.0.0` and `compose.yaml` publishes
  the port on `127.0.0.1` only.
- OpenTelemetry through zero-code instrumentation, on only when
  `OTEL_EXPORTER_OTLP_ENDPOINT` is set: request spans and a request-duration
  histogram over OTLP/HTTP. The SDK reads every other `OTEL_*` variable itself.
  Without the endpoint, nothing is imported.
- `just serve`, and a `<slug>` console script, to run it outside Docker.
- Tests for `/health`, telemetry off, and telemetry on (console exporters in a child
  process: one span and one duration point per request).

## Layout: one package or a monorepo

`python_dir`, `ts_dir`, `rust_dir` and `go_dir` all default to `.`, the repo root. At `.` you get a
plain single-package repo. Any other value nests the package:

```text
apps/api/{pyproject.toml,src,tests,Dockerfile,.dockerignore}
apps/web/{package.json,tsconfig.json,biome.json,src,Dockerfile,.dockerignore}
compose.yaml            # one service per image, api on 8000 and web on 8001
.github/workflows/      # python.yml and ts.yml scoped with working-directory + paths, docker.yml a matrix over both images
justfile, just/, .pre-commit-config.yaml, .copier-answers.yml
```

Only the package moves. The workflows, hooks, and justfile stay at the root.

Two stacks can share `.`, but two *images* can't: both Dockerfiles would land at
`./Dockerfile`. `docker_stacks` rejects that combination.

To move a package later, run `copier update` with the new directory, then delete
the old one by hand: copier cleans up files that left the *template*, not files
that moved because an *answer* did.

This isn't a real workspace. Its `pnpm-workspace.yaml` holds settings and no
`packages:` list, and there's no `[tool.uv.workspace]`. Once you need two packages in one language, switch to
that language's workspace tooling.

## Tooling

|            | Lint and format | Types | Tests    | Packaging                        |
| ---------- | --------------- | ----- | -------- | -------------------------------- |
| Python     | `ruff`          | `ty`  | `pytest` | `uv`, locked, `uv_build` backend |
| TypeScript | `biome`         | `tsc` | `vitest` | `pnpm`                           |
| Rust       | `rustfmt`, `clippy` | `rustc` | `cargo nextest`, plus `cargo test --doc` | `cargo`, checked by `cargo-deny` |
| Go         | `golangci-lint` (`gofumpt`, `goimports`) | `go vet`, via golangci-lint | `go test -race`, Examples included | Go modules, checked by `govulncheck` |

**Rust lints** live in the crate's `Cargo.toml` `[lints]` table, because clippy has no
user-wide config. The policy is clippy's `pedantic` group plus restriction lints against
shortcuts: `unwrap_used`, `expect_used`, `dbg_macro`, `todo`, `unimplemented`, and
`allow_attributes_without_reason`. `unsafe_code` is forbidden. A library also warns on
`missing_docs` and on printing to stdout or stderr. `clippy.toml` allows `unwrap`,
`expect` and `dbg!` in tests, and `deny.toml` limits dependencies to crates.io and
permissive licenses. Install `cargo-nextest` and `cargo-deny` once per machine.

**Go lints** live in the module's `.golangci.yml`, for golangci-lint v2. The policy is the
`standard` linters plus `bodyclose`, `errorlint`, `gocritic`, `gosec`, `misspell`,
`modernize`, `nilerr`, `noctx`, `revive`, `sloglint`, `unconvert`, `unparam` and
`usestdlibvars`, with `gosec` and `noctx` off in tests. `gofumpt` and `goimports` format.
Install golangci-lint once per machine (the scaffold's README has the line);
`govulncheck` runs through `go run` at a pinned version, so it needs no install.
Both tool versions come from the template, so `copier update` moves them, not Dependabot.

**Git hooks** run through [prek](https://prek.j178.dev): one runner and one
`.pre-commit-config.yaml` covering every stack. Python projects install it with
`uv tool install prek`. TypeScript-only projects get the same binary from the
`@j178/prek` devDependency.

**Tasks** run through [just](https://just.systems). The root `justfile` imports a
`just/<stack>.just` from each stack. Recipes use the `py-`, `ts-`, `rs-` and `go-` prefixes
because those imports share one namespace. Your `stacks` answer builds
`just check`, which runs everything.

**Docker images** follow the upstream [uv](https://docs.astral.sh/uv/guides/integration/docker/)
and [pnpm](https://pnpm.io/docker) guides: multi-stage builds on `-slim` bases, BuildKit
cache mounts, a non-root runtime user, and Open Container Initiative labels.

**GitHub Actions** pins actions to commit digests and puts the version in a
trailing comment. Every workflow declares least-privilege `permissions`. A
[zizmor](https://docs.zizmor.sh) git hook audits `.github/` for template injection,
credential leakage, cache poisoning, and impostor digests, and an actionlint hook
checks keys, expressions, and shell. A `hygiene.yml` workflow runs the hooks in CI, so
the workflows you add later meet the same standard. CI renders the templates before it
audits them. `.jinja` isn't YAML, but its output is. [docs/ci-baseline.md](docs/ci-baseline.md)
lists every check, and what was left out and why.

**Coverage** is opt-in: `just py-cov` and `just ts-cov` (not `just check`) print a
summary and write `coverage.xml` / `coverage/lcov.info` for an uploader. No threshold.

**Licenses** are `MIT`, `Apache-2.0`, `BSD-3-Clause` or none. The texts come from
the GitHub licenses API, with the copyright placeholders filled in.

**Dependency updates** in scaffolded projects go through Dependabot: no app to install,
and it covers every ecosystem this template generates. Version updates wait through a
`cooldown` of one week, or one month for majors. A compromised release is usually
yanked during that time. Security updates skip it. This repo uses Renovate because its
pins live inside `.jinja` files Dependabot can't parse. Neither bot tracks the `FROM`
base images. Those tags are copier answers, so bump them by hand.

**Dependency age and audits.** Resolvers wait a week too: uv's `exclude-newer = "1 week"`
in `pyproject.toml` and pnpm's `minimumReleaseAge` in `pnpm-workspace.yaml` skip any
release younger than that, so a `uv lock` or `pnpm install` can't pull in a release
that Dependabot would still hold back. Both settings are per project, so every machine
writes the same lockfile. Go has no such setting, so for a Go module Dependabot's cooldown
is the only wait. `just check` and CI also audit dependencies for known
advisories: `uv audit` (every locked dependency), `pnpm audit --prod` (what ships),
`cargo deny check`, and `govulncheck` (advisories whose code the module reaches). Knip reports unused files, exports and dependencies in the TypeScript
package.

## Publishing

All three publish targets default to **off**. Each one needs a trust relationship set up
on the registry side before it can work.

| Answer            | Off by default                                                              | On                                                     |
| ----------------- | -------------------------------------------------------------------------- | ------------------------------------------------------ |
| `publish_to_pypi` | `classifiers = ["Private :: Do Not Upload"]`, so PyPI rejects the upload   | `python-release.yml` publishing via trusted publishing |
| `publish_to_npm`  | `"private": true`, so pnpm refuses with `EPRIVATE` before any network call | `ts-release.yml` publishing via trusted publishing     |
| `publish_to_ghcr` | CI builds the image and smoke-tests `/health`, pushes nothing              | same smoke test, then push to the GitHub Container Registry with a software bill of materials and provenance |

To turn one on, first configure the publisher through
[pypi.org](https://pypi.org/manage/account/publishing/) or
[npmjs.com](https://docs.npmjs.com/trusted-publishers/). Then flip the answer and run
`copier update`. Both use OpenID Connect trusted publishing, so there's no token to
store. npm can't create a brand-new package that way, so publish version one by hand first.

Each release workflow splits build from publish. The build job re-runs the checks and
then validates the artifact itself: the wheel installed into a clean environment and
tested, the tarball checked with `publint`. Only the publish job carries
`id-token: write`, and it runs no project code: it downloads the artifact and uploads it.

## Working on the templates themselves

To try out edits you haven't tagged yet, pass `--vcs-ref=HEAD`:

```sh
copier copy --vcs-ref=HEAD gh:simonvanlierde/project-templates .
```

Without it, copier renders the last tag and your changes never reach the output.

Before you push, run the hooks and the render checks CI runs. The script renders
uncommitted edits too:

```sh
prek run -a
scripts/check-render.sh "$(mktemp -d)"
```

A render of a tag from a local checkout records `gh:simonvanlierde/project-templates`
as `_src_path` in `.copier-answers.yml`, not the local path. A local path would leak
your home directory and break `copier update` on any other machine.

A render of any other commit keeps the local path, because that commit may not exist
on GitHub. `_commit` is then the checkout's commit, and `copier update` can't check
out a commit that exists only on your machine (an unpushed tag, a deleted branch) or
in a fork. Before you commit a real project's answers file, render from a tag pushed
to this repository, or edit `_src_path` and `_commit`.

To test an update against a local checkout, set `_src_path` to the checkout's path
for that run, as the CI `update` job does.
