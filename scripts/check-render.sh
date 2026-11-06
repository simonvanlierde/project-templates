#!/usr/bin/env bash
# Renders the answer combinations that CI's stack jobs skip, and checks that each
# conditional file landed. Run from the repo root: scripts/check-render.sh "$(mktemp -d)"
#
# Renders HEAD plus uncommitted edits (--vcs-ref=HEAD). COPIER_VERSION pins
# copier; unset, it is the version ci.yml pins.
set -euo pipefail
# A bare test or grep below fails silently under set -e; say which line tripped.
trap 'echo "check-render: failed at line $LINENO" >&2' ERR
# A negated grep passes when the file is missing (grep exits 2). lacks passes only on exit 1, no match.
lacks() {
  local rc=0
  grep -q "$@" || rc=$?
  [ "$rc" -eq 1 ]
}
# A Compose-only render: no Dockerfile anywhere, the compose workflow, no image workflow.
no_image() {
  test -z "$(find "$1" -name 'Dockerfile*' -not -path '*/.git/*')"
  test -f "$1/.github/workflows/compose.yml"
  test ! -e "$1/.github/workflows/docker.yml"
}

bash scripts/check-release-fixtures.sh

out=${1:?usage: scripts/check-render.sh OUT_DIR}
# The identity answers have no defaults. CI's settings file fills them, and
# replaces your own copier settings for this run.
export COPIER_SETTINGS_PATH=$PWD/.github/ci-copier-settings.yml
COPIER_VERSION=${COPIER_VERSION:-$(sed -n 's/^ *COPIER_VERSION: *//p' .github/workflows/ci.yml)}
PREK_VERSION=${PREK_VERSION:-$(sed -n 's/^ *PREK_VERSION: *//p' .github/workflows/ci.yml)}
copier_pin=$(sed -n '/^copier_version:/,/^$/s/^  default: //p' copier.yml)
howfairis_pin=$(sed -n '/^howfairis_version:/,/^$/s/^  default: \([^ ]*\).*/\1/p' copier.yml)
copier=(uvx "copier${COPIER_VERSION:+@$COPIER_VERSION}" copy --defaults --overwrite)

# a: every stack, other answers at their defaults, but for an author name with a
# leading space. module_name is not set,
# so its slug-derived default renders.
"${copier[@]}" --vcs-ref=HEAD \
  --data project_name=render-me --data 'stacks=[python,ts,rust,go,docker]' \
  --data kind=research --data ts_kind=app \
  --data 'author_name= Ada Lovelace' \
  --data codspeed=true --data profiling=true \
  . "$out/a"

# b: public=false, so no SECURITY.md and a license that defaults to none, and a name, description and author name with punctuation that `slug`
# strips and `to_json` escapes. A nested web-service beside the root ts package,
# so the name also reaches the FastAPI title as a Python literal. The description's braces,
# `$` and `ï` test the escaping in the justfile and the Dockerfile labels.
# shellcheck disable=SC2016 # a literal $ in the description
"${copier[@]}" --vcs-ref=HEAD \
  --data 'project_name=Odd "Name" & Co!' \
  --data 'project_description=A "quoted" {{ one }}, naïve $USD' \
  --data 'author_name=Ada "X" Lovelace' \
  --data public=false --data openssf_badge=silver --data 'stacks=[python,ts,docker]' \
  --data kind=web-service --data python_dir=svc \
  . "$out/b"
# Explicit badge answers cannot add public-policy documents to a private project.
for f in GOVERNANCE.md docs/roadmap.md docs/assurance-case.md; do
  test ! -e "$out/b/$f"
done
# A Dockerfile string has no \u escapes and expands $, so neither may reach a LABEL.
# shellcheck disable=SC1003,SC2016 # the line's literal \$ and trailing \
grep -qxF '      org.opencontainers.image.description="A \"quoted\" {{ one }}, naïve \$USD" \' "$out/b/svc/Dockerfile"
# shellcheck disable=SC2016 # literal ${...} in docker compose default value
grep -qF 'OTEL_RESOURCE_ATTRIBUTES: ${OTEL_RESOURCE_ATTRIBUTES:-project=odd-name--co,env=dev}' "$out/b/compose.yaml"

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
  --data codspeed=true --data profiling=true \
  --data 'test_extras=[mutation]' \
  --data cold_install=true \
  --data publish_to_ghcr=true . "$out/c"

# d: nested data-pipeline with docker. Covers the nested paths in .gitignore, the
# workflow's artifact path and ATTRIBUTION.md. Also the only Apache-2.0 render, the
# only one with Renovate, and the only web-app: Preact, nested, so the e2e job's
# paths are audited with the rest. Its user_data answer is the one that adds terms.md.
# It also has the static site, so both kinds of preview share one retire workflow.
d_args=(
  --data project_name=pipe-me --data 'stacks=[python,ts,docker]'
  --data kind=data-pipeline --data python_dir=pipe --data license=Apache-2.0
  --data ts_dir=web --data ts_kind=web-app --data web_framework=preact --data user_data=accounts
  --data dependency_bot=renovate --data codecov=true --data cold_install=true
  --data site=plain
)
"${copier[@]}" --vcs-ref=HEAD \
  "${d_args[@]}" . "$out/d"

# The web-app starter files belong to the project: rendering d again over edited
# copies keeps them (_skip_if_exists), while a template-owned file is rewritten.
echo '// project edit' >>"$out/d/web/src/App.tsx"
echo '<!-- project edit -->' >>"$out/d/web/index.html"
echo '// project edit' >>"$out/d/web/vite.config.ts"
echo '<!-- project edit -->' >>"$out/d/web/docs/privacy.md"
echo '<!-- project edit -->' >>"$out/d/web/docs/accessibility-assessment.md"
"${copier[@]}" --vcs-ref=HEAD \
  "${d_args[@]}" . "$out/d" >/dev/null 2>&1
grep -q 'project edit' "$out/d/web/src/App.tsx"
grep -q 'project edit' "$out/d/web/index.html"
grep -q 'project edit' "$out/d/web/docs/privacy.md"
grep -q 'project edit' "$out/d/web/docs/accessibility-assessment.md"
(lacks -q 'project edit' "$out/d/web/vite.config.ts")

# h: a go library named like the Example file. The unit test must not share its path
# with example_test.go, which a project_name of `example` would otherwise claim. The
# only silver-badge render.
"${copier[@]}" --vcs-ref=HEAD \
  --data project_name=example --data 'stacks=[go]' --data openssf_badge=silver . "$out/h"
# go.mod belongs to the project once written: `go mod tidy` rewrites it.
echo '// project edit' >>"$out/h/go.mod"
# The badge documents are filled in by the project. Rendered first, then kept.
for f in GOVERNANCE.md docs/roadmap.md docs/assurance-case.md; do
  test -f "$out/h/$f"
  echo 'project edit' >>"$out/h/$f"
done
"${copier[@]}" --vcs-ref=HEAD \
  --data project_name=example --data 'stacks=[go]' --data openssf_badge=silver . "$out/h" >/dev/null 2>&1
for f in GOVERNANCE.md docs/roadmap.md docs/assurance-case.md; do
  grep -q 'project edit' "$out/h/$f"
done
grep -q 'project edit' "$out/h/go.mod"

# m: every stack a library, nested, with both extras: mutation.yml and property.yml get a
# job for each. a has libraries too but no extras, so it must render neither. Also the
# only BSD-3-Clause render, and the only npm-only publisher.
"${copier[@]}" --vcs-ref=HEAD \
  --data project_name=mutate-me --data 'stacks=[python,ts,rust,go]' \
  --data kind=library --data ts_kind=library --data rust_kind=library --data go_kind=library \
  --data python_dir=py --data ts_dir=web --data rust_dir=crates/lib --data go_dir=svc \
  --data 'test_extras=[property, mutation]' --data openssf_badge=passing \
  --data license=BSD-3-Clause --data publish_to_npm=true --data cold_install=true . "$out/m"
# x: a Python library that publishes but answers python_api=false (CLI-only): no api job.
# x and r have the static site without a package.json.
"${copier[@]}" --vcs-ref=HEAD --data project_name=cli-me --data 'stacks=[python]' \
  --data kind=library --data publish_to_pypi=true --data python_api=false --data site=plain . "$out/x"
# w: a Python app, the one render no citation file is for.
"${copier[@]}" --vcs-ref=HEAD --data project_name=app-me --data 'stacks=[python]' --data kind=app . "$out/w"
# r and t: a Rust and a TypeScript library alone, so each gets the citation files with
# only its own manifest beside them, and t's hooks run through pnpm. Both have the
# static site: r the plain one, t the Astro one beside a package at the root.
r_args=(--data project_name=crate-me --data 'stacks=[rust]' --data site=plain)
"${copier[@]}" --vcs-ref=HEAD "${r_args[@]}" . "$out/r"
# Rendered again over edited starter pages, which stay the project's.
echo '<!-- project edit -->' >>"$out/r/site/index.html"
echo '/* project edit */' >>"$out/r/site/style.css"
echo '// project edit' >>"$out/r/site/main.mjs"
"${copier[@]}" --vcs-ref=HEAD "${r_args[@]}" . "$out/r" >/dev/null 2>&1
"${copier[@]}" --vcs-ref=HEAD \
  --data project_name=lib-me --data 'stacks=[ts]' --data publish_to_npm=true --data site=astro . "$out/t"
# y: the Astro site in a project without the TypeScript stack. Rendered again over edited
# copies: the starter pages stay the project's, package.json is rewritten.
y_args=(--data project_name=site-me --data 'stacks=[python]' --data kind=app --data site=astro)
"${copier[@]}" --vcs-ref=HEAD "${y_args[@]}" . "$out/y"
for f in src/layouts/Base.astro src/pages/index.astro src/pages/about.md; do
  echo '<!-- project edit -->' >>"$out/y/site/$f"
done
echo '// project edit' >>"$out/y/site/astro.config.mjs"
echo 'project edit' >>"$out/y/site/package.json"
"${copier[@]}" --vcs-ref=HEAD "${y_args[@]}" . "$out/y" >/dev/null 2>&1
# hush-plain and hush-astro: a site in a private repo.
for s in plain astro; do
  "${copier[@]}" --vcs-ref=HEAD --data project_name=hush-me --data 'stacks=[python]' \
    --data public=false --data site=$s . "$out/hush-$s" >/dev/null
done
# k: adopting the template in an existing flat Python package under the GPL. The repo's
# own README, citation file and package stay; no src/ stub or sample test lands.
mkdir -p "$out/k/adopt_me"
echo '# project readme' >"$out/k/README.md"
echo '# project citation' >"$out/k/CITATION.cff"
echo 'VALUE = 1' >"$out/k/adopt_me/__init__.py"
"${copier[@]}" --vcs-ref=HEAD \
  --data project_name=adopt-me --data customise=true --data python_layout=flat \
  --data license=GPL-3.0-or-later --data codspeed=true --data 'test_extras=[mutation]' \
  --data publish_to_pypi=true --data cold_install=true . "$out/k"
grep -qx '# project readme' "$out/k/README.md"
grep -qx '# project citation' "$out/k/CITATION.cff"
grep -qx 'VALUE = 1' "$out/k/adopt_me/__init__.py"
test ! -e "$out/k/src"
# The benchmarks run for a pull request that touches the root package.
grep -qx '      - "adopt_me/\*\*"' "$out/k/.github/workflows/benchmarks.yml"
test ! -e "$out/k/tests/test_add.py"
(lacks -q 'import add' "$out/k/tests/test_benchmarks.py")
grep -qx 'module-root = ""' "$out/k/pyproject.toml"
grep -qx 'source = \["adopt_me"\]' "$out/k/pyproject.toml"
grep -q 'GNU GENERAL PUBLIC LICENSE' "$out/k/LICENSE"
grep -qx 'license = "GPL-3.0-or-later"' "$out/k/pyproject.toml"
grep -q '"license": "https://spdx.org/licenses/GPL-3.0-or-later"' "$out/k/codemeta.json"
# The REUSE.toml year is stored, so an update does not move it to the current year.
grep -qE "^copyright_year: .?[0-9]{4}" "$out/k/.copier-answers.yml"
grep -q 'Programming Language :: Python :: 3' "$out/k/pyproject.toml"
grep -qx 'keywords = \[\] # citesync compares this list to keywords in CITATION.cff' "$out/k/pyproject.toml"
grep -q 'Changelog = "https://github.com/[^/]*/adopt-me/blob/main/CHANGELOG.md"' "$out/k/pyproject.toml"
(lacks -q 'Private :: Do Not Upload' "$out/k/pyproject.toml")
# A warn-level ty rule must not fail the check, and the hooks must not rewrite data/.
grep -qx 'error-on-warning = false' "$out/k/pyproject.toml"
# Per hook, never top-level: the secret scan and the large-file check still cover them.
test "$(grep -cx ' *exclude: \^(data|tests/fixtures)/' "$out/k/.pre-commit-config.yaml")" = 4
(lacks -qx 'exclude: \^(data|tests/fixtures)/' "$out/k/.pre-commit-config.yaml")
grep -qx 'source_paths = \["adopt_me"\]' "$out/k/pyproject.toml"
grep -q 'check --search \. --format github adopt_me' "$out/k/.github/workflows/python.yml"
# yamlfmt rewrites a trailing `run: |` block to `|-`, so render it that way.
grep -qx '        run: |-' "$out/k/.github/workflows/copier-update.yml"
# A GITHUB_TOKEN PR starts no checks, so its body says how to start them.
grep -qF 'close it and reopen it to run them' "$out/k/.github/workflows/copier-update.yml"

# copier matches _skip_if_exists like .gitignore lines, so an entry without a leading /
# also skips the same name in any directory, such as data/README.md.
(! sed -n '/^_skip_if_exists:/,/^$/p' copier.yml | grep '^  - ' | grep -v '^  - "\{0,1\}/')

# e: released scaffolds render from a tag. A throwaway local tag on HEAD stands
# in for one. The trap uses -C because the checks below cd out of the repo. The
# -f on `git tag` covers a killed run that left the tag behind. Also the only
# AGPL-3.0-or-later render.
repo=$PWD
trap 'git -C "$repo" tag -d check-render-tag >/dev/null 2>&1 || true' EXIT
git tag -f check-render-tag >/dev/null
"${copier[@]}" --vcs-ref=check-render-tag \
  --data project_name=tag-me --data 'stacks=[python]' --data license=AGPL-3.0-or-later . "$out/e"

# compose: a deploy repo that only composes upstream images. `stacks=[docker]` without
# python builds no image: no Dockerfile, no image workflow, and `just check` validates
# the Compose file and shell scripts instead.
# Its author has a GitHub noreply address, which gets no mail.
"${copier[@]}" --vcs-ref=HEAD \
  --data project_name=compose-me --data 'stacks=[docker]' \
  --data author_email=1+ada@users.noreply.github.com . "$out/compose"
c=$out/compose
"${copier[@]}" --vcs-ref=HEAD --data project_name=compose-site --data 'stacks=[docker]' \
  --data site=plain . "$out/compose-site"
test -f "$out/compose-site/.github/scripts/preview-retire.sh"
# A fresh render passes its own git hooks.
git -C "$c" init -q
git -C "$c" add -A
(cd "$c" && uvx -q "prek${PREK_VERSION:+@$PREK_VERSION}" run --all-files >"$out/compose-hooks.log" 2>&1) ||
  {
    cat "$out/compose-hooks.log" >&2
    exit 1
  }
# CI has no .env: the check reads the example values.
grep -qF 'docker compose --env-file .env.example config -q' "$c/just/docker.just"
# README.md is the project's after the first render, so CONTRIBUTING links no anchor in it.
(lacks -q 'README.md#' "$c/.github/CONTRIBUTING.md")
# Compose files that `include:` pulls in from a subdirectory get updates too.
grep -qxF '    directories: [/, /*]' "$c/.github/dependabot.yml"
# The noreply address is never offered as a contact.
(lacks -q 'noreply' "$c/.github/SECURITY.md" "$c/.github/CODE_OF_CONDUCT.md")
grep -q 'Report abuse' "$c/.github/CODE_OF_CONDUCT.md"
# No other stack's text: ignore sections, recipe prefixes and imports, tool remarks,
# lockfile steps, SKIP entries, and docs the render does not have.
(lacks -qE '^# (Python|Node|Rust)$' "$c/.gitignore")
(lacks -qE 'py-|python\.just|ts\.just' "$c/justfile")
(lacks -qE 'uv (tool|run)|pnpm|Python projects' "$c/.pre-commit-config.yaml" "$c/.yamlfmt" "$c/.yamllint.yml")
(lacks -qE 'uv lock|pnpm|go-sync' "$c/.github/workflows/copier-update.yml")
(lacks -qE 'ruff|biome|cargo|golangci' "$c/.github/workflows/checks.yml")
grep -qx '          SKIP: betterleaks,zizmor' "$c/.github/workflows/checks.yml"
(lacks -q 'NumPy' "$c/_typos.toml")
(lacks -q 'Renovate' "$c/justfile")
(lacks -q 'release the project' "$c/AGENTS.md")
# Compose-only defaults to decision records: AGENTS.md points at a folder with a first record.
grep -qF 'docs/decisions/README.md' "$c/AGENTS.md"
grep -qF '0001-start-from-project-templates.md' "$c/docs/decisions/README.md"
grep -q 'Compose-only: no image of its own' "$c/docs/decisions/0001-start-from-project-templates.md"
(lacks -q 'the dependencies' "$c/.github/CONTRIBUTING.md")
(lacks -qE 'the version you|label: Version$' "$c/.github/SECURITY.md" "$c/.github/CONTRIBUTING.md" "$c/.github/ISSUE_TEMPLATE/bug.yml")
test -f "$out/compose/compose.yaml"
test -f "$out/compose/.env.example"
no_image "$out/compose"
# The Compose-only answers file records no image settings.
(lacks -q '^app_port:' "$c/.copier-answers.yml")
grep -qF 'actions/workflows/compose.yml/badge.svg' "$c/README.md"
# The wording that replaced other stacks' text.
grep -q 'release or commit' "$c/.github/SECURITY.md"
grep -q 'label: Release or commit' "$c/.github/ISSUE_TEMPLATE/bug.yml"
grep -q 'The README says how to install prek' "$c/.pre-commit-config.yaml"
grep -q 'image: .*@sha256:' "$out/compose/compose.yaml"
grep -q '127.0.0.1:' "$out/compose/compose.yaml"
grep -q 'healthcheck:' "$out/compose/compose.yaml"
grep -q '@just docker-check' "$out/compose/justfile"
(lacks -q 'hadolint' "$out/compose/.pre-commit-config.yaml")
grep -q "package-ecosystem: docker-compose" "$out/compose/.github/dependabot.yml"
grep -q '"context": "compose"' "$out/compose/.github/rulesets/main-checks.json"
# Files that must stay out of the shell lint: a docs page with a shebang in a code block,
# a zsh script and a fish script. just check runs where Docker is available.
mkdir -p "$out/compose/scripts"
# shellcheck disable=SC2016 # literal $1 in the sample scripts
printf '# Ops\n\n```sh\n#!/bin/bash\nfoo=$1\n```\n' >"$out/compose/docs/ops.md"
# shellcheck disable=SC2016 # literal $1
printf '#!/usr/bin/env zsh\nprint $1\n' >"$out/compose/scripts/z"
# shellcheck disable=SC2016 # literal $argv
printf '#!/usr/bin/env fish\necho $argv\n' >"$out/compose/scripts/f"
printf '#!/usr/bin/env bash\nset -euo pipefail\nif true; then\n  echo ok\nfi\n' >"$out/compose/scripts/ok"
printf '# shellcheck shell=bash\necho no shebang, still a .sh\n' >"$out/compose/scripts/plain.sh"
# CI has just and Docker, so there a missing one fails the run instead of skipping this.
if [ -n "${CI:-}" ] || { command -v just >/dev/null && docker info >/dev/null 2>&1; }; then
  # A required variable, set only in .env.example: the check passes without a .env.
  # shellcheck disable=SC2016 # literal ${...} for Compose
  awk '/^    restart: unless-stopped$/ { print "    environment:"; print "      EXAMPLE_VAR: ${EXAMPLE_VAR:?}" } { print }' \
    "$out/compose/compose.yaml" >"$out/compose.yaml.tmp"
  mv "$out/compose.yaml.tmp" "$out/compose/compose.yaml"
  # shellcheck disable=SC2016 # the same literal
  grep -qF 'EXAMPLE_VAR: ${EXAMPLE_VAR:?}' "$out/compose/compose.yaml"
  # A repo's own local-check runs at the end of just check.
  printf 'local-check:\n    echo local-check-ran\n' >"$out/compose/just/local.just"
  # A vendored script in another style is left alone by the lint and by fmt.
  printf '#!/bin/bash\nif true;then\necho a\nfi\n' >"$out/compose/scripts/vendored.sh"
  echo 'scripts/vendored.sh linguist-vendored' >"$out/compose/.gitattributes"
  git -C "$out/compose" add -A
  (cd "$out/compose" && just check) >"$out/compose-check.log"
  grep -qx 'local-check-ran' "$out/compose-check.log"
  grep -qx 'if true;then' "$out/compose/scripts/vendored.sh"
  # A badly formatted bash script must still fail it.
  printf '#!/bin/bash\nif true;then\necho a\nfi\n' >"$out/compose/scripts/bad"
  git -C "$out/compose" add -A
  ( ! (cd "$out/compose" && just check) >/dev/null 2>&1)
  # `just fmt` rewrites it to the 2-space style, and the check then passes.
  (cd "$out/compose" && just docker-fmt && just check)
  grep -qx 'if true;then' "$out/compose/scripts/vendored.sh"
  # With a site the render ships .github/scripts/preview-retire.sh, whose case arms are
  # not indented: docker-check must pass on the template's own scripts.
  git -C "$out/compose-site" init -q
  git -C "$out/compose-site" add -A
  (cd "$out/compose-site" && just docker-check)
fi
# docker-check passes -i 2 itself; .editorconfig gives editors the same indent for *.sh.
grep -zqF $'[*.sh]\nindent_size = 2\n' "$out/compose/.editorconfig"
# compose.yaml and .env.example are the project's after the first render.
echo '# project edit' >>"$out/compose/.env.example"
echo '# project edit' >>"$out/compose/compose.yaml"
"${copier[@]}" --vcs-ref=HEAD --data project_name=compose-me --data 'stacks=[docker]' \
  --data author_email=1+ada@users.noreply.github.com . "$out/compose" >/dev/null 2>&1
grep -q 'project edit' "$out/compose/.env.example"
grep -q 'project edit' "$out/compose/compose.yaml"

# compose2: Renovate reads the Compose file, and the cold-install job (a container with no
# Docker daemon) must not run the recipes that need one.
"${copier[@]}" --vcs-ref=HEAD --data project_name=compose-two --data 'stacks=[docker]' \
  --data dependency_bot=renovate --data cold_install=true --data public=false . "$out/compose2"
grep -qF "'docker-compose': { enabled: true }" "$out/compose2/renovate.json5"
grep -E "^ +grep -vE" "$out/compose2/.github/workflows/cold-install.yml" | grep -qE '\|check\|fmt\||check\|fmt'
# The same project with an image still runs `just check` there.
"${copier[@]}" --vcs-ref=HEAD --data project_name=compose-img --data 'stacks=[python,docker]' \
  --data cold_install=true . "$out/compose3"
(lacks -qE '\|check\|fmt' "$out/compose3/.github/workflows/cold-install.yml")
# A Compose-only repo with another stack runs that stack's own check and fmt there.
"${copier[@]}" --vcs-ref=HEAD --data project_name=compose-mix --data 'stacks=[python,docker]' \
  --data docker_image=false --data cold_install=true . "$out/compose-mix"
(lacks -qE '\|check\|fmt' "$out/compose-mix/.github/workflows/cold-install.yml")
mkdir -p "$out/mix"
printf 'uv sync\njust check       # all\njust fmt\n' >"$out/mix/readme.sh"
RUNNER_TEMP=$out/mix bash -c "$(grep -E '^ +sed -i -E' "$out/compose-mix/.github/workflows/cold-install.yml")"
[ "$(cat "$out/mix/readme.sh")" = "$(printf 'uv sync\njust py-check       # all\njust py-fmt')" ]

# docker without python, or docker_image=false, is a Compose-only repo too. With no
# image the flat layout is allowed.
"${copier[@]}" --vcs-ref=HEAD --data project_name=ts-compose --data 'stacks=[ts,docker]' \
  --data ts_kind=app . "$out/ts-compose"
no_image "$out/ts-compose"
"${copier[@]}" --vcs-ref=HEAD --data project_name=py-no-img --data 'stacks=[python,docker]' \
  --data docker_image=false --data python_layout=flat . "$out/py-no-img"
no_image "$out/py-no-img"
# The image side of each Compose-only conditional: a and c build images, d uses Renovate.
for r in a c; do
  (lacks -q 'docker-compose' "$out/$r/.github/dependabot.yml")
  test ! -e "$out/$r/.env.example"
  test ! -e "$out/$r/.github/workflows/compose.yml"
  grep -qF 'actions/workflows/docker.yml/badge.svg' "$out/$r/README.md"
done
[ "$(find "$out/c" -name 'Dockerfile*' -not -path '*/.git/*' | wc -l)" -eq 1 ]
grep -qF "'docker-compose': { enabled: false }" "$out/d/renovate.json5"
grep -q 'the dependencies' "$out/a/.github/CONTRIBUTING.md"

# Each preset renders on its own, with only the identity answers from the settings file.
for f in presets/*.yml; do
  p=$(basename "$f" .yml)
  "${copier[@]}" --vcs-ref=HEAD --data-file "$f" --data "project_name=preset-$p" . "$out/preset-$p"
done
test -f "$out/preset-rust-cli/src/main.rs"
test -d "$out/preset-uv-research/notebooks"
no_image "$out/preset-compose-deploy"
test -f "$out/preset-compose-deploy/docs/decisions/0001-start-from-project-templates.md"
test -f "$out/py-no-img/pyproject.toml"
grep -q '^  example:' "$out/py-no-img/compose.yaml"
(lacks -q '^  app:' "$out/py-no-img/compose.yaml")

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
refuses 'Give a plain relative path' --data 'stacks=[ts]' --data ts_dir=apps//web
refuses 'Go keyword' --data 'stacks=[go]' --data project_name=type
refuses 'Keep the description to one line' --data 'project_description=Says """hi"""'
refuses 'Keep the description to one line' --data 'project_description=Ends a comment */ early'
refuses 'Keep the description to one line' --data $'project_description=Two\nlines'
refuses 'Keep the description to one line' --data 'project_description=Has a \x escape'
refuses 'Rust keyword' --data 'stacks=[rust]' --data project_name=type
refuses 'Rust keyword' --data 'stacks=[rust]' --data project_name=gen
refuses 'Python keyword' --data 'stacks=[python]' --data project_name=lambda
# A digit-leading name makes no module name, and the question is hidden behind customise.
refuses 'to give one when the project name does not make one' --data 'stacks=[python]' --data project_name=1abc
# The name goes into the README and the web app's Markdown pages unescaped.
refuses 'the name is written into Markdown' --data 'stacks=[python]' --data 'project_name=my*app'
refuses 'the name is written into Markdown' --data 'stacks=[python]' --data 'project_name=my<app>'
refuses 'the name is written into Markdown' --data 'stacks=[python]' --data 'project_name=a _b_'
refuses 'the name is written into Markdown' --data 'stacks=[python]' --data 'project_name=my~app'
refuses 'at least one stack' --data 'stacks=[]'
# A package directory can't be where the site goes.
# shellcheck disable=SC2016 # the messages quote with backticks
{
  refuses 'python_dir is `site`, where the static site goes' --data 'stacks=[python]' --data python_dir=site --data site=plain
  refuses 'ts_dir is `_site`, where the static site goes' --data 'stacks=[ts]' --data ts_dir=_site --data site=plain
  refuses 'go_dir is `site/api`, where the static site goes' --data 'stacks=[go]' --data go_dir=site/api --data site=astro
  refuses 'python_dir is `_site/pkg`, where the static site goes' --data 'stacks=[python]' --data python_dir=_site/pkg --data site=plain
}
refuses 'The flat layout' --data 'stacks=[python]' --data kind=data-pipeline --data python_layout=flat
# A noreply address gets no mail, and these renders give it as a contact on a page.
refuses 'A GitHub noreply address' --data 'stacks=[ts]' --data ts_kind=web-app --data user_data=nothing \
  --data author_email=1+ada@users.noreply.github.com
refuses 'A GitHub noreply address' --data 'stacks=[go]' --data go_kind=binary \
  --data author_email=1+ada@users.noreply.github.com
refuses 'The flat layout' --data 'stacks=[python,docker]' \
  --data python_layout=flat
refuses 'edition 2024' --data 'stacks=[rust]' --data rust_version=1.84.0
# The legal pages are written from user_data, so it has no default to fall back on.
refuses 'Question "user_data" is required' --data 'stacks=[ts]' --data ts_kind=web-app
refuses "Invalid choice for 'user_data'" --data 'stacks=[ts]' --data ts_kind=web-app --data user_data=some
refuses 'starting with https://' --data 'stacks=[ts]' --data ts_kind=web-app \
  --data user_data=nothing --data site_url=http://example.org
# A Worker's custom domain is a whole host: no path, and the site on a Worker asks too.
refuses 'so no path' --data 'stacks=[ts]' --data ts_kind=web-app \
  --data user_data=nothing --data site_url=https://example.org/app
refuses 'so no path' --data 'stacks=[python]' --data site=plain --data site_host=cloudflare \
  --data site_url=https://Example.org
# An app that keeps personal data on a server needs its own contact address.
refuses 'needs its own contact address' --data 'stacks=[ts]' --data ts_kind=web-app \
  --data user_data=accounts --data author_email=Code@duinlab.nl
refuses 'Give a port' --data 'stacks=[python,docker]' --data app_port=0
refuses 'shipped as the python image' --data 'stacks=[python,docker]' --data kind=web-service \
  --data docker_image=false
# A binary never uses the Go package name, so a digit-leading project name is fine.
# Its gitignored build output drops the module path's /v2.
"${copier[@]}" --vcs-ref=HEAD --data project_name=1tool --data 'stacks=[go]' \
  --data go_kind=binary --data go_module=github.com/example-org/1tool/v2 \
  --data license=none --data openssf_badge=silver . "$out/i"
# A public repo without an open-source license is also outside the badge scope.
for f in GOVERNANCE.md docs/roadmap.md docs/assurance-case.md; do
  test ! -e "$out/i/$f"
done
(lacks -q '## Tests and code style' "$out/i/.github/CONTRIBUTING.md")
# j: a private web app, so its legal pages must not link a repo visitors can't open.
"${copier[@]}" --vcs-ref=HEAD --data project_name=private-web --data 'stacks=[ts]' \
  --data ts_kind=web-app --data user_data=browser --data public=false . "$out/j"
# s: a name ending in `.`, which the slug drops: `app-.example-org.workers.dev` is no hostname.
"${copier[@]}" --vcs-ref=HEAD --data project_name=app. --data 'stacks=[ts]' \
  --data ts_kind=web-app --data user_data=browser . "$out/s"
grep -qF '"name": "app",' "$out/s/wrangler.jsonc"
grep -qx 'site_url: https://app.example-org.workers.dev' "$out/s/.copier-answers.yml"
# wk: a web app at the root with the Worker script and a custom domain.
"${copier[@]}" --vcs-ref=HEAD --data project_name=edge-me --data 'stacks=[ts]' \
  --data ts_kind=web-app --data user_data=nothing --data worker=true \
  --data site_url=https://app.example.org . "$out/wk"
# cfp and cfa: the site on a Worker instead of Pages. cfp is the plain one with the Worker
# script and a custom domain; cfa the Astro one at its default workers.dev address.
"${copier[@]}" --vcs-ref=HEAD --data project_name=cf-me --data 'stacks=[python]' \
  --data site=plain --data site_host=cloudflare --data worker=true \
  --data site_url=https://demo.example.org . "$out/cfp"
"${copier[@]}" --vcs-ref=HEAD --data project_name=cfa-me --data 'stacks=[python]' \
  --data site=astro --data site_host=cloudflare . "$out/cfa"

# Every file in template/ must land in at least one render above. No tool measures
# coverage of Jinja templates, so this is the floor. Copier renders a probe copy of the
# template, each file holding only its line number in files.txt, with each render's
# stored answers. Copier decides every file name, so conditional names need no parsing.
probe=$out/coverage
mkdir -p "$probe/template"
cp -R copier.yml includes "$probe/"
(cd template && find . -type f | LC_ALL=C sort) >"$probe/files.txt"
n=0
while IFS= read -r f; do
  n=$((n + 1))
  mkdir -p "$probe/template/${f%/*}"
  echo "$n" >"$probe/template/$f"
done <"$probe/files.txt"
for answers in "$out"/*/.copier-answers.yml; do
  case_dir=${answers%/.copier-answers.yml}
  "${copier[@]}" --quiet --data-file "$answers" "$probe" "$probe/out/${case_dir##*/}" >/dev/null
done
missing=$(comm -23 <(seq "$n" | sort) <(find "$probe/out" -type f -exec cat {} + | sort -u))
if [ -n "$missing" ]; then
  echo "no render produces these template files; add a case or a --data that does:" >&2
  for i in $missing; do sed -n "${i}p" "$probe/files.txt" >&2; done
  exit 1
fi

OUT=$out uv run --no-project --with pyyaml --with json5 python - <<'PY'
import ast, collections, itertools, json, json5, os, pathlib, subprocess, tempfile, tomllib, yaml

load = {".json": json.loads, ".json5": json5.loads, ".toml": tomllib.loads,
        ".yml": yaml.safe_load, ".yaml": yaml.safe_load}
seen = 0
out = pathlib.Path(os.environ["OUT"])
for path in sorted(itertools.chain(out.glob("[abcdm]/**/*"), out.glob("compose/**/*"), out.glob("compose2/**/*"))):
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
# No schema covers codemeta.json, so check the CodeMeta context.
codemeta = json.loads((out / "a/codemeta.json").read_text())
assert codemeta["@context"] == "https://w3id.org/codemeta/3.0", codemeta
# A leading space in the author name must not leave the given name empty.
assert codemeta["author"][0]["givenName"] == "Ada", codemeta
assert "given-names: \"Ada\"" in (out / "a/CITATION.cff").read_text()
# The push job holds the write scopes and reads no cache on a tag. trivy-action restores
# its database from the Actions cache, so the scan stays in the build job.
docker = yaml.safe_load((out / "c/.github/workflows/docker.yml").read_text())["jobs"]
assert any("trivy-action" in s.get("uses", "") for s in docker["build"]["steps"]), docker["build"]
assert not any("trivy-action" in s.get("uses", "") for s in docker["push"]["steps"]), docker["push"]
# PyPI finishes before GitHub becomes immutable; the write job executes no project code.
python_release = yaml.safe_load((out / "c/.github/workflows/python-release.yml").read_text())["jobs"]
release = python_release["release"]
assert release["needs"] == "publish", release
assert release["permissions"] == {"contents": "write"}, release
assert not any("checkout" in s.get("uses", "") for s in release["steps"]), release
publish_script = release["steps"][-1]["run"]
for fail_create, expected in [(False, ["create", "edit"]), (True, ["create"])]:
    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(tmp)
        for directory in ("dist", "provenance", "notes", "bin"):
            (work / directory).mkdir()
        (work / "dist/package.whl").touch()
        (work / "provenance/bundle.json").write_text("{}")
        (work / "notes/notes.md").write_text("Release notes")
        gh = work / "bin/gh"
        gh.write_text('#!/bin/sh\nprintf "%s\\n" "$2" >>calls\n'
                      'test "$2" != create || test "$FAIL_CREATE" != true\n')
        gh.chmod(0o755)
        result = subprocess.run(["bash", "-c", publish_script], cwd=work,
                                env={"PATH": f"{work / 'bin'}:/usr/bin:/bin", "TAG": "v1.2.3",
                                     "FAIL_CREATE": str(fail_create).lower()}, check=False)
        assert (result.returncode != 0) == fail_create, result
        assert (work / "calls").read_text().splitlines() == expected
        assert (work / "provenance/mono-me-1.2.3.sigstore.json").is_file()
# A ruleset requires a check by its job name, so two jobs with one name can't be told
# apart. a, b, c and d each render more than one stack.
for render in [*"abcdm", "compose", "compose2"]:
    names = {}
    for wf in sorted((out / render / ".github/workflows").glob("*.yml")):
        for job_id, job in yaml.safe_load(wf.read_text())["jobs"].items():
            if "name" in job:
                names.setdefault(job["name"], []).append(f"{wf.name}:{job_id}")
    dupes = {n: where for n, where in names.items() if len(where) > 1}
    assert not dupes, f"{render}: jobs share a name: {dupes}"
# Every check a ruleset requires is one a rendered workflow reports. GitHub names a
# matrix job's runs "<name> (<value>, ...)" when the name holds no matrix expression.
required_by = collections.defaultdict(list)
for checks in sorted(out.glob("*/.github/rulesets/main*.json")):
    render = checks.parents[2]
    runs = set()
    for wf in (render / ".github/workflows").glob("*.yml"):
        for job in yaml.safe_load(wf.read_text())["jobs"].values():
            name = job.get("name")
            matrix = {k: v for k, v in job.get("strategy", {}).get("matrix", {}).items() if isinstance(v, list)}
            if not name:
                continue
            if matrix and "${{" not in name:
                for combo in itertools.product(*matrix.values()):
                    runs.add(f"{name} ({', '.join(map(str, combo))})")
            else:
                runs.add(name)
    for rule in json.loads(checks.read_text())["rules"]:
        for required in rule.get("parameters", {}).get("required_status_checks", []):
            assert required["context"] in runs, f"{checks}: {required['context']!r} is no job's check run"
            required_by[render].append(required["context"])
# Every render was checked, and each requires some check: an empty list passes the loop above.
renders = {answers.parent for answers in out.glob("*/.copier-answers.yml")}
assert len(renders) >= 18 and set(required_by) == renders, sorted(map(str, renders - set(required_by)))
# A pull request saves no cache: only it could read one, and it evicts main's. Each
# action that caches by default must carry its switch. CodSpeed's instrument cache has
# no save switch and is left on. A job whose `if` excludes pull requests outright (an
# `&&` chain with no `||`) is skipped, like docker.yml's push job.
off_pr = "${{ github.event_name != 'pull_request' }}"
saves = {
    "actions/cache": lambda w, cond: "github.event_name != 'pull_request'" not in cond,
    "actions/cache/save": lambda w, cond: "github.event_name != 'pull_request'" not in cond,
    "astral-sh/setup-uv": lambda w, cond: w.get("enable-cache") is not False and w.get("save-cache") != off_pr,
    "Swatinem/rust-cache": lambda w, cond: w.get("save-if") != off_pr,
    "actions/setup-node": lambda w, cond: bool(w.get("cache")),
    "actions/setup-go": lambda w, cond: w.get("cache") is not False,
    "golangci/golangci-lint-action": lambda w, cond: w.get("skip-save-cache") != "${{ github.event_name == 'pull_request' }}",
    "j178/prek-action": lambda w, cond: w.get("cache") is not False,
    "aquasecurity/trivy-action": lambda w, cond: w.get("cache") != off_pr,
    "docker/build-push-action": lambda w, cond: bool(w.get("cache-to")) and "github.event_name == 'push'" not in w["cache-to"],
}
checked = collections.Counter()
for render in [*"abcdm", "compose", "compose2"]:
    for wf in sorted((out / render / ".github/workflows").glob("*.yml")):
        doc = yaml.safe_load(wf.read_text())
        if "pull_request" not in doc[True]:
            continue
        for job_id, job in doc["jobs"].items():
            job_if = str(job.get("if", ""))
            if "github.event_name != 'pull_request'" in job_if and "||" not in job_if:
                continue
            for step in job.get("steps", []):
                uses = step.get("uses", "").split("@")[0]
                check = saves.get(uses)
                if check:
                    checked[uses] += 1
                if check and check(step.get("with") or {}, str(step.get("if", ""))):
                    raise AssertionError(f"{render}/{wf.name}:{job_id}: {step['uses']} saves a cache on pull requests")
# The steps the table matched, so a renamed action or a moved job can't empty the check.
assert checked["docker/build-push-action"] >= 1, checked
assert sum(checked.values()) >= 70, checked  # 75 when this was written
PY

# This repo lints its own YAML with the config a project with pnpm gets.
diff .yamlfmt "$out/t/.yamlfmt"
diff .yamllint.yml "$out/t/.yamllint.yml"
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
# Release steps are for the maintainer: the README has none, and the public CONTRIBUTING
# points to the template docs for them.
for r in a c m; do (lacks -q 'Releasing' "$r/README.md"); done
# shellcheck disable=SC2016 # literal backticks in the rendered text
grep -q '`just release X.Y.Z`' c/.github/CONTRIBUTING.md
# PyPI and npm render the README as the package page, so its links must not be relative.
# A link may start with http, # or {; anything else is a repo path that is dead there.
for f in c/README.md c/api/README.md k/README.md m/README.md t/README.md; do
  (lacks -E '\]\([^h#]' "$f")
done
grep -qF '](https://github.com/example-org/mono-me/blob/main/README.md)' c/api/README.md
grep -qF '](https://github.com/example-org/mono-me/tree/main/.github/workflows/)' c/README.md
# Without publishing, the README keeps its relative links.
grep -qF '](LICENSE)' d/README.md
test -x a/.github/scripts/release-notes.sh
test -x a/.github/scripts/tag-release.sh
grep -q 'scripts/tag-release.sh' a/justfile
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
# just release: the first run cuts the changelog, the second signs and pushes the tag.
# The key is made here and the remote is a local bare repo; the host's git config and
# keys are not read.
rel=$out/rel
mkdir "$rel"
ssh-keygen -q -t ed25519 -N '' -f "$rel/key"
# A citable project's recipe runs the citesync hook through `prek`; CI has only uvx.
# The shim stays on PATH for the rest of the run, at the version CI pins.
mkdir "$rel/bin"
printf '#!/bin/sh\nexec uvx -q prek%s "$@"\n' "${PREK_VERSION:+@$PREK_VERSION}" >"$rel/bin/prek"
chmod +x "$rel/bin/prek"
PATH=$rel/bin:$PATH
git init -q --bare -b main "$rel/origin.git"
cp -R k "$rel/w"
(
  # shellcheck disable=SC2030 # only this subshell reads it
  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
  # k keeps a placeholder CITATION.cff that citesync cannot read; c's case below runs it.
  export SKIP=citesync
  cd "$rel/w"
  git init -q -b main
  git remote add origin "$rel/origin.git"
  git config user.name 'Marie Curie'
  git config user.email curie@example.org
  git config gpg.format ssh
  git config user.signingkey "$rel/key.pub"
  git config gpg.ssh.allowedSignersFile "$rel/signers"
  echo "curie@example.org $(cat "$rel/key.pub")" >"$rel/signers"
  git add -A
  git commit -q -s -m 'chore: init'
  git push -q origin main
  # An empty [Unreleased] and a manifest at another version both refuse, changing nothing.
  (! just release 0.1.0 >release.log 2>&1)
  grep -qxF '[Unreleased] has no entries to release' release.log
  (! just release 0.2.0 >release.log 2>&1)
  grep -qxF 'pyproject.toml is not at 0.2.0' release.log
  rm release.log
  git diff --quiet
  sed -i 's/^## \[Unreleased\]$/&\n\n- first thing/' CHANGELOG.md
  git commit -q -s -am 'docs: add entry'
  just release 0.1.0 >/dev/null
  grep -qx '## \[0.1.0\] - [0-9-]*' CHANGELOG.md
  grep -qx '\[Unreleased\]: https://github.com/example-org/adopt-me/compare/v0.1.0...HEAD' CHANGELOG.md
  (! git rev-parse --verify -q v0.1.0 >/dev/null)
  git push -q origin main
  just release 0.1.0 >/dev/null
  test "$(git cat-file -t v0.1.0)" = tag
  git verify-tag v0.1.0 >/dev/null 2>&1
  test "$(git -C "$rel/origin.git" rev-parse 'v0.1.0^{commit}')" = "$(git rev-parse HEAD)"
  .github/scripts/release-notes.sh v0.1.0 CHANGELOG.md >/dev/null
  # The tag step refuses a bad version, a version with no changelog section, and a HEAD
  # that is not origin/main.
  (! .github/scripts/tag-release.sh 1.2 >release.log 2>&1)
  grep -qxF 'not a version: 1.2' release.log
  (! .github/scripts/tag-release.sh 9.9.9 >release.log 2>&1)
  grep -qxF 'CHANGELOG.md on origin/main has no 9.9.9 section' release.log
  # The manifest checks read the working tree, so an uncommitted edit refuses too.
  echo '# local edit' >>README.md
  (! .github/scripts/tag-release.sh 0.1.0 >release.log 2>&1)
  grep -qF 'uncommitted changes to tracked files' release.log
  git checkout -q README.md
  git commit -q -s --allow-empty -m 'chore: local only'
  (! just release 0.1.0 >release.log 2>&1)
  grep -q 'HEAD is not origin/main' release.log
)
# c lists three manifests in citesync.toml. Bumping the two the recipe reads, but not
# Cargo.toml, stops the release at citesync with CHANGELOG.md unchanged. No remote: the
# check runs before the fetch.
cp -R c "$rel/c"
(
  cd "$rel/c"
  git init -q -b main
  sed -i 's/^## \[Unreleased\]$/&\n\n- first thing/' CHANGELOG.md
  sed -i 's/^version = "0.1.0"$/version = "0.2.0"/' api/pyproject.toml
  sed -i 's/^  "version": "0.1.0",$/  "version": "0.2.0",/' apps/web/package.json
  git add -A
  git -c user.name=t -c user.email=t@t.test commit -qm base --no-verify
  (! just release 0.2.0 >../c-release.log 2>&1)
  grep -q "version-mismatch.*0.1.0" ../c-release.log
  git diff --quiet
)

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
test ! -e "$out/a/.github/workflows/cold-install.yml"
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
  test "$(python3 -I mutation_diff.py HEAD)" = "$(printf 'pkg.a.xǁCǁm__mutmut_*\npkg.a.xǁCǁs__mutmut_*')"
)
# go-mutation-diff reads the diff relative to go_dir, or gremlins finds no changed lines there.
grep -qF 'GIT_CONFIG_KEY_0=diff.relative' m/just/go.just
# property.yml: the same shape, running each stack's property or fuzz recipe.
test -f m/.github/workflows/property.yml
test ! -e a/.github/workflows/property.yml
uv run --no-project --with pyyaml python - <<'PY'
import yaml
wf = yaml.safe_load(open("m/.github/workflows/property.yml"))
assert set(wf["jobs"]) == {"python", "ts", "rust", "go"}, wf["jobs"].keys()
assert set(wf[True]) == {"schedule", "workflow_dispatch"}, wf[True]
assert wf["permissions"] == {"contents": "read"}, wf["permissions"]
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
  (lacks -q '^_src_path: gh:' a/.copier-answers.yml)
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
# One cooldown for every ecosystem and update type: a week.
test "$(grep -cx '    cooldown: {default-days: 7}' a/.github/dependabot.yml)" = "$(grep -c 'package-ecosystem:' a/.github/dependabot.yml)"
(lacks -q semver-major-days a/.github/dependabot.yml)
grep -qx "  minimumReleaseAge: '7 days'," d/renovate.json5
(lacks -q "30 days" d/renovate.json5)
# dependency_bot: Dependabot by default, Renovate in d, never both.
test ! -e a/renovate.json5
test -f d/renovate.json5
# Only Dependabot repos need the workflow that hears about template releases.
test -f a/.github/workflows/copier-update.yml
test ! -e d/.github/workflows/copier-update.yml
test ! -e d/.github/dependabot.yml
(lacks -q working-directory a/just/go.just)
# public=false defaults the license to none: no file and no license key.
test ! -e b/LICENSE
(lacks -q '"license"' b/package.json)
(lacks -q 'image.licenses' b/svc/Dockerfile)
(lacks -q '^license' b/svc/pyproject.toml)
# The awkward project name became a valid npm name.
grep -q '"name": "odd-name--co"' b/package.json
# Monorepo: packages nested, root files at the root, one Dockerfile.
test -f c/api/pyproject.toml
test -f c/apps/web/package.json
test -f c/api/Dockerfile
test -f c/compose.yaml
test -f c/.github/workflows/python.yml
test ! -e c/pyproject.toml
grep -q 'working-directory: api' c/.github/workflows/python.yml
grep -q 'context: api' c/compose.yaml
grep -q 'uv --directory api' c/just/python.just
# rust binary, nested: main.rs, no library-only lints, no doctest step.
test -f c/crates/cli/Cargo.toml
test -f c/crates/cli/deny.toml
test -f c/crates/cli/src/main.rs
test ! -e c/Cargo.toml
(lacks -q missing_docs c/crates/cli/Cargo.toml)
(lacks -q -- '--doc' c/just/rust.just)
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
(lacks -q linkedProjects a/.vscode/settings.json)
# Another stack's secrets stay out of an image's build context.
grep -qx '\*\*/.env' c/api/.dockerignore
# A local .env stays out of git, and compose publishes each port on loopback only.
grep -qxF '.env' c/.gitignore
test "$(grep -c '^      - "127.0.0.1:' c/compose.yaml)" = 1
(lacks -qE '^ +- "[0-9]+:' c/compose.yaml)
# Every release workflow publishes only a tag whose signature GitHub verified. e renders
# the last commit, without uncommitted edits.
n=0
for wf in */.github/workflows/{release,python-release,ts-release}.yml; do
  [ -e "$wf" ] && [ "${wf%%/*}" != e ] || continue
  grep -qF '.verification.verified' "$wf"
  n=$((n + 1))
done
test -f c/.github/workflows/python-release.yml && test -f c/.github/workflows/ts-release.yml && test "$n" -ge 10
# Both package workflows exist; Python creates the GitHub release after PyPI.
test ! -e c/.github/workflows/release.yml
test -f c/.github/workflows/ts-release.yml
grep -qx "    needs: publish" c/.github/workflows/python-release.yml
# The build refuses a tag that does not match the manifest version it publishes.
# shellcheck disable=SC2016 # literal workflow text
grep -qF 'test "$(uv version --short)" = "${GITHUB_REF_NAME#v}"' c/.github/workflows/python-release.yml
# shellcheck disable=SC2016 # literal workflow text
grep -qF '= "${GITHUB_REF_NAME#v}"' c/.github/workflows/ts-release.yml
grep -q -- '--draft --verify-tag' c/.github/workflows/python-release.yml
grep -q -- '--draft=false' c/.github/workflows/python-release.yml
# shellcheck disable=SC2016 # literal workflow expression
grep -qF '${{ steps.attest.outputs.bundle-path }}' c/.github/workflows/python-release.yml
# The API-break checks render with the publish answers, and only with them: griffe in CI from
# the repository root, so its search path carries the nested dir; the npm report beside
# the nested package.
grep -qx '      - run: uvx griffe@[0-9.]* check --search api/src --format github mono_me' c/.github/workflows/python.yml
# A CLI-only package (x, python_api=false) gets no api job, though it publishes.
grep -q 'name: "python: API breaks since the last tag"' c/.github/workflows/python.yml
test -f x/.github/workflows/python.yml
(lacks -q 'griffe' x/.github/workflows/python.yml)
test -f x/.github/workflows/python-release.yml
# Not in py-check: a deliberate break would keep local checks red until the next tag.
(lacks -q griffe c/just/python.just)
grep -qx '      - run: pnpm run api' c/.github/workflows/ts.yml
grep -qx '    pnpm -C apps/web run api' c/just/ts.just
test -f c/apps/web/api-extractor.json
test -f c/apps/web/mono-me.api.md
(lacks -q griffe a/.github/workflows/python.yml a/just/python.just)
(lacks -q 'run api' a/.github/workflows/ts.yml a/just/ts.just)
test ! -e a/api-extractor.json
test ! -e a/render-me.api.md
# publish_to_ghcr=true: docker.yml rendered its pushing half.
grep -q 'packages: write' c/.github/workflows/docker.yml
# docker.yml filters by path only when every build context is nested (c), not with a
# root context (a).
grep -qF 'paths: ["api/**", ".github/workflows/docker.yml"]' c/.github/workflows/docker.yml
(lacks -q 'paths:' a/.github/workflows/docker.yml)
# The push job also runs on main, so repo-settings must not limit `ghcr` to tags alone.
# shellcheck disable=SC2016 # literal $env in the recipe
grep -qF '"$env" = "ghcr"' c/justfile
grep -qF -- '-f name="main" -f type="branch"' c/justfile
# The publish job has no checkout; the wheels land in the root dist/.
grep -qx '          path: dist/' c/.github/workflows/python-release.yml
# A release made with GITHUB_TOKEN starts no workflow, so npm publishing
# must follow the tag push, not the release.
grep -qx '    tags: \["v\[0-9\]+.\[0-9\]+.\[0-9\]+"\]' c/.github/workflows/python-release.yml
grep -qx '    tags: \["v\[0-9\]+.\[0-9\]+.\[0-9\]+"\]' c/.github/workflows/ts-release.yml
(lacks -q 'types: \[published\]' c/.github/workflows/python-release.yml c/.github/workflows/ts-release.yml)
for w in python ts; do
  # shellcheck disable=SC2016 # the literal workflow text, not a shell expansion
  grep -q 'release-notes.sh" "$GITHUB_REF_NAME' "c/.github/workflows/$w-release.yml"
done
# Up-paths at both depths.
grep -qF '"root": "../.."' c/apps/web/biome.json
# data-pipeline: manifest and data dirs in the package, the rest at the root.
test -f d/pipe/sources.toml
test -f d/pipe/src/pipe_me/pipeline.py
test -f d/pipe/data/raw/.gitkeep
grep -qF '](pipe/sources.toml)' d/ATTRIBUTION.md
grep -qF '](pipe/sources.toml)' d/README.md
# The week-old-release escape hatch names each nested lockfile owner, and only those.
(lacks -q 'exclude-newer' d/README.md)
grep -qF 'uv and pnpm lock only' d/.github/CONTRIBUTING.md
grep -q 'in .pipe/pyproject\.toml. or .minimumReleaseAgeExclude. in .web/pnpm-workspace\.yaml.' d/.github/CONTRIBUTING.md
(lacks -q 'exclude-newer' h/.github/CONTRIBUTING.md)
grep -q 'Apache License' d/LICENSE
grep -qx 'BSD 3-Clause License' m/LICENSE
grep -q '^Copyright (c) [0-9]\{4\}, ' m/LICENSE
grep -q 'GNU AFFERO GENERAL PUBLIC LICENSE' e/LICENSE
grep -qx 'license = "AGPL-3.0-or-later"' e/pyproject.toml
# Each license text ends in exactly one newline (MIT in a, Apache-2.0 in d, BSD-3-Clause
# in m, AGPL-3.0-or-later in e), so the end-of-file-fixer hook has nothing to rewrite in
# a new project.
for lic in a/LICENSE d/LICENSE m/LICENSE e/LICENSE; do
  end=$(tail -c 2 "$lic" | od -An -tx1 | tr -d ' \n')
  [[ $end == ??0a && $end != 0a0a ]]
done
# REUSE: LICENSES/ holds the code license beside LICENSE, and data/ gets its own
# license in the research (a) and data-pipeline (d, nested) kinds only. e renders the
# last commit, without uncommitted edits, so it is not linted.
cmp a/LICENSE a/LICENSES/MIT.txt
grep -qx 'path = "data/\*\*"' a/REUSE.toml
test -f a/LICENSES/CC-BY-4.0.txt
grep -qx 'path = "pipe/data/\*\*"' d/REUSE.toml
grep -qx 'SPDX-License-Identifier = "CC0-1.0"' d/REUSE.toml
test -f d/LICENSES/CC0-1.0.txt
test -f k/LICENSES/GPL-3.0-or-later.txt
(lacks -q 'data/' k/REUSE.toml m/REUSE.toml)
# n: research data under the code license, so REUSE.toml and LICENSES/ have no data license.
"${copier[@]}" --vcs-ref=HEAD --data project_name=nodata-me --data 'stacks=[python]' \
  --data kind=research --data data_license=none "$repo" "$out/n" >/dev/null 2>&1
test -f n/data/README.md
(lacks -q 'data/' n/REUSE.toml)
test -z "$(find n/LICENSES -name 'CC-*' ! -name CC-BY-SA-4.0.txt)"
test ! -e b/REUSE.toml
# A public render's Code of Conduct is the Contributor Covenant, under CC-BY-SA-4.0.
grep -qx 'path = ".github/CODE_OF_CONDUCT.md"' a/REUSE.toml
test -f a/LICENSES/CC-BY-SA-4.0.txt
test ! -e b/LICENSES
(lacks -q reuse-tool b/.pre-commit-config.yaml)
for r in a d h k m; do grep -qx '      - id: reuse' "$r/.pre-commit-config.yaml"; done
reuse_version=$(sed -n '/fsfe\/reuse-tool/{n;s/.*frozen: v//p;}' "$repo/template/.pre-commit-config.yaml.jinja")
for r in a d k m n; do
  uvx "reuse@$reuse_version" --root "$r" lint --quiet
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
# `just ts-shots` screenshots the same routes; shots/ stays out of git.
test -f d/web/tests/shots/shots.spec.ts
grep -q '^ts-shots:' d/just/ts.just
grep -qF 'rm -rf web/shots' d/just/ts.just
grep -qF 'SHOTS=1 pnpm -C web exec playwright test --project shots' d/just/ts.just
grep -qF 'web/shots/' d/README.md
grep -qF 'ts-(e2e|shots)' d/.github/workflows/cold-install.yml
grep -qx '/web/shots/' d/.gitignore
(lacks -q '^ts-shots:' a/just/ts.just)
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
(lacks -rq 'github.com/example-org/private-web' j/docs)
grep -qF '[tests/e2e](https://github.com/example-org/pipe-me/tree/main/web/tests/e2e)' d/web/docs/accessibility.md
grep -qF "are in \`tests/e2e\`." j/docs/accessibility.md
# The WCAG 2.2 self-assessment sits beside the statement, which links it only once every row
# has a result: one row per level A and AA criterion, 55 in all, none of them assessed yet.
# Other kinds have none.
test "$(grep -cE '^\| [1-4]\.[0-9]+\.[0-9]+ .* \| AA? \| Not assessed \| \|$' d/web/docs/accessibility-assessment.md)" = 55
(lacks -q 'accessibility-assessment.md)' d/web/docs/accessibility.md)
test ! -e m/web/docs/accessibility-assessment.md
# The answers reach the terms: the site, who runs it and the contact, and the privacy
# statement links them.
grep -qxF 'These terms cover pipe-me at [pipe-me.example-org.workers.dev](https://pipe-me.example-org.workers.dev).' d/web/docs/terms.md
grep -qxF 'Ada Lovelace, who runs pipe-me.' d/web/docs/terms.md
grep -qF '[ada@example.com](mailto:ada@example.com)' d/web/docs/terms.md
grep -qxF 'Using pipe-me also means accepting its [terms of use](https://pipe-me.example-org.workers.dev/terms).' d/web/docs/privacy.md
# j keeps work in the browser, with no accounts: its privacy statement says so, and it has
# no terms page, route or footer link.
grep -qxF 'private-web keeps your work on your device. It isn'"'"'t sent to us or to anyone else.' j/docs/privacy.md
grep -qF "private-web saves your work in your browser's local storage" j/docs/privacy.md
grep -qx "private-web sets no cookies, so there's no cookie banner. Local storage holds only what you" j/docs/privacy.md
grep -qx 'private-web comes with no warranty.' j/docs/privacy.md
test ! -e j/docs/terms.md
(lacks -q '/terms' j/src/App.tsx j/tests/e2e/routes.ts j/tests/e2e/legal-pages.spec.ts j/docs/privacy.md)
# GitHub shows the pages as they are, so they pass the project's own Markdown lint.
rumdl_version=$(sed -n '/rumdl-pre-commit/{n;s/.*frozen: v//p;}' "$repo/.pre-commit-config.yaml")
uvx "rumdl@$rumdl_version" check --config d/.rumdl.toml d/web/docs d/AGENTS.md
test ! -e a/docs/privacy.md
# PRODUCT.md and DESIGN.md stubs: a web app gets both, beside its package.json,
# and they speak of the project's own users. Other kinds have neither.
for f in PRODUCT DESIGN; do
  test -f "d/web/$f.md"
  grep -qF 'pipe-me' "d/web/$f.md"
  (lacks -iE 'recruit|portfolio|hiring|showcase' "d/web/$f.md")
  test ! -e "t/$f.md"
  test ! -e "w/$f.md"
  test ! -e "a/$f.md"
done
grep -qx '## Users' d/web/PRODUCT.md
grep -qx '## Overview' d/web/DESIGN.md
# Like the other starter files, they are the project's once rendered.
echo '<!-- project edit -->' >>"$out/d/web/PRODUCT.md"
"${copier[@]}" --vcs-ref=HEAD "${d_args[@]}" "$repo" "$out/d" >/dev/null 2>&1
grep -q 'project edit' "$out/d/web/PRODUCT.md"
test ! -e d/web/src/index.ts
test ! -e d/web/tsconfig.build.json
test ! -e d/web/Dockerfile
grep -q 'stub for a data pipeline' d/pipe/Dockerfile
test ! -e a/index.html
grep -q '"react": \["./node_modules/preact/compat/"\]' d/web/tsconfig.json
grep -q 'react: "preact/compat"' d/web/vite.config.ts
(lacks -q '"react":' d/web/package.json)
grep -q 'script-src .self.;' d/web/public/_headers
(lacks -q "'unsafe-inline'" d/web/public/_headers)
grep -q '"budget": "node scripts/checkBundleBudget.mjs"' d/web/package.json
grep -q 'pnpm -C web run budget' d/just/ts.just
grep -qF 'image: mcr.microsoft.com/playwright:v' d/.github/workflows/ts.yml
grep -qF 'needs.check.outputs.playwright }}-noble' d/.github/workflows/ts.yml
grep -q 'fonts-dejavu-core' d/.github/workflows/ts.yml
grep -qx '          path: web/playwright-report/' d/.github/workflows/ts.yml
# Deploys: web-app renders get one Worker config for production and previews, the
# production and preview jobs and preview-retire.yml, with wrangler at the pinned version
# and nested paths for d. Production headers never carry noindex.
wrangler_pin=$(sed -n '/^wrangler_version:/,/^$/s/^  default: //p' "$repo/copier.yml")
test -n "$wrangler_pin"
grep -qF '"name": "pipe-me",' d/web/wrangler.jsonc
grep -qF '"directory": "./dist",' d/web/wrangler.jsonc
grep -qF '"not_found_handling": "single-page-application"' d/web/wrangler.jsonc
grep -qF '"preview_urls": false,' d/web/wrangler.jsonc
grep -qF '"workers_dev": true' d/web/wrangler.jsonc
(lacks -q 'pages_build_output_dir' d/web/wrangler.jsonc s/wrangler.jsonc)
test ! -e d/web/wrangler.preview.jsonc
# No web app names Pages' address anywhere.
(lacks -rq --exclude-dir=.git 'pages\.dev' d j s)
grep -q '^  preview:' d/.github/workflows/ts.yml
grep -q 'name: dist$' d/.github/workflows/ts.yml
(lacks -q 'preview-dist' d/.github/workflows/ts.yml)
test "$(grep -c 'path: web/dist$' d/.github/workflows/ts.yml)" = 3
# Production: push to main only, after the checks, in the production environment, one
# deploy at a time, under the config's own name.
prod=$(sed -n '/^  production:$/,/^  [a-z]/p' d/.github/workflows/ts.yml)
grep -qxF "    if: github.event_name == 'push' && github.ref == 'refs/heads/main'" <<<"$prod"
grep -qxF '    needs: [check, e2e]' <<<"$prod"
grep -qxF '      name: production' <<<"$prod"
grep -qxF '      group: production' <<<"$prod"
grep -qxF '      cancel-in-progress: false' <<<"$prod"
grep -qxF "        run: '\"\$GITHUB_WORKSPACE/.github/scripts/deploy-worker.sh\" Production'" <<<"$prod"
(! grep -q -- '--name\|X-Robots-Tag' <<<"$prod")
# A newer push to main must not cancel the run whose deploy is in flight.
grep -qF "cancel-in-progress: \${{ github.event_name == 'pull_request' }}" d/.github/workflows/ts.yml
grep -q '^ *name: preview$' d/.github/workflows/ts.yml
# The gate step runs before checkout, so it must not cd into web/.
grep -A2 -- '- id: gate$' d/.github/workflows/ts.yml | grep -q 'working-directory: \.$'
grep -qF "deploy-worker.sh\" Preview \"pipe-me-pr-\$PR\"" d/.github/workflows/ts.yml
# Both jobs deploy through the one script, which only a web app gets and which runs wrangler.
test "$(grep -cE 'deploy-worker\.sh" (Preview|Production)' d/.github/workflows/ts.yml)" = 2
# A nested app's ts.yml also runs when only the script changes, on push and on PRs.
test "$(grep -cF 'paths: ["web/**", ".github/workflows/ts.yml", ".github/scripts/deploy-worker.sh"]' d/.github/workflows/ts.yml)" = 2
(lacks -q 'wrangler deploy' d/.github/workflows/ts.yml)
# Every Cloudflare secrets gate checks both secrets: a missing account id fails each run.
n=0
for wf in */.github/workflows/{ts,site,preview-retire}.yml; do
  [ -e "$wf" ] || continue
  gates=$(grep -c 'missing=CLOUDFLARE_API_TOKEN$' "$wf" || true)
  [ "$gates" -gt 0 ] || continue
  # shellcheck disable=SC2016 # the literal workflow text
  test "$(grep -cF '[ -n "$ACCOUNT" ] || missing="${missing:+$missing and }CLOUDFLARE_ACCOUNT_ID"' "$wf")" = "$gates"
  n=$((n + gates))
done
test "$n" -ge 10
test -x d/.github/scripts/deploy-worker.sh
test ! -e m/.github/scripts/deploy-worker.sh
test -x s/.github/scripts/deploy-worker.sh
test ! -e a/.github/scripts/deploy-worker.sh
# deploy-worker.sh against a stub pnpm: the name goes to wrangler only when given, the
# address lands in the output and summary, and a deploy that prints none fails.
deploy_sh=$out/d/.github/scripts/deploy-worker.sh
dstub=$out/fake-deploy
mkdir -p "$dstub/work"
# wrangler 4's deploy output; with workers_dev off it prints no address lines.
cat >"$dstub/pnpm" <<'STUB'
#!/usr/bin/env bash
echo "pnpm $*" >>"$STUB/calls"
cat <<'OUT'

 ⛅️ wrangler 4.154.0
───────────────────
🌀 Building list of assets...
✨ Read 6 files from the assets directory /home/runner/work/pipe-me/pipe-me/web/dist
🌀 Starting asset upload...
✨ Success! Uploaded 2 files (4 already uploaded) (1.12 sec)

Total Upload: 0.34 KiB / gzip: 0.24 KiB
Uploaded pipe-me (3.41 sec)
OUT
[ -n "${NO_URL:-}" ] || printf '%s\n' 'Deployed pipe-me triggers (0.87 sec)' '  https://pipe-me.acct.workers.dev'
echo 'Current Version ID: 6f9a3c2e-1b4d-4e8f-9a7c-2d5e8b1f0c3a'
STUB
chmod +x "$dstub/pnpm"
deploy() {
  : >"$dstub/calls" && : >"$dstub/gho" && : >"$dstub/sum"
  (cd "$dstub/work" && env STUB="$dstub" PATH="$dstub:$PATH" GITHUB_OUTPUT="$dstub/gho" \
    GITHUB_STEP_SUMMARY="$dstub/sum" "$@" "$deploy_sh" Label ${DEPLOY_NAME:+"$DEPLOY_NAME"} >"$dstub/out" 2>&1)
}
deploy
grep -qx 'pnpm exec wrangler deploy' "$dstub/calls"
grep -qx 'url=https://pipe-me.acct.workers.dev' "$dstub/gho"
grep -qx '### Label: https://pipe-me.acct.workers.dev' "$dstub/sum"
DEPLOY_NAME=pipe-me-pr-4 deploy
grep -qx 'pnpm exec wrangler deploy --name pipe-me-pr-4' "$dstub/calls"
(! deploy NO_URL=1)
grep -qF 'wrangler printed no workers.dev address' "$dstub/out"
# wrangler is an exact devDependency of a web app only, which both deploy jobs install.
grep -qxF "    \"wrangler\": \"$wrangler_pin\"" d/web/package.json
(lacks -q 'pnpm dlx' d/.github/workflows/ts.yml)
test "$(grep -c 'run: pnpm install --frozen-lockfile' d/.github/workflows/ts.yml)" -ge 4
(lacks -q '"wrangler"' m/web/package.json)
# pnpm refuses the install unless wrangler's esbuild and workerd builds are allowed.
grep -A2 -x 'allowBuilds:' d/web/pnpm-workspace.yaml | grep -qx '  workerd: true'
(lacks -q 'allowBuilds' m/web/pnpm-workspace.yaml)
# knip does not read deploy-worker.sh, the only caller of wrangler, so every web app ignores it.
jq -e '.knip.ignoreDependencies | index("wrangler")' d/web/package.json >/dev/null
jq -e '.knip.ignoreDependencies | index("wrangler")' s/package.json >/dev/null
(lacks -q 'versions upload' d/.github/workflows/ts.yml)
grep -qF 'X-Robots-Tag: noindex' d/.github/workflows/ts.yml
(lacks -q '^  X-Robots-Tag' d/web/public/_headers)
# A preview lives only while its pull request is open and ready: drafts get none, the deploy
# re-reads the state, the retire runs on close and on a draft switch, and both share one
# concurrency group so a retire waits for a deploy in flight.
grep -qF "if: github.event_name == 'pull_request' && !github.event.pull_request.draft && !endsWith(github.event.pull_request.user.login, '[bot]')" d/.github/workflows/ts.yml
# shellcheck disable=SC2016
grep -qF 'gh api "repos/$REPO/pulls/$PR" --jq '\''.state + " " + (.draft|tostring)'\''' d/.github/workflows/ts.yml
# shellcheck disable=SC2016
grep -qF '[ "$state" != "open false" ]' d/.github/workflows/ts.yml
grep -q 'pull-requests: read' d/.github/workflows/ts.yml
# shellcheck disable=SC2016
grep -qF 'group: preview-${{ github.event.pull_request.number }}' d/.github/workflows/ts.yml
# shellcheck disable=SC2016
grep -qF 'group: ${{ matrix.group }}-${{ github.event.pull_request.number || github.run_id }}' d/.github/workflows/preview-retire.yml
grep -qF 'types: [closed, converted_to_draft]' d/.github/workflows/preview-retire.yml
grep -qF 'cron: "17 4 * * *"' d/.github/workflows/preview-retire.yml
grep -q 'pull-requests: read' d/.github/workflows/preview-retire.yml
grep -q 'environment: preview$' d/.github/workflows/preview-retire.yml
grep -qxF '        run: .github/scripts/preview-retire.sh' d/.github/workflows/preview-retire.yml
(lacks -q 'pnpm\|working-directory' d/.github/workflows/preview-retire.yml)
test -x d/.github/scripts/preview-retire.sh
# preview-retire.sh against a stub curl and gh. The account holds pipe-me-pr-1 to -3,
# pipe-me-site-pr-1 and pipe-me-preview; each test sets the PR states, the DELETE answer and the address answer.
retire_sh=$out/d/.github/scripts/preview-retire.sh
stub=$out/fake-retire
mkdir -p "$stub"
cat >"$stub/curl" <<'STUB'
#!/usr/bin/env bash
method=GET out=/dev/null prev=''
for a; do
  case $prev in -X) method=$a ;; -o) out=$a ;; esac
  prev=$a
done
url=$a
case $method:$url in
  DELETE:*) echo "${url##*/}" >>"$STUB/deleted"; echo '{}' >"$out"; printf %s "${DELETE_CODE:-200}" ;;
  *workers/scripts) echo '{"result":[{"id":"pipe-me-pr-1"},{"id":"pipe-me-pr-2"},{"id":"pipe-me-pr-3"},{"id":"pipe-me-site-pr-1"},{"id":"pipe-me-preview"}]}' ;;
  *workers/subdomain) [ -z "${SUB_FAIL:-}" ] || exit 22; echo '{"result":{"subdomain":"acct"}}' ;;
  *.workers.dev) printf %s "${PROBE_CODE:-404}"; [ "${PROBE_CODE:-404}" != 000 ] || exit 28 ;;
esac
STUB
# gh answers from $STUB/pr-<n>, and fails when there is no such file.
cat >"$stub/gh" <<'STUB'
#!/usr/bin/env bash
f=$STUB/pr-${2##*/}
[ -f "$f" ] && jq -r "$4" "$f"
STUB
chmod +x "$stub/curl" "$stub/gh"
retire() {
  : >"$stub/deleted"
  env SLUG=pipe-me REPO=o/r CLOUDFLARE_API_TOKEN=t CLOUDFLARE_ACCOUNT_ID=a PROBE_WAITS='0 0' \
    STUB="$stub" PATH="$stub:$PATH" "$@" "$retire_sh" pipe-me-preview >"$stub/out" 2>&1
}
echo '{"state": "open", "draft": true}' >"$stub/pr-1"
echo '{"state": "open", "draft": false}' >"$stub/pr-2"
# The sweep deletes the draft's Worker and keeps the ready one's. It cannot read PR 3, so it
# keeps that Worker too and fails.
(! retire)
test "$(LC_ALL=C sort "$stub/deleted")" = "$(printf 'pipe-me-pr-1?force=true\npipe-me-preview?force=true')"
grep -q 'Could not read PR 3' "$stub/out"
# The site's prefix takes only its own Worker.
retire SLUG=pipe-me-site
grep -qx 'pipe-me-site-pr-1?force=true' "$stub/deleted"
(lacks -q '^pipe-me-pr-' "$stub/deleted")
# Once PR 3 reads as closed, the sweep deletes it and passes.
echo '{"state": "closed", "draft": false}' >"$stub/pr-3"
retire
test "$(grep -c 'pr-3' "$stub/deleted")" = 1
(lacks -q 'pr-2' "$stub/deleted")
# A Worker that does not exist answers 404, which is not an error.
retire PRS=7 DELETE_CODE=404
grep -qx 'pipe-me-pr-7?force=true' "$stub/deleted"
# Without the subdomain, every delete still runs, unverified, and the run fails.
(! retire PRS='1 2' SUB_FAIL=1)
test "$(wc -l <"$stub/deleted")" = 2
grep -q 'no takedown below is verified' "$stub/out"
# Only a 404 counts as gone: a timeout or a 502 on every try fails, naming the code.
(! retire PRS=1 PROBE_CODE=000)
grep -qF 'answers HTTP 000 after the delete' "$stub/out"
(! retire PRS=1 PROBE_CODE=502)
grep -qF 'answers HTTP 502 after the delete' "$stub/out"
# Static site: x (Python), r (Rust) and d (beside a web app) answer site=plain. One build,
# which only the deploy job may publish to Pages, and a preview Worker per open, ready PR,
# deployed from that build through the web app's own script.
pnpm_pin=$(sed -n '/^pnpm_version:/,/^$/s/^  default: //p' "$repo/copier.yml")
grep -qF "\"packageManager\": \"pnpm@$pnpm_pin\"" d/web/package.json
for r in x r d; do
  for f in site/index.html site/style.css site/main.mjs wrangler.site.jsonc .github/workflows/site.yml .github/workflows/preview-retire.yml; do
    test -f "$r/$f"
  done
  test -x "$r/.github/scripts/deploy-worker.sh"
  test -x "$r/.github/scripts/preview-retire.sh"
  grep -qF '<script type="module" src="main.mjs"></script>' "$r/site/index.html"
  grep -qx '/_site/' "$r/.gitignore"
  grep -qx 'site:' "$r/justfile"
  grep -qF '"directory": "./_site"' "$r/wrangler.site.jsonc"
  grep -qF '"preview_urls": false,' "$r/wrangler.site.jsonc"
  grep -qF '"workers_dev": true' "$r/wrangler.site.jsonc"
  wf=$r/.github/workflows/site.yml
  # Least privilege: contents: read for the workflow, Pages rights on the deploy job alone.
  sed -n '1,/^jobs:/p' "$wf" | grep -qx '  contents: read'
  test "$(grep -c 'pages: write' "$wf")" = 1
  test "$(grep -c 'id-token: write' "$wf")" = 1
  deploy_job=$(sed -n '/^  deploy:$/,/^  [a-z]/p' "$wf")
  grep -q '^      pages: write' <<<"$deploy_job"
  grep -q '^      id-token: write' <<<"$deploy_job"
  grep -qx '      name: github-pages' <<<"$deploy_job"
  grep -qxF "    if: github.event_name != 'pull_request' && github.ref == 'refs/heads/main'" <<<"$deploy_job"
  test "$(grep -c '^    timeout-minutes:' "$wf")" = 3
  test "$(grep -c 'uses: actions/checkout@' "$wf")" = "$(grep -c 'persist-credentials: false' "$wf")"
  grep -qx '      - run: just site' "$wf"
  grep -qx '          path: _site' "$wf"
  # The preview deploys the build job's artifact: it never runs the build with the token.
  preview_job=$(sed -n '/^  preview:$/,$p' "$wf")
  (! grep -q 'just site' <<<"$preview_job")
  grep -qx '          name: github-pages' <<<"$preview_job"
  grep -qF "if: github.event_name == 'pull_request' && !github.event.pull_request.draft && !endsWith(github.event.pull_request.user.login, '[bot]')" <<<"$preview_job"
  # shellcheck disable=SC2016
  grep -qF 'gh api "repos/$REPO/pulls/$PR" --jq '\''.state + " " + (.draft|tostring)'\''' <<<"$preview_job"
  # shellcheck disable=SC2016
  grep -qF '[ "$state" != "open false" ]' <<<"$preview_job"
  # shellcheck disable=SC2016
  grep -qF 'group: preview-site-${{ github.event.pull_request.number }}' <<<"$preview_job"
  grep -qF 'X-Robots-Tag: noindex' <<<"$preview_job"
  grep -qF "dlx wrangler@$wrangler_pin" <<<"$preview_job"
done
# The site build is a required check, and `just check` builds an Astro site.
jq -e '.rules[0].parameters.required_status_checks | any(.context == "site: build")' x/.github/rulesets/main-checks.json >/dev/null
jq -e '.rules[0].parameters.required_status_checks | any(.context == "site: build")' y/.github/rulesets/main-checks.json >/dev/null
(lacks -q '"site: build"' c/.github/rulesets/main-checks.json)
sed -n '/^check:/,/^$/p' y/justfile | grep -qx '    @just site'
(sed -n '/^check:/,/^$/p' x/justfile | lacks -q 'just site')
# A private repo's page has no links into the repo, which its readers cannot open.
(lacks -rq 'github.com/' hush-plain/site hush-astro/site/src)
grep -q 'href="https://github.com/.*/issues"' x/site/index.html
grep -q 'Skip to the content' hush-astro/site/src/layouts/Base.astro
# Site previews are <slug>-site-pr-<n>, apart from a web app's <slug>-pr-<n>.
# shellcheck disable=SC2016
grep -qF 'deploy-worker.sh" Preview "cli-me-site-pr-$PR" --config wrangler.site.jsonc' x/.github/workflows/site.yml
# shellcheck disable=SC2016
grep -qF 'deploy-worker.sh" Preview "pipe-me-site-pr-$PR" --config wrangler.site.jsonc' d/.github/workflows/site.yml
# One retire job per prefix, each in the group of the preview job it retires, so a site
# preview and a web-app preview of one PR never share a group.
grep -qx '          - { slug: cli-me-site, group: preview-site }' x/.github/workflows/preview-retire.yml
test "$(grep -c '^          - { slug: ' x/.github/workflows/preview-retire.yml)" = 1
grep -qx '          - { slug: pipe-me, group: preview }' d/.github/workflows/preview-retire.yml
grep -qx '          - { slug: pipe-me-site, group: preview-site }' d/.github/workflows/preview-retire.yml
grep -qx '          - { slug: app, group: preview }' s/.github/workflows/preview-retire.yml
test "$(grep -c '^          - { slug: ' s/.github/workflows/preview-retire.yml)" = 1
# Without a package.json, the preview job's pnpm comes from the pin; with one, from it.
grep -qxF "          version: \"$pnpm_pin\"" x/.github/workflows/site.yml
grep -qx '          package_json_file: web/package.json' d/.github/workflows/site.yml
# The starter page builds as it is.
(cd x && just site >/dev/null)
test -f x/_site/index.html
test -f x/_site/main.mjs
# deploy-worker.sh with the site's wrangler command and config.
(cd "$dstub/work" && env STUB="$dstub" PATH="$dstub:$PATH" GITHUB_OUTPUT="$dstub/gho" GITHUB_STEP_SUMMARY="$dstub/sum" \
  WRANGLER="pnpm dlx wrangler@$wrangler_pin" "$deploy_sh" Preview cli-me-site-pr-4 --config wrangler.site.jsonc >"$dstub/out" 2>&1)
test "$(tail -n 1 "$dstub/calls")" = "pnpm dlx wrangler@$wrangler_pin deploy --name cli-me-site-pr-4 --config wrangler.site.jsonc"
# A nested package's knip never sees the page's files.
jq -e '.knip | has("ignoreFiles") | not' d/web/package.json >/dev/null
# The preview serves the build under /<repo>/, as Pages does.
grep -qF "printf '/ /cli-me/ 302\n' > _site/_redirects" x/.github/workflows/site.yml
test ! -e x/site/package.json
# A project without the site gets none of it.
for r in a m w; do
  test ! -e "$r/site"
  test ! -e "$r/wrangler.site.jsonc"
  test ! -e "$r/.github/workflows/site.yml"
  test ! -e "$r/.github/workflows/preview-retire.yml"
  test ! -e "$r/.github/scripts/preview-retire.sh"
  test ! -e "$r/.github/scripts/deploy-worker.sh"
  (lacks -q '_site' "$r/.gitignore")
  (lacks -qx 'site:' "$r/justfile")
  (lacks -qF 'repos/{owner}/{repo}/pages' "$r/justfile")
done
(lacks -q 'app-site' s/.github/workflows/preview-retire.yml)
# Astro site: y has no TypeScript stack, so the site's node and pnpm come from site.yml and
# site/package.json alone. t has it beside a TypeScript package at the root.
astro_pin=$(sed -n '/^astro_version:/,/^$/s/^  default: //p' "$repo/copier.yml")
test -n "$astro_pin"
for r in y t; do
  for f in astro.config.mjs package.json pnpm-workspace.yaml src/layouts/Base.astro src/pages/index.astro src/pages/about.md; do
    test -f "$r/site/$f"
  done
  test ! -e "$r/site/index.html"
  jq -e --arg v "$astro_pin" '.dependencies.astro == $v' "$r/site/package.json" >/dev/null
  jq -e --arg v "pnpm@$pnpm_pin" '.packageManager == $v' "$r/site/package.json" >/dev/null
  grep -qx 'minimumReleaseAge: 10080' "$r/site/pnpm-workspace.yaml"
  grep -qx '/site/dist/' "$r/.gitignore"
  grep -qx '/site/.astro/' "$r/.gitignore"
  grep -qF '"directory": "./site/dist"' "$r/wrangler.site.jsonc"
  grep -qx '    pnpm -C site install --frozen-lockfile' "$r/justfile"
  grep -qx 'site-sync:' "$r/justfile"
  wf=$r/.github/workflows/site.yml
  grep -qx '          path: site/dist' "$wf"
  # The build job sets up node and pnpm from the site's own package.json.
  sed -n '/^  build:$/,/^  deploy:$/p' "$wf" | grep -qx '          package_json_file: site/package.json'
  sed -n '/^  build:$/,/^  deploy:$/p' "$wf" | grep -q 'uses: actions/setup-node@'
  # Pages serves the site under /<repo>/, and so does its preview.
  grep -qx "  base: \"/$([ "$r" = y ] && echo site-me || echo lib-me)\"," "$r/site/astro.config.mjs"
  # The lockfile it writes is skipped by the YAML hooks at any depth.
  grep -qxF '  - "**/pnpm-lock.yaml"' "$r/.yamlfmt"
  test "$(grep -cxF '        exclude: (^|/)pnpm-lock\.yaml$' "$r/.pre-commit-config.yaml")" -ge 2
done
grep -qx '          version: "'"$pnpm_pin"'"' y/.github/workflows/site.yml
# shellcheck disable=SC2016
grep -qF 'tar -xf "$RUNNER_TEMP/pages/artifact.tar" -C site/dist/site-me' y/.github/workflows/site.yml
grep -qF "printf '/ /site-me/ 302\n' > site/dist/_redirects" y/.github/workflows/site.yml
# The site's package.json gets its own Dependabot entry; Renovate finds every package.json.
grep -A1 -x '  - package-ecosystem: npm' y/.github/dependabot.yml | grep -qx '    directory: /site'
(lacks -q 'directory: /site' x/.github/dependabot.yml)
(lacks -q 'ignorePaths\|enabledManagers' d/renovate.json5)
# A root package's tools leave the site alone: knip reports none of it, biome skips the
# .astro files it can only half read.
jq -e '.knip.ignoreFiles == ["site/**"]' t/package.json >/dev/null
jq -e '.files.includes | index("!site/**/*.astro")' t/biome.json >/dev/null
(lacks -q 'astro' x/.github/workflows/site.yml)
# The starter pages are the project's; package.json stays the template's.
for f in r/site/index.html r/site/style.css r/site/main.mjs y/site/astro.config.mjs \
  y/site/src/layouts/Base.astro y/site/src/pages/index.astro y/site/src/pages/about.md; do
  grep -q 'project edit' "$f"
done
(lacks -q 'project edit' y/site/package.json)
# It builds: every page, Markdown included, inside the layout.
astro_start=$SECONDS
(cd y && just site-sync >/dev/null 2>&1 && just site >/dev/null 2>&1)
echo "check-render: the Astro build took $((SECONDS - astro_start)) s" >&2
test -f y/site/dist/index.html
test -f y/site/dist/about/index.html
grep -qF '<h1>About</h1>' y/site/dist/about/index.html
grep -qF 'href="/site-me/about/"' y/site/dist/index.html
test -f y/site/pnpm-lock.yaml
# The deploy job's gate: it deploys only when Pages deploys from Actions, skips with a
# notice while Pages is off (404), and fails on any other error. Run against a stub gh.
gate_sh=$out/fake-pages-gate
mkdir -p "$gate_sh"
sed -n '/^  deploy:$/,/^  [a-z]/p' x/.github/workflows/site.yml |
  sed -n '/^          if build=/,/^          echo "run=false"/s/^          //p' >"$gate_sh/gate.sh"
test -s "$gate_sh/gate.sh"
cat >"$gate_sh/gh" <<'STUB'
#!/usr/bin/env bash
[ "$*" = 'api repos/o/r/pages --jq .build_type' ] || { echo "gh: unexpected call: $*" >&2; exit 2; }
case $PAGES in
  workflow | legacy) echo "$PAGES" ;;
  404) echo 'gh: Not Found (HTTP 404)' >&2 && exit 1 ;;
  *) echo 'gh: Server Error (HTTP 500)' >&2 && exit 1 ;;
esac
STUB
chmod +x "$gate_sh/gh"
pages_gate() {
  : >"$gate_sh/gho"
  (cd "$gate_sh" && env PAGES="$1" REPO=o/r PATH="$gate_sh:$PATH" GITHUB_OUTPUT="$gate_sh/gho" bash -e gate.sh >"$gate_sh/out" 2>&1)
}
pages_gate workflow
grep -qx 'run=true' "$gate_sh/gho"
pages_gate 404
grep -qx 'run=false' "$gate_sh/gho"
grep -qF '::notice::GitHub Pages is off' "$gate_sh/out"
pages_gate legacy
grep -qx 'run=false' "$gate_sh/gho"
# Any other error fails the job with gh's message, and sets no output.
(! pages_gate 500)
grep -qF 'HTTP 500' "$gate_sh/out"
test ! -s "$gate_sh/gho"
grep -qxF "      - if: steps.gate.outputs.run == 'true'" <<<"$(sed -n '/^  deploy:$/,/^  [a-z]/p' x/.github/workflows/site.yml)"
# dlx resolves wrangler without a lockfile, so it waits the same week as an install.
grep -qxF "          WRANGLER: pnpm --config.minimum-release-age=10080 dlx wrangler@$wrangler_pin" x/.github/workflows/site.yml
# The site's README section, with its own previews heading unless the web app's is there.
for r in x y d; do grep -qx '## Site' "$r/README.md"; done
grep -qx '### Pull request previews' x/README.md
test "$(grep -cx '### Pull request previews' d/README.md)" = 1
grep -qF 'cli-me-site-pr-<number>' x/README.md
grep -qF 'just site-sync' y/README.md
grep -q 'You need .*\[pnpm\]' y/README.md
(lacks -q '\[pnpm\]' x/README.md)
(lacks -qx '## Site' a/README.md)
# The copier-update PR names the Astro lockfile refresh too.
# shellcheck disable=SC2016
grep -qF '\`just site-sync\`' y/.github/workflows/copier-update.yml
(lacks -q 'site-sync' x/.github/workflows/copier-update.yml)
grep -q '^  # shortcut: the sweep matches Workers by name alone' x/.github/scripts/preview-retire.sh
# A web app at the repo root builds in place.
test -f s/wrangler.jsonc
grep -q '^  production:' s/.github/workflows/ts.yml
sed -n '/^  production:$/,/^  [a-z]/p' s/.github/workflows/ts.yml | grep -xF '    needs: [check, e2e]' >/dev/null
test -f s/.github/workflows/preview-retire.yml
grep -qx '          path: dist' s/.github/workflows/ts.yml
(lacks -q 'working-directory' s/.github/workflows/preview-retire.yml)
# Hosting and the Worker script. d, s, x and y keep the defaults: no script, no custom
# domain, the site on Pages. wk is a web app with both; cfp a plain site on a Worker with
# both; cfa an Astro site on a Worker at its workers.dev address.
for f in wk/wrangler.jsonc cfp/wrangler.site.jsonc; do
  grep -qF '"binding": "ASSETS",' "$f"
  grep -qF '"run_worker_first": ["/api/*"]' "$f"
done
grep -qF '"main": "./worker/index.ts",' wk/wrangler.jsonc
grep -qF '"main": "./site/worker/index.mjs",' cfp/wrangler.site.jsonc
for f in d/web/wrangler.jsonc s/wrangler.jsonc x/wrangler.site.jsonc cfa/wrangler.site.jsonc; do
  (lacks -qE '"main"|"binding"|run_worker_first' "$f")
done
for f in index.ts index.test.ts tsconfig.json; do test -f "wk/worker/$f"; done
test ! -e s/worker
test ! -e d/web/worker
grep -qF '"typecheck": "tsc && tsc -p worker"' wk/package.json
jq -e '.devDependencies["@cloudflare/workers-types"]' wk/package.json >/dev/null
grep -qF '"typecheck": "tsc"' s/package.json
(lacks -q 'workers-types' s/package.json d/web/package.json)
# The site's script: `just site` runs its tests with node, which the build job sets up,
# and leaves it out of the files it builds.
test -f cfp/site/worker/index.mjs
test -f cfp/site/worker/index.test.mjs
test ! -e x/site/worker
test ! -e cfa/site/worker
grep -qx '    node --test site/worker/index.test.mjs' cfp/justfile
(lacks -q 'node --test' x/justfile cfa/justfile)
(cd cfp && just site >/dev/null 2>&1)
test -f cfp/_site/index.html
test ! -e cfp/_site/worker
sed -n '/^  build:$/,/^  deploy:$/p' cfp/.github/workflows/site.yml | grep -q 'uses: actions/setup-node@'
(sed -n '/^  build:$/,/^  deploy:$/p' x/.github/workflows/site.yml | lacks -q 'uses: actions/setup-node@')
# A custom domain goes to production alone, as --domain: previews deploy the same config.
grep -qxF "        run: '\"\$GITHUB_WORKSPACE/.github/scripts/deploy-worker.sh\" Production \"\" --domain app.example.org'" wk/.github/workflows/ts.yml
(lacks -q 'Preview.*--domain' wk/.github/workflows/ts.yml cfp/.github/workflows/site.yml)
(lacks -q -- '--domain' d/.github/workflows/ts.yml s/.github/workflows/ts.yml cfa/.github/workflows/site.yml x/.github/workflows/site.yml)
# shellcheck disable=SC2016 # the backticks are Markdown
grep -qF 'Zone > Workers Routes: Edit for the zone of `app.example.org`' wk/README.md
# shellcheck disable=SC2016 # the backticks are Markdown
grep -qF 'Zone > Workers Routes: Edit for the zone of `demo.example.org`' cfp/README.md
(lacks -q 'Workers Routes' d/README.md s/README.md cfa/README.md x/README.md)
# The site on a Worker: production deploys the build job's artifact with the site's
# config, in the production environment, and neither job touches Pages or serves under /<repo>/.
for r in cfp cfa; do
  wf=$r/.github/workflows/site.yml
  deploy_job=$(sed -n '/^  deploy:$/,/^  [a-z]/p' "$wf")
  grep -qx '      name: production' <<<"$deploy_job"
  grep -qx '      group: site-production' <<<"$deploy_job"
  grep -qxF "    if: github.event_name != 'pull_request' && github.ref == 'refs/heads/main'" <<<"$deploy_job"
  grep -qxF "          WRANGLER: pnpm --config.minimum-release-age=10080 dlx wrangler@$wrangler_pin" <<<"$deploy_job"
  (lacks -qE 'pages: write|id-token|deploy-pages|_redirects' "$wf")
  (lacks -qF 'repos/{owner}/{repo}/pages' "$r/justfile")
  test "$(grep -c '^    timeout-minutes:' "$wf")" = 3
  test "$(grep -c 'uses: actions/checkout@' "$wf")" = "$(grep -c 'persist-credentials: false' "$wf")"
done
grep -qxF "        run: '\"\$GITHUB_WORKSPACE/.github/scripts/deploy-worker.sh\" Production \"\" --config wrangler.site.jsonc --domain demo.example.org'" cfp/.github/workflows/site.yml
grep -qxF "        run: '\"\$GITHUB_WORKSPACE/.github/scripts/deploy-worker.sh\" Production \"\" --config wrangler.site.jsonc'" cfa/.github/workflows/site.yml
grep -qF "printf '\\n/*\\n  X-Robots-Tag: noindex\\n' >> _site/_headers" cfp/.github/workflows/site.yml
# The Pages site keeps its deploy and its /<repo>/ previews.
grep -qx '      name: github-pages' <<<"$(sed -n '/^  deploy:$/,/^  [a-z]/p' x/.github/workflows/site.yml)"
# Astro on a Worker: `site` is the Worker's address, with no Pages base.
grep -qx '  site: "https://cfa-me-site.example-org.workers.dev",' cfa/site/astro.config.mjs
(lacks -q 'base:' cfa/site/astro.config.mjs)
# shellcheck disable=SC2016 # the backticks are Markdown
grep -q 'deploys that build to the Cloudflare Worker `cf-me-site`' cfp/README.md
grep -q 'deploys that build to GitHub Pages' x/README.md
# site_url: asked of a site on a Worker, defaulting to the site Worker's address; a Pages
# site has none.
grep -qx 'site_url: https://cfa-me-site.example-org.workers.dev' cfa/.copier-answers.yml
(lacks -q 'site_url' x/.copier-answers.yml y/.copier-answers.yml)
# Other kinds get none of it.
test ! -e a/wrangler.jsonc
(lacks -q 'production' a/.github/workflows/ts.yml)
test ! -e a/.github/workflows/preview-retire.yml
(lacks -q 'preview' a/.github/workflows/ts.yml)
grep -q 'stages: \[pre-push\]' d/.pre-commit-config.yaml
grep -qx 'default_install_hook_types: \[pre-commit, commit-msg, pre-push\]' d/.pre-commit-config.yaml
(lacks -q 'pre-push' a/.pre-commit-config.yaml)
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
# Spelling and links: a fresh render passes both hooks, and fails them on a misspelt
# word and on a relative link to a missing file. prek needs a git repo, so each check
# runs in a copy. lychee runs offline in the hook; links.yml checks the web weekly.
prek=(uvx -q "prek${PREK_VERSION:+@$PREK_VERSION}" run --all-files)
for r in a b d h; do
  rm -rf "$r-hooks"
  cp -R "$r" "$r-hooks"
  git -C "$r-hooks" init -q
  git -C "$r-hooks" add -A
  (cd "$r-hooks" && "${prek[@]}" typos lychee jsonvet >/dev/null)
  # b is private with no license, so it has no reuse hook.
  [ "$r" = b ] || (cd "$r-hooks" && "${prek[@]}" reuse >/dev/null)
done
# The web apps track the shots spec and ignore only the screenshots `just ts-shots` writes.
rm -rf s-git
cp -R s s-git
git -C s-git init -q
git -C s-git add -A
git -C s-git ls-files --error-unmatch tests/shots/shots.spec.ts >/dev/null
git -C s-git check-ignore -q shots/index-390-light.png
git -C d-hooks ls-files --error-unmatch web/tests/shots/shots.spec.ts >/dev/null
git -C d-hooks check-ignore -q web/shots/index-390-light.png
# h's commit-msg hook takes a sign-off with an email, and refuses one without.
dco_hook=(uvx -q "prek${PREK_VERSION:+@$PREK_VERSION}" run --hook-stage commit-msg --commit-msg-filename msg dco-signoff)
printf 'feat: x\n\nSigned-off-by: Ada Lovelace <ada@example.com>\n' >h-hooks/msg
(cd h-hooks && "${dco_hook[@]}" >/dev/null)
printf 'feat: x\n\nSigned-off-by: Ada Lovelace\n' >h-hooks/msg
(cd h-hooks && ! "${dco_hook[@]}" >/dev/null 2>&1)
rm -rf h-hooks
# citesync passes on each fresh citable render: root (a), nested (c, d, m), one stack (h, r, t).
# Adding a release to CITATION.cff leaves codemeta.json stale, which fails the hook until
# the manual-stage writer fixes it. The writer re-indents codemeta.json, so a second
# pass of the hooks over the citation files must leave nothing to change. biome is skipped:
# it runs through pnpm, which CI's render job doesn't install.
write=(uvx -q "prek${PREK_VERSION:+@$PREK_VERSION}" run citesync-write --hook-stage manual --all-files)
cite_files=(env SKIP=biome uvx -q "prek${PREK_VERSION:+@$PREK_VERSION}" run --files CITATION.cff codemeta.json)
for r in a c d h m r t; do
  rm -rf "$r-cite"
  cp -R "$r" "$r-cite"
  git -C "$r-cite" init -q
  git -C "$r-cite" add -A
  (cd "$r-cite" && "${prek[@]}" citesync >/dev/null)
done
for r in a m r t; do
  printf 'version: "0.1.0"\ndate-released: 2026-10-29\ndoi: 10.5281/zenodo.1234\n' >>"$r-cite/CITATION.cff"
  sed -i.bak 's/^  "@type": "SoftwareSourceCode",$/&\n  "version": "0.0.9",/' "$r-cite/codemeta.json"
  rm "$r-cite/codemeta.json.bak"
  git -C "$r-cite" add -A
  (cd "$r-cite" && ! "${prek[@]}" citesync >../cite.err 2>&1)
  grep -q "version-mismatch.*'0.0.9'" cite.err
  (cd "$r-cite" && "${write[@]}" >/dev/null || true)
  (cd "$r-cite" && "${prek[@]}" citesync >/dev/null)
  grep -q '"version": "0.1.0"' "$r-cite/codemeta.json"
  git -C "$r-cite" add -A
  (cd "$r-cite" && "${cite_files[@]}" >/dev/null || true)
  git -C "$r-cite" add -A
  (cd "$r-cite" && "${cite_files[@]}" >/dev/null)
  git -C "$r-cite" diff --quiet
done
rm -rf a-cite c-cite d-cite h-cite m-cite r-cite t-cite cite.err
# Copier writes the template's commit id into the answers file, and a hex id can spell a
# word typos rejects, so typos skips that file.
printf '# definately\n' >>a-hooks/.copier-answers.yml
git -C a-hooks add .copier-answers.yml
(cd a-hooks && "${prek[@]}" typos >/dev/null)
printf 'This is definately wrong.\n' >a-hooks/docs/typo.md
printf 'See [the guide](missing.md).\n' >a-hooks/docs/dead.md
git -C a-hooks add docs/typo.md docs/dead.md
(cd a-hooks && ! "${prek[@]}" typos >typos.log 2>&1)
grep -qx 'This is definitely wrong.' a-hooks/docs/typo.md
# NumPy spells the flag `writeable`; typos must not rewrite the API to `writable`.
printf 'a.flags.writeable = False\nb = a.flags["WRITEABLE"]\n' >a-hooks/docs/flags.py
cp a-hooks/docs/flags.py flags.py.orig
git -C a-hooks add docs/flags.py
(cd a-hooks && "${prek[@]}" typos >/dev/null)
cmp a-hooks/docs/flags.py flags.py.orig
rm -f flags.py.orig
(cd a-hooks && ! "${prek[@]}" lychee >lychee.log 2>&1)
grep -q 'docs/missing.md.*File not found' a-hooks/lychee.log
# yamlfmt ignores a nested pnpm-lock.yaml passed by prek
mkdir -p a-hooks/ui
cat >a-hooks/ui/pnpm-lock.yaml <<'LOCK'
lockfileVersion: '9.0'

settings:
  autoInstallPeers: true
  excludeLinksFromLockfile: false
LOCK
git -C a-hooks add ui/pnpm-lock.yaml
(cd a-hooks && "${prek[@]}" yamlfmt >/dev/null)
git -C a-hooks diff --quiet ui/pnpm-lock.yaml
# end-of-file-fixer leaves tests/fixtures/ untouched
mkdir -p a-hooks/tests/fixtures
printf 'fixture content' >a-hooks/tests/fixtures/fixture.txt
git -C a-hooks add tests/fixtures/fixture.txt
(cd a-hooks && "${prek[@]}" end-of-file-fixer >/dev/null)
test "$(cat a-hooks/tests/fixtures/fixture.txt)" = 'fixture content'
rm -rf a-hooks b-hooks d-hooks
for r in a b; do
  grep -qx '      - id: typos' "$r/.pre-commit-config.yaml"
  grep -qx '        entry: lychee --no-progress --offline' "$r/.pre-commit-config.yaml"
  grep -q 'lycheeverse/lychee-action@' "$r/.github/workflows/links.yml"
  grep -q 'cron:' "$r/.github/workflows/links.yml"
done
# A private repo's own pages need a sign-in, so its link check skips them.
(lacks -q -- '--exclude' a/.github/workflows/links.yml)
grep -qF -- "--exclude '^https://github\\.com/example-org/odd-name--co([/#?]|\$)'" b/.github/workflows/links.yml
test "$(grep -c 'commit-message: {prefix: chore, include: scope}' a/.github/dependabot.yml)" -eq 5
grep -q "extends: \['config:recommended', ':semanticCommits'\]" d/renovate.json5
grep -qx 'playwright-report/' d/.gitignore
# Outside CI, reusing a server on the preview port would test whichever app holds it.
(lacks -q reuseExistingServer d/web/playwright.config.ts)
(lacks -q 'playwright-report' a/.gitignore)
(lacks -q 'e2e' a/.github/workflows/ts.yml)
(lacks -qx 'shots/' a/.gitignore)
grep -q 'applies-to: security-updates' a/.github/dependabot.yml
# Actions and hook revs share one multi-ecosystem PR, with the same group in Renovate.
grep -qx '  actions-and-hooks:' a/.github/dependabot.yml
test "$(grep -c 'multi-ecosystem-group: actions-and-hooks' a/.github/dependabot.yml)" = 2
grep -q "groupName: 'actions and hooks'" d/renovate.json5
# Lock refreshes carry transitive security fixes, and the week's wait would block them.
grep -A3 'lockFileMaintenance: {' d/renovate.json5 | grep -q 'minimumReleaseAge: null'
# Minor and patch updates and the relock merge themselves, by Renovate, so the merge uses
# its app's bypass. Nothing else does: majors, copier and the actions group stay manual.
grep -qx '  platformAutomerge: false,' d/renovate.json5
grep -A4 'lockFileMaintenance: {' d/renovate.json5 | grep -qx '    automerge: true,'
grep -B3 'automerge: true' d/renovate.json5 | grep -q "groupName: 'runtime'"
test "$(grep -c 'automerge: true' d/renovate.json5)" = 2
# Exemptions that `pnpm audit --fix` writes for fresh security fixes clean themselves up.
grep -qx 'minimumReleaseAgeExcludePrune: true' d/web/pnpm-workspace.yaml
# Only data-pipeline renders it.
test ! -e a/sources.toml
test ! -e a/ATTRIBUTION.md
# Only web-service renders the FastAPI modules; the others keep the stdlib stub.
test ! -e a/src/render_me/app.py
(lacks -q fastapi a/pyproject.toml)
grep -q http.server a/src/render_me/__main__.py
# h: the unit test and the Example are two files, not one overwriting the other.
grep -q 'func TestAdd' h/add_test.go
grep -q 'func ExampleAdd' h/example_test.go

test -f i/main.go
grep -qx '/1tool' i/.gitignore

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
# Whitespace control around the fmt recipe's last line must not glue the next comment onto it.
for r in a h t; do
  grep -qx '# Run every git hook over the whole repo, not just staged files. The checks workflow skips' "$r/justfile"
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
(lacks -q '^  id-token' c/.github/workflows/python-release.yml c/.github/workflows/ts-release.yml)

# repo-settings: a fake gh keeps a list of rulesets and applies the recipe's real --jq
# filter to it. An existing ruleset with a legacy name (protect-main) is adopted in place.
test -f a/.github/rulesets/main.json
test -f a/.github/rulesets/main-checks.json
# A root stack's check is required; c's nested stacks run only on their own paths, so theirs aren't.
test "$(jq -c '[.rules[0].parameters.required_status_checks[].context]' a/.github/rulesets/main-checks.json)" = '["git hooks","pull request title","DCO sign-off","dependency review","python: lint, types, tests","ts: lint, types, tests","fmt, clippy, tests, deny","golangci-lint, tests, govulncheck"]'
test "$(jq '.rules[0].parameters.required_status_checks | length' c/.github/rulesets/main-checks.json)" = 4
test -f a/.github/rulesets/tags.json
fake=$out/fake-gh
mkdir -p "$fake"
echo '[{"name": "release-branches", "target": "branch", "id": 7, "conditions": {"ref_name": {"include": ["refs/heads/release/*"]}}}, {"name": "protect-main", "target": "branch", "id": 42, "conditions": {"ref_name": {"include": ["~DEFAULT_BRANCH"]}}}]' >"$fake/rulesets.json"
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
  *"api user"*) echo "90462640" ;;
  *"code-scanning/default-setup"*)
    if [ -n "${FAKE_CODEQL:-}" ]; then
      echo '{"message":"Code Security must be enabled for this repository to use code scanning.","status":"403"}'
      echo "gh: refused (HTTP $FAKE_CODEQL)" >&2
      exit 1
    fi
    echo '{"state":"configured"}' ;;
  *"-X POST repos/{owner}/{repo}/rulesets --input"*)
    jq --slurpfile b "$input" '. + [{name: $b[0].name, target: $b[0].target, conditions: $b[0].conditions, id: (length + 41)}]' "$list" >"$list.new" && mv "$list.new" "$list"
    cp "$input" "$FAKE_DIR/posted.$(basename "$input")" ;;
  *"-X PUT repos/{owner}/{repo}/rulesets/"*)
    id=${call#*rulesets/}
    id=${id%% *}
    jq --slurpfile b "$input" --argjson id "$id" 'map(if .id == $id then .name = $b[0].name | .target = $b[0].target | .conditions = $b[0].conditions else . end)' "$list" >"$list.new" && mv "$list.new" "$list"
    cp "$input" "$FAKE_DIR/put.$(basename "$input")" ;;
  # The list has no conditions; a GET of one ruleset does.
  *"/rulesets?includes_parents=false"*) jq -r "map(del(.conditions)) | $filter" "$list" ;;
  *"api repos/{owner}/{repo}/rulesets/"*)
    id=${call#*rulesets/}
    id=${id%% *}
    jq -r --argjson id "$id" "first(.[] | select(.id == \$id)) | $filter" "$list" ;;
  *"-X POST repos/{owner}/{repo}/environments/"*"/deployment-branch-policies"*)
    env=${call#*environments/}
    env=${env%%/*}
    pol=$FAKE_DIR/policies-$env.json
    [ -f "$pol" ] || echo '{"branch_policies":[]}' >"$pol"
    name=''
    for arg in $call; do
      case $arg in name=*) name=${arg#name=} ;; esac
    done
    jq --arg n "$name" '.branch_policies += [{"name": $n}]' "$pol" >"$pol.new"
    mv "$pol.new" "$pol"
    echo '{}' ;;
  *"/deployment-branch-policies"*)
    env=${call#*environments/}
    env=${env%%/*}
    pol=$FAKE_DIR/policies-$env.json
    [ -f "$pol" ] || echo '{"branch_policies":[]}' >"$pol"
    jq -r "$filter" "$pol" ;;
  *"-X PUT repos/{owner}/{repo}/environments/"*) echo '{}' ;;
  # Pages is created once; GitHub refuses a second create with 409.
  *"-X POST repos/{owner}/{repo}/pages "*)
    if [ -n "${FAKE_PAGES:-}" ]; then
      echo "gh: refused (HTTP $FAKE_PAGES)" >&2
      exit 1
    fi
    if [ -f "$FAKE_DIR/pages" ]; then
      echo '{"message":"GitHub Pages is already enabled.","status":"409"}'
      echo 'gh: GitHub Pages is already enabled. (HTTP 409)' >&2
      exit 1
    fi
    : >"$FAKE_DIR/pages"
    echo '{}' ;;
  *"-X PUT repos/{owner}/{repo}/pages "*) echo '{}' ;;
  *"repos/{owner}/{repo}"*"--jq .full_name"*) echo "simonvanlierde/project-templates" ;;
esac
FAKE
chmod +x "$fake/gh"
(
  cd a
  # shellcheck disable=SC2030 # the about test and the copier-update run below set their own PATH
  export FAKE_LOG="$fake/log" FAKE_DIR="$fake" PATH="$fake:$PATH"
  just repo-settings >/dev/null
  just repo-settings >/dev/null
  # main adopted protect-main, so only main-checks and tags were posted.
  test "$(grep -c -- '-X POST repos/{owner}/{repo}/rulesets' "$FAKE_LOG")" = 2
  grep -qxF -- 'api -X PUT repos/{owner}/{repo}/rulesets/42 --input .github/rulesets/main.json' "$FAKE_LOG"
  grep -qxF -- 'api -X PUT repos/{owner}/{repo}/rulesets/43 --input .github/rulesets/main-checks.json' "$FAKE_LOG"
  grep -qxF -- 'api -X PUT repos/{owner}/{repo}/rulesets/44 --input .github/rulesets/tags.json' "$FAKE_LOG"
  # A branch ruleset that protects other refs is never adopted.
  (lacks -q -- '-X PUT repos/{owner}/{repo}/rulesets/7 ' "$FAKE_LOG")
  test "$(jq -r '.[] | select(.id == 7) | .name' "$fake/rulesets.json")" = "release-branches"
  # The adoption check matches the files' own conditions.
  jq -e '.conditions.ref_name.include == ["~DEFAULT_BRANCH"]' .github/rulesets/main.json .github/rulesets/main-checks.json >/dev/null
  # protect-main was updated in place to main: no duplicate ruleset on the default branch.
  test "$(jq -r '.[] | select(.id == 42) | .name' "$fake/rulesets.json")" = "main"
  (! jq -e '.[] | select(.name == "protect-main")' "$fake/rulesets.json" >/dev/null)
  patch=$(grep -- '^api -X PATCH repos/{owner}/{repo} ' "$FAKE_LOG" | head -1)
  for flag in allow_squash_merge=true allow_merge_commit=false allow_rebase_merge=false delete_branch_on_merge=true; do
    [[ "$patch " == *" -F $flag "* ]]
  done
  # Every public render has the DCO check, so web commits need a sign-off from silver down.
  [[ "$patch " == *" -F web_commit_signoff_required=true "* ]]
  # SECURITY.md's advisory link needs private vulnerability reporting on.
  grep -qxF -- 'api -X PUT repos/{owner}/{repo}/private-vulnerability-reporting' "$FAKE_LOG"
  # CodeQL default setup scans every PR and push on public repos.
  grep -qxF -- 'api -X PATCH repos/{owner}/{repo}/code-scanning/default-setup -f state=configured' "$FAKE_LOG"
  # Dependabot alerts let Renovate open security PRs.
  grep -qxF -- 'api -X PUT repos/{owner}/{repo}/vulnerability-alerts' "$FAKE_LOG"
  for f in main-checks tags; do
    cmp "$fake/posted.$f.json" ".github/rulesets/$f.json"
  done
  for f in main main-checks tags; do
    cmp "$fake/put.$f.json" ".github/rulesets/$f.json"
  done
  # The required checks are the always-on jobs, by the names the workflows give them.
  for check in 'git hooks' 'pull request title' 'dependency review' 'DCO sign-off'; do
    jq -e --arg c "$check" '.rules[] | select(.type == "required_status_checks")
      | .parameters.required_status_checks | any(.context == $c)' .github/rulesets/main-checks.json >/dev/null
    grep -rqxF "    name: $check" .github/workflows
  done
  # Public: one approval from someone who did not push last, so Scorecard's branch
  # protection can reach 8. An admin may merge without one, but not without the checks,
  # which sit in a ruleset of their own so a bypass of the review leaves them on.
  jq -e '(.rules[] | select(.type == "pull_request").parameters
      | .required_approving_review_count == 1 and .dismiss_stale_reviews_on_push and .require_last_push_approval)
    and ([.rules[].type] | index("required_status_checks") == null)
    and .bypass_actors == [{actor_id: 5, actor_type: "RepositoryRole", bypass_mode: "pull_request"}]' \
    .github/rulesets/main.json >/dev/null
  jq -e '[.rules[].type] == ["required_status_checks"]
    and .bypass_actors == [{actor_id: 5, actor_type: "RepositoryRole", bypass_mode: "pull_request"}]' \
    .github/rulesets/main-checks.json >/dev/null
  # A path filter would leave a required check unreported on some PRs, which blocks them.
  (lacks -q '^ *paths' .github/workflows/checks.yml .github/workflows/pr-title.yml .github/workflows/dco.yml)
  jq -e '.target == "tag" and .conditions.ref_name.include == ["refs/tags/v*"]' .github/rulesets/tags.json >/dev/null
  # A refused CodeQL setup warns with GitHub's reason, and the rest still runs.
  : >"$FAKE_LOG"
  FAKE_CODEQL=403 just repo-settings >/dev/null 2>"$fake/err"
  grep -q 'Warning: CodeQL default setup could not be turned on.*Code Security must be enabled' "$fake/err"
  grep -qxF -- 'api -X PUT repos/{owner}/{repo}/vulnerability-alerts' "$FAKE_LOG"
)
(cd b && ! grep -q 'DCO sign-off' .github/rulesets/main.json)
# Silver: the DCO check needs commits made in GitHub's web UI to carry a sign-off.
: >"$fake/log"
(
  cd h
  # shellcheck disable=SC2031 # the PATH set for this one command, as above
  FAKE_LOG="$fake/log" FAKE_DIR="$fake" PATH="$fake:$PATH" just repo-settings >/dev/null
  patch=$(grep -- '^api -X PATCH repos/{owner}/{repo} ' "$fake/log" | head -1)
  [[ "$patch " == *" -F web_commit_signoff_required=true "* ]]
)
# Release environments and publishing links: c has PyPI, npm and GHCR.
(
  cd c
  # shellcheck disable=SC2030,SC2031 # the about test and the copier-update run below set their own PATH
  export FAKE_LOG="$fake/log-c" FAKE_DIR="$fake" PATH="$fake:$PATH"
  just repo-settings >"$fake/out-c"
  just repo-settings >/dev/null
  for env in pypi npm ghcr; do
    grep -q "api -X PUT repos/{owner}/{repo}/environments/$env " "$fake/log-c"
    grep -q "api -X POST repos/{owner}/{repo}/environments/$env/deployment-branch-policies -f name=v\* -f type=tag" "$fake/log-c"
  done
  grep -q "api -X POST repos/{owner}/{repo}/environments/ghcr/deployment-branch-policies -f name=main -f type=branch" "$fake/log-c"
  test "$(grep -c 'deployment-branch-policies -f name=v\*' "$fake/log-c")" = 3
  test "$(grep -c 'deployment-branch-policies -f name=main' "$fake/log-c")" = 1
  # Only a web app has the preview environment.
  (lacks -q 'environments/preview' "$fake/log-c")
  (lacks -q 'environments/production' "$fake/log-c")
  grep -q 'https://pypi.org/manage/account/publishing/?provider=github&project_name=mono-me&owner=simonvanlierde&repository=project-templates&workflow_filename=python-release.yml&environment=pypi' "$fake/out-c"
  grep -q 'https://zenodo.org/account/settings/github/' "$fake/out-c"
)
# The web app (d) gets the preview environment, with no reviewer or branch limit.
(
  cd d
  # shellcheck disable=SC2030,SC2031 # as above
  export FAKE_LOG="$fake/log-d" FAKE_DIR="$fake" PATH="$fake:$PATH"
  just repo-settings >"$fake/out-d"
  just repo-settings >/dev/null
  grep -qxF -- 'api -X PUT repos/{owner}/{repo}/environments/preview' "$FAKE_LOG"
  (lacks -q 'environments/preview/' "$FAKE_LOG")
  grep -q "Configured environment 'preview'" "$fake/out-d"
  # production: no reviewer, and only main may deploy to it, posted once over two runs.
  grep -qxF -- 'api -X PUT repos/{owner}/{repo}/environments/production -F deployment_branch_policy[protected_branches]=false -F deployment_branch_policy[custom_branch_policies]=true' "$FAKE_LOG"
  test "$(grep -cxF -- 'api -X POST repos/{owner}/{repo}/environments/production/deployment-branch-policies -f name=main -f type=branch' "$FAKE_LOG")" = 1
  (lacks -q 'environments/production.*reviewers' "$FAKE_LOG")
  grep -q "Configured environment 'production'" "$fake/out-d"
)
# The site (x) gets the preview environment and Pages from Actions: created on the first
# run, switched over on the second, when GitHub answers 409.
(
  cd x
  # shellcheck disable=SC2030,SC2031 # as above
  export FAKE_LOG="$fake/log-x" FAKE_DIR="$fake/x" PATH="$fake:$PATH"
  mkdir -p "$FAKE_DIR"
  cp "$fake/rulesets.json" "$FAKE_DIR/"
  just repo-settings >"$fake/out-x"
  just repo-settings >/dev/null
  grep -qxF -- 'api -X PUT repos/{owner}/{repo}/environments/preview' "$FAKE_LOG"
  test "$(grep -cxF -- 'api -X POST repos/{owner}/{repo}/pages -f build_type=workflow' "$FAKE_LOG")" = 2
  test "$(grep -cxF -- 'api -X PUT repos/{owner}/{repo}/pages -f build_type=workflow' "$FAKE_LOG")" = 1
  (lacks -q 'environments/production' "$FAKE_LOG")
  grep -q 'GitHub Pages deploys from Actions' "$fake/out-x"
  # A repo that cannot have Pages (403, 422) gets a warning, and the rest still runs.
  FAKE_PAGES=403 just repo-settings >/dev/null 2>"$fake/err-x"
  grep -q 'GitHub Pages is not available for this repo' "$fake/err-x"
  FAKE_PAGES=422 just repo-settings >/dev/null 2>&1
  (! FAKE_PAGES=500 just repo-settings >/dev/null 2>&1)
)
(lacks -qF 'repos/{owner}/{repo}/pages' "$fake/log-c")
# A site on a Worker (cfp) gets the production environment instead of Pages.
(
  cd cfp
  # shellcheck disable=SC2030,SC2031 # as above
  export FAKE_LOG="$fake/log-cfp" FAKE_DIR="$fake/cfp" PATH="$fake:$PATH"
  mkdir -p "$FAKE_DIR"
  cp "$fake/rulesets.json" "$FAKE_DIR/"
  just repo-settings >"$fake/out-cfp"
  grep -qxF -- 'api -X PUT repos/{owner}/{repo}/environments/preview' "$FAKE_LOG"
  grep -q 'environments/production' "$FAKE_LOG"
  (lacks -qF 'repos/{owner}/{repo}/pages' "$FAKE_LOG")
  grep -q 'see the Site section of the README' "$fake/out-cfp"
)
# Renovate's app skips the review, so its PRs merge themselves, but never the checks.
jq -e '.bypass_actors[1] == {actor_id: 2740, actor_type: "Integration", bypass_mode: "pull_request"}' d/.github/rulesets/main.json >/dev/null
jq -e '.bypass_actors | length == 1' d/.github/rulesets/main-checks.json >/dev/null
# Before the Renovate app is on the repo, GitHub refuses it as a bypass actor. gh prints
# the reason on stdout, as this fake does, and the recipe says to install the app.
nobot=$out/nobot-gh
mkdir -p "$nobot"
cat >"$nobot/gh" <<'FAKE'
#!/usr/bin/env bash
case $* in
  *"-X POST"*"rulesets"*)
    echo '{"message":"Validation Failed","errors":["Actor Renovate integration must be part of the ruleset source or owner organization"],"status":"422"}'
    echo 'gh: Validation Failed (HTTP 422)' >&2
    exit 1 ;;
esac
FAKE
chmod +x "$nobot/gh"
# shellcheck disable=SC2031 # the PATH set for this one command, as above
(cd d && ! PATH="$nobot:$PATH" just repo-settings 2>"$nobot/err" >/dev/null)
grep -q 'https://github.com/apps/renovate, then rerun' "$nobot/err"
# Private: no approval, no bypass and the checks in main itself, as before.
test ! -e b/.github/rulesets/main-checks.json
grep -qx '    for name in main tags; do' b/justfile
jq -e '(.rules[] | select(.type == "pull_request").parameters
    | .required_approving_review_count == 0 and (.dismiss_stale_reviews_on_push | not) and (.require_last_push_approval | not))
  and (.rules | any(.type == "required_status_checks")) and (has("bypass_actors") | not)' b/.github/rulesets/main.json >/dev/null
(lacks -q private-vulnerability-reporting b/justfile)
(lacks -q code-scanning b/justfile)
# repo-about: the About box comes from the answers. No description answer leaves the description alone;
# a quote in it survives the shell and braces survive just; topics only get added.
for r in a b d cfp x; do
  # shellcheck disable=SC2031 # $fake/gh from the repo-settings test, logging every call
  (cd "$r" && FAKE_LOG="$fake/about-$r" PATH="$fake:$PATH" just repo-about >/dev/null)
done
grep -qxF -- 'repo edit --add-topic python --add-topic typescript --add-topic rust --add-topic go --add-topic docker' "$fake/about-a"
grep -qxF -- "repo edit --description A \"quoted\" {{ one }}, naïve \$USD --add-topic python --add-topic typescript --add-topic docker" "$fake/about-b"
grep -qxF -- 'repo edit --homepage https://pipe-me.example-org.workers.dev --add-topic python --add-topic typescript --add-topic docker' "$fake/about-d"
grep -qxF -- 'repo edit --homepage https://demo.example.org --add-topic python' "$fake/about-cfp"
grep -qxF -- 'repo edit --add-topic python' "$fake/about-x"
# The community files and the DCO check come with public and go with it, in every render.
for answers in */.copier-answers.yml; do
  r=${answers%%/*}
  # e renders a tag on HEAD, so it lacks uncommitted edits.
  [ "$r" = e ] && continue
  for f in SECURITY.md CONTRIBUTING.md CODE_OF_CONDUCT.md pull_request_template.md workflows/dco.yml \
    ISSUE_TEMPLATE/bug.yml ISSUE_TEMPLATE/feature.yml ISSUE_TEMPLATE/config.yml; do
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
grep -qx '## Scope and response' a/.github/CONTRIBUTING.md
grep -q 'within about two weeks' a/.github/CONTRIBUTING.md
# A command-line program (c's Rust and Go binaries, d's pipeline) gets the CLI statement
# at the root; a's libraries and research package don't. d's nested web app keeps its own.
for r in c d; do
  grep -qx '# Accessibility' "$r/docs/accessibility.md"
  grep -qF 'NO_COLOR' "$r/docs/accessibility.md"
  grep -qF '<ada@example.com>' "$r/docs/accessibility.md"
done
test ! -e a/docs/accessibility.md
grep -qx '# Accessibility statement' d/web/docs/accessibility.md
# The README says experimental; only a public repo points to CONTRIBUTING.md.
grep -qx 'Status: experimental. It may change in ways that break your code, without notice.' a/README.md
grep -qxF 'Questions and bugs: see [CONTRIBUTING.md](.github/CONTRIBUTING.md).' a/README.md
(lacks -q 'Questions and bugs' b/README.md)
grep -qx 'blank_issues_enabled: false' a/.github/ISSUE_TEMPLATE/config.yml
grep -qx '    url: https://github.com/example-org/render-me/blob/main/.github/CONTRIBUTING.md' \
  a/.github/ISSUE_TEMPLATE/config.yml
(lacks -q '\[NOTE:' a/.github/CODE_OF_CONDUCT.md)
# The bug form: a render with a web app (d) asks for a page URL and a browser and does not
# force shell formatting; the others keep the command-line form. Both pass GitHub's schema.
grep -qx '    id: url' d/.github/ISSUE_TEMPLATE/bug.yml
grep -qx '    id: browser' d/.github/ISSUE_TEMPLATE/bug.yml
(lacks -q 'render: shell' d/.github/ISSUE_TEMPLATE/bug.yml)
grep -qx '      render: shell' a/.github/ISSUE_TEMPLATE/bug.yml
(lacks -qE 'id: (url|browser)$' a/.github/ISSUE_TEMPLATE/bug.yml)
# The browser field covers the environment question on the web form.
(lacks -q 'id: environment' d/.github/ISSUE_TEMPLATE/bug.yml)
grep -qx '    id: environment' a/.github/ISSUE_TEMPLATE/bug.yml
uvx check-jsonschema --builtin-schema vendor.github-issue-forms \
  a/.github/ISSUE_TEMPLATE/bug.yml d/.github/ISSUE_TEMPLATE/bug.yml
# OpenSSF badge: passing (m) adds the test policy and a coding-standards line per stack;
# silver (h) also adds the governance, roadmap and assurance-case skeletons. a is public
# with the default none, so it gets neither.
badge_docs=(GOVERNANCE.md docs/roadmap.md docs/assurance-case.md)
for r in a m; do
  for f in "${badge_docs[@]}"; do test ! -e "$r/$f"; done
done
(lacks -q '## Tests and code style' a/.github/CONTRIBUTING.md)
grep -q '## Tests and code style' m/.github/CONTRIBUTING.md
test "$(grep -c '^- \(Python\|TypeScript\|Rust\|Go\): ' m/.github/CONTRIBUTING.md)" = 4
grep -qx -- '- Go: gofmt and \[golangci-lint\](https://golangci-lint.run).' h/.github/CONTRIBUTING.md
for f in "${badge_docs[@]}"; do test -f "h/$f"; done
# The four parts the silver assurance_case criterion names, in a short skeleton.
for heading in 'Threat model' 'Trust boundaries' 'Secure design principles' 'Weaknesses countered'; do
  grep -qx "## $heading" h/docs/assurance-case.md
done
test "$(wc -l <h/docs/assurance-case.md)" -le 60
grep -qF '| Maintainer |' h/GOVERNANCE.md
grep -qx 'Bus factor: TODO (the fewest people whose departure would leave the project unable to continue).' h/GOVERNANCE.md
# This repo runs the silver render's DCO check, hook and commit rules: it checks its own
# branches too. Below silver a render checks only pull requests from forks.
diff "$repo/.github/workflows/dco.yml" h/.github/workflows/dco.yml
grep -qx '    if: github.event.pull_request.head.repo.full_name != github.repository' \
  a/.github/workflows/dco.yml
(lacks -q '^    if: ' h/.github/workflows/dco.yml)
grep -q 'id: dco-signoff' h/.pre-commit-config.yaml
# The hook and sign-off setting follow dco.yml, which every public render has, with or
# without a license; b is private and has none of the three.
for r in a h i; do
  grep -q 'id: dco-signoff' "$r/.pre-commit-config.yaml"
  grep -q 'web_commit_signoff_required=true' "$r/justfile"
done
test ! -e b/.github/workflows/dco.yml
(lacks -q 'id: dco-signoff' b/.pre-commit-config.yaml)
(lacks -q 'web_commit_signoff_required' b/justfile)
# A fresh clone has only origin, and a pushed branch needs a lease, not a bare force-push.
for f in "$repo/CONTRIBUTING.md" a/.github/CONTRIBUTING.md h/.github/CONTRIBUTING.md \
  a/.github/workflows/dco.yml; do
  grep -qF 'git rebase --signoff origin/main' "$f"
  grep -qF -- '--force-with-lease' "$f"
  (lacks -q 'upstream/main\|force-push' "$f")
done
grep -qx '    if: github.event.pull_request.head.repo.full_name != github.repository' \
  i/.github/workflows/dco.yml
(lacks -q 'the maintainers. included' i/.github/CONTRIBUTING.md)
grep -q 'the maintainers. included' h/.github/CONTRIBUTING.md
cmp "$repo/committed.toml" "$repo/template/committed.toml"
# Its jq filter, run on a commits API fixture, lists the unsigned commit and the sign-off
# without an email, and skips the merge. Trailing whitespace and CRLF still count as signed.
dco_filter=$(uv run --no-project --with pyyaml python -c '
import re, sys, yaml
run = yaml.safe_load(open(sys.argv[1]))["jobs"]["sign-off"]["steps"][0]["run"]
print(re.search(r"--jq \x27(.*?)\x27\)", run, re.S).group(1))' "$repo/.github/workflows/dco.yml")
commits=$out/dco-commits.json
cat >"$commits" <<'JSON'
[
  {"sha": "aaaaaaa1", "parents": [{}], "commit": {"message": "feat: signed\n\nSigned-off-by: Ada Lovelace <ada@example.com>"}},
  {"sha": "bbbbbbb2", "parents": [{}], "commit": {"message": "fix: unsigned"}},
  {"sha": "ccccccc3", "parents": [{}, {}], "commit": {"message": "Merge branch 'main'"}},
  {"sha": "ddddddd4", "parents": [{}], "commit": {"message": "fix: malformed\n\nSigned-off-by: Ada Lovelace"}},
  {"sha": "eeeeeee5", "parents": [{}], "commit": {"message": "fix: trailing space\n\nSigned-off-by: Ada Lovelace <ada@example.com>  "}},
  {"sha": "fffffff6", "parents": [{}], "commit": {"message": "fix: crlf\r\n\r\nSigned-off-by: Ada Lovelace <ada@example.com>\r\n"}},
  {"sha": "1111111a", "parents": [{}], "author": {"type": "Bot"}, "commit": {"message": "chore(deps): bump"}},
  {"sha": "2222222b", "parents": [{}], "author": {"type": "User"}, "commit": {"message": "fix: human on a bot branch"}}
]
JSON
# A bot's commit counts only in a pull request a person opened. A person's commit counts
# in a bot's pull request too.
test "$(PR_BY_BOT=false jq -r "$dco_filter" "$commits")" = "$(printf 'bbbbbbb fix: unsigned\nddddddd fix: malformed\n1111111 chore(deps): bump\n2222222 fix: human on a bot branch')"
test "$(PR_BY_BOT=true jq -r "$dco_filter" "$commits")" = "$(printf 'bbbbbbb fix: unsigned\nddddddd fix: malformed\n2222222 fix: human on a bot branch')"
# copier-update pushes with COPIER_UPDATE_TOKEN when set; GITHUB_TOKEN can't push workflow
# changes, so without it a workflow change becomes an issue, not a failed push.
cu=a/.github/workflows/copier-update.yml
# Copier dependencies and the push token must run on separate workers.
uv run --no-project --with pyyaml python - "$cu" <<'PYTEST'
import sys, yaml
jobs = yaml.safe_load(open(sys.argv[1]))["jobs"]
assert jobs["update"]["permissions"] == {"contents": "read"}
assert "COPIER_UPDATE_TOKEN" not in str(jobs["update"])
assert jobs["push"]["needs"] == "update"
assert any(s.get("uses", "").startswith("actions/download-artifact@") for s in jobs["push"]["steps"])
assert not any("uvx" in s.get("run", "") for s in jobs["push"]["steps"])
PYTEST
cuh=$out/copier-update
mkdir -p "$cuh"
awk -v d="$cuh" '/^      - /{n++} n{print >(d "/step" n)}' "$cu"
grep -l 'copier@' "$cuh"/step* | grep -q .
(! grep -l 'copier@' "$cuh"/step* | xargs grep -q COPIER_UPDATE_TOKEN)
# shellcheck disable=SC2016 # literal workflow text, not shell expansions
grep -qF 'GH_TOKEN: ${{ secrets.COPIER_UPDATE_TOKEN || github.token }}' "$cu"
grep -qx '      issues: write # to ask for a local update when it can.t push one' "$cu"
# The run below stands in true or false for this expression.
grep -qF "HAS_TOKEN: \${{ secrets.COPIER_UPDATE_TOKEN != '' }}" "$cu"
# Run the step's script against a fake gh, a fake uvx that changes one file, a template
# repo with two tags and a bare repo standing in for GitHub. GIT_ALLOW_PROTOCOL=file makes
# a push that misses the rewrite fail instead of reaching github.com.
# Each step's script: the copier step runs first, with no token, then the push step.
for n in copier apply push; do
  case $n in copier) name=Update ;; apply) name=Apply ;; push) name=Push ;; esac
  f=$(grep -l "^      - name: $name" "$cuh"/step*)
  awk '/^        run: \|-$/{f=1;next} f&&NF&&!/^          /{exit} f{sub(/^          /,"");print}' "$f" >"$cuh/$n.sh"
done
cat >"$cuh/gh" <<'FAKE'
#!/usr/bin/env bash
echo "$*" >>"$FAKE_LOG"
case "$1 $2" in
  "issue list") echo "${FAKE_ISSUE:-}" ;;
  "pr list") echo "${FAKE_PR:-}" ;;
esac
FAKE
cat >"$cuh/uvx" <<'FAKE'
#!/usr/bin/env bash
echo "uvx $*" >>"$FAKE_LOG"
mkdir -p "$(dirname "$FAKE_FILE")"
echo "# from the template" >>"$FAKE_FILE"
FAKE
chmod +x "$cuh/gh" "$cuh/uvx"
(
  # A subshell drops the ERR trap; set -E would fire it in every (! ...) below.
  trap 'echo "check-render: failed at line $LINENO" >&2' ERR
  # shellcheck disable=SC2031 # a separate subshell sets its own
  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_ALLOW_PROTOCOL=file \
    GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.org GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.org
  git init -q -b main "$cuh/tpl"
  git -C "$cuh/tpl" commit -q --allow-empty -m one
  git -C "$cuh/tpl" tag v0.9.0
  git -C "$cuh/tpl" tag v0.10.0
  # name, HAS_TOKEN, the open PR and the issue the fake gh finds ("-": none), and the
  # file the update changes.
  while read -r name token pr issue file; do
    p=$cuh/$name
    git init -q --bare "$p.git"
    # An open PR has its branch on the remote, on a history the update does not extend.
    if [ "$pr" != - ]; then git -C "$cuh/tpl" push -q "$p.git" HEAD:refs/heads/chore/copier-update; fi
    git init -q -b main "$p"
    printf '_commit: v0.9.0\n_src_path: %s\n' "$cuh/tpl" >"$p/.copier-answers.yml"
    # A layered template with its own answers file; this project's own is already current.
    if [ "$name" = layer ]; then
      cp "$p/.copier-answers.yml" "$p/.copier-answers.cml.yml"
      printf '_commit: v0.10.0\n_src_path: %s\n' "$cuh/tpl" >"$p/.copier-answers.yml"
    fi
    git -C "$p" add -A
    git -C "$p" commit -q -m init
    # The privileged job starts from a clean checkout, not the generator's worktree.
    git clone -q "$p" "$p-clean"
    (
      cd "$p"
      # shellcheck disable=SC2030,SC2031 # each fake run sets its own environment
      export PATH="$cuh:$PATH" FAKE_LOG="$p.log" FAKE_PR="${pr#-}" FAKE_ISSUE="${issue#-}" \
        FAKE_FILE="${file:-.github/workflows/ci.yml}" \
        GH_TOKEN=fake HAS_TOKEN="$token" REPO=example-org/render-me BASE=main COPIER_VERSION="$copier_pin" \
        RUNNER_TEMP="$p-runner"
      export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0="url.$p.git.insteadOf" \
        GIT_CONFIG_VALUE_0="https://x-access-token:$GH_TOKEN@github.com/$REPO.git"
      : >"$p.gho"
      # The copier step gets neither token variable.
      env -u GH_TOKEN -u HAS_TOKEN GITHUB_OUTPUT="$p.gho" bash --noprofile --norc -eo pipefail "$cuh/copier.sh" >"$p.out" 2>&1 || {
        cat "$p.out" >&2
        exit 1
      }
      # shellcheck disable=SC2030 # each fake run reads its own outputs
      LATEST=$(sed -n 's/^latest=//p' "$p.gho") WORKFLOWS=$(sed -n 's/^workflows=//p' "$p.gho")
      export LATEST WORKFLOWS
      if [ -n "$LATEST" ]; then
        cd "$p-clean"
        bash --noprofile --norc -eo pipefail "$cuh/apply.sh" >>"$p.out" 2>&1 || {
          cat "$p.out" >&2
          exit 1
        }
        bash --noprofile --norc -eo pipefail "$cuh/push.sh" >>"$p.out" 2>&1 || {
          cat "$p.out" >&2
          exit 1
        }
      fi
    )
  done <<'CASES'
issue false 7 -
asked false - 3
push true - -
edit true 7 -
plain false - - README.md
layer true - - README.md
CASES
  cd "$cuh"
  # Newest tag by version, not by name.
  grep -qx "uvx copier@$copier_pin update --answers-file .copier-answers.yml --defaults --vcs-ref v0.10.0" issue.log
  # Each answers file updates on its own, and the PR names the layer that moved.
  grep -qx "uvx copier@$copier_pin update --answers-file .copier-answers.cml.yml --defaults --vcs-ref v0.10.0" layer.log
  (lacks -q 'answers-file .copier-answers.yml' layer.log)
  grep -q '^pr create --head chore/copier-update --base main --title chore: update from template cml v0.10.0 ' layer.log
  git -C layer.git show chore/copier-update:README.md | grep -qx '# from the template'
  # No token and a workflow change: one issue, the older PR closed, no push.
  grep -qxF 'issue list --state all --search "Update from template v0.10.0 by hand" in:title --json number --jq .[0].number' issue.log
  grep -c '^issue create --title Update from template v0.10.0 by hand ' issue.log | grep -qx 1
  grep -q '^pr close 7 --delete-branch ' issue.log
  (! git -C issue.git cat-file -e chore/copier-update:.github/workflows/ci.yml 2>/dev/null)
  # An issue that exists, open or closed, is not asked again.
  (lacks -q '^issue create' asked.log)
  # A token pushes the branch with the workflow change, over the open PR's, then opens or
  # updates the PR. So does no token with no workflow change.
  for r in push:.github/workflows/ci.yml edit:.github/workflows/ci.yml plain:README.md; do
    git -C "${r%%:*}.git" show "chore/copier-update:${r#*:}" | grep -qx '# from the template'
    (lacks -q '^issue ' "${r%%:*}.log")
  done
  grep -q '^pr create --head chore/copier-update --base main ' push.log
  grep -q '^pr create --head chore/copier-update --base main ' plain.log
  grep -q '^pr edit chore/copier-update ' edit.log
  (lacks -q '^pr create' edit.log)
  # Patch data must never replace Git configuration, and artifact symlinks are refused.
  git clone -q "$cuh/tpl" "$cuh/reject-checkout"
  mkdir -p "$cuh/reject/copier-update"
  echo body >"$cuh/reject/copier-update/body.md"
  cat >"$cuh/reject/copier-update/update.patch" <<'PATCH'
diff --git a/.git/config b/.git/config
new file mode 100644
--- /dev/null
+++ b/.git/config
@@ -0,0 +1 @@
+unsafe config
PATCH
  (
    cd "$cuh/reject-checkout"
    # shellcheck disable=SC2031 # the rejection check sets its own environment
    export RUNNER_TEMP="$cuh/reject" LATEST=v0.10.0
    if bash --noprofile --norc -eo pipefail "$cuh/apply.sh" >"$cuh/rejected.log" 2>&1; then
      echo "accepted a patch to Git configuration" >&2
      exit 1
    fi
    grep -qF ".git/config:" "$cuh/rejected.log"
    mv "$RUNNER_TEMP/copier-update/update.patch" "$RUNNER_TEMP/config.patch"
    ln -s "$RUNNER_TEMP/config.patch" "$RUNNER_TEMP/copier-update/update.patch"
    if bash --noprofile --norc -eo pipefail "$cuh/apply.sh" >"$cuh/rejected.log" 2>&1; then
      echo "accepted a symlink artifact" >&2
      exit 1
    fi
    # The symlink fails before Git gets to parse its invalid patch.
    (lacks -qF '.git/config' "$cuh/rejected.log")
  )
)

# rumdl's MD012 rewrites a README with two blank lines in a row on its first commit.
for r in a c; do
  if ! awk '/^$/ { if (++n == 2) exit 1; next } { n = 0 }' "$out/$r/README.md"; then
    echo "check-render: $r/README.md has two blank lines in a row" >&2
    exit 1
  fi
done

# Rendering over a repo with docs/adr leaves ADRs intact, and usage docs guide migration:
adr_dir=$out/adr-check
mkdir -p "$adr_dir/docs/adr"
echo "# 1. Record" >"$adr_dir/docs/adr/0001-x.md"
"${copier[@]}" --vcs-ref=HEAD \
  --data project_name=adr-check --data 'stacks=[python]' \
  --data kind=library "$repo" "$adr_dir"
test -f "$adr_dir/docs/adr/0001-x.md"
test ! -e "$adr_dir/docs/decisions"
grep -q 'docs/adr' "$repo/docs/usage.md"

# Sample code is not recreated on copier update. The update must cross a template commit
# that changes the sample files: from an unchanged template, copier keeps a project's own
# deletions and edits even without the skip and exclude rules. A throwaway template repo
# holds the working tree, so uncommitted edits are tested too.
sample_tpl=$out/sample-tpl
sample_up=$out/sample-up
mkdir -p "$sample_tpl"
cp -R "$repo/copier.yml" "$repo/includes" "$repo/template" "$sample_tpl/"
git_t=(git -C "$sample_tpl" -c user.name=t -c user.email=t@example.org)
"${git_t[@]}" init -q
"${git_t[@]}" add -A
"${git_t[@]}" commit -q -m base
"${copier[@]}" --vcs-ref=HEAD \
  --data project_name=sample-me --data 'stacks=[python]' \
  --data kind=library "$sample_tpl" "$sample_up" >/dev/null
test -f "$sample_up/src/sample_me/__init__.py"
test -f "$sample_up/tests/test_add.py"
grep -q 'def add(' "$sample_up/src/sample_me/__init__.py"
cat >"$sample_up/src/sample_me/__init__.py" <<'PY'
"""sample-me package."""
PY
rm "$sample_up/tests/test_add.py"
git -C "$sample_up" init -q
git -C "$sample_up" add -A
git -C "$sample_up" -c user.name=t -c user.email=t@example.org commit -q -m "customize package"
for f in "$sample_tpl"/template/*/tests/*test_add.py*.jinja "$sample_tpl"/template/*/*/*/__init__.py.jinja; do
  echo '# changed upstream' >>"$f"
done
"${git_t[@]}" commit -q -am "change the samples"
# shellcheck disable=SC2031 # COPIER_VERSION is set at file top
uvx "copier${COPIER_VERSION:+@$COPIER_VERSION}" update --defaults --vcs-ref=HEAD "$sample_up" >"$out/sample-up.log" 2>&1
grep -q 'Updating to template version' "$out/sample-up.log"
(lacks -q 'def add(' "$sample_up/src/sample_me/__init__.py")
test ! -e "$sample_up/tests/test_add.py"

echo "all render checks passed"
