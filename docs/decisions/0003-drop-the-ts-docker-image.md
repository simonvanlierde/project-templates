---
status: accepted
date: 2026-11-04
---

# Drop the TypeScript Docker image

## Context and Problem Statement

The `docker_stacks` question offered a `ts` image: a Node service with a `/health` endpoint. No render
of the template used it. Every TypeScript project is a web app deployed to Cloudflare
Pages or Workers, and the hand-written TypeScript Dockerfiles elsewhere serve a static
build with Caddy instead of running Node.

## Considered Options

* Keep the `ts` image
* Drop it, which leaves one image and no question to ask

## Decision Outcome

Chosen: drop it, and the `docker_stacks` question with it. The Dockerfile,
`.dockerignore`, `src/main.ts` stub, compose service and the CI renders that used it are
gone. `docker` in `stacks` now means the Python image, and `docker` without `python` is
refused. An old `docker_stacks` answer is ignored, and the update deletes the ts files,
so the change is marked **Breaking** in the changelog.

### Consequences

* Good: less template to render, test and keep current.
* Bad: a project that wants a Node image writes its own Dockerfile.

### Confirmation

`scripts/check-render.sh` fails if `docker` without `python` renders, and renders the
Python image in several answer sets.
