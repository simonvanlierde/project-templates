# Python project kinds

A Python project asks for a `kind`:

| `kind`          | Pick it when                                                           | What it adds                                                     |
| --------------- | ---------------------------------------------------------------------- | ---------------------------------------------------------------- |
| `library`       | Other projects install and import your package                         | Project URLs, citation files, tests on supported Python versions, and PyPI publishing options |
| `app`           | You run the code yourself and nothing imports it                       | The package structure without publishing metadata                |
| `research`      | You analyse data in notebooks and manage data files manually           | `notebooks/`, `data/`, JupyterLab, citation files                |
| `data-pipeline` | You rebuild a dataset from public sources, traceable to each download  | A source manifest, fetch/build/validate stages, citation files   |
| `web-service`   | You run an HTTP service in a container (requires the `docker` stack)   | A FastAPI app with a `/health` endpoint                          |

When the project has a license, `CITATION.cff` and `codemeta.json` render from your identity answers. Edit `CITATION.cff` only; run `just citation` to sync `codemeta.json`. A git hook fails if either file or `pyproject.toml` disagrees. A library also sets `python_min`: `requires-python` starts there, and CI tests every minor version up to `python_version`.

## data-pipeline

A `data-pipeline` project includes:

- `sources.toml`: a manifest of inputs. Each source records its URL, publisher terms (`terms`, `terms_url`), SPDX `license`, redistribution permission (`redistribute`), and `status`. Set `status = "unimplemented"` for known sources not yet parsed.
- `data/raw/` and `data/processed/`: gitignored directories so raw source data is never committed.
- `data/fetches.jsonl`: committed log recording every fetch of every source version. Governed by `data_license` (CC0-1.0 by default) in `REUSE.toml` ([Licenses](usage.md#licenses)).
- `pipeline.py`: defines `parse` to extract records from raw files and a command entry point. `parse` delegates CSV, JSON, and Excel reading to [sourceledger](https://github.com/simonvanlierde/sourceledger). For other formats, branch on the source ID.
  - `fetch`: downloads sources with retries, writes provenance records, and checks upstream `ETag` and `Last-Modified` headers.
  - `build`: verifies downloads against fetch records, prepends five provenance columns, and emits `datapackage.json` with checksums, sources, and licenses.
  - `validate`: checks output files against the manifest, fetch records, and reuse terms.
- Lifecycle recipes: `just fetch`, `just build`, `just validate`, and `just pipeline` to run all three. `just status` lists source fetch timestamps, and `just attribution` generates the table for `ATTRIBUTION.md`.
- `ATTRIBUTION.md`: documents upstream data sources and reuse terms.
- Tests: verify pipeline execution against local fixtures without network access.
- CI workflow: runs the pipeline against live manifest URLs. Weekly scheduled runs (`TRIPWIRE=1`) check published numbers against expectations and compare fetched data against `data/fetches.jsonl`. When source bytes change, CI reports differences in an issue ("Source data revised upstream"). Run `just pipeline` locally and commit `data/fetches.jsonl` to record the new version. Inspect local changes with `uv run <slug> revisions <older copy of the log>`.
- Docker stub: with the `docker` stack, the image includes the installed package and `/health` stub, but excludes `sources.toml` and `data/`. Copy the manifest into the image and adjust `CMD` to run stages in the container.

Replace the 1 kB example entry in `sources.toml` and its sample tests with your project's sources.

## web-service

A `web-service` project includes:

- A FastAPI app with `GET /health` returning `{"status": "ok"}`, probed by the Docker `HEALTHCHECK`.
- An entrypoint that reads `HOST` and `PORT`. Listens on `127.0.0.1` by default. The Docker image sets `HOST=0.0.0.0`, and `compose.yaml` maps the port to `127.0.0.1`.
- Interactive docs (`/docs`, `/redoc`, `/openapi.json`) disabled by default; set `API_DOCS=1` to enable them.
- OpenTelemetry: zero-code instrumentation activates when `OTEL_EXPORTER_OTLP_ENDPOINT` is set, exporting request spans and duration histograms via OTLP/HTTP. The SDK reads all other `OTEL_*` variables. When unset, telemetry modules are not imported.
- `just serve` and a `<slug>` console script to run outside Docker.
- Tests for `/health` with telemetry enabled and disabled.

## Telemetry scope across kinds

Only the Python `web-service` kind includes OpenTelemetry. Other kinds omit it intentionally:

- **`library`**: provides importable APIs. Applications that consume the library configure telemetry if required.
- **`app` (CLI)**: short-lived commands exit before background span exporters flush.
- **`research`**: exploratory notebook analysis does not need tracing overhead.
- **`data-pipeline`**: batch runs use heartbeat monitoring or dead-man alerts on failure rather than distributed tracing spans.
- **`web-app` (TypeScript)**: client-side tracing is out of scope for the static hosting baseline.

Service kinds for TypeScript, Go, and Rust are not yet implemented. When added, they will follow this zero-code OTLP/HTTP pattern.
