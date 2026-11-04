---
status: accepted
date: 2026-11-04
---

# Drop the TypeScript Docker image

## Context and Problem Statement

The `docker_stacks` question offered a `ts` image: a Node service with a `/health` endpoint. No render
of the template used it, and the web-app kind deploys to Cloudflare Workers without
one.

## Considered Options

* Keep the `ts` image
* Drop it, and refuse `docker` without `python`
* Drop it, and ask one yes/no question for the Python image; without it, a Compose-only repo

## Decision Outcome

Chosen: drop it, and replace the `docker_stacks` question with a yes/no `docker_image`.
The Dockerfile, `.dockerignore`, `src/main.ts` stub, compose service and the CI renders
that used it are gone. `docker_image` is asked only when `stacks` has both `docker` and
`python`, and defaults to yes: build the Python image. `docker` without `python`, or
`docker_image=false`, renders the Compose-only repo (an example upstream service, no
Dockerfile), so a deploy repo that composes upstream images keeps a place in the template.
Copier drops an old `docker_stacks` answer, and the update deletes the ts files, so the
change is marked **Breaking** in the changelog.

### Consequences

* Good: less template to render, test and keep current.
* Bad: a project that wants a Node image writes its own Dockerfile.

### Confirmation

`scripts/check-render.sh` renders `docker` without `python` and `docker_image=false` and
fails if either writes a Dockerfile, and renders the Python image in several answer sets.
