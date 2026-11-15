---
status: accepted
date: 2026-11-15
---

# Rust releases through one workflow

## Context and Problem Statement

Python, TypeScript and the container image publish without a stored token. Rust had no
release path: `Cargo.toml` carried `publish = false` and the GitHub release came from
`release.yml`. A crate needs crates.io trusted publishing, and a binary needs archives
that `cargo binstall` finds, with attestations like `python-release.yml` makes.

## Considered Options

* Extend `release.yml` with Rust jobs
* A `rust-release.yml` beside `release.yml`, as `python-release.yml` does
* Publish with a stored `CARGO_REGISTRY_TOKEN`

## Decision Outcome

Chosen: a `publish_to_crates` answer (default off, asked of the Rust stack) that adds
`rust-release.yml` and drops `release.yml`, the pattern of `publish_to_pypi`. The
`publish` job alone holds the OIDC token and runs `cargo publish --no-verify`, so no
build script runs beside it. For a binary, the same job attests four target archives
(named per `[package.metadata.binstall]`), and the `release` job verifies each
attestation before it uploads to a draft release. Both jobs follow `verify-tag.sh`
and the `crates` environment, limited to `v*` tags by `just repo-settings`.

Both workflows create the GitHub release, so a validator refuses `publish_to_crates`
with `publish_to_pypi`. A project that needs both publishes one registry by hand or
splits the repo. Existing projects answer `false` on update and keep `publish = false`.
crates.io cannot create a crate by trusted publishing: `first-release.md` lists the
manual first upload.

### Consequences

* Good: no registry token is stored, and a binary's provenance is checkable with
  `gh attestation verify`.
* Bad: one repo cannot publish to PyPI and crates.io through the template.
* Bad: the first release needs a manual `cargo publish`.

### Confirmation

`scripts/render/release.sh` renders a binary and a nested library with the answer and
checks the workflow, the binstall metadata, the justfile environment list and the
first-release step. `scripts/render/cases.sh` checks that the validator refuses the pair.
