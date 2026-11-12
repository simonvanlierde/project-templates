# Python project kinds

A Python project asks for a `kind`:

| `kind`          | Pick it when                                                           | What it adds                                                     |
| --------------- | ---------------------------------------------------------------------- | ---------------------------------------------------------------- |
| `library`       | Other projects install and import your package                         | Project URLs, citation files, tests on supported Python versions, and PyPI publishing options |
| `app`           | You run the code yourself and nothing imports it                       | The package structure without publishing metadata                |
| `research`      | You analyse data in notebooks and manage data files manually           | `notebooks/`, `data/`, JupyterLab, citation files                |
| `data-pipeline` | You rebuild a dataset from public sources, traceable to each download  | A source manifest, fetch/build/validate stages, citation files   |
| `web-service`   | You run an HTTP service in a container (requires the `docker` stack)   | A FastAPI app with a `/health` endpoint                          |

Licensed Python `library`, `research` and `data-pipeline` projects get `CITATION.cff`, `codemeta.json` and `just citation`. An `app` or `web-service` gets them only when another selected stack has a library kind and the project has a license.

The citation files render from your identity answers. Edit `CITATION.cff` only; run `just citation` to sync `codemeta.json`. A git hook fails if either file or `pyproject.toml` disagrees.

A Python library also sets `python_min`: `requires-python` starts there, and CI tests every minor version up to `python_version`.

## data-pipeline

A `data-pipeline` project includes:

- `sources.toml`: a manifest of inputs. Each source records its URL, publisher terms (`terms`, `terms_url`), SPDX `license`, redistribution permission (`redistribute`), and `status`. Set `status = "unimplemented"` for known sources not yet parsed.
- `data/raw/` and `data/processed/`: gitignored directories so raw source data is never committed.
- `data/fetches.jsonl`: committed log recording every fetch of every source version. Governed by `data_license` (CC0-1.0 by default) in `REUSE.toml` ([Licenses](usage.md#licenses)).
- `pipeline.py`: defines `parse` to extract records from raw files and a command entry point. `parse` delegates CSV, JSON, and Excel reading to [sourceledger](https://github.com/simonvanlierde/sourceledger). For other formats, branch on the source ID.
  - `fetch`: downloads sources with retries, writes provenance records, and checks upstream `ETag` and `Last-Modified` headers.
  - `build`: verifies downloads against fetch records, prepends five provenance columns, writes `data/processed/<id>.parquet`, and emits `datapackage.json` with checksums, sources, and licenses.
    Set `output_format = "csv"` at the top of `sources.toml` to write CSV instead.
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
- OpenTelemetry: zero-code instrumentation activates when `OTEL_EXPORTER_OTLP_ENDPOINT` is set, exporting request spans and duration histograms via OTLP/HTTP. To send to a collector, set the standard OpenTelemetry variables:
  - `OTEL_EXPORTER_OTLP_ENDPOINT`: the collector's URL, such as `http://otel-collector:4318` or `https://monitoring.example.org:4318`.
  - `OTEL_EXPORTER_OTLP_HEADERS`: authentication headers, if the collector needs them (`Authorization=Bearer ...`).
  - `OTEL_EXPORTER_OTLP_PROTOCOL`: the export protocol. The entrypoint defaults it to `http/protobuf`.
  - `OTEL_RESOURCE_ATTRIBUTES`: comma-separated attributes on every span. `compose.yaml` defaults it to `project=<slug>,env=dev`, the two keys a monitoring hub uses to tell projects and environments apart. Set `env` to `production` or similar where you deploy.
  When `OTEL_EXPORTER_OTLP_ENDPOINT` is unset, telemetry modules are not imported.
- `just serve` and a `<slug>` console script to run outside Docker.
- Tests for `/health` with telemetry enabled and disabled.

No other kind, in any stack, includes OpenTelemetry.
