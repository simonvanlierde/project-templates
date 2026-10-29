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
- Add a release path for Rust: a `publish_to_crates` answer, crates.io trusted publishing,
  binaries that `cargo binstall` can find, attestations, and a `cargo-semver-checks` step.
- Register one generated project for the OpenSSF Best Practices badge before the README
  says a fresh render meets it.

## Not planned

- A docs site for library kinds, until one library needs more than its README.
- A CODEOWNERS file, until other people start contributing.
- CodeQL, Renovate from Actions, release-please and the other pieces generated projects
  leave out, as [docs/ci-baseline.md](docs/ci-baseline.md#what-is-left-out-and-why) explains,
  until the reason given there no longer holds.
