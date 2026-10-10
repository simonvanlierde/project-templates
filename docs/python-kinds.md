# Python project kinds

The `library`, `app` and `research` kinds are described in the
[README](../README.md#python-project-kinds). This page covers the two kinds that
generate more: `data-pipeline` and `web-service`.

## data-pipeline

Pick this kind when the repository rebuilds a dataset from third-party sources, and
each value must trace back to a download. A `data-pipeline` project gets:

- `sources.toml`, a manifest of every input. Each source has a URL, the publisher's
  reuse terms (`terms`, `terms_url`), and a `status`. A source marked
  `status = "unimplemented"` is one you know about but don't read yet.
- `data/raw/` and `data/processed/`. Both are gitignored, so the repository never
  redistributes source data.
- A small module, standard library only, with three stages:
  - `fetch` writes each download atomically. Beside it, it records the URL, the
    retrieval time, the SHA-256 checksum and the data release the manifest names.
    It refuses a download that misses the `sha256` a source may pin, or one over the
    size cap.
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

The example source in `sources.toml` is about 1 kB. Replace it with your own sources,
and replace the tests that read its output.

## web-service

Pick this kind for an HTTP service that runs as a container. It needs the `docker`
stack. A `web-service` project gets:

- A FastAPI app with one route: `GET /health`. It returns a fixed `{"status": "ok"}`,
  which the image's `HEALTHCHECK` probes.
- An entrypoint that reads `HOST` and `PORT`. It listens on `127.0.0.1` unless `HOST`
  says otherwise. The image sets `HOST=0.0.0.0`, and `compose.yaml` publishes the port
  on `127.0.0.1` only.
- `/docs`, `/redoc` and `/openapi.json` stay off unless `API_DOCS` is set, since they
  list every route to anyone who asks.
- OpenTelemetry through zero-code instrumentation. It turns on only when
  `OTEL_EXPORTER_OTLP_ENDPOINT` is set, and then sends request spans and a
  request-duration histogram over OTLP/HTTP. The SDK reads every other `OTEL_*`
  variable itself. Without the endpoint, nothing is imported.
- `just serve`, and a `<slug>` console script, to run the service outside Docker.
- Tests for `/health`, with telemetry off, and with telemetry on. The telemetry-on test
  uses console exporters in a child process and expects one span and one duration
  point per request.
