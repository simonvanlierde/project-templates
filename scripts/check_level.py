#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pyyaml==6.0.3"]
# ///
# ruff: noqa: PLR2004 -- the string literals are file names and answer values, clearer inline than as constants
"""Check a repo against the requirements in levels.toml and print the results as JSON.

Usage: scripts/check_level.py [--levels FILE] [--level LEVEL] [--trait TRAIT ...] REPO

REPO is a checkout. Its level and traits come from its .copier-answers.yml; --level
replaces the level and --trait adds a trait, for a repo without answers. Each
requirement in levels.toml gets one status: met, missing, not_applicable (above the
repo's level, for traits it lacks, or its condition does not hold), or unchecked (a
person judges it, or the facts are not in the files). docs/levels.md#checking-a-repo
describes the output, and scripts/check_level.schema.json is its schema.

Exit codes: 0 the report was printed, whatever it found; 2 a usage error; 3 the repo,
its answers or levels.toml could not be read.
"""

from __future__ import annotations

import argparse
import datetime as dt
import io
import json
import os
import posixpath
import re
import subprocess
import sys
import tomllib
from pathlib import Path
from typing import TYPE_CHECKING

import yaml

if TYPE_CHECKING:
    from collections.abc import Callable

ROOT = Path(__file__).resolve().parent.parent
SCHEMA_VERSION = 1
LEVELS = ("minimal", "standard", "community")
TRAITS = ("web", "cli", "package", "pipeline", "numerics")
ANSWERS = ".copier-answers.yml"
Result = tuple[str, str]  # (status, evidence)


class Repo:
    """The files of a checkout: paths relative to its root, with `/` separators."""

    def __init__(self, root: Path, today: dt.date) -> None:
        self.root, self.today = root, today
        self.paths = list_files(root)
        self.workflows = {
            p: self.text(p) for p in sorted(self.paths) if re.fullmatch(r"\.github/workflows/[^/]+\.ya?ml", p)
        }
        answers = yaml.safe_load(self.text(ANSWERS)) if ANSWERS in self.paths else None
        self.has_answers = answers is not None
        self.answers: dict = answers if isinstance(answers, dict) else {}
        self.traits = answer_traits(self.answers)

    def text(self, path: str) -> str:
        """The file's text, "" when the repo lacks it."""
        return (self.root / path).read_text(errors="replace") if path in self.paths else ""

    def first(self, *candidates: str) -> str | None:
        """The first of the paths that the repo has."""
        return next((p for p in candidates if p in self.paths), None)

    def workflow(self, pattern: re.Pattern | Callable[[str], bool]) -> str | None:
        """The first workflow whose text matches."""
        test = pattern.search if isinstance(pattern, re.Pattern) else pattern
        return next((p for p, t in self.workflows.items() if test(t)), None)


def without_git_env() -> dict[str, str]:
    """The environment minus GIT_DIR, GIT_INDEX_FILE and the rest, which a git hook sets for its own repo."""
    return {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}


def list_files(root: Path) -> set[str]:
    """Tracked and untracked files that git does not ignore; every file outside `.git` when it is not a git repo."""
    r = subprocess.run(  # noqa: S603 -- a fixed git command, found on PATH; the path is an argument
        ["git", "-C", str(root), "ls-files", "-co", "--exclude-standard", "-z"],  # noqa: S607
        capture_output=True,
        text=True,
        check=False,
        env=without_git_env(),
    )
    if r.returncode == 0 and (root / ".git").exists():
        # ls-files lists tracked files deleted from the checkout, and submodules as paths.
        return {p for p in r.stdout.split("\0") if p and (root / p).is_file()}
    out = set()
    for d, dirs, files in os.walk(root):
        dirs[:] = [x for x in dirs if x != ".git"]
        out |= {(Path(d) / f).relative_to(root).as_posix() for f in files}
    return out


def answer_traits(a: dict) -> set[str]:
    """Traits from the answers, as the Requirements table in docs/levels.md derives them."""
    stacks = a.get("stacks") or []
    # Answers files from before 0.15.0 call python_kind `kind`.
    kind = a.get("python_kind", a.get("kind")) if "python" in stacks else None
    ts_kind = a.get("ts_kind") if "ts" in stacks else None
    rust_kind = a.get("rust_kind") if "rust" in stacks else None
    out = set()
    if ts_kind == "web-app" or a.get("site") not in (None, "none"):
        out.add("web")
    if rust_kind == "binary" or (a.get("go_kind") == "binary" and "go" in stacks) or kind == "data-pipeline":
        out.add("cli")
    if ("python" in stacks and a.get("publish_to_pypi")) or ("ts" in stacks and a.get("publish_to_npm")):
        out.add("package")
    if rust_kind == "library":
        out.add("package")
    out |= {"data-pipeline": {"pipeline"}, "research": {"numerics"}}.get(kind, set())
    return out


# --- the checks: one function per requirement id, each returning (status, evidence) ----------------------------

LOCKS = {"pyproject.toml": "uv.lock", "package.json": "pnpm-lock.yaml"}
RENOVATE = ("renovate.json", "renovate.json5", ".renovaterc", ".renovaterc.json", ".renovaterc.json5")
DEP_BOTS = (".github/dependabot.yml", ".github/dependabot.yaml", *RENOVATE, *(f".github/{c}" for c in RENOVATE))
# LICENSE, LICENSE.md, COPYING, or the dual-license pair LICENSE-MIT and LICENSE-APACHE.
LICENSE_FILE = re.compile(r"(LICEN[CS]E|COPYING)([-.][\w.-]+)?", re.IGNORECASE)


def where(name: str) -> tuple[str, ...]:
    """The places GitHub looks for a community file."""
    return (name, f".github/{name}", f"docs/{name}")


PR_TRIGGER = re.compile(r"^\s*pull_request\s*:|^on:.*\bpull_request\b", re.MULTILINE)
# A release runs on `on: release` or on a pushed version tag (`push: tags:`).
RELEASE_TRIGGER = re.compile(r"^\s*release\s*:|^on:.*\brelease\b|^\s*tags\s*:", re.MULTILINE)
TEST_CMD = re.compile(
    r"\bpytest\b|cargo (nextest run|test)\b|\bpnpm (run )?test\b|\bvitest\b|\bgo test\b|\bjust (test|check)\b"
)
LICENCE_CMD = re.compile(
    r"\blicensecheck\b|pip-licenses|cargo[- ]deny (list|check)\b|license-checker|pnpm (run )?licenses\b|go-licenses"
)
RELEASE_UPLOAD = re.compile(
    r"upload-artifact|gh release upload|pypa/gh-action-pypi-publish|cargo publish|npm publish|pnpm publish"
)
API_CHECK = re.compile(r"griffe|cargo[- ]semver-checks|api-extractor", re.IGNORECASE)
# test-policy: a sentence that ties a change to its tests, and a named style, standard or linter.
TEST_POLICY = re.compile(r"\b(change|pull request|fix|feature)s?\b[^.]{0,120}?\btests?\b", re.IGNORECASE)
CODING_STANDARDS = re.compile(
    r"\b(code style|coding standards?|style guide|lint\w*|format\w*|ruff|biome|clippy|rustfmt|eslint|prettier)\b",
    re.IGNORECASE,
)
# architecture-doc: a repo with this many code files (tests, fixtures and build output not counted).
ARCH_MIN_SOURCE = 40
SOURCE_FILE = re.compile(
    r"\.(py|pyx|ts|tsx|js|jsx|mjs|svelte|astro|vue|go|rs|java|kt|swift|rb|c|cc|cpp|h|hpp|jl|r)$", re.IGNORECASE
)
NOT_SOURCE = re.compile(r"(^|/)(tests?|fixtures?|vendor|node_modules|dist|build|examples?)/")
ARCH_DOCS = ("docs/architecture.md", "ARCHITECTURE.md", "docs/ARCHITECTURE.md")
ARCH_HEADING = re.compile(r"^##\s+(architecture|how it works)\b.*$", re.IGNORECASE | re.MULTILINE)
# An axe or a11y test file or folder, not a name that only contains the letters (taxes.py).
AXE_PATH = re.compile(r"(^|[/._-])(axe|a11y)([/._-]|$)", re.IGNORECASE)
ISSUE_URL = re.compile(r"https://github\.com/([\w.-]+/[\w.-]+)/issues/(\d+)")


def met_if(path: str | None, missing: str) -> Result:
    """Met with the path as evidence, else missing for the reason given."""
    return ("met", path) if path else ("missing", missing)


def lockfile(r: Repo) -> Result:
    """A lockfile beside each root manifest."""
    manifests = [m for m in LOCKS if m in r.paths]
    if not manifests:
        return "not_applicable", "no root pyproject.toml or package.json"
    if lacking := [f"{m} without {LOCKS[m]}" for m in manifests if LOCKS[m] not in r.paths]:
        return "missing", "; ".join(lacking)
    return "met", ", ".join(LOCKS[m] for m in manifests)


def workflow_problems(name: str, text: str) -> list[str]:
    """A missing `permissions:` block, checkout with persisted credentials, or a `pull_request_target` trigger."""
    try:
        doc = yaml.safe_load(text)
    except yaml.YAMLError:
        return [f"{name} does not parse"]
    if not isinstance(doc, dict):
        return [f"{name} is not a workflow"]
    on = doc.get("on", doc.get(True))  # YAML 1.1 reads a bare `on:` key as True.
    triggers = {on} if isinstance(on, str) else set(map(str, on)) if isinstance(on, list | dict) else set()
    jobs = {j: s for j, s in (doc.get("jobs") or {}).items() if isinstance(s, dict)}
    out = [f"{name} runs on pull_request_target"] if "pull_request_target" in triggers else []
    if "permissions" not in doc and (bare := [j for j, s in jobs.items() if "permissions" not in s]):
        out.append(f"{name}: no permissions: block at the top or on job(s) {', '.join(bare)}")
    persisted = [
        j
        for j, s in jobs.items()
        for step in s.get("steps") or []
        if isinstance(step, dict)
        and str(step.get("uses", "")).startswith("actions/checkout@")
        # An explicit `true` is a deliberate choice for a job that pushes.
        and "persist-credentials" not in (step.get("with") or {})
    ]
    if persisted:
        out.append(
            f"{name}: actions/checkout without persist-credentials: false"
            f" in job(s) {', '.join(dict.fromkeys(persisted))}"
        )
    return out


def workflow_hardening(r: Repo) -> Result:
    """Every workflow passes workflow_problems."""
    if not r.workflows:
        return "not_applicable", "no workflows in .github/workflows"
    problems = [p for name, text in r.workflows.items() for p in workflow_problems(name, text)]
    return ("missing", "; ".join(problems)) if problems else ("met", f"{len(r.workflows)} workflows")


def license_(r: Repo) -> Result:
    """A LICENSE file, and no `license: none` answer."""
    path = ", ".join(sorted(p for p in r.paths if LICENSE_FILE.fullmatch(p)))
    if not path:
        return "missing", "no LICENSE"
    spdx = r.answers.get("license")
    if spdx == "none":
        return "missing", f"{ANSWERS} answers license: none"
    # Every license the template offers is OSI-approved; another LICENSE text is taken on trust.
    return "met", f"{path} ({spdx})" if spdx else path


def community_files(r: Repo) -> Result:
    """CONTRIBUTING.md, a code of conduct, issue forms and a pull request template."""
    found = {
        "CONTRIBUTING.md": r.first(*where("CONTRIBUTING.md")),
        "CODE_OF_CONDUCT.md": r.first(*where("CODE_OF_CONDUCT.md")),
        "issue forms": next((p for p in sorted(r.paths) if p.startswith(".github/ISSUE_TEMPLATE/")), None),
        "pull request template": next(
            (
                p
                for p in sorted(r.paths)
                if re.fullmatch(r"(\.github/|docs/)?pull_request_template(\.md|/.+)", p, re.IGNORECASE)
            ),
            None,
        ),
    }
    if lacking := [k for k, v in found.items() if not v]:
        return "missing", "no " + ", ".join(lacking)
    return "met", ", ".join(v for v in found.values() if v)


def test_policy(r: Repo) -> Result:
    """CONTRIBUTING.md ties a change to its tests and names the coding standards."""
    path = r.first(*where("CONTRIBUTING.md"))
    if not path:
        return "missing", "no CONTRIBUTING.md"
    text = r.text(path)
    if TEST_POLICY.search(text) and CODING_STANDARDS.search(text):
        return "met", path
    return "missing", f"{path} does not say that a change comes with tests and which coding standards apply"


def python_repo_review(r: Repo) -> Result:
    """Unchecked: it takes a run of sp-repo-review, which this script does not make."""
    if "pyproject.toml" not in r.paths:
        return "not_applicable", "no root pyproject.toml"
    return "unchecked", "needs a run of sp-repo-review (uvx sp-repo-review)"


def architecture_doc(r: Repo) -> Result:
    """A repo with enough code files describes its architecture with a diagram, and each path it names exists."""
    n = sum(1 for p in r.paths if SOURCE_FILE.search(p) and not NOT_SOURCE.search(p))
    if n < ARCH_MIN_SOURCE:
        return "not_applicable", f"{n} code files, under {ARCH_MIN_SOURCE}"
    doc = r.first(*ARCH_DOCS)
    text = r.text(doc) if doc else ""
    if not doc and (m := ARCH_HEADING.search(readme := r.text("README.md"))):
        doc, rest = "README.md", readme[m.end() :]
        text = rest[: end.start()] if (end := re.search(r"^##\s", rest, re.MULTILINE)) else rest
    if not doc:
        return "missing", f'{n} code files and no docs/architecture.md or README "How it works" section'
    problems = [] if "```mermaid" in text else ["no mermaid diagram"]
    # Links resolve against the doc's folder; backticked paths against the repo root.
    top, here = {p.split("/")[0] for p in r.paths}, posixpath.dirname(doc)
    refs = {posixpath.normpath(posixpath.join(here, x)) for x in re.findall(r"\]\(([^)#\s]+)", text) if "://" not in x}
    refs |= set(re.findall(r"`([\w.-]+/[\w./-]+)`", text))
    problems += [
        f"names {ref}, which is gone"
        for ref in sorted({x.removeprefix("./").rstrip("/") for x in refs})
        if ref.split("/")[0] in top and ref not in r.paths and not any(p.startswith(ref + "/") for p in r.paths)
    ]
    return ("missing", f"{doc}: " + "; ".join(problems)) if problems else ("met", doc)


def accessibility_statement(r: Repo) -> Result:
    """A web app: a statement and an axe scan. A command-line tool: docs/accessibility.md."""
    found, lacking = [], []
    if "web" in r.traits:
        statement = next((p for p in sorted(r.paths) if re.search(r"accessibility", p, re.IGNORECASE)), None)
        axe = "package.json" if "axe-core" in r.text("package.json") else None
        axe = axe or next((p for p in sorted(r.paths) if AXE_PATH.search(p)), None)
        found += [p for p in (statement, axe) if p]
        lacking += [w for w, p in (("accessibility statement", statement), ("axe scan", axe)) if not p]
    if "cli" in r.traits:
        found += ["docs/accessibility.md"] if "docs/accessibility.md" in r.paths else []
        lacking += [] if "docs/accessibility.md" in r.paths else ["docs/accessibility.md"]
    return ("missing", "no " + ", ".join(lacking)) if lacking else ("met", ", ".join(found))


def stale_review(text: str, name: str, today: dt.date) -> str | None:
    """Why `name`'s "Last reviewed: YYYY-MM-DD" line fails: missing, unparsable or over a year old."""
    m = re.search(r"^Last reviewed:\s*(\d{4}-\d{2}-\d{2})", text, re.MULTILINE)
    try:
        reviewed = dt.date.fromisoformat(m[1]) if m else None
    except ValueError:
        reviewed = None
    if reviewed is None:
        return f'{name} has no "Last reviewed: YYYY-MM-DD" line'
    if today - reviewed > dt.timedelta(days=365):
        return f"{name} was last reviewed {reviewed}, over a year ago"
    return None


def roadmap_issue_links(r: Repo) -> Result:
    """A recent "Last reviewed" date and an issue link per planned theme; open issues are not checked."""
    if "docs/roadmap.md" not in r.paths:
        return "missing", "no docs/roadmap.md"
    text = r.text("docs/roadmap.md")
    problems = [m] if (m := stale_review(text, "docs/roadmap.md", r.today)) else []
    section = ""
    for line in text.splitlines():
        if h := re.match(r"#+\s+(.*)", line):
            section = h[1].lower()
        elif re.match(r"[-*]\s", line) and "not planned" not in section and not ISSUE_URL.search(line):
            problems.append(f"theme links no issue: {line[2:].strip()[:60]}")
    if problems:
        return "missing", "; ".join(problems)
    return "unchecked", "each theme links an issue; whether those issues are open needs the GitHub API"


def dco(r: Repo) -> Result:
    """A workflow checks every pull request, not only forks' ones, for Signed-off-by lines."""
    signoff = [n for n, t in r.workflows.items() if "signed-off-by" in t.lower()]
    if not signoff:
        return "missing", "no workflow checks each pull request for Signed-off-by lines"
    if all("head.repo.full_name != github.repository" in r.workflows[n] for n in signoff):
        return "missing", f"{signoff[0]} checks only pull requests from forks"
    return "met", signoff[0]


CHECKS: dict[str, Callable[[Repo], Result]] = {
    "lockfile": lockfile,
    "dependency-bot": lambda r: met_if(r.first(*DEP_BOTS), "no Dependabot or Renovate config"),
    "workflow-hardening": workflow_hardening,
    "scorecard-workflow": lambda r: met_if(
        r.workflow(lambda t: "ossf/scorecard-action" in t), "no workflow runs ossf/scorecard-action"
    ),
    "security-policy": lambda r: met_if(r.first(*where("SECURITY.md")), "no SECURITY.md"),
    "python-repo-review": python_repo_review,
    "license": license_,
    "community-files": community_files,
    "test-policy": test_policy,
    "changelog": lambda r: met_if(r.first("CHANGELOG.md"), "no CHANGELOG.md"),
    "api-break-check": lambda r: met_if(
        r.workflow(API_CHECK), "no workflow runs griffe, cargo-semver-checks or API Extractor"
    ),
    "citation-file": lambda r: met_if(r.first("CITATION.cff"), "no CITATION.cff"),
    "codemeta": lambda r: met_if(r.first("codemeta.json"), "no codemeta.json"),
    "cold-install": lambda r: met_if(
        next((p for p in r.workflows if "cold-install" in p), None), "no cold-install workflow"
    ),
    "architecture-doc": architecture_doc,
    "accessibility-statement": accessibility_statement,
    "ci-tests": lambda r: met_if(
        r.workflow(lambda t: bool(PR_TRIGGER.search(t) and TEST_CMD.search(t))),
        "no workflow runs the tests on every pull request",
    ),
    "dependency-licenses": lambda r: met_if(
        r.workflow(LICENCE_CMD), "no workflow lists the dependency licenses and fails on an incompatible one"
    ),
    "governance": lambda r: met_if(r.first(*where("GOVERNANCE.md")), "no GOVERNANCE.md"),
    "dco": dco,
    "roadmap": lambda r: met_if(r.first("docs/roadmap.md"), "no docs/roadmap.md"),
    "roadmap-issue-links": roadmap_issue_links,
    "release-build": lambda r: met_if(
        r.workflow(lambda t: bool(RELEASE_TRIGGER.search(t) and RELEASE_UPLOAD.search(t))),
        "no release workflow builds and uploads the release packages",
    ),
}
# `automated` requirements whose facts are not in the files.
UNCHECKED = {
    "web-head-tags": "needs the live site",
    "security-headers": "needs the live site",
    "security-txt": "needs the live site",
    "sitemap-answers": "needs the live site",
    "signed-releases": "needs the tag signatures and the keys the release workflow lists; no check yet",
}


def evaluate(rid: str, req: dict, repo: Repo, level: str | None, why_off: str) -> Result:  # noqa: PLR0911
    """The status and evidence of one requirement for this repo."""
    if level is None:
        return "not_applicable", why_off
    if LEVELS.index(req["level"]) > LEVELS.index(level):
        return "not_applicable", f"a {req['level']} requirement; the repo is at {level}"
    if req["traits"] and not set(req["traits"]) & repo.traits:
        return "not_applicable", f"applies to traits {', '.join(req['traits'])}; the repo has none of them"
    if req["verify"] == "review":
        return "unchecked", "a person judges it (verify = review)"
    if rid in UNCHECKED:
        return "unchecked", UNCHECKED[rid]
    if rid not in CHECKS:
        return "unchecked", "no check for this requirement yet"
    return CHECKS[rid](repo)


def entry(rid: str, req: dict, status_evidence: Result) -> dict:
    """One item of the report's `requirements` list."""
    status, evidence = status_evidence
    return {"id": rid, "area": req["area"], "level": req["level"], "since": req["since"].isoformat(),
            "status": status, "evidence": evidence}  # fmt: skip


def report(root: Path, levels: dict, now: dt.datetime, level: str | None = None, traits: tuple[str, ...] = ()) -> dict:
    """The JSON report. level replaces the answers' level; traits add to theirs."""
    repo = Repo(root, now.date())
    repo.traits |= set(traits)
    level = level or repo.answers.get("level")
    if level is not None and level not in LEVELS:
        msg = f"{ANSWERS} has level {level!r}, not one of {', '.join(LEVELS)}"
        raise ValueError(msg)
    why_off = f"no {ANSWERS}" if not repo.has_answers else f"no level in {ANSWERS}: the repo is not on the ladder"
    return {
        "schema_version": SCHEMA_VERSION,
        "repo": root.name,
        "level": level,
        "traits": sorted(repo.traits),
        "levels_version": levels["version"],
        "checked_at": now.isoformat(timespec="seconds").replace("+00:00", "Z"),
        "requirements": [
            entry(rid, req, evaluate(rid, req, repo, level, f"{why_off}; pass --level"))
            for rid, req in levels["requirement"].items()
        ],
    }


def main(argv: list[str] | None = None) -> int:
    """Print the report; the module docstring lists the exit codes."""
    if isinstance(sys.stdout, io.TextIOWrapper):
        sys.stdout.reconfigure(encoding="utf-8", newline="\n")
    parser = argparse.ArgumentParser(
        prog="check_level.py",
        description=__doc__.split("\n\n")[0],
        epilog="example: scripts/check_level.py ../my-project > my-project.json",
    )
    parser.add_argument("repo", type=Path, help="path to the repo's checkout")
    parser.add_argument(
        "--levels", type=Path, default=ROOT / "levels.toml", help="levels.toml to read (default: this repo's)"
    )
    parser.add_argument("--level", choices=LEVELS, help=f"the repo's level, in place of the one in {ANSWERS}")
    parser.add_argument(
        "--trait",
        action="append",
        default=[],
        choices=TRAITS,
        help="a trait to add to those the answers give (repeatable)",
    )
    args = parser.parse_args(argv)
    try:
        if not args.repo.is_dir():
            msg = f"{args.repo} is not a directory"
            raise FileNotFoundError(msg)
        levels = tomllib.loads(args.levels.read_text())
        out = report(args.repo.resolve(), levels, dt.datetime.now(dt.UTC), args.level, tuple(args.trait))
    except (OSError, ValueError, KeyError, yaml.YAMLError) as e:
        sys.stderr.write(f"error: {e!r}\n" if isinstance(e, KeyError) else f"error: {e}\n")
        return 3
    sys.stdout.write(json.dumps(out, indent=2, ensure_ascii=False) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
