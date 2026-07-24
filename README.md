# project-templates

[![CI](https://github.com/simonvanlierde/project-templates/actions/workflows/ci.yml/badge.svg)](https://github.com/simonvanlierde/project-templates/actions/workflows/ci.yml)
[![Copier](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/copier-org/copier/master/img/badge/badge.json)](https://github.com/copier-org/copier)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Starter templates for new projects, built with [Copier](https://copier.readthedocs.io).

The templates are split into four layers: `base`, `python`, `ts` and `docker`. You apply
one layer at a time and answer its questions. Each layer writes its own answers file
under `.copier/`, so you can update a layer later without touching the others.

## Getting started

```sh
mkdir myproject && cd myproject && git init
copier copy gh:simonvanlierde/project-templates .   # pick: base
copier copy gh:simonvanlierde/project-templates .   # pick: python
uv sync && git add -A && git commit -m "chore: scaffold"
```

You don't need to clone this repo. Copier downloads and caches the template for you.

Commit the lockfile before your first push. CI runs `uv sync --locked` and
`pnpm install --frozen-lockfile`, both of which fail without one.

## Pulling in template fixes

When this template changes, update your project one layer at a time:

```sh
copier update -a .copier/base.yml
copier update -a .copier/python.yml
```

Copier only updates from a tagged template version, and only when your git tree is
clean. So tag this repo whenever you change a layer.

## The layers

| Layer    | What it writes                                                                                                                                       |
| -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| `base`   | The repo furniture: `README.md`, `LICENSE`, `.gitignore`, `.editorconfig`, `.github/dependabot.yml`, `.pre-commit-config.yaml`, and a `justfile`     |
| `python` | A Python package in `<python_dir>`: `pyproject.toml`, `.python-version`, `src/`, `tests/`, and `data/` + `notebooks/` for a research project         |
| `ts`     | A TypeScript package in `<ts_dir>`: `package.json`, `tsconfig.json`, `tsconfig.build.json`, `biome.json`, `src/index.ts`, `src/index.test.ts`        |
| `docker` | Per containerized stack: `Dockerfile`, `.dockerignore`, a runnable `/health` entrypoint. Plus `compose.yaml` at the repo root                        |

Each stack layer also drops a CI workflow into `.github/workflows/`, and a release
workflow if the matching publish answer is on. A package nested below the repo root gets
its own `README.md` too. The `justfile` and the per-layer `just/<layer>.just` files
appear only if `use_just` is on, which it is by default.

### Apply `base` first and `docker` last

`base` records the answers the other layers read: where each package lives, and which
stacks the repo uses. `docker` reads `module_name`, `python_version` and `node_version`
out of the stack layers' answers files, so at least one stack layer has to exist first.

Nothing stops you from getting the order wrong. The layers write disjoint sets of files,
so nothing collides — the mistake shows up later, at `uv sync` or `docker build`.

### Tell `base` which stacks you'll use

`base` writes the git hooks config, the justfile and the project's README, so it asks up
front which stacks the repo will have. A stack you leave out still gets its CI workflow,
but no git hooks and no line in `just check`.

Each stack layer prints a note when it notices it's missing from that list. To fix it,
re-run `copier update -a .copier/base.yml` and tick the stack.

## Layout: one package or a monorepo

`base` asks for `python_dir` and `ts_dir`. Both default to `.`, the repo root, and every
other layer reads those answers — so you decide the layout once.

At `.` you get a plain single-package repo. Any other value nests the package:

```text
apps/api/{pyproject.toml,src,tests,Dockerfile,.dockerignore}
apps/web/{package.json,tsconfig.json,biome.json,src,Dockerfile,.dockerignore}
compose.yaml            # one service per image, api on 8000 and web on 8001
.github/workflows/      # python.yml and ts.yml scoped with working-directory + paths, docker.yml a matrix over both images
justfile, just/, .pre-commit-config.yaml, .copier/
```

Only the package moves. The stack layers still apply at the repo root, so
`copier update -a .copier/python.yml` keeps working unchanged.

Two stacks can share `.`, but two *images* cannot: both Dockerfiles would land at
`./Dockerfile`. `docker_stacks` rejects that combination.

To move a package later, run `copier update -a .copier/base.yml` with the new directory,
then `copier update -a .copier/python.yml` to write the package to its new path. Delete
the old directory by hand — copier cleans up files that left the *template*, not files
that moved because an *answer* did.

None of this is a real workspace: there's no `pnpm-workspace.yaml` and no
`[tool.uv.workspace]`. Once you need a second package in the same language, stop
scaffolding from this template and set up that language's workspace instead.

## Tooling

|            | Lint and format | Types | Tests    | Packaging                        |
| ---------- | --------------- | ----- | -------- | -------------------------------- |
| Python     | `ruff`          | `ty`  | `pytest` | `uv`, locked, `uv_build` backend |
| TypeScript | `biome`         | `tsc` | `vitest` | `pnpm`                           |

**Git hooks** run through [prek](https://prek.j178.dev) — one runner and one
`.pre-commit-config.yaml` covering every stack. Python projects install it with
`uv tool install prek`. TypeScript-only projects get the same binary from the
`@j178/prek` devDependency.

**Tasks** run through [just](https://just.systems), unless you turn off `use_just`
(default on). The root `justfile` imports a `just/<layer>.just` from each stack layer.
Recipes are prefixed `py-` and `ts-` because those imports share one namespace.
`just check` runs everything, and is built from your `stacks` answer.

**Docker images** follow the upstream [uv](https://docs.astral.sh/uv/guides/integration/docker/)
and [pnpm](https://pnpm.io/docker) guides: multi-stage builds on `-slim` bases, BuildKit
cache mounts, a non-root runtime user, OCI labels.

**GitHub Actions** are pinned to commit digests, with the human-readable version in a
trailing comment. Every workflow declares least-privilege `permissions`. A
[zizmor](https://docs.zizmor.sh) git hook audits `.github/` for the mistakes that
convention prevents — template injection, credential leakage, cache poisoning, a digest
that isn't the commit it claims to be — so the workflows you add later are held to the
same line as the ones this template wrote. This repo audits its own templates by
rendering them in CI first: `.jinja` is not YAML, but its output is.

**Licenses** are MIT, Apache-2.0, BSD-3-Clause or none. The texts come from the GitHub
licenses API, with the copyright placeholders filled in.

**Dependency updates** in scaffolded projects go through Dependabot: no app to install,
and it covers every ecosystem these layers generate. This repo itself uses Renovate,
because its pins live inside `.jinja` templates that Dependabot can't parse. Neither bot
tracks the `FROM` base images — those tags are copier answers, so bump them by hand.

## Publishing

All three publish targets default to **off**. Each one needs a trust relationship set up
on the registry side before it can work.

| Answer            | Off (default)                                                              | On                                                     |
| ----------------- | -------------------------------------------------------------------------- | ------------------------------------------------------ |
| `publish_to_pypi` | `classifiers = ["Private :: Do Not Upload"]`, so PyPI rejects the upload   | `python-release.yml` publishing via trusted publishing |
| `publish_to_npm`  | `"private": true`, so pnpm refuses with `EPRIVATE` before any network call | `ts-release.yml` publishing via trusted publishing     |
| `publish_to_ghcr` | CI builds the image and smoke-tests `/health`, pushes nothing              | same smoke test, then push to GHCR, SBOM, provenance   |

To turn one on, configure the publisher first
([pypi.org](https://pypi.org/manage/account/publishing/),
[npmjs.com](https://docs.npmjs.com/trusted-publishers/)), then flip the answer and run
`copier update`. Both use OIDC trusted publishing, so there's no token to store. npm
can't create a brand-new package that way, so publish version one by hand first.

Each release workflow splits build from publish. The build job re-runs lint, types and
tests, then checks the artifact itself: the Python job installs the built wheel into a
clean environment and runs the suite against it, and the npm job runs `publint` over the
packed tarball. Only the publish job carries `id-token: write`, and it runs no project
code at all — it downloads the artifact and uploads it.

## Working on the templates themselves

To try out edits you haven't tagged yet, pass `--vcs-ref=HEAD`:

```sh
copier copy --vcs-ref=HEAD gh:simonvanlierde/project-templates .
```

Without it, copier renders the last tag and your changes never reach the output.

Scaffold your test project somewhere real rather than under macOS's `$TMPDIR`. Copier
resolves symlinks on only one side of its `_external_data` path check, so a destination
under `/var/folders` fails with `ForbiddenPathError` on the second layer. `--trust` works
around it. CI's Linux `$RUNNER_TEMP` isn't affected.
