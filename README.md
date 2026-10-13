# project-templates

[![Copier](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/copier-org/copier/master/img/badge/badge-black.json)](https://github.com/copier-org/copier)
[![CI](https://github.com/simonvanlierde/project-templates/actions/workflows/ci.yml/badge.svg)](https://github.com/simonvanlierde/project-templates/actions/workflows/ci.yml)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![release](https://img.shields.io/github/v/release/simonvanlierde/project-templates)](https://github.com/simonvanlierde/project-templates/releases/latest)

Start a new project with linting, tests, CI and releases already set up.

This is a [Copier](https://copier.readthedocs.io) template. You answer a few questions,
and it writes a ready-to-commit repository for Python, TypeScript, Rust, Go, Docker, or
any mix of them. When the template improves later, one command pulls the changes into
your project.

You get a passing test on day one, `just check` running the same checks as CI, actions
pinned to exact commits, and optional release workflows for PyPI, npm and the GitHub
Container Registry with no tokens to store.

## Quick start

You need [Copier](https://copier.readthedocs.io/en/stable/#installation) 9.1 or later
and [just](https://just.systems). Each language also needs its own toolchain: `uv` for
Python, `pnpm` for TypeScript, `cargo` for Rust, or `go` for Go.

```sh
mkdir myproject && cd myproject && git init
copier copy gh:simonvanlierde/project-templates .
just py-sync   # run the *-sync line for each stack you picked: py, ts, go, rs
just check     # every linter and test; Rust and Go need a few tools first, see the new README
git add -A && git commit -m "chore: scaffold"
```

Commit the lockfiles: CI installs exactly what they list, so it fails without them.
Later, `copier update` pulls in template changes, and [CHANGELOG.md](CHANGELOG.md)
lists what each release changes.

### Your details

Copier asks for your GitHub user, name and email, and for some Python kinds your ORCID
iD. They have no defaults, so nobody publishes the template author's details by
accident. To skip the questions, save your answers once in Copier's
[settings file](https://copier.readthedocs.io/en/stable/settings/):
`~/.config/copier/settings.yml` on Linux, `~/Library/Application Support/copier/settings.yml`
on macOS, or wherever `COPIER_SETTINGS_PATH` points.

```yaml
defaults:
  github_user: your-github-name
  author_name: Your Name
  author_email: you@example.com
  author_orcid: "0000-0000-0000-0000"
```

## More

- [docs/usage.md](docs/usage.md): the stacks, monorepos, updating, publishing and Codecov.
- [docs/python-kinds.md](docs/python-kinds.md): the Python project kinds.
- [docs/tooling.md](docs/tooling.md): the tools, lint policies, Docker images,
  dependency updates and release workflows.
- [docs/ci-baseline.md](docs/ci-baseline.md): every CI check, and what was left out.
- [CONTRIBUTING.md](CONTRIBUTING.md): how to test a template change before you tag it.
- [SECURITY.md](SECURITY.md): how to report a vulnerability.
