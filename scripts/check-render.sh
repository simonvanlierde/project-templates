#!/usr/bin/env bash
# Renders the branches the default answers reach, which CI's stack jobs skip,
# and checks that each conditional branch landed. The CI render job runs this;
# so can you, from the repo root: scripts/check-render.sh "$(mktemp -d)"
#
# Renders HEAD with uncommitted edits (--vcs-ref=HEAD), so run it before you
# commit. COPIER_VERSION pins copier, as CI does; unset, uvx takes the latest.
set -euo pipefail

out=${1:?usage: scripts/check-render.sh OUT_DIR}
copier=(uvx "copier${COPIER_VERSION:+@$COPIER_VERSION}" copy --defaults --overwrite)

# a: all three stacks at once, everything else at its defaults. module_name is
# withheld so its slug-derived default is what renders.
"${copier[@]}" --vcs-ref=HEAD \
  --data project_name=render-me --data 'stacks=[python,ts,docker]' \
  --data kind=research --data ts_kind=app \
  --data 'docker_stacks=[python]' . "$out/a"

# b: license=none, plus a name and description carrying the punctuation `slug`
# strips and `to_json` escapes.
"${copier[@]}" --vcs-ref=HEAD \
  --data 'project_name=Odd "Name" & Co!' \
  --data 'project_description=A "quoted" one' \
  --data license=none --data 'stacks=[ts,docker]' \
  --data 'docker_stacks=[ts]' . "$out/b"

# c: the only render with nested paths, at two depths to catch hardcoded
# up-paths. All three publish flags on: the only render where the two release
# workflows could collide, and where docker.yml grows its pushing half.
"${copier[@]}" --vcs-ref=HEAD \
  --data project_name=mono-me --data 'stacks=[python,ts,docker]' \
  --data python_dir=api --data ts_dir=apps/web \
  --data publish_to_pypi=true --data publish_to_npm=true \
  --data 'docker_stacks=[python,ts]' --data publish_to_ghcr=true . "$out/c"

# d: data-pipeline nested and beside docker: the nested paths reach .gitignore,
# the workflow's artifact path and ATTRIBUTION.md.
"${copier[@]}" --vcs-ref=HEAD \
  --data project_name=pipe-me --data 'stacks=[python,docker]' \
  --data kind=data-pipeline --data python_dir=pipe \
  --data 'docker_stacks=[python]' . "$out/d"

# e: released scaffolds come from a tag, which the renders above are not. A
# throwaway local tag on HEAD stands in for one.
git tag check-render-tag
# -C: the checks below cd out of the repo before this fires.
repo=$PWD
trap 'git -C "$repo" tag -d check-render-tag >/dev/null' EXIT
"${copier[@]}" --vcs-ref=check-render-tag \
  --data project_name=tag-me --data 'stacks=[python]' . "$out/e"

OUT=$out uv run --no-project --with pyyaml python - <<'PY'
import json, os, pathlib, tomllib, yaml

load = {".json": json.loads, ".toml": tomllib.loads,
        ".yml": yaml.safe_load, ".yaml": yaml.safe_load}
seen = 0
for path in sorted(pathlib.Path(os.environ["OUT"]).glob("[abcd]/**/*")):
    parse = load.get(path.suffix)
    if parse and path.is_file():
        parse(path.read_text())
        seen += 1
print(f"parsed {seen} files")
# A copier run that silently rendered nothing would otherwise pass.
assert seen > 20, f"only {seen} structured files rendered"
PY

# A bare `! cmd` never trips set -e; the negated subshells below do.
cd "$out"
# kind=research adds two dirs; publishing off on both stacks removes both
# release workflows.
test -f a/data/README.md
test -f a/notebooks/.gitkeep
test ! -e a/.github/workflows/python-release.yml
test ! -e a/.github/workflows/ts-release.yml
grep -q 'Private :: Do Not Upload' a/pyproject.toml
grep -q '"private": true' a/package.json
# module_name fell back to its slug-derived default.
test -f a/src/render_me/__main__.py
# The .vscode files rendered valid recommendations per stack.
grep -q charliermarsh.ruff a/.vscode/extensions.json
grep -q biomejs.biome a/.vscode/settings.json
test -f a/.github/SECURITY.md
# Every render gets the hooks enforced in CI.
test -f a/.github/workflows/hygiene.yml
test -f b/.github/workflows/hygiene.yml
# CITATION.cff only for the kinds that publish research output, at the root
# even when the package is nested.
test -f a/CITATION.cff
test -f d/CITATION.cff
test ! -e b/CITATION.cff
test ! -e c/CITATION.cff
grep -q check-citation-file-format a/.pre-commit-config.yaml
(! grep -q check-citation-file-format c/.pre-commit-config.yaml)
# Rendered from a tag, the answers name the canonical source, never the local
# path. From any other commit they keep the source as given: the canonical
# source has no such commit for `copier update` to check out.
grep -qx '_src_path: gh:simonvanlierde/project-templates' e/.copier-answers.yml
grep -qx '_commit: check-render-tag' e/.copier-answers.yml
(! grep -q '^_src_path: gh:' a/.copier-answers.yml)
# All three stacks at once: every hook block present together.
grep -q hadolint a/.pre-commit-config.yaml
grep -q 'ruff check' a/.pre-commit-config.yaml
grep -q 'biome check' a/.pre-commit-config.yaml
# license=none: no file, and no license key in either place that carries one.
test ! -e b/LICENSE
(! grep -q '"license"' b/package.json)
(! grep -q 'image.licenses' b/Dockerfile)
# The awkward project name reduced to something npm will accept.
grep -q '"name": "odd-name--co"' b/package.json
# Monorepo: packages nested, root files at the root, one Dockerfile per context.
test -f c/api/pyproject.toml
test -f c/apps/web/package.json
test -f c/api/Dockerfile
test -f c/apps/web/Dockerfile
test -f c/compose.yaml
test -f c/.github/workflows/python.yml
test ! -e c/pyproject.toml
grep -q 'working-directory: api' c/.github/workflows/python.yml
grep -q 'context: apps/web' c/compose.yaml
grep -q 'uv --directory api' c/just/python.just
# Both stacks publishing: two release workflows, neither overwritten.
test -f c/.github/workflows/python-release.yml
test -f c/.github/workflows/ts-release.yml
# publish_to_ghcr=true: docker.yml rendered its pushing half.
grep -q 'packages: write' c/.github/workflows/docker.yml
# The depth-derived up-paths, at both depths this render uses.
grep -qF '](../README.md)' c/api/README.md
grep -qF '"root": "../.."' c/apps/web/biome.json
# data-pipeline: manifest and data dirs in the package, the rest at the root.
test -f d/pipe/sources.toml
test -f d/pipe/src/pipe_me/pipeline.py
test -f d/pipe/data/raw/.gitkeep
test -f d/ATTRIBUTION.md
grep -qF '](pipe/sources.toml)' d/ATTRIBUTION.md
grep -qF '](pipe/sources.toml)' d/README.md
test ! -e d/pipe/notebooks
grep -qx 'pipe/data/raw/\*' d/.gitignore
grep -q 'path: pipe/data/raw/\*.fetch.json' d/.github/workflows/python.yml
grep -q '^pipeline: fetch build validate' d/just/python.just
# Only data-pipeline renders it.
test ! -e a/sources.toml
test ! -e a/ATTRIBUTION.md
# Only web-service renders the FastAPI modules; the others keep the stdlib
# /health stub.
test ! -e a/src/render_me/app.py
(! grep -q fastapi a/pyproject.toml)
grep -q http.server a/src/render_me/__main__.py

echo "all render checks passed"
