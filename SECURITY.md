# Security

## Report a vulnerability

Report it privately through GitHub:
[open a private advisory](https://github.com/simonvanlierde/project-templates/security/advisories/new).
Don't open a public issue or pull request for it: anyone can read those before there is a fix.

Please include:

- What the problem is and where: a file in `template/`, a workflow it renders, or this
  repository's own CI.
- The copier answers that produce it, or the rendered file, and how to reproduce it.
- The impact you expect on a generated project.

I acknowledge a report within 14 days, then tell you whether I can reproduce it and when I
expect a fix.

## Fixes and disclosure

A fix ships in a new tagged release, and generated projects receive it with
`copier update`. When the release is out, I publish the GitHub security advisory for it,
with a CVE where one applies, and credit you unless you'd rather not be named. The
CHANGELOG entry for that release links the advisory.

## Verify a release

Releases from v0.8.1 on are immutable: once one is published, no one can add or change its
files, or move or delete its tag. GitHub also signs an attestation for each one. Check it
with:

```sh
gh release verify vX.Y.Z --repo simonvanlierde/project-templates
```

A pass proves that GitHub's release service signed a statement that release `vX.Y.Z` of
this repository points at the commit the command prints. It proves where the release came
from, not that its code is safe. The signing key belongs to GitHub, not to a maintainer.
Releases up to v0.8.0 came before immutable releases and have no attestation.

From v0.11.0 on, the maintainer also signs each tag with his own key, and GitHub shows it
as Verified. The release workflow refuses a tag it can't verify.

Releases here attach no files. Where a release does attach one, such as a generated
project's Python release, `gh release verify-asset vX.Y.Z <file>` checks a downloaded copy
against the release's attestation.

## What the template promises

A fresh render:

- runs no workflow on `pull_request_target` or `workflow_run`, so code from a fork never
  runs with write access;
- gives each workflow read-only permissions unless a job needs more, and gives a
  publishing token only to the job that uploads;
- pins every action to a full commit SHA and keeps the token out of checkouts.

It does not promise that the tools it installs are free of vulnerabilities, that a project
stays safe after its own changes, or the repository settings a render can't create, such as
environment rules and branch protection. [docs/design.md](docs/design.md#security-assessment)
lists the main threats and what limits each one.

## Scope

In scope:

- The files in `template/` and what they render: workflows, hooks, configs and scripts.
- The questions and their validation in `copier.yml`.
- This repository's own CI and release workflows.

Out of scope:

- A vulnerability in a tool the template installs or runs, such as copier, uv, pnpm or
  an action. Report it upstream; a pin or setting the template should change is in scope.
- Code a project wrote after it was generated.

[docs/design.md](docs/design.md) describes who acts on a generated project and which
workflows get a publishing token.
