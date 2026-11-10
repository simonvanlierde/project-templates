# shellcheck shell=bash
# shellcheck disable=SC2154,SC2164 # check-render.sh sets out, repo, copier and set -e
# Checks every render parses and every workflow keeps its caches off pull requests.
# Runs from the repo root, after cases.sh.

OUT=$out uv run --no-project --with pyyaml --with json5 python - <<'PY'
import ast, collections, itertools, json, json5, os, pathlib, subprocess, tempfile, tomllib, yaml

load = {".json": json.loads, ".json5": json5.loads, ".toml": tomllib.loads,
        ".yml": yaml.safe_load, ".yaml": yaml.safe_load}
seen = 0
out = pathlib.Path(os.environ["OUT"])
# Every render, found by its answers file, so a new case gets every check below.
renders = sorted(answers.parent for answers in out.glob("*/.copier-answers.yml"))
for render in renders:
    for path in sorted(render.rglob("*")):
        # The site builds install packages and write pnpm's multi-document lockfile; neither is template output.
        if "node_modules" in path.parts or path.name == "pnpm-lock.yaml":
            continue
        # tsconfig is JSON with comments, as tsc and Biome read it.
        parse = json5.loads if path.name.startswith("tsconfig") else load.get(path.suffix)
        if parse and path.is_file():
            parse(path.read_text())
            seen += 1
print(f"parsed {seen} files")
# Catches a copier run that rendered nothing.
assert seen > 20, f"only {seen} structured files rendered"
# The title literal, in whichever quote style Jinja picked, evaluates back to the name.
app = next(out.glob("b/svc/src/*/app.py"))
title = next(k for k in ast.walk(ast.parse(app.read_text())) if isinstance(k, ast.keyword) and k.arg == "title")
assert ast.literal_eval(title.value) == 'Odd "Name" & Co!', ast.unparse(title.value)
# No schema covers codemeta.json, so check the CodeMeta context.
codemeta = json.loads((out / "a/codemeta.json").read_text())
assert codemeta["@context"] == "https://w3id.org/codemeta/3.0", codemeta
# A leading space in the author name must not leave the given name empty.
assert codemeta["author"][0]["givenName"] == "Ada", codemeta
assert "given-names: \"Ada\"" in (out / "a/CITATION.cff").read_text()
# The push job holds the write scopes and reads no cache on a tag. trivy-action restores
# its database from the Actions cache, so the scan stays in the build job.
docker = yaml.safe_load((out / "c/.github/workflows/docker.yml").read_text())["jobs"]
assert any("trivy-action" in s.get("uses", "") for s in docker["build"]["steps"]), docker["build"]
assert not any("trivy-action" in s.get("uses", "") for s in docker["push"]["steps"]), docker["push"]
# PyPI finishes before GitHub becomes immutable; the write job executes no project code.
python_release = yaml.safe_load((out / "c/.github/workflows/python-release.yml").read_text())["jobs"]
release = python_release["release"]
assert python_release["publish"]["needs"] == ["build", "test"], python_release["publish"]
assert not any("uv sync" in s.get("run", "") for s in python_release["build"]["steps"]), python_release["build"]
assert any("uv sync --locked" in s.get("run", "") for s in python_release["test"]["steps"]), python_release["test"]
assert release["needs"] == "publish", release
assert release["permissions"] == {"contents": "write"}, release
assert not any("checkout" in s.get("uses", "") for s in release["steps"]), release
publish_script = release["steps"][-1]["run"]
verify = ["verify"] * 4
for fail, expected in [("", ["create", *verify, "edit"]), ("create", ["create"]),
                       ("verify", ["create", "verify"])]:
    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(tmp)
        for directory in ("assets", "provenance", "sbom-attestation", "notes", "bin"):
            (work / directory).mkdir()
        for asset in ("package.whl", "package.tar.gz", "package.tar.gz.cdx.json"):
            (work / "assets" / asset).touch()
        (work / "provenance/bundle.json").write_text("{}")
        (work / "sbom-attestation/bundle.json").write_text("{}")
        (work / "notes/notes.md").write_text("Release notes")
        gh = work / "bin/gh"
        gh.write_text('#!/bin/sh\nprintf "%s\\n" "$2" >>"$(dirname "$0")/../calls"\n'
                      'test "$2" != "$FAIL" || exit 1\n')
        gh.chmod(0o755)
        result = subprocess.run(["bash", "-c", publish_script], cwd=work,
                                env={"PATH": f"{work / 'bin'}:/usr/bin:/bin", "TAG": "v1.2.3", "GH_REPO": "o/r",
                                     "FAIL": fail}, check=False)
        assert (result.returncode != 0) == bool(fail), result
        assert (work / "calls").read_text().splitlines() == expected
        # Every asset carries a bundle under its own name; the SBOM's rides on the sdist.
        for bundle in ("package.whl", "package.tar.gz", "package.tar.gz.cdx.json"):
            assert (work / f"assets/{bundle}.intoto.jsonl").is_file()
        assert (work / "assets/package.tar.gz.sbom.intoto.jsonl").is_file()
# A ruleset requires a check by its job name, so two jobs with one name can't be told
# apart.
for render in renders:
    names = {}
    for wf in sorted((render / ".github/workflows").glob("*.yml")):
        for job_id, job in yaml.safe_load(wf.read_text())["jobs"].items():
            if "name" in job:
                names.setdefault(job["name"], []).append(f"{wf.name}:{job_id}")
    dupes = {n: where for n, where in names.items() if len(where) > 1}
    assert not dupes, f"{render}: jobs share a name: {dupes}"
# Every check a ruleset requires is one a rendered workflow reports. GitHub names a
# matrix job's runs "<name> (<value>, ...)" when the name holds no matrix expression.
required_by = collections.defaultdict(list)
for checks in sorted(out.glob("*/.github/rulesets/main*.json")):
    render = checks.parents[2]
    runs = set()
    for wf in (render / ".github/workflows").glob("*.yml"):
        for job in yaml.safe_load(wf.read_text())["jobs"].values():
            name = job.get("name")
            matrix = {k: v for k, v in job.get("strategy", {}).get("matrix", {}).items() if isinstance(v, list)}
            if not name:
                continue
            if matrix and "${{" not in name:
                for combo in itertools.product(*matrix.values()):
                    runs.add(f"{name} ({', '.join(map(str, combo))})")
            else:
                runs.add(name)
    for rule in json.loads(checks.read_text())["rules"]:
        for required in rule.get("parameters", {}).get("required_status_checks", []):
            assert required["context"] in runs, f"{checks}: {required['context']!r} is no job's check run"
            required_by[render].append(required["context"])
# Every render was checked, and each requires some check: an empty list passes the loop above.
assert len(renders) >= 18 and set(required_by) == set(renders), sorted(map(str, set(renders) - set(required_by)))
# A pull request saves no cache: only it could read one, and it evicts main's. Each
# action that caches by default must carry its switch. CodSpeed's instrument cache has
# no save switch and is left on. A job whose `if` excludes pull requests outright (an
# `&&` chain with no `||`) is skipped, like docker.yml's push job.
off_pr = "${{ github.event_name != 'pull_request' }}"
saves = {
    "actions/cache": lambda w, cond: "github.event_name != 'pull_request'" not in cond,
    "actions/cache/save": lambda w, cond: "github.event_name != 'pull_request'" not in cond,
    "astral-sh/setup-uv": lambda w, cond: w.get("enable-cache") is not False and w.get("save-cache") != off_pr,
    "Swatinem/rust-cache": lambda w, cond: w.get("save-if") != off_pr,
    "actions/setup-node": lambda w, cond: bool(w.get("cache")),
    "actions/setup-go": lambda w, cond: w.get("cache") is not False,
    "golangci/golangci-lint-action": lambda w, cond: w.get("skip-save-cache") != "${{ github.event_name == 'pull_request' }}",
    "j178/prek-action": lambda w, cond: w.get("cache") is not False,
    "aquasecurity/trivy-action": lambda w, cond: w.get("cache") != off_pr,
    "docker/build-push-action": lambda w, cond: bool(w.get("cache-to")) and "github.event_name == 'push'" not in w["cache-to"],
}
checked = collections.Counter()
for render in renders:
    for wf in sorted((render / ".github/workflows").glob("*.yml")):
        doc = yaml.safe_load(wf.read_text())
        if "pull_request" not in doc[True]:
            continue
        for job_id, job in doc["jobs"].items():
            job_if = str(job.get("if", ""))
            if "github.event_name != 'pull_request'" in job_if and "||" not in job_if:
                continue
            for step in job.get("steps", []):
                uses = step.get("uses", "").split("@")[0]
                check = saves.get(uses)
                if check:
                    checked[uses] += 1
                if check and check(step.get("with") or {}, str(step.get("if", ""))):
                    raise AssertionError(f"{render}/{wf.name}:{job_id}: {step['uses']} saves a cache on pull requests")
# The steps the table matched, so a renamed action or a moved job can't empty the check.
assert checked["docker/build-push-action"] >= 1, checked
assert sum(checked.values()) >= 70, checked  # 75 when this was written
PY

# This repo lints its own YAML with the config a project with pnpm gets.
diff .yamlfmt "$out/t/.yamlfmt"
diff .yamllint.yml "$out/t/.yamllint.yml"
