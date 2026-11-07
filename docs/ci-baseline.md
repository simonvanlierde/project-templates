# CI baseline

What CI and the git hooks check in a generated project, why, and what the template leaves out.

## What every scaffold gets

| Piece | Where | Why |
| --- | --- | --- |
| Pinned action digests with version comments | Every workflow | Tags are mutable; SHA digests prevent supply-chain tampering. Dependabot bumps both |
| Pinned git hook SHAs with `# frozen:` comments | `.pre-commit-config.yaml` | Reproducible hook execution across local machines and CI. Dependabot updates both |
| Minimal default permissions (`contents: read` or `{}`) | Every workflow | Implements least privilege; elevated permissions granted per job |
| `concurrency` with `cancel-in-progress` | Non-release workflows | Cancels stale PR runs when new commits push. Excludes release, property, mutation, and copier-update workflows |
| `timeout-minutes` on all jobs | Every workflow | Prevents hung jobs from consuming runner minutes |
| Caches saved only from `main` | Caching workflows | PRs restore caches saved on `main` without saving new ones, preventing cache eviction within the 10 GB limit |
| `persist-credentials: false` on checkout | Every workflow | Prevents subsequent job steps from reusing the runner checkout token |
| Stack validation checks | `python.yml`, `ts.yml`, `rust.yml`, `go.yml` | Executes lint, format, type-check, test, and dependency audits matching `just check` |
| Git hooks executed in CI | `checks.yml` | Enforces hook compliance even if local contributors omit `prek install`. |
| Conventional commit and PR title checks | `committed.toml`, commit-msg hook, `pr-title.yml` | Enforces clean git history for squash merges to `main` |
| zizmor workflow auditor | Git hook and CI | Scans workflows for injection vulnerabilities, leaked secrets, and compromised actions |
| jactionlint | Git hook and CI | Validates workflow syntax, expressions, and shell commands in `run:` blocks |
| CodeQL code scanning | GitHub default setup, turned on by `just repo-settings` (when `public`) | Finds injection and other security bugs in the code; free for public repos |
| Dependency review | `checks.yml` (PRs only) | Blocks pull requests that introduce dependencies with known security advisories |
| Cooldown period on dependency updates | `.github/dependabot.yml` or `renovate.json5` | Delays non-critical updates by 7 days to allow malicious releases to be detected and yanked |
| `SECURITY.md` | `.github/` (when `public`) | Documents private vulnerability disclosure procedures, SLAs (14 days), and remediation policies |
| `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, PR template | `.github/` (when `public`) | Provides contributor setup instructions, sign-off guidelines, and Contributor Covenant 3.0 |
| Issue forms | `.github/ISSUE_TEMPLATE/` (when `public`) | Structured templates for bugs and feature requests, validated against GitHub schemas |
| DCO sign-off check | `dco.yml` (when `public`) | Verifies `Signed-off-by:` lines on fork commits; enforced on all branches with `openssf_badge=silver`. The `dco-signoff` commit-msg hook refuses an unsigned commit locally in every public render |
| `CITATION.cff`, `codemeta.json` | Licensed `library` kinds, plus licensed Python `research` and `data-pipeline` | Maintained for Zenodo, Software Heritage, and GitHub citation. `citesync` verifies consistency |
| REUSE licensing check | `reuse` git hook (when licensed) | Fails while a file has no copyright and license in `REUSE.toml` or `LICENSES/` |
| Multi-version Python testing | `python.yml` (`library` kind) | Tests packages across all supported minor versions from `python_min` to `python_version` |
| Python tests on Windows | `python.yml` (`python_windows` option) | Runs the tests on `windows-latest` with `python_version`, without lint or type checks |
| Code coverage reporting | `python.yml`, `ts.yml`, `codecov.yml` (`codecov` option) | Uploads coverage to Codecov; flags PR regressions exceeding 2 percentage points |
| Scheduled extended property tests | `property.yml` (`property` extra) | Runs 10,000 cases per property (or 10 minutes of Go fuzzing) weekly; excluded from PRs |
| Scheduled mutation testing | `mutation.yml` (`mutation` extra) | Measures test resilience against injected bugs weekly; excluded from PRs |
| Pull request benchmarks | `benchmarks.yml` (`codspeed` option) | Runs CodSpeed instruction-count benchmarks on PRs that touch benchmarked code and on every push to `main`, using OIDC authentication |
| Production deploy from CI | `ts.yml` (`web-app` kind) | Deploys the build the checks ran on to a Cloudflare Worker on each push to `main`, through a `production` environment limited to `main` |
| Pull request previews | `ts.yml` and `site.yml` preview jobs, `preview-retire.yml` (`web-app` kind, `site` option) | Deploys each open, ready pull request to its own Worker, and deletes it when the pull request closes, merges or turns draft |
| Static site on GitHub Pages or a Worker | `site.yml` (`site` option) | Builds `site/` with `just site` on every pull request and push to `main`, and deploys that build from `main` to GitHub Pages, or to a Cloudflare Worker with `site_host=cloudflare` |
| Browser tests in Playwright container | `ts.yml` (`web-app` kind) | Runs end-to-end tests against production builds using the pinned Playwright container |
| Automated accessibility tests (axe) | `tests/e2e/a11y.spec.ts` (`web-app` kind) | Tests routes in light and dark modes against WCAG 2.0–2.2 Levels A and AA |
| Content-Security-Policy enforcement | `public/_headers`, `tests/e2e/csp.spec.ts` | Validates strict CSP (`script-src 'self'`), HSTS, and frame protection without inline scripts |
| Viewport reflow validation | `tests/e2e/reflow.spec.ts` (`web-app` kind) | Verifies responsive layout at 320 px viewport width without horizontal scrollbars (WCAG 1.4.10) |
| Accessibility statement checks | `tests/e2e/accessibility-statement.spec.ts` | Validates statement sections, contact details, and valid status |
| Legal page tests | `tests/e2e/legal-pages.spec.ts` (`web-app` kind) | Ensures all legal pages render properly, are linked from every route in `LEGAL_LINKED_FROM`, and link back home |
| Clean state on initial load | `tests/e2e/privacy.spec.ts` (`web-app` kind) | Verifies routes set no cookies, create no storage, and contact only declared origins on load |
| Bundle size budget enforcement | `scripts/checkBundleBudget.mjs` (`web-app` kind) | Fails builds if gzipped JavaScript bundles exceed declared size limits |
| Publication provenance | Release workflows | Generates Sigstore attestations and provenance bundles for PyPI, npm, and GHCR artifacts |
| Container security scans | `docker.yml` (`docker` stack with `docker_image`) | Trivy scans images for HIGH/CRITICAL vulnerabilities; weekly scheduled rebuilds check base updates |
| Compose and shell lint | `compose.yml` (Compose-only repo) | Validates the Compose files against `.env.example`, then runs shellcheck and shfmt on the tracked shell scripts |
| Public API break detection | `python.yml` (griffe), `ts.yml` (API Extractor), `rust.yml` (cargo-semver-checks) | Compares public APIs against prior releases to detect breaking changes before publication |
| Documentation site build | `docs.yml` (`docs_site` option) | Builds `docs/` with Zensical in `--strict` mode on every pull request and push to `main`, and deploys that build from `main` to GitHub Pages |
| Cold-install setup verification | `cold-install.yml` (when `cold_install`) | Executes README development instructions in a minimal Debian container to catch missing prerequisites. Also runs when `pyproject.toml`, `uv.lock` or `.python-version` change |
| Scheduled dependency audits | `advisories.yml` | Runs weekly scans (`uv audit`, `pnpm audit`, `cargo deny`, `govulncheck`, `zizmor`) without commits |
| Scheduled link validation | `links.yml` | Validates internal and external links weekly via lychee and reports broken URLs |
| OpenSSF Scorecard | `scorecard.yml` (when `public`) | Evaluates supply-chain security practices and generates README status badges |
| FAIR software checks | `fair.yml` (when `public` with citation) | Validates repo compliance against fair-software.eu recommendations |
| Tag-based release publishing | Release workflows | Restricts publishing to version tags (`vX.Y.Z`) signed with a key in `.github/allowed_signers` on the default branch; disables manual workflow dispatch |

Rendered workflows default to `contents: read` or `{}`. Docker containers execute as non-root users ([Docker images](tooling.md#docker-images)).

> [!NOTE]
> GitHub automatically disables scheduled workflows in public repositories after 60 days of inactivity. Push a commit or re-enable them in the Actions tab.

CI skips hooks that require the local runtime environment (`ruff`, `ty`, `biome`, `tsc`, `cargo fmt`, `cargo clippy`, `golangci-lint`), as stack workflows run them directly. It also skips `betterleaks`, which operates only on staged files.

## What is left out, and why

| Omitted | Rationale | When to add |
| --- | --- | --- |
| In-workflow Renovate | Requires private GitHub App and secrets; Dependabot works out of the box | When advanced Renovate configuration options are required |
| release-please | Creates release PR churn on every push; ill-suited for tag-driven research releases | When release frequency justifies automated changelog PR generation |
| Repository history secret scan | GitHub secret scanning covers public repos; local hooks scan staged commits | For private repositories without GitHub Advanced Security |
| Docker base images pinned to SHA | The base image tag matches the `python_version` answer | In production deployments requiring byte-exact base images |
| Unified "CI result" job | Stack-specific workflows are small enough to list directly in branch rules | When workflow matrices expand beyond manual ruleset configuration |
| CODEOWNERS | Unnecessary for single-maintainer repositories | When adding multi-maintainer teams with distinct ownership areas |
| Multi-browser Playwright matrix | Triples CI test duration; modern engines rarely exhibit isolated rendering bugs | When using browser-specific Web APIs across rendering engines. Run Firefox and WebKit on pushes to `main` and weekly, with the deploy waiting on them, not on PRs: in credit-matrix they took 65% of a PR run's minutes |
| Dynamic CSP inline script hashing | Template enforces strict `script-src 'self'` without inline scripts | Not needed under current zero-inline-script policy |
| Offline service workers | Aggressive caching complicates rollback of broken deployments | When offline availability is an explicit user requirement |

## Path filters

A path filter skips work a pull request cannot affect. It never applies to pushes to `main` or to scheduled runs, which refill the caches and give CodSpeed its base results. The one exception is `docker.yml` with a nested `python_dir`, which filters its push trigger too: a push that changes no build context has no image to build.

- **Required checks:** a workflow that a ruleset requires takes no workflow-level `paths:`. A pull request it skips never reports the check, so the merge waits for it ([usage](usage.md), "Requires pull requests").
- **Optional single-purpose workflows** filter their `pull_request` trigger by path: `benchmarks.yml`, `cold-install.yml`, and `docker.yml` when the image builds from a subdirectory.
- **Repos with independent parts** (a web app beside a Python pipeline, each with jobs that take minutes) add one `changes` job that lists the PR's files and sets an output per part. Each part's jobs run with `if: ${{ !cancelled() && needs.changes.outputs.<part> != 'false' }}`, so a skipped or failed `changes` job runs everything, and a skipped required job counts as passed. A matrix job is the exception: skipped by its `if`, it reports no check under its legs' names, so the ruleset requires a small non-matrix job that needs it and passes when it succeeded or was skipped. Files outside every part, such as workflows and root config, select all parts. A job further down the chain checks `needs.<job>.result` explicitly: by default a failed `changes` job would skip it, though the jobs between them run.
- **Single-stack repos** use no filter: the jobs run in parallel and a skip saves little.

## Caveats

- **Dependency review:** Requires GitHub dependency graph. If disabled on a new repository, enable Dependabot alerts in repository settings (`gh api -X PUT repos/OWNER/REPO/vulnerability-alerts`). Skipped on private repositories without GitHub Advanced Security.
- **zizmor:** Online audits (impostor commits, action advisories) require a GitHub token. CI passes the read-only `github.token`; locally, set `GH_TOKEN` to run online checks.
- **Accessibility scope:** Automated axe and reflow tests apply exclusively to the `web-app` kind. CLI programs receive a static `docs/accessibility.md` specification.
- **Local network bindings:** Local development servers bind `127.0.0.1` (`just serve`, Docker Compose port mappings, Vite dev servers). Deployed services communicate over HTTPS.
- **Data pipeline network access:** `data-pipeline` projects fetch live sources in CI. The pipeline retries transient network errors three times over 35 seconds before failing.
