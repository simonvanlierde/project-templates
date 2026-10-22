# Working on the template

To report a bug or ask for a feature, open an
[issue](https://github.com/simonvanlierde/project-templates/issues) with the copier
answers you used and what the render did. Report a vulnerability as
[SECURITY.md](SECURITY.md) says, not in an issue. [docs/design.md](docs/design.md)
describes who acts on a generated project and what render and update do.

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
cd "$out/a" && git init -q && just py-sync py-check
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
[committed.toml](committed.toml): Conventional Commits, an imperative summary, no period.
The commit-msg hook checks each commit and the `pull request title` check checks the title.
Write the summary in lower case too; nothing checks that. A revert is titled
`revert: <original subject>`: rename the `Revert "..."` title that GitHub's Revert button
writes, or the check fails.

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

## Sign off your commits

Every commit in a pull request carries a `Signed-off-by:` line, which says you wrote the
change or have the right to submit it under the MIT license: the
[Developer Certificate of Origin 1.1](https://developercertificate.org/). `git commit -s`
adds it. To add it to commits you already made, run `git rebase --signoff upstream/main`
(the branch you started from) and force-push the branch. The `dco` workflow fails a pull
request from a fork with a commit that lacks it. Pull requests from a branch in this
repository skip it.

## How pull requests merge

A ruleset on `main` requires the `ci ok`, `git hooks`, `renovate extract` and `DCO sign-off`
checks. GitHub's auto-merge lands a pull request once they pass, which is also how Renovate's
non-major updates merge.

## Who maintains this

Simon van Lierde ([@simonvanlierde](https://github.com/simonvanlierde)) maintains the
template: reviews and merges pull requests, and tags releases. Only he can merge to `main`.
A new maintainer would be named here
first. If he stops maintaining it, the README says so and the repository is archived;
anyone may fork it under the MIT license.
