# Governance

project-templates has one maintainer, Simon van Lierde
([@simonvanlierde](https://github.com/simonvanlierde)). This file says who decides, who has
access, and what happens if he is unavailable.

## Who decides

The maintainer decides what goes into the template and when to release it, reviews and
merges pull requests, triages issues and handles security reports as
[SECURITY.md](SECURITY.md) says.

Anyone can propose a change in an issue or a pull request, and it is discussed there in the
open. [CONTRIBUTING.md](CONTRIBUTING.md) says how to make one, and
[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) covers how people treat each other. When the
maintainer turns a proposal down, he says why in the issue or pull request. [docs/design.md](docs/design.md)
records the design: who acts on a generated project and what render and update do. The
planned work is in the [roadmap](ROADMAP.md).

## Who has access

- **Repository:** only the maintainer has write and admin access. A ruleset on `main`
  requires a pull request, the required checks and a linear history, and blocks
  force-pushes and deletion. Other contributors send changes as pull requests.
- **Releases:** the only thing this repository publishes is a GitHub release. Pushing a
  `vX.Y.Z` tag runs `release.yml`, which creates the release from that version's
  [CHANGELOG.md](CHANGELOG.md) section. A tag ruleset lets only repository admins create,
  move or delete a `v*` tag, so only the maintainer can release. Nothing is published to
  PyPI, npm or a container registry: generated projects publish their own packages.
- **Bots:** the hosted Renovate app opens dependency updates, and GitHub's auto-merge lands
  its non-major updates once every required check passes, as CONTRIBUTING.md says.

## If the maintainer is unavailable

Simon's GitHub account has a named successor, who can take over his repositories. The
repository depends on no account outside GitHub: the workflows use only the token GitHub
gives each run, and store no other secret. The recovery details for that account are in an
emergency-access vault.

The code, the release history and the docs are public under the MIT license, so anyone can
also fork the template. Projects already generated keep working without it; only
`copier update` needs the repository.

## Changes to this file

The maintainer changes this file through a pull request, like any other change. If more
people get access, this file will name them and their role first.
