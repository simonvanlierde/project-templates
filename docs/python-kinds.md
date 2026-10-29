# Python project kinds

A Python project also asks for a `kind`:

| `kind`          | Pick it when                                                      | It adds                                          |
| --------------- | ----------------------------------------------------------------- | ------------------------------------------------ |
| `library`       | Other projects install and import your package                    | Project URLs, citation files, tests on every supported Python, and the option to publish to PyPI |
| `app`           | You run the code yourself, and nothing imports it                 | Nothing beyond the package                       |
| `research`      | You analyse data in notebooks and manage the data files by hand   | `notebooks/`, `data/`, JupyterLab, citation files |
| `data-pipeline` | You rebuild a dataset from public sources, traceable to each download | A source manifest, fetch, build and validate steps, citation files |
| `web-service`   | You run an HTTP service in a container (needs the `docker` stack)  | A FastAPI app with a `/health` endpoint          |

The citation files are `CITATION.cff`, `.zenodo.json` and `codemeta.json`, rendered from
the same answers. After that, edit `CITATION.cff` only and run `just citation` to write
the other two from it; a git hook fails while they disagree. A library also asks for
`python_min`, the oldest Python it supports: `requires-python` starts there and CI tests
every version up to `python_version`.

## data-pipeline

A `data-pipeline` project gets:

- `sources.toml`, a manifest of every input. Each source has a URL, the publisher's
  reuse terms (`terms`, `terms_url`), the same terms as an SPDX `license`, whether the
  raw file may be republished (`redistribute`), and a `status`. A source marked
  `status = "unimplemented"` is one you know about but don't read yet. The file's
  comments list every key.
- `data/raw/` and `data/processed/`, both gitignored, so the repository never
  redistributes source data, and `data/fetches.jsonl`, committed: the history of every
  version of every source the pipeline has fetched.
- A `pipeline.py` that holds `parse`, the reader for each raw file, and a two-line entry
  point. `parse` hands each file to sourceledger, which reads CSV, JSON and Excel,
  gzipped or not. For any other format, branch on the source's id. The stages come from
  [sourceledger](https://github.com/simonvanlierde/sourceledger), a
  dependency with no dependencies of its own, so fixes to them arrive as a version bump.
  Its README says how each stage behaves:
  - `fetch` downloads each source with retries, writes a provenance record beside it,
    and next time asks the server whether it changed.
  - `build` re-hashes each download against its record, then writes the output with
    five provenance columns in front, and a `datapackage.json` that lists each output
    with its checksum, source and licence.
  - `validate` checks the output against the manifest, the records and the reuse terms.
- `just fetch`, `just build` and `just validate`, and `just pipeline` to run all three.
  `just status` lists each source with its last fetch, and `just attribution` prints the
  table of sources and terms for `ATTRIBUTION.md`.
- `ATTRIBUTION.md`, which states what the repository reuses and on what terms. The
  code license doesn't cover those.
- Tests that run the whole pipeline against a local file, with no network. sourceledger
  tests the stages; these test the project's own parser and entry point.
- A CI workflow that runs the pipeline for real on the manifest's URLs. It uploads only
  the fetch records and, from the weekly run, a revisions report of checksums.
- With the `docker` stack, an image that is a stub. It holds the installed package but
  no `sources.toml` or `data/`, and it starts the `/health` placeholder, not the
  pipeline. To run the stages in it, copy the manifest in and change the `CMD`.

Some tests compare published values with literal numbers. They run only in the weekly
scheduled CI run (`TRIPWIRE=1`). A publisher that revises its data then fails that run,
not your pull requests.

The same weekly run compares what it fetched with the committed `data/fetches.jsonl`.
When a source that the log already has comes back with different bytes, it comments on
one open issue, "Source data revised upstream", with the old and new checksums. Run
`just pipeline` and commit the log to record the new version. `uv run <slug> revisions
<older copy of the log>` prints the same list locally.

The example source in `sources.toml` is about 1 kB. Replace it with your own sources,
and replace the tests that read its output.

## web-service

A `web-service` project gets:

- A FastAPI app with one route: `GET /health`. It returns a fixed `{"status": "ok"}`,
  which the image's `HEALTHCHECK` probes.
- An entrypoint that reads `HOST` and `PORT`. It listens on `127.0.0.1` unless `HOST`
  says otherwise. The image sets `HOST=0.0.0.0`, and `compose.yaml` publishes the port
  on `127.0.0.1` only.
- `/docs`, `/redoc` and `/openapi.json` stay off unless `API_DOCS` is set, because
  they list every route to anyone who asks.
- OpenTelemetry through zero-code instrumentation. It turns on only when
  `OTEL_EXPORTER_OTLP_ENDPOINT` is set, and then sends request spans and a
  request-duration histogram over OTLP/HTTP. The SDK reads every other `OTEL_*`
  variable itself. Without the endpoint, nothing is imported.
- `just serve`, and a `<slug>` console script, to run the service outside Docker.
- Tests for `/health`, with telemetry off, and with telemetry on. The telemetry-on test
  uses console exporters in a child process and expects one span and one duration
  point per request.
