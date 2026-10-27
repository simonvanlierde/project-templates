# Roadmap

This is a short view of what is planned for the template over the next year, to October
2027. It is a plan, not a promise, and it changes as needs change. Released work is in
[CHANGELOG.md](CHANGELOG.md). Ideas and bugs are tracked as GitHub issues.
[GOVERNANCE.md](GOVERNANCE.md) says who decides what goes here.

## Planned

- Move the `data-pipeline` kind to sourceledger 0.3.1 from PyPI once it is a week old,
  so the one-week release-age cutoff lets it in.
- Add a `just release` recipe and its CI checks to the `data-pipeline` kind, once
  sourceledger has a release step.
- Raise the `main` ruleset a public render gets: one required approval, approval after the
  last push, and dismissal of stale reviews. In the same change, let Renovate renders merge
  non-major updates on their own once they are a week old and CI passes.
- Add an accessibility assessment to the `web-app` kind: one row per WCAG 2.2 level A and
  AA criterion, with a result and the evidence for it, linked from the statement.
- Add a release path for Rust: a `publish_to_crates` answer, crates.io trusted publishing,
  binaries that `cargo binstall` can find, attestations, and a `cargo-semver-checks` step.
- Turn off Biome's Markdown and YAML formatters in the rendered `biome.json` when the
  template moves to Biome 2.6, which turns them on by default.
- Get the OpenSSF Best Practices badge at Silver for this repository, and register one
  generated project for the badge before the README says a fresh render meets it.
- Archive v1.0.0 on Zenodo, so the template has a DOI.

## Not planned

- A docs site for library kinds, until one library needs more than its README.
- Issue forms and a CODEOWNERS file, until other people start contributing.
- CodeQL, Renovate from Actions, release-please and the other pieces
  [docs/ci-baseline.md](docs/ci-baseline.md#what-is-left-out-and-why) leaves out, until
  the reason given there no longer holds.
