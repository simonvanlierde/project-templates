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
# sourceledger releases resolve without the week's wait; other packages keep it.
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
lc_pin=$(sed -n '/^licensecheck_version:/,/^$/s/^  default: //p' "$repo/copier.yml")
gl_pin=$(sed -n '/^go_licenses_version:/,/^$/s/^  default: //p' "$repo/copier.yml")
# shellcheck disable=SC2016 # a literal $d for the recipe's shell
export_args='export --locked --no-default-groups --no-hashes --no-annotate --no-header --no-emit-project -q -o "$d/requirements.txt"'
lc="licensecheck==$lc_pin licensecheck -r \"\$d/requirements.txt\" --zero; }"
recipe_has a/just/python.just py-check "    d=\$(mktemp -d) && trap 'rm -rf \"\$d\"' EXIT && uv $export_args && { test ! -s \"\$d/requirements.txt\" || uv run --locked --with $lc"
recipe_has c/just/python.just py-check "    d=\$(mktemp -d) && trap 'rm -rf \"\$d\"' EXIT && uv --directory api $export_args && { test ! -s \"\$d/requirements.txt\" || uv --directory api run --locked --with $lc"
# licensecheck reads AGPL-3.0-or-later as the GPL, which refuses AGPL dependencies.
recipe_has agl/just/python.just py-check "    d=\$(mktemp -d) && trap 'rm -rf \"\$d\"' EXIT && uv $export_args && { test ! -s \"\$d/requirements.txt\" || uv run --locked --with licensecheck==$lc_pin licensecheck --license AGPL -r \"\$d/requirements.txt\" --zero; }"
recipe_has a/just/ts.just ts-check '    pnpm run licenses'
grep -qF '"licenses": "pnpm licenses list --prod --json | node scripts/checkLicenses.mjs"' a/package.json
lacks -F 'GPL' a/scripts/checkLicenses.mjs a/deny.toml
# The TypeScript check on `pnpm licenses list --json` output: one package per license.
licenses_pass() {
  printf '{"%s":[{"name":"p","versions":["1.0.0"]}]}' "$2" | node "$1/scripts/checkLicenses.mjs" >/dev/null 2>&1
}
# glob, minimatch and lru-cache are BlueOak-1.0.0, argparse is PSF-2.0 or Python-2.0.
for l in MIT BlueOak-1.0.0 PSF-2.0 Python-2.0 BSL-1.0 MIT-0 Unlicense CDLA-Permissive-2.0 \
  '(MIT OR Apache-2.0)' 'MIT OR GPL-3.0-only' 'Apache-2.0 WITH LLVM-exception' 'mit' \
  '((MIT))' 'MIT AND (Apache-2.0 OR GPL-3.0-only)' 'MIT OR GPL-3.0-only AND CC-BY-4.0'; do
  licenses_pass a "$l" || {
    echo "checkLicenses.mjs refuses $l in an MIT project" >&2
    exit 1
  }
done
for l in GPL-3.0-only 'GPL-3.0-only AND (MIT OR Apache-2.0)' '(MIT OR GPL-3.0-only) AND CC-BY-4.0' \
  'GPL-2.0-or-later WITH Classpath-exception-2.0' Unknown LicenseRef-Proprietary 'MIT OR' \
  '(MIT' 'MIT)' 'MIT WITH' 'MIT WITH OR' 'MIT WITH )' 'GPL-3.0-only AND MIT OR GPL-3.0-only' ''; do
  if licenses_pass a "$l"; then
    echo "checkLicenses.mjs lets $l into an MIT project" >&2
    exit 1
  fi
done
for l in AGPL-3.0-only 'GPL-3.0-only AND (MIT OR Apache-2.0)'; do
  licenses_pass agl "$l" || {
    echo "checkLicenses.mjs refuses $l in an AGPL project" >&2
    exit 1
  }
done
if licenses_pass agl GPL-2.0-only; then
  echo "checkLicenses.mjs lets GPL-2.0-only into an AGPL project" >&2
  exit 1
fi
recipe_has a/just/rust.just rs-check '    cargo deny list'
# webpki-roots (via reqwest) is CDLA-Permissive-2.0, target-lexicon Apache-2.0 WITH
# LLVM-exception; cargo-deny wants a WITH expression listed whole.
for l in CDLA-Permissive-2.0 BSL-1.0 'Apache-2.0 WITH LLVM-exception'; do
  grep -qxF "  \"$l\"," a/deny.toml
done
for l in AGPL-3.0-or-later GPL-3.0-or-later GPL-3.0-only LGPL-3.0-or-later; do
  grep -qxF "  \"$l\"," agl/deny.toml
done
gl="go run github.com/google/go-licenses/v2@$gl_pin"
permissive=0BSD,Apache-2.0,BlueOak-1.0.0,BSD-2-Clause,BSD-3-Clause,BSL-1.0,CC0-1.0,CDLA-Permissive-2.0,ISC,MIT,MIT-0,MPL-2.0,PSF-2.0,Python-2.0,Unicode-3.0,Unlicense,Zlib
recipe_has a/just/go.just go-check "    $gl check --ignore github.com/example-org/render-me --allowed_licenses=$permissive ./..."
# go-licenses names the GPL family without -only or -or-later: AGPL-3.0, not AGPL-3.0-or-later.
recipe_has agl/just/go.just go-check "    $gl check --ignore github.com/example-org/agl-me --allowed_licenses=$permissive,GPL-3.0,LGPL-3.0,AGPL-3.0 ./..."
# A project without a license has nothing to be compatible with: no check.
lacks -F licensecheck b/just/python.just
test ! -e b/scripts/checkLicenses.mjs
lacks -F go-licenses i/just/go.just
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
# shellcheck disable=SC2016 # a literal $RUNNER_TEMP for the runner's shell
grep -qxF '      - run: uv export --locked --no-default-groups --no-hashes --no-annotate --no-header --no-emit-project -q -o "$RUNNER_TEMP/requirements.txt"' a/.github/workflows/python.yml
grep -qxF "      - run: test ! -s \"\$RUNNER_TEMP/requirements.txt\" || uv run --locked --with licensecheck==$lc_pin licensecheck -r \"\$RUNNER_TEMP/requirements.txt\" --zero" a/.github/workflows/python.yml
grep -qxF "      - run: test ! -s \"\$RUNNER_TEMP/requirements.txt\" || uv run --locked --with licensecheck==$lc_pin licensecheck --license AGPL -r \"\$RUNNER_TEMP/requirements.txt\" --zero" agl/.github/workflows/python.yml
grep -qx '      - run: pnpm run licenses' a/.github/workflows/ts.yml
grep -qx '      - run: cargo deny list' a/.github/workflows/rust.yml
grep -qx "      - run: $gl report --ignore github.com/example-org/render-me ./..." a/.github/workflows/go.yml
# Trusted publishing and attestations need the job-level write scopes; the
# workflow-level grant stays read-only.
grep -q '^      id-token: write ' c/.github/workflows/python-release.yml
grep -qx '      attestations: write' c/.github/workflows/python-release.yml
grep -q '^      artifact-metadata: write' c/.github/workflows/python-release.yml
grep -q '^      id-token: write ' c/.github/workflows/ts-release.yml
# The publish step: npm, from a tarball built earlier.
grep -qx '      - run: npm publish --access public ./\*.tgz' c/.github/workflows/ts-release.yml
(lacks -q '^  id-token' c/.github/workflows/python-release.yml c/.github/workflows/ts-release.yml)
