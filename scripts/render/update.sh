# shellcheck shell=bash
# shellcheck disable=SC2030 # independent test subshells set their own environment
# shellcheck disable=SC2154,SC2164 # check-render.sh sets out, repo, copier and set -e
# Template updates: the copier-update workflow, ADRs and sample code across an update.
# Renders adr-check and sample-up, which the install-action sweep at the end covers.

# copier-update pushes with the update App's token when it is set up; GITHUB_TOKEN can't push workflow
# changes, so without it a workflow change becomes an issue, not a failed push.
cu=a/.github/workflows/copier-update.yml
# Copier dependencies and the push token must run on separate workers.
uv run --no-project --with pyyaml python - "$cu" <<'PYTEST'
import sys, yaml
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
PYTEST
cuh=$out/copier-update
mkdir -p "$cuh"
awk -v d="$cuh" '/^      - /{n++} n{print >(d "/step" n)}' "$cu"
grep -l 'copier@' "$cuh"/step* | grep -q .
(! grep -l 'copier@' "$cuh"/step* | xargs grep -q COPIER_UPDATE_PRIVATE_KEY)
# shellcheck disable=SC2016 # literal workflow text, not shell expansions
grep -qF 'GH_TOKEN: ${{ steps.app.outputs.token || github.token }}' "$cu"
# The token never sits in a command line: git asks gh's credential helper for it.
(lacks -q 'x-access-token' "$cu")
grep -qx '      issues: write # to ask for a local update when it can.t push one' "$cu"
# The run below stands in true or false for this expression.
grep -qF "HAS_TOKEN: \${{ steps.app.outputs.token != '' }}" "$cu"
# Run the step's script against a fake gh, a fake uvx that changes one file, a template
# repo with two tags and a bare repo standing in for GitHub. GIT_ALLOW_PROTOCOL=file makes
# a push that misses the rewrite fail instead of reaching github.com.
# Each step's script: the copier step runs first, with no token, then the push step.
for n in copier apply push; do
  case $n in copier) name=Update ;; apply) name=Apply ;; push) name=Push ;; esac
  f=$(grep -l "^      - name: $name" "$cuh"/step*)
  awk '/^        run: \|-$/{f=1;next} f&&NF&&!/^          /{exit} f{sub(/^          /,"");print}' "$f" >"$cuh/$n.sh"
done
cat >"$cuh/gh" <<'FAKE'
#!/usr/bin/env bash
echo "$*" >>"$FAKE_LOG"
case "$1 $2" in
  "issue list") echo "${FAKE_ISSUE:-}" ;;
  "pr list")
    case " $* " in
      *" --state closed "*) printf '%s\n' "${FAKE_CLOSED_PRS:-[]}" ;;
      *) echo "${FAKE_PR:-}" ;;
    esac
    ;;
esac
FAKE
cat >"$cuh/uvx" <<'FAKE'
#!/usr/bin/env bash
echo "uvx $*" >>"$FAKE_LOG"
mkdir -p "$(dirname "$FAKE_FILE")"
echo "${FAKE_TEXT:-# from the template}" >>"$FAKE_FILE"
FAKE
chmod +x "$cuh/gh" "$cuh/uvx"
(
  # A subshell drops the ERR trap; set -E would fire it in every (! ...) below.
  trap 'echo "check-render: failed at ${BASH_SOURCE[0]}:$LINENO" >&2' ERR
  # shellcheck disable=SC2031 # a separate subshell sets its own
  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_ALLOW_PROTOCOL=file \
    GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.org GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.org
  git init -q -b main "$cuh/tpl"
  git -C "$cuh/tpl" commit -q --allow-empty -m one
  git -C "$cuh/tpl" tag v0.9.0
  git -C "$cuh/tpl" tag v0.10.0
  # name, HAS_TOKEN, the open PR and the issue the fake gh finds ("-": none), and the
  # file the update changes.
  while read -r name token pr issue file; do
    p=$cuh/$name
    git init -q --bare "$p.git"
    # An open PR has its branch on the remote, on a history the update does not extend.
    if [ "$pr" != - ]; then git -C "$cuh/tpl" push -q "$p.git" HEAD:refs/heads/chore/copier-update; fi
    git init -q -b main "$p"
    printf '_commit: v0.9.0\n_src_path: %s\n' "$cuh/tpl" >"$p/.copier-answers.yml"
    # A layered template with its own answers file; this project's own is already current.
    if [ "$name" = layer ]; then
      cp "$p/.copier-answers.yml" "$p/.copier-answers.cml.yml"
      printf '_commit: v0.10.0\n_src_path: %s\n' "$cuh/tpl" >"$p/.copier-answers.yml"
    fi
    # Both answers files behind, and an update that leaves a conflict marker.
    if [ "$name" = both ]; then cp "$p/.copier-answers.yml" "$p/.copier-answers.cml.yml"; fi
    git -C "$p" add -A
    git -C "$p" commit -q -m init
    # The privileged job starts from a clean checkout, not the generator's worktree.
    git clone -q "$p" "$p-clean"
    (
      cd "$p"
      # shellcheck disable=SC2030,SC2031 # each fake run sets its own environment
      export PATH="$cuh:$PATH" FAKE_LOG="$p.log" FAKE_PR="${pr#-}" FAKE_ISSUE="${issue#-}" \
        FAKE_FILE="${file:-.github/workflows/ci.yml}" \
        GH_TOKEN=fake HAS_TOKEN="$token" REPO=example-org/render-me BASE=main COPIER_VERSION="$copier_pin" \
        RUNNER_TEMP="$p-runner"
      export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0="url.$p.git.insteadOf" \
        GIT_CONFIG_VALUE_0="https://github.com/$REPO.git"
      FAKE_TEXT=''
      if [ "$name" = both ]; then FAKE_TEXT='<<<<<<< before updating'; fi
      export FAKE_TEXT
      FAKE_CLOSED_PRS='[]'
      # shellcheck disable=SC2089 # JSON data, never evaluated as shell code.
      case $name in
      declined*) FAKE_CLOSED_PRS='[{"title":"chore: update from template v0.10.0","mergedAt":null}]' ;;
      older-declined) FAKE_CLOSED_PRS='[{"title":"chore: update from template v0.9.0","mergedAt":null}]' ;;
      merged) FAKE_CLOSED_PRS='[{"title":"chore: update from template v0.10.0","mergedAt":"2026-11-11T12:00:00Z"}]' ;;
      esac
      # shellcheck disable=SC2090 # The fake gh prints this JSON verbatim.
      export FAKE_CLOSED_PRS
      : >"$p.gho"
      # The copier step gets neither token variable.
      env -u GH_TOKEN -u HAS_TOKEN GITHUB_OUTPUT="$p.gho" bash --noprofile --norc -eo pipefail "$cuh/copier.sh" >"$p.out" 2>&1 || {
        cat "$p.out" >&2
        exit 1
      }
      # shellcheck disable=SC2030 # each fake run reads its own outputs
      LATEST=$(sed -n 's/^latest=//p' "$p.gho") WORKFLOWS=$(sed -n 's/^workflows=//p' "$p.gho")
      export LATEST WORKFLOWS
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
asked false - 3
push true - -
edit true 7 -
plain false - - README.md
layer true - - README.md
both true - - README.md
declined true - -
declined-no-token false - -
declined-plain false - - README.md
older-declined true - -
merged true - -
CASES
  cd "$cuh"
  # Newest tag by version, not by name.
  grep -qx "uvx --exclude-newer 1 week copier@$copier_pin update --answers-file .copier-answers.yml --defaults --vcs-ref v0.10.0" issue.log
  # Each answers file updates on its own, and the PR names the layer that moved.
  grep -qx "uvx --exclude-newer 1 week copier@$copier_pin update --answers-file .copier-answers.cml.yml --defaults --vcs-ref v0.10.0" layer.log
  (lacks -q 'answers-file .copier-answers.yml' layer.log)
  grep -q '^pr create --head chore/copier-update --base main --title chore: update from template cml v0.10.0 ' layer.log
  git -C layer.git show chore/copier-update:README.md | grep -qx '# from the template'
  # Two templates that both moved share one title, and a conflict marker is named in the body.
  grep -q '^pr create --head chore/copier-update --base main --title chore: update from template v0.10.0, cml v0.10.0 ' both.log
  # shellcheck disable=SC2016 # the backticks are Markdown
  grep -qx -- '- `README.md`' both-runner/copier-update/body.md
  (lacks -q 'merge conflicts' layer-runner/copier-update/body.md)
  # No token and a workflow change: one issue, the older PR closed, no push.
  grep -qxF 'issue list --state all --search "Update from template v0.10.0 by hand" in:title --json number --jq .[0].number' issue.log
  grep -c '^issue create --title Update from template v0.10.0 by hand ' issue.log | grep -qx 1
  grep -q '^pr close 7 --delete-branch ' issue.log
  (! git -C issue.git cat-file -e chore/copier-update:.github/workflows/ci.yml 2>/dev/null)
  # An issue that exists, open or closed, is not asked again.
  (lacks -q '^issue create' asked.log)
  # A token pushes the branch with the workflow change, over the open PR's, then opens or
  # updates the PR. So does no token with no workflow change.
  for r in push:.github/workflows/ci.yml edit:.github/workflows/ci.yml plain:README.md; do
    git -C "${r%%:*}.git" show "chore/copier-update:${r#*:}" | grep -qx '# from the template'
    (lacks -q '^issue ' "${r%%:*}.log")
  done
  grep -q '^pr create --head chore/copier-update --base main ' push.log
  # gh becomes git's credential helper before the push.
  for r in push edit plain; do grep -qx 'auth setup-git' "$r.log"; done
  grep -q '^pr create --head chore/copier-update --base main ' plain.log
  grep -q '^pr edit chore/copier-update ' edit.log
  (lacks -q '^pr create' edit.log)
  # Declining a tag suppresses both pushes and manual-update issues for that tag.
  for r in declined declined-no-token declined-plain; do
    (lacks -q '^auth setup-git\|^pr create\|^pr edit\|^issue ' "$r.log")
    (! git -C "$r.git" rev-parse --verify refs/heads/chore/copier-update 2>/dev/null)
  done
  # An older declined tag or a merged PR does not suppress a newer update.
  for r in older-declined merged; do
    grep -q '^pr create --head chore/copier-update --base main ' "$r.log"
  done
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
grep -q 'docs/adr' "$repo/docs/usage.md"

# Each sample in _skip_if_exists (the entries after its `# Samples:` comment) has an
# update-only _exclude entry with the same path, and no update-only entry lacks one.
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
have = {e for e in conf["_exclude"] if e.startswith("{% if _copier_operation == 'update' %}")}
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
git_t=(git -C "$sample_tpl" -c user.name=t -c user.email=t@example.org)
"${git_t[@]}" init -q
"${git_t[@]}" add -A
"${git_t[@]}" commit -q -m base
"${copier[@]}" --vcs-ref=HEAD \
  --data project_name=sample-me --data 'stacks=[python,ts]' --data python_kind=library \
  --data ts_dir=web --data ts_kind=web-app --data user_data=nothing --data worker=true \
  --data site=astro --data site_host=cloudflare --data decision_records=true \
  "$sample_tpl" "$sample_up" >/dev/null
# Every sample this render has: a missing one fails here, before the update can pass on it.
samples=(src/sample_me/__init__.py tests/test_add.py
  web/src/App.tsx web/src/App.test.tsx web/src/main.tsx web/src/app.css
  web/worker/index.ts web/worker/index.test.ts
  site/src/pages/index.astro site/src/pages/about.md site/worker/index.mjs site/worker/index.test.mjs
  docs/og-card.html)
owned=docs/decisions/0001-start-from-project-templates.md
(cd "$sample_up" && rm "${samples[@]}" "$owned")
git -C "$sample_up" init -q
git -C "$sample_up" add -A
git -C "$sample_up" -c user.name=t -c user.email=t@example.org commit -q -m "replace the samples"
find "$sample_tpl/template" -type f \( -name '*test_add.py*' -o -name '__init__.py.jinja' \
  -o -name '*App.tsx*' -o -name '*App.test.tsx*' -o -name '*main.tsx*' -o -name '*app.css*' \
  -o -path '*worker*/index.ts' -o -path '*worker*/index.test.ts' -o -path '*worker*/index.mjs' \
  -o -path '*worker*/index.test.mjs' -o -name 'index.astro.jinja' -o -name 'about.md' \
  -o -name '0001-start-from-project-templates.md.jinja' \) -exec sh -c 'echo "// changed upstream" >>"$1"' _ {} \;
"${git_t[@]}" commit -q -am "change the samples"
# shellcheck disable=SC2031 # COPIER_VERSION is set at file top
uvx "copier${COPIER_VERSION:+@$COPIER_VERSION}" update --defaults --vcs-ref=HEAD "$sample_up" >"$out/sample-up.log" 2>&1
grep -q 'Updating to template version' "$out/sample-up.log"
back=$(cd "$sample_up" && for f in "${samples[@]}"; do if [ -e "$f" ]; then echo "$f"; fi; done)
test -z "$back" || {
  echo "check-render: copier update brought back deleted samples: $back" >&2
  exit 1
}
test -f "$sample_up/$owned"

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
# values at standard, and the old `kind` answer survives its rename to python_kind.
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
  cp "$repo/copier.yml" "$extras_tpl/copier.yml"
  cp -R "$repo/includes/." "$extras_tpl/includes/"
  cp -R "$repo/template/." "$extras_tpl/template/"
  "${git_extras[@]}" add copier.yml includes template
  "${git_extras[@]}" commit -qm extras
  for selection in all some none; do
    (
      cd "$out/extras-$selection"
      uvx "copier${COPIER_VERSION:+@$COPIER_VERSION}" update --vcs-ref=HEAD --defaults --quiet
    )
  done
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
PYTEST
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
