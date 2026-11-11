---
status: accepted
date: 2026-11-06
---

# Zensical builds the docs site

## Context and Problem Statement

The `docs-site` requirement in `docs/usage.md#levels` is a search-indexed site built from the Markdown
in `docs/`, never a second copy. Until now the template had no way to render one, and
`ROADMAP.md` ruled out a docs-site starter. The `docs_site` selection in `extras` adds one. The
generator is costly to swap: projects write their config and page syntax for it.

It has to build `docs/*.md` unchanged, give a Python library an API reference from its
docstrings, have search, need little config, be maintained, and run with uv.

## Considered Options

* Zensical with mkdocstrings
* MkDocs with Material for MkDocs
* Sphinx with MyST
* Astro Starlight

## Decision Outcome

Chosen: Zensical, the successor to Material for MkDocs from the same team, with
mkdocstrings-python for the API reference. It reads plain Markdown, ships search, and
a working `zensical.toml` is under ten lines. mkdocstrings reads the source with griffe,
so the package needs no install. `just docs` runs both with `uvx` at the versions
`copier.yml` pins, so it works the same in every stack. The build runs with `--strict`.

The site deploys to GitHub Pages, like the `site` option on its default host. A repo has
one Pages site, so the validator refuses `docs_site` beside a `site` on Pages. A `site` on
a Worker (`site_host=cloudflare`, [decision 0005](0005-workers-hosting-with-an-optional-script.md)) leaves Pages free, so the two can sit
together. Building the docs into a path under the
`site` page would share one Pages artifact between two workflows; that waits until a
project needs both.

TypeScript, Rust and Go projects get the site without an API reference: docs.rs and
pkg.go.dev publish one, and the template has no TypeScript handler.

### Consequences

* Good: one config file and two recipes, and no docs dependencies in the project.
* Good: the docs follow the template's one-week release-age rule (`uvx --exclude-newer`).
* Bad: Zensical is a beta (0.0.x), so its config can change between releases. Renovate
  bumps the pin in `copier.yml`, and `check-render.sh` builds a render for real.
* Bad: a strict build refuses a link out of `docs/`, such as `../README.md`. Such links
  have to be full GitHub URLs.

### Confirmation

`scripts/check-render.sh` renders the docs site with and without the API reference,
refuses it beside a `site` on Pages, and runs a strict `just docs` on two renders.

## Pros and Cons of the Options

### MkDocs with Material for MkDocs

* Good: the mature ecosystem the API reference plugins came from.
* Bad: MkDocs 1.6.1 is from August 2024, and Material marks itself inactive on PyPI.

### Sphinx with MyST

* Good: maintained, with autodoc and cross-project references.
* Bad: a `conf.py`, a theme and a toctree in each page tree; MyST Markdown is not
  plain Markdown once directives come in.

### Astro Starlight

* Good: the Node toolchain the `site=astro` option already uses.
* Bad: no Python API reference, and a Node project inside a Python repo.
