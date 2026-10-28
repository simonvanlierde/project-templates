# CI baseline

Every repository scaffolded from this template gets the same checks. The tables below
say what each piece is, why it's there, and what I left out on purpose.

## What every scaffold gets

| Piece | Where | Why |
| --- | --- | --- |
| Actions pinned to a commit digest, version in a trailing comment | every workflow | A tag can move; a digest can't. Dependabot bumps both. |
| Hook revs pinned to a commit SHA, tag in a `# frozen:` comment | `.pre-commit-config.yaml` | The same reason: hooks run in CI and on every contributor's machine. Dependabot bumps both. |
| `permissions: contents: read` at the top, wider grants per job only | every workflow | The token can do only what the job needs. |
| `concurrency` group with `cancel-in-progress` | every workflow except the release ones, which must not stop halfway, `mutation.yml` and `copier-update.yml`, which never cancel, and the weekly `advisories.yml`, which has no group. `python.yml`, `docker.yml` and `benchmarks.yml` cancel only on pull requests, so a push to main never stops a scheduled run, an image push or a benchmark baseline. `scorecard.yml` lets a push cancel the weekly run, because both do the same scan. Their groups include the event, because GitHub replaces a pending run whenever a newer one queues in its group | A new push cancels the stale run. |
| `timeout-minutes` on every job | every workflow | A hung job stops in minutes, not six hours. |
| `persist-credentials: false` on checkout | every workflow | Later steps can't reuse the checkout token. |
| Stack checks: lint, format, types, tests, dependency audit | `python.yml`, `ts.yml`, `rust.yml`, `go.yml` | The same commands as `just check`. |
| Git hooks run in CI | `checks.yml` | `prek install` is opt-in per clone. Without this job, a commit made without hooks reaches `main` unchecked. |
| Commit message and PR title rules | `committed.toml`, the `committed` commit-msg hook and `pr-title.yml` | A squash merge makes the PR title the commit subject on `main`, so the title follows the same rules as a commit: Conventional Commits, an imperative summary, no period. Lower case is a convention only: committed can't refuse a capital. The hook skips merge commits, whose message git writes. Dependabot and Renovate are set to write titles that pass. |
| zizmor | hook, so also CI | Audits workflows for template injection, credential leaks, cache poisoning, and impostor commits. |
| jactionlint | hook, so also CI | Catches what zizmor doesn't: unknown keys, bad `needs`, expression type errors, and shellcheck findings in `run:` blocks. |
| Dependency review | `checks.yml`, PRs only | Fails a PR that adds a dependency with a known advisory. |
| Dependabot (or Renovate) with a one-week cooldown | `.github/dependabot.yml`, or `renovate.json5` with `dependency_bot=renovate` | Updates wait until a compromised release has usually been yanked. Security updates skip the wait. Dependabot groups npm security updates into one pull request. |
| `SECURITY.md` | `.github/`, with `public` (the default) | Tells a reporter where to send a vulnerability privately, what to include, when to expect an answer (14 days) and how a fix is disclosed. |
| `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `pull_request_template.md` | `.github/`, with `public` | Tell contributors how to report a bug, set up and check a change, the commit, pull request and changelog conventions, the sign-off rule and who maintains the project, and the Contributor Covenant 3.0. |
| DCO sign-off check | `dco.yml`, with `public` | Fails a pull request from a fork with a commit that has no `Signed-off-by:` line, the Developer Certificate of Origin that CONTRIBUTING.md asks for. Pull requests from a branch in the repository skip it, except with `openssf_badge=silver`, where it checks every pull request and the commit-msg hook refuses an unsigned commit. A bot's own commits in a bot's pull request are skipped. |
| `CITATION.cff`, `.zenodo.json`, `codemeta.json` | `library`, `research` and `data-pipeline` kinds | GitHub's "Cite this repository" button reads `CITATION.cff`, Zenodo reads `.zenodo.json` when it archives a release, and software indexes read `codemeta.json` (CodeMeta 4.0). A hook checks `CITATION.cff` against its schema. |
| Tests on every supported Python | `python.yml`, `library` kind | A library declares `requires-python >= python_min` and CI tests each minor from there to `python_version`. The default floor is two minors below, after [SPEC 0](https://scientific-python.org/specs/spec-0000/). |
| Coverage upload, gated only on a drop of over 2 points | `python.yml`, `ts.yml`, `codecov.yml`, with the `codecov` option | Coverage shows per pull request without blocking one over a few untested lines. Codecov does not comment; the failing check links to the report. |
| Weekly property tests at length | `property.yml`, with `property` in `test_extras` | The property tests run briefly with every test run; once a week they try far more inputs: 10,000 a property in Python, TypeScript and Rust, and 10 minutes of `go test -fuzz=FuzzAdd`. Never on a pull request. A failing input fails the job. |
| Weekly mutation testing | `mutation.yml`, with `mutation` in `test_extras` | The tests are checked against planted bugs, but a run takes minutes to hours, so it never runs on a pull request. The Rust job fails on a surviving mutant; the others print the survivors and pass. |
| Benchmarks on every pull request | `benchmarks.yml`, with the `codspeed` option | CodSpeed counts CPU instructions in simulation mode, so a noisy runner does not move the result, and reports each pull request against main. Pushes to main run too, so a pull request has a base to compare with. The job signs in with OpenID Connect and holds no secret. |
| End-to-end tests in Chromium, in the Playwright container | `ts.yml`, `web-app` kind | The tests run against the production build, which is what users get. The image tag comes from the `@playwright/test` version the lockfile installed, so a Playwright bump needs no workflow edit. The job installs a Latin font: the image's fallback font has narrow Latin glyphs, which can hide text that overflows. A failed run uploads the HTML report. |
| Accessibility check with axe | `tests/e2e/a11y.spec.ts`, `web-app` kind | Every route, in light and dark color schemes, against WCAG 2.0, 2.1 and 2.2 levels A and AA and axe's best-practice rules. Any violation fails, whatever its impact. |
| Content-Security-Policy with no inline script | `public/_headers`, `tests/e2e/csp.spec.ts`, `web-app` kind | Cloudflare Pages serves the policy (`script-src 'self'`) with HSTS, frame, opener and cross-origin resource isolation. The spec checks that each security header is still in the file, runs the built app under that policy and fails on any violation, so a change that needs a looser policy fails in CI, not in production. |
| Reflow at 320 px | `tests/e2e/reflow.spec.ts`, `web-app` kind | Every route, in a 320 px wide viewport (WCAG 1.4.10). The page must not scroll sideways. |
| Accessibility statement | `docs/accessibility.md`, `tests/e2e/accessibility-statement.spec.ts`, `web-app` kind | The statement keeps its sections and email contact, its status sentence says "not assessed", "partially conformant" or "non-conformant" and never "fully conformant", and its "Last reviewed" date is under 400 days old and not in the future. |
| Legal pages | `docs/*.md`, `tests/e2e/legal-pages.spec.ts`, `web-app` kind | The accessibility statement, the privacy statement and, with accounts, the terms each render with an email contact and hold no TODO, and every route's footer links all of them, marking the current one. |
| No cookies, storage or outside requests on first load | `docs/privacy.md`, `tests/e2e/privacy.spec.ts`, `web-app` kind | A first visit to every route, left idle for three seconds, sets no cookies, writes nothing to local or session storage, IndexedDB or the cache, registers no service worker, and requests only the app's own origin and any listed in `OTHER_ORIGINS`, so the app needs no cookie banner. |
| Bundle budget | `scripts/checkBundleBudget.mjs`, `web-app` kind | Fails `just check` and CI when the largest JavaScript file, gzipped, passes the limit set in the script. A dependency that doubles the bundle shows up in its own pull request. |
| Provenance on publish | release workflows | PyPI and npm trusted publishing attach attestations. The Python release also attaches the distributions and their signed Sigstore provenance bundle to its GitHub release, checkable with `gh attestation verify --bundle`. Container images pushed to GHCR carry an SBOM and a provenance attestation. |
| Image scan and weekly rebuild | `docker.yml`, with the `docker` stack | Trivy lists HIGH and CRITICAL vulnerabilities in the built image that already have a fix. A weekly run rebuilds the image on the newest base image and scans it without pushing. Only that run fails on a finding, because a fix often waits days on a rebuilt base image and a pull request can't change that. |
| API-break check | `python.yml` (`api` job) with `publish_to_pypi`, `ts.yml` and `just ts-check` with `publish_to_npm` | A release that drops or changes a public function breaks its users, so the change should be seen before it ships. Python: griffe compares the public API with the last git tag and passes while there is none. The job checks out full history for the tags. A deliberate break keeps the job red until the next tag, so leave it out of the required checks and merge such a PR knowingly. It is not in `just py-check` for the same reason. TypeScript: API Extractor compares the built types with the committed `<package>.api.md`. After a deliberate change, `just ts-api` rewrites the report, and its diff shows the change in review. |
| README commands in a fresh container | `cold-install.yml`, with any stack | A README that skips a setup step works on the author's machine and fails for the next contributor. The job runs the ```` ```sh ```` blocks under `## Development` as written, from the checkout, in a Debian container that has git and a C compiler but none of the tools the README asks for, which it installs one setup step each. Those steps also put each tool on `PATH`, so a README that leaves out a `PATH` step still passes. It skips `just up`, `just pipeline`, `just ts-e2e` and the weekly mutation and property recipes, which need Docker, a browser, live sources or hours, and the hadolint hook, which needs Docker. It runs on pull requests that change `README.md` and weekly, because a tool release can break the steps with no commit here. |
| Weekly dependency audit | `advisories.yml`, one job per stack | The stack workflows audit on push and pull request only. On Mondays this runs the same audit without a commit: `uv audit`, `pnpm audit --prod`, `cargo deny check advisories` and `govulncheck`. |
| Weekly link check | `links.yml`, every project | The `lychee` git hook runs offline and checks relative links only. On Thursdays lychee checks every link in the Markdown and HTML files, web links too, and the job summary lists the dead ones. |
| OpenSSF Scorecard | `scorecard.yml`, with `public` (the default) | Rates the repo's supply-chain practices, publishes the score for the README badge and uploads the findings to code scanning. It runs on pushes to main, weekly, and when branch protection changes. A private repo gets none: publishing the score needs a public repo. |
| fair-software.eu check | `fair.yml`, with `public` and a kind that gets `CITATION.cff` | Runs `uvx howfairis` against the repo weekly, and on demand, and lists each of the five recommendations in the job summary. The job fails when fewer than `FAIR_MIN` dots are filled; a new repo has three (repository, license, citation), so raise `FAIR_MIN` as you add a registry entry and the OpenSSF Best Practices badge. The README badge starts at three of five dots; edit it to the score the run prints. howfairis calls GitHub's API without a token. |
| Publishing from a version tag only | release workflows | `python-release.yml` creates the GitHub release after PyPI succeeds, with distributions and provenance attached before publication. Other projects use `release.yml`. Both use the tag's `CHANGELOG.md` section. No `workflow_dispatch`: a manual run can target any branch, and neither trusted publishing nor the environment checks the ref. |

A render is hardened from the start. Every workflow begins with read-only permissions,
`contents: read` or none at all, and widens them only for the job that needs more. A
`web-app` sends a Content-Security-Policy and the other security headers from
`public/_headers`. The Docker images run as a non-root user
([Docker images](tooling.md#docker-images)).

GitHub turns off scheduled workflows in a public repository with no activity for 60 days, such
as the weekly audit, the cold install, the link check, the Scorecard run, the Trivy rebuild, the data-pipeline tripwire and the revisions report. They
stop without an error, so push a commit or re-enable them under the Actions tab. See
[GitHub's docs](https://docs.github.com/en/actions/managing-workflow-runs-and-deployments/managing-workflow-runs/disabling-and-enabling-a-workflow).

The hooks job skips the hooks that need the project environment (`ruff`, `ty`,
`biome`, `tsc`, `cargo fmt`, `cargo clippy` and `golangci-lint`), because the stack workflows already run them. It also skips
betterleaks, which scans only staged changes, and CI stages nothing. GitHub secret
scanning covers the server side.

## What is left out, and why

| Left out | Reason | Add it when |
| --- | --- | --- |
| CodeQL | Minutes per run and gigabytes of memory, for little signal on a small repo that already runs ruff and ty. | The repo grows a web surface or outside contributors. Default setup is a toggle in the repository settings; it needs no YAML. |
| Renovate from Actions | Needs a GitHub App and two secrets. Dependabot needs neither and covers every ecosystem here, including hook revs. The hosted Renovate app is the `dependency_bot=renovate` answer. | You need Renovate options the hosted app doesn't run. |
| release-please | Research repos release rarely, and Zenodo archives a tagged release. A release PR on every push is noise. | Releases become frequent enough that writing the changelog by hand costs time. |
| Secret scan over full history | GitHub secret scanning and push protection cover public repos at no cost. The hook covers local commits. | The repo is private without GitHub Advanced Security. |
| Base images pinned to a digest | The `FROM` tags are copier answers (`python_version`, `node_version`), so Dependabot's docker ecosystem would fight `copier update` over them. | The image runs in production: pin `FROM ...@sha256:` and add a docker entry to `dependabot.yml`. |
| One required "CI result" job | A single workflow per stack is short enough to list its jobs in branch protection. | The job list grows past what you want to maintain by hand. |
| `cargo-semver-checks` | The Rust stack has no crates.io release workflow yet, so no publish answer to hang it on. | A `publish_to_crates` option lands. |
| CODEOWNERS, issue templates | Single-author repos. | Other people start contributing. |
| A deploy workflow for the `web-app` kind | Cloudflare Pages' Git integration builds every push and gives each pull request a preview URL, with no API token stored in GitHub. | You deploy somewhere without a Git integration, or need a check to pass before a deploy. |
| Firefox, WebKit and mobile browsers in the e2e job | Each browser multiplies the job's time, and a small app rarely breaks in only one engine. | The app uses an API whose support differs between browsers. Add a project to `playwright.config.ts`. |
| A build step that hashes inline scripts into the policy | The policy allows no inline script at all, so there is nothing to hash. Code that must run before first paint goes in a file under `public/`. | Never, while that rule holds. |
| Offline support (a service worker) | It caches old builds, which makes a broken deploy harder to roll back. | Users need the app offline. `vite-plugin-pwa` is the usual choice. |

## Caveats

- Dependency review needs the dependency graph. A new public repo can start with it
  off, and then the job fails every pull request. Turn on Dependabot alerts under
  Settings, Advanced Security (`gh api -X PUT repos/OWNER/REPO/vulnerability-alerts`),
  which turns the graph on. A private repo needs GitHub Advanced Security for it, so
  the job skips private repos.
  The dependency audits in their stack workflows still run.
- zizmor needs a token for its online audits: impostor commits and known-vulnerable
  actions. The hooks job runs it in a step of its own, the only one given the read-only
  `github.token`, so the other hooks never see it. Locally, set `GH_TOKEN`
  to get them. Without it, only the offline audits run.
- Accessibility checks cover the `web-app` kind only: the axe and 320 px reflow tests
  above. The docs, in this repository and in a render, are plain Markdown that GitHub
  renders, with no styles or scripts of their own.
- The local servers speak plain HTTP and are for development on your own machine:
  `just serve` binds 127.0.0.1, compose publishes ports on 127.0.0.1 only, and Vite's dev
  and preview servers listen on localhost. What a project publishes goes out over HTTPS:
  GitHub, PyPI, npm, the GitHub Container Registry and Cloudflare Pages. A web app's
  `site_url` must start with `https://`.
- A `data-pipeline` project fetches its sources from their live URLs in CI, and so
  does this template's own CI. `fetch` retries a server error, a rate limit or a
  dropped connection three times over about 35 seconds, so only a longer outage or a
  moved file fails the run, whatever the diff. Re-run it.
