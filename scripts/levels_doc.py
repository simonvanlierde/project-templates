#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Write the Levels table in docs/levels.md from levels.toml.

Usage: scripts/levels_doc.py [--check]
--check writes nothing and exits 1 when the table is stale or levels.toml's version is not
the newest release in CHANGELOG.md.
"""

import datetime
import re
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LEVELS = ("minimal", "standard", "community")
TRAITS = {"web", "cli", "package", "pipeline", "numerics"}
VERIFY = {"automated", "review"}
FIELDS = {"area", "level", "traits", "text", "source", "verify", "since"}
START, END = "<!-- levels:start -->", "<!-- levels:end -->"


def problems(rid: str, r: dict) -> list[str]:
    out = []
    if set(r) != FIELDS:
        out.append(f"fields {sorted(set(r) ^ FIELDS)} missing or unknown")
    if r.get("level") not in LEVELS:
        out.append(f"level {r.get('level')!r} is not one of {LEVELS}")
    if not set(r.get("traits", [])) <= TRAITS:
        out.append(f"traits {sorted(set(r['traits']) - TRAITS)} unknown")
    if r.get("verify") not in VERIFY:
        out.append(f"verify {r.get('verify')!r} is not one of {sorted(VERIFY)}")
    if not isinstance(r.get("since"), datetime.date):
        out.append("since is not a date")
    if isinstance(r.get("since"), datetime.datetime):
        out.append("since is a datetime, not a date")
    for field in ("text", "source", "area"):
        if "|" in str(r.get(field, "")) or "\n" in str(r.get(field, "")):
            out.append(f"{field} must be one line without |")
    return [f"levels.toml: requirement.{rid}: {p}" for p in out]


def table(data: dict) -> str:
    reqs = data["requirement"]
    errors = [p for rid, r in reqs.items() for p in problems(rid, r)]
    if errors:
        sys.exit("\n".join(errors))
    rows = [
        f"| `{rid}` | {r['level']} | {', '.join(r['traits']) or 'all'} | {r['text']} | {r['verify']} | {r['source']} | {r['since']} |"
        for rid, r in sorted(reqs.items(), key=lambda kv: LEVELS.index(kv[1]["level"]))
    ]
    return "\n".join(
        [
            START,
            "<!-- Generated from levels.toml by `just levels-doc`; edit that file, not this table. -->",
            "",
            f"Levels version {data['version']}:",
            "",
            "| Requirement | Level | Applies to | What it asks | Verified by | Source | Counts from |",
            "| --- | --- | --- | --- | --- | --- | --- |",
            *rows,
            END,
        ]
    )


def main() -> int:
    check = sys.argv[1:] == ["--check"]
    if sys.argv[1:] not in ([], ["--check"]):
        sys.exit(__doc__)
    data = tomllib.loads((ROOT / "levels.toml").read_text())
    release = re.search(r"^## \[(\d+\.\d+\.\d+)\]", (ROOT / "CHANGELOG.md").read_text(), re.M)
    if release and data["version"] != release[1]:
        print(
            f"levels.toml: version {data['version']} is not the newest release {release[1]} in CHANGELOG.md",
            file=sys.stderr,
        )
        return 1
    doc = ROOT / "docs" / "levels.md"
    text = doc.read_text()
    if START not in text or END not in text:
        sys.exit(f"docs/levels.md: needs both {START} and {END}")
    new = re.sub(re.escape(START) + ".*?" + re.escape(END), lambda _: table(data), text, count=1, flags=re.S)
    if new == text:
        return 0
    if check:
        print("docs/levels.md: the Levels table is stale; run `just levels-doc`", file=sys.stderr)
        return 1
    doc.write_text(new)
    return 0


if __name__ == "__main__":
    sys.exit(main())
