# Setting up the repo

The one-time GitHub setup around a new repo, after [the render](usage.md): making it
public, protecting `main`, the About box, and publishing its first release.

## Public repos

`public` defaults to `yes`. Choosing `no` for private repositories omits `.github/SECURITY.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `pull_request_template.md`, issue forms, and the DCO sign-off check.

Public repositories also receive `.github/workflows/scorecard.yml` to publish [OpenSSF Scorecard](https://scorecard.dev) results for the README badge.

### Making a repo public

Before switching a private repository to public:

1. Scan git history for committed secrets:

   ```sh
   betterleaks git --log-opts=--all .
   ```

   Revoke any detected credentials and rewrite history before publishing.
2. Confirm package name availability on target registries ([PyPI](https://pypi.org/search/), [crates.io](https://crates.io), [npm](https://www.npmjs.com)).
3. Review open issues and pull requests to ensure internal notes or identifiers are removed.
4. Verify the status statement in `README.md`.

Update the repository configuration with Copier:

```sh
copier update --data public=true --data license=MIT
```

## Protecting main

`just repo-settings` applies `.github/rulesets/main.json` using the GitHub CLI:

- Blocks force-pushes and branch deletions.
- Enforces linear history and squash merges.
- Requires pull requests. A required check blocks every PR that skips CI, because a skipped workflow leaves its check pending. If some PRs in your repo skip CI, drop `required_status_checks` from the ruleset or make that check always report. In private repositories, the checks `git hooks`, `pull request title` and `dependency review` must pass.
- In public repositories, requires one approving review submitted after the latest push. Required checks reside in `.github/rulesets/main-checks.json`, which requires the same three, `DCO sign-off`, and each stack's own check (`ts: lint, types, tests` and so on, with `python: tests (windows)` under `python_windows`) for a stack at the repo root, `compose` in a Compose-only repo, plus `site: build` when the project has a site. A nested stack's workflow runs only when its folder changes, so its check is not required.
- With `dependency_bot=renovate`, permits the Renovate app to bypass review for minor and patch updates once required checks pass.
- Applies `.github/rulesets/tags.json` to restrict `v*` tag creation to repository administrators.
- Enables Dependabot security alerts (`gh api -X PUT repos/OWNER/REPO/vulnerability-alerts`).

It leaves one setting to you: refusing any action not pinned to a full commit SHA. The template's workflows pin every action, but the setting also stops a workflow added later from using a tag. Turn it on once the repo's own workflows pin too, since an unpinned action then fails its run:

```sh
gh api -X PUT repos/OWNER/REPO/actions/permissions -F enabled=true -f allowed_actions=all -F sha_pinning_required=true
```

This call also resets `allowed_actions` to `all`; check the current value first with `gh api repos/OWNER/REPO/actions/permissions`.

Execute `just repo-settings` once after creating the repository and again whenever ruleset templates change. Requires administrative permissions.

## The GitHub About box

`just repo-about` syncs repository metadata with `gh repo edit`:

- Updates repository description from `project_description`.
- Sets the homepage: `site_url` for a web app or a site on a Worker, else the GitHub Pages address of the site or the documentation site.
- Adds stack topics (`python`, `typescript`, `rust`, `go`, `docker`). Existing manual topics are preserved.

## Publishing

To publish a release:

1. Set the version `X.Y.Z` in the manifest you publish (`pyproject.toml` or `package.json`). A citable project sets it in every manifest `citesync.toml` lists, or in every manifest at the root when it has no `citesync.toml`. `CITATION.cff` starts without a `version`, which citesync skips. Once you add one, after the first release, keep it in step, or citesync fails with `version-mismatch`.
2. Run `just release X.Y.Z`. It checks that version and, in a citable project, runs the citesync hook, then cuts `## [Unreleased]` in `CHANGELOG.md` into `## [X.Y.Z] - date`, fixes the compare links and commits. In a web app it also sets the version in `package.json` itself and commits both files.
3. Merge that commit to `main`, then run `just release X.Y.Z` again on up-to-date `main`. It signs the annotated tag `vX.Y.Z` on `origin/main`, checks it against `.github/allowed_signers` on `origin/main` and pushes it. A web app's run first refuses a `package.json` on `origin/main` at another version, and its `release.yml` refuses such a tag again before it publishes. See [Signed release tags](#signed-release-tags) for the key it needs.

With `publish_to_pypi`, `python-release.yml` publishes to PyPI and attaches distributions and Sigstore provenance to the GitHub release. Other configurations publish using `release.yml`.

If a publishing job fails before any artifacts upload to the registry, re-run the failed CI job on the existing tag. PyPI uploads stay strict: an existing filename fails the job, so inspect the registry for a partial upload first. If any release artifact is already published, keep the git tag and publish a new patch release. This includes a failure in `docker.yml`'s attestation step after the image push. GitHub Actions can re-run a job, but not an individual step; re-running this job rebuilds the image and repoints the semver tags.

Publishing controls:

| Option | Disabled | Enabled |
| --- | --- | --- |
| `publish_to_pypi` | Package marked `Private :: Do Not Upload` | `python-release.yml` publishes to PyPI |
| `publish_to_npm` | Package set to `"private": true` | `ts-release.yml` publishes to npm |
| `publish_to_ghcr` | Images built and tested; no push | Images pushed to GitHub Container Registry |

Setting up trusted publishing (OIDC):

1. Configure trusted publishers on [pypi.org](https://pypi.org/manage/account/publishing/) or [npmjs.com](https://docs.npmjs.com/trusted-publishers/). For npm, manually publish version 0.1.0 before enabling trusted publishing.
2. Enable publishing via Copier:

   ```sh
   copier update --data publish_to_pypi=true
   ```

3. Run `just repo-settings` to create the enabled publishing environments (`pypi`, `npm`, `ghcr`). It sets yourself as required reviewer and a `v*` tag policy (`ghcr` also on `main`).

### Signed release tags

Every workflow that publishes from a tag (`release.yml`, `python-release.yml`, `ts-release.yml`, and the tag push in `docker.yml`) first runs `.github/scripts/verify-tag.sh`. It passes only an annotated tag with an SSH signature from a key listed in `.github/allowed_signers`, read from the default branch rather than from the tag, so a tag cannot bring its own key. GitHub's "Verified" mark is not enough: it accepts a key registered to any GitHub account. `tag-release.sh` runs the same check before it pushes.

The file renders with a comment and no keys, so the first release fails until you add yours. Sign with an SSH key (`git config gpg.format ssh` and `git config user.signingkey ~/.ssh/id_ed25519.pub`), then add it and commit to `main`:

```sh
echo "$(git config user.email) namespaces=\"git\" $(cat "$(git config --type=path user.signingkey | sed 's/\.pub$//').pub")" >>.github/allowed_signers
```

The check holds together with the `v*` tag ruleset, which lets only admins push tags: a tag runs the workflow and script from its own commit, so a tag pushed by someone else could carry a weaker check. `copier update` and Renovate also move a project to the newest `v*` tag of the template whether or not that tag's `release.yml` accepted it.

A GPG-signed tag fails the check: `git tag -v` reads an allowed signers file for SSH signatures only. `allowed_signers` is the project's file after the first render, and `copier update` leaves it alone. To check a tag yourself: `git -c gpg.ssh.allowedSignersFile=.github/allowed_signers tag -v vX.Y.Z`.

### First release

A public citable project, a project at level `standard` or `community`, and one with `publish_to_pypi` get `.github/first-release.md`: the one-time steps around the first release, only those its answers need. `just repo-settings` prints the command that opens it as an issue. Delete the file once the issue is open.

The steps are the release signing key, PyPI trusted publishing, Zenodo, [Software Heritage](https://archive.softwareheritage.org/save/), the [Research Software Directory](https://research-software-directory.org) and the OpenSSF Best Practices badge. A public citable README gets a Software Heritage badge. It reads "not found" until the archive has visited the repo, then links to the archived copy and its SWHID. After `just release` pushes a tag, it prints the Software Heritage save link.
