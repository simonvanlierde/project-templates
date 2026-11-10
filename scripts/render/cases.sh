# shellcheck shell=bash
# shellcheck disable=SC2154,SC2164 # check-render.sh sets out, repo, copier and set -e
# The renders, and the checks that must see a render before a later one changes it.
# Runs from the repo root, first. Renders a later check depends on stay beside it:
# n in stacks.sh, d again in web.sh, adr-check and sample-up in update.sh.

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
  --data site=plain --data python_windows=true
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
# only silver-badge render, and the docs site without an API reference.
"${copier[@]}" --vcs-ref=HEAD \
  --data project_name=example --data 'stacks=[go]' --data openssf_badge=silver --data docs_site=true . "$out/h"
# go.mod belongs to the project once written: `go mod tidy` rewrites it.
echo '// project edit' >>"$out/h/go.mod"
echo 'project edit' >>"$out/h/docs/index.md"
# The badge documents and the release signing keys are filled in by the project.
# Rendered first, then kept.
for f in GOVERNANCE.md docs/roadmap.md docs/assurance-case.md .github/allowed_signers; do
  test -f "$out/h/$f"
  echo 'project edit' >>"$out/h/$f"
done
"${copier[@]}" --vcs-ref=HEAD \
  --data project_name=example --data 'stacks=[go]' --data openssf_badge=silver --data docs_site=true . "$out/h" >/dev/null 2>&1
for f in GOVERNANCE.md docs/roadmap.md docs/assurance-case.md .github/allowed_signers; do
  grep -q 'project edit' "$out/h/$f"
done
grep -q 'project edit' "$out/h/go.mod"
grep -q 'project edit' "$out/h/docs/index.md"

# m: every stack a library, nested, with both extras, and the docs site with an API reference: mutation.yml and property.yml get a
# job for each. a has libraries too but no extras, so it must render neither. Also the
# only BSD-3-Clause render, and the only npm-only publisher.
"${copier[@]}" --vcs-ref=HEAD \
  --data project_name=mutate-me --data 'stacks=[python,ts,rust,go]' \
  --data kind=library --data ts_kind=library --data rust_kind=library --data go_kind=library \
  --data python_dir=py --data ts_dir=web --data rust_dir=crates/lib --data go_dir=svc \
  --data 'test_extras=[property, mutation]' --data openssf_badge=passing \
  --data license=BSD-3-Clause --data publish_to_npm=true --data cold_install=true \
  --data docs_site=true . "$out/m"
# x: a Python library that publishes but answers python_api=false (CLI-only): no api job.
# x and r have the static site without a package.json. x and d run the tests on Windows.
"${copier[@]}" --vcs-ref=HEAD --data project_name=cli-me --data 'stacks=[python]' \
  --data kind=library --data publish_to_pypi=true --data python_api=false --data site=plain \
  --data 'test_extras=[property,mutation]' --data python_windows=true . "$out/x"
# w: a Python app, the one render no citation file is for.
"${copier[@]}" --vcs-ref=HEAD --data project_name=app-me --data 'stacks=[python]' --data kind=app . "$out/w"
# ds: a command-line-only Python library with the docs site: no API reference.
"${copier[@]}" --vcs-ref=HEAD --data project_name=docs-me --data 'stacks=[python]' \
  --data python_api=false --data docs_site=true . "$out/ds"
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
# hush-plain and hush-astro: a site in a private repo, with a description that needs
# escaping in HTML.
for s in plain astro; do
  "${copier[@]}" --vcs-ref=HEAD --data project_name=hush-me --data 'stacks=[python]' \
    --data 'project_description=Tidies "<b>" tags & more' \
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
  --data publish_to_pypi=true --data cold_install=true --data docs_site=true . "$out/k"
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

# e: released scaffolds render from a tag, the throwaway one check-render.sh puts on
# HEAD. Also the only AGPL-3.0-or-later render.
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
  --data site=plain . "$out/compose-site" 2>"$out/compose-site.log" || {
  cat "$out/compose-site.log" >&2
  exit 1
}
# The closing message names no lockfiles and no package version: this repo has neither.
grep -qx ' *Then commit\.' "$out/compose-site.log"
(lacks -e 'lockfiles' -e 'package manifest' "$out/compose-site.log")
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

# pw: a web app with a Python package on PyPI. python-release.yml takes over from
# release.yml, so it refuses a tag that differs from web/package.json.
"${copier[@]}" --vcs-ref=HEAD --data project_name=pypi-web --data 'stacks=[python,ts]' \
  --data kind=library --data publish_to_pypi=true --data ts_kind=web-app --data ts_dir=web \
  --data user_data=nothing . "$out/pw" >/dev/null 2>&1
test ! -e "$out/pw/.github/workflows/release.yml"
grep -qF 'name: refuse a tag that differs from package.json' "$out/pw/.github/workflows/python-release.yml"
# shellcheck disable=SC2016 # the workflow's literal $app
grep -qF 'web/package.json is at $app, not' "$out/pw/.github/workflows/python-release.yml"

# rsren: Rust with Renovate. Cargo has no release-age cutoff, so its relock gets its own
# branch that waits for review, and the uv and pnpm relocks still merge themselves.
"${copier[@]}" --vcs-ref=HEAD --data project_name=rs-renovate --data 'stacks=[rust]' \
  --data dependency_bot=renovate . "$out/rsren" >/dev/null 2>&1
uv run --no-project --with json5 python - "$out/rsren/renovate.json5" "$out/d/renovate.json5" <<'PY'
import json5, sys
rust, other = (json5.load(open(p)) for p in sys.argv[1:])
assert rust["lockFileMaintenance"]["automerge"] is True
cargo = [r for r in rust["packageRules"] if r.get("matchUpdateTypes") == ["lockFileMaintenance"]]
assert cargo == [{"matchManagers": ["cargo"], "matchUpdateTypes": ["lockFileMaintenance"],
                  "groupName": "cargo lock file maintenance", "automerge": False}], cargo
assert not [r for r in other["packageRules"] if "lockFileMaintenance" in r.get("matchUpdateTypes", [])]
PY
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
# CONTRIBUTING describes the two lines pull_request_template.md asks for.
grep -q 'Tested:' "$out/a/.github/CONTRIBUTING.md"
grep -q 'Not checked:' "$out/a/.github/CONTRIBUTING.md"
# The citesync hook's Python dependencies are exact pins.
grep -q 'additional_dependencies: \[packaging==' "$out/a/.pre-commit-config.yaml"

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
# One repo has one GitHub Pages site.
refuses 'one GitHub Pages site' --data 'stacks=[python]' --data site=plain --data docs_site=true
# A root web app's legal pages are in docs/, which the docs site would publish again.
refuses 'A web app at the repo root' --data 'stacks=[ts]' --data ts_kind=web-app --data user_data=nothing \
  --data docs_site=true
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
# lychee resolves a web app's root-relative links in public/; other kinds have no lychee.toml.
grep -qx 'root_dir = "public"' "$out/s/lychee.toml"
test ! -e "$out/a/lychee.toml"
# The privacy spec's ALLOWED is for what a browser-storage app keeps; ci.yml runs it.
grep -q 'What a first visit may keep in the browser, by name, each with a line' "$out/s/tests/e2e/privacy.spec.ts"
# wk: a web app at the root with the Worker script and a custom domain.
"${copier[@]}" --vcs-ref=HEAD --data project_name=edge-me --data 'stacks=[ts]' \
  --data ts_kind=web-app --data user_data=nothing --data worker=true \
  --data site_url=https://app.example.org/ . "$out/wk"
# cfp and cfa: the site on a Worker instead of Pages. cfp is the plain one with the Worker
# script and a custom domain; cfa the Astro one at its default workers.dev address.
"${copier[@]}" --vcs-ref=HEAD --data project_name=cf-me --data 'stacks=[python]' \
  --data site=plain --data site_host=cloudflare --data worker=true \
  --data site_url=https://demo.example.org . "$out/cfp"
"${copier[@]}" --vcs-ref=HEAD --data project_name=cfa-me --data 'stacks=[python]' \
  --data site=astro --data site_host=cloudflare . "$out/cfa"
# dp: a data-pipeline at the root, whose python.yml ends on the revisions job's `run:` block.
"${copier[@]}" --vcs-ref=HEAD --data project_name=dp-me --data 'stacks=[python]' \
  --data kind=data-pipeline . "$out/dp"
# cfd: a site on a Worker leaves GitHub Pages to the docs site.
"${copier[@]}" --vcs-ref=HEAD --data project_name=cfd-me --data 'stacks=[python]' \
  --data site=plain --data site_host=cloudflare --data docs_site=true . "$out/cfd"
# A site on a Worker ignores wrangler's local secrets and state; a render without wrangler does not list them.
grep -qxF '.dev.vars*' "$out/cfp/.gitignore"
grep -qxF '.wrangler/' "$out/cfp/.gitignore"
lacks -q wrangler "$out/dp/.gitignore"

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
