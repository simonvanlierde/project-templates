---
name: project-templates documentation
description: A practical reference with a short path for first-time readers
colors:
  primary: "#4051b5"
  primary-muted: "#4051b51a"
  neutral-bg: "#ffffff"
---

# Design System: project-templates documentation

## Overview

This file describes the documentation website. The template's architecture is
documented separately in [docs/design.md](docs/design.md).

The site is a reading surface that uses Zensical's built-in theme. Reading and finding instructions take
priority: the homepage introduces the template, gives the first steps and links to
the reference pages.

## Colors

Use the theme's indigo accent for links and active controls, with its muted accent
for highlights. Keep the light reading surface and the theme's text colors.
`zensical.toml` selects the theme; theme styles own the remaining colors.

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
keyboard behavior and visible focus indicators. The chooser uses native radio
buttons, selects and a copy button, revealing only the questions relevant to the
reader’s task. Check normal text against its
background for at least 4.5:1 contrast when changing colors.

## Do's and Don'ts

- Give first-time readers a short route to choosing and creating a project.
- Label links that take readers to the GitHub quick start.
- Keep theme components and assets local; omit remote repository statistics.
- Keep the homepage as a reading page, without a hero or a grid of cards.
- Avoid custom colors or components when the theme already serves the task.
