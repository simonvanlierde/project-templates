# Working on the template

You need [uv](https://docs.astral.sh/uv/) (it runs copier), [just](https://just.systems),
git, and prek for the hooks (`uv tool install prek`, then `prek install`).

## Test an untagged change

Copier renders the latest tag by default, so your edits don't show up until you tag
them. To render your working copy, including uncommitted edits, pass `--vcs-ref=HEAD`.
Point `COPIER_SETTINGS_PATH` at the CI settings file. It fills the identity answers that
have no default, and `--defaults` stops at them without it. For this run it replaces your
own copier settings.

```sh
export COPIER_SETTINGS_PATH=$PWD/.github/ci-copier-settings.yml
copier copy --defaults --vcs-ref=HEAD . "$(mktemp -d)"
```

Drop `--defaults` to answer the questions yourself. Don't render into the repository
root: the output would land among the template files.

## Run the checks before you push

Run the git hooks and the render checks CI runs. The render script includes uncommitted
edits. CI also runs zizmor, jactionlint and the CITATION.cff schema check on the rendered
output, because `.jinja` files aren't YAML:

```sh
prek run -a
scripts/check-render.sh "$(mktemp -d)"
```

The render script checks which files each answer set produces. It doesn't run the
generated projects' own checks. CI does that for each stack and kind. To run one locally,
render into a directory and check it there:

```sh
out=$(mktemp -d) && scripts/check-render.sh "$out"
cd "$out/a" && git init -q && just py-sync check
```

## Tag every change

`copier update` in a generated project only sees tagged releases. Tag this repository
after each change you want projects to receive, and add an entry to
[CHANGELOG.md](CHANGELOG.md). Its introduction says which part of the version to bump.

Before you tag, move the `[Unreleased]` entries under a `## [X.Y.Z] - YYYY-MM-DD`
heading and add its compare link. Pushing the tag `vX.Y.Z` runs the release workflow,
which publishes a GitHub release with that section as its notes. A tag with no section
fails the workflow and publishes nothing. Releases here are immutable, so don't create
one by hand first: the workflow leaves an existing release as it is.

## Write pull requests for any reader

Commit messages and the pull request title, which becomes the squash commit subject, follow
[committed.toml](committed.toml): Conventional Commits, an imperative lower-case summary, no
period. The commit-msg hook checks each commit and the `pr title` workflow checks the title.

This repository is public. A pull request body is one line on its purpose and a few
bullets on what changed. Leave out steps for the maintainer, such as tagging after the
merge, and long check logs.

## Render real projects from a pushed tag

Rendered from a tag, `.copier-answers.yml` records `_src_path` as
`gh:simonvanlierde/project-templates`, so `copier update` works on any machine. Rendered
from any other local commit, it keeps your local path. That leaks your home directory and
breaks `copier update` everywhere else. Render a real project from a pushed tag, or fix
`_src_path` and `_commit` by hand.

To test an update against a local checkout, point `_src_path` at it for that run, as
the CI `update` job does.
