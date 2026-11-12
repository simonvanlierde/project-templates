# Task runner: https://just.systems. `just` lists the recipes, `just <name>` runs one.

# List the recipes (what a bare `just` runs).
default:
    @just --list

# CI is the source of truth and also runs zizmor, actionlint and the generated
# projects' own checks, which are too slow for here.

# Run the git hooks, render checks and strict docs build before you push.
check: hooks render docs

# Run every git hook over the whole repo, as the `git hooks` job does.
hooks:
    prek run -a

# The render includes uncommitted edits. Its commit tag is shared by every worktree of
# this repo, so don't run it in two worktrees at once.

# Render the answer sets in scripts/render/cases.sh and check the output.
render:
    #!/usr/bin/env bash
    set -euo pipefail
    out=$(mktemp -d)
    trap 'rm -rf "$out"' EXIT
    scripts/check-render.sh "$out"

# Write the Levels table in docs/usage.md from levels.toml; `--check` fails when it is stale.
levels-doc *args:
    uv run scripts/levels_doc.py {{ args }}

# Keep the docs builder on the version that new projects receive.
zensical_version := `sed -n '/^zensical_version:/,/^$/s/^  default: //p' copier.yml`

# Build docs/ into _docs/; warnings fail the build.
docs:
    uvx --exclude-newer "1 week" zensical@{{zensical_version}} build --strict

# Serve docs/ at http://localhost:8000, rebuilt on each save.
docs-serve:
    uvx --exclude-newer "1 week" zensical@{{zensical_version}} serve
