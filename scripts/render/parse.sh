# shellcheck shell=bash
# shellcheck disable=SC2154,SC2164 # check-render.sh sets out, repo, copier and set -e
# Checks every render parses and every workflow keeps its caches off pull requests.
# Runs from the repo root, after cases.sh.

OUT=$out uv run --no-project --with pyyaml --with json5 python - <<'PY'
import ast, collections, itertools, json, json5, os, pathlib, subprocess, tempfile, tomllib, yaml

load = {".json": json.loads, ".json5": json5.loads, ".jsonc": json5.loads, ".toml": tomllib.loads,
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
# Every attestation is checked before the draft exists, so a failed check leaves nothing to delete.
# `view` asks whether an earlier run left a draft (VIEW=true), published the release (VIEW=false) or
# made none (nothing printed). A failed `view` is an error, not "no release". A failed verify is retried
# three times, with the sleep faked.
for fail, view, expected in [("", "", [*verify, "view", "create", "edit"]),
                             ("", "true", [*verify, "view", "delete", "create", "edit"]),
                             ("", "false", [*verify, "view"]),
                             ("view", "", [*verify, "view"]),
                             ("create", "", [*verify, "view", "create"]),
                             ("verify", "", ["verify"] * 3)]:
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
                      'test "$2" != "$FAIL" || exit 1\n'
                      'test "$2" != view || test -z "$VIEW" || echo "$VIEW"\n')
        gh.chmod(0o755)
        sleep = work / "bin/sleep"
        sleep.write_text("#!/bin/sh\n")
        sleep.chmod(0o755)
        result = subprocess.run(["bash", "-c", publish_script], cwd=work,
                                env={"PATH": f"{work / 'bin'}:/usr/bin:/bin", "TAG": "v1.2.3", "GH_REPO": "o/r",
                                     "FAIL": fail, "VIEW": view}, check=False)
        assert (result.returncode != 0) == bool(fail), result
        assert (work / "calls").read_text().splitlines() == expected
        # Every asset carries a bundle under its own name; the SBOM's rides on the sdist.
        for bundle in ("package.whl", "package.tar.gz", "package.tar.gz.cdx.json"):
            assert (work / f"assets/{bundle}.intoto.jsonl").is_file()
        assert (work / "assets/package.tar.gz.sbom.intoto.jsonl").is_file()
# A re-run that finds the version on a registry goes on only when the registry holds this build's
# bytes, and publishes when it holds nothing. The fakes stand in for curl, npm and cargo.
import hashlib
def step(path, job, name):
    jobs = yaml.safe_load((out / path).read_text())["jobs"]
    return next(x["run"] for x in jobs[job]["steps"] if x.get("name") == name)
def run_step(script, work, env, fakes):
    (work / "bin").mkdir()
    for name, body in fakes.items():
        fake = work / "bin" / name
        fake.write_text("#!/bin/sh\n" + body)
        fake.chmod(0o755)
    base = {"PATH": f"{work / 'bin'}:/usr/bin:/bin:/usr/local/bin", "RUNNER_TEMP": str(work)}
    return subprocess.run(["bash", "-c", script], cwd=work, env={**base, **env}, check=False,
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
# The optional files travel from build to the attestation and reach the release with their bundles.
extra_workflow = "release-assets/.github/workflows/python-release.yml"
extra_jobs = yaml.safe_load((out / extra_workflow).read_text())["jobs"]
assert not any(s.get("with", {}).get("name", "").startswith("release-extra-")
               for job in python_release.values() for s in job["steps"]), python_release
for job, paths in (
    ("build", ["api/export/", "api/metadata/generated/"]),
    ("publish", ["export/", "metadata/generated/"]),
    ("release", ["${{ runner.temp }}/release-extra-1/", "${{ runner.temp }}/release-extra-2/"]),
):
    transfers = [s["with"] for s in extra_jobs[job]["steps"]
                 if s.get("with", {}).get("name", "").startswith("release-extra-")]
    assert [s["name"] for s in transfers] == ["release-extra-1", "release-extra-2"], transfers
    assert [s["path"] for s in transfers] == paths, transfers
attest = next(s["with"] for s in extra_jobs["publish"]["steps"] if s.get("id") == "attest")
assert attest["subject-path"].splitlines() == ["dist/*", "sbom/*", "export/*", "metadata/generated/*"], attest
collect = step(extra_workflow, "build", "collect extra release assets")
digest = next(s["run"] for s in extra_jobs["build"]["steps"] if s.get("id") == "digest")
check = step(extra_workflow, "publish", "refuse artifacts that changed after the build")
for fault in ("", "missing", "duplicate", "duplicate-case", "symlink", "bundle", "oversize", "too-many", "count-limit"):
    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(tmp)
        pkg = work / "api"
        for directory in ("dist", "sbom"):
            (pkg / directory).mkdir(parents=True)
        (pkg / "dist/pkg.tar.gz").write_text("sdist")
        (pkg / "sbom/pkg.tar.gz.cdx.json").write_text("sbom")
        # The repo's optional hook must run at the configured Python working directory.
        scripts = work / ".github/scripts"
        scripts.mkdir(parents=True)
        (scripts / "build-release-assets.sh").write_text(
            "mkdir -p export metadata/generated\n"
            "printf maps >export/maps.tar.gz\n"
            "printf sums >metadata/generated/SHA256SUMS\n"
            + {"": "", "missing": "rm export/maps.tar.gz\nrmdir export\n",
               "duplicate": "cp export/maps.tar.gz metadata/generated/maps.tar.gz\n",
               "duplicate-case": "cp export/maps.tar.gz metadata/generated/MAPS.tar.gz\n",
               "symlink": "ln -s ../dist/pkg.tar.gz export/link\n",
               "bundle": "touch export/file.intoto.jsonl\n",
               "oversize": "truncate -s 2147483648 export/maps.tar.gz\n",
               "too-many": 'for i in {1..496}; do touch "export/file-$i"; done\n',
               "count-limit": 'for i in {1..495}; do touch "export/file-$i"; done\n'}[fault]
        )
        env = {"PATH": "/usr/bin:/bin", "GITHUB_WORKSPACE": str(work), "GITHUB_OUTPUT": str(work / "output")}
        collected = subprocess.run(["bash", "-c", collect], cwd=pkg, env=env, capture_output=True, check=False)
        assert (collected.returncode == 0) == (fault in ("", "count-limit")), collected
        if fault == "duplicate-case":
            assert b"Duplicate release asset name" in collected.stdout, collected
        if fault == "oversize":
            assert b"must be under 2 GiB" in collected.stdout, collected
        if fault == "too-many":
            assert b"at most 499 payload files" in collected.stdout, collected
        if fault:
            continue
        subprocess.run(["bash", "-c", digest], cwd=pkg, env=env, check=True)
        env["EXPECTED"] = (work / "output").read_text().strip().removeprefix("value=")
        subprocess.run(["bash", "-c", check], cwd=pkg, env=env, check=True)
        (pkg / "metadata/generated/SHA256SUMS").write_text("changed")
        assert subprocess.run(["bash", "-c", check], cwd=pkg, env=env, check=False).returncode != 0
        (pkg / "export/maps.tar.gz").unlink()
        assert subprocess.run(["bash", "-c", check], cwd=pkg, env=env, capture_output=True, check=False).returncode != 0
with tempfile.TemporaryDirectory() as tmp:
    work = pathlib.Path(tmp)
    for directory in ("assets", "provenance", "sbom-attestation", "notes", "release-extra-1", "release-extra-2"):
        (work / directory).mkdir()
    for asset in ("assets/pkg.tar.gz", "assets/pkg.tar.gz.cdx.json", "provenance/bundle.json",
                  "sbom-attestation/bundle.json", "notes/notes.md", "release-extra-1/maps.tar.gz",
                  "release-extra-2/SHA256SUMS"):
        (work / asset).touch()
    publish_extra = step(extra_workflow, "release", "publish the GitHub release")
    result = run_step(publish_extra, work, {"TAG": "v1.2.3", "GH_REPO": "o/r"}, {
        "gh": 'case "$2" in verify) echo "$3" >>../verified ;; esac\n',
    })
    assert result.returncode == 0, result
    verified = (work / "verified").read_text().splitlines()
    assert collections.Counter(verified) == {"maps.tar.gz": 1, "SHA256SUMS": 1, "pkg.tar.gz": 2,
                                              "pkg.tar.gz.cdx.json": 1}, verified
    assert (work / "assets/maps.tar.gz.intoto.jsonl").is_file()
    assert (work / "assets/SHA256SUMS.intoto.jsonl").is_file()
# curl writes the body to the file after -o and prints the status (CODE) the way -w does.
curl = 'while [ $# -gt 0 ]; do [ "$1" = -o ] && out=$2; shift; done\nprintf %s "$BODY" >"$out"\nprintf %s "$CODE"\n'
pypi = step("c/.github/workflows/python-release.yml", "publish", "refuse a file PyPI has with other content")
wheel = b"wheel bytes"
sha = hashlib.sha256(wheel).hexdigest()
for code, body_sha, ok in [("404", "", True), ("200", sha, True), ("200", "0" * 64, False), ("503", "", False)]:
    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(tmp)
        (work / "dist").mkdir()
        (work / "dist/pkg-1.0.0-py3-none-any.whl").write_bytes(wheel)
        body = json.dumps({"urls": [{"filename": "pkg-1.0.0-py3-none-any.whl", "digests": {"sha256": body_sha}}]})
        result = run_step(pypi, work, {"TAG": "v1.0.0", "CODE": code, "BODY": body}, {"curl": curl})
        assert (result.returncode == 0) == ok, (code, body_sha, result)
npm = step("c/.github/workflows/ts-release.yml", "publish", "publish to npm")
import base64
for remote, expected_calls, ok in [("", ["publish"], True), ("same", [], True), ("sha512-other", [], False)]:
    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(tmp)
        pack = work / "pkg"
        (pack / "package").mkdir(parents=True)
        (pack / "package/package.json").write_text('{"name":"pkg","version":"1.0.0"}')
        subprocess.run(["tar", "-czf", str(work / "pkg-1.0.0.tgz"), "-C", str(pack), "package"], check=True)
        mine = "sha512-" + base64.b64encode(hashlib.sha512((work / "pkg-1.0.0.tgz").read_bytes()).digest()).decode()
        value = mine if remote == "same" else remote
        fake_npm = ('echo "$1" >>"$(dirname "$0")/../calls"\n'
                    'if [ "$1" = view ]; then test -n "$REMOTE" && echo "$REMOTE" || exit 1; fi\n')
        result = run_step(npm, work, {"REMOTE": value}, {"npm": fake_npm})
        calls = [c for c in (work / "calls").read_text().splitlines() if c != "view"] if (work / "calls").exists() else []
        assert (result.returncode == 0) == ok and calls == expected_calls, (remote, calls, result)
crates = step("cb/.github/workflows/rust-release.yml", "publish", "publish to crates.io")
name = tomllib.loads((out / "cb/Cargo.toml").read_text())["package"]["name"]
crate_bytes = b"crate bytes"
crate_sha = hashlib.sha256(crate_bytes).hexdigest()
for code, remote_sha, expected_calls, ok in [("404", "", ["publish"], True), ("200", crate_sha, [], True),
                                              ("200", "0" * 64, [], False), ("500", "", [], False)]:
    with tempfile.TemporaryDirectory() as tmp:
        work = pathlib.Path(tmp)
        body = json.dumps({"version": {"checksum": remote_sha}})
        fake_cargo = ('echo "$1" >>"$(dirname "$0")/../calls"\n'
                      f'if [ "$1" = package ]; then mkdir -p "$RUNNER_TEMP/target/package"; printf %s "$CRATE" >"$RUNNER_TEMP/target/package/{name}-1.0.0.crate"; fi\n')
        result = run_step(crates, work, {"GITHUB_REF_NAME": "v1.0.0", "CODE": code, "BODY": body,
                                         "CRATE": crate_bytes.decode()}, {"curl": curl, "cargo": fake_cargo})
        calls = [c for c in (work / "calls").read_text().splitlines() if c != "package"] if (work / "calls").exists() else []
        assert (result.returncode == 0) == ok and calls == expected_calls, (code, remote_sha, calls, result)
# Nothing is published before the tag is verified: the gate runs right after checkout in
# the first job, and the job that publishes is that job or waits for it.
def waits_for(jobs, job, gate):
    todo, seen = [job], set()
    while todo:
        name = todo.pop()
        if name not in seen:
            seen.add(name)
            need = jobs[name].get("needs", [])
            todo += [need] if isinstance(need, str) else need
    return gate in seen
for path, publisher in [("c/.github/workflows/python-release.yml", "publish"),
                        ("c/.github/workflows/ts-release.yml", "publish"),
                        ("c/.github/workflows/docker.yml", "push"), ("a/.github/workflows/release.yml", "release")]:
    jobs = yaml.safe_load((out / path).read_text())["jobs"]
    gates = [(job, i) for job, body in jobs.items() for i, step in enumerate(body["steps"])
             if "verify-tag.sh" in step.get("run", "")]
    assert len(gates) == 1, (path, gates)
    (gate_job, at), = gates
    assert "continue-on-error" not in jobs[gate_job], (path, gate_job)
    assert "continue-on-error" not in jobs[gate_job]["steps"][at], (path, gate_job)
    before = [step.get("uses", "").split("@")[0] for step in jobs[gate_job]["steps"][:at]]
    assert before == ["actions/checkout"], (path, before)
    assert waits_for(jobs, publisher, gate_job), (path, publisher, gate_job)
# Each preset's answers are what its render recorded, so a renamed question can't drop one
# silently.
for preset in sorted(pathlib.Path("presets").glob("*.yml")):
    recorded = yaml.safe_load((out / f"preset-{preset.stem}/.copier-answers.yml").read_text())
    for key, value in yaml.safe_load(preset.read_text()).items():
        assert recorded.get(key) == value, (preset.name, key, value, recorded.get(key))
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
