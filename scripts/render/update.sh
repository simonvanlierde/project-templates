# shellcheck shell=bash
# shellcheck disable=SC2030 # independent test subshells set their own environment
# shellcheck disable=SC2154,SC2164 # check-render.sh sets out, repo, copier and set -e
# Template updates: the copier-update workflow, ADRs and sample code across an update.
# Renders adr-check and sample-up, which the install-action sweep at the end covers.

# copier-update pushes with the update App's token when it is set up; GITHUB_TOKEN can't push workflow
# changes, so without it a workflow change becomes an issue, not a failed push.
cu=a/.github/workflows/copier-update.yml
publisher=.github/scripts/publish-copier-update.sh
test -x "a/$publisher"
test ! -e "d/$publisher"
uv run --no-project python "$repo/scripts/test_copier_push.py" "a/$publisher"
# Copier dependencies and the push token must run on separate workers.
cuh=$out/copier-update
mkdir -p "$cuh"
uv run --no-project --with pyyaml python - "$cu" "$cuh/push.sh" <<'PYTEST'
import sys, yaml
from pathlib import Path
jobs = yaml.safe_load(open(sys.argv[1]))["jobs"]
assert jobs["update"]["permissions"] == {"contents": "read"}
assert "COPIER_UPDATE_PRIVATE_KEY" not in str(jobs["update"]) and "environment" not in jobs["update"]
# The App key is an environment secret; repo-settings limits that environment to main.
assert jobs["push"]["environment"] == "copier-update"
app = [s for s in jobs["push"]["steps"] if s.get("uses", "").startswith("actions/create-github-app-token@")]
assert len(app) == 1 and app[0]["if"] == "vars.COPIER_UPDATE_CLIENT_ID != ''", app
assert {k for k in app[0]["with"] if k.startswith("permission-")} == {"permission-contents", "permission-pull-requests", "permission-workflows"}
assert jobs["push"]["needs"] == "update"
assert any(s.get("uses", "").startswith("actions/download-artifact@") for s in jobs["push"]["steps"])
assert not any("uvx" in s.get("run", "") for s in jobs["push"]["steps"])
publish = next(s for s in jobs["push"]["steps"] if s.get("name") == "Push the update and open the PR")
assert "git show HEAD^:.github/scripts/publish-copier-update.sh" in publish["run"]
Path(sys.argv[2]).write_text(publish["run"])
PYTEST
awk -v d="$cuh" '/^      - /{n++} n{print >(d "/step" n)}' "$cu"
grep -l 'copier@' "$cuh"/step* | grep -q .
(! grep -l 'copier@' "$cuh"/step* | xargs grep -q COPIER_UPDATE_PRIVATE_KEY)
# shellcheck disable=SC2016 # literal workflow text, not shell expansions
grep -qF 'GH_TOKEN: ${{ steps.app.outputs.token || github.token }}' "$cu"
# The token never sits in a command line: git asks gh's credential helper for it.
(lacks -q 'x-access-token' "$cu" "a/$publisher")
grep -qx '      issues: write # to ask for a local update when it can.t push one' "$cu"
# The run below stands in true or false for this expression.
grep -qF "HAS_TOKEN: \${{ steps.app.outputs.token != '' }}" "$cu"
# Run the step's script against a fake gh, a fake uvx that changes one file, a template
# repo with two tags and a bare repo standing in for GitHub. GIT_ALLOW_PROTOCOL=file makes
# a push that misses the rewrite fail instead of reaching github.com.
# Test the two inline steps and the launch of the standalone publisher.
for n in copier apply; do
  case $n in copier) name=Update ;; apply) name=Apply ;; esac
  f=$(grep -l "^      - name: $name" "$cuh"/step*)
  awk '/^        run: \|-$/{f=1;next} f&&NF&&!/^          /{exit} f{sub(/^          /,"");print}' "$f" >"$cuh/$n.sh"
done
# The fake gh keeps only the --json fields a list asks for and applies --jq, as gh does,
# so a filter on a field the call does not request finds nothing. gh prints null as an empty line.
cat >"$cuh/gh" <<'FAKE'
#!/usr/bin/env bash
echo "$*" >>"$FAKE_LOG"
case "$1 $2" in
  "issue list") rows=${FAKE_ISSUES:-[]} ;;
  "pr list")
    case " $* " in
      *" --state closed "*) rows=${FAKE_CLOSED_PRS:-[]} ;;
      *) rows=${FAKE_OPEN_PRS:-[]} ;;
    esac
    ;;
  # The authors of the branch's commits since the base, one per line.
  "api "*) printf '%s\n' "${FAKE_AUTHORS:-}" && exit 0 ;;
  *) exit 0 ;;
esac
fields='' filter=.
while [ $# -gt 0 ]; do
  case $1 in --json) fields=$2 ;; --jq) filter=$2 ;; esac
  shift
done
printf '%s\n' "$rows" | jq -c --arg f "$fields" 'map(with_entries(select(.key as $k | $f | split(",") | index($k))))' | jq -r "$filter" | sed "s/^null$//"
FAKE
cat >"$cuh/uvx" <<'FAKE'
#!/usr/bin/env bash
echo "uvx $*" >>"$FAKE_LOG"
mkdir -p "$(dirname "$FAKE_FILE")"
echo "${FAKE_TEXT:-# from the template}" >>"$FAKE_FILE"
if [ "${FAKE_LARGE_UPDATE:-}" = true ]; then
  for ((i = 0; i < 4096; i++)); do
    : >"sample-path-for-large-update-$i.txt"
  done
fi
FAKE
chmod +x "$cuh/gh" "$cuh/uvx"
(
  # A subshell drops the ERR trap; set -E would fire it in every (! ...) below.
  trap 'echo "check-render: failed at ${BASH_SOURCE[0]}:$LINENO" >&2' ERR
  # shellcheck disable=SC2031 # a separate subshell sets its own
  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_ALLOW_PROTOCOL=file \
    GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.org GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.org
  git init -q -b main "$cuh/tpl"
  # The tags are a month old: a tag under a week old waits for a later run.
  GIT_COMMITTER_DATE=2020-01-01T00:00:00Z git -C "$cuh/tpl" commit -q --allow-empty -m one
  git -C "$cuh/tpl" tag v0.9.0
  git -C "$cuh/tpl" tag v0.10.0
  # Annotated tags, as releases are: their own date counts, not the commit's. In young the newest tag
  # is 6 days old and waits; in mixed v0.9.0 is 8 days old, so it is the newest that does not.
  for t in young mixed; do
    git init -q -b main "$cuh/tpl-$t"
    GIT_COMMITTER_DATE=2020-01-01T00:00:00Z git -C "$cuh/tpl-$t" commit -q --allow-empty -m one
  done
  GIT_COMMITTER_DATE="@$(($(date +%s) - 30 * 86400)) +0000" git -C "$cuh/tpl-young" tag -a -m t v0.9.0
  GIT_COMMITTER_DATE="@$(($(date +%s) - 6 * 86400)) +0000" git -C "$cuh/tpl-young" tag -a -m t v0.10.0
  GIT_COMMITTER_DATE="@$(($(date +%s) - 40 * 86400)) +0000" git -C "$cuh/tpl-mixed" tag -a -m t v0.8.0
  GIT_COMMITTER_DATE="@$(($(date +%s) - 8 * 86400)) +0000" git -C "$cuh/tpl-mixed" tag -a -m t v0.9.0
  GIT_COMMITTER_DATE="@$(($(date +%s) - 1 * 86400)) +0000" git -C "$cuh/tpl-mixed" tag -a -m t v0.10.0
  pin_a='      - uses: a/b@1111111111111111111111111111111111111111 # v1.2.4'
  pin_b='      - uses: a/b@2222222222222222222222222222222222222222 # v1.2.3'
  # name, HAS_TOKEN, the open PR and the issue the fake gh finds ("-": none), and the
  # file the update changes.
  while read -r name token pr issue file; do
    p=$cuh/$name
    git init -q --bare "$p.git"
    # An open PR has its branch on the remote, on a history the update does not extend.
    if [ "$pr" != - ]; then git -C "$cuh/tpl" push -q "$p.git" HEAD:refs/heads/chore/copier-update; fi
    git init -q -b main "$p"
    src=$cuh/tpl
    commit=v0.9.0
    if [ "$name" = young ]; then src=$cuh/tpl-young; fi
    if [ "$name" = mixed ]; then
      src=$cuh/tpl-mixed
      commit=v0.8.0
    fi
    if [ "$name" = own-young ]; then src=gh:simonvanlierde/project-templates; fi
    if [ "$name" = own-young-https ]; then src=https://github.com/simonvanlierde/project-templates; fi
    # Another owner whose repo name merely contains simonvanlierde gets no exemption.
    if [ "$name" = lookalike ]; then src=gh:evil/simonvanlierde-templates; fi
    printf '_commit: %s\n_src_path: %s\n' "$commit" "$src" >"$p/.copier-answers.yml"
    # A layered template with its own answers file; this project's own is already current.
    if [ "$name" = layer ]; then
      cp "$p/.copier-answers.yml" "$p/.copier-answers.cml.yml"
      printf '_commit: v0.10.0\n_src_path: %s\n' "$cuh/tpl" >"$p/.copier-answers.yml"
    fi
    # Both answers files behind, and an update that leaves a conflict marker.
    if [ "$name" = both ]; then cp "$p/.copier-answers.yml" "$p/.copier-answers.cml.yml"; fi
    # The file the fake copier changes exists in the project, as it does in a real update.
    mkdir -p "$p/.github/scripts" "$p/$(dirname "${file:-.github/workflows/ci.yml}")"
    cp "$out/a/$publisher" "$p/$publisher"
    if [ "$name" != self-update ]; then echo 'project line' >"$p/${file:-.github/workflows/ci.yml}"; fi
    if [ "$name" = issue ]; then echo 'project issue notes' >"$p/issue.md"; fi
    # A module at the project root that shadows one the resolver imports.
    if [ "$name" = pyroot ]; then echo 'raise SystemExit("imported the project re.py")' >"$p/re.py"; fi
    git -C "$p" add -A
    git -C "$p" commit -q -m init
    # The privileged job starts from a clean checkout, not the generator's worktree.
    git clone -q "$p" "$p-clean"
    (
      cd "$p"
      # shellcheck disable=SC2030,SC2031 # each fake run sets its own environment
      export PATH="$cuh:$PATH" FAKE_LOG="$p.log" \
        FAKE_FILE="${file:-.github/workflows/ci.yml}" \
        GH_TOKEN=fake HAS_TOKEN="$token" REPO=example-org/render-me BASE=main COPIER_VERSION="$copier_pin" \
        RUNNER_TEMP="$p-runner" GITHUB_STEP_SUMMARY="$p.summary"
      if [ "$name" = issue-large ]; then export FAKE_LARGE_UPDATE=true; fi
      export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0="url.$p.git.insteadOf" \
        GIT_CONFIG_VALUE_0="https://github.com/$REPO.git"
      # A simonvanlierde template, as gh: names it, is the young template here.
      if [ "$name" = own-young ] || [ "$name" = own-young-https ]; then
        export GIT_CONFIG_COUNT=2 GIT_CONFIG_KEY_1="url.$cuh/tpl-young.insteadOf" \
          GIT_CONFIG_VALUE_1=https://github.com/simonvanlierde/project-templates
      fi
      if [ "$name" = lookalike ]; then
        export GIT_CONFIG_COUNT=2 GIT_CONFIG_KEY_1="url.$cuh/tpl-young.insteadOf" \
          GIT_CONFIG_VALUE_1=https://github.com/evil/simonvanlierde-templates
      fi
      FAKE_TEXT=''
      conflict() { printf '<<<<<<< before updating\n%s\n=======\n%s\n>>>>>>> after updating' "$1" "$2"; }
      # Hunks that differ only in pinned SHAs and their comments keep the project's pins, whichever
      # side is newer. A changed repo, a change outside the pin, or unequal hunks stay conflicts.
      case $name in
      both | edit-conflict | café) FAKE_TEXT=$(conflict 'project edit' 'template edit') ;;
      pin-project | pyroot) FAKE_TEXT=$(conflict "$pin_a" "$pin_b") ;;
      pin-template) FAKE_TEXT=$(conflict "$pin_b" "$pin_a") ;;
      crlf) FAKE_TEXT=$(conflict "$pin_a" "$pin_b" | sed 's/$/\r/') ;;
      frozen) FAKE_TEXT=$(conflict '    rev: 1111111111111111111111111111111111111111 # frozen: v1.1.0' '    rev: 2222222222222222222222222222222222222222 # frozen: v1.2.0') ;;
      repo-swap) FAKE_TEXT=$(conflict '      - uses: a/b@1111111111111111111111111111111111111111 # v1' '      - uses: evil/b@2222222222222222222222222222222222222222 # v2') ;;
      mixed-hunks) FAKE_TEXT="$(conflict "$pin_a" "$pin_b")"$'\nshared line\n'"$(conflict 'project edit' $'template edit\nsecond template line')" ;;
      esac
      # The branch's commits so far: the workflow's own, plus someone's in human.
      FAKE_AUTHORS='41898282+github-actions[bot]@users.noreply.github.com'
      if [ "$name" = human ]; then FAKE_AUTHORS+=$'\nada@example.org'; fi
      export FAKE_AUTHORS
      export FAKE_TEXT
      FAKE_OPEN_PRS='[]' FAKE_ISSUES='[]' FAKE_CLOSED_PRS='[]'
      if [ "$pr" != - ]; then FAKE_OPEN_PRS=$(printf '[{"number":%s,"isCrossRepository":false}]' "$pr"); fi
      if [ "$issue" != - ]; then FAKE_ISSUES=$(printf '[{"number":%s}]' "$issue"); fi
      # shellcheck disable=SC2089 # JSON data, never evaluated as shell code.
      case $name in
      declined*) FAKE_CLOSED_PRS='[{"title":"chore: update from template v0.10.0","mergedAt":null,"isCrossRepository":false}]' ;;
      older-declined) FAKE_CLOSED_PRS='[{"title":"chore: update from template v0.9.0","mergedAt":null,"isCrossRepository":false}]' ;;
      merged) FAKE_CLOSED_PRS='[{"title":"chore: update from template v0.10.0","mergedAt":"2026-11-11T12:00:00Z","isCrossRepository":false}]' ;;
      # A fork can open a PR from its own chore/copier-update branch: gh lists it by
      # branch name too, but closing it declines nothing, and it is never edited or closed.
      fork-declined) FAKE_CLOSED_PRS='[{"title":"chore: update from template v0.10.0","mergedAt":null,"isCrossRepository":true}]' ;;
      fork-open*) FAKE_OPEN_PRS='[{"number":9,"isCrossRepository":true}]' ;;
      esac
      # shellcheck disable=SC2090 # The fake gh prints this JSON verbatim.
      export FAKE_OPEN_PRS FAKE_ISSUES FAKE_CLOSED_PRS
      : >"$p.gho"
      : >"$p.log"
      # The copier step gets neither token variable.
      env -u GH_TOKEN -u HAS_TOKEN GITHUB_OUTPUT="$p.gho" bash --noprofile --norc -eo pipefail "$cuh/copier.sh" >"$p.out" 2>&1 || {
        cat "$p.out" >&2
        exit 1
      }
      # shellcheck disable=SC2030 # each fake run reads its own outputs
      LATEST=$(sed -n 's/^latest=//p' "$p.gho") WORKFLOWS=$(sed -n 's/^workflows=//p' "$p.gho")
      CONFLICTS=$(sed -n 's/^conflicts=//p' "$p.gho")
      export LATEST WORKFLOWS CONFLICTS
      if [ -n "$LATEST" ]; then
        cd "$p-clean"
        bash --noprofile --norc -eo pipefail "$cuh/apply.sh" >>"$p.out" 2>&1 || {
          cat "$p.out" >&2
          exit 1
        }
        bash --noprofile --norc -eo pipefail "$cuh/push.sh" >>"$p.out" 2>&1 || {
          cat "$p.out" >&2
          exit 1
        }
      fi
    )
  done <<'CASES'
issue false 7 -
issue-large false - -
asked false - 3
push true - -
edit true 7 -
plain false - - README.md
self-update true - - .github/scripts/publish-copier-update.sh
layer true - - README.md
both true - - README.md
pin-project true - - README.md
pin-template true - - README.md
crlf true - - README.md
frozen true - - README.md
repo-swap true - - README.md
mixed-hunks true - - README.md
pyroot true - - README.md
café true - - café.md
edit-conflict true 7 - README.md
human true 7 -
declined true - -
declined-no-token false - -
declined-plain false - - README.md
older-declined true - -
merged true - -
fork-declined true - -
fork-open true - -
fork-open-no-token false - -
young true - -
mixed true - -
own-young true - -
own-young-https true - -
lookalike true - -
CASES
  cd "$cuh"
  # An update to the publisher itself is committed, while this run uses the checkout's copy.
  cmp "$out/a/$publisher" "self-update-runner/publish-copier-update.sh"
  git -C self-update.git show "chore/copier-update:$publisher" | grep -qxF '# from the template'
  # Newest tag by version, not by name.
  grep -qx "uvx --exclude-newer 1 week copier@$copier_pin update --answers-file .copier-answers.yml --defaults --vcs-ref v0.10.0" issue.log
  # Each answers file updates on its own, and the PR names the layer that moved.
  grep -qx "uvx --exclude-newer 1 week copier@$copier_pin update --answers-file .copier-answers.cml.yml --defaults --vcs-ref v0.10.0" layer.log
  (lacks -q 'answers-file .copier-answers.yml' layer.log)
  grep -q '^pr create --head chore/copier-update --base main --title chore: update from template cml v0.10.0 ' layer.log
  git -C layer.git show chore/copier-update:README.md | grep -qx '# from the template'
  # Two templates that both moved share one title, and a conflict marker is named in the body.
  grep -q '^pr create --head chore/copier-update --base main --title chore: update from template v0.10.0, cml v0.10.0 ' both.log
  # A conflict leaves the project's file as it was, with no marker, and the merge next to it in a .rej
  # file, one per layer, that the body names. The PR is a draft until someone resolves them.
  # shellcheck disable=SC2016 # the backticks are Markdown
  for rej in README.md.rej README.md.cml.rej; do
    grep -qxF -- "- \`\` $rej \`\`" both-runner/copier-update/body.md
    git -C both.git show "chore/copier-update:$rej" | grep -qx '<<<<<<< before updating'
    git -C both.git show "chore/copier-update:$rej" | grep -qx 'template edit'
  done
  grep -q 'did not merge' both-runner/copier-update/body.md
  # The second layer's scan skips the first layer's .rej file.
  (! git -C both.git cat-file -e chore/copier-update:README.md.rej.rej 2>/dev/null)
  git -C both.git show chore/copier-update:README.md >both.readme
  test "$(cat both.readme)" = 'project line'
  grep -q '^pr create .* --draft$' both.log
  (lacks -q -- '--draft\|^pr ready' push.log edit.log)
  # An open PR the update adds conflicts to goes back to draft.
  grep -qx 'pr ready 7 --undo' edit-conflict.log
  # A non-ASCII name reaches the resolver unquoted.
  git -C café.git show 'chore/copier-update:café.md' | grep -qx 'project line'
  git -C café.git show 'chore/copier-update:café.md.rej' | grep -qx 'template edit'
  # Pins resolve with no .rej and no body note; CRLF lines keep their CR.
  for r in pin-project pin-template crlf frozen pyroot; do
    git -C "$r.git" show chore/copier-update:README.md >"$r.readme"
    (lacks -q '<<<<<<<' "$r.readme")
    (lacks -q 'did not merge' "$r-runner/copier-update/body.md")
    (lacks -q -- '--draft' "$r.log")
    (! git -C "$r.git" cat-file -e chore/copier-update:README.md.rej 2>/dev/null)
  done
  grep -qxF "$pin_b" pin-template.readme
  (lacks -q 1111111111 pin-template.readme)
  (lacks -q 2222222222 pin-project.readme crlf.readme frozen.readme pyroot.readme)
  grep -qxF "$pin_a" pin-project.readme
  grep -qxF "$pin_a"$'\r' crlf.readme
  grep -qxF '    rev: 1111111111111111111111111111111111111111 # frozen: v1.1.0' frozen.readme
  grep -qxF "$pin_a" pyroot.readme
  # A changed repo and a hunk with a real change stay conflicts. In mixed-hunks the .rej keeps only
  # the real one marked, its pin hunk already resolved.
  for r in repo-swap mixed-hunks; do
    git -C "$r.git" show chore/copier-update:README.md | grep -qx 'project line'
    git -C "$r.git" show chore/copier-update:README.md.rej >"$r.rej"
  done
  grep -q 'evil/b@' repo-swap.rej
  grep -c '^<<<<<<< before updating$' mixed-hunks.rej | grep -qx 1
  grep -qxF "$pin_a" mixed-hunks.rej
  grep -qx 'second template line' mixed-hunks.rej
  (lacks -q 'did not merge' layer-runner/copier-update/body.md)
  # A branch with someone else's commits is not force-pushed or edited.
  (lacks -q '^pr edit\|^pr create' human.log)
  grep -q 'someone other than this workflow' human.out
  grep -q 'someone other than this workflow' human.summary
  # No token and a workflow change: one issue, the older PR stays open, no push.
  # Only the issue this workflow opened counts: it runs with GITHUB_TOKEN there.
  grep -qxF 'issue list --state all --author app/github-actions --search "Update from template v0.10.0 by hand" in:title --json number --jq .[0].number' issue.log
  grep -c '^issue create --title Update from template v0.10.0 by hand ' issue.log | grep -qx 1
  grep -qF -- "--body-file $cuh/issue-runner/copier-update-issue.md" issue.log
  grep -qF 'Run `copier update --answers-file' issue-runner/copier-update-issue.md
  grep -qxF 'project issue notes' issue-clean/issue.md
  (lacks -q '^pr close' issue.log)
  grep -q 'Pull request #7 is still open for an older template version' issue.out
  (! git -C issue.git cat-file -e chore/copier-update:.github/workflows/ci.yml 2>/dev/null)
  # A large patch still takes the manual-update path if it touches a workflow.
  grep -qx 'workflows=true' issue-large.gho
  grep -q '^issue create ' issue-large.log
  (! git -C issue-large.git rev-parse --verify refs/heads/chore/copier-update 2>/dev/null)
  # An issue that exists, open or closed, is not asked again.
  (lacks -q '^issue create' asked.log)
  # A token pushes the branch with the workflow change, over the open PR's, then opens or
  # updates the PR. So does no token with no workflow change.
  for r in push:.github/workflows/ci.yml edit:.github/workflows/ci.yml plain:README.md; do
    git -C "${r%%:*}.git" show "chore/copier-update:${r#*:}" >"${r%%:*}.updated"
    grep -qx '# from the template' "${r%%:*}.updated"
    grep -qx 'project line' "${r%%:*}.updated"
    (lacks -q '^issue ' "${r%%:*}.log")
  done
  grep -q '^pr create --head chore/copier-update --base main ' push.log
  # gh becomes git's credential helper before the push.
  for r in push edit plain; do grep -qx 'auth setup-git' "$r.log"; done
  grep -q '^pr create --head chore/copier-update --base main ' plain.log
  (lacks -q '^workflows=' plain.gho)
  grep -qF 'Select **Approve workflows to run**' plain-runner/copier-update/body.md
  grep -q '^pr edit 7 ' edit.log
  (lacks -q '^pr create' edit.log)
  # Declining a tag suppresses both pushes and manual-update issues for that tag.
  for r in declined declined-no-token declined-plain; do
    (lacks -q '^auth setup-git\|^pr create\|^pr edit\|^issue ' "$r.log")
    (! git -C "$r.git" rev-parse --verify refs/heads/chore/copier-update 2>/dev/null)
  done
  # A tag under a week old is not applied: no copier run, no push, no pull request, no issue.
  (lacks -q '^uvx\|^pr create\|^pr edit\|^issue \|^auth setup-git' young.log)
  grep -q 'under a week old' young.out
  grep -q 'under a week old' young.summary
  # A lookalike owner waits like any other: the exemption is for simonvanlierde/ itself.
  (lacks -q '^uvx\|^pr create\|^pr edit' lookalike.log)
  grep -q 'under a week old' lookalike.out
  # The newest tag that is a week old is the one it updates to, not none.
  grep -qx "uvx --exclude-newer 1 week copier@$copier_pin update --answers-file .copier-answers.yml --defaults --vcs-ref v0.9.0" mixed.log
  # A simonvanlierde template is not held back.
  for r in own-young own-young-https; do
    grep -q '^pr create --head chore/copier-update --base main ' "$r.log"
    (lacks -q 'under a week old' "$r.out")
  done
  # An older declined tag or a merged PR does not suppress a newer update.
  for r in older-declined merged fork-declined fork-open; do
    grep -q '^pr create --head chore/copier-update --base main ' "$r.log"
  done
  (lacks -q '^pr edit\|^pr close' fork-open.log)
  grep -q '^issue create' fork-open-no-token.log
  (lacks -q '^pr close' fork-open-no-token.log)
  # Patch data must never replace Git configuration, and artifact symlinks are refused.
  git clone -q "$cuh/tpl" "$cuh/reject-checkout"
  mkdir -p "$cuh/reject/copier-update"
  echo body >"$cuh/reject/copier-update/body.md"
  cat >"$cuh/reject/copier-update/update.patch" <<'PATCH'
diff --git a/.git/config b/.git/config
new file mode 100644
--- /dev/null
+++ b/.git/config
@@ -0,0 +1 @@
+unsafe config
PATCH
  (
    cd "$cuh/reject-checkout"
    # shellcheck disable=SC2031 # the rejection check sets its own environment
    export RUNNER_TEMP="$cuh/reject" LATEST=v0.10.0
    if bash --noprofile --norc -eo pipefail "$cuh/apply.sh" >"$cuh/rejected.log" 2>&1; then
      echo "accepted a patch to Git configuration" >&2
      exit 1
    fi
    grep -qF ".git/config:" "$cuh/rejected.log"
    mv "$RUNNER_TEMP/copier-update/update.patch" "$RUNNER_TEMP/config.patch"
    ln -s "$RUNNER_TEMP/config.patch" "$RUNNER_TEMP/copier-update/update.patch"
    if bash --noprofile --norc -eo pipefail "$cuh/apply.sh" >"$cuh/rejected.log" 2>&1; then
      echo "accepted a symlink artifact" >&2
      exit 1
    fi
    # The symlink fails before Git gets to parse its invalid patch.
    (lacks -qF '.git/config' "$cuh/rejected.log")
  )
)

# rumdl's MD012 rewrites a README with two blank lines in a row on its first commit.
for r in a c; do
  if ! awk '/^$/ { if (++n == 2) exit 1; next } { n = 0 }' "$out/$r/README.md"; then
    echo "check-render: $r/README.md has two blank lines in a row" >&2
    exit 1
  fi
done

# Rendering over a repo with docs/adr leaves ADRs intact, and usage docs guide migration:
adr_dir=$out/adr-check
mkdir -p "$adr_dir/docs/adr"
echo "# 1. Record" >"$adr_dir/docs/adr/0001-x.md"
"${copier[@]}" --vcs-ref=HEAD \
  --data project_name=adr-check --data 'stacks=[python]' \
  --data python_kind=library "$repo" "$adr_dir"
test -f "$adr_dir/docs/adr/0001-x.md"
test ! -e "$adr_dir/docs/decisions"
grep -q 'docs/adr' "$repo/docs/updates.md"

# Each sample in _skip_if_exists (the entries after its `# Samples:` comment) has an
# update-only _exclude entry with the same path, and no other _exclude entry reads the
# operation. copier.yml says why the list cannot live in one place.
uv run --no-project --with pyyaml python - "$repo/copier.yml" <<'PY'
import sys, yaml
text = open(sys.argv[1]).read()
conf = yaml.safe_load(text)
samples = []
for line in text[text.index("\n  # Samples:") + 1:].splitlines():
    if line.startswith("  #"):
        continue
    if not line.startswith("  - "):
        break
    samples += yaml.safe_load(line.strip())
assert samples and set(samples) <= set(conf["_skip_if_exists"]), samples
want = {"{% if _copier_operation == 'update' %}" + s + "{% endif %}" for s in samples}
have = {e for e in conf["_exclude"] if "_copier_operation" in e}
assert not want - have, f"samples not excluded on update: {sorted(want - have)}"
assert not have - want, f"update-only excludes outside the samples group: {sorted(have - want)}"
PY

# A sample the project deleted stays deleted on copier update; an owned file it deleted comes
# back. The update must cross a template commit that changes those files: from an unchanged
# template, copier keeps a project's own deletions even without the skip and exclude rules. A
# throwaway template repo holds the working tree, so uncommitted edits are tested too.
sample_tpl=$out/sample-tpl
sample_up=$out/sample-up
mkdir -p "$sample_tpl"
cp -R "$repo/copier.yml" "$repo/includes" "$repo/template" "$sample_tpl/"
# These throwaway repos have no remote, and a host commit hook can read such a repo as public: --no-verify.
git_t=(git -C "$sample_tpl" -c user.name=t -c user.email=t@example.org)
"${git_t[@]}" init -q
"${git_t[@]}" add -A
"${git_t[@]}" commit -q --no-verify -m base
"${copier[@]}" --vcs-ref=HEAD \
  --data project_name=sample-me --data 'stacks=[python,ts]' --data python_kind=library \
  --data ts_dir=web --data ts_kind=web-app --data user_data=nothing --data worker=true \
  --data site=astro --data site_host=cloudflare --data decision_records=true --data 'extras=[docs_site]' \
  "$sample_tpl" "$sample_up" >/dev/null
# Every sample this render has: a missing one fails here, before the update can pass on it.
samples=(src/sample_me/__init__.py tests/test_add.py
  web/src/App.tsx web/src/App.test.tsx web/src/main.tsx web/src/app.css
  web/worker/index.ts web/worker/index.test.ts
  site/src/pages/index.astro site/src/pages/about.md site/worker/index.mjs site/worker/index.test.mjs)
owned=(docs/decisions/0001-start-from-project-templates.md docs/og-card.html docs/assets/docs-tokens.css)
(cd "$sample_up" && rm "${samples[@]}" "${owned[@]}")
git -C "$sample_up" init -q
git -C "$sample_up" add -A
git -C "$sample_up" -c user.name=t -c user.email=t@example.org commit -q --no-verify -m "replace the samples"
# The Starlight docs' owned files come back the same way.
"${copier[@]}" --vcs-ref=HEAD --data project_name=sample-docs --data 'stacks=[rust]' --data 'extras=[docs_site]' \
  "$sample_tpl" "$sample_up-docs" >/dev/null
owned_docs=(docs-site/astro.config.mjs docs-site/public/favicon.svg)
(cd "$sample_up-docs" && rm "${owned_docs[@]}")
git -C "$sample_up-docs" init -q
git -C "$sample_up-docs" add -A
git -C "$sample_up-docs" -c user.name=t -c user.email=t@example.org commit -q --no-verify -m "delete the owned docs files"
# A Rust binary with its own main.rs keeps it, and the update says to drop the starter's dependencies.
"${copier[@]}" --vcs-ref=HEAD --data project_name=sample-bin --data 'stacks=[rust]' --data rust_kind=binary \
  "$sample_tpl" "$sample_up-bin" >/dev/null
echo 'fn main() {}' >"$sample_up-bin/src/main.rs"
git -C "$sample_up-bin" init -q
git -C "$sample_up-bin" add -A
git -C "$sample_up-bin" -c user.name=t -c user.email=t@example.org commit -q --no-verify -m "own main.rs"
find "$sample_tpl/template" -type f \( -name '*test_add.py*' -o -name '__init__.py.jinja' \
  -o -name '*App.tsx*' -o -name '*App.test.tsx*' -o -name '*main.tsx*' -o -name '*app.css*' \
  -o -path '*worker*/index.ts' -o -path '*worker*/index.test.ts' -o -path '*worker*/index.mjs' \
  -o -path '*worker*/index.test.mjs' -o -name 'index.astro.jinja' -o -name 'about.md' \
  -o -name '0001-start-from-project-templates.md.jinja' \) -exec sh -c 'echo "// changed upstream" >>"$1"' _ {} \;
"${git_t[@]}" commit -q --no-verify -am "change the samples"
# shellcheck disable=SC2031 # COPIER_VERSION is set at file top
uvx "copier${COPIER_VERSION:+@$COPIER_VERSION}" update --defaults --vcs-ref=HEAD "$sample_up" >"$out/sample-up.log" 2>&1
grep -q 'Updating to template version' "$out/sample-up.log"
back=$(cd "$sample_up" && for f in "${samples[@]}"; do if [ -e "$f" ]; then echo "$f"; fi; done)
test -z "$back" || {
  echo "check-render: copier update brought back deleted samples: $back" >&2
  exit 1
}
for f in "${owned[@]}"; do test -f "$sample_up/$f"; done
# shellcheck disable=SC2031 # COPIER_VERSION is set at file top
uvx "copier${COPIER_VERSION:+@$COPIER_VERSION}" update --defaults --vcs-ref=HEAD "$sample_up-docs" >"$out/sample-up-docs.log" 2>&1
for f in "${owned_docs[@]}"; do test -f "$sample_up-docs/$f"; done
# shellcheck disable=SC2031 # COPIER_VERSION is set at file top
uvx "copier${COPIER_VERSION:+@$COPIER_VERSION}" update --defaults --vcs-ref=HEAD "$sample_up-bin" >"$out/sample-up-bin.log" 2>&1
grep -qx 'fn main() {}' "$sample_up-bin/src/main.rs"
grep -qxF 'If src/main.rs is your own, remove serde_json and jsonschema from Cargo.toml unless it uses them.' "$out/sample-up-bin.log"

# install-action falls back to cargo-binstall for a tool past its manifest, which
# installs an unchecked binary: every step says fallback: none, but cargo-codspeed,
# which the manifest does not list.
# The sweep counts the steps it saw, so a changed `uses:` spelling cannot pass it by
# matching nothing.
unpinned=$(find . -path '*/.github/workflows/*.yml' -exec awk '
  FNR == 1 { n = 0 }
  /uses: taiki-e\/install-action@/ { n = 3; step = ""; seen++; next }
  n > 0 { step = step $0 "\n"; if (--n == 0 && step !~ /fallback: none/ && step !~ /tool: cargo-codspeed@/) print FILENAME }
  END { if (!seen) print "no install-action step found" }
' {} +)
test -z "$unpinned" || {
  echo "install-action without fallback: none: $unpinned" >&2
  exit 1
}

# v0.14.0 optional answers survive the move to extras, including explicit false
# values at standard, the old `kind` answer survives its rename to python_kind, and
# the old openssf_badge answer becomes level.
# An untagged scratch history keeps updates local.
# shellcheck disable=SC2030,SC2031 # each test subshell sets its own environment
(
  while IFS= read -r git_var; do unset "$git_var"; done < <(git rev-parse --local-env-vars)
  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
  extras_tpl=$out/extras-tpl
  mkdir -p "$extras_tpl"
  git -C "$repo" archive v0.14.0 copier.yml includes template | tar -x -C "$extras_tpl"
  git_extras=(git -C "$extras_tpl" -c core.hooksPath=/dev/null -c user.name=t -c user.email=t@example.org)
  "${git_extras[@]}" init -q
  "${git_extras[@]}" add copier.yml includes template
  "${git_extras[@]}" commit -qm old
  for selection in all some none; do
    flags=()
    for feature in codecov codspeed profiling cold_install python_windows docs_site; do
      enabled=false
      if [ "$selection" = all ] || { [ "$selection" = some ] && [ "$feature" = python_windows ]; }; then
        enabled=true
      fi
      flags+=(--data "$feature=$enabled")
    done
    if [ "$selection" = all ]; then flags+=(--data 'test_extras=[property,mutation]'); fi
    # The old `kind` answer becomes python_kind; research keeps its notebooks/.
    if [ "$selection" = some ]; then flags+=(--data kind=research); fi
    "${copier[@]}" --vcs-ref=HEAD --quiet --data project_name=extras-check \
      --data 'stacks=[python,ts,rust,go]' "${flags[@]}" "$extras_tpl" "$out/extras-$selection"
    git -C "$out/extras-$selection" -c core.hooksPath=/dev/null init -q
    git -C "$out/extras-$selection" add .
    git -C "$out/extras-$selection" -c core.hooksPath=/dev/null -c user.name=t -c user.email=t@example.org commit -qm old
  done
  # The old openssf_badge answer becomes level: silver keeps its governance documents.
  for badge in silver none; do
    "${copier[@]}" --vcs-ref=HEAD --quiet --data project_name=level-check \
      --data "openssf_badge=$badge" "$extras_tpl" "$out/level-$badge"
    if [ "$badge" = silver ]; then echo "Edited by the project." >>"$out/level-$badge/GOVERNANCE.md"; fi
    git -C "$out/level-$badge" -c core.hooksPath=/dev/null init -q
    git -C "$out/level-$badge" add .
    git -C "$out/level-$badge" -c core.hooksPath=/dev/null -c user.name=t -c user.email=t@example.org commit -qm old
  done
  cp "$repo/copier.yml" "$extras_tpl/copier.yml"
  cp -R "$repo/includes/." "$extras_tpl/includes/"
  cp -R "$repo/template/." "$extras_tpl/template/"
  "${git_extras[@]}" add copier.yml includes template
  "${git_extras[@]}" commit -qm extras
  # shellcheck disable=SC2329 # bg runs it.
  update_in() { cd "$1" && uvx "copier${COPIER_VERSION:+@$COPIER_VERSION}" update --vcs-ref=HEAD --defaults --quiet; }
  for selection in extras-all extras-some extras-none level-silver level-none; do bg update_in "$out/$selection"; done
  bg_wait
  uv run --no-project --with pyyaml python - "$out" <<'PYTEST'
from pathlib import Path
import sys, yaml
root = Path(sys.argv[1])
features = {'codecov', 'codspeed', 'profiling', 'cold_install', 'python_windows', 'docs_site'}
for selection, expected in [('all', features | {'property', 'mutation'}),
                            ('some', {'python_windows'}), ('none', set())]:
    project = root / f'extras-{selection}'
    answers = yaml.safe_load((project / '.copier-answers.yml').read_text())
    assert set(answers['extras']) == expected, (selection, answers)
    assert not (features | {'test_extras'}) & answers.keys(), answers
    assert answers['python_kind'] == ('research' if selection == 'some' else 'library'), answers
    assert 'kind' not in answers, answers
    assert (project / 'notebooks').is_dir() == (selection == 'some'), selection
    for path, feature in [('codecov.yml', 'codecov'), ('zensical.toml', 'docs_site'),
                          ('.github/workflows/cold-install.yml', 'cold_install'),
                          ('.github/workflows/benchmarks.yml', 'codspeed'),
                          ('.github/workflows/property.yml', 'property'),
                          ('.github/workflows/mutation.yml', 'mutation')]:
        assert (project / path).exists() == (feature in expected), (selection, path)
    workflow = (project / '.github/workflows/python.yml').read_text()
    assert ('windows-latest' in workflow) == ('python_windows' in expected), selection
    assert not list(project.rglob('*.rej')), selection
    # The kept zensical.toml does not list the new tokens file, so docs.css falls back to its values.
    if 'docs_site' in expected:
        assert (project / 'docs/assets/docs-tokens.css').is_file(), selection
        assert 'docs-tokens' not in (project / 'zensical.toml').read_text(), selection
        assert 'var(--docs-paper, #ffffff)' in (project / 'docs/assets/docs.css').read_text(), selection
    # publish_to_crates is new since v0.14.0: an update keeps the crate unpublishable.
    assert answers['publish_to_crates'] is False, answers
    assert 'publish = false' in (project / 'Cargo.toml').read_text(), selection
    assert not (project / '.github/workflows/rust-release.yml').exists(), selection
PYTEST
  grep -qx 'level: community' "$out/level-silver/.copier-answers.yml"
  grep -qx 'level: minimal' "$out/level-none/.copier-answers.yml"
  for f in GOVERNANCE.md docs/roadmap.md docs/assurance-case.md; do test -f "$out/level-silver/$f"; done
  grep -qx 'Edited by the project.' "$out/level-silver/GOVERNANCE.md"
  (lacks openssf_badge "$out/level-silver/.copier-answers.yml")
  # A later edit replaces the full selection rather than reviving legacy answers.
  git -C "$out/extras-all" add .
  git -C "$out/extras-all" -c core.hooksPath=/dev/null -c user.name=t -c user.email=t@example.org commit -qm migrated
  (
    cd "$out/extras-all"
    uvx "copier${COPIER_VERSION:+@$COPIER_VERSION}" update --vcs-ref=HEAD --defaults --quiet --data 'extras=[]'
  )
  grep -qx 'extras: \[\]' "$out/extras-all/.copier-answers.yml"
  test ! -e "$out/extras-all/.github/workflows/cold-install.yml"
  test ! -e "$out/extras-all/zensical.toml"
)

# Where rulesets fail for the plan, repo-settings also says the update App's key is readable
# from any branch. Renovate projects have no App key.
grep -qF 'cannot limit branches either' "$out/a/justfile"
(lacks -F 'cannot limit branches either' "$out/d/justfile")

# A v0.15.0 docs site in a Rust or TypeScript repo stored no docs_engine. The new default would
# be Starlight; the update keeps it on Zensical and stores that answer.
# shellcheck disable=SC2030,SC2031 # each test subshell sets its own environment
(
  while IFS= read -r git_var; do unset "$git_var"; done < <(git rev-parse --local-env-vars)
  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
  engine_tpl=$out/engine-tpl
  mkdir -p "$engine_tpl"
  git -C "$repo" archive v0.15.0 copier.yml includes template | tar -x -C "$engine_tpl"
  git_engine=(git -C "$engine_tpl" -c core.hooksPath=/dev/null -c user.name=t -c user.email=t@example.org)
  "${git_engine[@]}" init -q
  "${git_engine[@]}" add copier.yml includes template
  "${git_engine[@]}" commit -qm old
  for stack in rust ts; do
    p=$out/engine-$stack
    "${copier[@]}" --vcs-ref=HEAD --quiet --data project_name=engine-check \
      --data "stacks=[$stack]" --data 'extras=[docs_site]' "$engine_tpl" "$p"
    (lacks -q docs_engine "$p/.copier-answers.yml")
    git -C "$p" -c core.hooksPath=/dev/null init -q
    git -C "$p" add .
    git -C "$p" -c core.hooksPath=/dev/null -c user.name=t -c user.email=t@example.org commit -qm old
  done
  rm -rf "$engine_tpl/includes" "$engine_tpl/template"
  cp "$repo/copier.yml" "$engine_tpl/copier.yml"
  cp -R "$repo/includes" "$repo/template" "$engine_tpl/"
  "${git_engine[@]}" add -A copier.yml includes template
  "${git_engine[@]}" commit -qm engine
  for stack in rust ts; do
    p=$out/engine-$stack
    (cd "$p" && uvx "copier${COPIER_VERSION:+@$COPIER_VERSION}" update --vcs-ref=HEAD --defaults --quiet)
    grep -qx 'docs_engine: zensical' "$p/.copier-answers.yml"
    test -f "$p/zensical.toml"
    test -f "$p/docs/assets/docs.css"
    test -f "$p/docs-site/pyproject.toml"
    test ! -e "$p/docs-site/package.json"
  done
)
