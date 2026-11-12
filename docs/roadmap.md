# Roadmap

This is a short view of what is planned for the template over the next year, to October
2027. It is a plan, not a promise, and it changes as needs change. Released work is in
[CHANGELOG.md](https://github.com/simonvanlierde/project-templates/blob/main/CHANGELOG.md).
Ideas and bugs are tracked as GitHub issues.
[GOVERNANCE.md](https://github.com/simonvanlierde/project-templates/blob/main/GOVERNANCE.md)
says who decides what goes here.

Last reviewed: 2026-11-12

## Planned

- Let the `data-pipeline` kind release its data: a `just release` recipe that publishes
  the pipeline's outputs, with CI checks, once sourceledger has a release step.
  Tracked in [#291](https://github.com/simonvanlierde/project-templates/issues/291).
- Add a release path for Rust: a `publish_to_crates` answer, crates.io trusted publishing,
  binaries that `cargo binstall` can find, and attestations.
  Tracked in [#292](https://github.com/simonvanlierde/project-templates/issues/292).
- Register one generated project for the OpenSSF Best Practices badge before the README
  says a fresh render meets it.
  Tracked in [#293](https://github.com/simonvanlierde/project-templates/issues/293).

## Not planned

- A CODEOWNERS file, until other people start contributing.
- Renovate from Actions, release-please and the other pieces generated projects leave
  out, as [ci-baseline.md](ci-baseline.md#what-is-left-out-and-why) explains,
  until the reason given there no longer holds.
