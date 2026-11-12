"""Tests for check_level.py: small repos written into a temp dir, with made-up content."""

import datetime as dt
import importlib.util
import json
import subprocess
import sys
import tomllib
from pathlib import Path

import jsonschema
import pytest

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("check_level", HERE / "check_level.py")
assert spec
assert spec.loader
check_level = importlib.util.module_from_spec(spec)
sys.modules["check_level"] = check_level
spec.loader.exec_module(check_level)

LEVELS = tomllib.loads((HERE.parent / "levels.toml").read_text())
SCHEMA = json.loads((HERE / "check_level.schema.json").read_text())
NOW = dt.datetime(2027, 3, 1, 9, 30, tzinfo=dt.UTC)

ANSWERS = """\
_commit: v0.14.0
_src_path: gh:simonvanlierde/project-templates
level: {level}
license: MIT
public: true
python_kind: research
stacks:
- python
"""
CI = """\
name: ci
on:
  pull_request:
  push:
    branches: [main]
permissions:
  contents: read
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
        with:
          persist-credentials: false
      - run: uv run pytest
"""
SCORECARD = """\
on:
  push:
    branches: [main]
permissions: read-all
jobs:
  analysis:
    runs-on: ubuntu-latest
    steps:
      - uses: ossf/scorecard-action@v2
"""
CONTRIBUTING = """\
# Contributing to Moonbase Tide Tables

Every pull request that changes behaviour comes with tests.
Code style: ruff formats and lints the code.
"""
# A standard-level research package that meets every file-checkable requirement at its level.
GOOD = {
    ".copier-answers.yml": ANSWERS.format(level="standard"),
    "pyproject.toml": '[project]\nname = "tide-tables"\n',
    "uv.lock": "version = 1\n",
    ".github/dependabot.yml": "version: 2\n",
    ".github/workflows/ci.yml": CI,
    ".github/workflows/scorecard.yml": SCORECARD,
    ".github/workflows/cold-install.yml": CI,
    ".github/SECURITY.md": "Report privately; we reply within a week.\n",
    ".github/CONTRIBUTING.md": CONTRIBUTING,
    ".github/CODE_OF_CONDUCT.md": "Be kind.\n",
    ".github/ISSUE_TEMPLATE/bug.yml": "name: Bug\n",
    ".github/pull_request_template.md": "## What\n",
    "LICENSE": "MIT License\n",
    "CHANGELOG.md": "# Changelog\n\n## [0.1.0]\n",
    "CITATION.cff": "cff-version: 1.2.0\n",
    "codemeta.json": "{}\n",
    "README.md": "# Moonbase Tide Tables\n",
}


def write(root: Path, files: dict[str, str]) -> Path:
    for name, text in files.items():
        (root / name).parent.mkdir(parents=True, exist_ok=True)
        (root / name).write_text(text)
    return root


def run(root: Path, level: str | None = None, traits: tuple[str, ...] = ()) -> dict[str, tuple[str, str]]:
    out = check_level.report(root, LEVELS, NOW, level, traits)
    jsonschema.validate(out, SCHEMA, format_checker=jsonschema.FormatChecker())
    return {r["id"]: (r["status"], r["evidence"]) for r in out["requirements"]}


def statuses(results: dict[str, tuple[str, str]], status: str) -> set[str]:
    return {rid for rid, (s, _) in results.items() if s == status}


def test_good_repo_meets_its_level(tmp_path: Path):
    res = run(write(tmp_path, GOOD))
    assert statuses(res, "met") == {
        "lockfile", "dependency-bot", "workflow-hardening", "scorecard-workflow", "security-policy", "license",
        "community-files", "test-policy", "changelog", "citation-file", "codemeta", "cold-install", "ci-tests",
    }  # fmt: skip
    assert res["license"] == ("met", "LICENSE (MIT)")
    assert res["ci-tests"] == ("met", ".github/workflows/ci.yml")
    assert statuses(res, "missing") == {"dependency-licenses"}
    # Above the level, for traits the repo lacks, or a condition that does not hold.
    assert res["governance"][0] == res["api-break-check"][0] == res["architecture-doc"][0] == "not_applicable"
    assert "community" in res["governance"][1]
    assert res["web-head-tags"] == ("not_applicable", "applies to traits web; the repo has none of them")
    assert res["readme"] == ("unchecked", "a person judges it (verify = review)")
    assert res["python-repo-review"][0] == "unchecked"


def test_bare_repo_misses_requirements(tmp_path: Path):
    res = run(write(tmp_path, {".copier-answers.yml": ANSWERS.format(level="standard"), "pyproject.toml": ""}))
    assert {"lockfile", "dependency-bot", "security-policy", "license", "community-files", "changelog"} <= statuses(
        res, "missing"
    )
    assert res["lockfile"] == ("missing", "pyproject.toml without uv.lock")
    assert res["community-files"] == (
        "missing",
        "no CONTRIBUTING.md, CODE_OF_CONDUCT.md, issue forms, pull request template",
    )
    assert res["workflow-hardening"] == ("not_applicable", "no workflows in .github/workflows")


def test_minimal_level_leaves_standard_requirements_out(tmp_path: Path):
    res = run(write(tmp_path, GOOD | {".copier-answers.yml": ANSWERS.format(level="minimal")}))
    assert res["changelog"] == ("not_applicable", "a standard requirement; the repo is at minimal")
    assert res["lockfile"][0] == "met"


def test_no_answers_is_off_the_ladder_unless_level_is_given(tmp_path: Path):
    files = {k: v for k, v in GOOD.items() if k != ".copier-answers.yml"}
    root = write(tmp_path, files)
    assert statuses(run(root), "not_applicable") == set(LEVELS["requirement"])
    res = run(root, level="community", traits=("package",))
    assert res["governance"] == ("missing", "no GOVERNANCE.md")
    assert res["api-break-check"][0] == "missing"
    assert res["citation-file"][0] == "met"


def test_workflow_hardening_names_each_problem(tmp_path: Path):
    bad = "on: [pull_request_target]\njobs:\n  x:\n    runs-on: ubuntu-latest\n    steps:\n"
    bad += "      - uses: actions/checkout@v6\n"
    status, evidence = run(write(tmp_path, GOOD | {".github/workflows/bad.yml": bad}))["workflow-hardening"]
    assert status == "missing"
    assert "bad.yml runs on pull_request_target" in evidence
    assert "no permissions: block" in evidence
    assert "without persist-credentials: false in job(s) x" in evidence


def test_architecture_doc_counts_code_files_and_checks_named_paths(tmp_path: Path):
    code = {f"src/tides/m{i}.py": "" for i in range(40)}
    assert run(write(tmp_path, GOOD | code))["architecture-doc"][0] == "missing"
    doc = "# Architecture\n\n```mermaid\ngraph LR\n```\n\n`src/tides/m1.py` and `src/tides/gone.py`\n"
    res = run(write(tmp_path, {"docs/architecture.md": doc}))
    assert res["architecture-doc"] == ("missing", "docs/architecture.md: names src/tides/gone.py, which is gone")


def test_roadmap_issue_links(tmp_path: Path):
    answers = {".copier-answers.yml": ANSWERS.format(level="community")}
    roadmap = "Last reviewed: 2027-01-15\n\n## Next year\n\n- Lunar tides https://github.com/example/tides/issues/4\n"
    res = run(write(tmp_path, GOOD | answers | {"docs/roadmap.md": roadmap}))
    assert res["roadmap"] == ("met", "docs/roadmap.md")
    assert res["roadmap-issue-links"][0] == "unchecked"
    res = run(write(tmp_path, {"docs/roadmap.md": roadmap + "- Solar tides\n"}))
    assert res["roadmap-issue-links"] == ("missing", "theme links no issue: Solar tides")


def test_every_automated_requirement_has_a_check_or_a_reason():
    automated = {rid for rid, r in LEVELS["requirement"].items() if r["verify"] == "automated"}
    assert automated <= set(check_level.CHECKS) | set(check_level.UNCHECKED)


def test_main_exit_codes(tmp_path: Path, capsys: pytest.CaptureFixture[str]):
    assert check_level.main([str(write(tmp_path, GOOD))]) == 0
    out = json.loads(capsys.readouterr().out)
    assert (out["repo"], out["level"], out["traits"]) == (tmp_path.name, "standard", ["numerics"])
    assert check_level.main([str(tmp_path / "nowhere")]) == 3
    assert capsys.readouterr().err.startswith("error: ")
    with pytest.raises(SystemExit) as e:
        check_level.main([str(tmp_path), "--level", "gold"])
    assert e.value.code == 2


@pytest.mark.parametrize(
    "step",
    [
        'uv run --locked --with licensecheck==2025.1.0 licensecheck -r "$RUNNER_TEMP/requirements.txt" --zero',
        "pnpm run licenses",
        "cargo deny list",
        "go run github.com/google/go-licenses/v2@v2.0.1 check ./...",
    ],
)
def test_dependency_licenses_finds_the_template_steps(tmp_path: Path, step: str):
    ci = CI.replace("uv run pytest", step)
    res = run(write(tmp_path, GOOD | {".github/workflows/ci.yml": ci}))
    assert res["dependency-licenses"] == ("met", ".github/workflows/ci.yml")


def test_a_tracked_file_deleted_from_the_checkout_is_not_read(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    # Run from a git hook, an inherited GIT_DIR or GIT_INDEX_FILE would point git at this repo.
    monkeypatch.setenv("GIT_INDEX_FILE", str(tmp_path / "wrong-index"))
    env = check_level.without_git_env()
    root = write(tmp_path, GOOD)
    subprocess.run(["git", "init", "-q", str(root)], check=True, env=env)  # noqa: S603, S607
    subprocess.run(["git", "-C", str(root), "add", "."], check=True, env=env)  # noqa: S603, S607
    (root / ".github/CONTRIBUTING.md").unlink()
    assert run(root)["test-policy"] == ("missing", "no CONTRIBUTING.md")


def test_axe_scan_is_not_found_in_unrelated_names(tmp_path: Path):
    web = {".copier-answers.yml": ANSWERS.format(level="standard") + "site: docs\n"}
    files = GOOD | web | {"docs/accessibility.md": "x\n", "src/taxes.py": ""}
    assert run(write(tmp_path, files))["accessibility-statement"] == ("missing", "no axe scan")


def test_dual_license_files_count_as_a_license(tmp_path: Path):
    files = {k: v for k, v in GOOD.items() if k != "LICENSE"} | {"LICENSE-MIT": "MIT\n", "LICENSE-APACHE": "Apache\n"}
    assert run(write(tmp_path, files))["license"] == ("met", "LICENSE-APACHE, LICENSE-MIT (MIT)")
