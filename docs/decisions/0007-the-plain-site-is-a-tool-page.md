---
status: accepted
date: 2026-11-07
---

# The plain site is a tool page

## Context and Problem Statement

`site=plain` rendered a header, a footer and a TODO where the tool goes. Small tools
such as jsonvet and citesync all ended up with the same layout: a compact header, an
input and its result in the first screen with one action, details in disclosures, and a
footer with one true privacy line. Each project rebuilt that layout from the empty page,
along with its states and its accessibility. The template should start a project from that
layout without making the projects share code or a look.

## Considered Options

* A new `site=tool` choice beside `plain`, which stays the empty page
* `site=plain` renders the tool page in place of the empty one
* A shared package or component library that each tool page imports

## Decision Outcome

Chosen: `site=plain` renders the tool page. The plain site was already described as "the
tool in the first screen, details in disclosures", so the starter now does what the
question promised. A fourth choice would double the plain files and the render cases for a
page that differs only in what is in `<main>`. A page that is not a tool, such as a report,
deletes the workspace and keeps the rest.

The starter is a working tool with a stand-in job (it formats JSON), so that its states
are real: sample, empty, invalid and ready. The project replaces `convert()`, the labels and
the palette. No code is shared between projects: the files are the project's after the first
render, and each tool keeps its own look. The layout can become a shared package only after
three tools show the same needs.

The privacy line says the visitor's input never leaves the page, and the page's
Content-Security-Policy has no `connect-src`, so the browser enforces it. A project that
adds a request must change both.

### Consequences

* Good: a new tool page starts with its states, its keyboard and screen reader behaviour,
  and a privacy line that is true.
* Good: no new question, and existing projects keep their page, because the starter files
  are in `_skip_if_exists`.
* Bad: a project that wants an empty page deletes more than before.
* Bad: the stand-in job can ship if nobody replaces it. The TODO markers in the three files
  are the only guard.

### Confirmation

`scripts/check-render.sh` asserts the workspace, the CSP without `connect-src`, the privacy
line, the job sentence or its TODO on both sides of `project_description`, and that
`main.mjs` parses. The browser behaviour (states, axe, 320 px, dark mode) has no check in CI.
