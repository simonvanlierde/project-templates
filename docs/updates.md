# Updates

How a project keeps up with the template and its dependencies, and how an existing repo
adopts the template.

## Keeping your project up to date

`copier update` performs a three-way merge against the latest template release.

User-owned files are never overwritten: `README.md`, `CHANGELOG.md`, citation files (`CITATION.cff`, `codemeta.json`), community-level governance documents, web app starter code, `<package>.api.md`, and `go.mod`.

Known limit: once a project has deleted any file the template renders, copier 9.19.1 reads the skip list before it loads the answers. A Compose-only repo's `compose.yaml` and `.env.example`, and the owned files under `ts_dir` or `go_dir`, then merge with the template's and can conflict. Keep your side of each.

Updates skip the sample code and pages (the package's `__init__.py`, `tests/test_add.py`, the web app's components, the site's pages and Worker scripts), so a sample you deleted stays deleted. So does a feature you turn on later with `copier update --data`: it comes without its samples, which a fresh `copier copy` into a scratch directory shows. Delete a file the project owns, such as `README.md`, `tests/test_benchmarks.py` or `docs/og-card.html`, and the update writes it again.

To move a package directory, run `copier update` with the new path, then delete the old directory yourself.

A project from before v0.12.0 with `docs/adr/` moves its records to `docs/decisions/` and removes `docs/adr/`.

After an update, refresh and commit the lockfiles (`uv lock`, `pnpm install`, `just go-sync`).

### Hearing about new releases

- **Renovate:** Automatically opens update PRs using `copier update --skip-answered --defaults`. Inspect PR diffs for conflict markers before merging.
- **Dependabot:** The `.github/workflows/copier-update.yml` workflow runs weekly and on demand. When updates exist, it opens a PR on branch `chore/copier-update`. It updates each `.copier-answers*.yml` in turn, so a [layered template](usage.md#layering-another-template) lands in the same PR. Closing that PR unmerged skips its tag; a later tag can open a new PR.

Without [the update App](#the-update-app), `copier-update.yml` pushes with `GITHUB_TOKEN`, which can't change files in `.github/workflows/`: an update that does opens an issue asking for a local update instead. A PR it opens starts no checks either, because `GITHUB_TOKEN` events trigger no workflows. Close and reopen the PR to run them; its body says so. To open the PR at all, turn on Settings > Actions > General > "Allow GitHub Actions to create and approve pull requests". With the App, the workflow does not need it.

#### The update App

A GitHub App of your own gives the workflow a token for each run. The token lasts an hour, reaches only the repo it runs in, and is revoked when the job ends. One App serves all your repos.

1. Create the App at <https://github.com/settings/apps/new>. Give it a name and any homepage URL, untick Webhook > Active, and give it the repository permissions Contents, Pull requests and Workflows, each "Read and write". Let it be installed on this account only.
2. On the App's page, note the Client ID and generate a private key, which downloads a `.pem` file.
3. Install the App on each repo that uses the template (Install App, then Only select repositories).
4. In each repo, run `just repo-settings`. It creates the `copier-update` environment and limits it to `main`, so a workflow on another branch can't read the key. (On a private repo on GitHub Free the environment cannot limit branches; see the note below the commands.) Then add the App to it:

   ```sh
   gh variable set COPIER_UPDATE_CLIENT_ID --env copier-update --body <client-id>
   gh secret set COPIER_UPDATE_PRIVATE_KEY --env copier-update <app.private-key.pem
   ```

Delete the `.pem` file afterwards, or keep it in your password manager to set up the next repo.

A private repo on GitHub Free has no environment secrets. There, leave `--env copier-update` out of both commands: the job reads repo-level ones too, but then a workflow on any branch can read the key. There the key is readable from any branch, so use one App per repo, or skip the App and use the `GITHUB_TOKEN` path above.

## Dependency updates

`dependency_bot` selects your automated update tool:

- **Dependabot** (default): built into GitHub; updates dependencies, workflows, and hook SHAs without external apps.
- **Renovate:** install the [Renovate GitHub App](https://github.com/apps/renovate), then run:

  ```sh
  copier update --data dependency_bot=renovate
  ```

  Disable Dependabot automated security fixes (`gh api -X DELETE repos/OWNER/REPO/automated-security-fixes`) while leaving security alerts active.

## Adopting the template in an existing repo

Each guide renders over the repo on a clean branch with `copier copy --overwrite`, then has
you review `git diff` and restore what was yours.

### Adopting the template in an existing Python package

1. On a clean branch, render the template:

   ```sh
   copier copy --vcs-ref=<tag> --overwrite gh:simonvanlierde/project-templates .
   ```

   Enable `customise`, specify `module_name`, and select `python_layout=flat` if code resides at repository root rather than under `src/`.
2. Review `git diff` for `pyproject.toml`. Restore dependencies, authors, and version numbers, then run `just py-sync`.
3. Format with `uv run ruff format`. For existing lint or type check findings, record baseline exceptions rather than disabling rules:
   - Ruff: add existing violation codes to `ignore` in `pyproject.toml` under a `# NOTE: baseline at adoption` comment.
   - ty: configure existing violations as `"warn"` under `[tool.ty.rules]`.
4. If `uv audit` flags patches under a week old, add temporary exemptions under `[tool.uv]` in `pyproject.toml` ([tooling](tooling.md#dependencies)).
5. Remove obsolete workflows, run `just check` and `just hooks`, and commit.
6. Ensure `CHANGELOG.md` contains Keep a Changelog `## [X.Y.Z]` headings for release tagging.

### Adopting the template in an existing web app

1. On a clean branch, render over the repository:

   ```sh
   copier copy --vcs-ref=<tag> --overwrite gh:simonvanlierde/project-templates .
   ```

   Select `ts_kind=web-app`, your framework, and your `user_data` setting.
2. Review `git diff`:
   - Remove unused starter components.
   - Integrate the legal page routes and links into your `src/App.tsx`. Add the paths to `tests/e2e/routes.ts`, and set its `LEGAL_LINKED_FROM` to the routes that link the legal pages.
   - Restore custom configurations in `vite.config.ts` and `vitest.config.ts`. Retain the template's `markdown()` plugin.
   - Restore custom package names in `package.json` and `wrangler.jsonc`.
   - Fill in all TODO markers in `docs/`.
3. Run `pnpm install`. If dependencies are newer than the one-week cooldown, exempt them in `pnpm-workspace.yaml`:

   ```yaml
   minimumReleaseAgeExclude:
     - vite@8.3.5
   ```

4. Move inline scripts from `index.html` into files under `public/` to satisfy `script-src 'self'`.
5. Run `just check` and `just ts-e2e`. Remove legacy workflows replaced by `ts.yml` and commit.

### Adopting the template in an existing Compose-only repo

1. On a clean branch, render over the repo:

   ```sh
   copier copy --vcs-ref=<tag> --overwrite --data 'stacks=[docker]' gh:simonvanlierde/project-templates .
   ```

2. The render keeps an existing `compose.yaml` and `.env.example`, and replaces the justfile.
   `just check` reads `.env.example` in place of `.env`, so give every variable a `${VAR:?}`
   needs there.
3. Move your own recipes into `just/local.just`, which updates never touch. Name the checks
   you add `local-check`: `just check` runs that recipe last.
4. The `docker-compose` entry in `.github/dependabot.yml` reads `compose.yaml` and the
   directories one level below it, where an `include:` usually points. A deeper Compose file
   needs its directory added there. `copier update` keeps that edit unless the template
   changes the same lines, which shows up as a conflict.
5. Run `just check` and `just hooks`. Add the words typos flags in your own files to
   `_typos.toml`, which is yours from then on. Then commit.
