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

## Render real projects from a pushed tag

A render from a local checkout records its source in the project's
`.copier-answers.yml`. From a tag, `_src_path` becomes
`gh:simonvanlierde/project-templates`, so `copier update` works on any machine. From any
other commit, it keeps your local path, which leaks your home directory and breaks
`copier update` everywhere else. So render a real project from a tag pushed to this
repository, or fix `_src_path` and `_commit` by hand.

To test an update against a local checkout, point `_src_path` at it for that run, as
the CI `update` job does.
