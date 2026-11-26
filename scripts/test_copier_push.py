"""Exercise the rendered update push against synthetic local Git remotes."""

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def _write_comparison_response(path: Path, case: str) -> None:
    bot = "41898282+github-actions[bot]@users.noreply.github.com"
    author = {"human": "maintainer@example.org", "unknown-author": ""}.get(case, bot)
    committer = "maintainer@example.org" if case == "human-committer" else author
    commit = {"author": {"email": author}, "committer": {"email": committer}}
    path.write_text(json.dumps({"commits": [{"commit": commit}]}))


def check_push(workflow: Path, case: str) -> None:
    """Keep unverified commits and reject races at the remote branch."""
    text = workflow.read_text()
    section = text.split("          # Git uses the credential helper", 1)[1].split("          # With a .rej", 1)[0]
    script = "\n".join(line[10:] for line in ("          # Git uses the credential helper" + section).splitlines())
    with tempfile.TemporaryDirectory(prefix="copier-push-") as tmp:
        root = Path(tmp)
        tools = root / "tools"
        tools.mkdir()
        remote = root / "remote.git"
        checkout = root / "checkout"
        env = {
            "PATH": os.defpath,
            "GIT_CONFIG_GLOBAL": os.devnull,
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_ALLOW_PROTOCOL": "file",
            "GIT_AUTHOR_NAME": "Example Author",
            "GIT_AUTHOR_EMAIL": "author@example.org",
            "GIT_COMMITTER_NAME": "Example Author",
            "GIT_COMMITTER_EMAIL": "author@example.org",
        }
        real_git = shutil.which("git", path=os.defpath)
        bash = shutil.which("bash", path=os.defpath)
        jq = shutil.which("jq")
        assert real_git
        assert bash
        assert jq
        (tools / "jq").symlink_to(jq)

        def git(*args: str, data: str = "") -> str:
            return subprocess.check_output(  # noqa: S603 -- fixed arguments for local fixture repositories
                [real_git, "-c", "core.hooksPath=/dev/null", *args],
                input=data,
                text=True,
                env=env,
                stderr=subprocess.PIPE,
            ).strip()

        git("init", "--bare", str(remote))
        tree = git("-C", str(remote), "mktree")
        base = git("-C", str(remote), "commit-tree", tree, data="base\n")
        before = git("-C", str(remote), "commit-tree", tree, "-p", base, data="old update\n")
        race = git("-C", str(remote), "commit-tree", tree, "-p", before, data="concurrent edit\n")
        git("-C", str(remote), "update-ref", "refs/heads/main", base)
        branch = "refs/heads/chore/copier-update"
        if case not in {"missing", "creation-race"}:
            git("-C", str(remote), "update-ref", branch, before)
        git("clone", "-b", "main", str(remote), str(checkout))
        update = git("-C", str(checkout), "commit-tree", tree, "-p", base, data="new update\n")
        git("-C", str(checkout), "update-ref", branch, update)
        git("-C", str(checkout), "switch", "chore/copier-update")
        git("-C", str(checkout), "config", f"url.{remote}.insteadOf", "https://github.com/example/tool.git")

        (tools / "git").write_text("""#!/usr/bin/env bash
if [ "$1" = ls-remote ] && [ "$CASE" = remote-failure ]; then exit 1; fi
case " $* " in
  *" push "*)
    echo push >>"$PUSH_LOG"
    if [ "$CASE" = advanced ] || [ "$CASE" = creation-race ]; then
      "$REAL_GIT" -C "$REMOTE" update-ref refs/heads/chore/copier-update "$RACE"
    fi
    ;;
esac
exec "$REAL_GIT" "$@"
""")
        (tools / "gh").write_text("""#!/usr/bin/env bash
if [ "$1 $2" = 'auth setup-git' ]; then exit 0; fi
if [ "$1" != api ]; then exit 90; fi
printf '%s\\n' "$*" >>"$API_LOG"
if [ "$CASE" = api-failure ]; then exit 1; fi
filter=.
pages=false
while [ "$#" -gt 0 ]; do
  case $1 in --jq) filter=$2; shift ;; --paginate) pages=true ;; esac
  shift
done
jq -r "$filter" "$RESPONSE"
if [ "$CASE" = paginated-human ] && [ "$pages" = true ]; then
  jq -r "$filter" <<'JSON'
{"commits":[{"commit":{
  "author":{"email":"maintainer@example.org"},
  "committer":{"email":"maintainer@example.org"}
}}]}
JSON
fi
""")
        for tool in tools.iterdir():
            if not tool.is_symlink():
                tool.chmod(0o755)
        response = root / "response.json"
        _write_comparison_response(response, case)
        env.update(
            PATH=str(tools) + os.pathsep + os.defpath,
            CASE=case,
            REAL_GIT=real_git,
            REMOTE=str(remote),
            RACE=race,
            RESPONSE=str(response),
            API_LOG=str(root / "api.log"),
            PUSH_LOG=str(root / "push.log"),
            REPO="example/tool",
            BASE="main",
            branch="chore/copier-update",
            GITHUB_STEP_SUMMARY=str(root / "summary"),
        )
        result = subprocess.run(  # noqa: S603 -- checked-in render against a file-only remote
            [bash, "-euo", "pipefail", "-c", script],
            check=False,
            cwd=checkout,
            env=env,
            text=True,
            capture_output=True,
        )
        refs = git("-C", str(remote), "for-each-ref", "--format=%(objectname)", branch)
        expected = update if case in {"bot", "missing"} else race if case in {"advanced", "creation-race"} else before
        assert refs == expected, f"{case}: changed unverified remote: {result.stdout}{result.stderr}"
        assert (result.returncode != 0) == (case in {"api-failure", "remote-failure", "advanced", "creation-race"}), (
            case
        )
        if case not in {"missing", "creation-race", "remote-failure"}:
            assert f"compare/{base}...{before}" in (root / "api.log").read_text(), case
        if case in {"api-failure", "remote-failure", "human", "unknown-author", "paginated-human", "human-committer"}:
            assert not (root / "push.log").exists(), case


if __name__ == "__main__":
    failed = []
    for case in (
        "api-failure",
        "remote-failure",
        "human",
        "advanced",
        "bot",
        "missing",
        "creation-race",
        "unknown-author",
        "paginated-human",
        "human-committer",
    ):
        try:
            check_push(Path(sys.argv[1]), case)
        except AssertionError as error:
            failed.append(case)
            sys.stderr.write(f"FAIL {case}: {error}\n")
        else:
            sys.stdout.write(f"PASS {case}\n")
    raise SystemExit(bool(failed))
