# Task runner: https://just.systems. `just` lists the recipes, `just <name>` runs one.

# List the recipes (what a bare `just` runs).
default:
    @just --list

# What a contributor runs before pushing: the git hooks, then the render checks. CI is
# the source of truth and also runs zizmor, jactionlint and the generated projects' own
# checks, which are too slow for here.
check: hooks render

# Run every git hook over the whole repo, as the `git hooks` job does.
hooks:
    prek run -a

# Render the answer sets in scripts/check-render.sh into a temp dir and check the output.
# The render includes uncommitted edits. Its commit tag is shared by every worktree of
# this repo, so don't run it in two worktrees at once.
render:
    #!/usr/bin/env bash
    set -euo pipefail
    out=$(mktemp -d)
    trap 'rm -rf "$out"' EXIT
    scripts/check-render.sh "$out"
