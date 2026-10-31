# CI baseline

Checks included in repositories generated from this template, their purposes, and omitted alternatives.

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
| Git hooks executed in CI | `checks.yml` | Enforces hook compliance even if local contributors omit `prek install` |
| Conventional commit and PR title checks | `committed.toml`, commit-msg hook, `pr-title.yml` | Enforces clean git history for squash merges to `main` |
| zizmor workflow auditor | Git hook and CI | Scans workflows for injection vulnerabilities, leaked secrets, and compromised actions |
| jactionlint | Git hook and CI | Validates workflow syntax, expressions, and shell commands in `run:` blocks |
| Dependency review | `checks.yml` (PRs only) | Blocks pull requests that introduce dependencies with known security advisories |
| Cooldown period on dependency updates | `.github/dependabot.yml` or `renovate.json5` | Delays non-critical updates by 7 days to allow malicious releases to be detected and yanked |
| `SECURITY.md` | `.github/` (when `public`) | Documents private vulnerability disclosure procedures, SLAs (14 days), and remediation policies |
| `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, PR template | `.github/` (when `public`) | Provides contributor setup instructions, sign-off guidelines, and Contributor Covenant 3.0 |
| Issue forms | `.github/ISSUE_TEMPLATE/` (when `public`) | Structured templates for bugs and feature requests, validated against GitHub schemas |
| DCO sign-off check | `dco.yml` (when `public`) | Verifies `Signed-off-by:` lines on fork commits; enforced on all branches with `openssf_badge=silver` |
| `CITATION.cff`, `codemeta.json` | `library` kinds, plus Python `research` and `data-pipeline` | Maintained for Zenodo, Software Heritage, and GitHub citation. `citesync` verifies consistency |
| Multi-version Python testing | `python.yml` (`library` kind) | Tests packages across all supported minor versions from `python_min` to `python_version` |
| Code coverage reporting | `python.yml`, `ts.yml`, `codecov.yml` (`codecov` option) | Uploads coverage to Codecov; flags PR regressions exceeding 2 percentage points |
| Scheduled extended property tests | `property.yml` (`property` extra) | Runs 10,000 cases per property (or 10 minutes of Go fuzzing) weekly; excluded from PRs |
| Scheduled mutation testing | `mutation.yml` (`mutation` extra) | Measures test resilience against injected bugs weekly; excluded from PRs |
| Pull request benchmarks | `benchmarks.yml` (`codspeed` option) | Runs CodSpeed instruction-count benchmarks on PRs and `main` using OIDC authentication |
| Browser tests in Playwright container | `ts.yml` (`web-app` kind) | Runs end-to-end tests against production builds using the pinned Playwright container |
| Automated accessibility tests (axe) | `tests/e2e/a11y.spec.ts` (`web-app` kind) | Tests routes in light and dark modes against WCAG 2.0–2.2 Levels A and AA |
| Content-Security-Policy enforcement | `public/_headers`, `tests/e2e/csp.spec.ts` | Validates strict CSP (`script-src 'self'`), HSTS, and frame protection without inline scripts |
| Viewport reflow validation | `tests/e2e/reflow.spec.ts` (`web-app` kind) | Verifies responsive layout at 320 px viewport width without horizontal scrollbars (WCAG 1.4.10) |
| Accessibility statement checks | `tests/e2e/accessibility-statement.spec.ts` | Validates statement sections, contact details, valid status, and review currency (< 400 days) |
| Legal page tests | `tests/e2e/legal-pages.spec.ts` (`web-app` kind) | Ensures all legal pages render without TODO markers and link from route footers |
| Clean state on initial load | `tests/e2e/privacy.spec.ts` (`web-app` kind) | Verifies routes set no cookies, create no storage, and contact only declared origins on load |
| Bundle size budget enforcement | `scripts/checkBundleBudget.mjs` (`web-app` kind) | Fails builds if gzipped JavaScript bundles exceed declared size limits |
| Publication provenance | Release workflows | Generates Sigstore attestations and provenance bundles for PyPI, npm, and GHCR artifacts |
| Container security scans | `docker.yml` (`docker` stack) | Trivy scans images for HIGH/CRITICAL vulnerabilities; weekly scheduled rebuilds check base updates |
| Public API break detection | `python.yml` (griffe), `ts.yml` (API Extractor) | Compares public APIs against prior releases to detect breaking changes before publication |
| Cold-install setup verification | `cold-install.yml` | Executes README development instructions in a minimal Debian container to catch missing prerequisites |
| Scheduled dependency audits | `advisories.yml` | Runs weekly scans (`uv audit`, `pnpm audit`, `cargo deny`, `govulncheck`, `zizmor`) without commits |
| Scheduled link validation | `links.yml` | Validates internal and external links weekly via lychee and reports broken URLs |
| OpenSSF Scorecard | `scorecard.yml` (when `public`) | Evaluates supply-chain security practices and generates README status badges |
| FAIR software checks | `fair.yml` (when `public` with citation) | Validates repo compliance against fair-software.eu recommendations |
| Tag-based release publishing | Release workflows | Restricts publishing to signed version tags (`vX.Y.Z`); disables manual workflow dispatch |

Rendered workflows default to `contents: read` or `{}`. Docker containers execute as non-root users ([Docker images](tooling.md#docker-images)).

> [!NOTE]
> GitHub automatically disables scheduled workflows in public repositories after 60 days of inactivity. Push a commit or re-enable them in the Actions tab.

CI skips hooks that require the local runtime environment (`ruff`, `ty`, `biome`, `tsc`, `cargo fmt`, `cargo clippy`, `golangci-lint`), as stack workflows run them directly. It also skips `betterleaks`, which operates only on staged files.

## What is left out, and why

| Omitted | Rationale | When to add |
| --- | --- | --- |
| CodeQL | Significant runtime and memory overhead; overlaps with ruff and ty on small repos | When repository accepts untrusted outside code or grows a substantial web surface |
| In-workflow Renovate | Requires private GitHub App and secrets; Dependabot works out of the box | When advanced Renovate configuration options are required |
| release-please | Creates release PR churn on every push; ill-suited for tag-driven research releases | When release frequency justifies automated changelog PR generation |
| Repository history secret scan | GitHub secret scanning covers public repos; local hooks scan staged commits | For private repositories without GitHub Advanced Security |
| Docker base images pinned to SHA | Base image tags match Copier answers (`python_version`, `node_version`) | In production deployments requiring byte-exact base images |
| Unified "CI result" job | Stack-specific workflows are small enough to list directly in branch rules | When workflow matrices expand beyond manual ruleset configuration |
| `cargo-semver-checks` | Crates.io publication workflow is not yet implemented | When automated Rust crate publishing is added |
| CODEOWNERS | Unnecessary for single-maintainer repositories | When adding multi-maintainer teams with distinct ownership areas |
| Web app deployment workflows | Cloudflare Pages deploys automatically via Git integration | When deploying to environments without native Git integrations |
| Multi-browser Playwright matrix | Triples CI test duration; modern engines rarely exhibit isolated rendering bugs | When using browser-specific Web APIs across rendering engines |
| Dynamic CSP inline script hashing | Template enforces strict `script-src 'self'` without inline scripts | Not needed under current zero-inline-script policy |
| Offline service workers | Aggressive caching complicates rollback of broken deployments | When offline availability is an explicit user requirement |

## Caveats

- **Dependency review:** Requires GitHub dependency graph. If disabled on a new repository, enable Dependabot alerts in repository settings (`gh api -X PUT repos/OWNER/REPO/vulnerability-alerts`). Skipped on private repositories without GitHub Advanced Security.
- **zizmor:** Online audits (impostor commits, action advisories) require a GitHub token. CI passes the read-only `github.token`; locally, set `GH_TOKEN` to run online checks.
- **Accessibility scope:** Automated axe and reflow tests apply exclusively to the `web-app` kind. CLI programs receive a static `docs/accessibility.md` specification.
- **Local network bindings:** Local development servers bind `127.0.0.1` (`just serve`, Docker Compose port mappings, Vite dev servers). Deployed services communicate over HTTPS.
- **Data pipeline network access:** `data-pipeline` projects fetch live sources in CI. The pipeline retries transient network errors three times over 35 seconds before failing.
