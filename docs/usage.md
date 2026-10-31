# Using the template

## The questions

A new project asks at most ten questions for a single stack, eleven for a web app: the
details only you know, then one switch for everything else. They come in this order:

| Question              | Asked when                         | What it changes                                                    |
| --------------------- | ---------------------------------- | ------------------------------------------------------------------ |
| `project_name`        | always                             | Repo and directory name; package, crate and image names come from it |
| `project_description` | always                             | One line for the README, package metadata and citation files       |
| `stacks`              | always                             | Which packages, CI workflows and `just` recipes the repo gets      |
| `kind`, `ts_kind`, `rust_kind`, `go_kind` | that stack is picked | What the package is: its layout, extra files and CI          |
| `web_framework`       | `ts_kind=web-app`                  | React, or Preact for a smaller bundle                              |
| `user_data`           | `ts_kind=web-app`                  | What the privacy page says, and whether there is a terms page ([legal pages](#legal-pages)) |
| `public`              | always                             | Yes adds the community files in `.github/`, and sets the license default |
| `github_user`, `author_name`, `author_email` | always      | Repo URLs and badges, the license, package metadata; a web app with `user_data=accounts` refuses `code@duinlab.nl` |
| `customise`           | always                             | Yes asks the advanced questions below; no takes their defaults     |
| `author_orcid`        | a `library` kind of any stack, or a `research` or `data-pipeline` Python kind, when there is a license | The citation files |
| `docker_stacks`       | the `docker` stack                 | Which packages get a Dockerfile and a compose service              |

The identity answers have no defaults. The README says how to save them once.

With `customise` left at no, the advanced questions take these defaults:

| Question                                        | Default                                          |
| ----------------------------------------------- | ------------------------------------------------ |
| `license`, `copyright_year`                     | MIT if `public`, otherwise none; this year       |
| `data_license`                                  | CC-BY-4.0 for `research`, CC0-1.0 for `data-pipeline`; none without a license ([Licenses](#licenses)) |
| `python_dir`, `ts_dir`, `rust_dir`, `go_dir`    | `.`: each package at the repo root               |
| `python_layout`                                 | `src`: the package in `src/<module>`, or `flat` ([adopting](#adopting-the-template-in-an-existing-python-package)) |
| `dependency_bot`                                | Dependabot                                       |
| `codecov`                                       | off                                              |
| `codspeed`                                      | off ([Benchmarks on CodSpeed](#benchmarks-on-codspeed)) |
| `profiling`                                     | off ([Profiling](#profiling))                    |
| `openssf_badge`                                 | none ([OpenSSF Best Practices badge](#openssf-best-practices-badge)) |
| `module_name`, `go_module`                      | made from the project name and GitHub user       |
| `python_version`, `python_min`, `node_version`, `rust_version`, `go_version` | the current releases; `python_min` two minors below `python_version` |
| `publish_to_pypi`, `publish_to_npm`, `publish_to_ghcr` | off ([Publishing](#publishing))           |
| `test_extras`                                   | none ([Test extras](#test-extras))               |
| `app_port`                                      | 8000                                             |
| `site_url`                                      | `https://<project>.pages.dev`, the Cloudflare Pages address |

On `copier update`, an advanced question you answered before keeps its answer even when
`customise` is no. To change one answer without the others, pass it:
`copier update --data codecov=true`, or have Copier ask just that one question:
`copier update --ask codecov`. Copier 9.19 or later is needed for this switch.

To skip the questions, `--data-file answers.yml` reads answers from a file, and
`--defaults` takes every default. Your details have no default, so give them with
`--data`, the data file or the settings file.

## Public repos

`public` is yes by default. Answer no for a private repo, and the template leaves out
`.github/SECURITY.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `pull_request_template.md`, the
issue forms in `ISSUE_TEMPLATE/` and the `dco.yml` sign-off check, which only outsiders need, and licenses nothing unless you pick a
license under `customise`. When the repo goes public, run
`copier update --data public=true`: that adds the files back. It does not change a
license you already answered, and without `customise` a private repo stored `none`
without asking, so pass `--data license=MIT` (or another) too.

A public repo also gets `.github/workflows/scorecard.yml`, which publishes its
[OpenSSF Scorecard](https://scorecard.dev) for the README badge. The workflow needs a public
repo, so a private one gets neither. Scorecard rates branch protection too: [Protecting main](#protecting-main)
sets it up.

### Making a repo public

Before you switch a private repo to public, check:

1. No secret in any commit. The git hook scans only what you stage, so scan the whole
   history once, every branch included:

   ```sh
   betterleaks git --log-opts=--all .
   ```

   A secret it finds is leaked even after you delete it: revoke it, then rewrite the
   history or start a fresh repo.
2. The name is free where you will publish:
   [PyPI](https://pypi.org/search/), [crates.io](https://crates.io) and
   [npm](https://www.npmjs.com). `npm view <name>` and `cargo search <name>` answer from
   the command line.
3. The issue list is clean: close or edit issues that hold private notes, names or
   links, since they go public with the code.
4. The README's status sentence says where the project stands. The README is yours after
   the first render, so edit the sentence by hand.

Then run `copier update --data public=true`, as above.

## Licenses

Pick the code license by what you want others to be able to do with the code:

- **MIT**, the default: anyone can reuse it, with credit.
- **Apache-2.0**: the same, plus an explicit patent grant. Take it when the code derives from
  Apache-2.0 code, or when a company or university contributor wants the patent terms written down.
- **BSD-3-Clause**: like MIT, but no one may use your name to promote their version. Take it
  when the ecosystem you build on uses it.
- **GPL-3.0-or-later**: changes and derived works must stay open under the GPL.
- **AGPL-3.0-or-later**: the GPL, plus anyone who runs a changed version as a web service must
  publish it. Take it for a hosted platform.

Research and data-pipeline projects also ask `data_license`, for the files you make and commit
under `data/`, because a software license fits data badly. CC-BY-4.0 asks for credit and is the
default for research data. CC0-1.0 asks for nothing and is the default for a pipeline, which
commits only its fetch log. A pipeline's outputs are not covered: they carry each source's terms
in `datapackage.json`.

Every project with a license follows the [REUSE spec](https://reuse.software). `REUSE.toml`
says who holds the copyright on each file and under which license, `LICENSES/` holds each
license text, and the `reuse` git hook fails while a file is not covered. `LICENSE` stays at the
root for GitHub and the package metadata. A file you copy in from elsewhere keeps its own license:
add `SPDX-FileCopyrightText` and `SPDX-License-Identifier` lines to its header, or an annotation
to `REUSE.toml`, and add the text with `reuse download <SPDX id>`.

## Protecting main

`just repo-settings` applies `.github/rulesets/main.json` to the default branch with `gh api`:
no deletion, no force-push, linear history, and PRs required, squash-merged only, with the
branch deleted once merged. A PR also
waits for the checks that run on every PR: `git hooks`, `pull request title`,
`dependency review` and, in a public repo, `DCO sign-off`. A skipped job counts as passed, so
a draft, a private repo's dependency review and, below `openssf_badge=silver`, a branch's DCO
check don't block. The stack
jobs aren't required: their workflows skip PRs that don't touch the stack, and a required
check that never reports blocks the PR. Add yours to the file by its job name.

A public repo also needs one approving review, given after the last push; a new push
dismisses an earlier approval. Scorecard's branch protection check scores at most 4 of 10
without an approval, and 8 with these settings. A repo admin can still merge without an
approval: the merge box offers to bypass the rules. In a public repo the required checks
sit in a second ruleset, `.github/rulesets/main-checks.json` (add yours there), so a bypass
of the review can't skip them by accident. Only an admin can bypass that one. With
`dependency_bot=renovate`, the Renovate app may skip the review too, so its minor and patch
updates merge themselves once their checks pass. It cannot skip the checks. GitHub accepts the
app in a ruleset only once it is installed on the repo, so install it before you run the
recipe. Dependabot PRs
always wait for you: merging them automatically would need a workflow with
`contents: write` and Actions allowed to approve pull requests. A private repo keeps one
ruleset with no approval and no bypass.

It applies `.github/rulesets/tags.json` to tags starting with `v`, because pushing one
publishes a release: only a repo admin can create, move or delete them. It also turns off
merge commits and rebase merges in the repo settings. In a public repo it turns on private
vulnerability reporting, where `SECURITY.md` sends reports. It also turns on Dependabot
alerts (`gh api -X PUT repos/OWNER/REPO/vulnerability-alerts`) so Renovate reads advisories
to open security PRs and the dependency graph is enabled. Run it once per repo, after the
first push, and again after you edit a file or a `copier update` changes one: it updates
the rulesets named `main`, `main-checks` and `tags` if they exist, and creates the rest.
Needs admin rights, and a paid GitHub plan on a private repo.

## The GitHub About box

`just repo-about` runs `gh repo edit` with your answers, so the About box matches the README:
the description from `project_description` (left alone when you gave none), the homepage from
`site_url` for a web app, and a topic per stack (`python`, `typescript`, `rust`, `go`,
`docker`). It only adds topics, so ones you set by hand stay. Rerun it after you change an
answer. Needs write access to the repo.

## Spelling and link checks

Two git hooks check the prose. `typos` finds misspelt words in code, comments and docs,
fixes the ones it is sure of and fails the commit so you see the fix. When it flags a word
that is right, such as a name or an abbreviation, list it in a `_typos.toml` at the root:

```toml
[default.extend-words]
ue = "ue"
```

`lychee` checks the links in Markdown and HTML files. The hook runs offline, so it checks
only relative links, such as `docs/usage.md` or `../README.md`, and fails on one that
points at a missing file. Web links die without a commit, so `.github/workflows/links.yml`
checks every link, with network access, on Thursdays and when you run it by hand. Its job
summary lists the dead links. A badge for a package you have not published yet, such as
PyPI's, fails it until the first release. In a private repo it skips links to the repo
itself, which only signed-in members can open.

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
`just/<stack>.just`. Every project gets `README.md`, `CHANGELOG.md`, `LICENSE`, `REUSE.toml`
and `LICENSES/` (unless `license=none`), `.gitignore`, `.editorconfig`, a dependency bot, git hooks and VS
Code recommendations. Unless `public=false`, it also gets the community files in `.github/`:
`SECURITY.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md` and a pull request template. A Python project also picks a [kind](python-kinds.md).

A Rust or Go `binary` and a Python `data-pipeline` are command-line programs, so they also
get `docs/accessibility.md`: four claims about how the program prints (colour is never the
only signal, `NO_COLOR` and `--color never` turn colour off, plain output when not on a
terminal, errors as `file:line:col` on standard error) and your email for problems. The
template writes the claims but does not test them: check each one holds for your program
before you publish, and reword or delete the ones that don't. A web app at the repo root
keeps its own accessibility statement at that path instead.

Every project also gets `docs/decisions/`, for decision records: one numbered file per
decision, such as `0001-one-parser.md`, saying what was chosen, why, and what it costs.
Copy `0000-template.md` for a new record and list it in the folder's `README.md`.

Every project also gets a short `AGENTS.md` for coding agents: the `just check` command, the
test recipe of each stack you picked, and where the docs are. It is filled from your answers
and the rendered `justfile`, so `copier update` rewrites it when your stacks change. Put your
own notes for agents in another file, or `copier update` overwrites them.

## TypeScript kinds

`ts_kind` picks what the TypeScript package is:

| Kind      | What it is                                                                                    |
| --------- | --------------------------------------------------------------------------------------------- |
| `library` | An ES module package compiled by `tsc` to `dist/`, with type declarations, publishable to npm |
| `app`     | The same Node package, built to `dist/` and never published                                   |
| `web-app` | A Vite single-page app for the browser, deployed to Cloudflare Pages                           |

A `web-app` asks two more questions: `web_framework`, React or Preact for a smaller
bundle, and `user_data` for its [legal pages](#legal-pages). Preact runs React code through `preact/compat`, set up as aliases in
`vite.config.ts` and `tsconfig.json`. On top of the TS stack's checks, a web app gets:

- `index.html`, `src/main.tsx` and an `App` component with a unit test (Vitest with jsdom).
- Playwright specs in `tests/e2e/` that run against the production build: an axe
  accessibility check of every route in light and dark mode, and a check that the app
  runs under its own Content-Security-Policy. `just ts-e2e` runs them, and so does an
  `e2e` job in `ts.yml`.
- An accessibility statement, a privacy statement and, for accounts or uploads, terms of
  use, linked from every page's footer ([legal pages](#legal-pages)).
- `public/_headers` with the response headers, and `wrangler.jsonc` with the build
  output directory, for Cloudflare Pages.
- A bundle budget in `scripts/checkBundleBudget.mjs`, which `just check` runs after the build.
- A pre-push git hook that runs the unit tests.

Cloudflare Pages deploys through its Git integration. Create a Pages project from the
repository, with build command `pnpm build` and output directory `dist`. Set the root
directory to `ts_dir` if the app is nested. No workflow deploys it, and no token is
stored in GitHub. A web app is static files, so the docker stack can't build it an image.

The starter files are the project's once written, and `copier update` leaves them
alone: `src/App.tsx`, `src/App.test.tsx`, `src/main.tsx`, `src/app.css`, `index.html`,
`tests/e2e/routes.ts` and the pages in `docs/`. Every other file keeps receiving template
changes.

### Legal pages

Each page is one Markdown file in the app's `docs/` folder. GitHub shows the file as it
is, and the build turns it into HTML (`marked`, in `vite.config.ts`), so the app ships no
Markdown code. Write plain Markdown with absolute links, since the same file is read in
two places. The build leaves out HTML comments: the note at the top of each page is for
you, and points to the tips below. `src/App.tsx` serves the pages, and every page's footer
links them:

| Page                     | Path             | Rendered when              |
| ------------------------ | ---------------- | -------------------------- |
| `docs/accessibility.md`  | `/accessibility` | always                     |
| `docs/privacy.md`        | `/privacy`       | always; its cookies section is part of it |
| `docs/terms.md`          | `/terms`         | `user_data=accounts`       |

The `user_data` answer, "What does the app keep about its users?", has no default:
`nothing`, `browser` (local storage only) or `accounts` (accounts or uploads on a
server). It decides what the privacy statement says, and whether there are terms. The
answers fill in the name, `site_url`, your email and today's date. The rest is marked
TODO, so a new app's e2e tests fail until you have filled them in.

Three specs in `tests/e2e/` keep the pages true. `legal-pages.spec.ts` checks that each
page renders with an email contact and no TODO, and that every route's footer links all
of them. `accessibility-statement.spec.ts` checks the statement's sections, its status
and its review date. `privacy.spec.ts` checks that a first visit to any route sets no
cookies, stores nothing and loads only the app's own files. The
[CI baseline](ci-baseline.md) has the details.

[`docs/web-legal.md`](https://github.com/simonvanlierde/project-templates/blob/main/docs/web-legal.md) in the template repository has tips for filling the pages in: who is
responsible for the data, what an organisation's privacy officer checks, and what the
Dutch and EU cookie rules say about local storage and analytics. It is not legal advice.

### Adopting the template in an existing web app

1. On a clean branch of the existing repository, render over it:
   `copier copy --vcs-ref=<tag> --overwrite gh:simonvanlierde/project-templates .`,
   answering `ts_kind=web-app`, the framework the app uses, and `user_data` for its
   [legal pages](#legal-pages).
2. A first copy has nothing to merge with, so it overwrites the files it writes, except
   the starter files and the README: an app's own `src/App.tsx`, `src/main.tsx`,
   `src/app.css`, `index.html`, `tests/e2e/routes.ts` and `README.md` stay as they are.
   The starter files the app doesn't have yet land next to its own components and
   styles. Review `git diff`:
   - Delete the starter files the app doesn't use.
   - Copy the footer and the routes for the legal pages from a fresh render's
     `src/App.tsx` into the app's own, and add `/accessibility` and `/privacy` (and
     `/terms`) to `tests/e2e/routes.ts`.
   - Restore `vite.config.ts` and `vitest.config.ts` if the app added plugins, test
     setup or coverage thresholds. Copier replaces both. Keep the template's
     `markdown()` plugin in `vite.config.ts`: the legal pages are `.md` imports, and
     the build fails without it.
   - Restore the `name` in `package.json` and `wrangler.jsonc`, which become the
     project slug.
   - Restore `public/_headers` if the app needs a looser policy.
   - Fill in the TODOs in the pages in `docs/`. The e2e tests fail until none is left.
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

## Adopting the template in an existing Python package

1. On a clean branch, render over the repo with
   `copier copy --vcs-ref=<tag> --overwrite gh:simonvanlierde/project-templates .`.
   Answer yes to `customise`, give the package's `module_name`, and pick
   `python_layout=flat` if the package sits at the root rather than under `src/`. Flat
   adds no `src/` stub and no `tests/test_add.py`. An existing `README.md`,
   `CHANGELOG.md` and `CITATION.cff` stay as they are, and `copier update` never touches
   them later either, so template changes to them reach you only by hand.
2. Copier replaces `pyproject.toml`. Restore your dependencies, authors and version from
   `git diff`, then run `just py-sync`. `--overwrite` also replaces `LICENSE`,
   `.gitignore`, `.pre-commit-config.yaml`, the `justfile` and the community files in
   `.github/`, so review `git diff` for those too. GitHub shows `.github/CONTRIBUTING.md`
   before a root `CONTRIBUTING.md`: keep one of each such pair and delete the other.
3. Run `uv run ruff format` and commit that on its own. `select = ["ALL"]` usually finds
   hundreds of issues in code written without it. To start from a baseline, add the codes
   `uv run ruff check --statistics --output-format json | jq -r '.[].code'` prints to
   `ignore` under a `# NOTE: baseline at adoption` comment, and delete them as you fix
   them. Do the same for ty: set each rule that
   `uv run ty check --output-format concise` names to `"warn"` under `[tool.ty.rules]`.
   Warnings are reported but don't fail `ty check`.
4. If `just check` fails on `uv audit` because the fix is less than a week old, exempt
   that package from `exclude-newer` (see [tooling](tooling.md#dependencies)).
5. The hooks leave `data/` alone. Delete the workflows the template replaces, then run
   `just check` and `just hooks`, and commit, `.copier-answers.yml` included.
6. Before the first tag, give `CHANGELOG.md` Keep a Changelog `## [X.Y.Z]` headings.
   `release.yml` and the publish workflows read the section for the tag and fail without it.

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

`README.md`, `CHANGELOG.md`, the citation files (`CITATION.cff`,
`codemeta.json`), `docs/decisions/README.md`, the silver-badge documents, a `web-app`'s starter files, a published
TypeScript library's `<package>.api.md` and Go's `go.mod` are written once
and then belong to your project: an update never touches them, so your release tool or
your own edits own them. A template release that changes them says so in the template's
changelog, for you to copy over by hand. `go mod tidy` rewrites `go.mod` and Dependabot
bumps its requirements, so a new `go_version` answer doesn't reach it: run `go mod edit
-go=<version>` yourself.

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
are up to date. The template tracks its Copier version with Renovate. Template updates refresh
the workflow's `COPIER_VERSION`; Dependabot cannot bump that pin.

Give the workflow a token of its own. GitHub refuses a push with `GITHUB_TOKEN` that
changes a file in `.github/workflows/`, which most template releases do. Create a
fine-grained token for this repository with read and write access to Contents, Pull
requests and Workflows, and store it as the `COPIER_UPDATE_TOKEN` repository secret (`gh secret set COPIER_UPDATE_TOKEN`). The workflow then pushes and
opens the PR with it, and the PR's own CI starts.

Without the secret, the workflow falls back to `GITHUB_TOKEN`. An update that touches a
workflow then opens an issue asking you to run `copier update` locally, and closes an
older update PR that is still open. Any other update still opens its PR, whose CI starts
only when you close and reopen it, and the required checks wait until then. The fallback also
needs the repository setting "Allow GitHub Actions to create and approve pull requests".
Turn it on with
`gh api -X PUT repos/OWNER/REPO/actions/permissions/workflow -F can_approve_pull_request_reviews=true -f default_workflow_permissions=read`.

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

Once a week, `.github/workflows/property.yml` runs them at length, one job per library
stack, never on a pull request. Each job runs a recipe you can run by hand:
`just py-property` (Hypothesis's `long` profile from `tests/conftest.py`, 10,000
examples a property), `just ts-property` (fast-check, 10,000 runs), `just rs-property`
(proptest, 10,000 cases) or `just go-property` (fuzzes `FuzzAdd` for 10 minutes; pass
`-fuzztime=30s` for less). The 10,000 applies to properties that do not set their own
count: a test's own `@settings`, `numRuns` or `ProptestConfig` wins. A failing input fails the job; the Go job uploads it from
`testdata/fuzz/`.

Mutation testing plants small bugs in your code, such as `+` turned into `-`, and
reports each one the tests don't catch. A run takes minutes to hours, and some
surviving mutants change nothing a test could see. So CI runs it once a week, from
`.github/workflows/mutation.yml`, never on a pull request. It has one job per library
stack and runs the same `just <stack>-mutation` recipe you run by hand. Start it from
the Actions tab with "Run workflow" after you change the tests. The Rust job fails when
a mutant survives; list a harmless one in `.cargo/mutants.toml` (`exclude_re`). The other
jobs print the survivors and pass.

OpenSSF Scorecard's Fuzzing check counts fast-check and Go's native fuzzing, not
Hypothesis or proptest. Weekly Go runs cache the generated fuzz corpus so each run
continues from earlier coverage inputs. A failure still uploads its reproducer as an artifact.
To add the extras to an existing library, run
`copier update --data 'test_extras=[property]'`.

## Publishing

To release, add a `## [X.Y.Z]` section to `CHANGELOG.md`, then push the tag `vX.Y.Z`.
With `publish_to_pypi` or `publish_to_npm`, set the version in `pyproject.toml`, `package.json`
or both to X.Y.Z first: the build takes the version from there, and refuses a tag that differs.
With `publish_to_pypi`, `python-release.yml` publishes to PyPI first. It then creates a
draft GitHub release from that section, attaches the distributions and their Sigstore
provenance bundle, and publishes the release. Approve the `pypi` environment when prompted.
Do not create the GitHub release by hand. Other projects use `release.yml` for the release.

If publishing fails, check the registry before retrying. If the version is absent,
re-run the failed jobs on the same tag. Never move or delete a published release's tag:
immutable releases protect it, and a registry will not accept changed files for that version.

If PyPI has the version but the GitHub release job failed, re-run only the `release` job.
Delete any leftover draft first with `gh release delete vX.Y.Z` (without `--cleanup-tag`).
If the GitHub release is already published and its files are wrong or missing, fix the
source and release a new patch version. A retry cannot change an immutable release.
For npm failures after the GitHub release appears, retry the failed publishing job if the
version is absent from npm; otherwise check the uploaded package before making a new version.

Publishing is off by default. While an option is off, a guard stops an accidental
release:

| Option            | While off                                                   | When on                                                  |
| ----------------- | ----------------------------------------------------------- | -------------------------------------------------------- |
| `publish_to_pypi` | PyPI rejects uploads (`Private :: Do Not Upload` classifier) | `python-release.yml` publishes to PyPI                   |
| `publish_to_npm`  | pnpm refuses to publish (`"private": true`)                 | `ts-release.yml` publishes to npm                        |
| `publish_to_ghcr` | CI builds the image and tests `/health`, but pushes nothing | CI also pushes the image to the GitHub Container Registry |

Both publishing options add an API-break check to CI. The npm check also runs in
`just check` (see the [CI baseline](ci-baseline.md)). With `publish_to_npm`, run
`just ts-api` once after the update and commit `<package>.api.md`: the template's copy
describes the sample `add` function.

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
there is no secret. Replace the starter benchmarks with calls into your own code. In a
library they call the sample `add`, so one without it fails to collect or compile them. In an
existing project, run `copier update --data codspeed=true`. Then two steps no file can do:

1. Import the repository on [codspeed.io](https://codspeed.io). Until you do, uploads fail
   with 401 "Repository not found".
2. In the repository's settings on codspeed.io, set Pull Request comments to "On Change".
   `codspeed.yml` has no option for it.

## Profiling

`profiling` (off by default, Python and Rust stacks) adds recipes for finding where time goes.
CodSpeed tells you that a change got slower; these tell you why.

- Python: `just py-profile <script or -m module> <args>` runs pyinstrument through
  `uv run --with`, so it adds no dependency, and prints the call tree.
- Rust: a `[profile.profiling]` in `Cargo.toml` (release code plus line tables), built with
  frame pointers by `just rs-profiling-build`. `just rs-profile <command>` records it with
  [samply](https://github.com/mstange/samply), and `just rs-counters <command>` runs
  `perf stat` five times for instructions, cycles and branch misses. Both need perf events
  (`perf_event_paranoid` 1 or lower), which many VMs and CI runners block. Install samply
  yourself; perf comes with the kernel tools.

In an existing project, run `copier update --data profiling=true`.

## OpenSSF Best Practices badge

`openssf_badge` (none by default, asked in a public repo with a license) prepares the
files used by the [OpenSSF Best Practices badge](https://www.bestpractices.dev).
The public community files, license, changelog and tests provide other starting points
for its questionnaire. A private repo or one with `license=none` gets no badge documents.

- `passing` adds a Tests and code style section to `.github/CONTRIBUTING.md`: changes
  come with tests, and the linters each stack runs are its coding standards.
- `silver` adds that, plus three skeletons to fill in: `GOVERNANCE.md` (roles, who holds
  which keys, what happens if a maintainer is gone), `docs/roadmap.md` (the next year,
  and what is out of scope) and `docs/assurance-case.md` (threat model, trust boundaries,
  secure design, weaknesses countered). They belong to your project once written.
  Silver's DCO criterion covers every developer, so the `dco` check also runs on your own
  branches, and a commit-msg hook refuses a commit without a `Signed-off-by:` line: use
  `git commit -s`. Commits Dependabot or Renovate write in their own pull requests are
  exempt.

The template can't earn the badge for you. Register the project on bestpractices.dev,
answer its questionnaire, and add the badge it gives you to the README. Silver also requires
signed releases intended for widespread use and recommends a bus factor of at least two.

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
