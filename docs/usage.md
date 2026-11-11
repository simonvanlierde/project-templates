# Using the template

The [README](https://github.com/simonvanlierde/project-templates/blob/main/README.md#quick-start) shows how to start a project. This page is the
reference for what comes after, in the order you are likely to need it:

- **Render:** [the questions](#the-questions) and [presets](#presets), [stacks](#choosing-your-stacks) and
  [kinds](python-kinds.md), [Compose-only repos](#compose-only-repos),
  [monorepos](#one-package-or-a-monorepo), [licenses](#licenses) and
  [public repos](#public-repos).
- **After the first push:** [protect `main`](#protecting-main) and
  [fill in the About box](#the-github-about-box).
- **Later:** [pull in template updates](#keeping-your-project-up-to-date).
- **Optional features**, which you can turn on at any time with `copier update --data`:
  [publishing](#publishing), [tests on Windows](#tests-on-windows), [Codecov](#coverage-on-codecov),
  [CodSpeed](#benchmarks-on-codspeed), [profiling](#profiling),
  [test extras](#test-extras), a [static site](#static-site),
  [Workers hosting](#workers-hosting), a [documentation site](#documentation-site), the
  [practice level](#levels), the [OpenSSF badge](#openssf-best-practices-badge) and the
  [dependency bot](#dependency-updates).
- **Existing code:** [adopt the template](#adopting-the-template-in-an-existing-repo) in a
  repo you already have.

## The questions

A new project asks at most ten questions for a single stack (eleven for a web app):

| Question | Prompted when | Effect |
| --- | --- | --- |
| `project_name` | Always | Repository, directory, package, crate, and image names |
| `project_description` | Always | One-line summary for README, package metadata, and citation files |
| `stacks` | Always | Selected packages, CI workflows, and `just` recipes |
| `kind`, `ts_kind`, `rust_kind`, `go_kind` | Respective stack selected | Package architecture, directory layout, and CI configuration |
| `web_framework` | `ts_kind=web-app` | React, or Preact for reduced bundle size |
| `user_data` | `ts_kind=web-app` | Configures privacy statement content and terms page ([legal pages](#legal-pages)) |
| `public` | Always | Adds `.github/` community files and sets default license |
| `github_user`, `author_name`, `author_email` | Always | Repository URLs, badges, licenses, and package metadata |
| `customise` | Always | `yes` prompts for advanced settings; `no` accepts defaults |
| `author_orcid` | Licensed `library`, or Python `research`/`data-pipeline` | Citation metadata |
| `docker_image` | `docker` and `python` stacks selected | Builds the Python package into an image with a Dockerfile and Compose service; no for a [Compose-only repo](#compose-only-repos) |

Identity answers have no defaults.

When `customise` is `no`, advanced questions take these defaults:

| Question | Default |
| --- | --- |
| `license`, `copyright_year` | MIT if `public`, otherwise none; current calendar year |
| `data_license` | CC-BY-4.0 for `research`, CC0-1.0 for `data-pipeline`; none without a license ([Licenses](#licenses)) |
| `python_dir`, `ts_dir`, `rust_dir`, `go_dir` | `.` (package located at repository root) |
| `python_layout` | `src` (`src/<module>`); choose `flat` when [adopting in existing packages](#adopting-the-template-in-an-existing-python-package) |
| `dependency_bot` | Dependabot |
| `site` | None ([Static site](#static-site)) |
| `site_host` | GitHub Pages; `cloudflare` deploys the site to a Worker ([Static site](#static-site)) |
| `worker` | Disabled; a Worker script for `/api/*` in a web app or a site on Cloudflare ([Workers hosting](#workers-hosting)) |
| `extras` | `cold_install` at `standard` and `community`; otherwise none ([Optional features](#optional-features)) |
| `level` | `standard` for a public repo with a license ([Levels](#levels)) |
| `decision_records` | On for `web-service`, `data-pipeline`, `web-app`, Compose-only and `community`-level projects ([Decision records](#decision-records)) |
| `module_name`, `go_module` | Derived from project name and GitHub user |
| `python_version`, `python_min`, `node_version`, `go_version` | Current stable releases; `python_min` defaults two minor versions below |
| `rust_version` | The crate's minimum supported Rust version (`rust-version` in `Cargo.toml`), the current stable minor by default |
| `python_api` | Enabled ([API-break check](#api-break-check)) |
| `publish_to_pypi`, `publish_to_npm`, `publish_to_ghcr` | Disabled ([Publishing](#publishing)) |
| `app_port` | 8000 |
| `site_url` | `https://<project>.<github_user>.workers.dev`, or `<project>-site` for a site on Cloudflare (the Worker's workers.dev address, if the account's subdomain is the GitHub user). Another host is a custom domain ([Workers hosting](#workers-hosting)) |

During `copier update`, previously configured answers are preserved even when `customise` is `no`. Change an individual setting with `copier update --data <key>=<value>` or prompt for a single setting with `copier update --ask <key>`.

### Optional features

`extras` is one multiselect under `customise`. Select every feature the project needs:
`codecov`, `codspeed`, `profiling`, `cold_install`, `python_windows`, `docs_site`,
`property` and `mutation`. Stack-specific features require their stack; property and
mutation tests require a library kind. Publishing and hosting keep their own questions.

New public, licensed projects at `standard` or `community` start with `cold_install`.
An explicit list replaces the whole selection, including that default. To change the
selection interactively, run `copier update --ask extras`. In scripts, list every feature
to keep, for example:

```sh
copier update --data 'extras=[cold_install,codecov,property]'
```

An update from v0.14.0 seeds this list from the old yes/no answers and `test_extras`.
It preserves disabled features too, including `cold_install: false` at `standard`.
The next answers file stores only `extras`. Replace old `--data codecov=true` and
`--data 'test_extras=[...]'` arguments with the full `extras` selection.

To bypass prompts during initial generation, supply values via `--data-file answers.yml` or pass flags with `--data`.

### Presets

`presets/` holds the answers for repo kinds that come up again and again. A preset fills
the project-kind questions; Copier still asks the identity ones.

| Preset | Repo |
| --- | --- |
| `rust-cli.yml` | A Rust command-line tool |
| `uv-research.yml` | A Python research package with notebooks, data and citation files |
| `compose-deploy.yml` | A [Compose-only](#compose-only-repos) deploy repo with decision records |

Pass one with `--data-file`, which reads a local path:

```sh
curl -fsSLo /tmp/preset.yml https://raw.githubusercontent.com/simonvanlierde/project-templates/main/presets/rust-cli.yml
copier copy --data-file /tmp/preset.yml gh:simonvanlierde/project-templates my-tool
```

`--data` flags after it override single answers. A preset is a starting point, not a
second template: `copier update` reads the answers file, not the preset.

### Layering another template

Copier applies several templates to one repo when each keeps its own answers file. An
organisation's own files (telemetry, contacts, org defaults) belong in a separate template
applied after this one, with `_answers_file: .copier-answers.<name>.yml` in its `copier.yml`.
Update each layer on its own: `copier update --answers-file .copier-answers.<name>.yml`.
This template stays free of any one organisation's setup.

## Choosing your stacks

Select any combination of stacks:

| Stack | Features added |
| --- | --- |
| `python` | Python package with `pyproject.toml`, `src/`, `tests/`, and uv tooling |
| `ts` | TypeScript package or Vite web app ([kinds](#typescript-kinds)) |
| `rust` | Rust crate (library or binary) with strict clippy rules |
| `go` | Go module (library or binary) with golangci-lint |
| `docker` | Dockerfile for the Python package and root `compose.yaml`; without `python`, a [Compose-only repo](#compose-only-repos) |

Each stack includes a CI workflow in `.github/workflows/` and recipes in `just/<stack>.just`. All projects receive `README.md`, `CHANGELOG.md`, `.gitignore`, `.editorconfig`, dependency bot configuration, git hooks, and `AGENTS.md`. Projects with a license also get `LICENSE` and `REUSE.toml`. Python projects select a [kind](python-kinds.md).

CLI binaries (Rust, Go, or Python `data-pipeline`) include `docs/accessibility.md`, documenting terminal output standards (`NO_COLOR` support, plain output redirection, error formats). Review and edit these claims to reflect your application.

With `decision_records` on, a project keeps its architectural choices in `docs/decisions/` ([Decision records](#decision-records)).

## TypeScript kinds

`ts_kind` configures the package target:

| Kind | Target |
| --- | --- |
| `library` | ES module compiled by `tsc` to `dist/`, publishable to npm |
| `app` | Node application compiled to `dist/`, not published |
| `web-app` | Single-page application built with Vite, served by a Cloudflare Worker |

`web-app` prompts for `web_framework` (React or Preact) and `user_data` ([legal pages](#legal-pages)). Web apps include:

- Single-page application entry points (`index.html`, `src/main.tsx`, `src/App.tsx`) and Vitest setup.
- Playwright end-to-end tests in `tests/e2e/`: axe accessibility scans in light/dark modes and Content-Security-Policy enforcement.
- Mandatory legal pages, linked from the footer in the starter app.
- Cloudflare Worker configuration: `public/_headers` (security headers) and `wrangler.jsonc` (static assets, and with `worker` a Worker script for `/api/*`: [Workers hosting](#workers-hosting)).
- A `production` job in `.github/workflows/ts.yml` that deploys `main`.
- `just ts-shots`: full-page screenshots of every route at 390 and 1440 px, light and dark, in `shots/`, to attach to a pull request that changes the UI.
- Pull request previews: a `preview` job in `.github/workflows/ts.yml`, `.github/workflows/preview-retire.yml` and `.github/scripts/preview-retire.sh`.
- Bundle size budget in `scripts/checkBundleBudget.mjs`: 100 KiB of gzipped JavaScript in the largest file. It catches a heavy dependency or a broken chunk split, not ordinary features, so keep it at least 25% above the build rather than just above it.

### Production

Every push to `main` runs the `production` job after the checks pass. It deploys the build the checks ran on to the Worker `<slug>`, with the pinned wrangler, at `https://<slug>.<subdomain>.workers.dev`. Static-asset requests are free and unlimited on the Workers Free plan. The job runs in the `production` GitHub environment, which `just repo-settings` limits to `main`. A preview job that holds the same Cloudflare token can still deploy to `<slug>` (see [Pull request previews](#pull-request-previews)). Without `CLOUDFLARE_API_TOKEN` or `CLOUDFLARE_ACCOUNT_ID`, the job skips with a notice. For a custom domain, set `site_url` to it ([Workers hosting](#workers-hosting)).

#### Moving an app off Cloudflare Pages

An app made before this template deployed from CI was deployed by Cloudflare Pages. To move it:

1. Delete any Pages `public/_redirects` rule with status `200!`: Workers refuses it with error `100324`. Merge the `copier update`, then run `just repo-settings` and add both secrets to the new `production` environment.
2. The next push to `main` deploys the Worker. Check the app at its workers.dev address.
3. Remove the custom domain from the Pages project. With `site_url` set to it, the next production deploy attaches it to the Worker.
4. Delete the Pages project, now that the Worker serves production.

Before step 2, check that the account has no Worker named `<slug>`: the first deploy overwrites it. Expect a short gap while the domain moves from Pages to the Worker.

Without a custom domain, the app's address changes: set the new one with `copier update --data site_url=https://<slug>.<subdomain>.workers.dev`.

### Pull request previews

Each pull request that is open, not a draft, not opened by a bot such as Renovate and not from `chore/copier-update` gets its own Cloudflare Worker, `<slug>-pr-<number>`, at `https://<slug>-pr-<number>.<subdomain>.workers.dev`. The `preview` job deploys `wrangler.jsonc` under that name. The job summary and the pull request's deployment show the link. Previews are public, and they send `X-Robots-Tag: noindex`. With a custom domain, production sends it only on the duplicate workers.dev origin.

When a pull request closes or turns draft, `preview-retire.yml` deletes its Worker through the Cloudflare API. A daily run lists the account's `<slug>-pr-<number>` Workers and deletes those whose pull request is not open and ready, in case an event was missed. When it cannot read a pull request, it keeps that Worker and fails. To retire previews by hand, run that workflow with a list of pull request numbers, or with the list empty to run the sweep.

Fork pull requests and repos without `CLOUDFLARE_API_TOKEN` or `CLOUDFLARE_ACCOUNT_ID` skip the job with a notice. One-time setup:

1. Run `just repo-settings`. It creates the `preview` and `production` environments in GitHub (or create them under Settings > Environments, with `production` limited to `main`).
2. Create a custom Cloudflare API token with the permission Account > Workers Scripts: Edit. Add it to both environments as the secret `CLOUDFLARE_API_TOKEN`, and add your account ID as `CLOUDFLARE_ACCOUNT_ID`.

The `preview` job runs the pull request's code with the `preview` environment's Cloudflare token. If both environments hold one account-wide token, anyone who can push a branch can deploy over the production Worker. To keep them apart, give previews a token from a second Cloudflare account.

The first deploy creates each Worker, so there is nothing to set up in Cloudflare except the token. The account needs a workers.dev subdomain. wrangler is an exact devDependency in `package.json` ([why](decisions/0002-wrangler-is-an-exact-dev-dependency.md)), and the dependency bot bumps it.

The starter app is yours after the first render. `copier update` never touches `src/App.tsx`, `src/App.test.tsx`, `src/main.tsx`, `src/app.css` or the Worker script, even to bring back one you deleted. It leaves `index.html`, `tests/e2e/routes.ts` and the Markdown files in `docs/` alone too, but re-creates one you delete.

The web app's folder also gets `PRODUCT.md` and `DESIGN.md`, stubs to fill in. They name who uses the app and how it looks, and are yours to edit: an update leaves them alone.

### Legal pages

Legal documents reside in `docs/` and compile to HTML at build time:

| Document | Route | Generation condition |
| --- | --- | --- |
| `docs/accessibility.md` | `/accessibility` | Always |
| `docs/privacy.md` | `/privacy` | Always (includes storage disclosure) |
| `docs/terms.md` | `/terms` | `user_data=accounts` |

`user_data` options: `nothing`, `browser` (local storage only), or `accounts` (server-side data). Playwright tests in `tests/e2e/` verify these pages render properly, contain required contact information, and introduce no undeclared storage or network requests. They also check that every route in `LEGAL_LINKED_FROM` links each page and that each page links back to `/`. The starter's `LEGAL_LINKED_FROM` in `tests/e2e/routes.ts` is all of `ROUTES`; an app that links the pages from one screen, such as its settings, sets it to that screen.
[Legal pages: tips](web-legal.md) says how to fill them in.

## Compose-only repos

A repo that only composes upstream images, with shell scripts and Compose files but no
Dockerfile of its own, answers `stacks=[docker]`. Any `stacks` with `docker` but not
`python` renders a Compose-only repo, because the only image the template builds is the Python one. With
the python stack, answer no to `docker_image` (`--data docker_image=false`) to keep the
package without an image.

The render has no Dockerfile, no image build and no `docker.yml`. It gets:

- `compose.yaml`: one example service with its image pinned by digest, a healthcheck and a
  port bound to `127.0.0.1`. Replace it with your own services: it and `.env.example` are
  yours after the first render, and `copier update` leaves them alone.
- `.env.example`, which `compose.yaml` reads through an optional `.env`.
- `just check`, which runs `docker compose --env-file .env.example config -q` (CI has no
  `.env`), then shellcheck and shfmt (2-space indent, from images pinned by digest) over
  every tracked script that starts with a shell shebang, then the `local-check` recipe if
  `just/local.just` has one. It needs a Docker daemon.
- `.github/workflows/compose.yml`, which runs `just docker-check` (not `local-check`) with no token scopes beyond
  `contents: read`, and is a required check on `main` when `public` is on.
- The `docker-compose` ecosystem in the dependency bot, so image tags and digests get update
  pull requests.

The shellcheck and shfmt images in `just/docker.just` are pinned by digest, and no bot
bumps them: update the tags and digests by hand now and then. `just docker-fmt` applies
shfmt's formatting (`.editorconfig` sets 2-space indent for `*.sh`), and `just fmt` runs it.
Shell files are the `*.sh` files and files whose first line is an sh, bash, dash or ksh
shebang. A zsh or fish script, or a shebang inside a Markdown code block, is not linted.

The git hooks, license and REUSE files, community files and the other CI workflows come
from the same questions as in any other project. `app_port` and `publish_to_ghcr` are not
asked: there is no image to expose or push.

## One package or a monorepo

By default, packages reside at the repository root. To host multiple packages, enable `customise` and assign distinct directory paths (for example, `python_dir: apps/api` and `ts_dir: apps/web`):

```text
apps/api/{pyproject.toml,src,tests,Dockerfile,.dockerignore}
apps/web/{package.json,tsconfig.json,biome.json,src}
compose.yaml
.github/workflows/
justfile, just/, .pre-commit-config.yaml, .copier-answers.yml
```

Workflows and configuration files remain at the repository root. Two packages may share the root directory.

## Licenses

Available code licenses:

- **MIT** (default): permissive reuse with attribution.
- **Apache-2.0**: permissive reuse with an explicit patent grant.
- **BSD-3-Clause**: permissive reuse prohibiting endorsement without permission.
- **GPL-3.0-or-later**: copyleft requiring derivative works to remain GPL-licensed.
- **AGPL-3.0-or-later**: network copyleft covering hosted network services.

`data-pipeline` and `research` projects configure `data_license` for files under `data/`. Research data defaults to CC-BY-4.0. Data pipelines default to CC0-1.0 because they commit only fetch logs; pipeline outputs inherit their respective source licenses.

Licensed projects follow the [REUSE specification](https://reuse.software). `REUSE.toml` declares copyright and licensing rules, full texts reside in `LICENSES/`, and the `reuse` git hook checks compliance. External files copied into the repository must include `SPDX-FileCopyrightText` and `SPDX-License-Identifier` headers or corresponding entries in `REUSE.toml`.

## Public repos

`public` defaults to `yes`. Choosing `no` for private repositories omits `.github/SECURITY.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `pull_request_template.md`, issue forms, and the DCO sign-off check.

Public repositories also receive `.github/workflows/scorecard.yml` to publish [OpenSSF Scorecard](https://scorecard.dev) results for the README badge.

### Making a repo public

Before switching a private repository to public:

1. Scan git history for committed secrets:

   ```sh
   betterleaks git --log-opts=--all .
   ```

   Revoke any detected credentials and rewrite history before publishing.
2. Confirm package name availability on target registries ([PyPI](https://pypi.org/search/), [crates.io](https://crates.io), [npm](https://www.npmjs.com)).
3. Review open issues and pull requests to ensure internal notes or identifiers are removed.
4. Verify the status statement in `README.md`.

Update the repository configuration with Copier:

```sh
copier update --data public=true --data license=MIT
```

## Protecting main

`just repo-settings` applies `.github/rulesets/main.json` using the GitHub CLI:

- Blocks force-pushes and branch deletions.
- Enforces linear history and squash merges.
- Requires pull requests. A required check blocks every PR that skips CI, because a skipped workflow leaves its check pending. If some PRs in your repo skip CI, drop `required_status_checks` from the ruleset or make that check always report. In private repositories, the checks `git hooks`, `pull request title` and `dependency review` must pass.
- In public repositories, requires one approving review submitted after the latest push. Required checks reside in `.github/rulesets/main-checks.json`, which requires the same three, `DCO sign-off`, and each stack's own check (`ts: lint, types, tests` and so on, with `python: tests (windows)` under `python_windows`) for a stack at the repo root, `compose` in a Compose-only repo, plus `site: build` when the project has a site. A nested stack's workflow runs only when its folder changes, so its check is not required.
- With `dependency_bot=renovate`, permits the Renovate app to bypass review for minor and patch updates once required checks pass.
- Applies `.github/rulesets/tags.json` to restrict `v*` tag creation to repository administrators.
- Enables Dependabot security alerts (`gh api -X PUT repos/OWNER/REPO/vulnerability-alerts`).

It leaves one setting to you: refusing any action not pinned to a full commit SHA. The template's workflows pin every action, but the setting also stops a workflow added later from using a tag. Turn it on once the repo's own workflows pin too, since an unpinned action then fails its run:

```sh
gh api -X PUT repos/OWNER/REPO/actions/permissions -F enabled=true -f allowed_actions=all -F sha_pinning_required=true
```

This call also resets `allowed_actions` to `all`; check the current value first with `gh api repos/OWNER/REPO/actions/permissions`.

Execute `just repo-settings` once after creating the repository and again whenever ruleset templates change. Requires administrative permissions.

## The GitHub About box

`just repo-about` syncs repository metadata with `gh repo edit`:

- Updates repository description from `project_description`.
- Sets homepage URL from `site_url` for web apps.
- Adds stack topics (`python`, `typescript`, `rust`, `go`, `docker`). Existing manual topics are preserved.

## Keeping your project up to date

`copier update` performs a three-way merge against the latest template release.

User-owned files are never overwritten: `README.md`, `CHANGELOG.md`, citation files (`CITATION.cff`, `codemeta.json`), community-level governance documents, web app starter code, `<package>.api.md`, and `go.mod`.

Known limit: once a project has deleted any file the template renders, copier 9.19.1 reads the skip list before it loads the answers. A Compose-only repo's `compose.yaml` and `.env.example`, and the owned files under `ts_dir` or `go_dir`, then merge with the template's and can conflict. Keep your side of each.

Updates skip the sample code and pages (the package's `__init__.py`, `tests/test_add.py`, the web app's components, the site's pages and Worker scripts), so a sample you deleted stays deleted. So does a feature you turn on later with `copier update --data`: it comes without its samples, which a fresh `copier copy` into a scratch directory shows. Delete a file the project owns, such as `README.md`, and the update writes it again.

To relocate a package directory, execute `copier update` with the new path and delete the old directory manually.

If upgrading from pre-v0.12.0 projects with `docs/adr/`, move existing records to `docs/decisions/` and remove `docs/adr/`.

After updating, refresh and commit project lockfiles (`uv lock`, `pnpm install`, `just go-sync`).

### Hearing about new releases

- **Renovate:** Automatically opens update PRs using `copier update --skip-answered --defaults`. Inspect PR diffs for conflict markers before merging.
- **Dependabot:** The `.github/workflows/copier-update.yml` workflow runs weekly and on demand. When updates exist, it opens a PR on branch `chore/copier-update`. It updates each `.copier-answers*.yml` in turn, so a [layered template](#layering-another-template) lands in the same PR. Closing that PR unmerged skips its tag; a later tag can open a new PR.

Without [the update App](#the-update-app), `copier-update.yml` pushes with `GITHUB_TOKEN`, which can't change files in `.github/workflows/`: an update that does opens an issue asking for a local update instead. A PR it opens starts no checks either, because `GITHUB_TOKEN` events trigger no workflows. Close and reopen the PR to run them; its body says so. To open the PR at all, turn on Settings > Actions > General > "Allow GitHub Actions to create and approve pull requests". With the App, the workflow does not need it.

#### The update App

A GitHub App of your own gives the workflow a token for each run. The token lasts an hour, reaches only the repo it runs in, and is revoked when the job ends. One App serves all your repos.

1. Create the App at <https://github.com/settings/apps/new>. Give it a name and any homepage URL, untick Webhook > Active, and give it the repository permissions Contents, Pull requests and Workflows, each "Read and write". Let it be installed on this account only.
2. On the App's page, note the Client ID and generate a private key, which downloads a `.pem` file.
3. Install the App on each repo that uses the template (Install App, then Only select repositories).
4. In each repo, run `just repo-settings`. It creates the `copier-update` environment and limits it to `main`, so a workflow on another branch can't read the key. (On a private repo on GitHub Free the environment cannot limit branches; see the note below the commands.) Then add the App to it:

   ```sh
   gh variable set COPIER_UPDATE_CLIENT_ID --env copier-update --body <client-id>
   gh secret set COPIER_UPDATE_PRIVATE_KEY --env copier-update <app.private-key.pem
   ```

Delete the `.pem` file afterwards, or keep it in your password manager to set up the next repo.

A private repo on GitHub Free has no environment secrets. There, leave `--env copier-update` out of both commands: the job reads repo-level ones too, but then a workflow on any branch can read the key. There the key is readable from any branch, so use one App per repo, or skip the App and use the `GITHUB_TOKEN` path above.

## Publishing

To publish a release:

1. Set the version in `pyproject.toml` and `package.json` to `X.Y.Z` (only the one you publish). A citable project sets it in every manifest `citesync.toml` lists, or in every manifest at the root when it has no `citesync.toml`. `CITATION.cff` starts with no `version`, so citesync skips it; once you add one, after the first release, set it there too, or citesync fails with `version-mismatch`.
2. Run `just release X.Y.Z`. It checks that version and, in a citable project, runs the citesync hook, then cuts `## [Unreleased]` in `CHANGELOG.md` into `## [X.Y.Z] - date`, fixes the compare links and commits. In a web app it also sets the version in `package.json` itself and commits both files.
3. Merge that commit to `main`, then run `just release X.Y.Z` again on up-to-date `main`. It signs the annotated tag `vX.Y.Z` on `origin/main`, checks it against `.github/allowed_signers` on `origin/main` and pushes it. A web app's run first refuses a `package.json` on `origin/main` at another version, and its `release.yml` refuses such a tag again before it publishes. See [Signed release tags](#signed-release-tags) for the key it needs.

With `publish_to_pypi`, `python-release.yml` publishes to PyPI and attaches distributions and Sigstore provenance to the GitHub release. Other configurations publish using `release.yml`.

If a publishing job fails before artifacts upload to the registry, re-run the failed CI job on the existing tag. PyPI uploads stay strict: an existing filename fails the job, so inspect a partial upload before publishing a new patch version. If `docker.yml`'s `attest` step fails after the image push, re-run only that step: a full re-run rebuilds the image and repoints the semver tags. If the release artifact is already published to the registry, do not move the git tag; bump the patch version and publish a new release.

Publishing controls:

| Option | Disabled | Enabled |
| --- | --- | --- |
| `publish_to_pypi` | Package marked `Private :: Do Not Upload` | `python-release.yml` publishes to PyPI |
| `publish_to_npm` | Package set to `"private": true` | `ts-release.yml` publishes to npm |
| `publish_to_ghcr` | Images built and tested; no push | Images pushed to GitHub Container Registry |

Setting up trusted publishing (OIDC):

1. Configure trusted publishers on [pypi.org](https://pypi.org/manage/account/publishing/) or [npmjs.com](https://docs.npmjs.com/trusted-publishers/). For npm, manually publish version 0.1.0 before enabling trusted publishing.
2. Run `just repo-settings` to create required environments (`pypi`, `npm`, `ghcr`) with yourself as required reviewer and a `v*` tag policy (`ghcr` also on `main`).
3. Enable publishing via Copier:

   ```sh
   copier update --data publish_to_pypi=true
   ```

### Signed release tags

Every workflow that publishes from a tag (`release.yml`, `python-release.yml`, `ts-release.yml`, and the tag push in `docker.yml`) first runs `.github/scripts/verify-tag.sh`. It passes only an annotated tag with an SSH signature from a key listed in `.github/allowed_signers`, read from the default branch rather than from the tag, so a tag cannot bring its own key. GitHub's "Verified" mark is not enough: it accepts a key registered to any GitHub account. `tag-release.sh` runs the same check before it pushes.

The file renders with a comment and no keys, so the first release fails until you add yours. Sign with an SSH key (`git config gpg.format ssh` and `git config user.signingkey ~/.ssh/id_ed25519.pub`), then add it and commit to `main`:

```sh
echo "$(git config user.email) namespaces=\"git\" $(cat "$(git config --type=path user.signingkey | sed 's/\.pub$//').pub")" >>.github/allowed_signers
```

The check holds together with the `v*` tag ruleset, which lets only admins push tags: a tag runs the workflow and script from its own commit, so a tag pushed by someone else could carry a weaker check. `copier update` and Renovate also move a project to the newest `v*` tag of the template whether or not that tag's `release.yml` accepted it.

A GPG-signed tag fails the check: `git tag -v` reads an allowed signers file for SSH signatures only. `allowed_signers` is the project's file after the first render, and `copier update` leaves it alone. To check a tag yourself: `git -c gpg.ssh.allowedSignersFile=.github/allowed_signers tag -v vX.Y.Z`.

### First release

A public citable project, a project at level `standard` or `community`, and one with `publish_to_pypi` get `.github/first-release.md`: the one-time steps around the first release, only those its answers need. `just repo-settings` prints the command that opens it as an issue. Delete the file once the issue is open.

The steps are the release signing key, PyPI trusted publishing, Zenodo, [Software Heritage](https://archive.softwareheritage.org/save/), the [Research Software Directory](https://research-software-directory.org) and the OpenSSF Best Practices badge. A public citable README gets a Software Heritage badge. It reads "not found" until the archive has visited the repo, then links to the archived copy and its SWHID. After `just release` pushes a tag, it prints the Software Heritage save link.

## API-break check

With `publish_to_pypi`, a Python library gets an `api` job in `python.yml`. It runs griffe against the last git tag and fails when a public name loses or changes a parameter. Every name without a leading underscore counts as public.

A package used only through its command line has no Python API to protect. Answer `python_api=false` to drop the job:

```sh
copier update --data python_api=false
```

To keep the job and mark a module internal instead, start its name with an underscore (`_check.py`).

A Rust library always gets an `api` job in `rust.yml`, and `just rs-api` runs the same check locally. It runs [cargo-semver-checks](https://github.com/obi1kenobi/cargo-semver-checks) against the last `v*` tag and reads the version in `Cargo.toml`: a break passes only after a major bump, or a minor bump before 1.0. Before the first tag, it passes. `rs-check` leaves it out, so a deliberate break does not hold up the other checks.

## Tests on Windows

`python_windows` adds a `windows` job to `python.yml`. It runs `uv run pytest` on `windows-latest` with `python_version`, so a text file opened without `encoding="utf-8"`, a path built with `/`, or a POSIX-only module such as `fcntl` fails CI instead of a Windows user. Ruff and ty read the same code on every OS, so the job skips them, and it checks out the committed bytes (no CRLF conversion) so a test that hashes a committed file passes. It costs one more job on every push and pull request; Windows runners are also slower to start. With the Python package at the repo root, its check `python: tests (windows)` is required like the Linux ones.

```sh
copier update --data 'extras=[cold_install,python_windows]'
```

Run `just repo-settings` after the update, so a public repo requires the new check.

## Coverage on Codecov

`codecov` (Python and TypeScript) uploads coverage reports to [Codecov](https://codecov.io). Pull requests fail only if overall coverage drops by more than 2 percentage points.

Setup:

1. Register the repository on Codecov and retrieve the upload token.
2. Save it as repository secret `CODECOV_TOKEN` (`gh secret set CODECOV_TOKEN`).
3. Enable Codecov:

   ```sh
   copier update --data 'extras=[cold_install,codecov]'
   ```

## Benchmarks on CodSpeed

`codspeed` (Python and Rust) adds `.github/workflows/benchmarks.yml` and starter benchmarks (`tests/test_benchmarks.py` or `benches/codspeed.rs`). CodSpeed measures CPU instruction counts in simulation on PRs that touch benchmarked code and on every push to `main`.

Setup:

1. Import the repository on [codspeed.io](https://codspeed.io).
2. Set Pull Request comments to "On Change" in CodSpeed repository settings.
3. Enable CodSpeed:

   ```sh
   copier update --data 'extras=[cold_install,codspeed]'
   ```

## Profiling

`profiling` (Python and Rust) adds profiling recipes:

- **Python:** `just py-profile <script or -m module> <args>` runs pyinstrument on demand via `uv run --with` without modifying dependencies.
- **Rust:** `Cargo.toml` adds a `[profile.profiling]` profile. `just rs-profile <command>` records performance profiles using [samply](https://github.com/mstange/samply); `just rs-counters <command>` executes `perf stat` five times to measure CPU cycles and branch misses. Requires local kernel perf event support.

Enable with:

```sh
copier update --data 'extras=[cold_install,profiling]'
```

## Test extras

Library kinds select `property` and `mutation` in `extras` under `customise`:

| Option | Python | TypeScript | Rust | Go |
| --- | --- | --- | --- | --- |
| `property` | Hypothesis | fast-check | proptest | Native fuzz test (`FuzzAdd`) |
| `mutation` | mutmut (`just py-mutation`) | Stryker (`just ts-mutation`) | cargo-mutants (`just rs-mutation`) | gremlins (`just go-mutation`) |

Property tests run fast suites locally and in CI. Weekly scheduled jobs (`.github/workflows/property.yml`) execute extended runs (10,000 cases or 10 minutes of fuzzing).

Mutation testing runs weekly via `.github/workflows/mutation.yml` and on demand via `just <stack>-mutation`. The Python and Rust jobs fail on a surviving mutant. The TypeScript and Go tools exit 0 when a mutant survives, so those jobs only print survivors.

Python: `just py-mutation` fails on a survivor (a mutant the tests miss, or that no test reaches) that is not in `tests/mutation-baseline.txt`. It also fails on a listed mutant that no longer survives, so the list stays true. Each line is the mutant name, then the reason. List a mutant only when no test could see the change. Mutant numbers shift when their function changes, so recheck the lines then. `copier update` adds the file with no entries; run the recipe once and list what it reports. Give it mutmut patterns, e.g. `just py-mutation 'mypkg.core.x_parse__mutmut_*'`, to run only those mutants; that run skips the check for listed ones that no longer survive.

A full run takes minutes to hours, so check each change with the diff recipe instead and keep the full run for the weekly job and before a release:

| Stack | Per-change recipe | What it runs |
| --- | --- | --- |
| Python | `just py-mutation-diff` | the mutants of functions and methods the branch changed since it split off `origin/main`, in the mutated modules (`just/mutation_diff.py` finds them) |
| Rust | `just rs-mutation-diff` | `cargo mutants --in-diff` on the branch's changes since it split off `origin/main` |
| Go | `just go-mutation-diff` | `gremlins unleash --diff` against the commit where the branch split off `origin/main` |
| TypeScript | none | Stryker has no diff mode. Its `--incremental` reuses the results file of an earlier run, which needs a stored file between runs, so the template adds no recipe |

Each takes another git ref, e.g. `just py-mutation-diff main`.

To add extras to an existing project:

```sh
copier update --data 'extras=[cold_install,property]'
```

## Static site

Answer `site` (under `customise`) to give any project a static page beside its code: a playground, a demo or a report. GitHub Pages serves it from `main`, or a Cloudflare Worker with `site_host=cloudflare`, and each pull request gets a preview. The page's readers are the project's users, so it stays small: the tool in the first screen, details in disclosures.

The two choices differ only in what is in `site/` and how `just site` builds it:

- `site=plain`: `site/index.html`, `site/style.css` and `site/main.mjs`, a working [tool page](#the-plain-tool-page). Plain HTML, CSS and an ES module, no build step or framework. `just site` copies `site/` to `_site/`. For a page that needs a build, replace the recipe's body with yours, such as `uv run site/build.py --out _site`, and add the setup it needs (uv, Rust, Node) before `just site` in the `build` job of `site.yml`.
- `site=astro`: a small Astro project. `package.json` has astro at the version `copier.yml` pins, `src/layouts/Base.astro` has the same header and footer, and `src/pages/` holds `index.astro` and a Markdown page, `about.md`. Run `just site-sync` once to write `site/pnpm-lock.yaml`, and commit it. `just site` installs from that lockfile and runs `astro build` into `site/dist/`. The `build` job sets up Node and pnpm from `site/package.json`, so the repo needs no TypeScript stack. Pages serves the site at `https://<user>.github.io/<repo>/`, so `site` and `base` in `astro.config.mjs` match it. On a Worker (`site_host=cloudflare`), the site is served from `/`: `site` is the Worker's address and there is no `base`.

The starter files are yours: an update leaves them alone. An Astro site's `package.json` stays the template's, and Dependabot or Renovate bumps it. Both choices also render:

- `.github/workflows/site.yml`. The `build` job runs `just site` on every pull request and push to `main` and uploads the result, which is gitignored. The `deploy` job publishes that build to GitHub Pages on a push to `main`. It is the only job with `pages: write`. [On a Worker](#hosting-on-a-worker), it deploys to the Worker instead.
- The `preview` job in `site.yml`, with `wrangler.site.jsonc`, `.github/scripts/deploy-worker.sh`, `preview-retire.yml` and `preview-retire.sh`. These are the web app's own preview pieces, with the same lifecycle ([Pull request previews](#pull-request-previews)): a pull request that is open, not a draft, not opened by a bot and not from `chore/copier-update` gets the Worker `<slug>-site-pr-<number>`, and it comes down when the pull request closes or turns draft. The `-site` in the name keeps it apart from a web app's `<slug>-pr-<number>` in a repo that has both. The job deploys the build job's artifact, not a fresh build, under `/<repo>/` as Pages does, with a redirect from `/` (from `/` itself on a Worker), and sends `X-Robots-Tag: noindex`.

On GitHub Pages, the one-time setup is below; on a Worker, see [Hosting on a Worker](#hosting-on-a-worker).

1. Run `just repo-settings`. It creates the `preview` environment and sets GitHub Pages to deploy from Actions (Settings > Pages > Source: GitHub Actions).
2. Add the Cloudflare API token (Account > Workers Scripts: Edit) to the `preview` environment as `CLOUDFLARE_API_TOKEN`, and your account ID as `CLOUDFLARE_ACCOUNT_ID`. Without either secret, the preview job skips with a notice, and Pages still deploys.

A GitHub Pages site is public even when the repo is private, and a private repo needs a paid GitHub plan for Pages. Until Pages is on, the `deploy` job skips with a notice, and `just repo-settings` warns and goes on where GitHub refuses Pages.

The daily sweep finds preview Workers by name alone. In one Cloudflare account, a repo `foo` with a site and a repo `foo-site` with a web app would share the names `foo-site-pr-<number>`: rename one of them if that happens.

### The plain tool page

`site=plain` starts from a small working tool: it formats JSON. It's there to show the layout and the states, and you replace the job with your own. The page has four parts, top to bottom:

1. A header with the project name, `project_description` as the one sentence that names the job, and a Docs link to the README. Without a description, a TODO marks where the sentence goes.
2. The workspace: an input with an Open a file button, and beside it the result with one action, Copy result. They sit side by side from 48rem and stack on a phone. The result updates 250 ms after the visitor stops typing. A label beside the result shows its state: Sample, Empty, Needs a fix or Ready. An error shows under the input, and Copy result is off until the input is valid again, so nobody copies a stale result. Screen readers hear a state change or the copy outcome, not every refresh.
3. Two disclosures: Settings, with an indent choice, and Use it elsewhere, a TODO for the command-line or CI use of the same job.
4. A footer with one privacy line, then the licence, the source and the issue tracker. A private repo's page has no links into the repo.

To make it your tool, change `convert()` at the top of `main.mjs`, the labels in `index.html`, and the colours at the top of `style.css`. `convert()` returns the result text, or throws an error whose message the page shows under the input.

The privacy line says that what the visitor types never leaves the page. The page's Content-Security-Policy has no `connect-src`, so the browser blocks any request the script makes, and the line stays true. A page that calls an API, such as a `worker` route, adds that origin to `connect-src` and changes the line to say what it sends.

The page has a skip link, labelled controls, a visible focus ring and targets at least 44 px tall. It follows the system's dark mode and reduced-motion setting, and keeps the primary action visible in forced colours.

### Hosting on a Worker

`site_host=cloudflare` replaces Pages with the Worker `<slug>-site`, from the same `wrangler.site.jsonc` the previews use. The `deploy` job deploys the build job's artifact on every push to `main`, in the `production` environment, one at a time, and skips with a notice without the Cloudflare secrets. Previews serve the build from `/`, as production does, with no redirect. `site_url` is the site's address, and can be a custom domain; with `worker`, a Worker script answers `/api/*` ([Workers hosting](#workers-hosting)). A repo with a web app keeps `site_url` for the app, and the site stays at its workers.dev address.

The starter `astro.config.mjs` is the project's, so switching an existing Astro site from Pages leaves it alone: set `site` to the new address and delete `base`.

One-time setup: `just repo-settings` creates the `preview` and `production` environments instead of setting up Pages. Add both Cloudflare secrets to each.

## Social card

A web app or a site renders `docs/og-card.html`, a 1200x630 poster with the project name, `project_description` and the site's address, and `og:image`, `og:image:width`, `og:image:height`, `og:image:alt` and `twitter:card` tags in the page head that point at it. The alt text is the name and the description. The file is yours: an update leaves it alone.

Run `just og-card` to render it to a PNG, and commit the PNG: `public/og.png` for a web app, `site/og.png` for `site=plain` and `site/public/og.png` for `site=astro`. A web app renders with the Playwright in its devDependencies (`pnpm exec playwright install chromium` once). A site runs `pnpm dlx playwright@<pinned version>`, so it needs no Node package of its own. The recipe also writes the PNG's first 8 hex of SHA-256 into the page's `og:image` URL (`og.png?v=<hash>`), because Facebook, Slack, Discord and iMessage cache a preview by image URL and would keep the old card after a redraw. Commit the page with the PNG. The head tags point at a file that does not exist until you run it.

Replace the card's colours and font with the project's own, then check it before you commit:

- View it at 300 px wide. The name and the one-line job must still read.
- Crop it to the centre 630 px square. Small square thumbnails (LinkedIn posts, X `summary`, WhatsApp) cut it that way, so the name and any mark must survive there. The job line and the address only need to stay 60 px clear of every edge, since no thumbnail is big enough to read them.

Keep the text at 36 px or more at 1200 px wide, one idea on the card, no label above the name, and never a screenshot of the app: it is illegible at preview size. Keep the job line and the address on the card even though `og:description` and the alt text say the same: X shows only the image, LinkedIn hides the description, and a shared screenshot carries no preview text. One real result or short example may go under the job line to prove it. A repo with both a web app and a site prints the app's address on the one card.

## Workers hosting

What deploys to a Cloudflare Worker (a web app, or a site with `site_host=cloudflare`) shares two answers.

`site_url` is its public address. Give a host alone, without a path: a Worker serves a whole host. When the host is not `*.workers.dev`, it is a custom domain: the production job runs `wrangler deploy --domain <host>`, which attaches it to the Worker and creates its DNS record. The domain needs a zone in the same Cloudflare account, without a CNAME record for that host, and the production token needs Zone > Workers Routes: Edit for that zone. The domain is not in the wrangler config, because previews deploy that config under their own names and must not take it. `just repo-about` sets it as the repo's homepage.

`worker` adds a Worker script in front of the static assets, for server code such as an API. `main` in the wrangler config points at it, the `ASSETS` binding lets it hand a request to the files, and `run_worker_first: ["/api/*"]` sends only `/api/*` to it first. Every other request is served from the files without running the script, so it stays free; each request the script handles counts against the Workers plan. The starter has one route, `/api/health`, answers 404 for the rest of `/api/`, and passes anything else to the files.

- A web app gets `worker/index.ts`, with its own `worker/tsconfig.json` that swaps the DOM types for `@cloudflare/workers-types`. `pnpm run typecheck` checks both, and Vitest runs `worker/index.test.ts` in Node against a stub `ASSETS`. `pnpm dev` runs Vite alone; `pnpm exec wrangler dev` serves the last build and the script together.
- A site gets `site/worker/index.mjs`, plain JavaScript with no TypeScript stack needed. `just site` runs `site/worker/index.test.mjs` with `node --test` first, and a plain site's build leaves `worker/` out. wrangler bundles the script on every preview and production deploy, so a script that does not bundle fails the pull request's preview.

A plain site on a Worker also gets `site/_headers`, with the same security headers as a web app's `public/_headers` (a Content-Security-Policy with `frame-ancestors 'none'`, `X-Content-Type-Options: nosniff` and HSTS). The page's meta tag cannot set `frame-ancestors`, so keep the header's policy in step with it; a site on Pages cannot send headers.

The script and its test are the project's after the first render. A binding beyond `ASSETS` (KV, D1, a secret) also reaches every preview: read [decision 0001](decisions/0001-pr-previews-use-the-production-cloudflare-account.md) first.

## Documentation site

Select `docs_site` in `extras` (under `customise`) when outside users need search or versioned docs (the `docs-site` requirement in [Levels](#levels)): a search-indexed site built from the Markdown in `docs/`. [Zensical](https://zensical.org) builds it, and GitHub Pages serves it from `main` at `https://<user>.github.io/<repo>/`. The site reads the files in `docs/` as they are, so there is no second copy to keep in step. Without a `nav` in `zensical.toml`, the menu follows the files.

A render with `docs_site` gets:

- `zensical.toml` and `docs/index.md`, the home page. Both are yours: an update leaves them alone.
- `docs/reference.md`, for a Python library with `python_api`. It holds one `::: <module>` line, which mkdocstrings expands into the API reference from the docstrings. It reads the source without importing the package.
- `just docs`, which builds into `_docs/` (gitignored), and `just docs-serve`, which serves the site on port 8000 and rebuilds it on each save. Both run the Zensical that `copier.yml` pins with `uvx`, so the project needs no docs dependencies. Like the project's own installs, uvx resolves only releases at least a week old. `copier update` brings a newer pin.
- `.github/workflows/docs.yml`. Every pull request and push to `main` runs `just docs`. In a public repo, `docs: build` is a required check. The `deploy` job publishes the build to Pages on a push to `main`. `just repo-settings` sets Pages to deploy from Actions.

The build is strict: a warning fails it. A link to a page that does not exist is a warning, and so is a link out of `docs/`, such as `../README.md`. Link to files outside `docs/` with their full GitHub URL instead.

TypeScript, Rust and Go projects get the site too, without an API reference. A Rust crate has one on docs.rs and a Go module on pkg.go.dev. The template has none for TypeScript yet.

One repo has one Pages site, so the template refuses `docs_site` together with a `site` on Pages. A `site` [on a Worker](#hosting-on-a-worker) leaves Pages to the docs. Otherwise, a playground page can go in `docs/` as Markdown or HTML.

The template also refuses `docs_site` for a web app at the repo root (`ts_dir` is `.`). The app keeps its privacy, terms and accessibility pages in `docs/`, so the docs site would publish a second copy that can drift from the one the app serves. A web app in a subfolder, such as `ts_dir=web` beside a Python package, keeps them in `web/docs/` and can have the site.

## OpenSSF Best Practices badge

The [level](#levels) prepares a public, licensed repo for a level of the [OpenSSF Best Practices badge](https://www.bestpractices.dev): `standard` for passing, `community` for silver, and `minimal` for neither.

- `standard` (passing): adds testing and style sections to `.github/CONTRIBUTING.md`, and a `## Usage` section to `README.md` that links the releases and the package registry, with a TODO for what the software does and how to use it.
- `community` (silver): adds `GOVERNANCE.md`, `docs/roadmap.md`, and `docs/assurance-case.md`, and the `dco` workflow checks every pull request, not only fork ones. The `dco-signoff` commit-msg hook (`git commit -s`) comes with every public render.

A public render at `standard` meets every MUST criterion of the passing level that a file or a repository setting can meet. The rest depend on you, or on the project's history.

### Before you register

1. Push the repository to GitHub and run `just repo-settings`. It protects `main` against direct pushes and deletion, and turns on secret scanning with push protection, private vulnerability reporting and CodeQL default setup.
2. Replace the TODO in the README's `## Usage` section. Say what the software does and the problem it solves, then show its basic use.
3. Write doc comments for the public API. They are its reference documentation. In Python, ruff's `D` rules ask for them.
4. Turn on two-factor authentication for your GitHub account. For a repository in an organization, also require it under the organization's Settings > Authentication security.
5. Make a release with `just release X.Y.Z`. Its notes are the CHANGELOG section for that version.

### Register

1. Open <https://www.bestpractices.dev/en/projects/new> and log in with GitHub.
2. Under "Select a GitHub repository", pick the repository. Both URL fields take `https://github.com/OWNER/REPO`, unless the project has a home page of its own.
3. Under "Badge series", pick "metal" for passing and silver, or "baseline" for OSPS Baseline level 1. Then select "Submit Project".
4. Answer the criteria. bestpractices.dev fills in some from the repository. Give the file as the URL where a criterion asks for one.

The render cannot answer these for you:

- `know_secure_design` and `know_common_errors`: a primary developer knows secure design and the common kinds of vulnerability for this kind of software.
- `maintained`, `report_responses` and `enhancement_responses`: you reply to issues. `.github/CONTRIBUTING.md` promises a reply within about two weeks.
- `vulnerability_report_response`: you reply to a vulnerability report within 14 days, as `.github/SECURITY.md` promises.
- `tests_are_added`, `warnings_fixed`, `static_analysis_fixed`, `vulnerabilities_fixed_60_days` and `dynamic_analysis_fixed`: the project's history shows it.
- `dynamic_analysis` (suggested): `property` in `extras` adds property tests.

Add the badge to `README.md` once bestpractices.dev awards it.

### OSPS Baseline level 1

Where a public render meets each level 1 control of [OSPS Baseline v2026.08.28](https://baseline.openssf.org/versions/2026-08-28) (level 1 is the same set of controls as in v2026.02.19):

| Control | Met by |
|---|---|
| AC-01.01 | You: two-factor authentication, step 4 above |
| AC-02.01 | GitHub: a new collaborator gets the permission you assign |
| AC-03.01, AC-03.02 | `.github/rulesets/main.json`, applied by `just repo-settings` |
| BR-01.01, BR-01.03 | No `pull_request_target` workflows; untrusted input reaches `run:` only through `env:`; the zizmor hook checks both |
| BR-03.01, BR-03.02 | GitHub and the package registries serve HTTPS only |
| BR-07.01 | The `betterleaks` hook, and push protection from `just repo-settings` |
| DO-01.01 | You: the README's `## Usage` section, step 2 above |
| DO-02.01, GV-02.01, GV-03.01 | `.github/CONTRIBUTING.md` and GitHub issues |
| LE-02.01 to LE-03.02 | `LICENSE` and `LICENSES/` in the repository, so each release's source archive has them too |
| QA-01.01, QA-01.02 | The public GitHub repository and its git history |
| QA-02.01 | The stack's manifest and lockfile, such as `pyproject.toml` and `uv.lock` |
| QA-04.01 | Not applicable to a single repository |
| QA-05.01, QA-05.02 | `.gitignore` and the `check-added-large-files` hook |
| VM-02.01 | `.github/SECURITY.md` |

## Dependency updates

`dependency_bot` selects your automated update tool:

- **Dependabot** (default): built into GitHub; updates dependencies, workflows, and hook SHAs without external apps.
- **Renovate:** install the [Renovate GitHub App](https://github.com/apps/renovate), then run:

  ```sh
  copier update --data dependency_bot=renovate
  ```

  Disable Dependabot automated security fixes (`gh api -X DELETE repos/OWNER/REPO/automated-security-fixes`) while leaving security alerts active.

## Spelling and link checks

Two git hooks validate prose:

- `typos`: detects spelling errors in code, comments, and documentation. Add project-specific terms to `_typos.toml` at the repository root:

  ```toml
  [default.extend-words]
  ue = "ue"
  ```

  typos knows English only. The hook skips gettext `.po` files and anything in a `locales/` directory; list other files with text in other languages under `[files] extend-exclude` in `_typos.toml`.

- `lychee`: validates links. The local git hook runs offline and checks relative paths. The weekly workflow `.github/workflows/links.yml` checks both internal and external web links. In a web app, both read `lychee.toml`, which resolves root-relative links such as `/favicon.svg` in the Vite `public/` directory.

## Scientific Python repo-review

A project with the python stack runs [sp-repo-review](https://learn.scientific-python.org/development/guides/repo-review/) as a git hook. It checks `pyproject.toml`, the pytest settings, the hooks and the workflows against the Scientific Python development guide, and fails on any check the project has not chosen to skip.

The checks the template skips on purpose are under `[tool.repo-review.ignore]` in `pyproject.toml`, each with its reason: `just` instead of nox, ruff and ty as local hooks, no reStructuredText, no pre-commit.ci. To skip another, add its code and a reason there. Run it on its own with `prek run sp-repo-review --all-files`.

## Levels

`level` sets how much a public repo commits to. Each level adds requirements to the one below it:

- `minimal`: a public repo with few users. Locked and updated dependencies, hardened workflows, the Scorecard workflow and `SECURITY.md`.
- `standard`, the default: every `minimal` and `standard` requirement that applies to the repo. The render adds the test policy and coding standards to `.github/CONTRIBUTING.md`, a `## Usage` section to the README, `.github/first-release.md` with the OpenSSF badge step ([OpenSSF badge](#openssf-best-practices-badge)), and `cold-install.yml`.
- `community`: a repo that wants outside contributors. The render adds `GOVERNANCE.md`, `docs/roadmap.md`, `docs/assurance-case.md` and `docs/decisions/`, and the `dco` workflow checks every pull request.

A private repo, or a public one without a license, is not on the ladder: copier skips the question.

A requirement applies to every repo, or only to repos with one of its traits. The template derives the traits from your answers:

| Trait | Applies when |
| --- | --- |
| `web` | `ts_kind=web-app`, or a `site` |
| `cli` | A Rust or Go binary, or a Python `data-pipeline` (the computed `cli` answer) |
| `package` | `publish_to_pypi`, `publish_to_npm`, or `rust_kind=library` (a crate for crates.io) |
| `pipeline` | Python `kind=data-pipeline` |
| `numerics` | Python `kind=research` |

The requirements live in [`levels.toml`](https://github.com/simonvanlierde/project-templates/blob/main/levels.toml), and `just levels-doc` writes the table below from it. A repo meets a level when it meets every requirement at that level and below that applies to it. "Counts from" is the date a requirement starts to count. Before then a tool that reads `levels.toml` may list it without counting it, which gives repos time to catch up. The file's version is the newest template release, so a repo can say which version of the ladder it meets.

The table says what a repo must have to count as meeting a level, not only what the render adds: every level also gets the files the template always renders, such as `.github/CONTRIBUTING.md`, the issue forms and the citation files. A fresh render meets each `automated` requirement at its level. The `review` ones need you, and `docs-site` needs `docs_site` in `extras` once its trigger holds.

<!-- levels:start -->
<!-- Generated from levels.toml by `just levels-doc`; edit that file, not this table. -->

Levels version 0.14.0:

| Requirement | Level | Applies to | What it asks | Verified by | Source | Counts from |
| --- | --- | --- | --- | --- | --- | --- |
| `lockfile` | minimal | all | A lockfile is committed beside each root `pyproject.toml` or `package.json`. | automated | OpenSSF Scorecard v5 (Pinned-Dependencies) | 2026-11-11 |
| `dependency-bot` | minimal | all | Dependabot or Renovate opens update pull requests for the repo's dependencies. | automated | OpenSSF Scorecard v5 (Dependency-Update-Tool) | 2026-11-11 |
| `workflow-hardening` | minimal | all | Every workflow sets `permissions:`, checks out with `persist-credentials: false` and has no `pull_request_target` trigger. | automated | OpenSSF Scorecard v5 (Token-Permissions, Dangerous-Workflow); OSPS Baseline v2026.08.28 (BR-01.01) | 2026-11-11 |
| `scorecard-workflow` | minimal | all | The OpenSSF Scorecard workflow runs on the default branch. | automated | OpenSSF Scorecard v5 | 2026-11-11 |
| `security-policy` | minimal | all | `SECURITY.md` says how to report a vulnerability privately and how soon you reply. | automated | OSPS Baseline v2026.08.28 (VM-02.01); OpenSSF Best Practices passing (vulnerability_report_process) | 2026-11-11 |
| `python-repo-review` | standard | all | A repo with a root `pyproject.toml` passes Scientific Python repo-review. | automated | Scientific Python Development Guide (sp-repo-review) | 2026-11-11 |
| `license` | standard | all | `LICENSE` holds an OSI-approved license. | automated | OpenSSF Best Practices passing (floss_license); OSPS Baseline v2026.08.28 (LE-02.01) | 2026-11-11 |
| `community-files` | standard | all | The repo has `CONTRIBUTING.md`, a code of conduct, issue forms and a pull request template. | automated | GitHub community profile; OpenSSF Best Practices passing (contribution) | 2026-11-11 |
| `test-policy` | standard | all | `CONTRIBUTING.md` says that a change comes with tests and names the coding standards. | automated | OpenSSF Best Practices passing (test_policy, coding_standards) | 2026-11-11 |
| `changelog` | standard | all | `CHANGELOG.md` has a section for each release. | automated | Keep a Changelog 1.1.0; OpenSSF Best Practices passing (release_notes) | 2026-11-11 |
| `api-break-check` | standard | package | CI checks each pull request for breaks in the public API (griffe, cargo-semver-checks or API Extractor). | automated | Semantic Versioning 2.0.0 | 2026-11-11 |
| `citation-file` | standard | package, pipeline, numerics | `CITATION.cff` says how to cite the software. | automated | Citation File Format 1.2.0 | 2026-11-11 |
| `codemeta` | standard | package, pipeline, numerics | `codemeta.json` describes the software for archives and registries. | automated | CodeMeta 3.0 | 2026-11-11 |
| `readme` | standard | all | `README.md` says what the project is, its status, and how to run or develop it. | review | OpenSSF Best Practices passing (description_good, interact) | 2026-11-11 |
| `cold-install` | standard | all | A CI workflow runs the README's setup steps in a clean container. | automated | project-templates | 2026-11-11 |
| `docs-structure` | standard | package, cli | `docs/` holds Markdown split into tutorials, how-to guides, reference and explanation, and the reference is generated or tested against the code. | review | Diátaxis | 2026-11-11 |
| `docs-site` | standard | package, cli | When outside users need search or versioned docs, `docs/` builds a search-indexed site from the same Markdown. | review | project-templates | 2026-11-11 |
| `architecture-doc` | standard | all | A repo with 40 or more code files has an architecture page with a diagram, and each path it names exists. | automated | project-templates | 2026-11-11 |
| `accessibility-statement` | standard | web, cli | A web app publishes an accessibility statement and runs an axe scan in CI; a command-line tool has `docs/accessibility.md`. | automated | WCAG 2.2 (Level AA) | 2026-11-11 |
| `web-head-tags` | standard | web | Each page has a canonical link, `og:url`, and an absolute `og:image` that loads, with `og:image:alt`. | automated | The Open Graph protocol | 2026-11-11 |
| `security-headers` | standard | web | The site sends a Content-Security-Policy, and its root sends Strict-Transport-Security. | automated | OWASP Secure Headers Project | 2026-11-11 |
| `security-txt` | standard | web | The site root serves `/.well-known/security.txt` with a `Contact:` line. | automated | RFC 9116 | 2026-11-11 |
| `sitemap-answers` | standard | web | Each sitemap that `robots.txt` names loads. | automated | RFC 9309; Sitemaps protocol 0.9 | 2026-11-11 |
| `ci-tests` | standard | all | A CI workflow runs the repo's test suite on every pull request. | automated | DLR Software Engineering Guidelines v1.0.0 (EST.2, EST.4, EAA.8), doi:10.5281/zenodo.1344612 | 2026-11-11 |
| `dependency-licenses` | standard | all | CI lists each dependency's license and fails when one is incompatible with the repo's license. | automated | DLR guidelines v1.0.0 (EAA.2, EAA.3); GI/de-RSE Muster-Leitlinie 2025 section 3.5, doi:10.18420/2025-gi_de-rse | 2026-11-11 |
| `governance` | community | all | `GOVERNANCE.md` says who decides, who can merge and release, and how the project carries on if a maintainer is gone. | automated | OpenSSF Best Practices silver (governance, roles_responsibilities, access_continuity) | 2026-11-11 |
| `dco` | community | all | Every commit carries a `Signed-off-by:` line, and CI checks each pull request for it. | automated | Developer Certificate of Origin 1.1; OpenSSF Best Practices silver (dco) | 2026-11-11 |
| `roadmap` | community | all | `docs/roadmap.md` says what the project plans for the next year and what it will not do. | automated | OpenSSF Best Practices silver (documentation_roadmap) | 2026-11-11 |
| `roadmap-issue-links` | community | all | Each theme in the roadmap links an open issue, and its "Last reviewed" date is under a year old. | automated | project-templates | 2027-01-01 |
| `assurance-case` | community | all | `docs/assurance-case.md` gives the threat model, the trust boundaries, the secure design principles and the weaknesses countered. | review | OpenSSF Best Practices silver (assurance_case) | 2026-11-11 |
| `decision-records` | community | all | `docs/decisions/` records each choice that is costly to reverse. | review | MADR 4.0.0 | 2026-11-11 |
| `signed-releases` | community | all | Release tags are signed, and the release workflow refuses a tag signed by a key it does not list. | automated | OpenSSF Best Practices silver (signed_releases) | 2026-11-11 |
| `release-build` | community | package | A workflow builds each release package, and the run log and artifacts are kept. | automated | DLR guidelines v1.0.0 (EAA.9, ERM.11) | 2026-11-11 |
| `architecture-review` | community | all | The architecture page is reviewed against the code at least once a year, and the review is dated. | review | DLR guidelines v1.0.0 (ESA.10) | 2026-11-11 |
<!-- levels:end -->

To move a project to another level, run `copier update --data level=community`.

### Decision records

`decision_records` adds `docs/decisions/`: a [MADR 4.0.0](https://adr.github.io/madr/) index and a
first record that says the project starts from this template. It is on for kinds whose choices are
costly to reverse, and off for small tools, which never get an empty folder. The index and the first
record are the project's after the first render.

### Documentation rules

- **Full URLs in package READMEs:** PyPI, npm, and crates.io render the project's `README.md` on their package pages. Relative links break when viewed on registry sites, so links to repository files and directories use absolute GitHub URLs (`https://github.com/<owner>/<repo>/...`). A render with `publish_to_pypi` or `publish_to_npm` writes its README links this way.
- **Stable links to documentation on `main`:** When documentation or CLI error messages link to rules or guides, point to `main`. Rule identifiers are permanent; if a rule is deprecated or removed, keep a stub heading so historical links continue to resolve.
- **Single source of truth:** The README holds the overview and quickstart; code comments and docstrings define API contracts; `docs/` holds extended guides and references.

## Adopting the template in an existing repo

Each guide renders over the repo on a clean branch with `copier copy --overwrite`, then has
you review `git diff` and restore what was yours.

### Adopting the template in an existing Python package

1. On a clean branch, render the template:

   ```sh
   copier copy --vcs-ref=<tag> --overwrite gh:simonvanlierde/project-templates .
   ```

   Enable `customise`, specify `module_name`, and select `python_layout=flat` if code resides at repository root rather than under `src/`.
2. Review `git diff` for `pyproject.toml`. Restore dependencies, authors, and version numbers, then run `just py-sync`.
3. Format with `uv run ruff format`. For existing lint or type check findings, record baseline exceptions rather than disabling rules:
   - Ruff: add existing violation codes to `ignore` in `pyproject.toml` under a `# NOTE: baseline at adoption` comment.
   - ty: configure existing violations as `"warn"` under `[tool.ty.rules]`.
4. If `uv audit` flags patches under a week old, add temporary exemptions under `[tool.uv]` in `pyproject.toml` ([tooling](tooling.md#dependencies)).
5. Remove obsolete workflows, run `just check` and `just hooks`, and commit.
6. Ensure `CHANGELOG.md` contains Keep a Changelog `## [X.Y.Z]` headings for release tagging.

### Adopting the template in an existing web app

1. On a clean branch, render over the repository:

   ```sh
   copier copy --vcs-ref=<tag> --overwrite gh:simonvanlierde/project-templates .
   ```

   Select `ts_kind=web-app`, your framework, and your `user_data` setting.
2. Review `git diff`:
   - Remove unused starter components.
   - Integrate the legal page routes and links into your `src/App.tsx`. Add the paths to `tests/e2e/routes.ts`, and set its `LEGAL_LINKED_FROM` to the routes that link the legal pages.
   - Restore custom configurations in `vite.config.ts` and `vitest.config.ts`. Retain the template's `markdown()` plugin.
   - Restore custom package names in `package.json` and `wrangler.jsonc`.
   - Fill in all TODO markers in `docs/`.
3. Run `pnpm install`. If dependencies are newer than the one-week cooldown, exempt them in `pnpm-workspace.yaml`:

   ```yaml
   minimumReleaseAgeExclude:
     - vite@8.3.5
   ```

4. Move inline scripts from `index.html` into files under `public/` to satisfy `script-src 'self'`.
5. Run `just check` and `just ts-e2e`. Remove legacy workflows replaced by `ts.yml` and commit.

### Adopting the template in an existing Compose-only repo

1. On a clean branch, render over the repo:

   ```sh
   copier copy --vcs-ref=<tag> --overwrite --data 'stacks=[docker]' gh:simonvanlierde/project-templates .
   ```

2. The render keeps an existing `compose.yaml` and `.env.example`, and replaces the justfile.
   `just check` reads `.env.example` in place of `.env`, so give every variable a `${VAR:?}`
   needs there.
3. Move your own recipes into `just/local.just`, which updates never touch. Name the checks
   you add `local-check`: `just check` runs that recipe last.
4. The `docker-compose` entry in `.github/dependabot.yml` reads `compose.yaml` and the
   directories one level below it, where an `include:` usually points. A deeper Compose file
   needs its directory added there. `copier update` keeps that edit unless the template
   changes the same lines, which shows up as a conflict.
5. Run `just check` and `just hooks`. Add the words typos flags in your own files to
   `_typos.toml`, which is yours from then on. Then commit.
