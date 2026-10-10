# project-templates

[![Copier](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/copier-org/copier/master/img/badge/badge-black.json)](https://github.com/copier-org/copier)
[![CI](https://github.com/simonvanlierde/project-templates/actions/workflows/ci.yml/badge.svg)](https://github.com/simonvanlierde/project-templates/actions/workflows/ci.yml)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Start a new project with linting, tests, CI and releases already set up.

This is a [Copier](https://copier.readthedocs.io) template. You answer a few questions,
and it writes a ready-to-commit repository for Python, TypeScript, Rust, Go, Docker, or
any mix of them. When the template improves later, one command pulls the changes into
your project.

## What you get

- **A working project on day one.** A package with source, a passing test, and a
  `justfile`, so `just check` runs every linter and test the same way CI does.
- **CI for each language.** GitHub Actions workflows that lint, type-check, test and
  audit dependencies on every push and pull request.
- **Supply-chain safety by default.** Actions are pinned to exact commits, workflows
  are audited for common attacks, and uv and pnpm wait a week before they install a
  new release.
- **Optional publishing.** Release workflows for PyPI, npm and the GitHub Container
  Registry, with no tokens to store. All of them start off.
- **The usual repository files.** `README.md`, `CHANGELOG.md`, `LICENSE`,
  `SECURITY.md`, `.gitignore`, `.editorconfig`, Dependabot, git hooks and VS Code
  recommendations.

## Quick start

You need [Copier](https://copier.readthedocs.io/en/stable/#installation) 9.1 or later
and [just](https://just.systems). Each language also needs its own toolchain: `uv` for
Python, `pnpm` for TypeScript, `cargo` for Rust, or `go` for Go.

1. Create an empty repository:

   ```sh
   mkdir myproject && cd myproject && git init
   ```

2. Run the template and answer the questions:

   ```sh
   copier copy gh:simonvanlierde/project-templates .
   ```

   Copier downloads the template itself, so you don't need to clone this repository.

3. Install dependencies and write the lockfiles. Run the line for each stack you
   picked:

   ```sh
   just py-sync   # Python: writes uv.lock
   just ts-sync   # TypeScript: writes pnpm-lock.yaml
   just go-sync   # Go: writes go.sum
   just rs-sync   # Rust: writes Cargo.lock
   ```

4. Run every linter and test, the same checks CI runs. Rust and Go need a few tools
   installed once per machine first. The new project's README lists them.

   ```sh
   just check
   ```

5. Commit everything, lockfiles included:

   ```sh
   git add -A && git commit -m "chore: scaffold"
   ```

Commit the lockfiles before your first push. CI installs exactly what they list
(`uv sync --locked`, `pnpm install --frozen-lockfile`, `cargo clippy --locked`, and
`go.sum` for Go), so it fails without them.

The new project's README also shows how to turn on the git hooks.

## Choosing your stacks

The `stacks` question is a multi-select. Pick any combination:

| Stack    | What it adds                                                                   |
| -------- | ------------------------------------------------------------------------------ |
| `python` | A Python package with `pyproject.toml`, `src/` and `tests/`                     |
| `ts`     | A TypeScript package with `package.json`, `tsconfig.json` and a test           |
| `rust`   | A Rust crate, as a library or a binary, with strict clippy lints               |
| `go`     | A Go module, as a library or a binary, with golangci-lint                      |
| `docker` | A `Dockerfile` for the Python or TypeScript package, and a root `compose.yaml` |

Each stack also gets its own CI workflow in `.github/workflows/` and its own recipes in
`just/<stack>.just`. [What you get](#what-you-get) lists the files that every project
gets.

### Python project kinds

A Python project also asks for a `kind`:

| `kind`          | Pick it when                                                      | It adds                                          |
| --------------- | ----------------------------------------------------------------- | ------------------------------------------------ |
| `library`       | Other projects install and import your package                    | Project URLs, and the option to publish to PyPI  |
| `app`           | You run the code yourself, and nothing imports it                 | Nothing beyond the package                       |
| `research`      | You analyse data in notebooks and manage the data files by hand   | `notebooks/`, `data/`, JupyterLab, `CITATION.cff` |
| `data-pipeline` | You rebuild a dataset from public sources, traceable to each download | A source manifest and fetch, build and validate steps |
| `web-service`   | You run an HTTP service in a container (needs the `docker` stack)  | A FastAPI app with a `/health` endpoint          |

[docs/python-kinds.md](docs/python-kinds.md) describes what the `data-pipeline` and
`web-service` kinds generate.

### One package or a monorepo

By default, each package sits at the repository root. To put several packages in one
repository, give each a directory when Copier asks, such as `python_dir: apps/api` and
`ts_dir: apps/web`:

```text
apps/api/{pyproject.toml,src,tests,Dockerfile,.dockerignore}
apps/web/{package.json,tsconfig.json,biome.json,src,Dockerfile,.dockerignore}
compose.yaml            # one service per image, api on 8000 and web on 8001
.github/workflows/      # python.yml and ts.yml scoped with working-directory + paths, docker.yml a matrix over both images
justfile, just/, .pre-commit-config.yaml, .copier-answers.yml
```

Only the packages move. The workflows, hooks and `justfile` stay at the root.

Two stacks can share the root, but two Docker images can't, because both Dockerfiles
would land at `./Dockerfile`. Copier rejects that combination.

This layout holds one package per language. It isn't a uv or pnpm workspace. Once you
need two packages in the same language, switch to that language's workspace tooling.

## Keeping your project up to date

Run this in your project to pull in template changes:

```sh
copier update
```

Copier needs a clean working tree. It updates to the latest tagged release of this
template, and [CHANGELOG.md](CHANGELOG.md) lists what each release changes.

The same command also lets you change your answers. If you add a stack to `stacks` or
turn on a publish option, Copier writes the new files.

To move a package to another directory, run `copier update` with the new directory.
Then delete the old directory by hand. Copier removes files that left the template,
but not files that moved because an answer changed.

## Publishing

Publishing is off by default. While an option is off, something blocks an accidental
release:

| Option            | While off                                                   | When on                                                  |
| ----------------- | ----------------------------------------------------------- | -------------------------------------------------------- |
| `publish_to_pypi` | PyPI rejects uploads (`Private :: Do Not Upload` classifier) | `python-release.yml` publishes to PyPI                   |
| `publish_to_npm`  | pnpm refuses to publish (`"private": true`)                 | `ts-release.yml` publishes to npm                        |
| `publish_to_ghcr` | CI builds the image and tests `/health`, but pushes nothing | CI also pushes the image to the GitHub Container Registry |

PyPI and npm use trusted publishing (OpenID Connect), so you store no tokens. The
registry needs to trust your repository first. To turn publishing on:

1. Add a trusted publisher on [pypi.org](https://pypi.org/manage/account/publishing/)
   or [npmjs.com](https://docs.npmjs.com/trusted-publishers/).
2. For a new npm package, publish the first version by hand. npm can't create a
   package through trusted publishing.
3. Run `copier update`, and answer yes to the publish option.

## How it works

[docs/tooling.md](docs/tooling.md) covers the tools each stack uses, the lint policies,
the Docker images, dependency updates and the release workflows.
[docs/ci-baseline.md](docs/ci-baseline.md) lists every CI check, and what was left out
and why.

## Contributing

[CONTRIBUTING.md](CONTRIBUTING.md) explains how to test changes to the template before
you tag a release.
