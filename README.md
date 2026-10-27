# project-templates

[![Copier](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/copier-org/copier/master/img/badge/badge-black.json)](https://github.com/copier-org/copier)
[![CI](https://github.com/simonvanlierde/project-templates/actions/workflows/ci.yml/badge.svg)](https://github.com/simonvanlierde/project-templates/actions/workflows/ci.yml)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![release](https://img.shields.io/github/v/release/simonvanlierde/project-templates)](https://github.com/simonvanlierde/project-templates/releases/latest)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/simonvanlierde/project-templates/badge)](https://scorecard.dev/viewer/?uri=github.com/simonvanlierde/project-templates)
[![OpenSSF Best Practices](https://www.bestpractices.dev/projects/16002/badge)](https://www.bestpractices.dev/projects/16002)

Build a dataset from public sources where every row says which download it came from.

This is a [Copier](https://copier.readthedocs.io) template. Its `data-pipeline` kind
writes a Python project around one manifest, `sources.toml`, which lists each input with
its URL and the publisher's reuse terms. Three steps from the
[sourceledger](https://github.com/simonvanlierde/sourceledger) library then run over it:

- `just fetch` downloads each source and writes a record beside it: the URL, when it
  was fetched, the SHA-256 and size of the bytes, the vintage you expect, and the
  server's ETag. The next fetch asks the server whether the file changed and keeps the
  record when it has not. Each new version of a source is added to `data/fetches.jsonl`,
  a log you commit.
- `just build` re-hashes each download against its record before it parses it, and
  stamps every output row with that record.
- `just validate` fails when an output came from an older download, a source has no
  reuse terms, or a raw file changed after it was fetched.

A row of the example output:

```csv
source_id,source_url,retrieved_at,vintage,raw_sha256,Year,Mean,Uncertainty
example-co2,https://raw.githubusercontent.com/datasets/co2-ppm/8c4097238570147adf6fa97ad357315528dac4c5/data/co2-annmean-mlo.csv,2026-10-17T22:30:03Z,datasets/co2-ppm commit 8c40972,b1548ededea6f9b7eecac370753de8d8da6e0afafe1041f749a11db78c2e33c4,1959,315.98,0.12
```

CI runs the whole pipeline against the live URLs. A weekly run comments on an issue when
a publisher serves new bytes for a source, and fails when a value the tests pinned
changed. The raw and processed data stay out of git, so the repository never
redistributes a source. `CITATION.cff`, `.zenodo.json` and `codemeta.json` come from the
same answers, ready for a Zenodo DOI.

The same template also starts Python libraries, apps, research projects and web
services, and TypeScript, Rust, Go and Docker projects, in any mix. Each gets a passing
test on day one, `just check` running the same checks as CI, actions pinned to exact
commits, and optional releases to PyPI, npm and the GitHub Container Registry with no
tokens to store. When the template improves, `copier update` pulls the changes in.

## Quick start

A data pipeline needs [Copier](https://copier.readthedocs.io/en/stable/#installation)
9.19 or later, [just](https://just.systems) and [uv](https://docs.astral.sh/uv/):

```sh
mkdir mydata && cd mydata && git init
copier copy --data 'stacks=[python]' --data kind=data-pipeline gh:simonvanlierde/project-templates .
just pipeline  # fetch, build and validate the example source
just check
git add -A && git commit -m "chore: scaffold"
```

Then replace the example source in `sources.toml` with your own.

### Any other project

Leave out the `--data` answers and Copier asks which stacks and kinds you want. Each
language needs its own toolchain: `uv` for Python, `pnpm` for TypeScript, `cargo` for
Rust, or `go` for Go.

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
accident. To fill them in for you, save your answers once in Copier's
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

- [docs/usage.md](docs/usage.md): the stacks, monorepos, updating, publishing, Codecov and
  the OpenSSF Best Practices badge.
- [docs/python-kinds.md](docs/python-kinds.md): the Python project kinds.
- [docs/tooling.md](docs/tooling.md): the tools, lint policies, Docker images,
  dependency updates and release workflows.
- [docs/ci-baseline.md](docs/ci-baseline.md): every CI check, and what was left out.
- [docs/design.md](docs/design.md): who can change what, and the workflows that can publish.
- [docs/web-legal.md](docs/web-legal.md): tips for filling in a web app's legal pages.
- [CONTRIBUTING.md](CONTRIBUTING.md): how to test a template change before you tag it.
- [SECURITY.md](SECURITY.md): how to report a vulnerability.
