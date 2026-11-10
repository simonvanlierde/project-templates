# shellcheck shell=bash
# shellcheck disable=SC2154,SC2164 # check-render.sh sets out, repo, copier and set -e
# Release: README links, the changelog, `just release`, citesync bumps and the tag checks.

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
  # The release check reads the key from .github/allowed_signers on origin/main, with the
  # command that file's comment gives. The file as rendered is kept for a case below.
  cp .github/allowed_signers "$rel/rendered_signers"
  echo "$(git config user.email) namespaces=\"git\" $(cat "$(git config --type=path user.signingkey | sed 's/\.pub$//').pub")" >>.github/allowed_signers
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
  # verify-tag.sh, which every release workflow runs, refuses a lightweight tag and a tag
  # signed with a key that is not in .github/allowed_signers on origin/main. Adding the
  # key to the tagged commit's own copy of the file counts for nothing. In the run a tag
  # push starts, the tag must still mark the commit being built.
  .github/scripts/verify-tag.sh v0.1.0 origin/main 2>/dev/null
  (! GITHUB_REF=refs/tags/v0.1.0 GITHUB_SHA=0000000000000000000000000000000000000000 .github/scripts/verify-tag.sh v0.1.0 origin/main >release.log 2>&1)
  grep -qxF 'v0.1.0 moved after this run started: it no longer marks 0000000000000000000000000000000000000000' release.log
  # A ref renamed to point at an older signed tag object, and an unsigned annotated tag.
  git update-ref refs/tags/v9.9.9 "$(git rev-parse refs/tags/v0.1.0)"
  (! .github/scripts/verify-tag.sh v9.9.9 origin/main >release.log 2>&1)
  grep -qxF 'refs/tags/v9.9.9 points at a tag object made for another name' release.log
  git tag -d v9.9.9 >/dev/null
  git tag --no-sign -a -m plain plain
  (! .github/scripts/verify-tag.sh plain origin/main >release.log 2>&1)
  grep -qF 'plain has no SSH signature' release.log
  # The file as rendered lists no key, so a release before you add yours refuses.
  git checkout -q -b rendered
  cp "$rel/rendered_signers" .github/allowed_signers
  git commit -q -s -am 'chore: no keys'
  (! .github/scripts/verify-tag.sh v0.1.0 rendered >release.log 2>&1)
  grep -qxF 'v0.1.0 is not signed with a key in .github/allowed_signers on rendered.' release.log
  git checkout -q main
  git tag light
  (! .github/scripts/verify-tag.sh light origin/main >release.log 2>&1)
  grep -qxF 'light is a lightweight tag; make it with .github/scripts/tag-release.sh' release.log
  ssh-keygen -q -t ed25519 -N '' -f "$rel/other"
  echo "mallory@example.org namespaces=\"git\" $(cat "$rel/other.pub")" >>.github/allowed_signers
  git commit -q -s -am 'chore: trust another key'
  git -c user.signingkey="$rel/other.pub" tag -s -m other other
  git -c gpg.ssh.allowedSignersFile=.github/allowed_signers verify-tag other 2>/dev/null
  (! .github/scripts/verify-tag.sh other origin/main >release.log 2>&1)
  grep -qxF 'other is not signed with a key in .github/allowed_signers on origin/main.' release.log
  # tag-release.sh refuses the same tag before the push and deletes the tag it made.
  git reset -q --hard origin/main
  git tag -d v0.1.0 >/dev/null
  git config user.signingkey "$rel/other.pub"
  (! .github/scripts/tag-release.sh 0.1.0 >release.log 2>&1)
  grep -qxF 'v0.1.0 is not signed with a key in .github/allowed_signers on origin/main.' release.log
  (! git rev-parse -q --verify refs/tags/v0.1.0 >/dev/null)
  # A refused tag that was already here stays, and the message says how to delete it.
  git tag -s -m v0.1.0 v0.1.0
  (! .github/scripts/tag-release.sh 0.1.0 >release.log 2>&1)
  grep -qxF 'the refused tag v0.1.0 was already here; delete it, then run this again: git tag -d v0.1.0' release.log
  git rev-parse -q --verify refs/tags/v0.1.0 >/dev/null
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
# A web app's first run sets package.json to the version and commits it with
# CHANGELOG.md. The tag run refuses a package.json at another version on origin/main
# before it signs anything.
git init -q --bare -b main "$rel/s-origin.git"
cp -R s "$rel/s"
(
  # shellcheck disable=SC2030,SC2031 # only this subshell reads them
  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
  cd "$rel/s"
  git init -q -b main
  git remote add origin "$rel/s-origin.git"
  git config user.name 'Marie Curie'
  git config user.email curie@example.org
  git config gpg.format ssh
  git config user.signingkey "$rel/key.pub"
  echo "curie@example.org namespaces=\"git\" $(cat "$rel/key.pub")" >>.github/allowed_signers
  sed -i 's/^## \[Unreleased\]$/&\n\n- first thing/' CHANGELOG.md
  git add -A
  git commit -q -s -m 'chore: init'
  git push -q origin main
  just release 0.2.0 >/dev/null
  test "$(git show --name-only --format= HEAD | sort | tr '\n' ' ')" = 'CHANGELOG.md package.json '
  grep -qx '  "version": "0.2.0",' package.json
  git push -q origin main
  sed -i 's/^  "version": "0.2.0",$/  "version": "0.1.0",/' package.json
  git commit -q -s -am 'chore: set another version'
  git push -q origin main
  (! just release 0.2.0 >release.log 2>&1)
  grep -qxF 'package.json on origin/main is at 0.1.0, not 0.2.0' release.log
  (! git rev-parse -q --verify refs/tags/v0.2.0 >/dev/null)
  test -z "$(git -C "$rel/s-origin.git" tag)"
)
# The release workflow refuses a tag that differs from package.json, before it publishes.
# shellcheck disable=SC2016 # literal $app and ${TAG#v}
grep -qF '[ "$app" = "${TAG#v}" ] || { echo "::error::web/package.json is at $app, not ${TAG#v}"; exit 1; }' d/.github/workflows/release.yml
(lacks -q 'differs from package.json' a/.github/workflows/release.yml)
