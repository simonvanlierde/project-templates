---
name: project-templates documentation
description: A practical reference with a short path for first-time readers
colors:
  primary: "#5b2d6e"
  link: "#7b3f94"
  link-dark: "#d3a6e8"
  accent: "#f5b942"
  neutral-bg: "#ffffff"
  card-bg: "#f8f5fa"
  card-ink: "#17191c"
  card-ink-muted: "#3c424a"
---

# Design System: project-templates documentation

## Overview

This file describes the documentation website. The template's architecture is
documented separately in [docs/design.md](docs/design.md).

The site is a reading surface that uses Zensical's built-in theme. Reading and finding instructions take
priority: the homepage introduces the template, gives the first steps and links to
the reference pages.

## Colors

Plum and gold, in place of the theme's default indigo. Plum (`primary`) fills the
release bar and the mark's tile; links and active controls use a lighter plum (`link`),
and `link-dark` in the dark scheme, whose surfaces lean toward plum. Gold (`accent`)
marks only the mark's seed and paths and the version in the release bar, never body
text. The site follows the reader's system setting until they pick one with the header
toggle. `docs/assets/brand.css` holds these colours and stays out of the template, so
generated docs sites keep the theme's own; theme styles own the remaining colors.

## Mark and social card

The mark is `docs/assets/logo.svg`: a white Copier C around a gold seed, with gold paths
leaving through its opening to a square, a circle and a triangle. One start, several
different stacks. It is the header logo and the favicon, and it stays legible at 16 px.
`scripts/og-card.html` is the 1200x630 link-preview card, centred so the mark and the
name survive a square crop; `just og-card` renders it to `docs/assets/og.png`.

## Typography

Use the system fonts selected by the theme when `font = false`. Keep the theme's
heading hierarchy, body text and monospace code styles. Fonts require no remote
service.

## Layout

Keep one reading column with the theme's navigation, page outline and search.
Use headings, short paragraphs, numbered steps and lists of reference links.
Let the theme adapt navigation to smaller screens.

## Components

Use the built-in navigation, search, links, tables and code blocks. Preserve their
keyboard behavior and visible focus indicators. The announcement bar names the newest
release and can be dismissed; each page has an edit link, and the footer links the
source, the DOI and the maintainer's site. The chooser uses native radio
buttons, selects and a copy button, revealing only the questions relevant to the
reader’s task. Check normal text against its
background for at least 4.5:1 contrast when changing colors.

## Do's and Don'ts

- Give first-time readers a short route to choosing and creating a project.
- Label links that take readers to the GitHub quick start.
- Keep theme components and assets local; omit remote repository statistics.
- Keep the homepage as a reading page, without a hero or a grid of cards.
- Avoid custom colors or components when the theme already serves the task.
