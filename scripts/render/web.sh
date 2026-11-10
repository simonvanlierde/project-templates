# shellcheck shell=bash
# shellcheck disable=SC2154,SC2164 # check-render.sh sets out, repo, copier and set -e
# The web app (d): starter files, PRODUCT.md and DESIGN.md, deploys and previews.
# Renders d again over $repo, so the checks after it see that render.

# web-app (d, Preact, nested): the Vite app and its e2e specs replace the Node
# package, the e2e job reads its container tag from the check job, and the
# unit tests run before a push.
test -f d/web/index.html
test -f d/web/src/main.tsx
test -f d/web/public/_headers
test -f d/web/wrangler.jsonc
test -f d/web/tests/e2e/a11y.spec.ts
test -f d/web/tests/e2e/csp.spec.ts
# `just ts-shots` screenshots the same routes; shots/ stays out of git.
test -f d/web/tests/shots/shots.spec.ts
grep -q '^ts-shots:' d/just/ts.just
grep -qF 'rm -rf web/shots' d/just/ts.just
grep -qF 'SHOTS=1 pnpm -C web exec playwright test --project shots' d/just/ts.just
grep -qF 'web/shots/' d/README.md
grep -qF 'ts-(e2e|shots)' d/.github/workflows/cold-install.yml
grep -qx '/web/shots/' d/.gitignore
(lacks -q '^ts-shots:' a/just/ts.just)
# The legal pages: statement and privacy always, terms for accounts or uploads,
# each a route the axe, CSP, privacy and legal-page specs visit.
for page in accessibility privacy terms; do
  test -f "d/web/docs/$page.md"
  grep -q "\"/$page\"" d/web/tests/e2e/routes.ts
done
test -f d/web/tests/e2e/privacy.spec.ts
test -f d/web/tests/e2e/accessibility-statement.spec.ts
test -f d/web/tests/e2e/legal-pages.spec.ts
grep -q 'Its conformance is \*\*not assessed\*\*' d/web/docs/accessibility.md
grep -qx '    "marked": "[0-9.]*",' d/web/package.json
# A private repo's GitHub links would 404 for visitors, so its legal pages have none.
test -f j/docs/accessibility.md
(lacks -rq 'github.com/example-org/private-web' j/docs)
grep -qF '[tests/e2e](https://github.com/example-org/pipe-me/tree/main/web/tests/e2e)' d/web/docs/accessibility.md
grep -qF "are in \`tests/e2e\`." j/docs/accessibility.md
# The WCAG 2.2 self-assessment sits beside the statement, which links it only once every row
# has a result: one row per level A and AA criterion, 55 in all, none of them assessed yet.
# Other kinds have none.
test "$(grep -cE '^\| [1-4]\.[0-9]+\.[0-9]+ .* \| AA? \| Not assessed \| \|$' d/web/docs/accessibility-assessment.md)" = 55
(lacks -q 'accessibility-assessment.md)' d/web/docs/accessibility.md)
test ! -e m/web/docs/accessibility-assessment.md
# The answers reach the terms: the site, who runs it and the contact, and the privacy
# statement links them.
grep -qxF 'These terms cover pipe-me at [pipe-me.example-org.workers.dev](https://pipe-me.example-org.workers.dev).' d/web/docs/terms.md
grep -qxF 'Ada Lovelace, who runs pipe-me.' d/web/docs/terms.md
grep -qF '[ada@example.com](mailto:ada@example.com)' d/web/docs/terms.md
grep -qxF 'Using pipe-me also means accepting its [terms of use](https://pipe-me.example-org.workers.dev/terms).' d/web/docs/privacy.md
# j keeps work in the browser, with no accounts: its privacy statement says so, and it has
# no terms page, route or footer link.
grep -qxF 'private-web keeps your work on your device. It isn'"'"'t sent to us or to anyone else.' j/docs/privacy.md
grep -qF "private-web saves your work in your browser's local storage" j/docs/privacy.md
grep -qx "private-web sets no cookies, so there's no cookie banner. Local storage holds only what you" j/docs/privacy.md
grep -qx 'private-web comes with no warranty.' j/docs/privacy.md
test ! -e j/docs/terms.md
(lacks -q '/terms' j/src/App.tsx j/tests/e2e/routes.ts j/tests/e2e/legal-pages.spec.ts j/docs/privacy.md)
# GitHub shows the pages and the design stubs as they are, so they pass the project's own
# Markdown lint. d has no description, which PRODUCT.md leaves out.
rumdl_version=$(sed -n '/rumdl-pre-commit/{n;s/.*frozen: v//p;}' "$repo/.pre-commit-config.yaml")
uvx "rumdl@$rumdl_version" check --config d/.rumdl.toml d/web/docs d/web/PRODUCT.md d/web/DESIGN.md d/AGENTS.md
test ! -e a/docs/privacy.md
# PRODUCT.md and DESIGN.md stubs: a web app gets both, beside its package.json,
# and they speak of the project's own users. Other kinds have neither.
for f in PRODUCT DESIGN; do
  test -f "d/web/$f.md"
  grep -qF 'pipe-me' "d/web/$f.md"
  (lacks -iE 'recruit|portfolio|hiring|showcase' "d/web/$f.md")
  test ! -e "t/$f.md"
  test ! -e "w/$f.md"
  test ! -e "a/$f.md"
done
grep -qx '## Users' d/web/PRODUCT.md
grep -qx '## Overview' d/web/DESIGN.md
# Like the other starter files, they are the project's once rendered.
echo '<!-- project edit -->' >>"$out/d/web/PRODUCT.md"
"${copier[@]}" --vcs-ref=HEAD "${d_args[@]}" "$repo" "$out/d" >/dev/null 2>&1
grep -q 'project edit' "$out/d/web/PRODUCT.md"
test ! -e d/web/src/index.ts
test ! -e d/web/tsconfig.build.json
test ! -e d/web/Dockerfile
grep -q 'stub for a data pipeline' d/pipe/Dockerfile
test ! -e a/index.html
grep -q '"react": \["./node_modules/preact/compat/"\]' d/web/tsconfig.json
grep -q 'react: "preact/compat"' d/web/vite.config.ts
# Biome's React rules run only with react in package.json: Preact turns on the one App.tsx suppresses.
grep -qF '"noDangerouslySetInnerHtml": "error"' d/web/biome.json
(lacks -q 'noDangerouslySetInnerHtml' j/biome.json)
(lacks -q '"react":' d/web/package.json)
grep -q 'script-src .self.;' d/web/public/_headers
(lacks -q "'unsafe-inline'" d/web/public/_headers)
grep -q '"budget": "node scripts/checkBundleBudget.mjs"' d/web/package.json
grep -q 'pnpm -C web run budget' d/just/ts.just
grep -qF 'image: mcr.microsoft.com/playwright:v' d/.github/workflows/ts.yml
grep -qF 'needs.playwright.outputs.version }}-noble' d/.github/workflows/ts.yml
# e2e waits for the version job only, which reads the nested lockfile.
grep -qx '    needs: playwright' d/.github/workflows/ts.yml
grep -qx '          sparse-checkout: web/pnpm-lock.yaml' d/.github/workflows/ts.yml
grep -q 'fonts-dejavu-core' d/.github/workflows/ts.yml
grep -qx '          path: web/playwright-report/' d/.github/workflows/ts.yml
# Deploys: web-app renders get one Worker config for production and previews, the
# production and preview jobs and preview-retire.yml, with wrangler at the pinned version
# and nested paths for d. Production headers never carry noindex.
wrangler_pin=$(sed -n '/^wrangler_version:/,/^$/s/^  default: //p' "$repo/copier.yml")
test -n "$wrangler_pin"
grep -qF '"name": "pipe-me",' d/web/wrangler.jsonc
grep -qF '"directory": "./dist",' d/web/wrangler.jsonc
grep -qF '"not_found_handling": "single-page-application"' d/web/wrangler.jsonc
grep -qF '"preview_urls": false,' d/web/wrangler.jsonc
grep -qF '"workers_dev": true' d/web/wrangler.jsonc
(lacks -q 'pages_build_output_dir' d/web/wrangler.jsonc s/wrangler.jsonc)
test ! -e d/web/wrangler.preview.jsonc
# No web app names Pages' address anywhere.
(lacks -rq --exclude-dir=.git 'pages\.dev' d j s)
grep -q '^  preview:' d/.github/workflows/ts.yml
grep -q 'name: dist$' d/.github/workflows/ts.yml
(lacks -q 'preview-dist' d/.github/workflows/ts.yml)
test "$(grep -c 'path: web/dist$' d/.github/workflows/ts.yml)" = 3
# Production: push to main only, after the checks, in the production environment, one
# deploy at a time, under the config's own name.
prod=$(sed -n '/^  production:$/,/^  [a-z]/p' d/.github/workflows/ts.yml)
grep -qxF "    if: github.event_name == 'push' && github.ref == 'refs/heads/main'" <<<"$prod"
grep -qxF '    needs: [check, e2e]' <<<"$prod"
grep -qxF '      name: production' <<<"$prod"
grep -qxF '      group: production' <<<"$prod"
grep -qxF '      cancel-in-progress: false' <<<"$prod"
grep -qxF "        run: '\"\$GITHUB_WORKSPACE/.github/scripts/deploy-worker.sh\" Production'" <<<"$prod"
(! grep -q -- '--name\|X-Robots-Tag' <<<"$prod")
# A newer push to main must not cancel the run whose deploy is in flight.
grep -qF "cancel-in-progress: \${{ github.event_name == 'pull_request' }}" d/.github/workflows/ts.yml
grep -q '^ *name: preview$' d/.github/workflows/ts.yml
grep -qF "deploy-worker.sh\" Preview \"pipe-me-pr-\$PR\"" d/.github/workflows/ts.yml
# Both jobs deploy through the one script, which only a web app gets and which runs wrangler.
test "$(grep -cE 'deploy-worker\.sh" (Preview|Production)' d/.github/workflows/ts.yml)" = 2
# A nested app's ts.yml also runs when only the script changes, on push and on PRs.
test "$(grep -cF 'paths: ["web/**", ".github/workflows/ts.yml", ".github/scripts/cloudflare-gate.sh", ".github/scripts/deploy-worker.sh"]' d/.github/workflows/ts.yml)" = 2
(lacks -q 'wrangler deploy' d/.github/workflows/ts.yml)
# Every Cloudflare secrets gate checks both secrets: a missing account id fails each run.
# Each deploy job runs the gate script right after its checkout, which brings the script.
n=0
for wf in */.github/workflows/{ts,site}.yml; do
  [ -e "$wf" ] || continue
  deploys=$(grep -cE 'deploy-worker\.sh" (Preview|Production)' "$wf" || true)
  test "$(grep -c '/\.github/scripts/cloudflare-gate\.sh" ' "$wf" || true)" = "$deploys"
  # The gate script comes from the checkout, so that step runs first and unconditionally.
  uv run --no-project --with pyyaml python - "$wf" <<'PY'
import sys, yaml
for name, job in yaml.safe_load(open(sys.argv[1]))["jobs"].items():
    steps = job.get("steps", [])
    for i, step in enumerate(steps):
        if step.get("id") == "gate":
            before = steps[i - 1]
            assert i > 0 and before.get("uses", "").startswith("actions/checkout@"), name
            assert "if" not in before and before["with"]["persist-credentials"] is False, name
PY
  n=$((n + deploys))
done
test "$n" -ge 4
for f in */.github/scripts/cloudflare-gate.sh */.github/workflows/preview-retire.yml; do
  # shellcheck disable=SC2016 # the literal script text
  grep -qF '[ -n "$ACCOUNT" ] || missing="${missing:+$missing and }CLOUDFLARE_ACCOUNT_ID"' "$f"
done
# The gate skips, never fails: no secrets or a fork PR give run=false and a notice.
gate_cf=$out/d/.github/scripts/cloudflare-gate.sh
test -x "$gate_cf"
cf_gate() { env GITHUB_OUTPUT="$out/cf-gate.out" "$@" "$gate_cf" "Production deploy" 2>&1; }
: >"$out/cf-gate.out"
test "$(cf_gate TOKEN=t ACCOUNT=)" = '::notice::Production deploy skipped: CLOUDFLARE_ACCOUNT_ID not set.'
test "$(cf_gate TOKEN= ACCOUNT=)" = '::notice::Production deploy skipped: CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID not set.'
test "$(cf_gate TOKEN=t ACCOUNT=a FORK=true)" = '::notice::Production deploy skipped: fork PR.'
test -z "$(cf_gate TOKEN=t ACCOUNT=a FORK=false)"
test "$(tr '\n' ' ' <"$out/cf-gate.out")" = 'run=false run=false run=false run=true '
test -x d/.github/scripts/deploy-worker.sh
test ! -e m/.github/scripts/deploy-worker.sh
test -x s/.github/scripts/deploy-worker.sh
test ! -e a/.github/scripts/deploy-worker.sh
# deploy-worker.sh against a stub pnpm: the name goes to wrangler only when given, the
# address lands in the output and summary, and a deploy that prints none fails.
deploy_sh=$out/d/.github/scripts/deploy-worker.sh
dstub=$out/fake-deploy
mkdir -p "$dstub/work"
# wrangler 4's deploy output; with workers_dev off it prints no address lines.
cat >"$dstub/pnpm" <<'STUB'
#!/usr/bin/env bash
echo "pnpm $*" >>"$STUB/calls"
cat <<'OUT'

 ⛅️ wrangler 4.154.0
───────────────────
🌀 Building list of assets...
✨ Read 6 files from the assets directory /home/runner/work/pipe-me/pipe-me/web/dist
🌀 Starting asset upload...
✨ Success! Uploaded 2 files (4 already uploaded) (1.12 sec)

Total Upload: 0.34 KiB / gzip: 0.24 KiB
Uploaded pipe-me (3.41 sec)
OUT
[ -n "${NO_URL:-}" ] || printf '%s\n' 'Deployed pipe-me triggers (0.87 sec)' '  https://pipe-me.acct.workers.dev'
echo 'Current Version ID: 6f9a3c2e-1b4d-4e8f-9a7c-2d5e8b1f0c3a'
STUB
chmod +x "$dstub/pnpm"
deploy() {
  : >"$dstub/calls" && : >"$dstub/gho" && : >"$dstub/sum"
  (cd "$dstub/work" && env STUB="$dstub" PATH="$dstub:$PATH" GITHUB_OUTPUT="$dstub/gho" \
    GITHUB_STEP_SUMMARY="$dstub/sum" "$@" "$deploy_sh" Label ${DEPLOY_NAME+"$DEPLOY_NAME"} \
    ${DEPLOY_DOMAIN:+--domain "$DEPLOY_DOMAIN"} >"$dstub/out" 2>&1)
}
deploy
grep -qx 'pnpm exec wrangler deploy' "$dstub/calls"
grep -qx 'url=https://pipe-me.acct.workers.dev' "$dstub/gho"
grep -qx '### Label: https://pipe-me.acct.workers.dev' "$dstub/sum"
DEPLOY_NAME=pipe-me-pr-4 deploy
grep -qx 'pnpm exec wrangler deploy --name pipe-me-pr-4' "$dstub/calls"
# An empty name keeps the config's, so the production deploy passes only its domain.
DEPLOY_NAME='' DEPLOY_DOMAIN=app.example.org deploy
grep -qx 'pnpm exec wrangler deploy --domain app.example.org' "$dstub/calls"
(! deploy NO_URL=1)
grep -qF 'wrangler printed no workers.dev address' "$dstub/out"
# wrangler is an exact devDependency of a web app only, which both deploy jobs install.
grep -qxF "    \"wrangler\": \"$wrangler_pin\"" d/web/package.json
(lacks -q 'pnpm dlx' d/.github/workflows/ts.yml)
test "$(grep -c 'run: pnpm install --frozen-lockfile' d/.github/workflows/ts.yml)" -ge 4
(lacks -q '"wrangler"' m/web/package.json)
# pnpm refuses the install unless wrangler's esbuild and workerd builds are allowed.
grep -A2 -x 'allowBuilds:' d/web/pnpm-workspace.yaml | grep -qx '  workerd: true'
(lacks -q 'allowBuilds' m/web/pnpm-workspace.yaml)
# knip does not read deploy-worker.sh, the only caller of wrangler, so every web app ignores it.
jq -e '.knip.ignoreDependencies | index("wrangler")' d/web/package.json >/dev/null
jq -e '.knip.ignoreDependencies | index("wrangler")' s/package.json >/dev/null
(lacks -q 'versions upload' d/.github/workflows/ts.yml)
grep -qF 'X-Robots-Tag: noindex' d/.github/workflows/ts.yml
(lacks -q '^  X-Robots-Tag' d/web/public/_headers)
# A preview lives only while its pull request is open and ready: drafts get none, the deploy
# re-reads the state, the retire runs on close and on a draft switch, and both share one
# concurrency group so a retire waits for a deploy in flight.
grep -qF "if: github.event_name == 'pull_request' && !github.event.pull_request.draft && !endsWith(github.event.pull_request.user.login, '[bot]')" d/.github/workflows/ts.yml
# shellcheck disable=SC2016
grep -qF 'gh api "repos/$REPO/pulls/$PR" --jq '\''.state + " " + (.draft|tostring)'\''' d/.github/workflows/ts.yml
# shellcheck disable=SC2016
grep -qF '[ "$state" != "open false" ]' d/.github/workflows/ts.yml
grep -q 'pull-requests: read' d/.github/workflows/ts.yml
# shellcheck disable=SC2016
grep -qF 'group: preview-${{ github.event.pull_request.number }}' d/.github/workflows/ts.yml
# shellcheck disable=SC2016
grep -qF 'group: ${{ matrix.group }}-${{ github.event.pull_request.number || github.run_id }}' d/.github/workflows/preview-retire.yml
grep -qF 'types: [closed, converted_to_draft]' d/.github/workflows/preview-retire.yml
grep -qF 'cron: "17 4 * * *"' d/.github/workflows/preview-retire.yml
grep -q 'pull-requests: read' d/.github/workflows/preview-retire.yml
grep -q 'environment: preview$' d/.github/workflows/preview-retire.yml
grep -qxF '        run: .github/scripts/preview-retire.sh' d/.github/workflows/preview-retire.yml
(lacks -q 'pnpm\|working-directory' d/.github/workflows/preview-retire.yml)
test -x d/.github/scripts/preview-retire.sh
# preview-retire.sh against a stub curl and gh. The account holds pipe-me-pr-1 to -3,
# pipe-me-site-pr-1 and pipe-me-preview; each test sets the PR states, the DELETE answer and the address answer.
retire_sh=$out/d/.github/scripts/preview-retire.sh
stub=$out/fake-retire
mkdir -p "$stub"
cat >"$stub/curl" <<'STUB'
#!/usr/bin/env bash
method=GET out=/dev/null prev=''
echo "$*" >>"$STUB/argv"
for a; do
  if [ "$prev" = -H ] && [[ $a = @* ]]; then cat "${a#@}" >>"$STUB/headers"; fi
  case $prev in -X) method=$a ;; -o) out=$a ;; esac
  prev=$a
done
url=$a
case $method:$url in
  DELETE:*) echo "${url##*/}" >>"$STUB/deleted"; echo '{}' >"$out"; printf %s "${DELETE_CODE:-200}" ;;
  *workers/scripts) echo '{"result":[{"id":"pipe-me-pr-1"},{"id":"pipe-me-pr-2"},{"id":"pipe-me-pr-3"},{"id":"pipe-me-site-pr-1"},{"id":"pipe-me-preview"}]}' ;;
  *workers/subdomain) [ -z "${SUB_FAIL:-}" ] || exit 22; echo '{"result":{"subdomain":"acct"}}' ;;
  *.workers.dev) printf %s "${PROBE_CODE:-404}"; [ "${PROBE_CODE:-404}" != 000 ] || exit 28 ;;
esac
STUB
# gh answers from $STUB/pr-<n>, and fails when there is no such file.
cat >"$stub/gh" <<'STUB'
#!/usr/bin/env bash
f=$STUB/pr-${2##*/}
[ -f "$f" ] && jq -r "$4" "$f"
STUB
chmod +x "$stub/curl" "$stub/gh"
retire() {
  : >"$stub/deleted"
  env SLUG=pipe-me REPO=o/r CLOUDFLARE_API_TOKEN=cf-stub-token CLOUDFLARE_ACCOUNT_ID=a PROBE_WAITS='0 0' \
    STUB="$stub" PATH="$stub:$PATH" "$@" "$retire_sh" pipe-me-preview >"$stub/out" 2>&1
}
echo '{"state": "open", "draft": true}' >"$stub/pr-1"
echo '{"state": "open", "draft": false}' >"$stub/pr-2"
# The sweep deletes the draft's Worker and keeps the ready one's. It cannot read PR 3, so it
# keeps that Worker too and fails.
(! retire)
test "$(LC_ALL=C sort "$stub/deleted")" = "$(printf 'pipe-me-pr-1?force=true\npipe-me-preview?force=true')"
grep -q 'Could not read PR 3' "$stub/out"
# Every Cloudflare call sends the token from a header file, never on curl's command line.
grep -qx 'Authorization: Bearer cf-stub-token' "$stub/headers"
(lacks -q 'cf-stub-token' "$stub/argv")
# The site's prefix takes only its own Worker.
retire SLUG=pipe-me-site
grep -qx 'pipe-me-site-pr-1?force=true' "$stub/deleted"
(lacks -q '^pipe-me-pr-' "$stub/deleted")
# Once PR 3 reads as closed, the sweep deletes it and passes.
echo '{"state": "closed", "draft": false}' >"$stub/pr-3"
retire
test "$(grep -c 'pr-3' "$stub/deleted")" = 1
(lacks -q 'pr-2' "$stub/deleted")
# A Worker that does not exist answers 404, which is not an error.
retire PRS=7 DELETE_CODE=404
grep -qx 'pipe-me-pr-7?force=true' "$stub/deleted"
# Without the subdomain, every delete still runs, unverified, and the run fails.
(! retire PRS='1 2' SUB_FAIL=1)
test "$(wc -l <"$stub/deleted")" = 2
grep -q 'no takedown below is verified' "$stub/out"
# Only a 404 counts as gone: a timeout or a 502 on every try fails, naming the code.
(! retire PRS=1 PROBE_CODE=000)
grep -qF 'answers HTTP 000 after the delete' "$stub/out"
(! retire PRS=1 PROBE_CODE=502)
grep -qF 'answers HTTP 502 after the delete' "$stub/out"
