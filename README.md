# project-templates

[![Copier](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/copier-org/copier/master/img/badge/badge-black.json)](https://github.com/copier-org/copier)
[![CI](https://github.com/simonvanlierde/project-templates/actions/workflows/ci.yml/badge.svg)](https://github.com/simonvanlierde/project-templates/actions/workflows/ci.yml)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![release](https://img.shields.io/github/v/release/simonvanlierde/project-templates)](https://github.com/simonvanlierde/project-templates/releases/latest)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/simonvanlierde/project-templates/badge)](https://scorecard.dev/viewer/?uri=github.com/simonvanlierde/project-templates)
[![OpenSSF Best Practices](https://www.bestpractices.dev/projects/16002/badge)](https://www.bestpractices.dev/projects/16002)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.23701980.svg)](https://doi.org/10.5281/zenodo.23701980)

Start a Python, TypeScript, Rust, Go or Docker repo that is secure by default and kept
current by a weekly update PR. Research code comes citable: `CITATION.cff`, a Zenodo DOI
and a Software Heritage archive from the first release.

This is a [Copier](https://copier.readthedocs.io) template. Combine the stacks as your
project needs ([quick start](#quick-start)). The [documentation site](https://simonvanlierde.com/project-templates/)
has the guides and a chooser that suggests a project type. Every project gets:

- a passing test on day one;
- `just check`, which runs the same checks as CI;
- actions pinned to exact commits;
- optional releases to PyPI, npm and the GitHub Container Registry, with no tokens to store.

When the template improves, `copier update` pulls the changes in.

## Data pipelines

The `data-pipeline` kind builds a dataset from public sources, and every row says which
download it came from. The Python project centres on one manifest, `sources.toml`.
`just fetch`, `just build` and `just validate` run [sourceledger](https://github.com/simonvanlierde/sourceledger)
over it: they record each download's URL, hash and date, stamp every output row with
that record, and fail when an output is stale or a source has no reuse terms. A row of
`data/processed/example-co2.parquet`:

| source_id | source_url | retrieved_at | vintage | raw_sha256 | Year | Mean | Uncertainty |
| --- | --- | --- | --- | --- | --- | --- | --- |
| example-co2 | `https://raw.githubusercontent.com/datasets/co2-ppm/8c40972…/co2-annmean-mlo.csv` | 2026-10-17T22:30:03Z | datasets/co2-ppm commit 8c40972 | `b1548ededea6f9b7eecac370753de8d8da6e0afafe1041f749a11db78c2e33c4` | 1959 | 315.98 | 0.12 |

The raw and processed data stay out of git, so the repository never redistributes a
source. [Python project kinds](https://simonvanlierde.com/project-templates/python-kinds/#data-pipeline)
lists the files, the CI checks and how to swap in your own sources.

## Quick start

A data pipeline needs [Copier](https://copier.readthedocs.io/en/stable/#installation)
9.19 or later, [just](https://just.systems) and [uv](https://docs.astral.sh/uv/). Without
Copier installed, `uvx copier` runs it through uv.

```sh
mkdir mydata && cd mydata && git init
copier copy --data 'stacks=[python]' --data kind=data-pipeline gh:simonvanlierde/project-templates .
just pipeline  # fetch, build and validate the example source
just check
git add -A && git commit -m "chore: scaffold"
```

Then replace the example source in `sources.toml` with your own.

### Any other project

Leave out the `--data` answers and Copier asks which stacks and kinds you want
([the questions](docs/usage.md#the-questions) says what each does). Each stack needs its
own toolchain: `uv` for Python, `pnpm` for TypeScript, `cargo` for Rust, `go` for Go.

```sh
mkdir myproject && cd myproject && git init
copier copy gh:simonvanlierde/project-templates .
just py-sync   # Copier prints these steps for the stacks you picked
just check     # every linter and test; Rust and Go need a few tools first, see the new README
git add -A && git commit -m "chore: scaffold"
```

Commit the lockfiles: CI installs exactly what they list, so it fails without them.
After the first push, run `just repo-settings` to protect `main`
([what it sets](docs/setup.md#protecting-main)).

### Updating

`copier update` pulls a new template release into your project as a merge, and a weekly
workflow opens that pull request for you
([how](docs/updates.md#keeping-your-project-up-to-date)). [CHANGELOG.md](CHANGELOG.md) lists
what each release changes and the upgrade steps a breaking one needs.

### Your details

Copier asks for your GitHub user, name and email. A licensed library, or a Python
research or data-pipeline project, also asks for your ORCID iD. These answers have no
defaults, so nobody publishes the template author's details by accident. To have Copier
fill them in, save them once in its
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

## Docs

The [documentation site](https://simonvanlierde.com/project-templates/) has the guides: [help me choose](https://simonvanlierde.com/project-templates/choose/),
[the questions and settings](https://simonvanlierde.com/project-templates/usage/), [setting up the repo](https://simonvanlierde.com/project-templates/setup/),
[updates](https://simonvanlierde.com/project-templates/updates/), [levels](https://simonvanlierde.com/project-templates/levels/) and the [tools per stack](https://simonvanlierde.com/project-templates/tooling/).

## About this project

- [CONTRIBUTING.md](CONTRIBUTING.md): how to test a template change before you tag it.
- [docs/design.md](docs/design.md): who can change what, the workflows that can publish,
  and the security assurance case.
- [docs/decisions/](docs/decisions/README.md): the decisions behind the template's shape.
- [SECURITY.md](SECURITY.md): how to report a vulnerability and verify a release.
- [GOVERNANCE.md](GOVERNANCE.md): who decides, who can release, and who takes over.
- [Roadmap](https://simonvanlierde.com/project-templates/roadmap/): what is planned for the next year.
- [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md): how people treat each other here.
