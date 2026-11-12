# Changelog

All notable changes to projects made from this template. Take a release with
`copier update`.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this
project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Before 1.0.0,
a breaking change bumps the minor version and anything else bumps the patch. Breaking
changes are marked **Breaking**.

## [Unreleased]

### Changed

- The `readme` requirement in `levels.toml` keeps maintainer-only material, such as deploy and release steps, out of the README: it goes in `docs/` or `CONTRIBUTING.md`.

### Fixed

- The project chooser and quick-start examples use the released `python_kind` answer in Python commands.

## [0.15.0] - 2026-11-12

Upgrade steps:

- **Breaking:** one `extras` multiselect replaces the optional CI, profiling, docs-site and library-test questions. Updates from v0.14.0 preserve the old selections, including disabled features. Scripts must pass the full `extras` list instead of `codecov`, `codspeed`, `profiling`, `cold_install`, `python_windows`, `docs_site` or `test_extras`. See [optional features](docs/usage.md#optional-features).
- **Breaking:** a `level` question (`minimal`, `standard` or `community`) replaces `openssf_badge`. An update carries the old answer over: `none` becomes `minimal`, `passing` becomes `standard` and `silver` becomes `community`, so a project keeps the documents it had. At `standard`, a new render's README also gets a `## Usage` section; `README.md` is yours after the first render, so an update leaves it alone. Scripts that pass `--data openssf_badge=...` need `--data level=...` instead.
- The Python `kind` answer is now `python_kind`, which matches `ts_kind`, `rust_kind` and `go_kind`. An update carries the old answer over and rewrites the answers file. Scripts should pass `--data python_kind=...`.
- At `standard`, the render also adds `.github/first-release.md` with the OpenSSF badge step. The [Levels](docs/levels.md) page replaces "How much documentation".
- `cold_install` is on by default for new projects at the `standard` and `community` levels, since the `cold-install` requirement starts at `standard`. An existing project keeps its stored answer; add the workflow with `copier update --ask extras`.

### Fixed

- A new plain site marks invalid JSON input for screen readers and clears that state when the input is valid. Existing sites keep their own script and stylesheet.
- Links to the old usage guide keep their section anchors after the guide splits into setup, hosting, updates and levels pages.
- Docs sites use Zensical 0.0.74, which escapes quotes and markup in site and page descriptions before writing the HTML meta tag.
- On a narrow screen, Tab no longer reaches the links of an open section in the closed navigation drawer of a docs site.
- A docs site with breadcrumbs labels them "Breadcrumb", so screen readers no longer hear two landmarks called "Navigation".
- Docs-site code blocks drop the empty line-number links screen readers announced without a name (`anchor_linenums = false` in `zensical.toml`; add it to an existing one as [Documentation site](docs/usage.md#documentation-site) shows), and a table wider than the page becomes a focusable region, so it scrolls from the keyboard.
- Quick-start commands and preset examples select the intended Python project type with released templates.
- Docs sites that enable code-copy buttons keep their actions from adding duplicate navigation landmarks.
- Docs sites keep mobile navigation reachable by keyboard and selected links readable. Code names in tables no longer break mid-word, and a wide table shows a shadow on the side it scrolls to. New sites use system fonts and a plain repository link without remote statistics; existing sites can adopt the [theme settings](docs/usage.md#documentation-site) after updating.
- Closing a Copier update PR unmerged skips that tag on later weekly runs; a newer tag can still open a PR. A fork's pull request from a branch with the same name no longer counts as declining a tag, and the workflow never edits or closes it. Only the issue the workflow opened itself stops the weekly reminder for a tag.
- Worker previews skip Copier update branches, including updates opened by a user account. A bot's push to a pull request a person opened does not start a preview either. Web app deploys keep hidden build files such as `.well-known/security.txt`.
- Workers explicitly disable observability. With a custom domain, production adds `noindex` only to its duplicate workers.dev origin.
- Generated hooks check shell scripts, and Dependabot projects explain how template updates refresh their prek pin.
- The CodSpeed, property and mutation Python jobs, the docs build, and the `cold-install`, `copier-update`, `fair` and `pr-title` workflows check what uv installs against OSV's malware advisories, as the test job does.
- `tests/test_benchmarks.py` belongs to the project once written. An update or a render into an existing repo keeps the project's own benchmarks, also when it turns `codspeed` on. A deleted one comes back, since the benchmarks workflow runs it.

### Added

- A licensed Astro site checks production dependency licenses during `just site` and its CI build, using the same checker and allow-list as TypeScript projects. Astro itself is a development dependency because it builds the static files; the site’s security audits include development dependencies.
- An Astro site's `site/pnpm-lock.yaml` gets its own `pnpm audit` job in the weekly `advisories.yml`, also in a repo whose stacks have no audit of their own. The build job in `site.yml` runs the same audit on every push and pull request.
- `just site-serve` serves the site locally: Astro's dev server at the address that includes the Pages base, or a plain site over HTTP, since a browser refuses its modules from a file. It fails when port 4321 is taken instead of moving to another port.
- Web-service tests exercise an unavailable OTLP HTTP collector, check that requests still succeed and bound shutdown after SIGTERM.
- [Levels](docs/levels.md): the requirements a public repo meets at each level, by the traits that make a requirement apply, with the standard each comes from and the date it starts to count. `levels.toml` holds them, versioned with the template's releases.
- A license check in each stack's CI job and check recipe, for a project with a license: licensecheck for Python, `pnpm run licenses` (`scripts/checkLicenses.mjs`) for TypeScript, `cargo deny list` beside `cargo deny check` for Rust and go-licenses for Go. Each lists the licenses of the dependencies that ship, not dev tooling, and fails on one the project's license cannot take. TypeScript, Rust and Go share one allow-list that follows the `license` answer: permissive licenses (BlueOak-1.0.0, BSL-1.0, CDLA-Permissive-2.0, PSF-2.0, Python-2.0 and Unlicense among them) and MPL-2.0 for every project, the GPL family for a GPL or AGPL one. Python uses licensecheck's own compatibility table instead, which lets LGPL into a permissive project, refuses Zlib and Unicode-3.0 as unknown, and reads an `AGPL-3.0-*` dependency as the GPL, so a GPL project's check lets it in. `deny.toml` now takes the shared list too, plus `Apache-2.0 WITH LLVM-exception`. If you edited that list, `copier update` may leave a conflict there to resolve.
- `scripts/check_level.py` checks a project's files against `levels.toml` and prints each requirement's status as JSON, with a schema ([Checking a repo](docs/levels.md#checking-a-repo)).
- Four requirements in [Levels](docs/levels.md): `ci-tests` and `dependency-licenses` at `standard`, `release-build` and `architecture-review` at `community`.
- The roadmap skeleton at level `community` asks for each planned theme to link the open issue that tracks it.
- A web app, a site or a docs site gets `docs/og-card.html`, a social card poster built from the project name, description and address, `just og-card` to render it to `og.png`, and `og:image`, size, alt and `twitter:card` tags in the page head. Run `just og-card` and commit the PNG, or the tags point at a missing file. `just og-card` also rewrites the `?v=<hash of the PNG>` on the `og:image` URL in the page head, so link previews that cache by image URL pick up a redrawn card; commit the page with the PNG. A docs site renders the same image to `docs/assets/og.png`, and `docs-overrides/main.html` writes `og:title` (the site name on the home page), `og:description`, `og:url`, `og:image`, size, alt and `twitter:card` on every page from `site_url`, `site_description` and `og_image` in `zensical.toml`; it does nothing without `og_image`. The card source belongs to the project once written: an update adds it when it is missing and leaves an edited one alone. An update does not touch a web app's `index.html` or a site's page: add the tags by hand ([Social card](docs/hosting.md#social-card)). A docs site gets `docs-overrides/main.html`; add `custom_dir`, `extra_css`, `extra_javascript` and `og_image` to its `zensical.toml` as [Documentation site](docs/usage.md#documentation-site) shows.

### Changed

- The release workflows' tag check is one call, `verify-tag.sh --fetch`, which fetches the tag object and the default branch itself.
- `just repo-about` also sets the homepage of a project whose site or documentation site is on GitHub Pages, to its github.io address.
- When `just repo-settings` stops because the plan has no rulesets, a Dependabot project also hears that the update App's key would be readable from any branch, with the link to set it up safely.
- The usage guide is split by job into [setup](docs/setup.md), [hosting](docs/hosting.md), [updates](docs/updates.md) and [levels](docs/levels.md) pages. Links in a new render's README, justfile, CONTRIBUTING and workflows point at them; the old `docs/usage.md` anchors still lead there.

## [0.14.0] - 2026-11-11

Upgrade steps:

- **Breaking:** with Dependabot, `copier-update.yml` no longer reads `COPIER_UPDATE_TOKEN`. Until you set up [the update App](docs/updates.md#the-update-app), it pushes with `GITHUB_TOKEN`, so a template update that changes a workflow opens an issue instead of a PR. Run `just repo-settings`, add the App's client ID and key to the `copier-update` environment, then delete the old secret: `gh secret delete COPIER_UPDATE_TOKEN`. Without the App, the PR is opened with `GITHUB_TOKEN`, which needs Settings > Actions > General > "Allow GitHub Actions to create and approve pull requests".
- **Breaking:** a release workflow publishes only a tag signed with an SSH key listed in `.github/allowed_signers` on `main`, which the update adds with no keys in it. Before your next release, add your signing key and commit the file to `main`: `echo "$(git config user.email) namespaces=\"git\" $(cat "$(git config --type=path user.signingkey | sed 's/\.pub$//').pub")" >>.github/allowed_signers`. A GPG-signed tag no longer publishes: switch to an SSH signing key (`git config gpg.format ssh`).
- **Breaking:** `docker_stacks` is gone, and copier drops the old answer. What the update does depends on what it listed:
  - Only `ts`, without the python stack: the project becomes a [Compose-only repo](docs/usage.md#compose-only-repos). The update deletes the TypeScript `Dockerfile`, `.dockerignore` and `src/main.ts` stub; keep them with `git checkout HEAD -- <path>` before you commit.
  - Only `ts`, with the python stack: update with `copier update --data docker_image=false`, or the update replaces the TypeScript `Dockerfile` with the Python image. In both cases `compose.yaml` is yours and the update leaves it alone, so delete its `web` build service by hand, or restore the `Dockerfile`.
  - `python` and `ts`: the Python service is now named `app`, and the `web` service is gone.
- **Breaking:** a web app or a command-line tool refuses a GitHub noreply `author_email`, because its privacy and accessibility pages give that address as the contact. Update with `copier update --data author_email=<an address that gets mail>` before the weekly `copier-update` run, which would otherwise reset an invalid answer without telling you.
- An update of a web-service, data-pipeline, web-app, Compose-only or Silver-badge project adds `docs/decisions/` with a first record. Update with `copier update --data decision_records=false` to skip it.
- **Breaking:** `site_url` takes a host alone, such as `https://example.org`: no path, port or capitals. Update with `copier update --data site_url=https://<host>` if yours has one, before the weekly `copier-update` run, which would otherwise reset an invalid `site_url` to the default without telling you.
- **Breaking:** in a web app whose `site_url` is a custom domain (not `*.workers.dev`), the production job now attaches that domain on every deploy. Before you merge the update, give the `production` environment's `CLOUDFLARE_API_TOKEN` the permission Zone > Workers Routes: Edit for that domain's zone, or the deploy fails. A domain already on the Worker stays.
- Python projects: an update adds the `sp-repo-review` hook. Run `prek run sp-repo-review --all-files`, then fix each check that fails or skip it under `[tool.repo-review.ignore]` in `pyproject.toml` with its reason ([Scientific Python repo-review](docs/levels.md#scientific-python-repo-review)).
- An update of a public project with a citation or an OpenSSF badge, or of one that publishes to PyPI, adds `.github/first-release.md`. Delete it if the project has already released.
- **Breaking:** data-pipeline projects write Parquet. Before you run `just build` on an existing project, move the old files in `data/processed/` (`.gitkeep` included) out of the way, or `just validate` refuses them. To keep CSV, set `output_format = "csv"` in `sources.toml`.
- **Breaking:** pytest settings move from `[tool.pytest.ini_options]` to pytest 9's `[tool.pytest]` table, with `strict = true`, `filterwarnings = ["error"]`, `log_level = "INFO"` and `minversion = "9.0"`. A warning in your tests now fails them: fix it, or add an `ignore::` entry to `filterwarnings` with the reason. Merge your own pytest options into the new table during `copier update`.
- Updating from before v0.13.0, check three files for a block the update added a second time beside your own, and delete the extra:
  - `pyproject.toml` with `keywords` or `classifiers` already set: TOML refuses the duplicate key, so delete the second of each.
  - `.pre-commit-config.yaml` with a citesync block from v0.12: delete the older one, or citesync runs twice.

### Added

- Scheduled runs of `copier-update.yml`, `advisories.yml` and the daily `preview-retire.yml` sweep open an issue when they fail, or comment on the one already open, as `mutation.yml` and `property.yml` do. All five call one `report-failure.yml` workflow.
- `mutation.yml` and `property.yml` open an issue, or comment on the open one, when a weekly run fails or times out, so a failure no longer reaches only whoever last edited the cron. GitHub pauses schedules after 60 days without repository activity; re-enable them from the Actions tab.
- Compose-only repos: with `docker` in `stacks` and no `python` stack, or with `docker_image=false`, the render has no Dockerfile. It gets a starter `compose.yaml` (an example service pinned by digest, with a healthcheck, bound to `127.0.0.1`) and `.env.example`, which are the project's after the first render (run `just repo-settings` to require the new `compose` check); a `compose.yml` workflow, a required check on `main` in a public repo; the `docker-compose` ecosystem in the dependency bot, which with Dependabot also reads the directories one level down, where an `include:` points; a `just check` that runs `docker compose --env-file .env.example config -q` and lints shell scripts; and a `just docker-fmt` that `just fmt` runs. With `cold_install`, that job runs each other stack's own `check` and `fmt` in place of `just check` and `just fmt`, which need Docker. Projects with the Python image render as before ([Compose-only repos](docs/usage.md#compose-only-repos)).
- `python_windows` (asked under `customise`, off by default) adds a `python: tests (windows)` job to `python.yml`: the tests on `windows-latest` with `python_version`, without ruff or ty, so a missing `encoding="utf-8"` or a POSIX-only path fails CI. A required check in a public repo with the package at the root ([Tests on Windows](docs/usage.md#tests-on-windows)).
- `just check` ends with the repo's own `local-check` recipe when `just/local.just` has one.
- `decision_records`: `docs/decisions/` with a MADR 4.0.0 index and a first record that the project starts from this template. On by default for the web-service, data-pipeline and web-app kinds, Compose-only repos and Silver-badge projects; AGENTS.md then points at it. ([Decision records](docs/usage.md#decision-records)).
- `site_host`, asked with a static site: `cloudflare` deploys `main` to the Worker `<slug>-site` from `wrangler.site.jsonc` instead of GitHub Pages, served from `/` (an Astro site gets no `base`). `just repo-settings` then creates the `production` environment and leaves Pages alone. The default, `pages`, renders as before ([Static site](docs/hosting.md#static-site)).
- A custom domain from `site_url`: a host other than `*.workers.dev` is attached to the production Worker of the web app, or of a site on Cloudflare, by `wrangler deploy --domain` in the production job. Previews deploy without it. `site_url` is asked of a site on Cloudflare too ([Workers hosting](docs/hosting.md#custom-domains)).
- `worker`, asked of a web app or a site on Cloudflare: a Worker script in front of the static assets, with the `ASSETS` binding and `run_worker_first` for `/api/*`, and an example `/api/health` route. A web app gets `worker/index.ts`, typed with `@cloudflare/workers-types` and tested by Vitest; a site gets `site/worker/index.mjs`, tested with `node --test` by `just site` ([Workers hosting](docs/hosting.md#worker-script)).
- `presets/`: answers files for a Rust CLI, a uv research package and a Compose-only deploy repo, passed with `--data-file` ([Presets](docs/usage.md#presets)), and a note on layering an organisation's own template with its own answers file.
- With `openssf_badge` set, `README.md` gets a `## Usage` section: where to get the software (releases, and PyPI or npm when the project publishes there), and a TODO for what it does and its basic use. The OpenSSF passing criteria and OSPS Baseline level 1 ask for both. The README is the project's after the first render, so `copier update` doesn't add the section to an existing one.
- `just repo-settings` turns on secret scanning and push protection in a public repo. GitHub then refuses a push that holds a known secret format (OSPS Baseline BR-07.01).
- The [badge section](docs/levels.md#openssf-best-practices-badge) of the usage docs lists the steps before you register a project on bestpractices.dev, the criteria only you can answer, and which file or setting meets each OSPS Baseline level 1 control.
- A Rust library gets an API-break check: an `api` job in `rust.yml` and a `just rs-api` recipe run `cargo-semver-checks` against the last `v*` tag. A break fails until `Cargo.toml`'s version is bumped to match (major, or minor before 1.0). With no tag yet, it passes ([API-break check](docs/usage.md#api-break-check)).
- Python projects run Scientific Python's [repo-review](docs/levels.md#scientific-python-repo-review) as a git hook (`sp-repo-review`), so `just hooks` and CI check the packaging, pytest and workflow settings. `[tool.repo-review.ignore]` in `pyproject.toml` lists the checks the template skips, each with its reason.
- `.github/first-release.md`, a checklist to open as an issue for the [first release](docs/setup.md#first-release): PyPI trusted publishing, Zenodo, Software Heritage, the Research Software Directory and the OpenSSF badge, as far as the answers need them. `just repo-settings` prints the `gh issue create` command.
- A public citable README gets a Software Heritage archive badge, and `just release` prints the Software Heritage save link after it pushes the tag. The badge lands in new renders only, since `copier update` leaves README.md alone.
- `docs_site` (under `customise`): a documentation site that [Zensical](https://zensical.org) builds from the Markdown in `docs/`, with search. It renders `zensical.toml`, a `docs/index.md` home page, `just docs` and `just docs-serve`, and a `docs.yml` workflow. The workflow builds with `--strict` on every pull request and deploys to GitHub Pages from `main`. A Python library with `python_api` also gets `docs/reference.md`, an API reference from the docstrings. The validator refuses it together with a `site` on GitHub Pages, since a repo has one Pages site; a site on a Worker can sit beside it. It also refuses a web app at the repo root, whose privacy and accessibility pages in `docs/` the site would publish a second time ([Documentation site](docs/usage.md#documentation-site)).

### Changed

- The Cloudflare deploy and preview jobs in `ts.yml` and `site.yml` check their secrets with one `.github/scripts/cloudflare-gate.sh`, after checkout. They skip with the same notices as before.
- **Breaking:** data-pipeline projects use `sourceledger[parquet]>=0.5.0` and write Parquet with zstd compression and explicit string columns (see the upgrade steps). sourceledger is exempt from `exclude-newer`, so a new release resolves without the week's wait.
- `python-release.yml` builds `dist/` in a job that installs only uv. A new `test` job syncs the dev group and runs the linters, the suite and the wheel suite after the upload, and `publish` needs both, so a compromised test dependency cannot change what the attestation signs.
- **Breaking:** `copier-update.yml` pushes with a token from your own GitHub App, which `actions/create-github-app-token` mints for each run: it lasts an hour, reaches only this repo with Contents, Pull requests and Workflows write, and is revoked when the job ends. It replaces the `COPIER_UPDATE_TOKEN` personal access token, which lasted until it expired and which any workflow on any branch could read. The App's key is a secret of the `copier-update` environment, which `just repo-settings` creates and limits to `main` ([The update App](docs/updates.md#the-update-app)).
- `copier-update.yml` pushes through gh's credential helper (`gh auth setup-git`), and `preview-retire.sh` sends the Cloudflare token from a header file, so neither token appears on a command line, where other processes on the runner could read it.
- `python-release.yml` attests with `actions/attest` (with `artifact-metadata: write`) in place of `actions/attest-build-provenance`, and attaches a CycloneDX SBOM (`uv export --format cyclonedx1.5 --no-dev`, attested against the sdist) and a `<asset>.intoto.jsonl` bundle for every asset, the name Scorecard's Signed-Releases check scores highest. The release job runs `gh attestation verify` on each asset before it creates the draft, so a failed check leaves no draft behind. uv marks the CycloneDX export as preview.
- `docker.yml` attests the image with `actions/attest` and `artifact-metadata: write` too.
- A `site=plain` page on a Cloudflare Worker (`site_host=cloudflare`) ships `site/_headers`: the page's Content-Security-Policy plus `frame-ancestors 'none'`, `X-Frame-Options`, `X-Content-Type-Options: nosniff`, HSTS and the web app's other security headers. It had none, and a meta tag cannot set `frame-ancestors`. The update adds the file; keep it in step with the CSP in `site/index.html`.
- **Breaking:** `release.yml`, `python-release.yml`, `ts-release.yml`, and `docker.yml` on a tag publish only a tag signed with an SSH key in `.github/allowed_signers`, read from the default branch so a tag cannot bring its own key. Before, they accepted any tag GitHub marked Verified, which a key registered to any GitHub account passes, and `docker.yml` checked no signature at all. `tag-release.sh` runs the same check, `.github/scripts/verify-tag.sh`, before it pushes, and deletes a tag it made that fails ([Signed release tags](docs/setup.md#signed-release-tags)).
- `site=plain` renders a working tool page in place of the empty starter: a compact header with the job, an input and its result with one Copy result action, Settings and Use it elsewhere disclosures, and a footer with a privacy line that the page's Content-Security-Policy keeps true. The stand-in job formats JSON; replace `convert()` in `site/main.mjs`. An existing site keeps its own files ([The plain tool page](docs/hosting.md#the-plain-tool-page)).
- `.editorconfig` sets a 2-space indent for `*.sh`, matching the scripts the template ships.
- A web app's `vitest.config.ts` also runs `worker/**/*.test.ts`.
- The `docker_stacks` question is now a yes/no `docker_image`: build the Python package into an image. It is asked only when `stacks` has both `docker` and `python`, and defaults to yes. `app_port` and `publish_to_ghcr` are not asked without an image.
- With `codspeed`, `benchmarks.yml` runs on pull requests that touch benchmarked code only: the stack's source, tests or benches, its manifest, lockfile and `.python-version`, or the workflow. A flat layout watches the package at the root. Pushes to `main` still run every time, so CodSpeed always has a recent main result to compare with. [CI baseline](docs/ci-baseline.md#path-filters) has the stance on path filters.
- `AGENTS.md` says `just check` runs the stack checks CI runs, so a miss is caught there too.
- Web apps: the e2e job starts beside `check` instead of after it. A small `playwright` job reads the locked Playwright version for the container tag, which `check` used to output.
- Web apps and sites on Cloudflare: the README's deploy setup warns that one Cloudflare token in both environments lets any pushed branch deploy over production, and links the fix in the usage guide.
- Renovate extends `config:best-practices` in place of `config:recommended`, without its `:pinDevDependencies` (the lockfile already pins them) and its 3-day npm wait (the config waits 7 days). New presets in it reach projects with the next Renovate release.
- `copier-update.yml` updates every `.copier-answers*.yml`, one template after another, so a template layered over this one (such as an organisation's own) lands in the same pull request. Its title names each template that moved.
- The shell lint and `just docker-fmt` skip files marked `linguist-vendored` in `.gitattributes`, so a vendored script keeps its upstream style.
- The message at the end of `copier copy` mentions lockfiles only when the project has
  them, and the package version only when it publishes to PyPI or npm. It ends by saying
  that `copier update` pulls in new template releases.
- Every `taiki-e/install-action` step sets `fallback: none`, so a tool past the action's manifest fails the step instead of installing an unchecked binary through cargo-binstall. The `cargo-codspeed` step in `benchmarks.yml` keeps the fallback: the manifest does not list it.

### Fixed

- `python-release.yml`'s SBOM lists the dependencies of every extra too. Before, a package whose runtime needs live in extras shipped an SBOM with no components.
- For a web app that publishes to PyPI, `python-release.yml` refuses a tag that differs from `package.json`, as `release.yml` already does.
- A sample file you deleted stays deleted on `copier update`: the package's `__init__.py` and `tests/test_add.py`, the web app's `App.tsx`, `App.test.tsx`, `main.tsx`, `app.css` and Worker script, the plain site's page, the example site Worker, and the Astro starter pages `site/src/pages/index.astro` and `about.md`. Before, an update that changed one could bring it back, and it conflicted on the sample `__init__.py` when the pages were gone. A file the project owns, such as `README.md`, a decision record or a legal page, comes back if you delete it. A feature you turn on later with `copier update --data` does not get its samples.
- A web app or a site on a Worker ignores `.dev.vars*`, where wrangler reads local secrets, so `git add .` no longer stages them with only the betterleaks hook in the way. A site on a Worker without a web app now ignores wrangler's `.wrangler/` state too.
- `.gitignore` lists `*.pem`, `*.key` and `.npmrc` under its secrets. The template keeps pnpm settings in `pnpm-workspace.yaml`, so a project `.npmrc` would hold only a registry token. A file you already track stays tracked.
- `.gitignore` lists `.rumdl_cache/`. A cache that an older rumdl wrote has no ignore file of its own, so Biome formatted its JSON and `pnpm check` failed after `just hooks`.
- Web apps: a new `lychee.toml` sets lychee's `root_dir` to the Vite `public/` directory, so the lychee hook and the weekly `links.yml` resolve root-relative links such as `/favicon.svg` or `/manifest.json` there, in place of failing on them with "Cannot resolve root-relative link". A missing asset still fails.
- The typos hook skips gettext `.po` files and anything in a `locales/` directory. typos knows English only, and rewrote valid French, German, Italian and Dutch in translation catalogs. List other files with text in other languages under `[files] extend-exclude` in `_typos.toml`.
- Web apps: the first `just release X.Y.Z` sets the version in `package.json` and commits it with `CHANGELOG.md`; it used to commit the changelog alone. The tag run refuses a `package.json` on `origin/main` at another version before it signs, and `release.yml` refuses such a tag before it publishes.
- Web apps: `tests/e2e/privacy.spec.ts` checks browser storage against an `ALLOWED` list of names (local and session storage keys, IndexedDB databases, caches and service worker scopes), empty as rendered. An app with `user_data=browser` lists what a first visit keeps, such as its settings key or its offline cache, where the spec used to refuse any storage at all. A cookie, an unlisted name and a request to an unlisted origin still fail. The file is the template's, so `copier update` brings the change.
- `copier update` in a project that deleted a file the template renders no longer conflicts the web app's own starter files and pages (`PRODUCT.md`, `DESIGN.md`, `src/main.tsx`, `index.html`, `docs/privacy.md` and the rest) or a root `go.mod` with the template's. In that case copier 9.19.1 reads the skip list before the answers, and every entry with `ts_dir` or `go_dir` in it missed. A package in a subdirectory still gets the conflicts: keep your side of each. The same limit applies to files the project owns: a Compose-only repo's `compose.yaml` and `.env.example`, and owned files under `ts_dir` or `go_dir`, can still merge and conflict once a template file is deleted ([Keeping your project up to date](docs/updates.md#keeping-your-project-up-to-date)).
- A new web app with no `project_description` no longer fails `just hooks` on its first run: `PRODUCT.md` left three blank lines where the description goes, which rumdl rewrote. `copier update` leaves an existing `PRODUCT.md` alone; delete the extra blank lines by hand.
- Data pipelines no longer ship `data/processed/.gitkeep`, which `just validate` refuses from sourceledger 0.4.0 on ("no source '.gitkeep' in sources.toml"). `copier update` deletes it.
- `site=astro`: a `"` in `project_description` ended the layout's quoted `content` attribute and failed `astro build`. The layout now passes the description as an expression.
- CONTRIBUTING describes the two lines of the pull request template, `Tested:` and `Not checked:`, not the three it used to ask for.
- `property.yml` mentions Go's `FuzzAdd` only in a project with the Go library.
- A comment of several lines above a recipe showed only its last line in `just --list`. Each recipe now has one summary line directly above it, and the detail sits behind a blank line (`hooks`, `citation`, `py-mutation`, `py-property` and the other recipes that had a block).
- `just py-check` runs `uv run --locked`, so a stale `uv.lock` fails locally the way CI's `uv sync --locked` does, in place of being rewritten.
- The citesync hook's Python dependencies (`packaging`, `ruamel-yaml`, `tomlkit`) are pinned exactly in `additional_dependencies`, so the dependency bot can bump them.
- `just/mutation_diff.py` prints `skipped (decorated): <name>` to stderr for each changed function mutmut leaves alone for its decorator.
- CONTRIBUTING links the README without the `#development` anchor, which a project's own README may not have.
- With a GitHub noreply `author_email`, SECURITY.md offers only the private advisory and the code of conduct only GitHub's abuse report: that address gets no mail.
- Files name only the stacks a project has: the `.gitignore` sections, the justfile's imports and recipe prefixes, the `uv` and `pnpm` remarks in the hook and YAML configs, the lockfile steps in the copier-update PR body, the SKIP list in `checks.yml`, and the NumPy words in `_typos.toml`. `just repo-settings` names the dependency bot the project uses.
- AGENTS.md no longer points at a README release section or a `docs/decisions/` folder the render does not have. SECURITY.md, CONTRIBUTING and the bug form ask for the release or commit, which works before the first release.
- A Preact web app's `biome.json` turns on `noDangerouslySetInnerHtml`, which Biome enables
  only with React. The suppression in `src/App.tsx` now has an effect, and `just check` no
  longer warns about it on a fresh render.
- A data-pipeline at the repo root ends `python.yml` on a `run: |-` block, so yamlfmt no
  longer rewrites it and a fresh render passes its own `prek run --all-files`.
- `preview-retire.yml` writes its matrix entries as `{slug: ..., group: ...}`, the way yamlfmt
  spaces flow mappings, so a web app or a site passes its own `prek run --all-files` on a
  fresh render.

### Removed

- The TypeScript image: the Node `Dockerfile`, `.dockerignore`, `src/main.ts` health stub and compose service. With `docker` but not `python` in `stacks`, the render is a Compose-only repo. No render used the ts image, and the web-app kind deploys to Cloudflare Workers without one.

### Security

- `uvx` in `copier-update.yml`, `pr-title.yml` and `python.yml`'s griffe step resolves only releases at least a week old (`--exclude-newer "1 week"`), like every other install.
- With Rust and Renovate, the weekly Cargo lockfile refresh waits for review instead of merging itself: Cargo has no release-age cutoff.

## [0.13.0] - 2026-11-04

Upgrade steps:

- When moving a web app from Pages to Workers, delete any `public/_redirects` rule with status `200!`. Workers refuses it with error `100324`.
- **Breaking:** in a web app, add `export const LEGAL_LINKED_FROM: readonly string[] = [...ROUTES];` to `tests/e2e/routes.ts` to keep the old legal-page check, or list only the routes that link the legal pages.
- **Breaking:** in a web app, merge the `copier update`, run `pnpm install` and commit `pnpm-lock.yaml` (the update adds wrangler as a devDependency, and CI installs with `--frozen-lockfile`). Run `just repo-settings` and add `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` to the `production` environment. Once the Worker is live, move the custom domain to it and delete the Pages project ([steps](docs/hosting.md#moving-an-app-off-cloudflare-pages)). Without a custom domain, change the `site_url` answer to the workers.dev address: `copier update --data site_url=https://<slug>.<subdomain>.workers.dev`. Then fix the lines that still name Pages in files the update leaves alone: `docs/privacy.md`, the README's deploy section and the comment in `src/App.tsx`.
- **Breaking:** in a web app, move any hand tests in `docs/accessibility.md` under "How we check" and delete the "Tested with" heading, or the statement test fails.
- **Breaking:** with the mutation extra, run `just py-mutation` and list each survivor you accept in `tests/mutation-baseline.txt`, with its reason.
- **Breaking:** to keep your `docs/decisions/README.md` or `docs/decisions/0000-template.md`, run `git checkout HEAD -- docs/decisions/README.md docs/decisions/0000-template.md` before you commit the update.
- **Breaking:** to keep `cold-install.yml`, run `copier update --data cold_install=true`.
- **Breaking:** delete `.github/scripts/citation.py` if it is still there, then run `prek run citesync --all-files` and fix what it reports. A TypeScript, Rust or Go library that gets the citation files for the first time needs the same run.
- **Breaking:** in a research or data-pipeline project, the update licenses `data/` under CC-BY-4.0 or CC0-1.0 instead of the code license. To keep the code license there, run `copier update --data data_license=none`.
- **Breaking:** delete `.zenodo.json` unless you added to it what `CITATION.cff` cannot hold, such as contributors, related records, communities or grants.
- **Breaking:** with `license` set to `none`, `copier update` deletes `CITATION.cff` and `codemeta.json`. To keep them, run `git checkout HEAD -- CITATION.cff codemeta.json` before you commit the update.
- **Breaking:** in a public repo, run `prek install`, then commit with `-s`: the `dco-signoff` hook refuses an unsigned commit.
- In a public repo, run `just repo-settings` after the update, so `main` also requires the checks of each stack at the repo root, and the site build when the project has a site.

### Added

- `site` question for any project (default `none`). `site=plain` adds a static page in `site/` and `site=astro` a small Astro site there, with a `just site` recipe and `site.yml`, which deploys the page to GitHub Pages from `main` and gives each open, ready pull request a preview Worker, `<slug>-site-pr-<number>`. The previews reuse the web app's deploy and retire scripts ([Static site](docs/hosting.md#static-site)).
- `python_api` question for Python libraries (default yes). A package used only through its command line answers no, with `copier update --data python_api=false`, and gets no `api` job in `python.yml`.
- A web app gets `PRODUCT.md` and `DESIGN.md` stubs in its folder to fill in. They are yours once rendered: `copier update` does not rewrite them.
- `just ts-shots` in web apps: full-page screenshots of every route at 390 and 1440 px, light and dark, saved to the gitignored `shots/`.
- The pull request template ends with `Tested:` (the command and its result, or a test that fails without the change) and `Not checked:` (what did not run, and what only a person can judge).
- A web app's bug form asks for the page URL and the browser, and no longer formats the steps as shell. Other projects keep the command-line form.
- `just py-mutation-diff`, `rs-mutation-diff` and `go-mutation-diff` run only the mutants of the code changed since the branch left `origin/main`. See [Test extras](docs/usage.md#test-extras).
- `just py-mutation` takes mutmut patterns to run only those mutants, and now shows mutmut's output, so a failing run says why.
- Web apps get a preview Worker for each open, ready pull request, deleted again when the pull request closes, merges or turns draft. See [Pull request previews](docs/hosting.md#pull-request-previews).
- `just release X.Y.Z` runs twice. The first run cuts `[Unreleased]` in `CHANGELOG.md` into the new version and commits it; merge that to `main`. The second run, on an up-to-date `main`, signs and pushes the tag. See [Publishing](docs/setup.md#publishing).
- The PyPI and npm release workflows refuse a tag that differs from the package version.
- Every release workflow refuses a lightweight tag or one GitHub cannot verify, before anything builds or publishes, so only a tag signed by `just release` publishes.
- `advisories.yml` runs zizmor over the workflows every Monday, so a newly known-bad action fails without a commit here.
- A project that publishes to PyPI gets classifiers, `keywords` and a `Changelog` URL in `pyproject.toml`.
- `copier copy` ends with how to release: `just release X.Y.Z`, the signing key it needs and where to set the version.
- Projects with a license follow the [REUSE spec](https://reuse.software): `REUSE.toml` and `LICENSES/` cover every file, and a `reuse` git hook fails on a file they don't. See [Licenses](docs/usage.md#licenses).
- Research and data-pipeline projects ask `data_license` for what they commit under `data/`: CC-BY-4.0 by default for research, CC0-1.0 for a pipeline. Until now data took the code license.
- [docs/usage.md](docs/usage.md#licenses) says which code license to pick.
- TypeScript, Rust and Go libraries get the citation files too, as Python libraries already did. `codemeta.json`'s `programmingLanguage` names your stacks instead of always saying Python.
- A `profiling` option for the Python and Rust stacks, off by default, adds `just py-profile`, `just rs-profile` and `just rs-counters`. See [Profiling](docs/usage.md#profiling).
- With publishing on, `just repo-settings` creates the PyPI, npm and GHCR environments with you as required reviewer. On a public repo it also turns on CodeQL default setup and prints the PyPI pending-publisher and Zenodo URLs.
- A Python web service's `compose.yaml` sets `OTEL_RESOURCE_ATTRIBUTES` to `project=<slug>,env=dev` unless you set it, so a monitoring hub can tell projects apart. See [Python kinds](docs/python-kinds.md#web-service).
- Python libraries get `just py-matrix`, which runs the tests on every Python version `python.yml` covers.
- The justfile imports `just/local.just` when it exists, so a project can keep its own recipes there, out of the way of `copier update`. They show in `just --list`.
- The README installs the `prek` version the checks workflow runs, and the justfile says why `just hooks` can fail where CI passes.

### Changed

- With `codecov`, the patch check now fails a pull request when tests cover under 90% of its new and changed lines, and total coverage is shown but no longer enforced.
- Dependabot and Renovate wait one week for every update, majors included; majors used to wait a month ([dependencies](docs/tooling.md#dependencies)).
- The setup docs show how to turn on the repo setting that refuses actions not pinned to a full commit SHA ([protecting main](docs/setup.md#protecting-main)).
- `just release` signs and pushes the tag with `.github/scripts/tag-release.sh X.Y.Z`, which `copier update` adds. The checks are the same. You can run the script on its own.
- A web app's production and preview jobs call one script, `.github/scripts/deploy-worker.sh`, for the deploy steps they shared. Nothing about what they deploy changes. Existing apps get the script with `copier update`.
- A web app pins wrangler as an exact devDependency, and the production and preview jobs run that copy instead of `pnpm dlx`, so Renovate bumps it and the lockfile records it. See [Production](docs/hosting.md#hosting-on-a-worker).
- In a public repo, `main-checks.json` also requires the check job of each stack at the repo root (`python: lint, types, tests`, `python: lint, types, pipeline, tests` for a data pipeline, or one `python: lint, types, tests (3.x)` per version for a library, `ts: lint, types, tests`, `fmt, clippy, tests, deny`, `golangci-lint, tests, govulncheck`), so a failing test blocks the merge. Run `just repo-settings` after the update. Nested stacks are left out: their workflow runs only when their folder changes.
- The bundle budget's comment in `scripts/checkBundleBudget.mjs` says to keep it at least 25% above the build, so a small feature doesn't trip it. The limit itself is unchanged. Existing apps get the comment with `copier update`; check your own limit against it.
- **Breaking:** a web app's legal pages no longer have to be linked from a footer on every route. `tests/e2e/legal-pages.spec.ts` checks the routes in a `LEGAL_LINKED_FROM` export from `tests/e2e/routes.ts`, and each page must link back to `/`, since an installed app has no back button. `routes.ts` is yours, so `copier update` doesn't add the export. The spec fails while the list is empty. See [Legal pages](docs/usage.md#legal-pages).
- **Breaking:** A web app's production moves from Cloudflare Pages to a Cloudflare Worker that serves the build as static assets. Pages built a preview of every branch push, and those previews could not be deleted. A new `production` job in `ts.yml` deploys the build the checks ran on at each push to `main`, through a `production` GitHub environment that only `main` can deploy to. `wrangler.jsonc` is now the Worker's config for production and previews, and `wrangler.preview.jsonc` is gone. `site_url` defaults to `https://<slug>.<github_user>.workers.dev`. See [Moving an app off Cloudflare Pages](docs/hosting.md#moving-an-app-off-cloudflare-pages).
- **Breaking:** `just py-mutation` now fails on a surviving mutant that is not listed in `tests/mutation-baseline.txt`, and on a listed one that no longer survives, so the weekly `mutation.yml` python job can fail. See [Test extras](docs/usage.md#test-extras).
- **Breaking:** the accessibility statement has no "Tested with" section any more, and its test fails while the heading is still there. Hand tests go under "How we check".
- **Breaking:** new projects no longer get `docs/decisions/`, and `copier update` deletes its `README.md` and `0000-template.md`. Your numbered records stay.
- **Breaking:** `cold-install.yml` is now opt-in through the `cold_install` question, off by default. See [CI baseline](docs/ci-baseline.md).
- **Breaking:** [citesync](https://github.com/simonvanlierde/citesync) replaces `.github/scripts/citation.py`, and its git hook also checks the package manifests against `CITATION.cff`. `just citation --check` is gone: the hook does the check.
- **Breaking:** no more `.zenodo.json`: Zenodo reads `CITATION.cff` when a repo has none. A project with `license` set to `none` gets no citation files, since a Zenodo record needs a license.
- **Breaking:** the `dco-signoff` commit-msg hook and the web sign-off setting now come with every public render, not only with `openssf_badge=silver` ([CI baseline](docs/ci-baseline.md)).
- A web app's end-to-end tests no longer fail on TODOs in the legal pages or on an accessibility statement last reviewed over 400 days ago, so a new web app passes CI as rendered ([docs/web-legal.md](docs/web-legal.md)).
- A README of a project that publishes to PyPI or npm links to repository files by full GitHub URL, so the links work on the package page.
- The README no longer has a "Releasing" section or the note on the week-old-release rule; public projects get both in `CONTRIBUTING.md`. After `copier update`, delete them from the README if you don't want them twice.
- `just repo-settings` updates existing rulesets in place, found by name or else by the refs they protect, without creating duplicates.
- A web app's privacy and accessibility statements are rewritten in plain language. New apps get the new pages; `copier update` leaves existing ones alone, because `_skip_if_exists` lists them. [docs/web-legal.md](docs/web-legal.md) says how to write them, with an example.
- `cold-install.yml` also runs when `pyproject.toml`, `uv.lock` or `.python-version` change, so a lockfile that breaks first setup fails on the pull request.
- In Python projects, the whitespace, end-of-file and notebook hooks leave `tests/fixtures/` alone, as they already did `data/`.

### Removed

- The `status` question is gone. New READMEs say "Status: experimental"; edit the line by hand when the project moves on.

### Fixed

- `typos` no longer rewrites NumPy's `flags.writeable` and `flags["WRITEABLE"]` to `writable`. Projects get a `_typos.toml` that accepts both; `copier update` leaves an existing `_typos.toml` alone, so add `writeable = "writeable"` and `WRITEABLE = "WRITEABLE"` under `[default.extend-words]` there yourself. typos reads only the first config file it finds, and `_typos.toml` comes first: if your words are in `.typos.toml`, `typos.toml` or a `[tool.typos]` table in `pyproject.toml` or `Cargo.toml`, move them into `_typos.toml` and delete the old table.
- A template update PR opened without `COPIER_UPDATE_TOKEN` says in its body that its checks do not start and that closing and reopening it runs them.
- A GPL or AGPL project now stores `copyright_year`, so `REUSE.toml` keeps its year instead of taking the current one on each update.
- yamlfmt no longer reformats a `pnpm-lock.yaml` in a nested package, such as `web/pnpm-lock.yaml`.
- The mutation extra needs mutmut 3.8.1: 3.8.0 crashes under pytest 9.2.
- Release notes keep named Markdown link definitions, including definitions at the end of a section. See [Publishing](docs/setup.md#publishing).
- The Copier update workflow selects stable template tags and skips prereleases. See [Dependency updates](docs/updates.md#dependency-updates).
- `just repo-settings` turns on GitHub's "Automatically delete head branches", so a merged PR's branch goes away.
- A deleted `tests/test_add.py` no longer comes back on `copier update`, and the update keeps your package's `__init__.py`.
- A web app's markdown plugin strips HTML comments until none are left: one pass over `<!<!---->---->` left a comment behind. CodeQL flagged this in every rendered web app.
- A project description with a `\` is refused. It went into the package docstring, where an escape such as `\x` is a syntax error.
- A project description with `{{` no longer breaks the justfile. just read it as a variable, so no recipe ran.
- A project name ending in `.`, `-` or `_` no longer leaves it on the package, image and Worker names: `app.` made `app-`, and `https://app-.example-org.workers.dev` is not a valid address.
- A project name with `~`, or with `_` at the start or end of a word (`a _b_`), is refused: Markdown read it as strikethrough or emphasis. `_` inside a word, as in `my_app`, is still fine.
- A package directory with `//`, such as `apps//web`, is refused. It counted as one level too many, so `biome.json` pointed above the repo.
- A private or unlicensed project given `openssf_badge=silver` no longer gets the sign-off hook, the `web_commit_signoff_required` setting or the silver DCO wording. A private project had the hook with no `dco` workflow behind it.
- The image labels in a Dockerfile show the description and name as written: `Café` showed as `Caf\u00e9`, and `$USD` expanded to nothing.
- The sign-off instructions in CONTRIBUTING and the `dco` failure message give `origin/main` as the base, which a fresh clone has, and say to use `git push --force-with-lease` on a branch you already pushed.

### Security

- `fair.yml` runs howfairis from a pinned commit instead of its `0.15.0` tag, which can be moved, and resolves howfairis' dependencies only to releases at least a week old.

## [0.12.0] - 2026-10-29

Upgrade steps:

- **Breaking:** in a `library`, `research` or `data-pipeline` project, run `just citation` after the update and commit what it writes. Until you do, the new `citation` hook fails, in CI too. Add `email:` to the authors in `CITATION.cff` first, or `codemeta.json` loses the email it has.
- With `openssf_badge=silver`: from this update on, sign off your own commits too (`git commit -s`, or `git rebase --signoff origin/main` for a branch you already have). Run `prek install` again so the new commit-msg hook is active.
- If your README.md has the three-dot fair-software.eu badge and `fair.yml` scores under five of five, delete the badge line by hand. `copier update` never changes README.md.

### Changed

- New citable public projects no longer get a fair-software.eu badge at three of five dots. Add it once `fair.yml` scores five of five: set `FAIR_MIN: 5` and paste the snippet howfairis prints in the job summary.
- **Breaking** for `openssf_badge=silver`: the `dco` check runs on every pull request, the maintainers' branches included, as the silver badge's DCO criterion asks of every developer. A commit-msg hook refuses an unsigned commit before the push. Commits Dependabot or Renovate write in their own pull requests are exempt; a human commit on a bot's branch is still checked. The commit-msg hook accepts only a full `Signed-off-by: Name <email>` line, as the check does. `just repo-settings` also turns on GitHub's "require contributors to sign off on web-based commits", so a commit made in the web UI, such as "Commit suggestion", passes the check. Below silver, only pull requests from forks are checked, as before.
- The copier-update workflow signs off its commit.
- Pull requests restore the CI caches main saved and save none of their own, in every workflow that caches: uv, Rust, the pnpm store, Go, the git hook environments and trivy's database. GitHub lets only the pull request read a cache it saves, and a repo holds 10 GB of caches before it evicts the oldest, so those caches pushed out main's and new pull requests built cold. The `pr title` workflow, which runs on pull requests only, no longer caches uv.
- `codemeta.json` declares CodeMeta 3.0 instead of 4.0, because Software Heritage's indexer reads only 2.0 and 3.0 and skipped the file. The fields are the same in both.
- JSON files are checked by [jsonvet](https://github.com/simonvanlierde/jsonvet) 3.2.0, the new name of check-json5, in every project, not only TypeScript ones: `.vscode/` and `.github/rulesets/` JSON ship with every stack. It reads `.json` files as JSON5, so comments and trailing commas still pass, and fails on syntax errors and duplicate keys.

### Fixed

- The generated README had two blank lines before "Before the first release" (or before "License" in a project that publishes nothing), so the Markdown linter rewrote it on the first commit.
- `fair.yml` called GitHub's API anonymously, so on a runner whose IP had used up its 60 requests an hour, howfairis scored checks as missing without an error. It now passes the job's token as `APIKEY_GITHUB`.
- `fair.yml` scored the checklist as missing on every repo with an OpenSSF Best Practices badge, because the howfairis on PyPI (0.14.2) predates the `www.bestpractices.dev` badge URL. It now runs howfairis 0.15.0 from its GitHub tag, which reads that URL; PyPI has no 0.15.0 yet.
- `biome check` failed on every new TypeScript project with biome 2.6, which formats Markdown and YAML too. `biome.json` now leaves those files to rumdl and yamlfmt.
- `just repo-settings` in a public Renovate repo stopped with a bare "Validation Failed" when the Renovate app was not installed yet, because GitHub refuses an app it can't see as a bypass actor. It now shows GitHub's reason and says to install the app first.

### Added

- `just citation` writes `.zenodo.json` and `codemeta.json` from `CITATION.cff`, so you edit one file instead of three: title, description, authors with their ORCID iD, email and affiliation, licence and repository into both, and version, release date and DOI into `codemeta.json` only. Zenodo takes the version and date from the release, and would take a DOI for the release's own and mint none. Other top-level fields you add to the JSON files stay; the author lists are rewritten whole. A name particle such as `van` is kept in front of the family name. A git hook, which CI also runs, fails while the files disagree, and `just citation --check` runs the same check by hand.
- [docs/setup.md](docs/setup.md#making-a-repo-public) has a checklist for making a private repo public: a secret scan over the full history, the name on PyPI, crates.io and npm, a clean issue list and the README status sentence.
- A Rust or Go `binary` and a Python `data-pipeline` get `docs/accessibility.md`: how the program prints (colour is never the only signal, `NO_COLOR` and `--color never` are honoured, plain output off a terminal, errors as `file:line:col` on standard error) and the author's email for problems. Check each claim holds for your program before you publish it. An existing project gets the file on `copier update` and keeps its own edits after that.
- A public repo's `CONTRIBUTING.md` has a "Scope and response" section: one maintainer, a reply within about two weeks, an issue before a large pull request, and out-of-scope pull requests closed with a link to it.
- A new `status` question (`experimental`, the default, `stable`, `maintenance` or `archived`, under `customise`) puts one status sentence under the README's badges. A public repo's README also says where questions and bugs go. An existing project's README is its own, so `copier update` adds neither: copy them from a fresh render.
- A public repo gets issue forms in `.github/ISSUE_TEMPLATE/`: one for bugs and one for feature requests. Blank issues are turned off, and a link sends questions to `CONTRIBUTING.md`. Vulnerabilities go to private reporting, as before. A private repo gets none.
- The template itself has a Zenodo DOI, [10.5281/zenodo.23701980](https://doi.org/10.5281/zenodo.23701980), which always points to the newest release. `CITATION.cff` and the README carry it.

## [0.11.0] - 2026-10-27

Upgrade steps:

- With `publish_to_pypi`: push the version tag and approve `pypi`; let `python-release.yml`
  create the GitHub release. It replaces `release.yml` and attaches the distributions
  and their provenance before publishing. Do not create the GitHub release by hand.
  If PyPI succeeds but the release job fails, delete any leftover draft and re-run
  only the `release` job ([recovery steps](docs/setup.md#publishing)).
- **Breaking:** install Copier 9.19 or later (`uv tool upgrade copier`) before you run
  `copier update`. Renovate's copier manager installs the latest Copier.
- **Breaking:** a web app made from an untagged main asks the new `user_data` question,
  which has no default, so `copier update --defaults` stops on it. Answer it, or pass it:
  `copier update --data user_data=nothing` (or `browser`, or `accounts`). Then add the
  footer and the page routing from a fresh render's `src/App.tsx` to yours, and
  `/accessibility` and `/privacy` (and `/terms`) to `tests/e2e/routes.ts`: an update
  leaves both files alone. Fill in the TODOs in `docs/`. An app on its own domain: pass
  `--data site_url=https://<your domain>`, or the pages name the `pages.dev` address.
  The weekly copier-update workflow fails until you have run this update by hand once.
- **Breaking:** a private repo: pass `--data public=false`. The new `public` question
  is yes by default, so `copier update --defaults`, Renovate's update PR and the
  `copier-update` workflow add the public-repo files, including a `scorecard.yml` that
  fails in a private repo. With no, `.github/SECURITY.md`, `CONTRIBUTING.md`,
  `CODE_OF_CONDUCT.md`, `pull_request_template.md`, `dco.yml` and `scorecard.yml` go.
  Your license answer stays as it is.
- A public repo: the update adds `.github/CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`,
  `pull_request_template.md` and a `dco` check on pull requests from forks,
  and `SECURITY.md` gains a Scope section to fill in. GitHub shows `.github/CONTRIBUTING.md`
  before a root `CONTRIBUTING.md`, so if you have your own, keep one and delete the other.
- With `dependency_bot=dependabot`: create a fine-grained token with read and write access
  to Contents, Pull requests and Workflows on the repo, and store it as the
  `COPIER_UPDATE_TOKEN` secret. Without it, the new weekly `copier-update` workflow opens
  an issue instead of a PR for an update that changes a workflow
  ([Hearing about new releases](docs/updates.md#hearing-about-new-releases)).
- `README.md`, `CHANGELOG.md` and the citation files (`CITATION.cff`, `.zenodo.json`,
  `codemeta.json`) are now your project's, and this update already leaves them alone. So
  this release's README changes don't arrive, such as the badges for the options you
  turned on and the Releasing section. Diff your README against a fresh render with your
  answers and copy the parts you want.
- **Breaking:** if a ruleset or branch protection requires the `lint, types, tests` check
  (`lint, types, pipeline, tests` in a `data-pipeline` project), switch it to the new
  name: `python: lint, types, tests` (`python: lint, types, pipeline, tests`) or
  `ts: lint, types, tests`. A library runs one per Python version, named
  `python: lint, types, tests (3.12)` and so on. Until then, pull requests wait on a
  check that never reports.
- Run `just repo-settings` once after the update, and in a new project after the first
  push. It protects `main` and the `v*` tags and, in a public repo, turns on private
  vulnerability reporting, which `SECURITY.md` points to. `main` then requires the `git hooks`,
  `pull request title`, `dependency review` and, in a public repo, `DCO sign-off` checks: if
  you renamed any of those jobs, edit `.github/rulesets/main.json` first (in a public repo,
  `main-checks.json`), or pull requests wait on a check that never reports. In a public
  repo, `main` also requires an approval from now on; as the repo admin you can merge your
  own pull requests by ticking the bypass box in the merge box.
- Run `prek install` again in each clone, so the new commit-msg hook is installed.
- The new `typos` and `lychee` hooks run on every file in CI's git hooks job. After the
  update, run `prek run --all-files typos lychee`, review what typos fixed, and fix the
  dead links lychee lists, or that job fails.
- After the update, refresh the lockfiles for your stacks and commit them: `uv lock`,
  `pnpm install`, `just go-sync`. This release bumps dev tools in every stack, and CI
  installs with `--locked` and `--frozen-lockfile`.
- A TypeScript library with `publish_to_npm`: after the update, run `just ts-api` and
  commit `<package>.api.md`. The template's copy describes the sample `add` function, not
  your exports, so CI fails until you do.
- With `dependency_bot=renovate`: turn Dependabot security updates off
  (`gh api -X DELETE repos/OWNER/REPO/automated-security-fixes`), or each security fix
  arrives as two PRs. Keep Dependabot alerts on: Renovate's security PRs need them.
- **Breaking:** in a Go library made with v0.10.0 or earlier, `copier update` deletes
  `<package>_test.go` without asking, your changes to it included, and adds
  `add_test.go`. Before you commit the update, run `git checkout HEAD -- <package>_test.go`
  (after committing it, `git checkout HEAD~1 -- <package>_test.go`). Then delete
  `add_test.go`, or the two `TestAdd` functions stop the tests compiling. With
  `test_extras=[property]`, first copy `FuzzAdd` from `add_test.go` into your test file.
- In a Python or TypeScript library, the new sample `add` function arrives as a conflict
  in `src/<module>/__init__.py` or `src/index.ts`: keep your own side. Then delete
  `tests/test_add.py`, and the `add` import and test the update merged into
  `src/index.test.ts`, or those tests fail.
- In a `data-pipeline` project (see the two Breaking changes below):
  - `src/<module>/pipeline.py` becomes a short file that imports sourceledger. If you
    added readers to `parse`, keep only your own branches, end it with
    `return sourceledger.parse_source(source, payload)`, and keep the imports your
    branches need: the new file no longer imports `csv` or `io`.
  - Take the new `tests/test_pipeline.py`, and keep any tests of your own readers.
  - `pyproject.toml` gains the `sourceledger` dependency. Keep any dependencies of your
    own next to it, where `copier update` can't merge the two lists.
  - In `sources.toml`, rename `release` to `vintage` (the old key still works, with a
    warning). Give each implemented source a `license` (an SPDX id, or
    `LicenseRef-<name>`) and `redistribute = true` or `false`. Rename any source id with
    a non-ASCII letter: only ASCII letters, digits, `_` and `-` are accepted.
  - Run `just pipeline`. `just validate` reports a missing `datapackage.json` until
    `just build` has written one.
- **Breaking:** `python-release.yml` and `ts-release.yml` now run when a `vX.Y.Z` tag is
  pushed, not when a GitHub release is published. Add the `## [X.Y.Z]` section to
  `CHANGELOG.md` before you tag. The release workflow reads that section and fails
  when it is missing. Releases created by `GITHUB_TOKEN` don't start other
  workflows, so the publish workflows could not follow the release.

### Added

- Weekly Go property runs cache generated fuzz inputs so each run resumes the
  coverage the previous runs found.
- Copier and howfairis workflow pins follow template updates. Renovate tracks their
  versions in the template, so they no longer need separate manual bumps.
- The code of conduct tells readers that a report about the maintainer can go to GitHub
  instead, through Report abuse.
- An `openssf_badge` question, asked in a public repo with a license, for the
  [OpenSSF Best Practices badge](https://www.bestpractices.dev). `passing` adds a test
  policy and each stack's coding standards to `.github/CONTRIBUTING.md`. `silver` also
  adds `GOVERNANCE.md`, `docs/roadmap.md` and `docs/assurance-case.md`, short skeletons
  you fill in and then own. It defaults to `none`, so an update changes nothing unless
  you pass `--data openssf_badge=passing` (or `silver`).
- A `cold-install.yml` workflow runs the shell blocks under the README's `## Development`
  heading as written, in a Debian container with only the tools the README says you
  need, so a setup step the README leaves out fails in CI. It runs weekly and on pull
  requests that change `README.md`. It skips `just up`, `just pipeline`, `just ts-e2e`
  and the mutation and property recipes, which need Docker, a browser, live sources or hours.
  Your README stays yours on `copier update`, so the job runs whatever it says now.
- Spelling and link checks. A `typos` git hook finds misspelt words and a `lychee` hook
  finds relative links to missing files in Markdown and HTML. The lychee hook runs
  offline, so a new weekly `links.yml` workflow checks the web links too. List a word
  typos must leave alone in `_typos.toml` ([Spelling and link checks](docs/tooling.md#spelling-and-link-checks)).
- A short `AGENTS.md` in every project, for coding agents: the `just check` command, each
  stack's test recipe and where the docs are. It names only recipes the project's
  `justfile` has.
- Commit message rules in `committed.toml`: Conventional Commits, an imperative summary,
  no period. A `committed` commit-msg hook checks each commit, skipping merge
  commits, and a new `pr-title.yml` workflow checks the pull request title, which a squash
  merge turns into the commit subject. Dependabot and Renovate now write PR titles in the
  same form, `chore(deps): ...`.
- GPL-3.0-or-later and AGPL-3.0-or-later as `license` answers, with
  the GNU texts in `LICENSE`. These texts have no copyright line, so they don't ask
  `copyright_year`.
- A `python_layout` question under `customise`, `src` by default. `flat` is for adopting
  the template in a repo whose package already sits at the root: it renders no
  `src/<module>` stub or `tests/test_add.py`, and sets `module-root = ""` for uv_build.
  [Adopting the template in an existing Python package](docs/updates.md#adopting-the-template-in-an-existing-python-package)
  covers the rest, including a ruff and ty baseline for code written without them.
- A `docs/decisions/` folder in every project, for recording why you chose what you
  did. It holds a short record template, `0000-template.md` (status, date, context,
  decision, consequences), and an index, `README.md`. The index is yours once written,
  so `copier update` leaves it alone.
- README badges for the options you turn on: Codecov coverage (`codecov`), CodSpeed
  (`codspeed`), PyPI version and supported Python versions (`publish_to_pypi`), npm version
  (`publish_to_npm`) and OpenSSF Scorecard (`public`).
- A weekly dependency audit, `advisories.yml`, on every Monday with a job per stack:
  `uv audit`, `pnpm audit`, `cargo deny check advisories` and `govulncheck`. Before, a repo
  with no new commits never heard of a new advisory. A failed run shows on the Actions page
  and in the failed-run email.
- With `public`, an OpenSSF Scorecard workflow (`scorecard.yml`): it runs on pushes to
  main, weekly and when branch protection changes, publishes the score for the README
  badge and uploads the findings to code scanning. A private repo gets none. After the
  update, the first run on main publishes the score.
- The release workflows and `.github/scripts/release-notes.sh`: a pushed `vX.Y.Z` tag becomes a
  GitHub release whose notes are that version's `CHANGELOG.md` section, so the two never
  differ.
- `just repo-settings` protects the default branch with a GitHub ruleset (no deletion, no force-push, linear history, PRs squash-merged once the checks every PR runs have passed) from `.github/rulesets/main.json`, lets only a repo admin create, move or delete a `v*` tag (`.github/rulesets/tags.json`), since pushing one publishes a release, and in a public repo turns on private vulnerability reporting, which `SECURITY.md` points to. Rerun it any time; it updates the ruleset instead of adding a second.
- `just repo-about` sets the GitHub About box from your answers with `gh repo edit`: the description from `project_description` (skipped when empty), the homepage from `site_url` in a web app, and a topic per stack. It only adds topics, so ones you set by hand stay. Rerun it any time.
- With `mutation` in `test_extras`, a weekly CI run of mutation testing:
  `.github/workflows/mutation.yml`, one job per library stack, also startable by hand
  and never run on a pull request. Each job runs the stack's `just <stack>-mutation`
  recipe. The Rust job fails when a mutant survives; the others print the survivors and
  pass.
- With `property` in `test_extras`, a weekly CI run of the property tests at length:
  `.github/workflows/property.yml`, one job per library stack, also startable by hand
  and never run on a pull request. Each job runs a new recipe you can also run by hand:
  `just py-property` (Hypothesis, 10,000 examples a property), `just ts-property`
  (fast-check, 10,000 runs), `just rs-property` (proptest, 10,000 cases) or
  `just go-property` (fuzzes `FuzzAdd` for 10 minutes). A failing input fails the job. A Python
  library gains `tests/conftest.py`, which registers the Hypothesis profile.
- A `public` question, yes by default. No leaves out `.github/SECURITY.md`,
  `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `pull_request_template.md` and `dco.yml`, and makes
  `none` the license default. See [Public repos](docs/setup.md#public-repos).
- `CONTRIBUTING.md` says where to report a bug, states the commit, pull request and
  changelog conventions, asks for a DCO sign-off on every commit and says who maintains the
  project. `CODE_OF_CONDUCT.md` is the Contributor Covenant 3.0, with the author email as
  the contact. A `dco.yml` workflow fails a pull request from a fork with a commit that isn't signed off.
- `SECURITY.md` says what to include in a report, promises an answer within 14 days, says
  how a fix is disclosed, and has a scope section to fill in.
- A `customise` question, no by default, ahead of the advanced questions: license,
  directories, versions, module names, Codecov, CodSpeed, the dependency bot,
  publishing, test extras, the port and the site URL. A new Python library, TypeScript web app or data pipeline now
  asks 10 questions, or 11 for a web app, down from 18, 14 and 15. Every question says what it changes.
  [The questions](docs/usage.md#the-questions) lists them with their defaults.
- `copier copy` says where your details can be saved before it asks, and lists the
  `just` commands to run after it.
- A `codspeed` option for the Python and Rust stacks: a `benchmarks.yml` workflow runs
  benchmarks on CodSpeed for every pull request and every push to main, with a starter
  benchmark per stack (`pytest-codspeed`, and divan through `codspeed-divan-compat`). Import
  the repository on codspeed.io and set Pull Request comments to "On Change" there; see
  [usage](docs/usage.md#benchmarks-on-codspeed).
- A `web-app` TypeScript kind: a Vite single-page app with React or Preact (the new
  `web_framework` question), deployed by Cloudflare Pages' Git integration. The docker
  stack builds no image for it, since it is static files.
  - Playwright specs run against the production build, in `ts.yml`'s `e2e` job and with
    `just ts-e2e`. They check every route with axe in light and dark mode (WCAG 2.2 AA
    and axe's best-practice rules) and at 320 px wide (reflow), and check that the app
    runs under the Content-Security-Policy in `public/_headers`, which allows no inline
    script. Removing any security header from that file fails the check.
  - `just check` and CI enforce a bundle budget, set in `scripts/checkBundleBudget.mjs`,
    and a pre-push hook runs the unit tests.
  - The e2e run always starts its own preview server, on port 4173, and fails if the
    port is taken, so it can't test another app's server instead.
  - [Adopting the template in an existing web app](docs/updates.md#adopting-the-template-in-an-existing-web-app)
    lists the files a first `copier copy --overwrite` adds or replaces, and how to
    install a lockfile resolved before the one-week release wait.
  - The starter files (`src/App.tsx`, `src/App.test.tsx`, `src/main.tsx`, `src/app.css`,
    `index.html` and `tests/e2e/routes.ts`) belong to the project once written:
    `copier update` never touches them again.
- A `test_extras` question for the library kinds, empty by default. `property` adds a
  property test of the sample `add` function: Hypothesis, fast-check, proptest, or a
  native Go `FuzzAdd`. `mutation` adds a `just <stack>-mutation` recipe to run by hand:
  mutmut, Stryker, cargo-mutants or gremlins. See [Test extras](docs/usage.md#test-extras).
  Python and TypeScript libraries now ship the sample `add`, as Rust and Go already did.
- With the `docker` stack, `docker.yml` scans each built image with Trivy for HIGH and
  CRITICAL vulnerabilities that have a fix, and rebuilds and scans the image every Monday
  without pushing it. Pull requests and pushes show the findings in the job log; only the
  weekly run fails on them. The job that pushes to GHCR runs no scan, so it reads no
  cache on a tag.
- In a `data-pipeline` project:
  - `data/fetches.jsonl` is committed and gets a line each time a source serves bytes it
    has not served before: the history of every version, as checksums, not values.
  - The weekly CI run comments on an open "Source data revised upstream" issue when a
    source in that file serves new bytes, with the old and new checksums. Only that job
    may write issues. `uv run <slug> revisions <older log>` prints the same list locally.
  - `just status` lists every source with its vintage, last fetch and licence, and
    `just attribution` prints the sources and their reuse terms as a Markdown table for
    `ATTRIBUTION.md`.
- `just fmt` runs each stack's fix-and-format recipe, the counterpart of `just check`.
- Dependabot groups npm security updates into one pull request instead of one per
  advisory.
- VS Code formats `.tsx`, `.jsx` and `.css` files with Biome, and the Biome hook also
  checks HTML.
- The README says how to lock a security fix that is less than a week old, which
  `exclude-newer` and `minimumReleaseAge` otherwise hold back.
- API-break checks for libraries that publish. With `publish_to_pypi`, a new `api` job
  in `python.yml` runs griffe, which fails when a public function, class or argument was
  removed or changed since the last git tag, and passes while there is no tag. It stays
  out of `just py-check`, so a deliberate break leaves local checks green. With `publish_to_npm`, `ts.yml` and `just ts-check` run API Extractor, which
  fails when the built types differ from the committed `<package>.api.md`. `just ts-api`
  rewrites that report after a deliberate change, so the change shows in review.
- A `web-app` has legal pages, linked from every page's footer: an accessibility
  statement at `/accessibility`, a privacy statement at `/privacy` and, with
  `user_data=accounts`, terms of use at `/terms`. Each is one Markdown file in `docs/`:
  GitHub shows it, and the build turns it into HTML. Its HTML comments are notes for you,
  and the build leaves them out. New e2e tests fail when a page still
  holds a TODO, when the statement says "fully conformant" or goes 400 days without a
  review, and when a first visit sets a cookie, stores anything in the browser or loads a
  file from another site. [`docs/web-legal.md`](https://github.com/simonvanlierde/project-templates/blob/main/docs/web-legal.md) in the template repository has tips for
  filling the pages in, linked from each page's notes ([Legal pages](docs/usage.md#legal-pages)).
- A `web-app` gets `docs/accessibility-assessment.md` beside the accessibility statement: a
  WCAG 2.2 self-assessment with one row for each of the 55 level A and AA criteria, and a
  result and an evidence column to fill in. The app does not serve it. The statement links
  it, and may say "partially conformant" only once every row has a result. An update
  leaves your copy alone.
- A public repo of a kind that has `CITATION.cff` (library, research, data-pipeline) gets
  `fair.yml`, which runs `howfairis` weekly and lists each fair-software.eu check in the job
  summary, and a fair-software.eu badge in the README. The job fails below `FAIR_MIN` filled
  dots out of five. A new repo has three, so that is the starting floor: raise it as you
  add a registry entry and the OpenSSF Best Practices badge, and edit the badge to match.
- With `dependency_bot: dependabot`, a `copier-update` workflow opens a weekly PR that
  runs `copier update` to the newest template tag, with conflicted files listed in the
  PR body. It pushes with a `COPIER_UPDATE_TOKEN` secret, a fine-grained token you create.
  Without one it uses `GITHUB_TOKEN`, which GitHub stops from pushing workflow changes, so
  such an update opens an issue asking you to run it locally, and other update PRs start
  no CI. See
  [Hearing about new releases](docs/updates.md#hearing-about-new-releases).

### Changed

- A public repo's `main` ruleset requires one approving review, given after the last push,
  and a new push dismisses an earlier one. That lifts Scorecard's branch protection score
  from at most 4 to 8. A repo admin can bypass the review from the merge box. The required
  checks move to a second ruleset, `main-checks`, which only an admin can bypass, so a
  bypass of the review still waits for them. Rerun `just repo-settings` after the update to
  apply both. A private repo's ruleset is unchanged.
- With `dependency_bot=renovate`, Renovate merges its own minor and patch updates of the
  packages CI installs, and the weekly relock, once their checks pass. Its app may bypass
  the review in a public repo, never the checks. Majors, copier template releases, and the
  actions and hooks group still wait for you. Dependabot PRs still never merge themselves.
- A web app with `user_data=accounts` refuses `code@duinlab.nl` as `author_email`: an app
  that keeps personal data on a server needs its own contact address. Pass another
  address to `copier update` if you hit this.
- `copier copy` keeps an existing `README.md`, and `copier update` no longer touches it.
  Template changes to the README, this release's included, reach existing projects only
  by hand.
- A ty rule set to `"warn"` reports without failing `ty check`, the hook and
  `just py-check`. ty exits 1 on warnings by default; `pyproject.toml` now sets
  `[tool.ty.terminal] error-on-warning = false`.
- In a Python project, the git hooks skip `data/`, so the whitespace, end-of-file and
  nbstripout hooks no longer rewrite input data and archived notebooks.
- `pnpm audit --fix=update` locks a security fix that is under a week old: it adds the
  patched version to `minimumReleaseAgeExclude`, and the new
  `minimumReleaseAgeExcludePrune` drops the entry once the lockfile moves past it.
- With `dependency_bot=renovate`, Renovate refreshes the lockfiles every Monday. That is
  how a security fix in a dependency of a dependency arrives, once it is a week old.
- **Breaking:** the TypeScript and Python check jobs are now `ts: lint, types, tests` and
  `python: lint, types, tests` (`python: lint, types, pipeline, tests` in a
  `data-pipeline` project). Both used to be `lint, types, tests`, so a ruleset could not
  require one without the other. A ruleset that requires the old name needs the new one
  (see the upgrade steps).
- With the `codecov` option, `just check` runs the TypeScript tests with coverage, as CI
  does, so a coverage threshold in the Vitest config fails locally as well as in CI.
- Dependabot and Renovate group minor and patch bumps of runtime dependencies into one
  weekly PR, instead of one PR each. A major still gets its own PR.
- GitHub Actions and pre-commit hook updates arrive as one weekly PR, instead of one
  each: a Dependabot multi-ecosystem group, and one Renovate group. Fewer PRs means fewer
  branches to bring up to date in turn where main requires it.
- With the `codecov` option, Codecov no longer comments on pull requests. Any line left
  untested drew a comment. A drop of over 2 points still fails the `codecov/project`
  check, which links to the report.
- **Breaking:** a `data-pipeline` project gets its fetch, build, validate and revisions
  stages from the [sourceledger](https://github.com/simonvanlierde/sourceledger)
  package instead of about 400 copied lines in `pipeline.py`. Fixes now arrive as a
  dependency bump, not a `copier update` merge. `pipeline.py` keeps only `parse`.
  - `parse` reads CSV, JSON and Excel sources, gzipped or not, by each source's `format`
    or its URL's extension. `just build` also writes a `datapackage.json`.
  - A fetch asks the server whether the file changed (`If-None-Match`,
    `If-Modified-Since`) and keeps the record on a 304, unless the raw file was edited or
    no longer matches its pinned `sha256`. It waits at most 2 minutes for a
    429's `Retry-After`, and a fetch that fails after its retries names the source and
    its URL.
  - The manifest names the edition `vintage`, as the fetch record and the output column
    already did. `sources.toml` has a schema line for editors, pinned to sourceledger
    v0.2.0, and its comments cover every key. The example source is pinned to a
    datasets/co2-ppm commit, so CI and the tripwire tests no longer follow a moving
    branch.
- **Breaking:** `just validate` in a `data-pipeline` project needs each implemented source
  to state `license` (an SPDX id) and `redistribute` (whether the raw file may be
  republished), beside `terms`. The free-text terms stay for people; these two are for a
  release step to check.
- `go.mod` is written once and then belongs to the project, like `CHANGELOG.md`. Before,
  every `copier update` conflicted with what `go mod tidy` had written there. To raise the
  minimum Go version, run `go mod edit -go=<version>`.
- `copier update` no longer touches `CITATION.cff`, `.zenodo.json` or `codemeta.json` once
  they exist, so a release that adds its version, date or DOI to them no longer conflicts
  with every update. Template changes to these files, this release's included, reach
  existing projects only by hand.
- Web-service projects test with `httpx2`, which Starlette's test client now prefers,
  instead of `httpx`, and require Starlette 1.2.0 or later. The pytest filter that hid
  Starlette's deprecation warning is gone.
- A new Python release becomes the default `python_version` 90 days after it comes out,
  once the packages projects install have wheels for it.
- The generated README lists the tools the project needs (uv only where it's used), puts
  `just hooks` next to `just check`, says that `just check` doesn't build the Docker
  image, and, with a publish option, has a Releasing section on setting up the publishing
  environment first.
- The workflow linter hook runs jactionlint, a maintained fork of actionlint. It adds
  checks for releases, caches and concurrency, so a workflow you wrote yourself may get new
  findings.
- A library's release workflow runs its wheel tests with the test tools from `uv.lock`,
  hash-checked, and turns on uv's malware check as `python.yml` does.
- `python-release.yml` and `ts-release.yml` run one release per tag at a time.
- The docker workflow cancels a superseded run only on a pull request, so a push to `main`
  or a tag is never stopped halfway through pushing an image. A tag build doesn't restore
  the shared build cache, so a poisoned cache entry can't reach a release image; release
  builds take longer as a result. When every image builds from a subdirectory, the
  workflow runs only when a build context or the workflow changes, so a required build
  check stays pending on a pull request that touches neither.
- The Docker image of a `data-pipeline` project is documented as a stub: it has no
  `sources.toml` or `data/`, and it starts the `/health` placeholder.
- Python projects accept `uv_build` 0.13 as their build backend. The 0.12.19 floor stays,
  so older uv versions still build them.
- With `dependency_bot: renovate`, Renovate's copier manager opens a PR for each new
  template release. Before, the one-week release age held those PRs back for good, because
  template tags carry no release date. The docs say how Dependabot users hear about
  releases.

### Fixed

- The typos hook skips `.copier-answers.yml`. The template commit id Copier writes there
  could spell a word typos rejects and fail the hook after a `copier update`.
- A project description with `"""`, `*/` or a line break is refused. It
  broke the Python docstring or the Go and TypeScript comments it lands in.
- With `dependency_bot: renovate`, the comments in `pyproject.toml`, `pnpm-workspace.yaml`
  and `.pre-commit-config.yaml` no longer say Dependabot waits the week or moves the hook
  SHAs.
- The README of a TypeScript project names Node.js among the tools you need.
- The weekly scheduled run and a push to `main` no longer cancel each other in
  `python.yml` and `docker.yml`. A cancelled weekly run used to skip that week's tripwire
  tests in a `data-pipeline` project.
- Copier refuses answers that rendered a broken project: a project name that is a Go,
  Rust or Python keyword (such as `type`, `gen` or `lambda`), an empty `stacks` list, an
  empty `*_dir`, a `rust_version` below 1.85 (the template uses edition 2024), and an
  `app_port` outside 1 to 65535, or 65535 when two images publish ports. A Go binary no
  longer needs a project name that can be a Go package name.
- The `check-yaml` hook no longer fails on `pnpm-lock.yaml`. pnpm 12 writes its own
  version into the lockfile as a second YAML document, so every TS project failed its
  `checks` workflow once the lockfile was committed.
- A name or email with a quote in it, such as `Ada "X" Lovelace`, no longer breaks the
  generated `pyproject.toml`, `package.json` or `Cargo.toml`. A leading space in the
  author name no longer leaves the given name empty in the citation files.
- The `ts` and stdlib Python starter servers in the Docker image stop on SIGTERM. As PID 1
  they ignored it, so `docker stop` waited 10 seconds and then killed them.
- A Go library named `example` no longer loses its `TestAdd`: the unit test is now
  `add_test.go`, which can't share a path with `example_test.go`.
- The image `.dockerignore` files match `.env`, `.venv` and `node_modules` in any
  directory, so another stack's secrets stay out of the build context when a package sits
  at the repo root.
- `.gitignore` names a Go binary without a trailing major version, as `go build` does for
  a module path ending in `/v2`.
- With a Rust crate below the repo root, `.vscode/settings.json` sets
  `rust-analyzer.linkedProjects`, so the editor finds a crate two levels deep.

### Security

- The weekly Copier updater renders in a read-only job. A fresh job applies only
  the patch before pushing, so Copier's dependencies cannot alter the runner that
  holds the update token.
- With `publish_to_ghcr`, the image push job runs in a `ghcr` environment, as PyPI and npm
  releases already do. Limit it to `main` and `v*` tags with a required reviewer in the
  repository's settings (see the README's Releasing section); until then GitHub creates it
  unprotected and pushes as before.
- A library's PyPI release signs a GitHub build-provenance attestation for each file in
  `dist/`, so users can check where a wheel was built with `gh attestation verify`. It is
  made in the publish job, which runs no project code.
- The hooks job installs a set prek version, 0.5.5, instead of the newest one on each run,
  and gives the read-only GitHub token to the zizmor hook only.

## [0.10.0] - 2026-10-16

### Added

- A `dependency_bot` question: Dependabot (the default, as before) or Renovate. Renovate
  gets a `renovate.json5` with the same rules as the Dependabot config: weekly, a one-week
  cooldown, grouped actions, hooks and dev tooling, and no updates to the copier-owned
  `FROM` tags. It needs the Renovate GitHub App on the repository. Existing projects keep
  Dependabot unless they answer `renovate` on the next `copier update`.
- A `data-pipeline` source can set `max_bytes` in `sources.toml` to accept a download
  over the 200 MiB default cap.
- A `data-pipeline` fetch retries a server error, a 429 (waiting at least its
  `Retry-After`), a network error or a body shorter than its `Content-Length`, up to
  four attempts with 5, 10 and 20 s between them. A brief publisher outage no longer
  fails CI. Any other 4xx still fails at once.
- Fetch records also hold the server's `last_modified` and `etag`, empty when it sends
  none. Records written before keep working.

### Changed

- With the `codecov` option, Codecov comments only when a pull request adds lines no test
  runs. It used to comment on any drop in total coverage, however small, although the
  docs said it waited for the 2-point threshold. A drop of over 2 points still fails the
  pull request's Codecov check.

### Fixed

- With both the Python and TS stacks and the `codecov` option, a pull request no longer
  gets a false coverage drop, with its comment, while the second stack's report is
  still on its way. `codecov.yml` now carries each stack's last numbers forward.
- A `data-pipeline` project's `pyproject.toml` no longer explains its packaging as if
  it were a research project with notebooks.

## [0.9.1] - 2026-10-13

### Fixed

- The README's licence badge now shows a hyphenated licence such as BSD-3-Clause.
  Before, shields.io read each hyphen as a field separator, so the badge broke.
- The Apache-2.0 and BSD-3-Clause LICENSE files now end in one newline, not two, so the
  end-of-file-fixer hook no longer rewrites LICENSE on its first run in a new project.

## [0.9.0] - 2026-10-13

### Added

- A `codecov` option for the Python and TS stacks: CI uploads test coverage to Codecov,
  and a `codecov.yml` fails a pull request only when total coverage drops by more than
  2 points. Codecov comments only then. It needs a `CODECOV_TOKEN` repository secret
  (see the README).

## [0.8.1] - 2026-10-13

### Fixed

- The dependency review job is skipped in private repositories. GitHub supports it
  there only with Advanced Security, so it failed every pull request.

## [0.8.0] - 2026-10-13

Upgrade steps:

- `copier copy --defaults` now stops at the GitHub user, author name and email, which
  have no defaults any more. Pass them with `--data`, or save them once under
  `defaults:` in Copier's settings file (see the README). `copier update` keeps the
  answers you already gave.
- A `library` project is asked for `python_min`. Its `requires-python` drops to that
  version and CI tests every version from there up, so check the code still runs on
  the oldest one. If you added a dependency, `copier update` can't merge the new
  `requires-python` next to it: take the new floor and keep your `dependencies`.
- In a `data-pipeline` project, re-run `just pipeline` after updating (see the
  Breaking change below).

### Added

- The `library` kind gets a `CITATION.cff`, like `research` and `data-pipeline`.
- `library`, `research` and `data-pipeline` projects also get `.zenodo.json`, which
  Zenodo reads when it archives a release, and a CodeMeta 4.0 `codemeta.json`.
- A `library` project tests every Python from `python_min` to `python_version` in CI.
  `python_min` defaults to two minors below `python_version`, after SPEC 0.
- A `data-pipeline` source can pin a `sha256`. `fetch` refuses a download that
  doesn't match it.

### Changed

- **Breaking:** the GitHub user, author name, author email and ORCID iD have no
  defaults. They used to default to the template author's details, which a
  `--defaults` run published in the new project.
- The copyright year defaults to the current year instead of a fixed one.
- The generated README installs golangci-lint with `go install`, which checks the
  download against the Go checksum database, instead of piping a script into `sh`.
- **Breaking:** `data-pipeline` drops the `vintage_basis` column and the per-source
  `encoding` key. The vintage is the manifest's `release`, and every source is read
  as UTF-8. Re-run `just pipeline` after updating.
- `data-pipeline` rejects a row with fewer fields than the header, and an id repeated
  in a different case is no longer an error.
- The web-service's `/docs`, `/redoc` and `/openapi.json` are off unless `API_DOCS` is
  set.
- VS Code formats TOML with the Tombi extension (`tombi-toml.tombi`), which reads the
  shipped `.tombi.toml`. Even Better TOML ignored it. Install the new recommendation
  after updating.
- CI no longer runs on draft pull requests; it runs when a pull request is marked ready
  for review. This saves Actions minutes on private repositories.
- Plainer wording in the generated `README.md`, `data/README.md` and `ATTRIBUTION.md`.

### Removed

- `workflow_dispatch` from the release workflows: a manual run could publish any
  branch.

### Security

- The Python workflow sets `UV_MALWARE_CHECK`, so uv checks every package against
  OSV's malware advisories before its code runs. A CI run fails if OSV is unreachable.

## [0.7.1] - 2026-09-30

### Added

- `just rs-sync` downloads Rust dependencies and writes `Cargo.lock`, like `just py-sync`
  and `just go-sync` do for their stacks.
- A yamlfmt hook with a `.yamlfmt` config. yamllint now checks yamlfmt's output.

### Changed

- Hook revs are commit SHAs with a `# frozen:` tag comment, since tags are mutable.
  Dependabot moves both together.
- Flow mappings are written `{key: value}`, as yamlfmt formats them.
- Comments and docstrings in generated files are shorter and plainer. Two
  `.dockerignore` comments now describe the Docker layer cache correctly.

## [0.7.0] - 2026-09-30

### Upgrade notes

1. Run `copier update`. It replaces `hygiene.yml` with `checks.yml`, swaps
   `.taplo.toml` for `.tombi.toml`, and deletes the pull request template.
2. If something uploads `coverage.xml` or `coverage/lcov.info`, add the reporter flag
   back to `just py-cov` or `just ts-cov`.

### Changed

- The `hygiene.yml` workflow is now `checks.yml`. Its job names are unchanged, so
  required status checks still match.
- `.tombi.toml` replaces `.taplo.toml`, because tombi replaced taplo as the TOML
  formatter.
- `just py-cov` and `just ts-cov` print a coverage summary only. They no longer write
  report files.
- CI reads the Python version from `.python-version` instead of repeating it.

### Removed

- The pull request template.
- The `knip` script in `package.json`. `pnpm run check` already runs knip.
- The copier checks that rejected a project name that is a Rust or Go keyword.

## [0.6.0] - 2026-09-30

### Upgrade notes

1. Run `copier update`. If you added dependencies, you get one conflict in
   `pyproject.toml`. Keep your dependencies and take the new comment below them.
2. Run `uv lock` and `pnpm install`, then commit the lockfiles. `uv lock` can downgrade
   packages released in the last week.
3. If a `SKIP` list names `gitleaks`, change it to `betterleaks`.
4. Delete the `.vale/` folder. Vale is gone, and so is the `.gitignore` entry that hid it.

### Added

- `rust` and `go` stacks, each as a library or a binary, with strict linting.
- Python `web-service` kind: FastAPI in a container, with a `/health` endpoint.
- Python `data-pipeline` kind: downloads third-party data and records a checksum for each
  file.
- Dependency audits in `just check` and CI for Python, TypeScript and Rust.
- A `hygiene.yml` workflow that runs the git hooks in CI.
- `CITATION.cff` for research and data-pipeline projects.
- Knip for TypeScript, and an actionlint hook.
- A `CHANGELOG.md` in the Keep a Changelog format. `copier update` never overwrites it.
- Copier rejects answers that would build a broken project, such as a name that starts
  with a digit or a directory with a trailing `/`.

### Changed

- **Breaking:** secret scanning uses Betterleaks instead of gitleaks.
- **Breaking:** the web service turns on OpenTelemetry only when
  `OTEL_EXPORTER_OTLP_ENDPOINT` is set.
- CI installs a pinned uv, because `uv audit` is a preview command that can change
  between releases.
- `pnpm audit` fails on moderate and higher advisories only.

### Removed

- **Breaking:** the web service's `config.py` and `telemetry.py`.
- **Breaking:** the vale prose linter and its `.vale.ini`. rumdl still lints Markdown.

### Fixed

- PyPI releases failed when the Python package was in a subdirectory.
- A project name with quotes or a trailing `!` broke the render or the README checks.
- Both Dockerfiles pass hadolint.
- yamllint skips `pnpm-lock.yaml`.

### Security

- uv and pnpm install a release only after it is a week old, the same as Dependabot.
- Data-pipeline downloads stop at 200 MiB.
- The release workflows and `SECURITY.md` list the GitHub settings to turn on.

## [0.5.0] - 2026-07-30

### Added

- Markdown linting with rumdl, and YAML linting with yamllint.

## [0.4.0] - 2026-07-28

### Added

- A JSON5 check for config files such as `tsconfig.json`.

## [0.3.0] - 2026-07-28

### Added

- Prose linting with vale.

## [0.2.0] - 2026-07-24

### Changed

- **Breaking:** the four templates are one template. A project made from 0.1.0 cannot
  update to this release.

### Fixed

- The shipped `.gitignore` no longer hides template files.
- biome accepts the rendered `.vscode/` files.

## [0.1.0] - 2026-07-24

### Added

- Separate templates for a base repo and for Python, TypeScript and Docker, in any mix.
- Python library, app and research projects, and TypeScript library and app projects.
- CI for each stack, with GitHub Actions pinned to commits and audited by zizmor.
- Optional releases to PyPI, npm and GitHub Container Registry.
- Dependabot with a one-week cooldown.
- Coverage recipes for Python and TypeScript.

[Unreleased]: https://github.com/simonvanlierde/project-templates/compare/v0.15.0...HEAD
[0.15.0]: https://github.com/simonvanlierde/project-templates/compare/v0.14.0...v0.15.0
[0.14.0]: https://github.com/simonvanlierde/project-templates/compare/v0.13.0...v0.14.0
[0.13.0]: https://github.com/simonvanlierde/project-templates/compare/v0.12.0...v0.13.0
[0.12.0]: https://github.com/simonvanlierde/project-templates/compare/v0.11.0...v0.12.0
[0.11.0]: https://github.com/simonvanlierde/project-templates/compare/v0.10.0...v0.11.0
[0.10.0]: https://github.com/simonvanlierde/project-templates/compare/v0.9.1...v0.10.0
[0.9.1]: https://github.com/simonvanlierde/project-templates/compare/v0.9.0...v0.9.1
[0.9.0]: https://github.com/simonvanlierde/project-templates/compare/v0.8.1...v0.9.0
[0.8.1]: https://github.com/simonvanlierde/project-templates/compare/v0.8.0...v0.8.1
[0.8.0]: https://github.com/simonvanlierde/project-templates/compare/v0.7.1...v0.8.0
[0.7.1]: https://github.com/simonvanlierde/project-templates/compare/v0.7.0...v0.7.1
[0.7.0]: https://github.com/simonvanlierde/project-templates/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/simonvanlierde/project-templates/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/simonvanlierde/project-templates/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/simonvanlierde/project-templates/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/simonvanlierde/project-templates/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/simonvanlierde/project-templates/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/simonvanlierde/project-templates/releases/tag/v0.1.0
