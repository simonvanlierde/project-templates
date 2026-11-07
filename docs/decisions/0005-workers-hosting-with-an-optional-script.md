---
status: accepted
date: 2026-11-06
---

# Workers hosting with an optional script

## Context and Problem Statement

A web app deploys to a Cloudflare Worker that serves static files. A static site could
deploy only to GitHub Pages, under `/<repo>/`. Some projects want the site on Cloudflare
too, on a custom domain, and some want a little server code (an API route) next to the
files of either. The template needs one way to do that for both, without a framework
adapter per site generator.

## Considered Options

* Where the site goes: a `site_host` choice (`pages` or `cloudflare`), or always Workers
* The custom domain: a `routes` entry with `custom_domain` in the wrangler config, or
  `wrangler deploy --domain` in the production job
* Server code: a Worker script with `main`, the `ASSETS` binding and `run_worker_first`; a
  framework adapter such as Astro's Cloudflare one; or the Cloudflare Vite plugin
* Its types and tests: `@cloudflare/workers-types` and a Vitest test with a stub `ASSETS`;
  `wrangler types` with a generated `worker-configuration.d.ts`; or
  `@cloudflare/vitest-pool-workers`

## Decision Outcome

Chosen:

* `site_host`, default `pages`, so every existing site renders as before. With
  `cloudflare`, production deploys `wrangler.site.jsonc`, the previews' own config, under
  its own name, `<slug>-site`.
* `--domain` from `site_url`, in the production job only. Previews deploy the same config
  under other names, and a `routes` entry there would move the domain to each preview.
  wrangler 4.154.0 adds `--domain` to the config's routes as a custom domain.
* One `worker` question for both: `main`, `assets.binding: "ASSETS"` and
  `run_worker_first: ["/api/*"]`. It works with any build that writes files, Vite or Astro
  or a plain copy, and requests for files still never run the script.
* A web app's script is TypeScript with `@cloudflare/workers-types` in its own
  `worker/tsconfig.json`, because those types clash with the DOM types of the app.
  Vitest runs its test in Node with a stub `ASSETS`: no workerd and no extra test pool. A
  site's script is plain JavaScript tested with `node --test`, so a site needs no
  TypeScript stack.

A script with only the `ASSETS` binding holds no secret, so
[0001](0001-pr-previews-use-the-production-cloudflare-account.md) still holds. A script
that gains KV, D1 or a secret triggers its revisit.

### Consequences

* Good: one config per Worker serves production and previews; a domain is one answer.
* Good: the script's tests run without Cloudflare's runtime, in the checks every project
  already runs.
* Bad: the tests do not run workerd, so a runtime-only difference (such as a
  compatibility flag) shows up in the preview, not in the tests.
* Bad: the custom domain is not in the wrangler config, so a local `wrangler deploy` does
  not attach it.
* Bad: a token that deploys a custom domain also needs Zone > Workers Routes: Edit.

### Confirmation

`scripts/check-render.sh` asserts that only production passes `--domain`, that `main`,
the binding and `run_worker_first` appear only with `worker`, that a site on a Worker
renders no Pages job, and it runs a site script's tests through `just site`. CI's
TypeScript job type-checks and tests a web app's script.
