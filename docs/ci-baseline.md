# CI baseline

Every repository scaffolded from this template gets the same checks. The tables below
say what each piece is, why it's there, and what I left out on purpose.

## What every scaffold gets

| Piece | Where | Why |
| --- | --- | --- |
| Actions pinned to a commit digest, version in a trailing comment | every workflow | A tag can move; a digest can't. Dependabot bumps both. |
| Hook revs pinned to a commit SHA, tag in a `# frozen:` comment | `.pre-commit-config.yaml` | The same reason: hooks run in CI and on every contributor's machine. Dependabot bumps both. |
| `permissions: contents: read` at the top, wider grants per job only | every workflow | The token can do only what the job needs. |
| `concurrency` group with `cancel-in-progress` | every workflow except the release ones, which must not stop halfway. `python.yml` and `docker.yml` cancel only on pull requests, so a push to main never stops a scheduled run or an image push. Their groups include the event, because GitHub replaces a pending run whenever a newer one queues in its group | A new push cancels the stale run. |
| `timeout-minutes` on every job | every workflow | A hung job stops in minutes, not six hours. |
| `persist-credentials: false` on checkout | every workflow | Later steps can't reuse the checkout token. |
| Stack checks: lint, format, types, tests, dependency audit | `python.yml`, `ts.yml`, `rust.yml`, `go.yml` | The same commands as `just check`. |
| Git hooks run in CI | `checks.yml` | `prek install` is opt-in per clone. Without this job, a commit made without hooks reaches `main` unchecked. |
| zizmor | hook, so also CI | Audits workflows for template injection, credential leaks, cache poisoning, and impostor commits. |
| jactionlint | hook, so also CI | Catches what zizmor doesn't: unknown keys, bad `needs`, expression type errors, and shellcheck findings in `run:` blocks. |
| Dependency review | `checks.yml`, PRs only | Fails a PR that adds a dependency with a known advisory. |
| Dependabot (or Renovate) with a one-week cooldown | `.github/dependabot.yml`, or `renovate.json5` with `dependency_bot=renovate` | Updates wait until a compromised release has usually been yanked. Security updates skip the wait. Dependabot groups npm security updates into one pull request. |
| `SECURITY.md` | `.github/`, with `public` (the default) | Tells a reporter where to send a vulnerability privately. |
| `CITATION.cff`, `.zenodo.json`, `codemeta.json` | `library`, `research` and `data-pipeline` kinds | GitHub's "Cite this repository" button reads `CITATION.cff`, Zenodo reads `.zenodo.json` when it archives a release, and software indexes read `codemeta.json` (CodeMeta 4.0). A hook checks `CITATION.cff` against its schema. |
| Tests on every supported Python | `python.yml`, `library` kind | A library declares `requires-python >= python_min` and CI tests each minor from there to `python_version`. The default floor is two minors below, after [SPEC 0](https://scientific-python.org/specs/spec-0000/). |
| Coverage upload, gated only on a drop of over 2 points | `python.yml`, `ts.yml`, `codecov.yml`, with the `codecov` option | Coverage shows per pull request without blocking one over a few untested lines. Codecov does not comment; the failing check links to the report. |
| End-to-end tests in Chromium, in the Playwright container | `ts.yml`, `web-app` kind | The tests run against the production build, which is what users get. The image tag comes from the `@playwright/test` version the lockfile installed, so a Playwright bump needs no workflow edit. The job installs a Latin font: the image's fallback font has narrow Latin glyphs, which can hide text that overflows. A failed run uploads the HTML report. |
| Accessibility check with axe | `tests/e2e/a11y.spec.ts`, `web-app` kind | Every route, in light and dark color schemes, against WCAG 2.0, 2.1 and 2.2 levels A and AA and axe's best-practice rules. Any violation fails, whatever its impact. |
| Content-Security-Policy with no inline script | `public/_headers`, `tests/e2e/csp.spec.ts`, `web-app` kind | Cloudflare Pages serves the policy (`script-src 'self'`) with HSTS, frame, opener and cross-origin resource isolation. The spec checks that each security header is still in the file, runs the built app under that policy and fails on any violation, so a change that needs a looser policy fails in CI, not in production. |
| Reflow at 320 px | `tests/e2e/reflow.spec.ts`, `web-app` kind | Every route, in a 320 px wide viewport (WCAG 1.4.10). The page must not scroll sideways. |
| Bundle budget | `scripts/checkBundleBudget.mjs`, `web-app` kind | Fails `just check` and CI when the largest JavaScript file, gzipped, passes the limit set in the script. A dependency that doubles the bundle shows up in its own pull request. |
| Provenance on publish | release workflows | PyPI and npm trusted publishing attach attestations. The Python release also signs a GitHub build-provenance attestation for each file, checkable with `gh attestation verify`. Container images pushed to GHCR carry an SBOM and a provenance attestation. |
| Image scan and weekly rebuild | `docker.yml`, with the `docker` stack | Trivy lists HIGH and CRITICAL vulnerabilities in the built image that already have a fix. A weekly run rebuilds the image on the newest base image and scans it without pushing. Only that run fails on a finding, because a fix often waits days on a rebuilt base image and a pull request can't change that. |
| Publishing from a published release only | release workflows | No `workflow_dispatch`: a manual run can target any branch, and neither trusted publishing nor the environment checks the ref. |

GitHub turns off scheduled workflows in a public repository with no activity for 60 days, such
as the weekly Trivy rebuild, the data-pipeline tripwire and the revisions report. They
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
| OpenSSF Scorecard | Needs a public repo to publish, and mostly scores the practices in the first table. | You want the badge. |
| Renovate from Actions | Needs a GitHub App and two secrets. Dependabot needs neither and covers every ecosystem here, including hook revs. The hosted Renovate app is the `dependency_bot=renovate` answer. | You need automerge, or Renovate options the hosted app doesn't run. |
| release-please | Research repos release rarely, and Zenodo archives a tagged release. A release PR on every push is noise. | Releases become frequent enough that writing the changelog by hand costs time. |
| Secret scan over full history | GitHub secret scanning and push protection cover public repos at no cost. The hook covers local commits. | The repo is private without GitHub Advanced Security. |
| Scheduled audit job | The stack workflows audit on every push and PR (`uv audit`, `pnpm audit --prod`, `cargo deny check`, `govulncheck`), and Dependabot security alerts cover the time between. | A dependency sits unchanged for months in a repo with few pushes. |
| Base images pinned to a digest | The `FROM` tags are copier answers (`python_version`, `node_version`), so Dependabot's docker ecosystem would fight `copier update` over them. | The image runs in production: pin `FROM ...@sha256:` and add a docker entry to `dependabot.yml`. |
| One required "CI result" job | A single workflow per stack is short enough to list its jobs in branch protection. | The job list grows past what you want to maintain by hand. |
| CODEOWNERS, issue templates, CONTRIBUTING | Single-author repos. | Other people start contributing. |
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
- A `data-pipeline` project fetches its sources from their live URLs in CI, and so
  does this template's own CI. `fetch` retries a server error, a rate limit or a
  dropped connection three times over about 35 seconds, so only a longer outage or a
  moved file fails the run, whatever the diff. Re-run it.
