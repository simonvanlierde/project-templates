# project-templates

[![Copier](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/copier-org/copier/master/img/badge/badge-black.json)](https://github.com/copier-org/copier)
[![CI](https://github.com/simonvanlierde/project-templates/actions/workflows/ci.yml/badge.svg)](https://github.com/simonvanlierde/project-templates/actions/workflows/ci.yml)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A starter template for new projects, built with [Copier](https://copier.readthedocs.io).
One `copier copy`, and a `stacks` answer picks any mix of `python`, `ts` and `docker`.

## Getting started

```sh
mkdir myproject && cd myproject && git init
copier copy gh:simonvanlierde/project-templates .
uv sync && git add -A && git commit -m "chore: scaffold"
```

You don't need to clone this repo. Copier downloads and caches the template for you.

Commit the lockfile before your first push. CI runs `uv sync --locked` and
`pnpm install --frozen-lockfile`, both of which fail without one.

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
| `python` | A Python package in `<python_dir>`: `pyproject.toml`, `.python-version`, `src/`, `tests/`, and `data/` + `notebooks/` for a research project         |
| `ts`     | A TypeScript package in `<ts_dir>`: `package.json`, `tsconfig.json`, `tsconfig.build.json`, `biome.json`, `src/index.ts`, `src/index.test.ts`        |
| `docker` | Per containerized stack: `Dockerfile`, `.dockerignore`, a runnable `/health` entrypoint. Plus `compose.yaml` at the repo root                        |

Each stack also gets a CI workflow in `.github/workflows/`, a `just/<stack>.just`
recipe file, and a release workflow if the matching publish answer is on. A package
nested below the repo root gets its own `README.md` too.

## Layout: one package or a monorepo

`python_dir` and `ts_dir` both default to `.`, the repo root. At `.` you get a
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

This isn't a real workspace. It has neither `pnpm-workspace.yaml` nor
`[tool.uv.workspace]`. Once you need two packages in one language, switch to
that language's workspace tooling.

## Tooling

|            | Lint and format | Types | Tests    | Packaging                        |
| ---------- | --------------- | ----- | -------- | -------------------------------- |
| Python     | `ruff`          | `ty`  | `pytest` | `uv`, locked, `uv_build` backend |
| TypeScript | `biome`         | `tsc` | `vitest` | `pnpm`                           |

**Git hooks** run through [prek](https://prek.j178.dev): one runner and one
`.pre-commit-config.yaml` covering every stack. Python projects install it with
`uv tool install prek`. TypeScript-only projects get the same binary from the
`@j178/prek` devDependency.

**Tasks** run through [just](https://just.systems). The root `justfile` imports a
`just/<stack>.just` from each stack. Recipes use the `py-` and `ts-` prefixes
because those imports share one namespace. Your `stacks` answer builds
`just check`, which runs everything.

**Docker images** follow the upstream [uv](https://docs.astral.sh/uv/guides/integration/docker/)
and [pnpm](https://pnpm.io/docker) guides: multi-stage builds on `-slim` bases, BuildKit
cache mounts, a non-root runtime user, and Open Container Initiative labels.

**GitHub Actions** pins actions to commit digests and puts the version in a
trailing comment. Every workflow declares least-privilege `permissions`. A
[zizmor](https://docs.zizmor.sh) git hook audits `.github/` for template injection,
credential leakage, cache poisoning, and impostor digests, so the workflows you add
later meet the same standard. CI renders the templates before it audits them.
`.jinja` isn't YAML, but its output is.

**Coverage** is opt-in: `just py-cov` and `just ts-cov` (not `just check`) print a
summary and write `coverage.xml` / `coverage/lcov.info` for an uploader. No threshold.

**Licenses** include Apache-2.0. The choices named `MIT` and `BSD-3-Clause`
refer to licenses from the Massachusetts Institute of Technology and Berkeley
Software Distribution. The texts come from the GitHub licenses API, with the
copyright placeholders filled in.

**Dependency updates** in scaffolded projects go through Dependabot: no app to install,
and it covers every ecosystem this template generates. Version updates wait through a
`cooldown` of one week, or one month for majors. A compromised release is usually
yanked during that time. Security updates skip it. This repo uses Renovate because its
pins live inside `.jinja` files Dependabot can't parse. Neither bot tracks the `FROM`
base images. Those tags are copier answers, so bump them by hand.

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
