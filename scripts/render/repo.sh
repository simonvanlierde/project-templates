# shellcheck shell=bash
# shellcheck disable=SC2154,SC2164 # check-render.sh sets out, repo, copier and set -e
# repo-settings against a fake gh, repo-about, community files, badges and DCO.

# repo-settings: a fake gh keeps a list of rulesets and applies the recipe's real --jq
# filter to it. An existing ruleset with a legacy name (protect-main) is adopted in place.
test -f a/.github/rulesets/main.json
test -f a/.github/rulesets/main-checks.json
# A root stack's check is required; c's nested stacks run only on their own paths, so theirs aren't.
test "$(jq -c '[.rules[0].parameters.required_status_checks[].context]' a/.github/rulesets/main-checks.json)" = '["git hooks","pull request title","DCO sign-off","dependency review","python: lint, types, tests","ts: lint, types, tests","fmt, clippy, tests, deny","golangci-lint, tests, govulncheck"]'
test "$(jq '.rules[0].parameters.required_status_checks | length' c/.github/rulesets/main-checks.json)" = 4
test -f a/.github/rulesets/tags.json
fake=$out/fake-gh
mkdir -p "$fake"
echo '[{"name": "release-branches", "target": "branch", "id": 7, "conditions": {"ref_name": {"include": ["refs/heads/release/*"]}}}, {"name": "protect-main", "target": "branch", "id": 42, "conditions": {"ref_name": {"include": ["~DEFAULT_BRANCH"]}}}]' >"$fake/rulesets.json"
cat >"$fake/gh" <<'FAKE'
#!/usr/bin/env bash
echo "$*" >>"$FAKE_LOG"
call=$*
input='' filter=''
while [ $# -gt 0 ]; do
  case $1 in --input) input=$2 ;; --jq) filter=$2 ;; esac
  shift
done
list=$FAKE_DIR/rulesets.json
case $call in
  *"api user"*) echo "90462640" ;;
  *"security_and_analysis"*)
    if [ -n "${FAKE_SECRET:-}" ]; then
      echo "gh: Secret scanning is not available for this repository. (HTTP $FAKE_SECRET)" >&2
      exit 1
    fi
    echo '{}' ;;
  *"code-scanning/default-setup"*)
    if [ -n "${FAKE_CODEQL:-}" ]; then
      echo '{"message":"Code Security must be enabled for this repository to use code scanning.","status":"403"}'
      echo "gh: refused (HTTP $FAKE_CODEQL)" >&2
      exit 1
    fi
    echo '{"state":"configured"}' ;;
  *"-X POST repos/{owner}/{repo}/rulesets --input"*)
    jq --slurpfile b "$input" '. + [{name: $b[0].name, target: $b[0].target, conditions: $b[0].conditions, id: (length + 41)}]' "$list" >"$list.new" && mv "$list.new" "$list"
    cp "$input" "$FAKE_DIR/posted.$(basename "$input")" ;;
  *"-X PUT repos/{owner}/{repo}/rulesets/"*)
    id=${call#*rulesets/}
    id=${id%% *}
    jq --slurpfile b "$input" --argjson id "$id" 'map(if .id == $id then .name = $b[0].name | .target = $b[0].target | .conditions = $b[0].conditions else . end)' "$list" >"$list.new" && mv "$list.new" "$list"
    cp "$input" "$FAKE_DIR/put.$(basename "$input")" ;;
  # The list has no conditions; a GET of one ruleset does.
  *"/rulesets?includes_parents=false"*) jq -r "map(del(.conditions)) | $filter" "$list" ;;
  *"api repos/{owner}/{repo}/rulesets/"*)
    id=${call#*rulesets/}
    id=${id%% *}
    jq -r --argjson id "$id" "first(.[] | select(.id == \$id)) | $filter" "$list" ;;
  *"-X POST repos/{owner}/{repo}/environments/"*"/deployment-branch-policies"*)
    env=${call#*environments/}
    env=${env%%/*}
    pol=$FAKE_DIR/policies-$env.json
    [ -f "$pol" ] || echo '{"branch_policies":[]}' >"$pol"
    name=''
    for arg in $call; do
      case $arg in name=*) name=${arg#name=} ;; esac
    done
    jq --arg n "$name" '.branch_policies += [{"name": $n}]' "$pol" >"$pol.new"
    mv "$pol.new" "$pol"
    echo '{}' ;;
  *"/deployment-branch-policies"*)
    env=${call#*environments/}
    env=${env%%/*}
    pol=$FAKE_DIR/policies-$env.json
    [ -f "$pol" ] || echo '{"branch_policies":[]}' >"$pol"
    jq -r "$filter" "$pol" ;;
  *"-X PUT repos/{owner}/{repo}/environments/"*) echo '{}' ;;
  # Pages is created once; GitHub refuses a second create with 409.
  *"-X POST repos/{owner}/{repo}/pages "*)
    if [ -n "${FAKE_PAGES:-}" ]; then
      echo "gh: refused (HTTP $FAKE_PAGES)" >&2
      exit 1
    fi
    if [ -f "$FAKE_DIR/pages" ]; then
      echo '{"message":"GitHub Pages is already enabled.","status":"409"}'
      echo 'gh: GitHub Pages is already enabled. (HTTP 409)' >&2
      exit 1
    fi
    : >"$FAKE_DIR/pages"
    echo '{}' ;;
  *"-X PUT repos/{owner}/{repo}/pages "*) echo '{}' ;;
  *"repos/{owner}/{repo}"*"--jq .full_name"*) echo "simonvanlierde/project-templates" ;;
esac
FAKE
chmod +x "$fake/gh"
(
  cd a
  # shellcheck disable=SC2030 # the about test and the copier-update run below set their own PATH
  export FAKE_LOG="$fake/log" FAKE_DIR="$fake" PATH="$fake:$PATH"
  just repo-settings >/dev/null
  just repo-settings >/dev/null
  # main adopted protect-main, so only main-checks and tags were posted.
  test "$(grep -c -- '-X POST repos/{owner}/{repo}/rulesets' "$FAKE_LOG")" = 2
  grep -qxF -- 'api -X PUT repos/{owner}/{repo}/rulesets/42 --input .github/rulesets/main.json' "$FAKE_LOG"
  grep -qxF -- 'api -X PUT repos/{owner}/{repo}/rulesets/43 --input .github/rulesets/main-checks.json' "$FAKE_LOG"
  grep -qxF -- 'api -X PUT repos/{owner}/{repo}/rulesets/44 --input .github/rulesets/tags.json' "$FAKE_LOG"
  # a uses Dependabot, so copier-update.yml gets its environment, limited to main.
  grep -q -- '^api -X PUT repos/{owner}/{repo}/environments/copier-update ' "$FAKE_LOG"
  grep -qF -- 'api -X POST repos/{owner}/{repo}/environments/copier-update/deployment-branch-policies -f name=main -f type=branch' "$FAKE_LOG"
  # A branch ruleset that protects other refs is never adopted.
  (lacks -q -- '-X PUT repos/{owner}/{repo}/rulesets/7 ' "$FAKE_LOG")
  test "$(jq -r '.[] | select(.id == 7) | .name' "$fake/rulesets.json")" = "release-branches"
  # The adoption check matches the files' own conditions.
  jq -e '.conditions.ref_name.include == ["~DEFAULT_BRANCH"]' .github/rulesets/main.json .github/rulesets/main-checks.json >/dev/null
  # protect-main was updated in place to main: no duplicate ruleset on the default branch.
  test "$(jq -r '.[] | select(.id == 42) | .name' "$fake/rulesets.json")" = "main"
  (! jq -e '.[] | select(.name == "protect-main")' "$fake/rulesets.json" >/dev/null)
  patch=$(grep -- '^api -X PATCH repos/{owner}/{repo} ' "$FAKE_LOG" | head -1)
  for flag in allow_squash_merge=true allow_merge_commit=false allow_rebase_merge=false delete_branch_on_merge=true; do
    [[ "$patch " == *" -F $flag "* ]]
  done
  # Every public render has the DCO check, so web commits need a sign-off from silver down.
  [[ "$patch " == *" -F web_commit_signoff_required=true "* ]]
  # OSPS Baseline BR-07.01: push protection refuses a known secret format before it lands.
  # It has a PATCH of its own, so a repo without Secret Protection still gets the rest.
  (lacks -q 'security_and_analysis' <<<"$patch")
  secret=$(grep -F -- 'api -X PATCH repos/{owner}/{repo} -f security_and_analysis' "$FAKE_LOG" | head -1)
  for flag in 'security_and_analysis[secret_scanning][status]=enabled' 'security_and_analysis[secret_scanning_push_protection][status]=enabled'; do
    [[ "$secret " == *" -f $flag "* ]]
  done
  # SECURITY.md's advisory link needs private vulnerability reporting on.
  grep -qxF -- 'api -X PUT repos/{owner}/{repo}/private-vulnerability-reporting' "$FAKE_LOG"
  # CodeQL default setup scans every PR and push on public repos.
  grep -qxF -- 'api -X PATCH repos/{owner}/{repo}/code-scanning/default-setup -f state=configured' "$FAKE_LOG"
  # Dependabot alerts let Renovate open security PRs.
  grep -qxF -- 'api -X PUT repos/{owner}/{repo}/vulnerability-alerts' "$FAKE_LOG"
  for f in main-checks tags; do
    cmp "$fake/posted.$f.json" ".github/rulesets/$f.json"
  done
  for f in main main-checks tags; do
    cmp "$fake/put.$f.json" ".github/rulesets/$f.json"
  done
  # The required checks are the always-on jobs, by the names the workflows give them.
  for check in 'git hooks' 'pull request title' 'dependency review' 'DCO sign-off'; do
    jq -e --arg c "$check" '.rules[] | select(.type == "required_status_checks")
      | .parameters.required_status_checks | any(.context == $c)' .github/rulesets/main-checks.json >/dev/null
    grep -rqxF "    name: $check" .github/workflows
  done
  # Public: one approval from someone who did not push last, so Scorecard's branch
  # protection can reach 8. An admin may merge without one, but not without the checks,
  # which sit in a ruleset of their own so a bypass of the review leaves them on.
  jq -e '(.rules[] | select(.type == "pull_request").parameters
      | .required_approving_review_count == 1 and .dismiss_stale_reviews_on_push and .require_last_push_approval)
    and ([.rules[].type] | index("required_status_checks") == null)
    and .bypass_actors == [{actor_id: 5, actor_type: "RepositoryRole", bypass_mode: "pull_request"}]' \
    .github/rulesets/main.json >/dev/null
  jq -e '[.rules[].type] == ["required_status_checks"]
    and .bypass_actors == [{actor_id: 5, actor_type: "RepositoryRole", bypass_mode: "pull_request"}]' \
    .github/rulesets/main-checks.json >/dev/null
  # A path filter would leave a required check unreported on some PRs, which blocks them.
  (lacks -q '^ *paths' .github/workflows/checks.yml .github/workflows/pr-title.yml .github/workflows/dco.yml)
  jq -e '.target == "tag" and .conditions.ref_name.include == ["refs/tags/v*"]' .github/rulesets/tags.json >/dev/null
  # A refused CodeQL setup warns with GitHub's reason, and the rest still runs.
  : >"$FAKE_LOG"
  FAKE_CODEQL=403 just repo-settings >/dev/null 2>"$fake/err"
  grep -q 'Warning: CodeQL default setup could not be turned on.*Code Security must be enabled' "$fake/err"
  grep -qxF -- 'api -X PUT repos/{owner}/{repo}/vulnerability-alerts' "$FAKE_LOG"
  # So does a refused secret scanning setup.
  : >"$FAKE_LOG"
  FAKE_SECRET=422 just repo-settings >/dev/null 2>"$fake/err"
  grep -q 'Warning: secret scanning could not be turned on.*not available' "$fake/err"
  grep -qxF -- 'api -X PUT repos/{owner}/{repo}/vulnerability-alerts' "$FAKE_LOG"
)
(cd b && ! grep -q 'DCO sign-off' .github/rulesets/main.json)
# Silver: the DCO check needs commits made in GitHub's web UI to carry a sign-off.
: >"$fake/log"
(
  cd h
  # shellcheck disable=SC2031 # the PATH set for this one command, as above
  FAKE_LOG="$fake/log" FAKE_DIR="$fake" PATH="$fake:$PATH" just repo-settings >/dev/null
  patch=$(grep -- '^api -X PATCH repos/{owner}/{repo} ' "$fake/log" | head -1)
  [[ "$patch " == *" -F web_commit_signoff_required=true "* ]]
)
# Release environments and publishing links: c has PyPI, npm and GHCR.
(
  cd c
  # shellcheck disable=SC2030,SC2031 # the about test and the copier-update run below set their own PATH
  export FAKE_LOG="$fake/log-c" FAKE_DIR="$fake" PATH="$fake:$PATH"
  just repo-settings >"$fake/out-c"
  just repo-settings >/dev/null
  for env in pypi npm ghcr; do
    grep -q "api -X PUT repos/{owner}/{repo}/environments/$env " "$fake/log-c"
    grep -q "api -X POST repos/{owner}/{repo}/environments/$env/deployment-branch-policies -f name=v\* -f type=tag" "$fake/log-c"
  done
  grep -q "api -X POST repos/{owner}/{repo}/environments/ghcr/deployment-branch-policies -f name=main -f type=branch" "$fake/log-c"
  test "$(grep -c 'deployment-branch-policies -f name=v\*' "$fake/log-c")" = 3
  test "$(grep -c 'deployment-branch-policies -f name=main' "$fake/log-c")" = 1
  # Only a web app has the preview environment.
  (lacks -q 'environments/preview' "$fake/log-c")
  (lacks -q 'environments/production' "$fake/log-c")
  grep -q 'https://pypi.org/manage/account/publishing/?provider=github&project_name=mono-me&owner=simonvanlierde&repository=project-templates&workflow_filename=python-release.yml&environment=pypi' "$fake/out-c"
  grep -q 'https://zenodo.org/account/settings/github/' "$fake/out-c"
  # A released project deletes the checklist, and the hint goes with it.
  grep -q 'First-release checklist' "$fake/out-c"
  mv .github/first-release.md "$fake/first-release.md"
  just repo-settings >"$fake/out-c"
  mv "$fake/first-release.md" .github/first-release.md
  (lacks -q 'First-release checklist' "$fake/out-c")
)
# The web app (d) gets the preview environment, with no reviewer or branch limit.
(
  cd d
  # shellcheck disable=SC2030,SC2031 # as above
  export FAKE_LOG="$fake/log-d" FAKE_DIR="$fake" PATH="$fake:$PATH"
  just repo-settings >"$fake/out-d"
  just repo-settings >/dev/null
  grep -qxF -- 'api -X PUT repos/{owner}/{repo}/environments/preview' "$FAKE_LOG"
  (lacks -q 'environments/preview/' "$FAKE_LOG")
  grep -q "Configured environment 'preview'" "$fake/out-d"
  # production: no reviewer, and only main may deploy to it, posted once over two runs.
  grep -qxF -- 'api -X PUT repos/{owner}/{repo}/environments/production -F deployment_branch_policy[protected_branches]=false -F deployment_branch_policy[custom_branch_policies]=true' "$FAKE_LOG"
  test "$(grep -cxF -- 'api -X POST repos/{owner}/{repo}/environments/production/deployment-branch-policies -f name=main -f type=branch' "$FAKE_LOG")" = 1
  (lacks -q 'environments/production.*reviewers' "$FAKE_LOG")
  grep -q "Configured environment 'production'" "$fake/out-d"
)
# The site (x) gets the preview environment and Pages from Actions: created on the first
# run, switched over on the second, when GitHub answers 409.
(
  cd x
  # shellcheck disable=SC2030,SC2031 # as above
  export FAKE_LOG="$fake/log-x" FAKE_DIR="$fake/x" PATH="$fake:$PATH"
  mkdir -p "$FAKE_DIR"
  cp "$fake/rulesets.json" "$FAKE_DIR/"
  just repo-settings >"$fake/out-x"
  just repo-settings >/dev/null
  grep -qxF -- 'api -X PUT repos/{owner}/{repo}/environments/preview' "$FAKE_LOG"
  test "$(grep -cxF -- 'api -X POST repos/{owner}/{repo}/pages -f build_type=workflow' "$FAKE_LOG")" = 2
  test "$(grep -cxF -- 'api -X PUT repos/{owner}/{repo}/pages -f build_type=workflow' "$FAKE_LOG")" = 1
  (lacks -q 'environments/production' "$FAKE_LOG")
  grep -q 'GitHub Pages deploys from Actions' "$fake/out-x"
  # A repo that cannot have Pages (403, 422) gets a warning, and the rest still runs.
  FAKE_PAGES=403 just repo-settings >/dev/null 2>"$fake/err-x"
  grep -q 'GitHub Pages is not available for this repo' "$fake/err-x"
  FAKE_PAGES=422 just repo-settings >/dev/null 2>&1
  (! FAKE_PAGES=500 just repo-settings >/dev/null 2>&1)
)
(lacks -qF 'repos/{owner}/{repo}/pages' "$fake/log-c")
# A site on a Worker (cfp) gets the production environment instead of Pages.
(
  cd cfp
  # shellcheck disable=SC2030,SC2031 # as above
  export FAKE_LOG="$fake/log-cfp" FAKE_DIR="$fake/cfp" PATH="$fake:$PATH"
  mkdir -p "$FAKE_DIR"
  cp "$fake/rulesets.json" "$FAKE_DIR/"
  just repo-settings >"$fake/out-cfp"
  grep -qxF -- 'api -X PUT repos/{owner}/{repo}/environments/preview' "$FAKE_LOG"
  grep -q 'environments/production' "$FAKE_LOG"
  (lacks -qF 'repos/{owner}/{repo}/pages' "$FAKE_LOG")
  grep -q 'see the Site section of the README' "$fake/out-cfp"
)
# Renovate's app skips the review, so its PRs merge themselves, but never the checks.
jq -e '.bypass_actors[1] == {actor_id: 2740, actor_type: "Integration", bypass_mode: "pull_request"}' d/.github/rulesets/main.json >/dev/null
jq -e '.bypass_actors | length == 1' d/.github/rulesets/main-checks.json >/dev/null
# Before the Renovate app is on the repo, GitHub refuses it as a bypass actor. gh prints
# the reason on stdout, as this fake does, and the recipe says to install the app.
nobot=$out/nobot-gh
mkdir -p "$nobot"
cat >"$nobot/gh" <<'FAKE'
#!/usr/bin/env bash
case $* in
  *"-X POST"*"rulesets"*)
    echo '{"message":"Validation Failed","errors":["Actor Renovate integration must be part of the ruleset source or owner organization"],"status":"422"}'
    echo 'gh: Validation Failed (HTTP 422)' >&2
    exit 1 ;;
esac
FAKE
chmod +x "$nobot/gh"
# shellcheck disable=SC2031 # the PATH set for this one command, as above
(cd d && ! PATH="$nobot:$PATH" just repo-settings 2>"$nobot/err" >/dev/null)
grep -q 'https://github.com/apps/renovate, then rerun' "$nobot/err"
# Private: no approval, no bypass and the checks in main itself, as before.
test ! -e b/.github/rulesets/main-checks.json
grep -qx '    for name in main tags; do' b/justfile
jq -e '(.rules[] | select(.type == "pull_request").parameters
    | .required_approving_review_count == 0 and (.dismiss_stale_reviews_on_push | not) and (.require_last_push_approval | not))
  and (.rules | any(.type == "required_status_checks")) and (has("bypass_actors") | not)' b/.github/rulesets/main.json >/dev/null
(lacks -q private-vulnerability-reporting b/justfile)
(lacks -q code-scanning b/justfile)
# repo-about: the About box comes from the answers. No description answer leaves the description alone;
# a quote in it survives the shell and braces survive just; topics only get added.
for r in a b d cfp x; do
  # shellcheck disable=SC2031 # $fake/gh from the repo-settings test, logging every call
  (cd "$r" && FAKE_LOG="$fake/about-$r" PATH="$fake:$PATH" just repo-about >/dev/null)
done
grep -qxF -- 'repo edit --add-topic python --add-topic typescript --add-topic rust --add-topic go --add-topic docker' "$fake/about-a"
grep -qxF -- "repo edit --description A \"quoted\" {{ one }}, naïve \$USD --add-topic python --add-topic typescript --add-topic docker" "$fake/about-b"
grep -qxF -- 'repo edit --homepage https://pipe-me.example-org.workers.dev --add-topic python --add-topic typescript --add-topic docker' "$fake/about-d"
grep -qxF -- 'repo edit --homepage https://demo.example.org --add-topic python' "$fake/about-cfp"
grep -qxF -- 'repo edit --add-topic python' "$fake/about-x"
# The community files and the DCO check come with public and go with it, in every render.
for answers in */.copier-answers.yml; do
  r=${answers%%/*}
  # e renders a tag on HEAD, so it lacks uncommitted edits.
  [ "$r" = e ] && continue
  for f in SECURITY.md CONTRIBUTING.md CODE_OF_CONDUCT.md pull_request_template.md workflows/dco.yml \
    ISSUE_TEMPLATE/bug.yml ISSUE_TEMPLATE/feature.yml ISSUE_TEMPLATE/config.yml; do
    if grep -qx 'public: false' "$answers"; then
      test ! -e "$r/.github/$f"
    else
      test -f "$r/.github/$f"
    fi
  done
done
# The community files' links point at this repo.
grep -qF 'https://github.com/example-org/render-me/issues)' a/.github/CONTRIBUTING.md
grep -qF '(../committed.toml)' a/.github/CONTRIBUTING.md
grep -qx '## Scope and response' a/.github/CONTRIBUTING.md
grep -q 'within about two weeks' a/.github/CONTRIBUTING.md
# A command-line program (c's Rust and Go binaries, d's pipeline) gets the CLI statement
# at the root; a's libraries and research package don't. d's nested web app keeps its own.
for r in c d; do
  grep -qx '# Accessibility' "$r/docs/accessibility.md"
  grep -qF 'NO_COLOR' "$r/docs/accessibility.md"
  grep -qF '<ada@example.com>' "$r/docs/accessibility.md"
done
test ! -e a/docs/accessibility.md
grep -qx '# Accessibility statement' d/web/docs/accessibility.md
# The README says experimental; only a public repo points to CONTRIBUTING.md.
grep -qx 'Status: experimental. It may change in ways that break your code, without notice.' a/README.md
grep -qxF 'Questions and bugs: see [CONTRIBUTING.md](.github/CONTRIBUTING.md).' a/README.md
(lacks -q 'Questions and bugs' b/README.md)
grep -qx 'blank_issues_enabled: false' a/.github/ISSUE_TEMPLATE/config.yml
grep -qx '    url: https://github.com/example-org/render-me/blob/main/.github/CONTRIBUTING.md' \
  a/.github/ISSUE_TEMPLATE/config.yml
(lacks -q '\[NOTE:' a/.github/CODE_OF_CONDUCT.md)
# The bug form: a render with a web app (d) asks for a page URL and a browser and does not
# force shell formatting; the others keep the command-line form. Both pass GitHub's schema.
grep -qx '    id: url' d/.github/ISSUE_TEMPLATE/bug.yml
grep -qx '    id: browser' d/.github/ISSUE_TEMPLATE/bug.yml
(lacks -q 'render: shell' d/.github/ISSUE_TEMPLATE/bug.yml)
grep -qx '      render: shell' a/.github/ISSUE_TEMPLATE/bug.yml
(lacks -qE 'id: (url|browser)$' a/.github/ISSUE_TEMPLATE/bug.yml)
# The browser field covers the environment question on the web form.
(lacks -q 'id: environment' d/.github/ISSUE_TEMPLATE/bug.yml)
grep -qx '    id: environment' a/.github/ISSUE_TEMPLATE/bug.yml
uvx check-jsonschema --builtin-schema vendor.github-issue-forms \
  a/.github/ISSUE_TEMPLATE/bug.yml d/.github/ISSUE_TEMPLATE/bug.yml
# OpenSSF badge: passing (m) adds the test policy and a coding-standards line per stack;
# silver (h) also adds the governance, roadmap and assurance-case skeletons. a is public
# with the default none, so it gets neither.
badge_docs=(GOVERNANCE.md docs/roadmap.md docs/assurance-case.md)
for r in a m; do
  for f in "${badge_docs[@]}"; do test ! -e "$r/$f"; done
done
(lacks -q '## Tests and code style' a/.github/CONTRIBUTING.md)
grep -q '## Tests and code style' m/.github/CONTRIBUTING.md
test "$(grep -c '^- \(Python\|TypeScript\|Rust\|Go\): ' m/.github/CONTRIBUTING.md)" = 4
grep -qx -- '- Go: gofmt and \[golangci-lint\](https://golangci-lint.run).' h/.github/CONTRIBUTING.md
for f in "${badge_docs[@]}"; do test -f "h/$f"; done
# The four parts the silver assurance_case criterion names, in a short skeleton.
for heading in 'Threat model' 'Trust boundaries' 'Secure design principles' 'Weaknesses countered'; do
  grep -qx "## $heading" h/docs/assurance-case.md
done
test "$(wc -l <h/docs/assurance-case.md)" -le 60
grep -qF '| Maintainer |' h/GOVERNANCE.md
grep -qx 'Bus factor: TODO (the fewest people whose departure would leave the project unable to continue).' h/GOVERNANCE.md
# This repo runs the silver render's DCO check, hook and commit rules: it checks its own
# branches too. Below silver a render checks only pull requests from forks.
diff "$repo/.github/workflows/dco.yml" h/.github/workflows/dco.yml
grep -qx '    if: github.event.pull_request.head.repo.full_name != github.repository' \
  a/.github/workflows/dco.yml
(lacks -q '^    if: ' h/.github/workflows/dco.yml)
grep -q 'id: dco-signoff' h/.pre-commit-config.yaml
# The hook and sign-off setting follow dco.yml, which every public render has, with or
# without a license; b is private and has none of the three.
for r in a h i; do
  grep -q 'id: dco-signoff' "$r/.pre-commit-config.yaml"
  grep -q 'web_commit_signoff_required=true' "$r/justfile"
done
test ! -e b/.github/workflows/dco.yml
(lacks -q 'id: dco-signoff' b/.pre-commit-config.yaml)
(lacks -q 'web_commit_signoff_required' b/justfile)
(lacks -q 'security_and_analysis' b/justfile)
# A fresh clone has only origin, and a pushed branch needs a lease, not a bare force-push.
for f in "$repo/CONTRIBUTING.md" a/.github/CONTRIBUTING.md h/.github/CONTRIBUTING.md \
  a/.github/workflows/dco.yml; do
  grep -qF 'git rebase --signoff origin/main' "$f"
  grep -qF -- '--force-with-lease' "$f"
  (lacks -q 'upstream/main\|force-push' "$f")
done
grep -qx '    if: github.event.pull_request.head.repo.full_name != github.repository' \
  i/.github/workflows/dco.yml
(lacks -q 'the maintainers. included' i/.github/CONTRIBUTING.md)
grep -q 'the maintainers. included' h/.github/CONTRIBUTING.md
cmp "$repo/committed.toml" "$repo/template/committed.toml"
# Every question someone can be asked is named in the usage docs.
# shellcheck disable=SC2016 # Python source: the backticks are Markdown, not a shell command
uv run --no-project --with pyyaml python -c '
import sys, yaml
questions = yaml.safe_load(open(sys.argv[1]))
doc = open(sys.argv[2]).read()
missing = [k for k, v in questions.items() if not k.startswith("_") and isinstance(v, dict)
           and v.get("when") is not False and f"`{k}`" not in doc]
sys.exit(f"questions missing from docs/usage.md: {missing}" if missing else 0)' \
  "$repo/copier.yml" "$repo/docs/usage.md"
# Its jq filter, run on a commits API fixture, lists the unsigned commit and the sign-off
# without an email, and skips the merge. Trailing whitespace and CRLF still count as signed.
dco_filter=$(uv run --no-project --with pyyaml python -c '
import re, sys, yaml
run = yaml.safe_load(open(sys.argv[1]))["jobs"]["sign-off"]["steps"][0]["run"]
print(re.search(r"--jq \x27(.*?)\x27\)", run, re.S).group(1))' "$repo/.github/workflows/dco.yml")
commits=$out/dco-commits.json
cat >"$commits" <<'JSON'
[
  {"sha": "aaaaaaa1", "parents": [{}], "commit": {"message": "feat: signed\n\nSigned-off-by: Ada Lovelace <ada@example.com>"}},
  {"sha": "bbbbbbb2", "parents": [{}], "commit": {"message": "fix: unsigned"}},
  {"sha": "ccccccc3", "parents": [{}, {}], "commit": {"message": "Merge branch 'main'"}},
  {"sha": "ddddddd4", "parents": [{}], "commit": {"message": "fix: malformed\n\nSigned-off-by: Ada Lovelace"}},
  {"sha": "eeeeeee5", "parents": [{}], "commit": {"message": "fix: trailing space\n\nSigned-off-by: Ada Lovelace <ada@example.com>  "}},
  {"sha": "fffffff6", "parents": [{}], "commit": {"message": "fix: crlf\r\n\r\nSigned-off-by: Ada Lovelace <ada@example.com>\r\n"}},
  {"sha": "1111111a", "parents": [{}], "author": {"type": "Bot"}, "commit": {"message": "chore(deps): bump"}},
  {"sha": "2222222b", "parents": [{}], "author": {"type": "User"}, "commit": {"message": "fix: human on a bot branch"}}
]
JSON
# A bot's commit counts only in a pull request a person opened. A person's commit counts
# in a bot's pull request too.
test "$(PR_BY_BOT=false jq -r "$dco_filter" "$commits")" = "$(printf 'bbbbbbb fix: unsigned\nddddddd fix: malformed\n1111111 chore(deps): bump\n2222222 fix: human on a bot branch')"
test "$(PR_BY_BOT=true jq -r "$dco_filter" "$commits")" = "$(printf 'bbbbbbb fix: unsigned\nddddddd fix: malformed\n2222222 fix: human on a bot branch')"
