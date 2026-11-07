#!/usr/bin/env bash
# Exit 0 only when TAG is an annotated tag with an SSH signature from a key listed in
# .github/allowed_signers as committed at REF. REF is the default branch, never the tag:
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
  echo "\$(git config user.email) namespaces=\"git\" \$(cat "\$(git config user.signingkey)")" >>.github/allowed_signers
EOF
  exit 1
fi
