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
