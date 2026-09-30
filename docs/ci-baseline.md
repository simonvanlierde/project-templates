# CI baseline

Every repository scaffolded from this template gets the same checks. The list below
says what each piece is, why it is there, and what was left out on purpose. It
compares against the ReLab production repository, which runs a heavier set.

## What every scaffold gets

| Piece | Where | Why |
| --- | --- | --- |
| Actions pinned to a commit digest, version in a trailing comment | every workflow | A tag can move; a digest can't. Dependabot bumps both. |
| `permissions: contents: read` at the top, wider grants per job only | every workflow | The token can do only what the job needs. |
| `concurrency` group with `cancel-in-progress` | every workflow except the release ones, which must not stop halfway | A new push cancels the stale run. |
| `timeout-minutes` on every job | every workflow | A hung job stops in minutes, not six hours. |
| `persist-credentials: false` on checkout | every workflow | Later steps can't reuse the checkout token. |
| Stack checks: lint, format, types, tests, dependency audit | `python.yml`, `ts.yml`, `rust.yml`, `go.yml` | The same commands as `just check`. |
| Git hooks run in CI | `checks.yml` | `prek install` is opt-in per clone. Without this job, a commit made without hooks reaches `main` unchecked. |
| zizmor | hook, so also CI | Audits workflows for template injection, credential leaks, cache poisoning, and impostor commits. |
| actionlint | hook, so also CI | Catches what zizmor doesn't: unknown keys, bad `needs`, expression type errors, and shellcheck findings in `run:` blocks. |
| Dependency review | `checks.yml`, PRs only | Fails a PR that adds a dependency with a known advisory. |
| Dependabot with a one-week cooldown | `.github/dependabot.yml` | Updates wait until a compromised release has usually been yanked. Security updates skip the wait. |
| `SECURITY.md` | `.github/` | Tells a reporter where to send a vulnerability privately. |
| `CITATION.cff` | `research` and `data-pipeline` kinds | GitHub's "Cite this repository" button and Zenodo read it. A hook checks it against the schema. |
| Provenance on publish | release workflows | PyPI and npm trusted publishing attach attestations. Container images pushed to GHCR carry an SBOM and a provenance attestation. |

The hooks job skips the hooks that need the project environment (`ruff`, `ty`,
`biome`, `tsc`), because the stack workflows already run them. It also skips betterleaks.
The betterleaks hook scans staged changes only, and CI stages nothing. GitHub secret
scanning is the server-side check.

## What is left out, and why

| Left out | Reason | Add it when |
| --- | --- | --- |
| CodeQL | Minutes per run and gigabytes of memory, for little signal on a small repo that already runs ruff and ty. | The repo grows a web surface or outside contributors. Default setup is a toggle in the repository settings; it needs no YAML. |
| OpenSSF Scorecard | Needs a public repo to publish, and mostly scores the practices in the first table. | You want the badge. Copy ReLab's `scorecard.yml`. |
| Renovate from Actions | Needs a GitHub App and two secrets. Dependabot needs neither and covers every ecosystem here, including hook revs. | You need automerge or grouping Dependabot can't express. |
| release-please | Research repos release rarely, and Zenodo archives a tagged release. A release PR on every push is noise. | Releases become frequent enough that writing the changelog by hand costs time. |
| Secret scan over full history | GitHub secret scanning and push protection cover public repos at no cost. The hook covers local commits. | The repo is private without GitHub Advanced Security. |
| Scheduled audit job | The stack workflows audit on every push and PR (`uv audit`, `pnpm audit --prod`, `cargo deny check`, `govulncheck`), and Dependabot security alerts cover the time between. | A dependency sits unchanged for months in a repo with few pushes. |
| One required "CI result" job | A single workflow per stack is short enough to list its jobs in branch protection. | The job list grows past what you want to maintain by hand. |
| CODEOWNERS, issue templates, CONTRIBUTING | Single-author repos. | Other people start contributing. |

## Caveats

- Dependency review needs the dependency graph. It is on by default for public repos.
  A private repo needs GitHub Advanced Security, or the job fails.
- zizmor needs a token for its online audits: impostor commits and known-vulnerable actions. The
  hooks job passes the read-only `github.token`. Locally, set `GH_TOKEN` to get them;
  without it, the offline subset runs.
- The `data-pipeline` kind fetches its sources' live URLs in CI, this template's own CI
  included. A publisher outage or a moved file fails the run whatever the diff; re-run it.
- This template's own CI renders the templates with `scripts/check-render.sh`. Then it
  runs zizmor, actionlint, and the CITATION.cff schema check over the output, because
  `.jinja` files aren't YAML.
