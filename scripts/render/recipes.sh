# shellcheck shell=bash
# shellcheck disable=SC2154,SC2164 # check-render.sh sets out, repo, copier and set -e
# The image stub, the tests per kind, the check recipes and the workflow run lines.

# PID 1 ignores SIGTERM without a handler, so the image stub installs one.
grep -q SIGTERM a/src/render_me/__main__.py

# Each kind gets its own tests and no other kind's. Dropping a filename condition
# renders nothing, which no parse or CI row notices.
test -f b/svc/tests/test_app.py
test ! -e a/tests/test_app.py
test -f c/api/tests/test_add.py
test ! -e b/svc/tests/test_add.py
test -f d/pipe/tests/test_pipeline.py
test -f d/pipe/tests/test_published.py
grep -qx 'output_format = "parquet"' d/pipe/sources.toml
grep -qF 'sourceledger[parquet]' d/pipe/pyproject.toml
grep -qF 'data/processed/example.parquet' d/pipe/tests/test_pipeline.py
# sourceledger 0.5 exits 3 when a stage cannot run, and read_output yields rows once.
grep -qF 'pipeline.main(["build"]) == 3' d/pipe/tests/test_pipeline.py
grep -qF 'rows = list(pipeline.sourceledger.read_output(OUT))' d/pipe/tests/test_pipeline.py
grep -qF 'f"example-co2.{OUTPUT_FORMAT}"' d/pipe/tests/test_published.py
# sourceledger releases resolve without the week's wait, whoever owns the project, since the template's
# own floor may be younger than a week; other packages keep it.
grep -qx 'exclude-newer-package = { sourceledger = false }' d/pipe/pyproject.toml
(lacks -q 'exclude-newer-package' a/pyproject.toml)
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
# --locked: CI's uv sync --locked fails on a stale uv.lock, so py-check must not rewrite it.
for cmd in 'uv run --locked ruff check' 'uv run --locked ruff format --check' 'uv run --locked ty check' \
  'uv run --locked pytest' 'uv audit --locked --preview-features audit-command'; do
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
# nextest skips doctests, so a library runs them apart, in the recipe and in CI.
recipe_has a/just/rust.just rs-check '    cargo test --doc --all-features'
grep -qx '      - run: cargo test --doc --all-features' a/.github/workflows/rust.yml
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
# dependency-licenses: each stack lists the licenses of the dependencies that ship and
# fails on one the license answer cannot take. a is MIT, so the GPL family stays out of
# the allow-list; agl is AGPL, so it goes in. The pins come from copier.yml, so a version
# bump needs no edit here.
osv_pin=$(sed -n '/^osv_scanner_version:/,/^$/s/^  default: //p' "$repo/copier.yml")
lc='run --locked --isolated --no-default-groups --all-extras --all-packages python scripts/check_licenses.py'
recipe_has a/just/python.just py-check "    uv $lc"
recipe_has c/just/python.just py-check "    uv --directory api $lc"
# The metadata path: fake installed packages, read without the host's site-packages (-S).
# The project and its workspace members are skipped by name; a local-path dependency is not.
meta=$(mktemp -d)
fake() {
  mkdir -p "$meta/site/$1-1.0.dist-info"
  printf 'Metadata-Version: 2.4\nName: %s\nVersion: 1.0\n%b' "$1" "$2" >"$meta/site/$1-1.0.dist-info/METADATA"
}
fake render-me 'License-Expression: GPL-3.0-only\n'
fake member 'License-Expression: GPL-3.0-only\n'
fake spdx 'License-Expression: MIT OR Apache-2.0\n'
fake classified 'Classifier: License :: OSI Approved :: MIT License\n'
fake texted 'License: BSD 3-Clause License\n'
fake vendored 'License-Expression: GPL-3.0-only\n'
printf '{"url": "file:///src/vendored", "dir_info": {}}' >"$meta/site/vendored-1.0.dist-info/direct_url.json"
fake custom 'License: Free for non-commercial use\n'
# A long License field continues on indented lines.
fake prose 'License: MIT with restrictions\n'
fake titled 'License: MIT License\n        Permission is hereby granted...\n'
fake hidden 'License: MIT\n        Except vendored/, which is GPL-3.0-only\n'
printf '[project]\nname = "render-me"\n' >"$meta/pyproject.toml"
printf 'version = 1\n[manifest]\nmembers = ["member", "render-me"]\n' >"$meta/uv.lock"
rc=0
(cd "$meta" && PYTHONPATH=site python3 -S "$out/a/scripts/check_licenses.py") >"$meta/out" 2>&1 || rc=$?
printf '%s\n' 'ok  classified==1.0: MIT' 'NOT ALLOWED  custom==1.0: Free for non-commercial use' \
  'NOT ALLOWED  hidden==1.0: MIT ...' 'NOT ALLOWED  prose==1.0: MIT with restrictions' \
  'ok  spdx==1.0: MIT OR Apache-2.0' 'ok  texted==1.0: BSD-3-Clause' 'ok  titled==1.0: MIT' \
  'NOT ALLOWED  vendored==1.0: GPL-3.0-only' >"$meta/want"
grep -E '^(ok|NOT ALLOWED) ' "$meta/out" | diff "$meta/want" -
test "$rc" = 1
grep -qF 'record it under KNOWN' "$meta/out"
rm -rf "$meta"
test -f c/api/scripts/check_licenses.py
recipe_has a/just/ts.just ts-check '    pnpm run licenses'
grep -qF '"licenses": "pnpm licenses list --prod --json | node scripts/checkLicenses.mjs"' a/package.json
lacks -F 'GPL' a/scripts/checkLicenses.mjs a/deny.toml
# The repo's own CI runs a copy of the MIT render's script; only its header and file name differ.
diff <(sed 1,2d a/scripts/checkLicenses.mjs | grep -v allow-list) \
  <(sed 1,2d "$repo/scripts/check-licenses.mjs" | grep -v allow-list)
# The TypeScript and Python checkers parse one SPDX grammar against one allow-list, so every
# case runs through both. TypeScript reads `pnpm licenses list --json` output.
licenses_pass() {
  printf '{"%s":[{"name":"p","versions":["1.0.0"]}]}' "$2" | node "$1/scripts/checkLicenses.mjs" >/dev/null 2>&1
}
py_licenses_pass() {
  python3 "$1/scripts/check_licenses.py" "$2" >/dev/null 2>&1
}
# verdict RENDER allow|refuse EXPRESSION...
verdict() {
  local r=$1 want=$2 l check got
  shift 2
  for l in "$@"; do
    for check in licenses_pass py_licenses_pass; do
      if "$check" "$r" "$l"; then got=allow; else got=refuse; fi
      [ "$got" = "$want" ] || {
        echo "$check: the $r render should $want '$l'" >&2
        exit 1
      }
    done
  done
}
# glob, minimatch and lru-cache are BlueOak-1.0.0, argparse is PSF-2.0 or Python-2.0, pillow MIT-CMU.
verdict a allow MIT mit Zlib Unicode-3.0 MIT-CMU BlueOak-1.0.0 PSF-2.0 Python-2.0 BSL-1.0 MIT-0 \
  Unlicense CDLA-Permissive-2.0 '(MIT OR Apache-2.0)' 'MIT OR GPL-3.0-only' '((MIT))' \
  '(MIT AND BSD-3-Clause) OR Proprietary' 'MIT OR GPL-3.0-only AND ISC' \
  'Apache-2.0 WITH LLVM-exception' 'MIT AND (Apache-2.0 OR GPL-3.0-only)' 'MIT OR GPL-3.0-only AND CC-BY-4.0'
verdict a refuse LGPL-2.1-only LGPL-2.1-or-later LGPL-3.0-or-later GPL-3.0-only 'MIT AND GPL-3.0-only' \
  'GPL-3.0-only AND (MIT OR Apache-2.0)' '(MIT OR GPL-3.0-only) AND GPL-3.0-only' \
  '(MIT OR GPL-3.0-only) AND CC-BY-4.0' 'GPL-2.0-or-later WITH Classpath-exception-2.0' \
  'GPL-3.0-only AND MIT OR GPL-3.0-only' UNKNOWN Unknown LicenseRef-Proprietary 'Public Domain' \
  'MIT OR' 'MIT ISC' '(MIT' 'MIT)' 'MIT WITH' 'MIT WITH OR' 'MIT WITH )' ''
verdict agl allow LGPL-2.1-or-later GPL-3.0-only AGPL-3.0-only 'GPL-3.0-only AND (MIT OR Apache-2.0)'
verdict agl refuse LGPL-2.1-only GPL-2.0-only
# A GPL project takes the GPL but not the AGPL, whose network clause its license lacks.
verdict gpl allow GPL-3.0-only LGPL-2.1-or-later
verdict gpl refuse AGPL-3.0-only LGPL-2.1-only
# The Python checker reads operators case-sensitively, as SPDX spells them; the License
# metadata field can hold prose.
for l in 'MIT with restrictions' 'MIT or GPL-3.0-only'; do
  if py_licenses_pass a "$l"; then
    echo "check_licenses.py lets '$l' into an MIT project" >&2
    exit 1
  fi
done
recipe_has a/just/rust.just rs-check '    cargo deny list'
# webpki-roots (via reqwest) is CDLA-Permissive-2.0, target-lexicon Apache-2.0 WITH
# LLVM-exception; cargo-deny wants a WITH expression listed whole.
for l in CDLA-Permissive-2.0 BSL-1.0 'Apache-2.0 WITH LLVM-exception'; do
  grep -qxF "  \"$l\"," a/deny.toml
done
for l in AGPL-3.0-or-later GPL-3.0-or-later GPL-3.0-only LGPL-3.0-or-later; do
  grep -qxF "  \"$l\"," agl/deny.toml
done
gl="go run github.com/google/osv-scanner/v2/cmd/osv-scanner@$osv_pin scan source"
permissive=0BSD,Apache-2.0,BlueOak-1.0.0,BSD-2-Clause,BSD-3-Clause,BSL-1.0,CC0-1.0,CDLA-Permissive-2.0,ISC,MIT,MIT-0,MIT-CMU,MPL-2.0,PSF-2.0,Python-2.0,Unicode-3.0,Unlicense,Zlib
recipe_has a/just/go.just go-check "    $gl --licenses=$permissive -L go.mod"
recipe_has agl/just/go.just go-check "    $gl --licenses=$permissive,GPL-2.0-or-later,GPL-3.0-only,GPL-3.0-or-later,LGPL-2.1-or-later,LGPL-3.0-only,LGPL-3.0-or-later,AGPL-3.0-only,AGPL-3.0-or-later -L go.mod"
# A project without a license has nothing to be compatible with: no check.
lacks -F check_licenses b/just/python.just
test ! -e b/svc/scripts
test ! -e b/scripts/checkLicenses.mjs
lacks -F osv-scanner i/just/go.just
recipe_has a/justfile check '    @just py-check'
recipe_has a/justfile check '    @just ts-check'
# Whitespace control around the fmt recipe's last line must not glue the next comment onto it.
for r in a h t; do
  test "$(grep -B1 -x '# The checks workflow skips the hooks in its SKIP list, which the stack workflows run' "$r/justfile" | head -1)" = ''
  grep -qx '# Run every git hook over the whole repo, not just staged files.' "$r/justfile"
done

# AGENTS.md names the check and test recipes, so each must be one the justfile has.
# h is go alone and d a nested web app, beside every stack in a and c.
# shellcheck disable=SC2016 # the backticks are literal Markdown
for r in a c d h; do
  check=$(sed -n 's/^Run `just \([a-z-]*\)` before.*/\1/p' "$r/AGENTS.md")
  test -n "$check"
  recipes=" $(cd "$r" && just --summary) "
  [[ $recipes == *" $check "* ]]
  for t in $(grep -o '`just [a-z]*-test`' "$r/AGENTS.md" | tr -d '`' | cut -d' ' -f2); do
    [[ $recipes == *" $t "* ]]
  done
done
test "$(grep -c -- '-test`' a/AGENTS.md)" = 4
# shellcheck disable=SC2016
grep -qF 'are in `web/docs/`' d/AGENTS.md
(lacks -q CONTRIBUTING b/AGENTS.md)
# A repo's own recipes in just/local.just appear in just --list:
cat >a/just/local.just <<'JUST'
# Run a custom local task.
local-custom:
    @echo local-custom
JUST
(cd a && just --list | grep -q 'local-custom')
rm -f a/just/local.just
# No hook lints a justfile's shebang recipes, so shellcheck their bodies in every render.
# The version argument becomes "$1", and gh's {owner}/{repo} placeholders plain words.
# SC2043: the release-environment loop runs once when the answers pick one registry.
for answers in */.copier-answers.yml; do
  for recipe in release repo-settings; do
    # shellcheck disable=SC2016 # a literal "$1" for the recipe body
    (cd "${answers%/*}" && just --show "$recipe") |
      sed -e '1,/^[a-z-]*\( [a-z]*\)*:$/d' -e 's/^    //' -e 's/{{ version }}/"$1"/' -e 's/{owner}\/{repo}/OWNER\/REPO/g' |
      shellcheck -s bash -e SC2043 - || {
      echo "${answers%/*}: just $recipe fails shellcheck" >&2
      exit 1
    }
  done
done

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
grep -qxF "      - run: uv $lc" a/.github/workflows/python.yml
grep -qx '      - run: pnpm run licenses' a/.github/workflows/ts.yml
grep -qx '      - run: cargo deny list' a/.github/workflows/rust.yml
grep -qxF "      - run: $gl --licenses=$permissive -L go.mod" a/.github/workflows/go.yml
# Trusted publishing and attestations need the job-level write scopes; the
# workflow-level grant stays read-only.
grep -q '^      id-token: write ' c/.github/workflows/python-release.yml
grep -qx '      attestations: write' c/.github/workflows/python-release.yml
grep -q '^      artifact-metadata: write' c/.github/workflows/python-release.yml
grep -q '^      id-token: write ' c/.github/workflows/ts-release.yml
# The publish step: npm, from a tarball built earlier.
grep -qx '            npm publish --access public ./\*.tgz' c/.github/workflows/ts-release.yml
# shellcheck disable=SC2016 # a literal $pkg for the runner's shell
grep -qF 'npm view "$pkg" dist.integrity' c/.github/workflows/ts-release.yml
(lacks -q '^  id-token' c/.github/workflows/python-release.yml c/.github/workflows/ts-release.yml)
# The GitHub release waits for the npm publish (t, npm only) and the plain release.yml is not
# rendered beside it; with PyPI too, python-release.yml makes the release (c).
test ! -e t/.github/workflows/release.yml
uv run --no-project --with pyyaml python - t/.github/workflows/ts-release.yml c/.github/workflows/ts-release.yml <<'PYTEST'
import sys, yaml
only, both = (yaml.safe_load(open(p))["jobs"] for p in sys.argv[1:])
assert only["release"]["needs"] == "publish", only["release"]
assert only["release"]["permissions"] == {"contents": "write"}, only["release"]
assert "release" not in both, both.keys()
assert not any("checkout" in s.get("uses", "") for s in only["release"]["steps"]), "the write token runs no project code"
PYTEST
