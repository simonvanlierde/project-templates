#!/usr/bin/env bash
# Renders the answer combinations that CI's stack jobs skip, and checks that each
# conditional file landed. Run from the repo root: scripts/check-render.sh "$(mktemp -d)"
#
# Renders HEAD plus uncommitted edits (--vcs-ref=HEAD). COPIER_VERSION pins
# copier; unset, it is the version ci.yml pins.
set -euo pipefail
# A bare test or grep below fails silently under set -e; say which line tripped.
trap 'echo "check-render: failed at ${BASH_SOURCE[0]}:$LINENO" >&2' ERR
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

# Windows git cannot check out a path over 260 characters, and the runner's checkout
# root takes about 40 of them: keep every tracked path under 200.
long=$(git ls-files | awk 'length($0) > 200')
if [ -n "$long" ]; then
  echo "check-render: paths too long for a Windows checkout:" >&2
  echo "$long" >&2
  exit 1
fi

# Copier ignores a data-file key it has no question for, so a misspelt preset key
# would fail nothing: every key must be a top-level question in copier.yml.
for f in presets/*.yml; do
  while read -r k; do
    grep -qx "$k:" copier.yml || {
      echo "check-render: $f sets $k, which is not a question" >&2
      exit 1
    }
  done < <(sed -n 's/^\([a-z_][a-z_0-9]*\):.*/\1/p' "$f")
done

out=${1:?usage: scripts/check-render.sh OUT_DIR}
# A render into a previous run's tree keeps that run's project edits, and the hooks then fail.
if [ -e "$out/a/.copier-answers.yml" ]; then
  echo "check-render: $out holds an earlier run; pass a new directory" >&2
  exit 2
fi
# The identity answers have no defaults. CI's settings file fills them, and
# replaces your own copier settings for this run.
export COPIER_SETTINGS_PATH=$PWD/.github/ci-copier-settings.yml
COPIER_VERSION=${COPIER_VERSION:-$(sed -n 's/^ *COPIER_VERSION: *//p' .github/workflows/ci.yml)}
PREK_VERSION=${PREK_VERSION:-$(sed -n 's/^ *PREK_VERSION: *//p' .github/workflows/ci.yml)}
# shellcheck disable=SC2034 # read in scripts/render/
copier_pin=$(sed -n '/^copier_version:/,/^$/s/^  default: //p' copier.yml)
# shellcheck disable=SC2034 # read in scripts/render/
howfairis_pin=$(sed -n '/^howfairis_version:/,/^$/s/^  default: \([^ ]*\).*/\1/p' copier.yml)
# shellcheck disable=SC2034 # read in scripts/render/
copier=(uvx "copier${COPIER_VERSION:+@$COPIER_VERSION}" copy --defaults --overwrite)

# The checks live in scripts/render/, one file per area, sourced in this order. Each
# file's checks may read state an earlier one left: cases.sh renders first, and later
# files re-render d, render n and edit renders in place, so keep the order.
render=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/render

# A throwaway local tag on HEAD stands in for a release, for render e. The trap uses
# -C because the checks cd out of the repo. The -f on `git tag` covers a killed run
# that left the tag behind.
repo=$PWD
trap 'git -C "$repo" tag -d check-render-tag >/dev/null 2>&1 || true' EXIT
git tag -f check-render-tag >/dev/null

for area in cases parse; do
  # shellcheck source=/dev/null # the area files lint on their own
  source "$render/$area.sh"
done

# NOTE: a bare `! cmd` never trips set -e; the negated subshells below do.
cd "$out"
for area in release ci stacks web site hooks recipes repo update; do
  # shellcheck source=/dev/null
  source "$render/$area.sh"
done

echo "all render checks passed"
