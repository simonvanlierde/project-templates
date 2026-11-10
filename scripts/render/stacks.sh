# shellcheck shell=bash
# shellcheck disable=SC2154,SC2164 # check-render.sh sets out, repo, copier and set -e
# Per stack: the answers source, library and binary layouts, the bots, monorepo paths,
# Docker, the publishing workflows, licenses and REUSE. Renders n.

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
# Every workflow that publishes from a tag checks it against .github/allowed_signers on the
# default branch, and every render that has one gets that file. e renders the last commit,
# without uncommitted edits.
n=0
for wf in */.github/workflows/{release,python-release,ts-release}.yml c/.github/workflows/docker.yml; do
  [ -e "$wf" ] && [ "${wf%%/*}" != e ] || continue
  # shellcheck disable=SC2016 # literal workflow text
  grep -qF '/.github/scripts/verify-tag.sh" "$TAG" "origin/$DEFAULT_BRANCH"' "$wf"
  (lacks -qF '.verification.verified' "$wf")
  test -x "${wf%%/*}/.github/scripts/verify-tag.sh"
  test -f "${wf%%/*}/.github/allowed_signers"
  n=$((n + 1))
done
test -f c/.github/workflows/python-release.yml && test -f c/.github/workflows/ts-release.yml && test "$n" -ge 11
grep -qxF "        if: startsWith(github.ref, 'refs/tags/')" c/.github/workflows/docker.yml
# Both package workflows exist; Python creates the GitHub release after PyPI.
test ! -e c/.github/workflows/release.yml
test -f c/.github/workflows/ts-release.yml
grep -qx "    needs: publish" c/.github/workflows/python-release.yml
# The build job installs only uv; the dev group syncs in the test job that publish waits for.
grep -qx "    needs: \[build, test\]" c/.github/workflows/python-release.yml
# The build refuses a tag that does not match the manifest version it publishes.
# shellcheck disable=SC2016 # literal workflow text
grep -qF 'test "$(uv version --short)" = "${GITHUB_REF_NAME#v}"' c/.github/workflows/python-release.yml
# shellcheck disable=SC2016 # literal workflow text
grep -qF '= "${GITHUB_REF_NAME#v}"' c/.github/workflows/ts-release.yml
grep -q -- '--draft --verify-tag' c/.github/workflows/python-release.yml
grep -q -- '--draft=false' c/.github/workflows/python-release.yml
# shellcheck disable=SC2016 # literal workflow expression
grep -qF '${{ steps.attest.outputs.bundle-path }}' c/.github/workflows/python-release.yml
grep -qF 'actions/attest@' c/.github/workflows/python-release.yml
(lacks -q 'attest-build-provenance' c/.github/workflows/python-release.yml)
# shellcheck disable=SC2016 # literal workflow expression
grep -qF 'sbom-path: ${{ steps.sbom.outputs.path }}' c/.github/workflows/python-release.yml
! grep -qF 'sbom-path: sbom/*' c/.github/workflows/python-release.yml
grep -qF 'gh attestation verify' c/.github/workflows/python-release.yml
# The API-break checks render with the publish answers, and only with them: griffe in CI from
# the repository root, so its search path carries the nested dir; the npm report beside
# the nested package.
grep -qx '      - run: uvx griffe@[0-9.]* check --search api/src --format github mono_me' c/.github/workflows/python.yml
# A CLI-only package (x, python_api=false) gets no api job, though it publishes.
grep -q 'name: "python: API breaks since the last tag"' c/.github/workflows/python.yml
test -f x/.github/workflows/python.yml
(lacks -q 'griffe' x/.github/workflows/python.yml)
test -f x/.github/workflows/python-release.yml
# python_windows: one job on windows-latest that runs the tests without ty, a required
# check like the Linux ones. Off by default.
sed -n '/^  windows:/,/^  [a-z]/p' x/.github/workflows/python.yml >windows-job.yml
grep -qx '    name: "python: tests (windows)"' windows-job.yml
grep -qx '    runs-on: windows-latest' windows-job.yml
grep -qx "          python-version: \"$(cat x/.python-version)\"" windows-job.yml
grep -qx '      - run: uv run pytest' windows-job.yml
(lacks -q 'ty check' windows-job.yml)
jq -e '.rules[0].parameters.required_status_checks | any(.context == "python: tests (windows)")' x/.github/rulesets/main-checks.json >/dev/null
# Nested: the git config step runs before checkout creates the folder.
sed -n '/^  windows:/,/^  [a-z]/p' d/.github/workflows/python.yml | grep -A2 'core.autocrlf false' | grep -qx '        working-directory: \.'
(lacks -q 'windows' e/.github/workflows/python.yml a/.github/workflows/python.yml)
(lacks -q 'windows' e/.github/rulesets/main-checks.json)
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
# A Rust library gets cargo-semver-checks in CI and as rs-api (m's nested crate through
# --manifest-path), a binary (c) neither.
grep -q 'name: "rust: API breaks since the last tag"' m/.github/workflows/rust.yml
semver_pin=$(sed -n '/^cargo_semver_checks_version:/,/^$/s/^  default: //p' "$repo/copier.yml")
grep -qxF "          tool: cargo-semver-checks@$semver_pin" m/.github/workflows/rust.yml
# shellcheck disable=SC2016 # literal recipe text
grep -qx '    cargo semver-checks --manifest-path crates/lib/Cargo.toml --baseline-rev "$tag"' m/just/rust.just
# shellcheck disable=SC2016 # literal recipe text
grep -qx '    cargo semver-checks --baseline-rev "$tag"' r/just/rust.just
(lacks -q semver-checks c/.github/workflows/rust.yml c/just/rust.just)
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
test ! -e d/pipe/data/processed/.gitkeep
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
