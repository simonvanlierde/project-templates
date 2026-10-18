#!/usr/bin/env bash
# Renders the answer combinations that CI's stack jobs skip, and checks that each
# conditional file landed. Run from the repo root: scripts/check-render.sh "$(mktemp -d)"
#
# Renders HEAD plus uncommitted edits (--vcs-ref=HEAD). COPIER_VERSION pins
# copier; unset, it is the version ci.yml pins.
set -euo pipefail
# A bare test or grep below fails silently under set -e; say which line tripped.
trap 'echo "check-render: failed at line $LINENO" >&2' ERR

out=${1:?usage: scripts/check-render.sh OUT_DIR}
# The identity answers have no defaults. CI's settings file fills them, and
# replaces your own copier settings for this run.
export COPIER_SETTINGS_PATH=$PWD/.github/ci-copier-settings.yml
COPIER_VERSION=${COPIER_VERSION:-$(sed -n 's/^ *COPIER_VERSION: *//p' .github/workflows/ci.yml)}
copier=(uvx "copier${COPIER_VERSION:+@$COPIER_VERSION}" copy --defaults --overwrite)

# a: every stack, other answers at their defaults. module_name is not set,
# so its slug-derived default renders.
"${copier[@]}" --vcs-ref=HEAD \
  --data project_name=render-me --data 'stacks=[python,ts,rust,go,docker]' \
  --data kind=research --data ts_kind=app \
  --data 'docker_stacks=[python]' . "$out/a"

# b: license=none, and a name and description with punctuation that `slug`
# strips and `to_json` escapes. A nested web-service beside the root ts package,
# so the name also reaches the FastAPI title as a Python literal.
"${copier[@]}" --vcs-ref=HEAD \
  --data 'project_name=Odd "Name" & Co!' \
  --data 'project_description=A "quoted" one' \
  --data license=none --data 'stacks=[python,ts,docker]' \
  --data kind=web-service --data python_dir=svc \
  --data 'docker_stacks=[python,ts]' . "$out/b"

# c: the only render with nested paths, at two depths to catch hardcoded
# up-paths. The rust crate and go module are the binary kind. Render a has the
# libraries. All publish flags on, so the release workflows could collide and
# docker.yml renders its push job. The only render with Codecov.
"${copier[@]}" --vcs-ref=HEAD \
  --data project_name=mono-me --data 'stacks=[python,ts,rust,go,docker]' \
  --data python_dir=api --data ts_dir=apps/web \
  --data rust_dir=crates/cli --data rust_kind=binary \
  --data go_dir=services/tool --data go_kind=binary \
  --data publish_to_pypi=true --data publish_to_npm=true --data codecov=true \
  --data 'docker_stacks=[python,ts]' --data publish_to_ghcr=true . "$out/c"

# d: nested data-pipeline with docker. Covers the nested paths in .gitignore, the
# workflow's artifact path and ATTRIBUTION.md. Also the only Apache-2.0 render, the
# only one with Renovate, and the only web-app: Preact, nested, so the e2e job's
# paths are audited with the rest.
"${copier[@]}" --vcs-ref=HEAD \
  --data project_name=pipe-me --data 'stacks=[python,ts,docker]' \
  --data kind=data-pipeline --data python_dir=pipe --data license=Apache-2.0 \
  --data ts_dir=web --data ts_kind=web-app --data web_framework=preact \
  --data dependency_bot=renovate \
  --data 'docker_stacks=[python]' . "$out/d"

# The web-app starter files belong to the project: rendering d again over edited
# copies keeps them (_skip_if_exists), while a template-owned file is rewritten.
echo '// project edit' >>"$out/d/web/src/App.tsx"
echo '<!-- project edit -->' >>"$out/d/web/index.html"
echo '// project edit' >>"$out/d/web/vite.config.ts"
"${copier[@]}" --vcs-ref=HEAD \
  --data project_name=pipe-me --data 'stacks=[python,ts,docker]' \
  --data kind=data-pipeline --data python_dir=pipe --data license=Apache-2.0 \
  --data ts_dir=web --data ts_kind=web-app --data web_framework=preact \
  --data dependency_bot=renovate \
  --data 'docker_stacks=[python]' . "$out/d" >/dev/null 2>&1
grep -q 'project edit' "$out/d/web/src/App.tsx"
grep -q 'project edit' "$out/d/web/index.html"
(! grep -q 'project edit' "$out/d/web/vite.config.ts")

# e: released scaffolds render from a tag. A throwaway local tag on HEAD stands
# in for one. The trap uses -C because the checks below cd out of the repo. The
# -f on `git tag` covers a killed run that left the tag behind.
repo=$PWD
trap 'git -C "$repo" tag -d check-render-tag >/dev/null 2>&1 || true' EXIT
git tag -f check-render-tag >/dev/null
"${copier[@]}" --vcs-ref=check-render-tag \
  --data project_name=tag-me --data 'stacks=[python]' . "$out/e"

# A web app is static files, so the ts image (a Node service) is refused for it.
# The grep checks the render failed for this reason, not for an unrelated break.
if "${copier[@]}" --vcs-ref=HEAD --data project_name=web-docker \
  --data 'stacks=[ts,docker]' --data ts_kind=web-app \
  --data 'docker_stacks=[ts]' . "$out/g" >"$out/g.log" 2>&1; then
  echo "rendered a ts image for a web app: the docker_stacks validator lost its web-app check" >&2
  exit 1
fi
grep -q 'A web app is static files' "$out/g.log"

# Without the settings file, --defaults must stop at the blank identity answers.
if COPIER_SETTINGS_PATH=$out/no-settings.yml "${copier[@]}" --vcs-ref=HEAD \
  --data project_name=anon-me . "$out/f" >"$out/f.log" 2>&1; then
  echo "rendered without an author: copier.yml has a personal default again" >&2
  exit 1
fi
grep -q 'Give the GitHub user or org' "$out/f.log"

OUT=$out uv run --no-project --with pyyaml --with json5 python - <<'PY'
import ast, json, json5, os, pathlib, tomllib, yaml

load = {".json": json.loads, ".json5": json5.loads, ".toml": tomllib.loads,
        ".yml": yaml.safe_load, ".yaml": yaml.safe_load}
seen = 0
out = pathlib.Path(os.environ["OUT"])
for path in sorted(out.glob("[abcd]/**/*")):
    parse = load.get(path.suffix)
    if parse and path.is_file():
        parse(path.read_text())
        seen += 1
print(f"parsed {seen} files")
# Catches a copier run that rendered nothing.
assert seen > 20, f"only {seen} structured files rendered"
# The title literal, in whichever quote style Jinja picked, evaluates back to the name.
app = next(out.glob("b/svc/src/*/app.py"))
title = next(k for k in ast.walk(ast.parse(app.read_text())) if isinstance(k, ast.keyword) and k.arg == "title")
assert ast.literal_eval(title.value) == 'Odd "Name" & Co!', ast.unparse(title.value)
# No schema covers these two, so check what Zenodo requires and the CodeMeta context.
zenodo = json.loads((out / "c/.zenodo.json").read_text())
assert {"upload_type", "title", "description", "creators", "license"} <= zenodo.keys(), zenodo
assert zenodo["creators"][0]["name"] == "Lovelace, Ada", zenodo
codemeta = json.loads((out / "a/codemeta.json").read_text())
assert codemeta["@context"] == "https://w3id.org/codemeta/4.0", codemeta
PY

# NOTE: a bare `! cmd` never trips set -e; the negated subshells below do.
cd "$out"
# kind=research adds two dirs. Publishing off removes both release workflows.
test -f a/data/README.md
test -f a/notebooks/.gitkeep
test ! -e a/.github/workflows/python-release.yml
test ! -e a/.github/workflows/ts-release.yml
grep -q 'Private :: Do Not Upload' a/pyproject.toml
grep -q '"private": true' a/package.json
# The one-week release age, in both resolvers.
grep -qx 'exclude-newer = "1 week"' a/pyproject.toml
grep -qx 'minimumReleaseAge: 10080' a/pnpm-workspace.yaml
test -f c/apps/web/pnpm-workspace.yaml
# module_name fell back to the slug-derived default.
test -f a/src/render_me/__main__.py
# .vscode recommendations per stack.
grep -q charliermarsh.ruff a/.vscode/extensions.json
grep -q biomejs.biome a/.vscode/settings.json
# TOML formats with tombi, which reads the shipped .tombi.toml; taplo would not.
grep -q tombi-toml.tombi a/.vscode/settings.json
test -f a/.github/SECURITY.md
grep -qx '## \[Unreleased\]' a/CHANGELOG.md
(! grep -rq vale a/.pre-commit-config.yaml a/.gitignore)
# Every render runs the hooks in CI.
test -f a/.github/workflows/checks.yml
test -f b/.github/workflows/checks.yml
# Citation files for the library, research and data-pipeline kinds, at the root
# even when nested.
for f in CITATION.cff .zenodo.json codemeta.json; do
  test -f "a/$f"
  test -f "c/$f"
  test -f "d/$f"
  test ! -e "b/$f"
done
grep -q check-citation-file-format c/.pre-commit-config.yaml
(! grep -q check-citation-file-format b/.pre-commit-config.yaml)
# The library (c) is tested from python_min up and declares that floor; other
# kinds pin python_version and run once.
min=$(sed -n 's/^python_min: *//p' c/.copier-answers.yml | tr -d "\"'")
grep -qx "requires-python = \">=$min\"" c/api/pyproject.toml
grep -q "python: \[\"$min\"" c/.github/workflows/python.yml
(! grep -q 'matrix' a/.github/workflows/python.yml)
# Codecov (c only): one upload per stack, from the nested paths, with a flag each,
# and the Python one from a single matrix job.
test -f c/codecov.yml
test ! -e a/codecov.yml
grep -q -- 'uv run pytest --cov --cov-report=xml' c/.github/workflows/python.yml
grep -qx '          files: api/coverage.xml' c/.github/workflows/python.yml
grep -qx "        if: matrix.python == '$(sed -n 's/^python_version: *//p' c/.copier-answers.yml | tr -d "\"'")'" c/.github/workflows/python.yml
grep -qx '          flags: python' c/.github/workflows/python.yml
grep -qx '          files: apps/web/coverage/lcov.info' c/.github/workflows/ts.yml
grep -qx '          flags: ts' c/.github/workflows/ts.yml
(! grep -q codecov a/.github/workflows/python.yml a/.github/workflows/ts.yml)
grep -qx '      - run: pnpm run test' a/.github/workflows/ts.yml
# From a tag, the answers file names the canonical source. From any other
# commit it keeps the local path, since GitHub has no such commit. HEAD may
# itself be a release tag, so render a is held to whichever its _commit is.
grep -qx '_src_path: gh:simonvanlierde/project-templates' e/.copier-answers.yml
grep -qx '_commit: check-render-tag' e/.copier-answers.yml
commit=$(sed -n 's/^_commit: //p' a/.copier-answers.yml)
# show-ref, not rev-parse: rev-parse reads a describe name such as
# refs/tags/v1.0.0-3-gabc1234 as commit abc1234, so an untagged commit passed as tagged.
if git -C "$repo" show-ref --verify -q "refs/tags/$commit"; then
  grep -qx '_src_path: gh:simonvanlierde/project-templates' a/.copier-answers.yml
else
  (! grep -q '^_src_path: gh:' a/.copier-answers.yml)
fi
# Every stack: every hook block is present.
grep -q hadolint a/.pre-commit-config.yaml
grep -q 'ruff check' a/.pre-commit-config.yaml
grep -q 'biome check' a/.pre-commit-config.yaml
grep -q 'cargo clippy' a/.pre-commit-config.yaml
grep -q rust-lang.rust-analyzer a/.vscode/extensions.json
# rust library: lib.rs, the library-only lints, and the doctest run nextest skips.
test -f a/src/lib.rs
test ! -e a/src/main.rs
grep -qx 'missing_docs = "warn"' a/Cargo.toml
grep -q 'cargo test --doc' a/just/rust.just
grep -qx '    @just rs-check' a/justfile
# go library: a package named from the slug, its Example importing it under that
# name, since render-me is not an identifier.
test -f a/go.mod
test -f a/.golangci.yml
grep -qx 'tool golang.org/x/vuln/cmd/govulncheck' a/go.mod
test -f a/renderme.go
test ! -e a/main.go
grep -qF 'renderme "github.com/example-org/render-me"' a/example_test.go
grep -qx '    @just go-check' a/justfile
grep -q 'id: golangci-lint$' a/.pre-commit-config.yaml
grep -q golang.go a/.vscode/extensions.json
grep -q 'package-ecosystem: gomod' a/.github/dependabot.yml
# dependency_bot: Dependabot by default, Renovate in d, never both.
test ! -e a/renovate.json5
test -f d/renovate.json5
test ! -e d/.github/dependabot.yml
(! grep -q working-directory a/just/go.just)
# license=none: no file and no license key.
test ! -e b/LICENSE
(! grep -q '"license"' b/package.json)
(! grep -q 'image.licenses' b/Dockerfile)
(! grep -q 'image.licenses' b/svc/Dockerfile)
(! grep -q '^license' b/svc/pyproject.toml)
# The awkward project name became a valid npm name.
grep -q '"name": "odd-name--co"' b/package.json
# Monorepo: packages nested, root files at the root, one Dockerfile each.
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
# rust binary, nested: main.rs, no library-only lints, no doctest step.
test -f c/crates/cli/Cargo.toml
test -f c/crates/cli/deny.toml
test -f c/crates/cli/src/main.rs
test ! -e c/Cargo.toml
(! grep -q missing_docs c/crates/cli/Cargo.toml)
(! grep -q -- '--doc' c/just/rust.just)
grep -q 'cargo fmt --manifest-path crates/cli/Cargo.toml --check' c/just/rust.just
grep -q 'working-directory: crates/cli' c/.github/workflows/rust.yml
grep -q 'directory: /crates/cli' c/.github/dependabot.yml
# go binary, nested: main.go, no Example package, and every tool reaches the module.
test -f c/services/tool/go.mod
test -f c/services/tool/main.go
test ! -e c/services/tool/example_test.go
test ! -e c/go.mod
grep -qF "[working-directory: 'services/tool']" c/just/go.just
grep -qF "cd services/tool && exec golangci-lint run" c/.pre-commit-config.yaml
grep -q 'go-version-file: services/tool/go.mod' c/.github/workflows/go.yml
grep -q 'directory: /services/tool' c/.github/dependabot.yml
grep -qx '/services/tool/mono-me' c/.gitignore
# Both release workflows exist.
test -f c/.github/workflows/python-release.yml
test -f c/.github/workflows/ts-release.yml
# publish_to_ghcr=true: docker.yml rendered its pushing half.
grep -q 'packages: write' c/.github/workflows/docker.yml
# The push job also runs on main, so the README must not limit `ghcr` to tags alone.
grep -q 'ghcr. also to .main' c/README.md
# The publish job has no checkout; the wheels land in the root dist/.
grep -qx '          path: dist/' c/.github/workflows/python-release.yml
# Up-paths at both depths.
grep -qF '](../README.md)' c/api/README.md
grep -qF '"root": "../.."' c/apps/web/biome.json
# data-pipeline: manifest and data dirs in the package, the rest at the root.
test -f d/pipe/sources.toml
test -f d/pipe/src/pipe_me/pipeline.py
test -f d/pipe/data/raw/.gitkeep
test -f d/ATTRIBUTION.md
grep -qF '](pipe/sources.toml)' d/ATTRIBUTION.md
grep -qF '](pipe/sources.toml)' d/README.md
grep -q 'Apache License' d/LICENSE
# Each license text ends in exactly one newline (MIT in a, Apache-2.0 in d), so the
# end-of-file-fixer hook has nothing to rewrite in a new project.
for lic in a/LICENSE d/LICENSE; do
  end=$(tail -c 2 "$lic" | od -An -tx1 | tr -d ' \n')
  [[ $end == ??0a && $end != 0a0a ]]
done
test ! -e d/pipe/notebooks
grep -qx 'pipe/data/raw/\*' d/.gitignore
grep -q 'path: pipe/data/raw/\*.fetch.json' d/.github/workflows/python.yml
grep -q '^pipeline: fetch build validate' d/just/python.just
# web-app (d, Preact, nested): the Vite app and its e2e specs replace the Node
# package, the e2e job reads its container tag from the check job, and the
# unit tests run before a push.
test -f d/web/index.html
test -f d/web/src/main.tsx
test -f d/web/public/_headers
test -f d/web/wrangler.jsonc
test -f d/web/tests/e2e/a11y.spec.ts
test -f d/web/tests/e2e/csp.spec.ts
test ! -e d/web/src/index.ts
test ! -e d/web/tsconfig.build.json
test ! -e d/web/Dockerfile
test ! -e a/index.html
grep -q '"react": \["./node_modules/preact/compat/"\]' d/web/tsconfig.json
grep -q 'react: "preact/compat"' d/web/vite.config.ts
(! grep -q '"react":' d/web/package.json)
grep -q 'script-src .self.;' d/web/public/_headers
(! grep -q "'unsafe-inline'" d/web/public/_headers)
grep -q '"budget": "node scripts/checkBundleBudget.mjs"' d/web/package.json
grep -q 'pnpm -C web run budget' d/just/ts.just
grep -qF 'image: mcr.microsoft.com/playwright:v' d/.github/workflows/ts.yml
grep -qF 'needs.check.outputs.playwright }}-noble' d/.github/workflows/ts.yml
grep -q 'fonts-dejavu-core' d/.github/workflows/ts.yml
grep -qx '          path: web/playwright-report/' d/.github/workflows/ts.yml
grep -q 'stages: \[pre-push\]' d/.pre-commit-config.yaml
grep -qx 'default_install_hook_types: \[pre-commit, pre-push\]' d/.pre-commit-config.yaml
(! grep -q 'pre-push' a/.pre-commit-config.yaml)
grep -qx 'playwright-report/' d/.gitignore
(! grep -q 'playwright-report' a/.gitignore)
(! grep -q 'e2e' a/.github/workflows/ts.yml)
grep -q 'applies-to: security-updates' a/.github/dependabot.yml
# Only data-pipeline renders it.
test ! -e a/sources.toml
test ! -e a/ATTRIBUTION.md
# Only web-service renders the FastAPI modules; the others keep the stdlib stub.
test ! -e a/src/render_me/app.py
(! grep -q fastapi a/pyproject.toml)
grep -q http.server a/src/render_me/__main__.py

echo "all render checks passed"
