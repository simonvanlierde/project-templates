---
status: accepted
date: 2026-11-03
---

# Pull request previews use the production Cloudflare account

## Context and Problem Statement

A web app gets a preview Worker for each pull request. The deploy needs a Cloudflare API
token, and the `preview` job runs the branch's own code with it. Previews could use a
separate Cloudflare account with their own token, or the production account.

## Considered Options

* One token in the production account, for production and previews
* A separate account and token for previews

## Decision Outcome

Chosen: one token in the production account. Fork pull requests and pull requests from
bots, such as Renovate's, get no preview. Anyone who can push a branch could replace or
delete the production Worker, or copy the token. That is accepted while the Worker serves
only static files, because the harm is a replaced site, as with a bad dependency merged to
`main`. The row on branch code reading the token in the
[threat table](../design.md) holds the reasoning.

Revisit before a Worker gets bindings (KV, D1, secrets): those reach every preview, so
previews then move to their own account.

### Consequences

* Good: one account and one token to set up and rotate.
* Bad: a branch can reach production until previews move out.

### Confirmation

`scripts/check-render.sh` asserts that the preview job skips draft and bot pull requests.
Nothing yet fails when a Worker gains bindings.
