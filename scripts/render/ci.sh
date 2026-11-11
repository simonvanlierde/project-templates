# shellcheck shell=bash
# shellcheck disable=SC2154,SC2164 # check-render.sh sets out, repo, copier and set -e
# CI workflows and badges: cold-install, pins, Scorecard, howfairis, advisories,
# citations, Codecov, CodSpeed, profiling, mutation and property testing.

# cold-install.yml runs the README's Development blocks. Run its step with `bash -ex`
# swapped for `cat`, and without the chown, to see which commands it picks: d's README
# has the install lines and `just check`, and the Docker, pipeline and e2e recipes are
# left out.
cold() {
  awk '/^        run: \|-$/ {on = 1; next} on && NF && !/^          / {exit} on' \
    "$1/.github/workflows/cold-install.yml" |
    sed 's/^          //; /^chown /d; s/^bash -ex /cat /' | (cd "$1" && RUNNER_TEMP=$out bash)
}
cold d >"$out/d-readme.sh"
grep -qx 'uv sync --directory pipe' "$out/d-readme.sh"
grep -q '^pnpm -C web exec playwright install chromium' "$out/d-readme.sh"
grep -q '^just check ' "$out/d-readme.sh"
(lacks -E '^just +(up|pipeline|ts-e2e)' "$out/d-readme.sh")
cold c >"$out/c-readme.sh"
grep -q '^just hooks ' "$out/c-readme.sh"
(lacks -q -- '-mutation' "$out/c-readme.sh")
cold m >"$out/m-readme.sh"
grep -q '^just check ' "$out/m-readme.sh"
(lacks -qE -- '-(mutation|property)' "$out/m-readme.sh")
# Any sh, bash or shell fence, trailing spaces and all. Indented slow recipes are
# dropped too; other languages and other sections are not run.
mkdir -p "$out/fence/.github/workflows"
cp d/.github/workflows/cold-install.yml "$out/fence/.github/workflows/"
printf '%s\n' '## Development' '```shell' 'echo from-shell' '```' '```sh ' '  just up' \
  'echo from-sh' '```' '```python' 'echo from-python' '```' '## License' '```sh' \
  'echo from-license' '```' >"$out/fence/README.md"
cold "$out/fence" >"$out/fence-readme.sh"
test "$(cat "$out/fence-readme.sh")" = $'echo from-shell\necho from-sh'
# k kept its own README, which has no Development block: the job says what to do.
if cold k >/dev/null 2>"$out/k-cold.log"; then
  echo "cold-install ran on a README with no Development block" >&2
  exit 1
fi
grep -qF 'or delete .github/workflows/cold-install.yml' "$out/k-cold.log"
# cold_install defaults on from the standard level (a), off at minimal (x) and in a private repo (b).
test -f "$out/a/.github/workflows/cold-install.yml"
test ! -e "$out/x/.github/workflows/cold-install.yml"
test ! -e "$out/b/.github/workflows/cold-install.yml"
test -f "$out/d/.github/workflows/cold-install.yml"
# A change to the lockfile or the interpreter pin can break the first setup.
for p in '"**/pyproject.toml"' '"**/uv.lock"' '"**/.python-version"'; do
  grep -qF -- "$p" "$out/d/.github/workflows/cold-install.yml"
done
# py-matrix is a library recipe over the versions python.yml tests, and cold-install skips it.
# shellcheck disable=SC2016 # the recipe's literal "$v"
grep -qF 'for v in 3.12 3.13 3.14; do uv --directory api run --isolated --locked --python "$v" pytest' c/just/python.just
grep -qF 'python: ["3.12", "3.13", "3.14"]' c/.github/workflows/python.yml
grep -qF 'just py-matrix ' c/README.md
(lacks -q 'py-matrix' a/just/python.just d/just/python.just)
(lacks -q 'py-matrix' c/.github/workflows/python.yml)
cold c >"$out/c-matrix.sh"
(lacks -q 'py-matrix' "$out/c-matrix.sh")
# The README installs the prek that checks.yml runs, and justfile explains the SKIP gap.
prek_ci=$(sed -n 's/^ *PREK_VERSION: *//p' c/.github/workflows/checks.yml)
grep -qF "uv tool install prek==$prek_ci " a/README.md
# The other two literal prek pins, so a Renovate bump that misses one fails here.
grep -qx "  PREK_VERSION: $prek_ci" c/.github/workflows/advisories.yml
grep -qxF "    \"@j178/prek\": \"^$prek_ci\"," a/package.json
grep -qF 'checks workflow skips' c/justfile
grep -q 'Private :: Do Not Upload' a/pyproject.toml
(lacks -q 'Development Status' a/pyproject.toml)
(lacks -q 'keywords =' a/pyproject.toml)
(lacks -q 'Changelog =' a/pyproject.toml)
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
grep -q 'by email to <ada@example.com>' a/.github/SECURITY.md
# Each stack's text where that stack is rendered.
grep -qx '# Python' a/.gitignore
# A TypeScript-only package still ignores its build output, which biome would lint.
grep -qx 'dist/' t/.gitignore
grep -qx "import? 'just/python.just'" a/justfile
grep -qF 'uv lock' a/.github/workflows/copier-update.yml
grep -q 'SKIP: ruff-check,ruff-format,ty,biome,tsc,cargo-fmt,cargo-clippy,golangci-lint-fmt,golangci-lint,betterleaks,zizmor$' a/.github/workflows/checks.yml
grep -q 'NumPy' a/_typos.toml
# Scorecard: its workflow and badge exist only with public (a), never without (b).
grep -qx '      id-token: write # to publish the results' a/.github/workflows/scorecard.yml
grep -q 'scorecard.dev/viewer/?uri=github.com/' a/README.md
test ! -e b/.github/workflows/scorecard.yml
(lacks -q -i scorecard b/README.md)
# A badge render's README says how to get the software and leaves a TODO for what it does
# and its basic use (OpenSSF interact, description_good, documentation_basics; Baseline
# DO-01.01). m publishes to npm only. c is at level minimal, and b is private.
grep -qx '## Usage' m/README.md
grep -qF '<!-- TODO: say what this software does and the problem it solves, then show its basic use.' m/README.md
# shellcheck disable=SC2016 # literal backticks
grep -qF 'Get it from the [releases](https://github.com/example-org/mutate-me/releases), from [npm](https://www.npmjs.com/package/mutate-me) (`pnpm add mutate-me`), or clone the repository.' m/README.md
grep -qx '## Usage' h/README.md
grep -qx '## Usage' a/README.md
for r in b c; do (lacks -qx '## Usage' "$r/README.md"); done
# fair-software.eu: the weekly howfairis workflow and its badge need a citable kind (a, research)
# and public. b is private; h, a public Go library, gets both.
grep -qx "          uvx --exclude-newer \"1 week\" --from git+https://github.com/fair-software/howfairis@$howfairis_pin howfairis $(grep -o 'https://github.com/[^/]*/render-me' a/CITATION.cff | head -1) | tee out.txt || true" a/.github/workflows/fair.yml
# shellcheck disable=SC2016 # the $ is literal workflow text
grep -qF 'cat out.txt >> "$GITHUB_STEP_SUMMARY"' a/.github/workflows/fair.yml
grep -qx '      FAIR_MIN: 3' a/.github/workflows/fair.yml
grep -qxF "      APIKEY_GITHUB: x-access-token:\${{ github.token }}" a/.github/workflows/fair.yml
grep -qx 'permissions: {}' a/.github/workflows/fair.yml
(lacks -q continue-on-error a/.github/workflows/fair.yml)
# howfairis order: repository, license, registry, citation, checklist.
# The badge waits for 5 of 5, so no render ships one.
(lacks -q fair-software.eu a/README.md)
test ! -e b/.github/workflows/fair.yml
(lacks -q fair-software.eu b/README.md)
test -f h/.github/workflows/fair.yml
(lacks -q fair-software.eu h/README.md)
# Badges follow their answers: a has codspeed only; c has codecov, codspeed, PyPI and npm;
# d has codecov alone; b has none.
grep -qF 'https://app.codspeed.io/' a/README.md
(lacks -q -e codecov.io -e img.shields.io/pypi -e img.shields.io/npm a/README.md)
grep -qF 'https://codecov.io/gh/' c/README.md
grep -qF 'https://app.codspeed.io/' c/README.md
grep -qF 'img.shields.io/pypi/v/mono-me' c/README.md
grep -qF 'img.shields.io/pypi/pyversions/mono-me' c/README.md
grep -qF 'img.shields.io/npm/v/mono-me' c/README.md
grep -qF 'https://codecov.io/gh/' d/README.md
(lacks -q -e codspeed -e img.shields.io/pypi -e img.shields.io/npm d/README.md)
(lacks -q -e codecov -e codspeed -e img.shields.io/pypi -e img.shields.io/npm b/README.md)
# The weekly audit: one job per stack, on a Monday schedule. python.yml keeps its own
# schedule for the data pipeline (d) and has none elsewhere.
for r in a b c d; do grep -q 'cron: "23 5 \* \* 1"' "$r/.github/workflows/advisories.yml"; done
for j in actions python ts rust go; do grep -q "^  $j:" a/.github/workflows/advisories.yml; done
grep -q 'extra-args: zizmor --all-files' a/.github/workflows/advisories.yml
grep -q 'cargo deny check advisories' a/.github/workflows/advisories.yml
grep -q 'go tool govulncheck' a/.github/workflows/advisories.yml
grep -q 'uv audit --locked' a/.github/workflows/advisories.yml
grep -q 'pnpm audit --prod' a/.github/workflows/advisories.yml
(lacks -q -e '^  rust:' -e '^  go:' b/.github/workflows/advisories.yml)
grep -q 'working-directory: svc' b/.github/workflows/advisories.yml
grep -q 'working-directory: crates/cli' c/.github/workflows/advisories.yml
grep -q 'working-directory: services/tool' c/.github/workflows/advisories.yml
grep -q 'working-directory: apps/web' c/.github/workflows/advisories.yml
grep -q 'cron: "0 6 \* \* 1"' d/.github/workflows/python.yml
(lacks -q 'cron:' a/.github/workflows/python.yml)
test -f h/.github/workflows/advisories.yml
(lacks -q -e '^  python:' -e '^  ts:' h/.github/workflows/advisories.yml)
grep -qx '## \[Unreleased\]' a/CHANGELOG.md
# Decision records default on for a web service (b), a data pipeline or web app (d) and a
# Silver badge (h); off for research (a), a monorepo of libraries (c) and an unlicensed tool (i).
for r in b d h; do
  test -f "$r/docs/decisions/0001-start-from-project-templates.md"
done
for r in a c i; do
  test ! -e "$r/docs/decisions"
  (lacks -q 'docs/decisions' "$r/AGENTS.md")
done
(lacks -rq vale a/.pre-commit-config.yaml a/.gitignore)
# Every render runs the hooks in CI.
test -f a/.github/workflows/checks.yml
test -f b/.github/workflows/checks.yml
# Citation files for each licensed library kind and Python's research and data-pipeline
# kinds, at the root even when nested, and never a .zenodo.json. w, an app, gets none, and
# neither does b, a library with no license, since a Zenodo record needs one.
for r in a c d h m r t; do
  for f in CITATION.cff codemeta.json; do
    test -f "$r/$f"
  done
  test ! -e "$r/.zenodo.json"
  grep -q 'id: citesync$' "$r/.pre-commit-config.yaml"
  grep -q 'id: citesync-write$' "$r/.pre-commit-config.yaml"
  grep -q '^citation:' "$r/justfile"
done
for r in b w; do
  for f in CITATION.cff .zenodo.json codemeta.json citesync.toml; do
    test ! -e "$r/$f"
  done
  (lacks -q citesync "$r/.pre-commit-config.yaml")
  (lacks -q '^citation' "$r/justfile")
done
grep -q check-citation-file-format c/.pre-commit-config.yaml
(lacks -q check-citation-file-format w/.pre-commit-config.yaml)
grep -qx '    pnpm exec prek run citesync --all-files' t/justfile
# citesync reads root manifests unless told otherwise, so a nested one gets listed.
grep -qx 'manifests = \["py/pyproject.toml", "crates/lib/Cargo.toml", "web/package.json"\]' m/citesync.toml
grep -qx 'manifests = \["api/pyproject.toml", "crates/cli/Cargo.toml", "apps/web/package.json"\]' c/citesync.toml
for r in a r t; do
  test ! -e "$r/citesync.toml"
done
grep -qx '  "programmingLanguage": "Rust"' r/codemeta.json
grep -qx '  "programmingLanguage": "TypeScript"' t/codemeta.json
grep -qx '  "programmingLanguage": \["Python", "TypeScript", "Rust", "Go"\]' a/codemeta.json
# The library (c) is tested from python_min up and declares that floor; other
# kinds pin python_version and run once.
min=$(sed -n 's/^python_min: *//p' c/.copier-answers.yml | tr -d "\"'")
grep -qx "requires-python = \">=$min\"" c/api/pyproject.toml
grep -q 'Development Status :: 3 - Alpha' c/api/pyproject.toml
grep -q 'Programming Language :: Python :: 3' c/api/pyproject.toml
grep -q "Programming Language :: Python :: $min" c/api/pyproject.toml
grep -q 'Typing :: Typed' c/api/pyproject.toml
grep -qx 'keywords = \[\] # citesync compares this list to keywords in CITATION.cff' c/api/pyproject.toml
grep -q 'Changelog = "https://github.com/[^/]*/mono-me/blob/main/CHANGELOG.md"' c/api/pyproject.toml
(lacks -q 'Private :: Do Not Upload' c/api/pyproject.toml)
grep -q "python: \[\"$min\"" c/.github/workflows/python.yml
(lacks -q 'matrix' a/.github/workflows/python.yml)
# Codecov (c only): one upload per stack, from the nested paths, with a flag each,
# and the Python one from a single matrix job.
test -f c/codecov.yml
test ! -e a/codecov.yml
# The patch check is the gate at 90%; total coverage is information only.
grep -qx '        target: 90%' c/codecov.yml
grep -A2 'project:' c/codecov.yml | grep -qx '        informational: true'
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
# Pull requests run the benchmarks only when benchmarked code changes: a at the root, c nested in api/.
grep -qxF '      - "benches/**"' a/.github/workflows/benchmarks.yml
grep -qxF '      - "api/**"' c/.github/workflows/benchmarks.yml
# profiling: a and c have it, nested in c, so the manifest path reaches the build; b and d do not.
grep -qx '\[profile.profiling\]' a/Cargo.toml
grep -qx '\[profile.profiling\]' c/crates/cli/Cargo.toml
grep -qF 'cargo build --profile profiling' a/just/rust.just
grep -qF 'cargo build --manifest-path crates/cli/Cargo.toml --profile profiling' c/just/rust.just
grep -qx 'py-profile \*args:' a/just/python.just
grep -qx 'py-profile \*args:' c/just/python.just
(lacks -rq 'py-profile' b/just d/just)
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
  (lacks -rq codspeed "$r" --include=pyproject.toml --include=Cargo.toml)
done
# The data-pipeline workflow has its own pytest line, so d checks its coverage flags.
grep -qx '      - run: uv run pytest --cov --cov-report=xml' d/.github/workflows/python.yml
(lacks -q codecov a/.github/workflows/python.yml a/.github/workflows/ts.yml)
grep -qx '      - run: pnpm run test' a/.github/workflows/ts.yml
# test_extras: asked only with a library kind (d has none), off by default (a's rust
# and go libraries get no property-test or mutation dependency).
(lacks -q '^test_extras' d/.copier-answers.yml)
grep -qx 'test_extras: \[\]' a/.copier-answers.yml
(lacks -q -e proptest -e gremlins a/Cargo.toml a/go.mod)
# mutation.yml: only with the extra, one job per library stack, weekly and by hand only.
test -f m/.github/workflows/mutation.yml
test ! -e a/.github/workflows/mutation.yml
uv run --no-project --with pyyaml python - <<'PY'
import yaml
wf = yaml.safe_load(open("m/.github/workflows/mutation.yml"))
assert set(wf["jobs"]) == {"python", "ts", "rust", "go", "notify"}, wf["jobs"].keys()
assert set(wf[True]) == {"schedule", "workflow_dispatch"}, wf[True]
assert wf["permissions"] == {"contents": "read"}, wf["permissions"]
assert all("timeout-minutes" in j for k, j in wf["jobs"].items() if k != "notify")
assert wf["jobs"]["notify"]["uses"] == "$/.github/workflows/report-failure.yml"
# A failed scheduled run reports itself, and only that job may write issues.
n = wf["jobs"]["notify"]
assert set(n["needs"]) == {"python", "ts", "rust", "go"}, n["needs"]
assert n["if"] == "always() && github.event_name == 'schedule' && (contains(needs.*.result, 'failure') || contains(needs.*.result, 'cancelled'))", n["if"]
assert n["permissions"] == {"issues": "write"}, n["permissions"]
for stack in ("py", "ts", "rs", "go"):
    assert any(f"just {stack}-mutation" in s.get("run", "") for j in wf["jobs"].values() for s in j["steps"]), stack
# cargo mutants --dir writes mutants.out inside rust_dir: the check and the upload follow it.
steps = wf["jobs"]["rust"]["steps"]
assert any("test ! -s crates/lib/mutants.out/missed.txt" in s.get("run", "") for s in steps), steps
assert any(s.get("with", {}).get("path") == "crates/lib/mutants.out/" for s in steps), steps
PY
# The python gate: a baseline file, a clean start, byte-order sorting, a failure both ways.
test -f m/py/tests/mutation-baseline.txt
test ! -e a/tests/mutation-baseline.txt
grep -qxF '    rm -rf mutants' m/just/python.just
grep -qxF '    export LC_ALL=C' m/just/python.just
# shellcheck disable=SC2016 # a literal recipe line
grep -qxF '    [ -z "$new$gone" ]' m/just/python.just
# mutmut's output shows why the gate failed, and the diff recipe reuses the gate. ci.yml's
# python job runs both against a broken baseline and an untested function.
(lacks -q 'mutmut run.*/dev/null' m/just/python.just)
# shellcheck disable=SC2016 # a literal recipe line
grep -qF ' py-mutation $patterns' m/just/python.just
# The per-change recipes: python maps the diff to functions with a script, rust and go use
# the tool's own diff mode, ts has no mutation-diff recipe (Stryker has no diff mode).
test -f m/just/mutation_diff.py
test ! -e a/just/mutation_diff.py
grep -q '^py-mutation-diff base=' m/just/python.just
grep -q 'cd py$' m/just/python.just
grep -q -e '--in-diff' m/just/rust.just
grep -q -e '--relative=crates/lib' m/just/rust.just
grep -q -e 'unleash --diff' m/just/go.just
# Each diffs against where the branch split off, not main's tip, so a branch behind
# main does not mutate functions only main changed.
for f in python rust go; do grep -q 'git merge-base' "m/just/$f.just"; done
(lacks -q 'mutation-diff' m/just/ts.just)
grep -q '^just py-mutation-diff ' m/README.md
(lacks -q 'ts-mutation-diff' m/README.md)
# mutation_diff.py names only the changed methods, matches only_mutate and do_not_mutate as
# globs the way mutmut does, and skips a function mutmut leaves alone for its decorator.
mutdiff="$out/mutdiff"
mkdir -p "$mutdiff/src/pkg" && cp m/just/mutation_diff.py "$mutdiff/"
(
  cd "$mutdiff"
  printf '[tool.mutmut]\nsource_paths = ["src/pkg"]\nonly_mutate = ["src/pkg/*"]\ndo_not_mutate = ["*/b.py"]\n' >pyproject.toml
  printf 'def f():\n    return 1\n\n\nclass C:\n    def m(self):\n        return 1\n\n    def n(self):\n        return 1\n\n    @staticmethod\n    def s():\n        return 1\n\n\n@cache\ndef g():\n    return 1\n' >src/pkg/a.py
  cp src/pkg/a.py src/pkg/b.py
  git init -q && git add -A && git -c user.name=t -c user.email=t@t.test commit -qm base --no-verify
  sed -i 's/return 1/return 2/' src/pkg/b.py
  sed -i -e '7s/1/2/' -e '14s/1/2/' -e '19s/1/2/' src/pkg/a.py
  test "$(python3 -I mutation_diff.py HEAD 2>stderr.txt)" = "$(printf 'pkg.a.xǁCǁm__mutmut_*\npkg.a.xǁCǁs__mutmut_*')"
  test "$(cat stderr.txt)" = 'skipped (decorated): pkg.a.g'
)
# just --list shows only the comment line directly above a recipe: a block of two or more
# lines there would show its last line alone, so the detail sits behind a blank line.
for f in m/justfile m/just/*.just; do
  (lacks -q 'multi-line doc comment' <(awk '/^#/ { n++; next } /^[{a-z]/ && /:/ && n > 1 { print "multi-line doc comment: " FILENAME ": " $0 } { n = 0 }' "$f"))
done
# property.yml names Go's FuzzAdd only when the project has the Go library (m does, x is Python only).
grep -q 'FuzzAdd' m/.github/workflows/property.yml
test -f x/.github/workflows/property.yml
(lacks -q 'FuzzAdd' x/.github/workflows/property.yml)
# go-mutation-diff reads the diff relative to go_dir, or gremlins finds no changed lines there.
grep -qF 'GIT_CONFIG_KEY_0=diff.relative' m/just/go.just
# property.yml: the same shape, running each stack's property or fuzz recipe.
test -f m/.github/workflows/property.yml
test ! -e a/.github/workflows/property.yml
uv run --no-project --with pyyaml python - <<'PY'
import yaml
wf = yaml.safe_load(open("m/.github/workflows/property.yml"))
assert set(wf["jobs"]) == {"python", "ts", "rust", "go", "notify"}, wf["jobs"].keys()
assert set(wf[True]) == {"schedule", "workflow_dispatch"}, wf[True]
assert wf["permissions"] == {"contents": "read"}, wf["permissions"]
n = wf["jobs"].pop("notify")
assert set(n["needs"]) == {"python", "ts", "rust", "go"}, n["needs"]
assert n["if"] == "always() && github.event_name == 'schedule' && (contains(needs.*.result, 'failure') || contains(needs.*.result, 'cancelled'))", n["if"]
assert n["permissions"] == {"issues": "write"}, n["permissions"]
assert all(j["timeout-minutes"] == 60 for j in wf["jobs"].values())
for job, recipe in (("python", "py-property"), ("ts", "ts-property"), ("rust", "rs-property"), ("go", "go-property")):
    assert any(s.get("run") == f"just {recipe}" for s in wf["jobs"][job]["steps"]), job
# go-property runs in go_dir, so the failing inputs land under it.
assert any(s.get("with", {}).get("path") == "svc/testdata/fuzz/" for s in wf["jobs"]["go"]["steps"])
steps = wf["jobs"]["go"]["steps"]
cache = next(s for s in steps if s.get("uses", "").startswith("actions/cache@"))
assert cache["with"]["path"] == "${{ steps.fuzz-cache.outputs.path }}/fuzz"
assert cache["with"]["key"] == "go-fuzz-${{ runner.os }}-${{ github.run_id }}-${{ github.run_attempt }}"
assert cache["with"]["restore-keys"] == "go-fuzz-${{ runner.os }}-"
assert steps.index(cache) < next(i for i, s in enumerate(steps) if s.get("run") == "just go-property")
PY
for stack in py ts rs go; do
  grep -q "^just $stack-property " m/README.md
done
test -f m/py/tests/conftest.py
test ! -e k/tests/conftest.py
