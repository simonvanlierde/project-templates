# Task runner: https://just.systems. `just` lists the recipes, `just <name>` runs one.

# List the recipes (what a bare `just` runs).
default:
    @just --list

# CI is the source of truth and also runs zizmor, actionlint and the generated
# projects' own checks, which are too slow for here.

# Run the git hooks, render checks and strict docs build before you push.
check: hooks render docs chooser

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

# Write the Levels table in docs/levels.md from levels.toml; `--check` fails when it is stale.
levels-doc *args:
    uv run scripts/levels_doc.py {{ args }}

# Check a repo against levels.toml and print its results as JSON (docs/levels.md#checking-a-repo).
check-level *args:
    uv run scripts/check_level.py {{ args }}

# Keep the docs builder on the version that new projects receive.
zensical_version := `sed -n '/^zensical_version:/,/^$/s/^  default: //p' copier.yml`

# Build docs/ into _docs/; warnings fail the build.
docs:
    uvx --exclude-newer "1 week" zensical@{{zensical_version}} build --strict

playwright_version := `sed -n '/^playwright_version:/,/^$/s/^  default: //p' copier.yml`

# Render scripts/og-card.html to docs/assets/og.png and put its hash in the og:image URL,
# since link previews cache by URL. Needs Chromium: `pnpm dlx playwright@<version> install chromium`.
og-card:
    pnpm dlx playwright@{{ playwright_version }} screenshot --viewport-size=1200,630 "file://$PWD/scripts/og-card.html" "$PWD/docs/assets/og.png"
    sed -E -i.bak "s/og\.png(\?v=[0-9a-f]+)?\"/og.png?v=$(shasum -a 256 docs/assets/og.png | cut -c1-8)\"/" zensical.toml && rm zensical.toml.bak

# Serve docs/ at http://localhost:8000, rebuilt on each save.
docs-serve:
    uvx --exclude-newer "1 week" zensical@{{zensical_version}} serve

# Check chooser recommendations against the released template and the current code.
chooser:
    node --test scripts/test-chooser.mjs
    node scripts/check-chooser-renders.mjs
