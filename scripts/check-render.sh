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

# a: every stack, other answers at their defaults, but for an author name with a
# leading space. module_name is not set,
# so its slug-derived default renders.
"${copier[@]}" --vcs-ref=HEAD \
  --data project_name=render-me --data 'stacks=[python,ts,rust,go,docker]' \
  --data kind=research --data ts_kind=app \
  --data 'author_name= Ada Lovelace' \
  --data codspeed=true \
  --data 'docker_stacks=[python]' . "$out/a"

# b: public=false, so no SECURITY.md and a license that defaults to none, and a name, description and author name with punctuation that `slug`
# strips and `to_json` escapes. A nested web-service beside the root ts package,
# so the name also reaches the FastAPI title as a Python literal.
"${copier[@]}" --vcs-ref=HEAD \
  --data 'project_name=Odd "Name" & Co!' \
  --data 'project_description=A "quoted" one' \
  --data 'author_name=Ada "X" Lovelace' \
  --data public=false --data 'stacks=[python,ts,docker]' \
  --data kind=web-service --data python_dir=svc \
  --data 'docker_stacks=[python,ts]' . "$out/b"

# c: the only render with nested paths, at two depths to catch hardcoded
# up-paths. The rust crate and go module are the binary kind. Render a has the
# libraries. All publish flags on, so the release workflows could collide and
# docker.yml renders its push job. Codecov is on here and in d. The only
# one with the mutation extra, which the ts library (stryker) is the first to show.
"${copier[@]}" --vcs-ref=HEAD \
  --data project_name=mono-me --data 'stacks=[python,ts,rust,go,docker]' \
  --data python_dir=api --data ts_dir=apps/web \
  --data rust_dir=crates/cli --data rust_kind=binary \
  --data go_dir=services/tool --data go_kind=binary \
  --data publish_to_pypi=true --data publish_to_npm=true --data codecov=true \
  --data codspeed=true \
  --data 'test_extras=[mutation]' \
  --data 'docker_stacks=[python,ts]' --data publish_to_ghcr=true . "$out/c"

# d: nested data-pipeline with docker. Covers the nested paths in .gitignore, the
# workflow's artifact path and ATTRIBUTION.md. Also the only Apache-2.0 render, the
# only one with Renovate, and the only web-app: Preact, nested, so the e2e job's
# paths are audited with the rest. Its user_data answer is the one that adds terms.md.
d_args=(
  --data project_name=pipe-me --data 'stacks=[python,ts,docker]'
  --data kind=data-pipeline --data python_dir=pipe --data license=Apache-2.0
  --data ts_dir=web --data ts_kind=web-app --data web_framework=preact --data user_data=accounts
  --data dependency_bot=renovate --data codecov=true
  --data 'docker_stacks=[python]'
)
"${copier[@]}" --vcs-ref=HEAD \
  "${d_args[@]}" . "$out/d"

# The web-app starter files belong to the project: rendering d again over edited
# copies keeps them (_skip_if_exists), while a template-owned file is rewritten.
echo '// project edit' >>"$out/d/web/src/App.tsx"
echo '<!-- project edit -->' >>"$out/d/web/index.html"
echo '// project edit' >>"$out/d/web/vite.config.ts"
echo '<!-- project edit -->' >>"$out/d/web/docs/privacy.md"
"${copier[@]}" --vcs-ref=HEAD \
  "${d_args[@]}" . "$out/d" >/dev/null 2>&1
grep -q 'project edit' "$out/d/web/src/App.tsx"
grep -q 'project edit' "$out/d/web/index.html"
grep -q 'project edit' "$out/d/web/docs/privacy.md"
(! grep -q 'project edit' "$out/d/web/vite.config.ts")

# h: a go library named like the Example file. The unit test must not share its path
# with example_test.go, which a project_name of `example` would otherwise claim.
"${copier[@]}" --vcs-ref=HEAD \
  --data project_name=example --data 'stacks=[go]' . "$out/h"
# go.mod belongs to the project once written: `go mod tidy` rewrites it.
echo '// project edit' >>"$out/h/go.mod"
# The decisions index belongs to the project too; the record template does not.
echo '- project record' >>"$out/h/docs/decisions/README.md"
echo 'project edit' >>"$out/h/docs/decisions/0000-template.md"
"${copier[@]}" --vcs-ref=HEAD \
  --data project_name=example --data 'stacks=[go]' . "$out/h" >/dev/null 2>&1
grep -q 'project edit' "$out/h/go.mod"
grep -q 'project record' "$out/h/docs/decisions/README.md"
(! grep -q 'project edit' "$out/h/docs/decisions/0000-template.md")

# m: every stack a library, nested, with the mutation extra: mutation.yml gets a job for
# each. a has libraries too but no extras, so it must render no mutation.yml.
"${copier[@]}" --vcs-ref=HEAD \
  --data project_name=mutate-me --data 'stacks=[python,ts,rust,go]' \
  --data kind=library --data ts_kind=library --data rust_kind=library --data go_kind=library \
  --data python_dir=py --data ts_dir=web --data rust_dir=crates/lib --data go_dir=svc \
  --data 'test_extras=[mutation]' . "$out/m"
# k: adopting the template in an existing flat Python package under the GPL. The repo's
# own README, citation file and package stay; no src/ stub or sample test lands.
mkdir -p "$out/k/adopt_me"
echo '# project readme' >"$out/k/README.md"
echo '# project citation' >"$out/k/CITATION.cff"
echo 'VALUE = 1' >"$out/k/adopt_me/__init__.py"
"${copier[@]}" --vcs-ref=HEAD \
  --data project_name=adopt-me --data customise=true --data python_layout=flat \
  --data license=GPL-3.0-or-later --data codspeed=true --data 'test_extras=[mutation]' \
  --data publish_to_pypi=true . "$out/k"
grep -qx '# project readme' "$out/k/README.md"
grep -qx '# project citation' "$out/k/CITATION.cff"
grep -qx 'VALUE = 1' "$out/k/adopt_me/__init__.py"
test ! -e "$out/k/src"
test ! -e "$out/k/tests/test_add.py"
(! grep -q 'import add' "$out/k/tests/test_benchmarks.py")
grep -qx 'module-root = ""' "$out/k/pyproject.toml"
grep -qx 'source = \["adopt_me"\]' "$out/k/pyproject.toml"
grep -q 'GNU GENERAL PUBLIC LICENSE' "$out/k/LICENSE"
grep -qx 'license = "GPL-3.0-or-later"' "$out/k/pyproject.toml"
grep -q '"license": "gpl-3.0-or-later"' "$out/k/.zenodo.json"
# A warn-level ty rule must not fail the check, and the hooks must not rewrite data/.
grep -qx 'error-on-warning = false' "$out/k/pyproject.toml"
# Per hook, never top-level: the secret scan and the large-file check still cover data/.
test "$(grep -cx ' *exclude: \^data/' "$out/k/.pre-commit-config.yaml")" = 4
(! grep -qx 'exclude: \^data/' "$out/k/.pre-commit-config.yaml")
grep -qx 'source_paths = \["adopt_me"\]' "$out/k/pyproject.toml"
grep -q 'check --search \. --format github adopt_me' "$out/k/.github/workflows/python.yml"
# yamlfmt rewrites a trailing `run: |` block to `|-`, so render it that way.
grep -qx '        run: |-' "$out/k/.github/workflows/copier-update.yml"

# copier matches _skip_if_exists like .gitignore lines, so an entry without a leading /
# also skips the same name in any directory, such as data/README.md.
(! sed -n '/^_skip_if_exists:/,/^$/p' copier.yml | grep '^  - ' | grep -v '^  - "\{0,1\}/')

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
  --data 'stacks=[ts,docker]' --data ts_kind=web-app --data user_data=nothing \
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

# Each answer below must be refused, with the validator's own message. A refusal for
# another reason, or a render that goes through, fails the check.
refuses() {
  local needle=$1 log
  shift
  if log=$("${copier[@]}" --vcs-ref=HEAD --data project_name=refuse-me "$@" . "$out/refused" 2>&1); then
    echo "rendered with $*: its validator is gone" >&2
    exit 1
  fi
  grep -qF -- "$needle" <<<"$log" || {
    echo "refused $* for another reason:" >&2
    echo "$log" >&2
    exit 1
  }
}
refuses 'An empty value' --data 'stacks=[python]' --data python_dir=
refuses 'An empty value' --data 'stacks=[ts]' --data ts_dir=
refuses 'An empty value' --data 'stacks=[rust]' --data rust_dir=
refuses 'An empty value' --data 'stacks=[go]' --data go_dir=
refuses 'Go keyword' --data 'stacks=[go]' --data project_name=type
refuses 'Rust keyword' --data 'stacks=[rust]' --data project_name=type
refuses 'Rust keyword' --data 'stacks=[rust]' --data project_name=gen
refuses 'Python keyword' --data 'stacks=[python]' --data project_name=lambda
# The name goes into the README and the web app's Markdown pages unescaped.
refuses 'the name is written into Markdown' --data 'stacks=[python]' --data 'project_name=my*app'
refuses 'the name is written into Markdown' --data 'stacks=[python]' --data 'project_name=my<app>'
refuses 'at least one stack' --data 'stacks=[]'
refuses 'The flat layout' --data 'stacks=[python]' --data kind=data-pipeline --data python_layout=flat
refuses 'The flat layout' --data 'stacks=[python,docker]' --data 'docker_stacks=[python]' \
  --data python_layout=flat
refuses 'edition 2024' --data 'stacks=[rust]' --data rust_version=1.84.0
# The legal pages are written from user_data, so it has no default to fall back on.
refuses 'Question "user_data" is required' --data 'stacks=[ts]' --data ts_kind=web-app
refuses "Invalid choice for 'user_data'" --data 'stacks=[ts]' --data ts_kind=web-app --data user_data=some
refuses 'starting with https://' --data 'stacks=[ts]' --data ts_kind=web-app \
  --data user_data=nothing --data site_url=http://example.org
refuses 'Give a port' --data 'stacks=[python,docker]' --data app_port=0
refuses 'second image' --data 'stacks=[python,ts,docker]' --data 'docker_stacks=[python,ts]' \
  --data python_dir=api --data ts_dir=web --data app_port=65535
# A binary never uses the Go package name, so a digit-leading project name is fine.
# Its gitignored build output drops the module path's /v2.
"${copier[@]}" --vcs-ref=HEAD --data project_name=1tool --data 'stacks=[go]' \
  --data go_kind=binary --data go_module=github.com/example-org/1tool/v2 . "$out/i"
# l: a flat Python package next to a ts image. Only the python image needs src/.
"${copier[@]}" --vcs-ref=HEAD --data project_name=flat-ts-image \
  --data 'stacks=[python,ts,docker]' --data python_layout=flat --data ts_dir=web \
  --data 'docker_stacks=[ts]' . "$out/l"
test -f "$out/l/web/Dockerfile"
test ! -e "$out/l/src"
# j: a private web app, so its legal pages must not link a repo visitors can't open.
"${copier[@]}" --vcs-ref=HEAD --data project_name=private-web --data 'stacks=[ts]' \
  --data ts_kind=web-app --data user_data=browser --data public=false . "$out/j"

OUT=$out uv run --no-project --with pyyaml --with json5 python - <<'PY'
import ast, json, json5, os, pathlib, tomllib, yaml

load = {".json": json.loads, ".json5": json5.loads, ".toml": tomllib.loads,
        ".yml": yaml.safe_load, ".yaml": yaml.safe_load}
seen = 0
out = pathlib.Path(os.environ["OUT"])
for path in sorted(out.glob("[abcdm]/**/*")):
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
# A leading space in the author name must not leave the given name empty.
assert codemeta["author"][0]["givenName"] == "Ada", codemeta
assert "given-names: \"Ada\"" in (out / "a/CITATION.cff").read_text()
# The push job holds the write scopes and reads no cache on a tag. trivy-action restores
# its database from the Actions cache, so the scan stays in the build job.
docker = yaml.safe_load((out / "c/.github/workflows/docker.yml").read_text())["jobs"]
assert any("trivy-action" in s.get("uses", "") for s in docker["build"]["steps"]), docker["build"]
assert not any("trivy-action" in s.get("uses", "") for s in docker["push"]["steps"]), docker["push"]
# A ruleset requires a check by its job name, so two jobs with one name can't be told
# apart. a, b, c and d each render more than one stack.
for render in "abcdm":
    names = {}
    for wf in sorted((out / render / ".github/workflows").glob("*.yml")):
        for job_id, job in yaml.safe_load(wf.read_text())["jobs"].items():
            if "name" in job:
                names.setdefault(job["name"], []).append(f"{wf.name}:{job_id}")
    dupes = {n: where for n, where in names.items() if len(where) > 1}
    assert not dupes, f"{render}: jobs share a name: {dupes}"
PY

# NOTE: a bare `! cmd` never trips set -e; the negated subshells below do.
cd "$out"
# kind=research adds two dirs. Publishing off removes both release workflows.
test -f a/data/README.md
test -f a/notebooks/.gitkeep
test ! -e a/.github/workflows/python-release.yml
test ! -e a/.github/workflows/ts-release.yml
# The release body is the CHANGELOG section of the tag. The last version before the
# link references is the edge case: its section must not swallow them.
test -f a/.github/workflows/release.yml
# Every project's README says how to release; only publishing ones add the environment setup.
grep -qx '## Releasing' a/README.md
(! grep -q 'Before the first release' a/README.md)
grep -q 'Before the first release' c/README.md
test -x a/.github/scripts/release-notes.sh
cat >"$out/sample-changelog.md" <<'MD'
# Changelog

## [Unreleased]

- not shipped

## [1.1.0] - 2026-02-01

### Added

- new thing

## [1.0.0] - 2026-01-01

- first release

[Unreleased]: https://example.com/compare/v1.1.0...HEAD
[1.1.0]: https://example.com/compare/v1.0.0...v1.1.0
[1.0.0]: https://example.com/releases/tag/v1.0.0
MD
notes=a/.github/scripts/release-notes.sh
test "$("$notes" v1.1.0 "$out/sample-changelog.md" | grep -c .)" = 2
"$notes" 1.1.0 "$out/sample-changelog.md" | grep -qx -- '- new thing'
test "$("$notes" 1.0.0 "$out/sample-changelog.md")" = $'\n- first release'
(! "$notes" 2.0.0 "$out/sample-changelog.md" 2>/dev/null)
(! "$notes" 1.0 "$out/sample-changelog.md" 2>/dev/null)
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
grep -q 'Contributor Covenant, version 3.0' a/.github/CODE_OF_CONDUCT.md
grep -q 'send an email to <ada@example.com>' a/.github/CODE_OF_CONDUCT.md
# Scorecard: its workflow and badge exist only with public (a), never without (b).
test -f a/.github/workflows/scorecard.yml
grep -qx '      id-token: write # to publish the results' a/.github/workflows/scorecard.yml
grep -q 'scorecard.dev/viewer/?uri=github.com/' a/README.md
test ! -e b/.github/workflows/scorecard.yml
(! grep -q -i scorecard b/README.md)
# Badges follow their answers: a has codspeed only; c has codecov, codspeed, PyPI and npm;
# d has codecov alone; b has none.
grep -qF 'https://app.codspeed.io/' a/README.md
(! grep -q -e codecov.io -e img.shields.io/pypi -e img.shields.io/npm a/README.md)
grep -qF 'https://codecov.io/gh/' c/README.md
grep -qF 'https://app.codspeed.io/' c/README.md
grep -qF 'img.shields.io/pypi/v/mono-me' c/README.md
grep -qF 'img.shields.io/pypi/pyversions/mono-me' c/README.md
grep -qF 'img.shields.io/npm/v/mono-me' c/README.md
grep -qF 'https://codecov.io/gh/' d/README.md
(! grep -q -e codspeed -e img.shields.io/pypi -e img.shields.io/npm d/README.md)
(! grep -q -e codecov -e codspeed -e img.shields.io/pypi -e img.shields.io/npm b/README.md)
# The weekly audit: one job per stack, on a Monday schedule. python.yml keeps its own
# schedule for the data pipeline (d) and has none elsewhere.
for r in a b c d; do grep -q 'cron: "23 5 \* \* 1"' "$r/.github/workflows/advisories.yml"; done
for j in python ts rust go; do grep -q "^  $j:" a/.github/workflows/advisories.yml; done
grep -q 'cargo deny check advisories' a/.github/workflows/advisories.yml
grep -q 'go tool govulncheck' a/.github/workflows/advisories.yml
grep -q 'uv audit --locked' a/.github/workflows/advisories.yml
grep -q 'pnpm audit --prod' a/.github/workflows/advisories.yml
(! grep -q -e '^  rust:' -e '^  go:' b/.github/workflows/advisories.yml)
grep -q 'working-directory: svc' b/.github/workflows/advisories.yml
grep -q 'working-directory: crates/cli' c/.github/workflows/advisories.yml
grep -q 'working-directory: services/tool' c/.github/workflows/advisories.yml
grep -q 'working-directory: apps/web' c/.github/workflows/advisories.yml
grep -q 'cron: "0 6 \* \* 1"' d/.github/workflows/python.yml
(! grep -q 'cron:' a/.github/workflows/python.yml)
test -f h/.github/workflows/advisories.yml
(! grep -q -e '^  python:' -e '^  ts:' h/.github/workflows/advisories.yml)
grep -qx '## \[Unreleased\]' a/CHANGELOG.md
# Every render gets the decisions folder.
for r in a b c d h i; do
  test -f "$r/docs/decisions/README.md"
  test -f "$r/docs/decisions/0000-template.md"
done
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
grep -qx '      - run: uv run pytest --cov --cov-report=xml' c/.github/workflows/python.yml
grep -qx '          files: api/coverage.xml' c/.github/workflows/python.yml
grep -qx "        if: matrix.python == '$(sed -n 's/^python_version: *//p' c/.copier-answers.yml | tr -d "\"'")'" c/.github/workflows/python.yml
grep -qx '          flags: python' c/.github/workflows/python.yml
grep -qx '          files: apps/web/coverage/lcov.info' c/.github/workflows/ts.yml
grep -qx '          flags: ts' c/.github/workflows/ts.yml
# CodSpeed: a has the root python and rust library, c the nested python library and rust
# binary. Each stack gets a job, a starter benchmark and its dependency; OIDC sign-in is
# on the job, not the workflow. b and d, without the option, get none of it.
for r in a c; do
  test -f "$r/.github/workflows/benchmarks.yml"
  grep -qx '      id-token: write # OpenID Connect sign-in to CodSpeed' "$r/.github/workflows/benchmarks.yml"
  grep -q 'CodSpeedHQ/action@' "$r/.github/workflows/benchmarks.yml"
done
test -f a/tests/test_benchmarks.py
test -f c/api/tests/test_benchmarks.py
test -f a/benches/codspeed.rs
test -f c/crates/cli/benches/codspeed.rs
grep -q 'use render_me::add;' a/benches/codspeed.rs
grep -q 'fn stand_in' c/crates/cli/benches/codspeed.rs
grep -q 'pytest-codspeed' a/pyproject.toml
grep -q 'pytest-codspeed' c/api/pyproject.toml
grep -q 'package = "codspeed-divan-compat"' a/Cargo.toml
grep -qx 'name = "codspeed"' c/crates/cli/Cargo.toml
grep -q 'working-directory: crates/cli' c/.github/workflows/benchmarks.yml
grep -q 'working-directory: api' c/.github/workflows/benchmarks.yml
for r in b d; do
  test ! -e "$r/.github/workflows/benchmarks.yml"
  test ! -e "$r/tests/test_benchmarks.py"
  (! grep -rq codspeed "$r" --include=pyproject.toml --include=Cargo.toml)
done
# The data-pipeline workflow has its own pytest line, so d checks its coverage flags.
grep -qx '      - run: uv run pytest --cov --cov-report=xml' d/.github/workflows/python.yml
(! grep -q codecov a/.github/workflows/python.yml a/.github/workflows/ts.yml)
grep -qx '      - run: pnpm run test' a/.github/workflows/ts.yml
# test_extras: asked only with a library kind (d has none), off by default (a's rust
# and go libraries get no property-test or mutation dependency).
(! grep -q '^test_extras' d/.copier-answers.yml)
grep -qx 'test_extras: \[\]' a/.copier-answers.yml
(! grep -q -e proptest -e gremlins a/Cargo.toml a/go.mod)
# mutation.yml: only with the extra, one job per library stack, weekly and by hand only.
test -f m/.github/workflows/mutation.yml
test ! -e a/.github/workflows/mutation.yml
python3 - <<'PY'
import yaml
wf = yaml.safe_load(open("m/.github/workflows/mutation.yml"))
assert set(wf["jobs"]) == {"python", "ts", "rust", "go"}, wf["jobs"].keys()
assert set(wf[True]) == {"schedule", "workflow_dispatch"}, wf[True]
assert wf["permissions"] == {"contents": "read"}, wf["permissions"]
assert all("timeout-minutes" in j for j in wf["jobs"].values())
for stack in ("py", "ts", "rs", "go"):
    assert any(f"just {stack}-mutation" in s.get("run", "") for j in wf["jobs"].values() for s in j["steps"]), stack
# cargo mutants --dir writes mutants.out inside rust_dir: the check and the upload follow it.
steps = wf["jobs"]["rust"]["steps"]
assert any("test ! -s crates/lib/mutants.out/missed.txt" in s.get("run", "") for s in steps), steps
assert any(s.get("with", {}).get("path") == "crates/lib/mutants.out/" for s in steps), steps
PY
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
# govulncheck fails until go-sync writes go.sum, so the README's setup runs it.
grep -q '^just go-sync' a/README.md
grep -q 'id: golangci-lint$' a/.pre-commit-config.yaml
grep -q golang.go a/.vscode/extensions.json
grep -q 'package-ecosystem: gomod' a/.github/dependabot.yml
# dependency_bot: Dependabot by default, Renovate in d, never both.
test ! -e a/renovate.json5
test -f d/renovate.json5
# Only Dependabot repos need the workflow that hears about template releases.
test -f a/.github/workflows/copier-update.yml
test ! -e d/.github/workflows/copier-update.yml
test ! -e d/.github/dependabot.yml
(! grep -q working-directory a/just/go.just)
# public=false defaults the license to none: no file and no license key.
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
# rust-analyzer finds a crate two levels down only when told.
grep -qF '"rust-analyzer.linkedProjects": ["crates/cli/Cargo.toml"]' c/.vscode/settings.json
(! grep -q linkedProjects a/.vscode/settings.json)
# Another stack's secrets stay out of an image's build context.
grep -qx '\*\*/.env' c/apps/web/.dockerignore
grep -qx '\*\*/.env' c/api/.dockerignore
# Both release workflows exist.
test -f c/.github/workflows/python-release.yml
test -f c/.github/workflows/ts-release.yml
# The API-break checks render with the publish answers, and only with them: griffe in CI from
# the repository root, so its search path carries the nested dir; the npm report beside
# the nested package.
grep -qx '      - run: uvx griffe@[0-9.]* check --search api/src --format github mono_me' c/.github/workflows/python.yml
# Not in py-check: a deliberate break would keep local checks red until the next tag.
(! grep -q griffe c/just/python.just)
grep -qx '      - run: pnpm run api' c/.github/workflows/ts.yml
grep -qx '    pnpm -C apps/web run api' c/just/ts.just
test -f c/apps/web/api-extractor.json
test -f c/apps/web/mono-me.api.md
(! grep -q griffe a/.github/workflows/python.yml a/just/python.just)
(! grep -q 'run api' a/.github/workflows/ts.yml a/just/ts.just)
test ! -e a/api-extractor.json
test ! -e a/render-me.api.md
# publish_to_ghcr=true: docker.yml rendered its pushing half.
grep -q 'packages: write' c/.github/workflows/docker.yml
# docker.yml filters by path only when every build context is nested (c), not with a
# root context (a, b).
grep -qF 'paths: ["api/**", "apps/web/**", ".github/workflows/docker.yml"]' c/.github/workflows/docker.yml
(! grep -q 'paths:' a/.github/workflows/docker.yml b/.github/workflows/docker.yml)
# The push job also runs on main, so the README must not limit `ghcr` to tags alone.
grep -q 'ghcr. also to .main' c/README.md
# The publish job has no checkout; the wheels land in the root dist/.
grep -qx '          path: dist/' c/.github/workflows/python-release.yml
# A release made by release.yml's GITHUB_TOKEN starts no workflow, so publishing
# must follow the tag push, not the release.
grep -qx '    tags: \["v\[0-9\]+.\[0-9\]+.\[0-9\]+"\]' c/.github/workflows/python-release.yml
grep -qx '    tags: \["v\[0-9\]+.\[0-9\]+.\[0-9\]+"\]' c/.github/workflows/ts-release.yml
(! grep -q 'types: \[published\]' c/.github/workflows/python-release.yml c/.github/workflows/ts-release.yml)
for w in python ts; do
  # shellcheck disable=SC2016 # the literal workflow text, not a shell expansion
  grep -q 'release-notes.sh" "$GITHUB_REF_NAME' "c/.github/workflows/$w-release.yml"
done
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
# The week-old-release escape hatch names each nested lockfile owner, and only those.
grep -qF 'uv and pnpm lock only' d/README.md
grep -q 'in .pipe/pyproject\.toml. or .minimumReleaseAgeExclude. in .web/pnpm-workspace\.yaml.' d/README.md
(! grep -q 'exclude-newer' h/README.md)
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
# The legal pages: statement and privacy always, terms for accounts or uploads,
# each a route the axe, CSP, privacy and legal-page specs visit.
for page in accessibility privacy terms; do
  test -f "d/web/docs/$page.md"
  grep -q "\"/$page\"" d/web/tests/e2e/routes.ts
done
test -f d/web/tests/e2e/privacy.spec.ts
test -f d/web/tests/e2e/accessibility-statement.spec.ts
test -f d/web/tests/e2e/legal-pages.spec.ts
grep -q 'Its conformance is \*\*not assessed\*\*' d/web/docs/accessibility.md
grep -qx '    "marked": "[0-9.]*",' d/web/package.json
# A private repo's GitHub links would 404 for visitors, so its legal pages have none.
test -f j/docs/accessibility.md
(! grep -rq 'github.com/example-org/private-web' j/docs)
grep -q 'github.com/example-org/pipe-me/blob/main/web/tests/e2e/a11y.spec.ts' d/web/docs/accessibility.md
# The answers reach the terms: the site, who runs it and the contact, and the privacy
# statement links them.
grep -qxF 'These terms cover pipe-me at [pipe-me.pages.dev](https://pipe-me.pages.dev).' d/web/docs/terms.md
grep -qxF 'Ada Lovelace, who runs pipe-me.' d/web/docs/terms.md
grep -qF '[ada@example.com](mailto:ada@example.com)' d/web/docs/terms.md
grep -qxF 'Using pipe-me also means accepting its [terms of use](https://pipe-me.pages.dev/terms).' d/web/docs/privacy.md
# j keeps work in the browser, with no accounts: its privacy statement says so, and it has
# no terms page, route or footer link.
grep -qF "private-web keeps your work in your browser's local storage" j/docs/privacy.md
grep -qx 'private-web sets no cookies. It uses local storage only to keep your work, which is what you' j/docs/privacy.md
grep -qx 'private-web comes with no warranty.' j/docs/privacy.md
test ! -e j/docs/terms.md
(! grep -q '/terms' j/src/App.tsx j/tests/e2e/routes.ts j/tests/e2e/legal-pages.spec.ts j/docs/privacy.md)
# GitHub shows the pages as they are, so they pass the project's own Markdown lint.
rumdl_version=$(sed -n '/rumdl-pre-commit/{n;s/.*frozen: v//p;}' "$repo/.pre-commit-config.yaml")
uvx "rumdl@$rumdl_version" check --config d/.rumdl.toml d/web/docs
test ! -e a/docs/privacy.md
test ! -e d/web/src/index.ts
test ! -e d/web/tsconfig.build.json
test ! -e d/web/Dockerfile
grep -q 'stub for a data pipeline' d/pipe/Dockerfile
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
grep -qx 'default_install_hook_types: \[pre-commit, commit-msg, pre-push\]' d/.pre-commit-config.yaml
(! grep -q 'pre-push' a/.pre-commit-config.yaml)
# Commit messages and PR titles: one committed.toml, read by the commit-msg hook and
# the pr-title workflow, in every render. The bots write titles that pass it.
grep -qx 'default_install_hook_types: \[pre-commit, commit-msg\]' a/.pre-commit-config.yaml
for r in a b c d; do
  grep -qx 'style = "conventional"' "$r/committed.toml"
  grep -qx '      - id: committed' "$r/.pre-commit-config.yaml"
  grep -q 'uvx committed@[0-9.]* --config committed.toml --commit-file -' "$r/.github/workflows/pr-title.yml"
  committed=$(sed -n 's/.*uvx committed@\([0-9.]*\) .*/\1/p' "$r/.github/workflows/pr-title.yml")
  for msg in 'chore: update from template v1.0.0' 'chore(deps): bump x from 1 to 2' 'feat!: drop x' 'revert: feat: add x'; do
    printf '%s\n' "$msg" | uvx -q "committed@$committed" --config "$r/committed.toml" --commit-file - >/dev/null
  done
  for msg in 'Add x' 'Revert "feat: add x"' 'feat: add x.'; do
    (! printf '%s\n' "$msg" | uvx -q "committed@$committed" --config "$r/committed.toml" --commit-file - >/dev/null 2>&1)
  done
done
test "$(grep -c 'commit-message: {prefix: chore, include: scope}' a/.github/dependabot.yml)" -eq 5
grep -q "extends: \['config:recommended', ':semanticCommits'\]" d/renovate.json5
grep -qx 'playwright-report/' d/.gitignore
# Outside CI, reusing a server on the preview port would test whichever app holds it.
(! grep -q reuseExistingServer d/web/playwright.config.ts)
(! grep -q 'playwright-report' a/.gitignore)
(! grep -q 'e2e' a/.github/workflows/ts.yml)
grep -q 'applies-to: security-updates' a/.github/dependabot.yml
# Actions and hook revs share one multi-ecosystem PR, with the same group in Renovate.
grep -qx '  actions-and-hooks:' a/.github/dependabot.yml
test "$(grep -c 'multi-ecosystem-group: actions-and-hooks' a/.github/dependabot.yml)" = 2
grep -q "groupName: 'actions and hooks'" d/renovate.json5
# Lock refreshes carry transitive security fixes, and the week's wait would block them.
grep -A3 'lockFileMaintenance: {' d/renovate.json5 | grep -q 'minimumReleaseAge: null'
# Exemptions that `pnpm audit --fix` writes for fresh security fixes clean themselves up.
grep -qx 'minimumReleaseAgeExcludePrune: true' d/web/pnpm-workspace.yaml
# Only data-pipeline renders it.
test ! -e a/sources.toml
test ! -e a/ATTRIBUTION.md
# Only web-service renders the FastAPI modules; the others keep the stdlib stub.
test ! -e a/src/render_me/app.py
(! grep -q fastapi a/pyproject.toml)
grep -q http.server a/src/render_me/__main__.py
# h: the unit test and the Example are two files, not one overwriting the other.
grep -q 'func TestAdd' h/add_test.go
grep -q 'func ExampleAdd' h/example_test.go

test -f i/main.go
grep -qx '/1tool' i/.gitignore

# PID 1 ignores SIGTERM without a handler, so both image stubs install one.
grep -q SIGTERM b/src/main.ts
grep -q SIGTERM a/src/render_me/__main__.py

# Each kind gets its own tests and no other kind's. Dropping a filename condition
# renders nothing, which no parse or CI row notices.
test -f b/svc/tests/test_app.py
test ! -e a/tests/test_app.py
test -f c/api/tests/test_add.py
test ! -e b/svc/tests/test_add.py
test -f d/pipe/tests/test_pipeline.py
test -f d/pipe/tests/test_published.py
test ! -e a/tests/test_pipeline.py
test ! -e a/tests/test_published.py
test -f d/web/src/App.test.tsx
test ! -e d/web/src/index.test.ts
test -f a/src/index.test.ts
test ! -e a/src/App.test.tsx
test -f c/apps/web/src/index.test.ts
test -f c/services/tool/main_test.go
test ! -e c/services/tool/add_test.go
test ! -e a/main_test.go
test -f i/main_test.go
# The mutation extra renders stryker for the ts library only (a is an app).
test -f c/apps/web/stryker.config.json
test ! -e a/stryker.config.json
# The rust tests are inline.
grep -qx '#\[cfg(test)\]' a/src/lib.rs
grep -qx '#\[cfg(test)\]' c/crates/cli/src/main.rs

# A stack's check recipe runs everything CI runs: dropping one command still exits 0.
recipe_has() {
  sed -n "/^$2:/,/^\$/p" "$1" | grep -qxF -- "$3" || {
    echo "$1: recipe $2 lost: $3" >&2
    exit 1
  }
}
for cmd in 'uv run ruff check' 'uv run ruff format --check' 'uv run ty check' 'uv run pytest' \
  'uv audit --locked --preview-features audit-command'; do
  recipe_has a/just/python.just py-check "    $cmd"
done
for cmd in check typecheck test build; do recipe_has a/just/ts.just ts-check "    pnpm run $cmd"; done
recipe_has a/just/ts.just ts-check '    pnpm audit --prod --audit-level=moderate'
# With codecov, CI runs the tests with coverage, so check does too: thresholds set in
# the vitest config then fail locally, not only in CI.
recipe_has c/just/ts.just ts-check '    pnpm -C apps/web run coverage'
for cmd in 'cargo fmt --check' 'cargo clippy --all-targets --all-features -- -D warnings' \
  'cargo nextest run --all-features' 'cargo deny check'; do
  recipe_has a/just/rust.just rs-check "    $cmd"
done
for cmd in 'golangci-lint fmt --diff' 'golangci-lint run' 'go test -race ./...' \
  'go tool govulncheck ./...'; do
  recipe_has a/just/go.just go-check "    $cmd"
done
# The root check calls every stack; rs and go are above.
# Nested (c): every cargo and go command reaches the crate and module.
for cmd in 'cargo fmt --manifest-path crates/cli/Cargo.toml --check' \
  'cargo clippy --manifest-path crates/cli/Cargo.toml --all-targets --all-features -- -D warnings' \
  'cargo nextest run --manifest-path crates/cli/Cargo.toml --all-features' \
  'cargo deny --manifest-path crates/cli/Cargo.toml check'; do
  recipe_has c/just/rust.just rs-check "    $cmd"
done
for cmd in 'golangci-lint fmt --diff' 'golangci-lint run' 'go test -race ./...' \
  'go tool govulncheck ./...'; do
  recipe_has c/just/go.just go-check "    $cmd"
done
recipe_has a/justfile check '    @just py-check'
recipe_has a/justfile check '    @just ts-check'

# The generated workflows are linted, never run: a typo in a run line fails only
# in the new project.
grep -qx '      - run: uv run pytest' a/.github/workflows/python.yml
grep -qx '      - run: uv run ty check' a/.github/workflows/python.yml
grep -qx '      - run: uv audit --locked --preview-features audit-command' a/.github/workflows/python.yml
grep -qx '      - run: cargo nextest run --all-features' a/.github/workflows/rust.yml
grep -qx '      - run: cargo deny check' a/.github/workflows/rust.yml
grep -qx '      - run: go test -race ./...' a/.github/workflows/go.yml
grep -qx '      - run: go tool govulncheck ./...' a/.github/workflows/go.yml
grep -qx '      - run: pnpm audit --prod --audit-level=moderate' a/.github/workflows/ts.yml
# Trusted publishing and attestations need the job-level write scopes; the
# workflow-level grant stays read-only.
grep -q '^      id-token: write ' c/.github/workflows/python-release.yml
grep -qx '      attestations: write' c/.github/workflows/python-release.yml
grep -q '^      id-token: write ' c/.github/workflows/ts-release.yml
# The publish step: npm, from a tarball built earlier.
grep -qx '      - run: npm publish --access public ./\*.tgz' c/.github/workflows/ts-release.yml
(! grep -q '^  id-token' c/.github/workflows/python-release.yml c/.github/workflows/ts-release.yml)

# repo-settings: a fake gh keeps a list of rulesets and applies the recipe's real --jq
# filter to it, so the first run POSTs each ruleset file and the second PUTs it by its id.
test -f a/.github/rulesets/main.json
test -f a/.github/rulesets/tags.json
fake=$(mktemp -d)
echo '[{"name": "other", "id": 7}]' >"$fake/rulesets.json"
cat >"$fake/gh" <<'FAKE'
#!/usr/bin/env bash
echo "$*" >>"$FAKE_LOG"
call=$*
input='' filter=''
while [ $# -gt 0 ]; do
  case $1 in --input) input=$2 ;; --jq) filter=$2 ;; esac
  shift
done
list=$FAKE_DIR/rulesets.json
case $call in
  *"-X POST repos/{owner}/{repo}/rulesets --input"*)
    jq --slurpfile b "$input" '. + [{name: $b[0].name, id: (length + 41)}]' "$list" >"$list.new"
    mv "$list.new" "$list"
    cp "$input" "$FAKE_DIR/posted.$(basename "$input")" ;;
  *"-X PUT repos/{owner}/{repo}/rulesets/"*) cp "$input" "$FAKE_DIR/put.$(basename "$input")" ;;
  *"/rulesets?includes_parents=false --jq"*) jq -r "$filter" "$list" ;;
esac
FAKE
chmod +x "$fake/gh"
(
  cd a
  # shellcheck disable=SC2030 # the about test below reuses this fake
  export FAKE_LOG="$fake/log" FAKE_DIR="$fake" PATH="$fake:$PATH"
  just repo-settings >/dev/null
  just repo-settings >/dev/null
  test "$(grep -c -- '-X POST repos/{owner}/{repo}/rulesets' "$FAKE_LOG")" = 2
  grep -qxF -- 'api -X PUT repos/{owner}/{repo}/rulesets/42 --input .github/rulesets/main.json' "$FAKE_LOG"
  grep -qxF -- 'api -X PUT repos/{owner}/{repo}/rulesets/43 --input .github/rulesets/tags.json' "$FAKE_LOG"
  patch=$(grep -- '^api -X PATCH repos/{owner}/{repo} ' "$FAKE_LOG" | head -1)
  for flag in allow_squash_merge=true allow_merge_commit=false allow_rebase_merge=false; do
    [[ "$patch " == *" -F $flag "* ]]
  done
  # SECURITY.md's advisory link needs private vulnerability reporting on.
  grep -qxF -- 'api -X PUT repos/{owner}/{repo}/private-vulnerability-reporting' "$FAKE_LOG"
  for f in main tags; do
    cmp "$fake/posted.$f.json" ".github/rulesets/$f.json"
    cmp "$fake/put.$f.json" ".github/rulesets/$f.json"
  done
  # The required checks are the always-on jobs, by the names the workflows give them.
  for check in 'git hooks' 'pull request title' 'dependency review' 'DCO sign-off'; do
    jq -e --arg c "$check" '.rules[] | select(.type == "required_status_checks")
      | .parameters.required_status_checks | any(.context == $c)' .github/rulesets/main.json >/dev/null
    grep -rqxF "    name: $check" .github/workflows
  done
  # A path filter would leave a required check unreported on some PRs, which blocks them.
  (! grep -q '^ *paths' .github/workflows/checks.yml .github/workflows/pr-title.yml .github/workflows/dco.yml)
  jq -e '.target == "tag" and .conditions.ref_name.include == ["refs/tags/v*"]' .github/rulesets/tags.json >/dev/null
)
(cd b && ! grep -q 'DCO sign-off' .github/rulesets/main.json)
(! grep -q private-vulnerability-reporting b/justfile)
# repo-about: the About box comes from the answers. No description answer leaves the description alone;
# a quote in it survives the shell; topics only get added.
for r in a b d; do
  # shellcheck disable=SC2031 # $fake/gh from the repo-settings test, logging every call
  (cd "$r" && FAKE_LOG="$fake/about-$r" PATH="$fake:$PATH" just repo-about >/dev/null)
done
grep -qxF -- 'repo edit --add-topic python --add-topic typescript --add-topic rust --add-topic go --add-topic docker' "$fake/about-a"
grep -qxF -- "repo edit --description A \"quoted\" one --add-topic python --add-topic typescript --add-topic docker" "$fake/about-b"
grep -qxF -- 'repo edit --homepage https://pipe-me.pages.dev --add-topic python --add-topic typescript --add-topic docker' "$fake/about-d"
# The community files and the DCO check come with public and go with it, in every render.
for answers in */.copier-answers.yml; do
  r=${answers%%/*}
  # e renders a tag on HEAD, so it lacks uncommitted edits.
  [ "$r" = e ] && continue
  for f in SECURITY.md CONTRIBUTING.md CODE_OF_CONDUCT.md pull_request_template.md workflows/dco.yml; do
    if grep -qx 'public: false' "$answers"; then
      test ! -e "$r/.github/$f"
    else
      test -f "$r/.github/$f"
    fi
  done
done
# The community files' links point at this repo.
grep -qF 'https://github.com/example-org/render-me/issues)' a/.github/CONTRIBUTING.md
grep -qF '(../committed.toml)' a/.github/CONTRIBUTING.md
(! grep -q '\[NOTE:' a/.github/CODE_OF_CONDUCT.md)
# This repo runs the same DCO check and commit rules it renders.
cmp "$repo/.github/workflows/dco.yml" "$repo/template/.github/workflows/{% if public %}dco.yml{% endif %}"
cmp "$repo/committed.toml" "$repo/template/committed.toml"
# Its jq filter, run on a commits API fixture, lists the unsigned commit and the sign-off
# without an email, and skips the merge. Trailing whitespace and CRLF still count as signed.
dco_filter=$(uv run --no-project --with pyyaml python -c '
import re, sys, yaml
run = yaml.safe_load(open(sys.argv[1]))["jobs"]["sign-off"]["steps"][0]["run"]
print(re.search(r"--jq \x27(.*?)\x27\)", run, re.S).group(1))' "$repo/.github/workflows/dco.yml")
commits=$(mktemp)
cat >"$commits" <<'JSON'
[
  {"sha": "aaaaaaa1", "parents": [{}], "commit": {"message": "feat: signed\n\nSigned-off-by: Ada Lovelace <ada@example.com>"}},
  {"sha": "bbbbbbb2", "parents": [{}], "commit": {"message": "fix: unsigned"}},
  {"sha": "ccccccc3", "parents": [{}, {}], "commit": {"message": "Merge branch 'main'"}},
  {"sha": "ddddddd4", "parents": [{}], "commit": {"message": "fix: malformed\n\nSigned-off-by: Ada Lovelace"}},
  {"sha": "eeeeeee5", "parents": [{}], "commit": {"message": "fix: trailing space\n\nSigned-off-by: Ada Lovelace <ada@example.com>  "}},
  {"sha": "fffffff6", "parents": [{}], "commit": {"message": "fix: crlf\r\n\r\nSigned-off-by: Ada Lovelace <ada@example.com>\r\n"}}
]
JSON
test "$(jq -r "$dco_filter" "$commits")" = "$(printf 'bbbbbbb fix: unsigned\nddddddd fix: malformed')"
# copier-update pushes with COPIER_UPDATE_TOKEN when set; GITHUB_TOKEN can't push workflow
# changes, so without it a workflow change becomes an issue, not a failed push.
cu=a/.github/workflows/copier-update.yml
# shellcheck disable=SC2016 # literal workflow text, not shell expansions
grep -qF 'GH_TOKEN: ${{ secrets.COPIER_UPDATE_TOKEN || github.token }}' "$cu"
grep -qx '      issues: write # to ask for a local update when it can.t push one' "$cu"
# shellcheck disable=SC2016
grep -q 'gh issue create --title "$title"' "$cu"
# shellcheck disable=SC2016
grep -q 'gh pr close "$stale"' "$cu"
grep -qF 'gh issue list --state all' "$cu"

echo "all render checks passed"
