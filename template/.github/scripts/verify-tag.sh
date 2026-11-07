#!/usr/bin/env bash
# Exit 0 only when TAG is an annotated tag named TAG, with an SSH signature from a key
# listed in .github/allowed_signers as committed at REF. In the run that the tag's push
# started, the tag must also still mark GITHUB_SHA, the commit the workflow builds. REF is the default branch, never the tag:
# the tagged commit's copy of the list is whatever the tag's pusher wrote. GitHub's
# "Verified" mark is no substitute, since it accepts a key registered to any account.
# Usage: verify-tag.sh TAG REF
set -euo pipefail

tag=${1:?usage: verify-tag.sh TAG REF}
ref=${2:?usage: verify-tag.sh TAG REF}

if [ "$(git cat-file -t "refs/tags/$tag")" != tag ]; then
  echo "$tag is a lightweight tag; make it with .github/scripts/tag-release.sh" >&2
  exit 1
fi
# The signed object names its tag: a ref renamed to point at an old signed tag fails here.
if [ "$(git cat-file tag "refs/tags/$tag" | sed -n '/^$/q; s/^tag //p')" != "$tag" ]; then
  echo "refs/tags/$tag points at a tag object made for another name" >&2
  exit 1
fi
if [ "${GITHUB_REF:-}" = "refs/tags/$tag" ] && [ "$(git rev-parse "refs/tags/$tag^{commit}")" != "$GITHUB_SHA" ]; then
  echo "$tag moved after this run started: it no longer marks $GITHUB_SHA" >&2
  exit 1
fi
# git tag -v reads only SSH signatures against the allowed signers file. A GPG signature
# would be checked against the local keyring instead, which the release runner does not have.
if ! git cat-file tag "refs/tags/$tag" | grep -xF -- '-----BEGIN SSH SIGNATURE-----' >/dev/null; then
  echo "$tag has no SSH signature: sign tags with an SSH key (git config gpg.format ssh)" >&2
  exit 1
fi

signers=$(mktemp)
trap 'rm -f "$signers"' EXIT
git show "$ref:.github/allowed_signers" >"$signers"
if ! git -c gpg.ssh.allowedSignersFile="$signers" tag -v "$tag" >/dev/null; then
  cat >&2 <<EOF
$tag is not signed with a key in .github/allowed_signers on $ref.
To allow your SSH signing key, run this and commit the change to the default branch:
  echo "\$(git config user.email) namespaces=\"git\" \$(cat "\$(git config --type=path user.signingkey | sed 's/\.pub\$//').pub")" >>.github/allowed_signers
EOF
  exit 1
fi
