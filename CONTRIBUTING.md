# Working on the template

## Test an untagged change

Copier renders the latest tag by default, so your edits never reach the output until
you tag them. To render your working copy instead, pass `--vcs-ref=HEAD`:

```sh
copier copy --vcs-ref=HEAD gh:simonvanlierde/project-templates .
```

## Run the checks before you push

Run the git hooks and the same render checks CI runs. The render script includes
uncommitted edits:

```sh
prek run -a
scripts/check-render.sh "$(mktemp -d)"
```

## Tag every change

`copier update` in a generated project only sees tagged releases. Tag this repository
after each change you want projects to receive, and add an entry to
[CHANGELOG.md](CHANGELOG.md). Its introduction says which part of the version to bump.

## Write pull requests for any reader

This repository is public. A pull request body is one line on its purpose and a few
bullets on what changed. Leave out steps for the maintainer, such as tagging after the
merge, and long check logs.

## How the answers file records the source

A render from a local checkout writes `_src_path` and `_commit` into the project's
`.copier-answers.yml`. What it writes depends on what you rendered:

- **A tag.** `_src_path` is `gh:simonvanlierde/project-templates`, not the local path.
  A local path would leak your home directory and break `copier update` on every other
  machine.
- **Any other commit.** `_src_path` stays the local path, because that commit may not
  exist on GitHub. `_commit` is the checkout's commit. `copier update` can't check out
  a commit that exists only on your machine (an unpushed tag, a deleted branch) or
  only in a fork.

Before you commit the answers file of a real project, render from a tag that is pushed
to this repository. Otherwise, edit `_src_path` and `_commit` by hand.

To test an update against a local checkout, set `_src_path` to the checkout's path for
that run. The CI `update` job does the same.
