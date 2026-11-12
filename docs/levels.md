# Levels

`level` sets how much a public repo commits to. Each level adds requirements to the one below it:

- `minimal`: a public repo with few users. Locked and updated dependencies, hardened workflows, the Scorecard workflow and `SECURITY.md`.
- `standard`, the default: every `minimal` and `standard` requirement that applies to the repo. The render adds the test policy and coding standards to `.github/CONTRIBUTING.md`, a `## Usage` section to a new render's README, `.github/first-release.md` with the OpenSSF badge step ([OpenSSF badge](#openssf-best-practices-badge)), and `cold-install.yml`.
- `community`: a repo that wants outside contributors. The render adds `GOVERNANCE.md`, `docs/roadmap.md`, `docs/assurance-case.md` and `docs/decisions/`, and the `dco` workflow, which every public repo gets, checks every pull request, maintainers' included.

A private repo, or a public one without a license, is not on the ladder: copier skips the question.

To move a project to another level, run `copier update --data level=community`. An update of a project made before 0.15.0 starts from its old `openssf_badge` answer: `none` becomes `minimal`, `passing` becomes `standard` and `silver` becomes `community`.

## Requirements

A requirement applies to every repo, or only to repos with one of its traits. The template derives the traits from your answers:

| Trait | Applies when |
| --- | --- |
| `web` | `ts_kind=web-app`, or a `site` |
| `cli` | A Rust or Go binary, or a Python `data-pipeline` (the computed `cli` answer) |
| `package` | `publish_to_pypi`, `publish_to_npm`, or `rust_kind=library` (a crate for crates.io) |
| `pipeline` | `python_kind=data-pipeline` |
| `numerics` | `python_kind=research` |

The requirements live in [`levels.toml`](https://github.com/simonvanlierde/project-templates/blob/main/levels.toml), and `just levels-doc` writes the table below from it. A repo meets a level when it meets every requirement that applies to it at that level and below. "Counts from" is the date a requirement starts to count: before then, a tool that reads `levels.toml` may list it without counting it, which gives repos time to catch up. The file's version is the newest template release, so a repo can say which version of the ladder it meets.

The table says what a repo must have to meet a level, not only what the render adds. Every level also gets the files the template always renders, such as `.github/CONTRIBUTING.md`, the issue forms and the citation files. A fresh render meets each `automated` requirement at its level. The `review` ones need you, and `docs-site` needs `docs_site` in `extras` once its trigger holds.

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

## Checking a repo

`just check-level <path>` checks a checkout against `levels.toml` and prints JSON. It reads the level and traits from the repo's `.copier-answers.yml`. For a repo without one, pass `--level standard` and a `--trait` for each trait. From another folder, run `uv run <this repo>/scripts/check_level.py <path>`. It reads files only: it makes no network calls and runs no tools.

Each requirement gets one status:

- `met`: the evidence names the files that meet it.
- `missing`: the evidence says what is missing.
- `not_applicable`: the requirement is above the repo's level, is for traits the repo lacks, or its condition does not hold, such as `lockfile` in a repo with no `pyproject.toml` or `package.json`.
- `unchecked`: a person has to judge it (`verify = "review"`), or the facts are not in the files: the live site's headers, sp-repo-review's results, whether a linked issue is open, release signatures.

```json
{
  "schema_version": 1,
  "repo": "tide-tables",
  "level": "standard",
  "traits": ["numerics"],
  "levels_version": "0.14.0",
  "checked_at": "2027-03-01T09:30:00Z",
  "requirements": [
    {"id": "lockfile", "area": "supply-chain", "level": "minimal", "since": "2026-11-11", "status": "met", "evidence": "uv.lock"}
  ]
}
```

[`scripts/check_level.schema.json`](https://github.com/simonvanlierde/project-templates/blob/main/scripts/check_level.schema.json) is the schema. A new field does not change `schema_version`; a breaking change does. The script exits 0 when it prints a report, whatever the report finds, 2 on a bad flag and 3 when it cannot read the repo or `levels.toml`.

## OpenSSF Best Practices badge

The level prepares a public, licensed repo for a level of the [OpenSSF Best Practices badge](https://www.bestpractices.dev): `standard` for passing, `community` for silver, and `minimal` for neither.

[Levels](#requirements) lists what each level adds. For the badge, the `## Usage` section of `README.md` links the releases and the package registry, with a TODO for what the software does and how to use it. The `dco-signoff` commit-msg hook (`git commit -s`) comes with every public render.

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

## Scientific Python repo-review

A project with the python stack runs [sp-repo-review](https://learn.scientific-python.org/development/guides/repo-review/) as a git hook. It checks `pyproject.toml`, the pytest settings, the hooks and the workflows against the Scientific Python development guide, and fails on any check the project has not chosen to skip.

The checks the template skips on purpose are under `[tool.repo-review.ignore]` in `pyproject.toml`, each with its reason: `just` instead of nox, ruff and ty as local hooks, no reStructuredText, no pre-commit.ci. To skip another, add its code and a reason there. Run it on its own with `prek run sp-repo-review --all-files`.
