# Using the template

## The questions

A new project asks at most ten questions for a single stack: the details only you know,
then one switch for everything else. They come in this order:

| Question              | Asked when                         | What it changes                                                    |
| --------------------- | ---------------------------------- | ------------------------------------------------------------------ |
| `project_name`        | always                             | Repo and directory name; package, crate and image names come from it |
| `project_description` | always                             | One line for the README, package metadata and citation files       |
| `stacks`              | always                             | Which packages, CI workflows and `just` recipes the repo gets      |
| `kind`, `ts_kind`, `rust_kind`, `go_kind` | that stack is picked | What the package is: its layout, extra files and CI          |
| `web_framework`       | `ts_kind=web-app`                  | React, or Preact for a smaller bundle                              |
| `public`              | always                             | Yes adds the community files in `.github/`, and sets the license default |
| `github_user`, `author_name`, `author_email` | always      | Repo URLs and badges, the license, package metadata                |
| `author_orcid`        | a `library`, `research` or `data-pipeline` Python kind | The citation files                    |
| `customise`           | always                             | Yes asks the advanced questions below; no takes their defaults     |
| `docker_stacks`       | the `docker` stack                 | Which packages get a Dockerfile and a compose service              |

The identity answers have no defaults. The README says how to save them once.

With `customise` left at no, the advanced questions take these defaults:

| Question                                        | Default                                          |
| ----------------------------------------------- | ------------------------------------------------ |
| `license`, `copyright_year`                     | MIT if `public`, otherwise none; this year       |
| `python_dir`, `ts_dir`, `rust_dir`, `go_dir`    | `.`: each package at the repo root               |
| `dependency_bot`                                | Dependabot                                       |
| `codecov`                                       | off                                              |
| `codspeed`                                      | off ([Benchmarks on CodSpeed](#benchmarks-on-codspeed)) |
| `module_name`, `go_module`                      | made from the project name and GitHub user       |
| `python_version`, `python_min`, `node_version`, `rust_version`, `go_version` | the current releases; `python_min` two minors below `python_version` |
| `publish_to_pypi`, `publish_to_npm`, `publish_to_ghcr` | off ([Publishing](#publishing))           |
| `test_extras`                                   | none ([Test extras](#test-extras))               |
| `app_port`                                      | 8000                                             |

On `copier update`, an advanced question you answered before keeps its answer even when
`customise` is no. To change one answer without the others, pass it:
`copier update --data codecov=true`, or have Copier ask just that one question:
`copier update --ask codecov`. Copier 9.19 or later is needed for this switch.

To skip the questions, `--data-file answers.yml` reads answers from a file, and
`--defaults` takes every default. Your details have no default, so give them with
`--data`, the data file or the settings file.

## Public repos

`public` is yes by default. Answer no for a private repo, and the template leaves out
`.github/SECURITY.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md` and `pull_request_template.md`,
which only outsiders need, and licenses nothing unless you pick a
license under `customise`. When the repo goes public, run
`copier update --data public=true`: that adds the files back. It does not change a
license you already answered.

A public repo also gets `.github/workflows/scorecard.yml`, which publishes its
[OpenSSF Scorecard](https://scorecard.dev) for the README badge. The workflow needs a public
repo, so a private one gets neither. Scorecard rates branch protection too, so set that up
for a higher score.

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
`just/<stack>.just`. Every project gets `README.md`, `CHANGELOG.md`, `LICENSE`
(unless `license=none`), `SECURITY.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md` and a pull request template (unless `public=false`), `.gitignore`, `.editorconfig`, a dependency bot, git hooks and VS Code
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

The starter files are the project's once written, and `copier update` leaves them
alone: `src/App.tsx`, `src/App.test.tsx`, `src/main.tsx`, `src/app.css`, `index.html`
and `tests/e2e/routes.ts`. Every other file keeps receiving template changes.

### Adopting the template in an existing web app

1. On a clean branch of the existing repository, render over it:
   `copier copy --vcs-ref=<tag> --overwrite gh:simonvanlierde/project-templates .`,
   answering `ts_kind=web-app` and the framework the app uses.
2. A first copy has nothing to merge with, so it overwrites every file it writes.
   It also adds the starter files the app may not have: `src/App.tsx`,
   `src/App.test.tsx` and `src/app.css` land next to the app's own components and
   styles. Review `git diff`:
   - Delete the starter files the app doesn't use, and restore its own versions of
     the rest.
   - Restore `vite.config.ts` and `vitest.config.ts` if the app added plugins, test
     setup or coverage thresholds. Copier replaces both.
   - Restore the `name` in `package.json` and `wrangler.jsonc`, which become the
     project slug, and the README.
   - Restore `public/_headers` if the app needs a looser policy.
3. Run `pnpm install`. The template's `pnpm-workspace.yaml` only accepts releases at
   least a week old, so it rejects a lockfile that holds a newer one. List each
   package it names under `minimumReleaseAgeExclude` in that file, with a date a week
   from now, and delete the list on that date (see [tooling](tooling.md#dependencies)):

   ```yaml
   # Delete after 2026-10-28: resolved before the one-week wait applied.
   minimumReleaseAgeExclude:
     - vite@8.3.5
   ```

4. Move any inline script in `index.html` to a file under `public/`, so the app runs
   under `script-src 'self'`. Then run `just check` and `just ts-e2e`.
5. Delete the workflows the template replaces, and point branch protection at the
   new job names. Commit, including `.copier-answers.yml`.

Later `copier update` runs merge the template's changes since the recorded commit,
so the edits from step 2 stay.

## One package or a monorepo

By default, each package sits at the repository root. To put several packages in one
repository, answer yes to `customise` and give each a directory, such as `python_dir: apps/api` and
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

`CHANGELOG.md`, the citation files (`CITATION.cff`, `.zenodo.json`, `codemeta.json`),
a `web-app`'s starter files and Go's `go.mod` are written once and then belong to your project: an
update never touches them, so your release tool or your own edits own them. A template release that
changes them says so in the template's changelog, for you to copy over by hand. `go mod tidy`
rewrites `go.mod` and Dependabot bumps its requirements, so a new `go_version` answer
doesn't reach it: run `go mod edit -go=<version>` yourself.

To move a package to another directory, run `copier update` with the new directory.
Then delete the old directory by hand. Copier removes files that left the template,
but not files that moved because an answer changed.

After any `copier update`, refresh the lockfiles for your stacks and commit them with
the update: `uv lock`, `pnpm install`, `just go-sync`. A template change can add or bump a
dependency, and CI installs with `--locked` and `--frozen-lockfile`, so a stale lockfile
fails the build.

Template releases are immutable, so a bad one is fixed by a new patch release. Until it
arrives, close the update PR, or run `git revert` on the update commit.

### Hearing about new releases

With `dependency_bot: renovate`, Renovate's
[copier manager](https://docs.renovatebot.com/modules/manager/copier/) watches
`.copier-answers.yml`. When this template tags a release, it opens a PR that runs
`copier update --skip-answered --defaults` to that tag. Read the PR before merging:
Renovate commits merge conflicts with their markers in the file and lists the conflicted
files in the PR body. The template runs no Copier tasks, so Renovate needs no `--trust`.

Dependabot can't update a Copier template. With it, the `copier-update` workflow does
the same every Monday, and on demand from the Actions tab. When the newest template tag
differs from `_commit`, it runs `copier update --defaults` and opens one PR on the branch
`chore/copier-update`, with conflicted files listed in the body. It does nothing when you
are up to date. It pins Copier in its `COPIER_VERSION`, which Dependabot does not bump.

The workflow needs the repository setting "Allow GitHub Actions to create and approve
pull requests". Turn it on with
`gh api -X PUT repos/OWNER/REPO/actions/permissions/workflow -F can_approve_pull_request_reviews=true -f default_workflow_permissions=read`.
A PR pushed with `GITHUB_TOKEN` does not start other workflows, so its CI stays
silent. Close and reopen the PR to start it, or change the workflow to push with a
fine-grained token or GitHub App token.

If `copier update` can't check out the `_commit` in `.copier-answers.yml`, the project
was rendered from a commit that was never pushed or tagged. Set `_commit` to the oldest
tag that offers every answer in the file, such as the first tag with your `kind`, and
commit that. Then run `copier update`. Expect conflicts where that tag differs from
the commit you started from.

## Test extras

A library kind (Python, TypeScript, Rust or Go) also asks for `test_extras` under
`customise`, empty by default. Pick either or both:

| Choice     | Python                  | TypeScript               | Rust                      | Go                          |
| ---------- | ----------------------- | ------------------------ | ------------------------- | --------------------------- |
| `property` | Hypothesis              | fast-check               | proptest                  | a native `FuzzAdd`          |
| `mutation` | `just py-mutation` (mutmut) | `just ts-mutation` (Stryker) | `just rs-mutation` (cargo-mutants) | `just go-mutation` (gremlins) |

A property test checks a rule, such as "order does not matter", against many generated
inputs, and shrinks any input that fails to the simplest one. The examples test the
sample `add` function and run with the other tests. Go's `FuzzAdd` runs on its seeds in
`go test`; `go test -fuzz=FuzzAdd` keeps generating inputs until you stop it.

Mutation testing plants small bugs in your code, such as `+` turned into `-`, and
reports each one the tests don't catch. A run takes minutes to hours, and some
surviving mutants change nothing a test could see, so it is a recipe to run before a
release or after writing tests, never a CI step.

OpenSSF Scorecard's Fuzzing check counts fast-check and Go's native fuzzing, not
Hypothesis or proptest. To add the extras to an existing library, run
`copier update --data 'test_extras=[property]'`.

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
3. In the repository's Settings > Environments, create the environment the workflow
   names (`pypi`, `npm` or `ghcr`). Limit it to tags matching `v*` (`ghcr` also to
   `main`), and add yourself as a required reviewer. Without this, GitHub creates the
   environment unprotected on the first run, and anyone who can push a branch can
   publish from it.
4. Run `copier update --data publish_to_pypi=true` (or the npm or ghcr option).

## Coverage on Codecov

`codecov` (off by default, Python and TS stacks) uploads each stack's test coverage to
[Codecov](https://codecov.io) and adds a `codecov.yml`. A pull request fails only when
total coverage drops by more than 2 points, and that check links to the report: Codecov
posts no comment. The share of new lines covered is shown but never fails a pull request.
To turn it on:

1. Add the repository on codecov.io and copy its upload token.
2. Save it as the `CODECOV_TOKEN` repository secret (`gh secret set CODECOV_TOKEN`).
3. Run `copier update --data codecov=true`.

## Benchmarks on CodSpeed

`codspeed` (off by default, Python and Rust stacks) adds `.github/workflows/benchmarks.yml`
and a starter benchmark per stack: a `pytest-codspeed` test in `tests/test_benchmarks.py`,
and a divan bench through `codspeed-divan-compat` in `benches/codspeed.rs`. CodSpeed
measures them in simulation mode on every pull request and every push to main, so each
pull request has a base to compare with. The workflow signs in with OpenID Connect, so
there is no secret. Replace the starter benchmarks with calls into your own code. Two steps
no file can do:

1. Import the repository on [codspeed.io](https://codspeed.io). Until you do, uploads fail
   with 401 "Repository not found".
2. In the repository's settings on codspeed.io, set Pull Request comments to "On Change".
   `codspeed.yml` has no option for it.
3. Run `copier update --data codspeed=true`.

## Dependency updates

`dependency_bot` picks who opens dependency-update PRs: Dependabot (the default, built
into GitHub) or Renovate. Both follow the rules in
[tooling](tooling.md#dependencies), which also names the one difference. Renovate needs its GitHub App on the repository:
install it from [github.com/apps/renovate](https://github.com/apps/renovate), choosing
only this repository, then run `copier update --data dependency_bot=renovate`. That writes
`renovate.json5` and removes `.github/dependabot.yml`, so Renovate skips its onboarding PR.
Then turn Dependabot security updates off, or each security fix arrives as two PRs:
`gh api -X DELETE repos/OWNER/REPO/automated-security-fixes`. Leave Dependabot alerts on.
Renovate reads them to open its own security PRs.
