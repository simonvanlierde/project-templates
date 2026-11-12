# Hosting

Where a web app (`ts_kind=web-app`, [TypeScript kinds](usage.md#typescript-kinds)) and a
static site (`site`) go live. A web app always deploys to a Cloudflare Worker. A site
deploys to GitHub Pages, or to a Worker with `site_host=cloudflare`. Either way, each pull
request gets a preview on its own Worker.

## Static site

Answer `site` (under `customise`) to give any project a static page beside its code: a playground, a demo or a report. GitHub Pages serves it from `main`, or a Cloudflare Worker with `site_host=cloudflare`, and each pull request gets a preview. The page's readers are the project's users, so it stays small: the tool in the first screen, details in disclosures.

The two choices differ only in what is in `site/` and how `just site` builds it:

- `site=plain`: `site/index.html`, `site/style.css` and `site/main.mjs`, a working [tool page](#the-plain-tool-page). Plain HTML, CSS and an ES module, no build step or framework. `just site` copies `site/` to `_site/`. For a page that needs a build, replace the recipe's body with yours, such as `uv run site/build.py --out _site`, and add the setup it needs (uv, Rust, Node) before `just site` in the `build` job of `site.yml`.
- `site=astro`: a small Astro project. `package.json` pins astro at the version in `copier.yml`, `src/layouts/Base.astro` has the same header and footer, and `src/pages/` holds `index.astro` and a Markdown page, `about.md`. Run `just site-sync` once and commit the `site/pnpm-lock.yaml` it writes. `just site` installs from that lockfile and runs `astro build` into `site/dist/`. The `build` job sets up Node and pnpm from `site/package.json`, so the repo needs no TypeScript stack. Pages serves the site at `https://<user>.github.io/<repo>/`, so `site` and `base` in `astro.config.mjs` match it. On a Worker (`site_host=cloudflare`) the site is served from `/`: `site` is the Worker's address and there is no `base`.

`just site-serve` serves either one at `http://localhost:4321/`, under `/<repo>/` for an Astro site on Pages, as Pages does.

The starter files are yours: an update leaves them alone. An Astro site's `package.json` stays the template's, and Dependabot or Renovate bumps it. Both choices also render:

- `.github/workflows/site.yml`. The `build` job runs `just site` on every pull request and push to `main` and uploads the result, which is gitignored. The `deploy` job publishes that build to GitHub Pages on a push to `main`. It is the only job with `pages: write`. [On a Worker](#hosting-on-a-worker), it deploys to the Worker instead.
- The `preview` job in `site.yml`, with `wrangler.site.jsonc`, `.github/scripts/deploy-worker.sh`, `preview-retire.yml` and `preview-retire.sh`: the web app's own preview pieces ([Pull request previews](#pull-request-previews)).

A GitHub Pages site is public even when the repo is private, and a private repo needs a paid GitHub plan for Pages. Until Pages is on, the `deploy` job skips with a notice, and `just repo-settings` warns and goes on where GitHub refuses Pages. The one-time setup is in [Cloudflare setup](#cloudflare-setup).

### The plain tool page

`site=plain` starts from a small working tool that formats JSON. It shows the layout and the states, and you replace the job with your own. Top to bottom, the page has:

1. A header with the project name, `project_description` as the one sentence that names the job, and a Docs link to the README. Without a description, a TODO marks the spot.
2. The workspace: an input with an Open a file button, and beside it the result with one action, Copy result. They sit side by side from 48rem and stack on a phone. The result updates 250 ms after the visitor stops typing, and a label shows its state: Sample, Empty, Needs a fix or Ready. An error shows under the input, and Copy result stays off until the input is valid, so nobody copies a stale result.
3. Two disclosures: Settings, with an indent choice, and Use it elsewhere, a TODO for command-line or CI use of the same job.
4. A footer with one privacy line, then the licence, the source and the issue tracker. A private repo's page has no links into the repo.

To make it your tool, change `convert()` at the top of `main.mjs`, the labels in `index.html` and the colours at the top of `style.css`. `convert()` returns the result text, or throws an error whose message the page shows under the input.

The privacy line says that what the visitor types never leaves the page. The page's Content-Security-Policy has no `connect-src`, so the browser blocks any request the script makes, and the line stays true. A page that calls an API, such as a `worker` route, adds that origin to `connect-src` and changes the line to say what it sends.

For accessibility, the page has a skip link, labelled controls, a visible focus ring, targets at least 44 px tall, and screen reader announcements for a state change or the copy outcome. It follows the system's dark mode and reduced-motion setting, and keeps the primary action visible in forced colours.

## Hosting on a Worker

A web app, and a site with `site_host=cloudflare`, deploy to a Worker on every push to `main`:

- A web app's `production` job in `ts.yml` runs after the checks pass. It deploys the build the checks ran on to the Worker `<slug>`, with the pinned wrangler, at `https://<slug>.<subdomain>.workers.dev`.
- A site's `deploy` job replaces Pages with the Worker `<slug>-site`, from the same `wrangler.site.jsonc` the previews use. It deploys the build job's artifact, one run at a time. A repo with a web app keeps `site_url` for the app, and the site stays at its workers.dev address.

Both jobs run in the `production` GitHub environment, which `just repo-settings` limits to `main`. A preview job that holds the same Cloudflare token can still deploy over production (see [Cloudflare setup](#cloudflare-setup)). Without `CLOUDFLARE_API_TOKEN` or `CLOUDFLARE_ACCOUNT_ID`, the job skips with a notice. Static-asset requests are free and unlimited on the Workers Free plan.

The starter `astro.config.mjs` is the project's, so switching an existing Astro site from Pages leaves it alone: set `site` to the new address and delete `base`.

### Custom domains

`site_url` is the public address of what deploys to a Worker. Give a host alone, without a path: a Worker serves a whole host. When the host is not `*.workers.dev`, it is a custom domain: the production job runs `wrangler deploy --domain <host>`, which attaches it to the Worker and creates its DNS record. The domain needs a zone in the same Cloudflare account, without a CNAME record for that host, and the production token needs Zone > Workers Routes: Edit for that zone. The domain is not in the wrangler config, because previews deploy that config under their own names and must not take it. `just repo-about` sets it as the repo's homepage.

### Worker script

`worker` adds a Worker script in front of the static assets, for server code such as an API. `main` in the wrangler config points at it, the `ASSETS` binding lets it hand a request to the files, and `run_worker_first: ["/api/*"]` sends only `/api/*` to it first. Every other request is served from the files without running the script, so it stays free; each request the script handles counts against the Workers plan. The starter has one route, `/api/health`, answers 404 for the rest of `/api/`, and passes anything else to the files.

- A web app gets `worker/index.ts`, with its own `worker/tsconfig.json` that swaps the DOM types for `@cloudflare/workers-types`. `pnpm run typecheck` checks both, and Vitest runs `worker/index.test.ts` in Node against a stub `ASSETS`. `pnpm dev` runs Vite alone; `pnpm exec wrangler dev` serves the last build and the script together.
- A site gets `site/worker/index.mjs`, plain JavaScript with no TypeScript stack needed. `just site` runs `site/worker/index.test.mjs` with `node --test` first, and a plain site's build leaves `worker/` out. wrangler bundles the script on every preview and production deploy, so a script that does not bundle fails the pull request's preview.

A plain site on a Worker also gets `site/_headers`, with the same security headers as a web app's `public/_headers` (a Content-Security-Policy with `frame-ancestors 'none'`, `X-Content-Type-Options: nosniff` and HSTS). The page's meta tag cannot set `frame-ancestors`, so keep the header's policy in step with it; a site on Pages cannot send headers.

The script and its test are the project's after the first render. A binding beyond `ASSETS` (KV, D1, a secret) also reaches every preview: read [decision 0001](decisions/0001-pr-previews-use-the-production-cloudflare-account.md) first.

### Moving an app off Cloudflare Pages

An app made before this template deployed from CI was deployed by Cloudflare Pages. Check first that the account has no Worker named `<slug>`: the first deploy overwrites it. Expect a short gap while the domain moves from Pages to the Worker. To move the app:

1. Delete any Pages `public/_redirects` rule with status `200!`: Workers refuses it with error `100324`. Merge the `copier update`, then run `just repo-settings` and add both secrets to the new `production` environment.
2. The next push to `main` deploys the Worker. Check the app at its workers.dev address.
3. Remove the custom domain from the Pages project. With `site_url` set to it, the next production deploy attaches it to the Worker.
4. Delete the Pages project, now that the Worker serves production.

Without a custom domain, the app's address changes: set the new one with `copier update --data site_url=https://<slug>.<subdomain>.workers.dev`.

## Pull request previews

Each pull request that is open, not a draft, not opened by a bot such as Renovate and not from `chore/copier-update` gets its own Cloudflare Worker:

- A web app's `preview` job in `ts.yml` deploys `wrangler.jsonc` as `<slug>-pr-<number>`, at `https://<slug>-pr-<number>.<subdomain>.workers.dev`.
- A site's `preview` job in `site.yml` deploys the build job's artifact, not a fresh build, as `<slug>-site-pr-<number>`. The `-site` in the name keeps it apart from a web app's preview in a repo that has both. For a site on Pages, the preview serves the build under `/<repo>/` as Pages does, with a redirect from `/`. For a site on a Worker, it serves the build from `/`, as production does.

The job summary and the pull request's deployment show the link. Previews are public, and they send `X-Robots-Tag: noindex`. With a custom domain, production sends it only on the duplicate workers.dev origin.

When a pull request closes or turns draft, `preview-retire.yml` deletes its Worker through the Cloudflare API. A daily run lists the account's preview Workers and deletes those whose pull request is not open and ready, in case an event was missed. When it cannot read a pull request, it keeps that Worker and fails. To retire previews by hand, run that workflow with a list of pull request numbers, or with the list empty to run the sweep.

The daily sweep finds preview Workers by name alone. In one Cloudflare account, a repo `foo` with a site and a repo `foo-site` with a web app would share the names `foo-site-pr-<number>`: rename one of them if that happens.

Fork pull requests and repos without `CLOUDFLARE_API_TOKEN` or `CLOUDFLARE_ACCOUNT_ID` skip the job with a notice. A site on Pages still deploys.

### Cloudflare setup

One-time setup for previews and Worker hosting:

1. Run `just repo-settings`. For a web app or a site on a Worker, it creates the `preview` and `production` environments in GitHub (or create them under Settings > Environments, with `production` limited to `main`). For a site on Pages, it creates the `preview` environment and sets GitHub Pages to deploy from Actions (Settings > Pages > Source: GitHub Actions).
2. Create a custom Cloudflare API token with the permission Account > Workers Scripts: Edit. Add it to each of those environments as the secret `CLOUDFLARE_API_TOKEN`, and add your account ID as `CLOUDFLARE_ACCOUNT_ID`.

The `preview` job runs the pull request's code with the `preview` environment's Cloudflare token. If both environments hold one account-wide token, anyone who can push a branch can deploy over the production Worker. To keep them apart, give previews a token from a second Cloudflare account ([why](design.md#security-assessment)).

The first deploy creates each Worker, so there is nothing to set up in Cloudflare except the token. The account needs a workers.dev subdomain. A web app's wrangler is an exact devDependency in `package.json` ([why](decisions/0002-wrangler-is-an-exact-dev-dependency.md)), and the dependency bot bumps it.

## Social card

A web app, a site or a docs site renders `docs/og-card.html`, a 1200x630 poster with the project name, `project_description` and the site's address, and `og:image`, `og:image:width`, `og:image:height`, `og:image:alt` and `twitter:card` tags in the page head that point at it. A docs site sets them from `docs-overrides/main.html` on every page, with `og:title`, `og:description` and `og:url` too, reading `og_image` from `zensical.toml`. The alt text is the name and the description. The file is yours: an update leaves it alone.

Run `just og-card` to render it to a PNG, and commit the PNG: `public/og.png` for a web app, `site/og.png` for `site=plain` and `site/public/og.png` for `site=astro` and `docs/assets/og.png` for a docs site. A web app renders with the Playwright in its devDependencies (`pnpm exec playwright install chromium` once). A site runs `pnpm dlx playwright@<pinned version>`, so it needs no Node package of its own. The recipe also writes the PNG's first 8 hex of SHA-256 into the page's `og:image` URL (`og_image` in `zensical.toml` for a docs site) (`og.png?v=<hash>`), because Facebook, Slack, Discord and iMessage cache a preview by image URL and would keep the old card after a redraw. Commit the page with the PNG. The head tags point at a file that does not exist until you run it.

Replace the card's colours and font with the project's own, then check it before you commit:

- View it at 300 px wide. The name and the one-line job must still read.
- Crop it to the centre 630 px square. Small square thumbnails (LinkedIn posts, X `summary`, WhatsApp) cut it that way, so the name and any mark must survive there. The job line and the address only need to stay 60 px clear of every edge, since no thumbnail is big enough to read them.

Keep the text at 36 px or more at 1200 px wide, one idea on the card and no label above the name. Never use a screenshot of the app: it is illegible at preview size. Keep the job line and the address on the card even though `og:description` and the alt text say the same, because X shows only the image, LinkedIn hides the description, and a shared screenshot carries no preview text. One real result or short example may go under the job line to prove it. A repo with several of them has one card source, `docs/og-card.html`, and `just og-card` renders the same image into each place. The card prints the web app's address, else the site's, else the docs site's. Every page head that names a card gets it: the app, the site and each docs page. The docs site's copy is in `docs/assets/`, so the build publishes the card source (`og-card.html`) beside it.
