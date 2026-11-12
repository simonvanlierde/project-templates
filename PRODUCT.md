# Product

## Platform

web

## Users

This brief covers the project-templates documentation website. Its readers use the
Copier template to start and maintain repositories. The audience order is the
maintainer's own projects, CML colleagues, then public Copier users, as recorded in
[decision 0008](docs/decisions/0008-three-audiences-in-order.md).

First-time readers need to choose a project kind, create a project and find the
checks to run. Returning readers need settings, update instructions and references.

## Product Purpose

Help readers start a project with the template and keep it current. The homepage
should give a first-time reader a clear next step without requiring knowledge of
the template's options.

## Operating Context

Readers use the site alongside Copier, their language toolchain and the generated
project's README. The repository README owns the quick-start commands; the site
links to them on GitHub. The usage guide owns settings and update instructions.

## Capabilities and Constraints

- The template supports Python, TypeScript, Rust, Go and Docker, including projects
  that combine stacks.
- Help me choose maps a reader’s main task to a project kind and a Copier command.
  It explains the starting files and checks, without storing answers or creating a
  project in the browser.
- Zensical builds the Markdown in `docs/`. Each document has one source for both
  GitHub and the documentation site, as recorded in
  [decision 0006](docs/decisions/0006-zensical-builds-the-docs-site.md).
- Keep the site a practical reference with a short path for new readers. Use the
  built-in theme and search, with local assets and system fonts.
- Root `DESIGN.md` describes the website's visual system. `docs/design.md` describes
  the template's architecture and security controls.

## Product Principles

- Explain what the template provides before asking readers to choose options.
- Put the common first steps before detailed reference material.
- Keep commands and technical facts in one place, then link to them.

## Accessibility & Inclusion

Keep navigation and search usable by keyboard. Maintain visible focus indicators
and at least 4.5:1 contrast for normal text.
