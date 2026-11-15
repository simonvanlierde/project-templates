# The CML golden path

CML is the Institute of Environmental Sciences at Leiden University, whose software repos live in the `CMLPlatform` GitHub organisation. This page is the one route a CML repo takes with this template, from the first render to a running, monitored service. It is the second audience of [decision 0008](decisions/0008-three-audiences-in-order.md): the template becomes the golden path for CML repos once three of them render from it and update through their weekly PR.

Each step names where the detail lives. This page adds no settings of its own.

## The route

1. **Render.** Run `copier copy` from a pushed release tag, with a [preset or your own answers](usage.md#presets). A research package or data pipeline picks the `research` or `data-pipeline` [kind](python-kinds.md); a service picks `web-service`. Run `just check`.
2. **Layer the CML files.** Contacts, org defaults and telemetry belong to a separate CML template applied after this one, with its own `.copier-answers.cml.yml` ([Layering another template](usage.md#layering-another-template)). This template stays free of any one organisation's setup. The weekly `copier-update` PR updates both answers files ([Updates](updates.md#keeping-your-project-up-to-date)).
3. **CI.** Every render gets the CI workflows and git hooks in [CI checks](ci-baseline.md#what-every-scaffold-gets): pinned actions, least-privilege permissions, lint, types, tests and dependency audits for each stack. There is no cross-repo reusable workflow: each repo carries its own copy and `copier update` keeps the copies current.
4. **Citation.** A licensed library, research package or data pipeline renders `CITATION.cff` and `codemeta.json`, kept consistent by `citesync` ([Public repositories and citation](ci-baseline.md#public-repositories-and-citation)).
5. **Signed release.** Add your SSH signing key to `.github/allowed_signers`, then run `just release X.Y.Z` twice, before and after the merge. CI publishes only from a tag that key signed, with Sigstore provenance ([Publishing](setup.md#publishing), [Signed release tags](setup.md#signed-release-tags), [First release](setup.md#first-release)).
6. **Container.** The `docker` stack builds a Python image, scanned with Trivy, and with `publish_to_ghcr` pushes it to GitHub Container Registry with an attestation ([Choosing your stacks](usage.md#choosing-your-stacks), [CI checks](ci-baseline.md)).
7. **Deploy.** A server that runs images without building them uses a [Compose-only repo](usage.md#compose-only-repos) with the `compose-deploy.yml` preset. A static site or web app deploys from `main` as [Hosting](hosting.md) describes.
8. **Telemetry.** A `web-service` exports traces and request-duration histograms over OTLP when `OTEL_EXPORTER_OTLP_ENDPOINT` is set. Point it at the CML monitoring hub and set `OTEL_RESOURCE_ATTRIBUTES` to `project=<slug>,env=production`, the two keys the hub uses to tell projects and environments apart ([web-service telemetry](python-kinds.md#web-service)). The hub's Alloy spoke template lives with the monitoring hub and is applied as the CML layer; its steps are in that repo, not here.

## Adoption count

[Issue #221](https://github.com/simonvanlierde/project-templates/issues/221) measures adoption against the inventory of the `CMLPlatform` organisation taken on 2026-09-27: CI in 5 of 19 repos and a `CITATION.cff` in 1. The count is repeated every quarter, and the next one is due in 2027-01. The recount is a queue task, not template code, so it lives with the agent task queue rather than in this repo.
