# Using the template

## Choosing your stacks

The `stacks` question is a multi-select. Pick any combination:

| Stack    | What it adds                                                                   |
| -------- | ------------------------------------------------------------------------------ |
| `python` | A Python package with `pyproject.toml`, `src/` and `tests/`                     |
| `ts`     | A TypeScript package or a Vite web app ([kinds](#typescript-kinds)), with a test |
| `rust`   | A Rust crate, as a library or a binary, with strict clippy lints               |
| `go`     | A Go module, as a library or a binary, with golangci-lint                      |
| `docker` | A `Dockerfile` for the Python or TypeScript package, and a root `compose.yaml` |

Each stack also gets its own CI workflow in `.github/workflows/` and its own recipes in
`just/<stack>.just`. Every project gets `README.md`, `CHANGELOG.md`, `LICENSE`,
`SECURITY.md`, `.gitignore`, `.editorconfig`, a dependency bot, git hooks and VS Code
recommendations. A Python project also picks a [kind](python-kinds.md).

## TypeScript kinds

`ts_kind` picks what the TypeScript package is:

| Kind      | What it is                                                                                    |
| --------- | --------------------------------------------------------------------------------------------- |
| `library` | An ES module package compiled by `tsc` to `dist/`, with type declarations, publishable to npm |
| `app`     | The same Node package, built to `dist/` and never published                                   |
| `web-app` | A Vite single-page app for the browser, deployed to Cloudflare Pages                           |

A `web-app` asks one more question, `web_framework`: React, or Preact for a smaller
bundle. Preact runs React code through `preact/compat`, set up as aliases in
`vite.config.ts` and `tsconfig.json`. On top of the TS stack's checks, a web app gets:

- `index.html`, `src/main.tsx` and an `App` component with a unit test (Vitest with jsdom).
- Playwright specs in `tests/e2e/` that run against the production build: an axe
  accessibility check of every route in light and dark mode, and a check that the app
  runs under its own Content-Security-Policy. `just ts-e2e` runs them, and so does an
  `e2e` job in `ts.yml`.
- `public/_headers` with the response headers, and `wrangler.jsonc` with the build
  output directory, for Cloudflare Pages.
- A bundle budget in `scripts/checkBundleBudget.mjs`, which `just check` runs after the build.
- A pre-push git hook that runs the unit tests.

Cloudflare Pages deploys through its Git integration. Create a Pages project from the
repository, with build command `pnpm build` and output directory `dist`. Set the root
directory to `ts_dir` if the app is nested. No workflow deploys it, and no token is
stored in GitHub. A web app is static files, so the docker stack can't build it an image.

## One package or a monorepo

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

`copier update` needs a clean working tree, and updates to the latest tagged release of
this template. The same command lets you change your answers: add a stack or turn on a
publish option, and Copier writes the new files.

To move a package to another directory, run `copier update` with the new directory.
Then delete the old directory by hand. Copier removes files that left the template,
but not files that moved because an answer changed.

If `copier update` can't check out the `_commit` in `.copier-answers.yml`, the project
was rendered from a commit that was never pushed or tagged. Set `_commit` to the oldest
tag that offers every answer in the file, such as the first tag with your `kind`, and
commit that. Then run `copier update`. Expect conflicts where that tag differs from
the commit you started from.

## Publishing

Publishing is off by default. While an option is off, a guard stops an accidental
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

## Coverage on Codecov

`codecov` (off by default, Python and TS stacks) uploads each stack's test coverage to
[Codecov](https://codecov.io) and adds a `codecov.yml`. A pull request fails only when
total coverage drops by more than 2 points. Codecov comments only when a pull request adds
lines no test runs. The share of new lines covered is shown but never fails a pull request.
To turn it on:

1. Add the repository on codecov.io and copy its upload token.
2. Save it as the `CODECOV_TOKEN` repository secret (`gh secret set CODECOV_TOKEN`).
3. Run `copier update`, and answer yes to `codecov`.

## Dependency updates

`dependency_bot` picks who opens dependency-update PRs: Dependabot (the default, built
into GitHub) or Renovate. Both follow the same rules, described in
[tooling](tooling.md#dependencies). Renovate needs its GitHub App on the repository:
install it from [github.com/apps/renovate](https://github.com/apps/renovate), choosing
only this repository, then run `copier update` and answer `renovate`. That writes
`renovate.json5` and removes `.github/dependabot.yml`, so Renovate skips its onboarding PR.
