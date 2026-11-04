---
status: accepted
date: 2026-11-04
---

# Drop the TypeScript Docker image

## Context and Problem Statement

`docker_stacks` offered a `ts` image: a Node service with a `/health` endpoint. No render
of the template used it. Every TypeScript project is a web app deployed to Cloudflare
Pages or Workers, and the hand-written TypeScript Dockerfiles elsewhere serve a static
build with Caddy instead of running Node.

## Considered Options

* Keep the `ts` image
* Drop it and leave `python` as the only choice

## Decision Outcome

Chosen: drop it. The choice, its Dockerfile, `.dockerignore`, `src/main.ts` stub, compose
service and the CI renders that used it are gone. An existing answer `docker_stacks: [ts]`
stops validating, so the change is marked **Breaking** in the changelog.

### Consequences

* Good: less template to render, test and keep current.
* Bad: a project that wants a Node image writes its own Dockerfile.

### Confirmation

`scripts/check-render.sh` fails if a render with `docker_stacks=[ts]` succeeds.
