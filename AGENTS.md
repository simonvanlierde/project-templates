# AGENTS.md

Notes for coding agents working on this Copier template. `just` lists the commands.

- Edit files under `template/`, not a rendered copy. `*.jinja` files render, the others
  copy as they are. The questions and validators are in `copier.yml`.
- Test a change by rendering it: `just check` runs the git hooks and
  `scripts/check-render.sh`, which renders every answer set with `--vcs-ref=HEAD`
  (uncommitted edits included). A new question, answer or file adds a case there.
- The render script tags a commit that all worktrees of this repo share, so don't run
  it in two worktrees at once.
- A render from an untagged commit records your local path as `_src_path`. Render a
  real project from a pushed tag.
- Every change that projects should receive goes in `CHANGELOG.md` under `[Unreleased]`,
  and breaking ones are marked **Breaking**. `CONTRIBUTING.md` has the release steps.
- Commits are Conventional Commits and carry a DCO sign-off (`git commit -s`). The
  commit-msg hooks refuse the rest. Main is protected: open a pull request.
- Read `docs/decisions/README.md` before you change the template's structure. A choice
  that is costly to reverse gets a record there.
- Keep the template's own standards in step with what it renders. A hook, workflow or
  file a generated project gets is worth having here too.
