---
status: accepted
date: 2026-11-16
---

# The docs engine is chosen per toolchain

## Context and Problem Statement

[Decision 0006](0006-zensical-builds-the-docs-site.md) made Zensical the only docs engine,
because it needs no Node and gives a Python library an API reference. It rejected Starlight
for the same reason. Since then the template has gained TypeScript and Rust repos that have
Node and pnpm already, a `site=astro` option, and projects that keep a Starlight site of their
own. A Rust or TypeScript repo that selects `docs_site` today installs uv and Python only to
build its docs, and a Python-free repo cannot restyle them with the Node tooling it has.

Starlight's pages carry about ten inline scripts and 35 `style` attributes each (Starlight
0.42.8). A policy for them has to hash the scripts, since `'unsafe-inline'` for scripts would
let any injected script run. Astro's own `security.csp` (Astro 7.4) leaves `is:inline` scripts,
which Starlight's head uses, out of its hashes (withastro/astro#16664, closed as not planned
and still reproduced on 7.4.5), and writes its meta tag after the scripts in `<head>`, which
the policy then does not cover (#18606, open).

## Considered Options

* Keep Zensical as the only engine
* Replace Zensical with Starlight
* Offer both, chosen by the repo's toolchain

## Decision Outcome

Chosen: both, kept on purpose, in a `docs_engine` answer stored with `docs_site`. It is not
asked; the default follows the toolchain, and `--data docs_engine=...` picks the other:

* Zensical for a repo with a Python stack, or with neither a `ts` nor a `rust` one.
* Starlight for a repo with a `ts` or `rust` stack and no Python one.

An update keeps what it had: a project that stored no `docs_engine` stays on Zensical. Copier
leaves `_copier_operation` unset while defaults render, so the default tells an update from a
copy by the stored answers it can see; a `_migrations` entry would need `--trust` on every
update, which the template does not ask for.

This supersedes only the engine rule of 0006: the requirements, the Pages deployment, the
`docs_site` and `site` conflict and the `--strict` build remain. The API reference stays
Zensical's, since only mkdocstrings reads a Python docstring.

The Starlight render is a `docs-site/` package of its own, as `site/` is for `site=astro`. It
reads the Markdown in `docs/` unchanged (links between pages and to other repository files are
rewritten, the first h1 is the title) and builds into `_docs/` like Zensical. Its pages carry
`default-src 'none'; script-src 'self' 'wasm-unsafe-eval' <sha256 of each inline script>;
style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self'`.
`'wasm-unsafe-eval'` and `connect-src` are Pagefind's, the search, and stay on the site's own
files. A post-build integration (`csp-hash.mjs`) hashes the scripts in the built files and
writes the policy, so a Starlight upgrade that changes a script changes its hash, and
`check.mjs` refuses a script the policy misses. Expressive Code is off, as it adds a script
and a `style` attribute per token. Nothing loads from a third-party origin.

Both engines read the colours and font stacks from `docs/assets/docs-tokens.css`, which the
project owns, so one edit restyles either.

### Consequences

* Good: a Rust or TypeScript repo builds its docs with the pnpm and Node it already has, and a
  Python repo keeps its API reference.
* Good: `just docs` checks links, anchors, origins and script hashes, and `just docs-check` runs
  axe in a browser, in both colour schemes at 400 and 1440 px.
* Bad: two engines to keep in step. A page feature, such as the link-preview tags or the 404, is
  written twice, and a docs change can need a check in both. The maintenance rule below keeps
  that cost visible.
* Bad: Starlight needs `'unsafe-inline'` for styles, because of the `style` attributes, and a
  hash per inline script that the build recomputes.
* Bad: the Starlight build installs about 200 MB of `node_modules`, and Astro and Starlight
  are pinned in `copier.yml` and bumped by Renovate with the other pins.

Zensical stays the Python default for a reason that may expire: it has been a 0.1.x beta since
2026-11-05 and its config can still change. If it stalls, Starlight can become the default
without a change to the question.

### Keeping the engines in step

What both engines share: `docs/` as the only source, `docs/assets/docs-tokens.css` (paper, ink,
accent and fonts, mapped by each engine's own stylesheet), `docs/og-card.html` and `just
og-card`, the `just docs` and `docs-serve` recipe names, `_docs/` as the output, and the
`docs.yml` deploy job. The checks are not shared: Zensical's build is `--strict` and its pages
need no policy, while `check.mjs` and `axe.mjs` test what only Starlight's pages carry. Neither
`site/` nor the web app has a static-HTML check to share them with.

The rule: a change to one engine's tokens, page features (link-preview tags, the 404, search),
checks or deploy is made in the other in the same pull request, or recorded under Known
differences here.

Known differences:

* The API reference is Zensical's alone.
* Starlight's pages carry a hash-based policy, a link, anchor and origin check and an axe run;
  Zensical's rely on `--strict` and the theme.
* Starlight rewrites a link out of `docs/`, such as `../README.md`, to GitHub; Zensical's
  `--strict` build fails on one, so a page that must build with both uses the full GitHub URL.

### Accepted limits of the Starlight policy

* `csp-hash.mjs` allows every inline script it finds in the built pages. A raw `<script>` in
  `docs/*.md` would be allowed with them, so `markdown.mjs` stops the build on one instead.
  A script that Starlight, Astro or another integration adds is allowed by its hash too.
* `'self'` on `<user>.github.io` covers every Pages site of that user, so a script, style or
  fetch from another of their repos' sites is allowed. A custom domain narrows it.
* A meta tag cannot set `frame-ancestors`, and GitHub Pages sets no headers, so the pages can
  be framed.

### Confirmation

`scripts/render/site.sh` renders both engines (Python, Rust, TypeScript and a nested web app),
checks each one's files and workflow, builds the Rust render with `just docs-sync docs
docs-check` (link, anchor, origin and script-hash checks and axe), and checks that a link to a
missing file or a `<script>` in the Markdown stops the build. `scripts/render/update.sh`
updates v0.15.0 Rust and TypeScript docs sites and checks they stay on Zensical.
`scripts/render/cases.sh` refuses a package directory that collides with `docs-site/` or
`_docs/`.

## Pros and Cons of the Options

### Keep Zensical as the only engine

* Good: one engine, one set of overrides.
* Bad: Node-only repos install Python to build their docs.

### Replace Zensical with Starlight

* Good: one engine.
* Bad: no API reference from Python docstrings, and a hash-based policy where Zensical needs
  none beyond its own files.
