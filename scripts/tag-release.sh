#!/usr/bin/env bash
# Sign the release tag vX.Y.Z on origin/main with your git signing key and push it.
# The release workflow refuses a tag GitHub cannot verify, so a tag pushed any other
# way publishes nothing.
#
#   scripts/tag-release.sh 0.11.0
set -euo pipefail

version=${1:?usage: scripts/tag-release.sh X.Y.Z}
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  echo "not a version: $version" >&2
  exit 1
}
tag="v$version"

git fetch --quiet origin main
sha=$(git rev-parse origin/main)
git show "$sha:CHANGELOG.md" | grep -q "^## \[$version\] - " || {
  echo "CHANGELOG.md on origin/main has no $version section" >&2
  exit 1
}

# A tag left by an earlier run is reused only if it marks the same commit.
if git rev-parse --quiet --verify "refs/tags/$tag" >/dev/null; then
  [[ $(git rev-parse "$tag^{commit}") == "$sha" ]] || {
    echo "tag $tag exists locally on another commit" >&2
    exit 1
  }
else
  git tag --sign "$tag" --message "$tag" "$sha"
fi
git verify-tag "$tag" >/dev/null 2>&1 || {
  echo "tag $tag is not signed with a key git trusts (gpg.ssh.allowedSignersFile)" >&2
  exit 1
}
git push origin "refs/tags/$tag"
