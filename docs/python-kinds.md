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
the same answers. A library also asks for `python_min`, the oldest Python it supports:
`requires-python` starts there and CI tests every version up to `python_version`.

## data-pipeline

A `data-pipeline` project gets:

- `sources.toml`, a manifest of every input. Each source has a URL, the publisher's
  reuse terms (`terms`, `terms_url`), the same terms as an SPDX `license`, whether the
  raw file may be republished (`redistribute`), and a `status`. A source marked
  `status = "unimplemented"` is one you know about but don't read yet.
- `data/raw/` and `data/processed/`. Both are gitignored, so the repository never
  redistributes source data.
- A small module, standard library only, with three stages:
  - `fetch` retries server errors, rate limits (waiting for `Retry-After`, up to
    2 minutes), network errors and a body shorter than its `Content-Length`, with
    backoff. A fetch that still fails names its source and URL. It writes each
    download atomically, so a failed download leaves no partial file. Beside each file
    it writes a record: the URL, the retrieval time, the SHA-256 checksum, the data
    release the manifest names, and the server's `Last-Modified` and `ETag`. The next
    fetch sends those back, and when the server answers that nothing changed, it keeps
    the file and its record. A fetch that brings new bytes also appends its record to
    `data/fetches.jsonl`, which is committed. It refuses a download
    over the size cap (200 MiB, or a source's own `max_bytes`), or one that doesn't
    match the `sha256` a source may pin.
  - `build` verifies the checksums before it parses. It also refuses a download whose
    URL no longer matches the manifest, so you re-fetch after changing a source.
  - `validate` re-reads the published output and re-hashes the raw files.
- `just fetch`, `just build` and `just validate`, and `just pipeline` to run all three.
- `ATTRIBUTION.md`, which states what the repository reuses and on what terms. The
  code license doesn't cover those.
- Tests that run the whole pipeline against a local file, with no network.
- A CI workflow that runs the pipeline for real on the manifest's URLs. It uploads only
  the fetch records.

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
