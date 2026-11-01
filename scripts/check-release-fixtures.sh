#!/usr/bin/env bash
# Check release extraction, stable tag selection and the root ignore rules without rendering.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
while IFS= read -r git_var; do unset "$git_var"; done < <(git rev-parse --local-env-vars)
scratch=$(mktemp -d "${TMPDIR:-/tmp}/template-release.XXXXXX")
trap 'rm -rf "$scratch"' EXIT

git -c core.hooksPath=/dev/null init -q "$scratch/ignore"
cp "$root/.gitignore" "$scratch/ignore/.gitignore"
for path in .env .env.local .env.production.local; do
  git -C "$scratch/ignore" -c core.excludesFile=/dev/null check-ignore --no-index -q "$path"
done

cat >"$scratch/CHANGELOG.md" <<'MD'
## [1.0.0]
- see [docs]

[docs]: https://example.com
- second entry

[1.0.0]: https://example.com/releases/tag/v1.0.0
MD
notes=$(bash "$root/template/.github/scripts/release-notes.sh" 1.0.0 "$scratch/CHANGELOG.md")
grep -qx -- '- second entry' <<<"$notes"
grep -qxF '[docs]: https://example.com' <<<"$notes"
if grep -qF '[1.0.0]:' <<<"$notes"; then exit 1; fi

git -c core.hooksPath=/dev/null init -q --bare "$scratch/tags.git"
blob=$(printf '' | git --git-dir="$scratch/tags.git" hash-object -w --stdin)
for tag in v1.9.0 v2.0.0 v2.0.0-rc1; do
  git --git-dir="$scratch/tags.git" update-ref "refs/tags/$tag" "$blob"
done
workflow="$root/template/.github/workflows/{% if dependency_bot == 'dependabot' %}copier-update.yml{% endif %}.jinja"
selection=$(sed -n 's/^ *latest=//p' "$workflow")
# shellcheck disable=SC2034 # the workflow selection below reads url through eval
url="$scratch/tags.git"
latest=$(eval "printf '%s' $selection")
test "$latest" = v2.0.0
git --git-dir="$scratch/tags.git" update-ref -d refs/tags/v2.0.0
git --git-dir="$scratch/tags.git" update-ref -d refs/tags/v1.9.0
latest=$(eval "printf '%s' $selection")
test -z "$latest"

cat >"$scratch/CHANGELOG.md" <<'MD'
## [1.0.0]
- See [installation].

[installation]: https://example.com/install
[1.0.0]: https://example.com/releases/tag/v1.0.0
MD
notes=$(bash "$root/template/.github/scripts/release-notes.sh" 1.0.0 "$scratch/CHANGELOG.md")
grep -qxF '[installation]: https://example.com/install' <<<"$notes"
