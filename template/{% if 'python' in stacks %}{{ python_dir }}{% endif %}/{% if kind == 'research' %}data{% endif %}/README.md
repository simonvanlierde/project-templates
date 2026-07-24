# data

`raw/` is read-only input, never edited in place. `processed/` is derived and
reproducible from `raw/` plus the notebooks, so it is safe to delete.

Record the provenance of anything in `raw/` here. Add these directories to
`.gitignore` if the inputs are large or private.
