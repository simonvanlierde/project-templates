# Changelog

All notable changes to projects made from this template. Take a release with
`copier update`.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this
project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Before 1.0.0,
a breaking change bumps the minor version and anything else bumps the patch. Breaking
changes are marked **Breaking**.

## [Unreleased]

### Changed

- A web app's privacy and accessibility statements are rewritten in plain language. The privacy page opens with what is stored and whether anything leaves the device, then says how to delete it, and has no legal jargon. The accessibility page drops test file names and CI details. The TODOs ask for facts in the user's words. `copier update` merges the new wording into pages you have already filled in, so expect conflicts there: keep your facts and take the new phrasing where it fits. [docs/web-legal.md](docs/web-legal.md) now says how to write the pages, with an example.

### Fixed

- A web app's markdown plugin now strips HTML comments until none are left. One pass over `<!<!---->---->` left a comment behind. CodeQL flagged the single pass as incomplete sanitization (`js/incomplete-multi-character-sanitization`, high) in every rendered web app.

### Security

- `fair.yml` runs howfairis from a pinned commit instead of its `0.15.0` tag, which can be moved, and resolves howfairis' dependencies only to releases at least a week old.

## [0.12.0] - 2026-10-29

Upgrade steps:

- **Breaking:** in a `library`, `research` or `data-pipeline` project, run `just citation` after the update and commit what it writes. Until you do, the new `citation` hook fails, in CI too. Add `email:` to the authors in `CITATION.cff` first, or `codemeta.json` loses the email it has.
- With `openssf_badge=silver`: from this update on, sign off your own commits too (`git commit -s`, or `git rebase --signoff origin/main` for a branch you already have). Run `prek install` again so the new commit-msg hook is active.
- If your README.md has the three-dot fair-software.eu badge and `fair.yml` scores under five of five, delete the badge line by hand. `copier update` never changes README.md.

### Changed

- New citable public projects no longer get a fair-software.eu badge at three of five dots. Add it once `fair.yml` scores five of five: set `FAIR_MIN: 5` and paste the snippet howfairis prints in the job summary.
- **Breaking** for `openssf_badge=silver`: the `dco` check runs on every pull request, the maintainers' branches included, as the silver badge's DCO criterion asks of every developer. A commit-msg hook refuses an unsigned commit before the push. Commits Dependabot or Renovate write in their own pull requests are exempt; a human commit on a bot's branch is still checked. The commit-msg hook accepts only a full `Signed-off-by: Name <email>` line, as the check does. `just repo-settings` also turns on GitHub's "require contributors to sign off on web-based commits", so a commit made in the web UI, such as "Commit suggestion", passes the check. Below silver, only pull requests from forks are checked, as before.
- The copier-update workflow signs off its commit.
- Pull requests restore the CI caches main saved and save none of their own, in every workflow that caches: uv, Rust, the pnpm store, Go, the git hook environments and trivy's database. GitHub lets only the pull request read a cache it saves, and a repo holds 10 GB of caches before it evicts the oldest, so those caches pushed out main's and new pull requests built cold. The `pr title` workflow, which runs on pull requests only, no longer caches uv.
- `codemeta.json` declares CodeMeta 3.0 instead of 4.0, because Software Heritage's indexer reads only 2.0 and 3.0 and skipped the file. The fields are the same in both.
- JSON files are checked by [jsonvet](https://github.com/simonvanlierde/jsonvet) 3.2.0, the new name of check-json5, in every project, not only TypeScript ones: `.vscode/` and `.github/rulesets/` JSON ship with every stack. It reads `.json` files as JSON5, so comments and trailing commas still pass, and fails on syntax errors and duplicate keys.

### Fixed

- The generated README had two blank lines before "Before the first release" (or before "License" in a project that publishes nothing), so the Markdown linter rewrote it on the first commit.
- `fair.yml` called GitHub's API anonymously, so on a runner whose IP had used up its 60 requests an hour, howfairis scored checks as missing without an error. It now passes the job's token as `APIKEY_GITHUB`.
- `fair.yml` scored the checklist as missing on every repo with an OpenSSF Best Practices badge, because the howfairis on PyPI (0.14.2) predates the `www.bestpractices.dev` badge URL. It now runs howfairis 0.15.0 from its GitHub tag, which reads that URL; PyPI has no 0.15.0 yet.
- `biome check` failed on every new TypeScript project with biome 2.6, which formats Markdown and YAML too. `biome.json` now leaves those files to rumdl and yamlfmt.
- `just repo-settings` in a public Renovate repo stopped with a bare "Validation Failed" when the Renovate app was not installed yet, because GitHub refuses an app it can't see as a bypass actor. It now shows GitHub's reason and says to install the app first.

### Added

- `just citation` writes `.zenodo.json` and `codemeta.json` from `CITATION.cff`, so you edit one file instead of three: title, description, authors with their ORCID iD, email and affiliation, licence and repository into both, and version, release date and DOI into `codemeta.json` only. Zenodo takes the version and date from the release, and would take a DOI for the release's own and mint none. Other top-level fields you add to the JSON files stay; the author lists are rewritten whole. A name particle such as `van` is kept in front of the family name. A git hook, which CI also runs, fails while the files disagree, and `just citation --check` runs the same check by hand.
- [docs/usage.md](docs/usage.md#making-a-repo-public) has a checklist for making a private repo public: a secret scan over the full history, the name on PyPI, crates.io and npm, a clean issue list and the README status sentence.
- A Rust or Go `binary` and a Python `data-pipeline` get `docs/accessibility.md`: how the program prints (colour is never the only signal, `NO_COLOR` and `--color never` are honoured, plain output off a terminal, errors as `file:line:col` on standard error) and the author's email for problems. Check each claim holds for your program before you publish it. An existing project gets the file on `copier update` and keeps its own edits after that.
- A public repo's `CONTRIBUTING.md` has a "Scope and response" section: one maintainer, a reply within about two weeks, an issue before a large pull request, and out-of-scope pull requests closed with a link to it.
- A new `status` question (`experimental`, the default, `stable`, `maintenance` or `archived`, under `customise`) puts one status sentence under the README's badges. A public repo's README also says where questions and bugs go. An existing project's README is its own, so `copier update` adds neither: copy them from a fresh render.
- A public repo gets issue forms in `.github/ISSUE_TEMPLATE/`: one for bugs and one for feature requests. Blank issues are turned off, and a link sends questions to `CONTRIBUTING.md`. Vulnerabilities go to private reporting, as before. A private repo gets none.
- The template itself has a Zenodo DOI, [10.5281/zenodo.23701980](https://doi.org/10.5281/zenodo.23701980), which always points to the newest release. `CITATION.cff` and the README carry it.

## [0.11.0] - 2026-10-27

Upgrade steps:

- With `publish_to_pypi`: push the version tag and approve `pypi`; let `python-release.yml`
  create the GitHub release. It replaces `release.yml` and attaches the distributions
  and their provenance before publishing. Do not create the GitHub release by hand.
  If PyPI succeeds but the release job fails, delete any leftover draft and re-run
  only the `release` job ([recovery steps](docs/usage.md#publishing)).
- **Breaking:** install Copier 9.19 or later (`uv tool upgrade copier`) before you run
  `copier update`. Renovate's copier manager installs the latest Copier.
- **Breaking:** a web app made from an untagged main asks the new `user_data` question,
  which has no default, so `copier update --defaults` stops on it. Answer it, or pass it:
  `copier update --data user_data=nothing` (or `browser`, or `accounts`). Then add the
  footer and the page routing from a fresh render's `src/App.tsx` to yours, and
  `/accessibility` and `/privacy` (and `/terms`) to `tests/e2e/routes.ts`: an update
  leaves both files alone. Fill in the TODOs in `docs/`. An app on its own domain: pass
  `--data site_url=https://<your domain>`, or the pages name the `pages.dev` address.
  The weekly copier-update workflow fails until you have run this update by hand once.
- **Breaking:** a private repo: pass `--data public=false`. The new `public` question
  is yes by default, so `copier update --defaults`, Renovate's update PR and the
  `copier-update` workflow add the public-repo files, including a `scorecard.yml` that
  fails in a private repo. With no, `.github/SECURITY.md`, `CONTRIBUTING.md`,
  `CODE_OF_CONDUCT.md`, `pull_request_template.md`, `dco.yml` and `scorecard.yml` go.
  Your license answer stays as it is.
- A public repo: the update adds `.github/CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`,
  `pull_request_template.md` and a `dco` check on pull requests from forks,
  and `SECURITY.md` gains a Scope section to fill in. GitHub shows `.github/CONTRIBUTING.md`
  before a root `CONTRIBUTING.md`, so if you have your own, keep one and delete the other.
- With `dependency_bot=dependabot`: create a fine-grained token with read and write access
  to Contents, Pull requests and Workflows on the repo, and store it as the
  `COPIER_UPDATE_TOKEN` secret. Without it, the new weekly `copier-update` workflow opens
  an issue instead of a PR for an update that changes a workflow
  ([Hearing about new releases](docs/usage.md#hearing-about-new-releases)).
- `README.md`, `CHANGELOG.md` and the citation files (`CITATION.cff`, `.zenodo.json`,
  `codemeta.json`) are now your project's, and this update already leaves them alone. So
  this release's README changes don't arrive, such as the badges for the options you
  turned on and the Releasing section. Diff your README against a fresh render with your
  answers and copy the parts you want.
- **Breaking:** if a ruleset or branch protection requires the `lint, types, tests` check
  (`lint, types, pipeline, tests` in a `data-pipeline` project), switch it to the new
  name: `python: lint, types, tests` (`python: lint, types, pipeline, tests`) or
  `ts: lint, types, tests`. A library runs one per Python version, named
  `python: lint, types, tests (3.12)` and so on. Until then, pull requests wait on a
  check that never reports.
- Run `just repo-settings` once after the update, and in a new project after the first
  push. It protects `main` and the `v*` tags and, in a public repo, turns on private
  vulnerability reporting, which `SECURITY.md` points to. `main` then requires the `git hooks`,
  `pull request title`, `dependency review` and, in a public repo, `DCO sign-off` checks: if
  you renamed any of those jobs, edit `.github/rulesets/main.json` first (in a public repo,
  `main-checks.json`), or pull requests wait on a check that never reports. In a public
  repo, `main` also requires an approval from now on; as the repo admin you can merge your
  own pull requests by ticking the bypass box in the merge box.
- Run `prek install` again in each clone, so the new commit-msg hook is installed.
- The new `typos` and `lychee` hooks run on every file in CI's git hooks job. After the
  update, run `prek run --all-files typos lychee`, review what typos fixed, and fix the
  dead links lychee lists, or that job fails.
- After the update, refresh the lockfiles for your stacks and commit them: `uv lock`,
  `pnpm install`, `just go-sync`. This release bumps dev tools in every stack, and CI
  installs with `--locked` and `--frozen-lockfile`.
- A TypeScript library with `publish_to_npm`: after the update, run `just ts-api` and
  commit `<package>.api.md`. The template's copy describes the sample `add` function, not
  your exports, so CI fails until you do.
- With `dependency_bot=renovate`: turn Dependabot security updates off
  (`gh api -X DELETE repos/OWNER/REPO/automated-security-fixes`), or each security fix
  arrives as two PRs. Keep Dependabot alerts on: Renovate's security PRs need them.
- **Breaking:** in a Go library made with v0.10.0 or earlier, `copier update` deletes
  `<package>_test.go` without asking, your changes to it included, and adds
  `add_test.go`. Before you commit the update, run `git checkout HEAD -- <package>_test.go`
  (after committing it, `git checkout HEAD~1 -- <package>_test.go`). Then delete
  `add_test.go`, or the two `TestAdd` functions stop the tests compiling. With
  `test_extras=[property]`, first copy `FuzzAdd` from `add_test.go` into your test file.
- In a Python or TypeScript library, the new sample `add` function arrives as a conflict
  in `src/<module>/__init__.py` or `src/index.ts`: keep your own side. Then delete
  `tests/test_add.py`, and the `add` import and test the update merged into
  `src/index.test.ts`, or those tests fail.
- In a `data-pipeline` project (see the two Breaking changes below):
  - `src/<module>/pipeline.py` becomes a short file that imports sourceledger. If you
    added readers to `parse`, keep only your own branches, end it with
    `return sourceledger.parse_source(source, payload)`, and keep the imports your
    branches need: the new file no longer imports `csv` or `io`.
  - Take the new `tests/test_pipeline.py`, and keep any tests of your own readers.
  - `pyproject.toml` gains the `sourceledger` dependency. Keep any dependencies of your
    own next to it, where `copier update` can't merge the two lists.
  - In `sources.toml`, rename `release` to `vintage` (the old key still works, with a
    warning). Give each implemented source a `license` (an SPDX id, or
    `LicenseRef-<name>`) and `redistribute = true` or `false`. Rename any source id with
    a non-ASCII letter: only ASCII letters, digits, `_` and `-` are accepted.
  - Run `just pipeline`. `just validate` reports a missing `datapackage.json` until
    `just build` has written one.
- **Breaking:** `python-release.yml` and `ts-release.yml` now run when a `vX.Y.Z` tag is
  pushed, not when a GitHub release is published. Add the `## [X.Y.Z]` section to
  `CHANGELOG.md` before you tag. The release workflow reads that section and fails
  when it is missing. Releases created by `GITHUB_TOKEN` don't start other
  workflows, so the publish workflows could not follow the release.

### Added

- Weekly Go property runs cache generated fuzz inputs so each run resumes the
  coverage the previous runs found.
- Copier and howfairis workflow pins follow template updates. Renovate tracks their
  versions in the template, so they no longer need separate manual bumps.
- The code of conduct tells readers that a report about the maintainer can go to GitHub
  instead, through Report abuse.
- An `openssf_badge` question, asked in a public repo with a license, for the
  [OpenSSF Best Practices badge](https://www.bestpractices.dev). `passing` adds a test
  policy and each stack's coding standards to `.github/CONTRIBUTING.md`. `silver` also
  adds `GOVERNANCE.md`, `docs/roadmap.md` and `docs/assurance-case.md`, short skeletons
  you fill in and then own. It defaults to `none`, so an update changes nothing unless
  you pass `--data openssf_badge=passing` (or `silver`).
- A `cold-install.yml` workflow runs the shell blocks under the README's `## Development`
  heading as written, in a Debian container with only the tools the README says you
  need, so a setup step the README leaves out fails in CI. It runs weekly and on pull
  requests that change `README.md`. It skips `just up`, `just pipeline`, `just ts-e2e`
  and the mutation and property recipes, which need Docker, a browser, live sources or hours.
  Your README stays yours on `copier update`, so the job runs whatever it says now.
- Spelling and link checks. A `typos` git hook finds misspelt words and a `lychee` hook
  finds relative links to missing files in Markdown and HTML. The lychee hook runs
  offline, so a new weekly `links.yml` workflow checks the web links too. List a word
  typos must leave alone in `_typos.toml` ([Spelling and link checks](docs/usage.md#spelling-and-link-checks)).
- A short `AGENTS.md` in every project, for coding agents: the `just check` command, each
  stack's test recipe and where the docs are. It names only recipes the project's
  `justfile` has.
- Commit message rules in `committed.toml`: Conventional Commits, an imperative summary,
  no period. A `committed` commit-msg hook checks each commit, skipping merge
  commits, and a new `pr-title.yml` workflow checks the pull request title, which a squash
  merge turns into the commit subject. Dependabot and Renovate now write PR titles in the
  same form, `chore(deps): ...`.
- GPL-3.0-or-later and AGPL-3.0-or-later as `license` answers, with
  the GNU texts in `LICENSE`. These texts have no copyright line, so they don't ask
  `copyright_year`.
- A `python_layout` question under `customise`, `src` by default. `flat` is for adopting
  the template in a repo whose package already sits at the root: it renders no
  `src/<module>` stub or `tests/test_add.py`, and sets `module-root = ""` for uv_build.
  [Adopting the template in an existing Python package](docs/usage.md#adopting-the-template-in-an-existing-python-package)
  covers the rest, including a ruff and ty baseline for code written without them.
- A `docs/decisions/` folder in every project, for recording why you chose what you
  did. It holds a short record template, `0000-template.md` (status, date, context,
  decision, consequences), and an index, `README.md`. The index is yours once written,
  so `copier update` leaves it alone.
- README badges for the options you turn on: Codecov coverage (`codecov`), CodSpeed
  (`codspeed`), PyPI version and supported Python versions (`publish_to_pypi`), npm version
  (`publish_to_npm`) and OpenSSF Scorecard (`public`).
- A weekly dependency audit, `advisories.yml`, on every Monday with a job per stack:
  `uv audit`, `pnpm audit`, `cargo deny check advisories` and `govulncheck`. Before, a repo
  with no new commits never heard of a new advisory. A failed run shows on the Actions page
  and in the failed-run email.
- With `public`, an OpenSSF Scorecard workflow (`scorecard.yml`): it runs on pushes to
  main, weekly and when branch protection changes, publishes the score for the README
  badge and uploads the findings to code scanning. A private repo gets none. After the
  update, the first run on main publishes the score.
- The release workflows and `.github/scripts/release-notes.sh`: a pushed `vX.Y.Z` tag becomes a
  GitHub release whose notes are that version's `CHANGELOG.md` section, so the two never
  differ.
- `just repo-settings` protects the default branch with a GitHub ruleset (no deletion, no force-push, linear history, PRs squash-merged once the checks every PR runs have passed) from `.github/rulesets/main.json`, lets only a repo admin create, move or delete a `v*` tag (`.github/rulesets/tags.json`), since pushing one publishes a release, and in a public repo turns on private vulnerability reporting, which `SECURITY.md` points to. Rerun it any time; it updates the ruleset instead of adding a second.
- `just repo-about` sets the GitHub About box from your answers with `gh repo edit`: the description from `project_description` (skipped when empty), the homepage from `site_url` in a web app, and a topic per stack. It only adds topics, so ones you set by hand stay. Rerun it any time.
- With `mutation` in `test_extras`, a weekly CI run of mutation testing:
  `.github/workflows/mutation.yml`, one job per library stack, also startable by hand
  and never run on a pull request. Each job runs the stack's `just <stack>-mutation`
  recipe. The Rust job fails when a mutant survives; the others print the survivors and
  pass.
- With `property` in `test_extras`, a weekly CI run of the property tests at length:
  `.github/workflows/property.yml`, one job per library stack, also startable by hand
  and never run on a pull request. Each job runs a new recipe you can also run by hand:
  `just py-property` (Hypothesis, 10,000 examples a property), `just ts-property`
  (fast-check, 10,000 runs), `just rs-property` (proptest, 10,000 cases) or
  `just go-property` (fuzzes `FuzzAdd` for 10 minutes). A failing input fails the job. A Python
  library gains `tests/conftest.py`, which registers the Hypothesis profile.
- A `public` question, yes by default. No leaves out `.github/SECURITY.md`,
  `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `pull_request_template.md` and `dco.yml`, and makes
  `none` the license default. See [Public repos](docs/usage.md#public-repos).
- `CONTRIBUTING.md` says where to report a bug, states the commit, pull request and
  changelog conventions, asks for a DCO sign-off on every commit and says who maintains the
  project. `CODE_OF_CONDUCT.md` is the Contributor Covenant 3.0, with the author email as
  the contact. A `dco.yml` workflow fails a pull request from a fork with a commit that isn't signed off.
- `SECURITY.md` says what to include in a report, promises an answer within 14 days, says
  how a fix is disclosed, and has a scope section to fill in.
- A `customise` question, no by default, ahead of the advanced questions: license,
  directories, versions, module names, Codecov, CodSpeed, the dependency bot,
  publishing, test extras, the port and the site URL. A new Python library, TypeScript web app or data pipeline now
  asks 10 questions, or 11 for a web app, down from 18, 14 and 15. Every question says what it changes.
  [The questions](docs/usage.md#the-questions) lists them with their defaults.
- `copier copy` says where your details can be saved before it asks, and lists the
  `just` commands to run after it.
- A `codspeed` option for the Python and Rust stacks: a `benchmarks.yml` workflow runs
  benchmarks on CodSpeed for every pull request and every push to main, with a starter
  benchmark per stack (`pytest-codspeed`, and divan through `codspeed-divan-compat`). Import
  the repository on codspeed.io and set Pull Request comments to "On Change" there; see
  [usage](docs/usage.md#benchmarks-on-codspeed).
- A `web-app` TypeScript kind: a Vite single-page app with React or Preact (the new
  `web_framework` question), deployed by Cloudflare Pages' Git integration. The docker
  stack builds no image for it, since it is static files.
  - Playwright specs run against the production build, in `ts.yml`'s `e2e` job and with
    `just ts-e2e`. They check every route with axe in light and dark mode (WCAG 2.2 AA
    and axe's best-practice rules) and at 320 px wide (reflow), and check that the app
    runs under the Content-Security-Policy in `public/_headers`, which allows no inline
    script. Removing any security header from that file fails the check.
  - `just check` and CI enforce a bundle budget, set in `scripts/checkBundleBudget.mjs`,
    and a pre-push hook runs the unit tests.
  - The e2e run always starts its own preview server, on port 4173, and fails if the
    port is taken, so it can't test another app's server instead.
  - [Adopting the template in an existing web app](docs/usage.md#adopting-the-template-in-an-existing-web-app)
    lists the files a first `copier copy --overwrite` adds or replaces, and how to
    install a lockfile resolved before the one-week release wait.
  - The starter files (`src/App.tsx`, `src/App.test.tsx`, `src/main.tsx`, `src/app.css`,
    `index.html` and `tests/e2e/routes.ts`) belong to the project once written:
    `copier update` never touches them again.
- A `test_extras` question for the library kinds, empty by default. `property` adds a
  property test of the sample `add` function: Hypothesis, fast-check, proptest, or a
  native Go `FuzzAdd`. `mutation` adds a `just <stack>-mutation` recipe to run by hand:
  mutmut, Stryker, cargo-mutants or gremlins. See [Test extras](docs/usage.md#test-extras).
  Python and TypeScript libraries now ship the sample `add`, as Rust and Go already did.
- With the `docker` stack, `docker.yml` scans each built image with Trivy for HIGH and
  CRITICAL vulnerabilities that have a fix, and rebuilds and scans the image every Monday
  without pushing it. Pull requests and pushes show the findings in the job log; only the
  weekly run fails on them. The job that pushes to GHCR runs no scan, so it reads no
  cache on a tag.
- In a `data-pipeline` project:
  - `data/fetches.jsonl` is committed and gets a line each time a source serves bytes it
    has not served before: the history of every version, as checksums, not values.
  - The weekly CI run comments on an open "Source data revised upstream" issue when a
    source in that file serves new bytes, with the old and new checksums. Only that job
    may write issues. `uv run <slug> revisions <older log>` prints the same list locally.
  - `just status` lists every source with its vintage, last fetch and licence, and
    `just attribution` prints the sources and their reuse terms as a Markdown table for
    `ATTRIBUTION.md`.
- `just fmt` runs each stack's fix-and-format recipe, the counterpart of `just check`.
- Dependabot groups npm security updates into one pull request instead of one per
  advisory.
- VS Code formats `.tsx`, `.jsx` and `.css` files with Biome, and the Biome hook also
  checks HTML.
- The README says how to lock a security fix that is less than a week old, which
  `exclude-newer` and `minimumReleaseAge` otherwise hold back.
- API-break checks for libraries that publish. With `publish_to_pypi`, a new `api` job
  in `python.yml` runs griffe, which fails when a public function, class or argument was
  removed or changed since the last git tag, and passes while there is no tag. It stays
  out of `just py-check`, so a deliberate break leaves local checks green. With `publish_to_npm`, `ts.yml` and `just ts-check` run API Extractor, which
  fails when the built types differ from the committed `<package>.api.md`. `just ts-api`
  rewrites that report after a deliberate change, so the change shows in review.
- A `web-app` has legal pages, linked from every page's footer: an accessibility
  statement at `/accessibility`, a privacy statement at `/privacy` and, with
  `user_data=accounts`, terms of use at `/terms`. Each is one Markdown file in `docs/`:
  GitHub shows it, and the build turns it into HTML. Its HTML comments are notes for you,
  and the build leaves them out. New e2e tests fail when a page still
  holds a TODO, when the statement says "fully conformant" or goes 400 days without a
  review, and when a first visit sets a cookie, stores anything in the browser or loads a
  file from another site. [`docs/web-legal.md`](https://github.com/simonvanlierde/project-templates/blob/main/docs/web-legal.md) in the template repository has tips for
  filling the pages in, linked from each page's notes ([Legal pages](docs/usage.md#legal-pages)).
- A `web-app` gets `docs/accessibility-assessment.md` beside the accessibility statement: a
  WCAG 2.2 self-assessment with one row for each of the 55 level A and AA criteria, and a
  result and an evidence column to fill in. The app does not serve it. The statement links
  it, and may say "partially conformant" only once every row has a result. An update
  leaves your copy alone.
- A public repo of a kind that has `CITATION.cff` (library, research, data-pipeline) gets
  `fair.yml`, which runs `howfairis` weekly and lists each fair-software.eu check in the job
  summary, and a fair-software.eu badge in the README. The job fails below `FAIR_MIN` filled
  dots out of five. A new repo has three, so that is the starting floor: raise it as you
  add a registry entry and the OpenSSF Best Practices badge, and edit the badge to match.
- With `dependency_bot: dependabot`, a `copier-update` workflow opens a weekly PR that
  runs `copier update` to the newest template tag, with conflicted files listed in the
  PR body. It pushes with a `COPIER_UPDATE_TOKEN` secret, a fine-grained token you create.
  Without one it uses `GITHUB_TOKEN`, which GitHub stops from pushing workflow changes, so
  such an update opens an issue asking you to run it locally, and other update PRs start
  no CI. See
  [Hearing about new releases](docs/usage.md#hearing-about-new-releases).

### Changed

- A public repo's `main` ruleset requires one approving review, given after the last push,
  and a new push dismisses an earlier one. That lifts Scorecard's branch protection score
  from at most 4 to 8. A repo admin can bypass the review from the merge box. The required
  checks move to a second ruleset, `main-checks`, which only an admin can bypass, so a
  bypass of the review still waits for them. Rerun `just repo-settings` after the update to
  apply both. A private repo's ruleset is unchanged.
- With `dependency_bot=renovate`, Renovate merges its own minor and patch updates of the
  packages CI installs, and the weekly relock, once their checks pass. Its app may bypass
  the review in a public repo, never the checks. Majors, copier template releases, and the
  actions and hooks group still wait for you. Dependabot PRs still never merge themselves.
- A web app with `user_data=accounts` refuses `code@duinlab.nl` as `author_email`: an app
  that keeps personal data on a server needs its own contact address. Pass another
  address to `copier update` if you hit this.
- `copier copy` keeps an existing `README.md`, and `copier update` no longer touches it.
  Template changes to the README, this release's included, reach existing projects only
  by hand.
- A ty rule set to `"warn"` reports without failing `ty check`, the hook and
  `just py-check`. ty exits 1 on warnings by default; `pyproject.toml` now sets
  `[tool.ty.terminal] error-on-warning = false`.
- In a Python project, the git hooks skip `data/`, so the whitespace, end-of-file and
  nbstripout hooks no longer rewrite input data and archived notebooks.
- `pnpm audit --fix=update` locks a security fix that is under a week old: it adds the
  patched version to `minimumReleaseAgeExclude`, and the new
  `minimumReleaseAgeExcludePrune` drops the entry once the lockfile moves past it.
- With `dependency_bot=renovate`, Renovate refreshes the lockfiles every Monday. That is
  how a security fix in a dependency of a dependency arrives, once it is a week old.
- **Breaking:** the TypeScript and Python check jobs are now `ts: lint, types, tests` and
  `python: lint, types, tests` (`python: lint, types, pipeline, tests` in a
  `data-pipeline` project). Both used to be `lint, types, tests`, so a ruleset could not
  require one without the other. A ruleset that requires the old name needs the new one
  (see the upgrade steps).
- With the `codecov` option, `just check` runs the TypeScript tests with coverage, as CI
  does, so a coverage threshold in the Vitest config fails locally as well as in CI.
- Dependabot and Renovate group minor and patch bumps of runtime dependencies into one
  weekly PR, instead of one PR each. A major still gets its own PR.
- GitHub Actions and pre-commit hook updates arrive as one weekly PR, instead of one
  each: a Dependabot multi-ecosystem group, and one Renovate group. Fewer PRs means fewer
  branches to bring up to date in turn where main requires it.
- With the `codecov` option, Codecov no longer comments on pull requests. Any line left
  untested drew a comment. A drop of over 2 points still fails the `codecov/project`
  check, which links to the report.
- **Breaking:** a `data-pipeline` project gets its fetch, build, validate and revisions
  stages from the [sourceledger](https://github.com/simonvanlierde/sourceledger)
  package instead of about 400 copied lines in `pipeline.py`. Fixes now arrive as a
  dependency bump, not a `copier update` merge. `pipeline.py` keeps only `parse`.
  - `parse` reads CSV, JSON and Excel sources, gzipped or not, by each source's `format`
    or its URL's extension. `just build` also writes a `datapackage.json`.
  - A fetch asks the server whether the file changed (`If-None-Match`,
    `If-Modified-Since`) and keeps the record on a 304, unless the raw file was edited or
    no longer matches its pinned `sha256`. It waits at most 2 minutes for a
    429's `Retry-After`, and a fetch that fails after its retries names the source and
    its URL.
  - The manifest names the edition `vintage`, as the fetch record and the output column
    already did. `sources.toml` has a schema line for editors, pinned to sourceledger
    v0.2.0, and its comments cover every key. The example source is pinned to a
    datasets/co2-ppm commit, so CI and the tripwire tests no longer follow a moving
    branch.
- **Breaking:** `just validate` in a `data-pipeline` project needs each implemented source
  to state `license` (an SPDX id) and `redistribute` (whether the raw file may be
  republished), beside `terms`. The free-text terms stay for people; these two are for a
  release step to check.
- `go.mod` is written once and then belongs to the project, like `CHANGELOG.md`. Before,
  every `copier update` conflicted with what `go mod tidy` had written there. To raise the
  minimum Go version, run `go mod edit -go=<version>`.
- `copier update` no longer touches `CITATION.cff`, `.zenodo.json` or `codemeta.json` once
  they exist, so a release that adds its version, date or DOI to them no longer conflicts
  with every update. Template changes to these files, this release's included, reach
  existing projects only by hand.
- Web-service projects test with `httpx2`, which Starlette's test client now prefers,
  instead of `httpx`, and require Starlette 1.2.0 or later. The pytest filter that hid
  Starlette's deprecation warning is gone.
- A new Python release becomes the default `python_version` 90 days after it comes out,
  once the packages projects install have wheels for it.
- The generated README lists the tools the project needs (uv only where it's used), puts
  `just hooks` next to `just check`, says that `just check` doesn't build the Docker
  image, and, with a publish option, has a Releasing section on setting up the publishing
  environment first.
- The workflow linter hook runs jactionlint, a maintained fork of actionlint. It adds
  checks for releases, caches and concurrency, so a workflow you wrote yourself may get new
  findings.
- A library's release workflow runs its wheel tests with the test tools from `uv.lock`,
  hash-checked, and turns on uv's malware check as `python.yml` does.
- `python-release.yml` and `ts-release.yml` run one release per tag at a time.
- The docker workflow cancels a superseded run only on a pull request, so a push to `main`
  or a tag is never stopped halfway through pushing an image. A tag build doesn't restore
  the shared build cache, so a poisoned cache entry can't reach a release image; release
  builds take longer as a result. When every image builds from a subdirectory, the
  workflow runs only when a build context or the workflow changes, so a required build
  check stays pending on a pull request that touches neither.
- The Docker image of a `data-pipeline` project is documented as a stub: it has no
  `sources.toml` or `data/`, and it starts the `/health` placeholder.
- Python projects accept `uv_build` 0.13 as their build backend. The 0.12.19 floor stays,
  so older uv versions still build them.
- With `dependency_bot: renovate`, Renovate's copier manager opens a PR for each new
  template release. Before, the one-week release age held those PRs back for good, because
  template tags carry no release date. The docs say how Dependabot users hear about
  releases.

### Fixed

- The typos hook skips `.copier-answers.yml`. The template commit id Copier writes there
  could spell a word typos rejects and fail the hook after a `copier update`.
- A project description with `"""`, `*/` or a line break is refused. It
  broke the Python docstring or the Go and TypeScript comments it lands in.
- With `dependency_bot: renovate`, the comments in `pyproject.toml`, `pnpm-workspace.yaml`
  and `.pre-commit-config.yaml` no longer say Dependabot waits the week or moves the hook
  SHAs.
- The README of a TypeScript project names Node.js among the tools you need.
- The weekly scheduled run and a push to `main` no longer cancel each other in
  `python.yml` and `docker.yml`. A cancelled weekly run used to skip that week's tripwire
  tests in a `data-pipeline` project.
- Copier refuses answers that rendered a broken project: a project name that is a Go,
  Rust or Python keyword (such as `type`, `gen` or `lambda`), an empty `stacks` list, an
  empty `*_dir`, a `rust_version` below 1.85 (the template uses edition 2024), and an
  `app_port` outside 1 to 65535, or 65535 when two images publish ports. A Go binary no
  longer needs a project name that can be a Go package name.
- The `check-yaml` hook no longer fails on `pnpm-lock.yaml`. pnpm 12 writes its own
  version into the lockfile as a second YAML document, so every TS project failed its
  `checks` workflow once the lockfile was committed.
- A name or email with a quote in it, such as `Ada "X" Lovelace`, no longer breaks the
  generated `pyproject.toml`, `package.json` or `Cargo.toml`. A leading space in the
  author name no longer leaves the given name empty in the citation files.
- The `ts` and stdlib Python starter servers in the Docker image stop on SIGTERM. As PID 1
  they ignored it, so `docker stop` waited 10 seconds and then killed them.
- A Go library named `example` no longer loses its `TestAdd`: the unit test is now
  `add_test.go`, which can't share a path with `example_test.go`.
- The image `.dockerignore` files match `.env`, `.venv` and `node_modules` in any
  directory, so another stack's secrets stay out of the build context when a package sits
  at the repo root.
- `.gitignore` names a Go binary without a trailing major version, as `go build` does for
  a module path ending in `/v2`.
- With a Rust crate below the repo root, `.vscode/settings.json` sets
  `rust-analyzer.linkedProjects`, so the editor finds a crate two levels deep.

### Security

- The weekly Copier updater renders in a read-only job. A fresh job applies only
  the patch before pushing, so Copier's dependencies cannot alter the runner that
  holds the update token.
- With `publish_to_ghcr`, the image push job runs in a `ghcr` environment, as PyPI and npm
  releases already do. Limit it to `main` and `v*` tags with a required reviewer in the
  repository's settings (see the README's Releasing section); until then GitHub creates it
  unprotected and pushes as before.
- A library's PyPI release signs a GitHub build-provenance attestation for each file in
  `dist/`, so users can check where a wheel was built with `gh attestation verify`. It is
  made in the publish job, which runs no project code.
- The hooks job installs a set prek version, 0.5.5, instead of the newest one on each run,
  and gives the read-only GitHub token to the zizmor hook only.

## [0.10.0] - 2026-10-16

### Added

- A `dependency_bot` question: Dependabot (the default, as before) or Renovate. Renovate
  gets a `renovate.json5` with the same rules as the Dependabot config: weekly, a one-week
  cooldown, grouped actions, hooks and dev tooling, and no updates to the copier-owned
  `FROM` tags. It needs the Renovate GitHub App on the repository. Existing projects keep
  Dependabot unless they answer `renovate` on the next `copier update`.
- A `data-pipeline` source can set `max_bytes` in `sources.toml` to accept a download
  over the 200 MiB default cap.
- A `data-pipeline` fetch retries a server error, a 429 (waiting at least its
  `Retry-After`), a network error or a body shorter than its `Content-Length`, up to
  four attempts with 5, 10 and 20 s between them. A brief publisher outage no longer
  fails CI. Any other 4xx still fails at once.
- Fetch records also hold the server's `last_modified` and `etag`, empty when it sends
  none. Records written before keep working.

### Changed

- With the `codecov` option, Codecov comments only when a pull request adds lines no test
  runs. It used to comment on any drop in total coverage, however small, although the
  docs said it waited for the 2-point threshold. A drop of over 2 points still fails the
  pull request's Codecov check.

### Fixed

- With both the Python and TS stacks and the `codecov` option, a pull request no longer
  gets a false coverage drop, with its comment, while the second stack's report is
  still on its way. `codecov.yml` now carries each stack's last numbers forward.
- A `data-pipeline` project's `pyproject.toml` no longer explains its packaging as if
  it were a research project with notebooks.

## [0.9.1] - 2026-10-13

### Fixed

- The README's licence badge now shows a hyphenated licence such as BSD-3-Clause.
  Before, shields.io read each hyphen as a field separator, so the badge broke.
- The Apache-2.0 and BSD-3-Clause LICENSE files now end in one newline, not two, so the
  end-of-file-fixer hook no longer rewrites LICENSE on its first run in a new project.

## [0.9.0] - 2026-10-13

### Added

- A `codecov` option for the Python and TS stacks: CI uploads test coverage to Codecov,
  and a `codecov.yml` fails a pull request only when total coverage drops by more than
  2 points. Codecov comments only then. It needs a `CODECOV_TOKEN` repository secret
  (see the README).

## [0.8.1] - 2026-10-13

### Fixed

- The dependency review job is skipped in private repositories. GitHub supports it
  there only with Advanced Security, so it failed every pull request.

## [0.8.0] - 2026-10-13

Upgrade steps:

- `copier copy --defaults` now stops at the GitHub user, author name and email, which
  have no defaults any more. Pass them with `--data`, or save them once under
  `defaults:` in Copier's settings file (see the README). `copier update` keeps the
  answers you already gave.
- A `library` project is asked for `python_min`. Its `requires-python` drops to that
  version and CI tests every version from there up, so check the code still runs on
  the oldest one. If you added a dependency, `copier update` can't merge the new
  `requires-python` next to it: take the new floor and keep your `dependencies`.
- In a `data-pipeline` project, re-run `just pipeline` after updating (see the
  Breaking change below).

### Added

- The `library` kind gets a `CITATION.cff`, like `research` and `data-pipeline`.
- `library`, `research` and `data-pipeline` projects also get `.zenodo.json`, which
  Zenodo reads when it archives a release, and a CodeMeta 4.0 `codemeta.json`.
- A `library` project tests every Python from `python_min` to `python_version` in CI.
  `python_min` defaults to two minors below `python_version`, after SPEC 0.
- A `data-pipeline` source can pin a `sha256`. `fetch` refuses a download that
  doesn't match it.

### Changed

- **Breaking:** the GitHub user, author name, author email and ORCID iD have no
  defaults. They used to default to the template author's details, which a
  `--defaults` run published in the new project.
- The copyright year defaults to the current year instead of a fixed one.
- The generated README installs golangci-lint with `go install`, which checks the
  download against the Go checksum database, instead of piping a script into `sh`.
- **Breaking:** `data-pipeline` drops the `vintage_basis` column and the per-source
  `encoding` key. The vintage is the manifest's `release`, and every source is read
  as UTF-8. Re-run `just pipeline` after updating.
- `data-pipeline` rejects a row with fewer fields than the header, and an id repeated
  in a different case is no longer an error.
- The web-service's `/docs`, `/redoc` and `/openapi.json` are off unless `API_DOCS` is
  set.
- VS Code formats TOML with the Tombi extension (`tombi-toml.tombi`), which reads the
  shipped `.tombi.toml`. Even Better TOML ignored it. Install the new recommendation
  after updating.
- CI no longer runs on draft pull requests; it runs when a pull request is marked ready
  for review. This saves Actions minutes on private repositories.
- Plainer wording in the generated `README.md`, `data/README.md` and `ATTRIBUTION.md`.

### Removed

- `workflow_dispatch` from the release workflows: a manual run could publish any
  branch.

### Security

- The Python workflow sets `UV_MALWARE_CHECK`, so uv checks every package against
  OSV's malware advisories before its code runs. A CI run fails if OSV is unreachable.

## [0.7.1] - 2026-09-30

### Added

- `just rs-sync` downloads Rust dependencies and writes `Cargo.lock`, like `just py-sync`
  and `just go-sync` do for their stacks.
- A yamlfmt hook with a `.yamlfmt` config. yamllint now checks yamlfmt's output.

### Changed

- Hook revs are commit SHAs with a `# frozen:` tag comment, since tags are mutable.
  Dependabot moves both together.
- Flow mappings are written `{key: value}`, as yamlfmt formats them.
- Comments and docstrings in generated files are shorter and plainer. Two
  `.dockerignore` comments now describe the Docker layer cache correctly.

## [0.7.0] - 2026-09-30

### Upgrade notes

1. Run `copier update`. It replaces `hygiene.yml` with `checks.yml`, swaps
   `.taplo.toml` for `.tombi.toml`, and deletes the pull request template.
2. If something uploads `coverage.xml` or `coverage/lcov.info`, add the reporter flag
   back to `just py-cov` or `just ts-cov`.

### Changed

- The `hygiene.yml` workflow is now `checks.yml`. Its job names are unchanged, so
  required status checks still match.
- `.tombi.toml` replaces `.taplo.toml`, because tombi replaced taplo as the TOML
  formatter.
- `just py-cov` and `just ts-cov` print a coverage summary only. They no longer write
  report files.
- CI reads the Python version from `.python-version` instead of repeating it.

### Removed

- The pull request template.
- The `knip` script in `package.json`. `pnpm run check` already runs knip.
- The copier checks that rejected a project name that is a Rust or Go keyword.

## [0.6.0] - 2026-09-30

### Upgrade notes

1. Run `copier update`. If you added dependencies, you get one conflict in
   `pyproject.toml`. Keep your dependencies and take the new comment below them.
2. Run `uv lock` and `pnpm install`, then commit the lockfiles. `uv lock` can downgrade
   packages released in the last week.
3. If a `SKIP` list names `gitleaks`, change it to `betterleaks`.
4. Delete the `.vale/` folder. Vale is gone, and so is the `.gitignore` entry that hid it.

### Added

- `rust` and `go` stacks, each as a library or a binary, with strict linting.
- Python `web-service` kind: FastAPI in a container, with a `/health` endpoint.
- Python `data-pipeline` kind: downloads third-party data and records a checksum for each
  file.
- Dependency audits in `just check` and CI for Python, TypeScript and Rust.
- A `hygiene.yml` workflow that runs the git hooks in CI.
- `CITATION.cff` for research and data-pipeline projects.
- Knip for TypeScript, and an actionlint hook.
- A `CHANGELOG.md` in the Keep a Changelog format. `copier update` never overwrites it.
- Copier rejects answers that would build a broken project, such as a name that starts
  with a digit or a directory with a trailing `/`.

### Changed

- **Breaking:** secret scanning uses Betterleaks instead of gitleaks.
- **Breaking:** the web service turns on OpenTelemetry only when
  `OTEL_EXPORTER_OTLP_ENDPOINT` is set.
- CI installs a pinned uv, because `uv audit` is a preview command that can change
  between releases.
- `pnpm audit` fails on moderate and higher advisories only.

### Removed

- **Breaking:** the web service's `config.py` and `telemetry.py`.
- **Breaking:** the vale prose linter and its `.vale.ini`. rumdl still lints Markdown.

### Fixed

- PyPI releases failed when the Python package was in a subdirectory.
- A project name with quotes or a trailing `!` broke the render or the README checks.
- Both Dockerfiles pass hadolint.
- yamllint skips `pnpm-lock.yaml`.

### Security

- uv and pnpm install a release only after it is a week old, the same as Dependabot.
- Data-pipeline downloads stop at 200 MiB.
- The release workflows and `SECURITY.md` list the GitHub settings to turn on.

## [0.5.0] - 2026-07-30

### Added

- Markdown linting with rumdl, and YAML linting with yamllint.

## [0.4.0] - 2026-07-28

### Added

- A JSON5 check for config files such as `tsconfig.json`.

## [0.3.0] - 2026-07-28

### Added

- Prose linting with vale.

## [0.2.0] - 2026-07-24

### Changed

- **Breaking:** the four templates are one template. A project made from 0.1.0 cannot
  update to this release.

### Fixed

- The shipped `.gitignore` no longer hides template files.
- biome accepts the rendered `.vscode/` files.

## [0.1.0] - 2026-07-24

### Added

- Separate templates for a base repo and for Python, TypeScript and Docker, in any mix.
- Python library, app and research projects, and TypeScript library and app projects.
- CI for each stack, with GitHub Actions pinned to commits and audited by zizmor.
- Optional releases to PyPI, npm and GitHub Container Registry.
- Dependabot with a one-week cooldown.
- Coverage recipes for Python and TypeScript.

[Unreleased]: https://github.com/simonvanlierde/project-templates/compare/v0.12.0...HEAD
[0.12.0]: https://github.com/simonvanlierde/project-templates/compare/v0.11.0...v0.12.0
[0.11.0]: https://github.com/simonvanlierde/project-templates/compare/v0.10.0...v0.11.0
[0.10.0]: https://github.com/simonvanlierde/project-templates/compare/v0.9.1...v0.10.0
[0.9.1]: https://github.com/simonvanlierde/project-templates/compare/v0.9.0...v0.9.1
[0.9.0]: https://github.com/simonvanlierde/project-templates/compare/v0.8.1...v0.9.0
[0.8.1]: https://github.com/simonvanlierde/project-templates/compare/v0.8.0...v0.8.1
[0.8.0]: https://github.com/simonvanlierde/project-templates/compare/v0.7.1...v0.8.0
[0.7.1]: https://github.com/simonvanlierde/project-templates/compare/v0.7.0...v0.7.1
[0.7.0]: https://github.com/simonvanlierde/project-templates/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/simonvanlierde/project-templates/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/simonvanlierde/project-templates/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/simonvanlierde/project-templates/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/simonvanlierde/project-templates/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/simonvanlierde/project-templates/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/simonvanlierde/project-templates/releases/tag/v0.1.0
