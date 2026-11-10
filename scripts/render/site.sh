# shellcheck shell=bash
# shellcheck disable=SC2154,SC2164 # check-render.sh sets out, repo, copier and set -e
# The static site, the docs site, GitHub Pages and the sites on a Worker.

# Static site: x (Python), r (Rust) and d (beside a web app) answer site=plain. One build,
# which only the deploy job may publish to Pages, and a preview Worker per open, ready PR,
# deployed from that build through the web app's own script.
pnpm_pin=$(sed -n '/^pnpm_version:/,/^$/s/^  default: //p' "$repo/copier.yml")
grep -qF "\"packageManager\": \"pnpm@$pnpm_pin\"" d/web/package.json
for r in x r d; do
  for f in site/index.html site/style.css site/main.mjs wrangler.site.jsonc .github/workflows/site.yml .github/workflows/preview-retire.yml; do
    test -f "$r/$f"
  done
  test -x "$r/.github/scripts/deploy-worker.sh"
  test -x "$r/.github/scripts/preview-retire.sh"
  grep -qF '<script type="module" src="main.mjs"></script>' "$r/site/index.html"
  grep -qx '/_site/' "$r/.gitignore"
  grep -qx 'site:' "$r/justfile"
  grep -qF '"directory": "./_site"' "$r/wrangler.site.jsonc"
  grep -qF '"preview_urls": false,' "$r/wrangler.site.jsonc"
  grep -qF '"workers_dev": true' "$r/wrangler.site.jsonc"
  wf=$r/.github/workflows/site.yml
  # Least privilege: contents: read for the workflow, Pages rights on the deploy job alone.
  sed -n '1,/^jobs:/p' "$wf" | grep -qx '  contents: read'
  test "$(grep -c 'pages: write' "$wf")" = 1
  test "$(grep -c 'id-token: write' "$wf")" = 1
  deploy_job=$(sed -n '/^  deploy:$/,/^  [a-z]/p' "$wf")
  grep -q '^      pages: write' <<<"$deploy_job"
  grep -q '^      id-token: write' <<<"$deploy_job"
  grep -qx '      name: github-pages' <<<"$deploy_job"
  grep -qxF "    if: github.event_name != 'pull_request' && github.ref == 'refs/heads/main'" <<<"$deploy_job"
  test "$(grep -c '^    timeout-minutes:' "$wf")" = 3
  test "$(grep -c 'uses: actions/checkout@' "$wf")" = "$(grep -c 'persist-credentials: false' "$wf")"
  grep -qx '      - run: just site' "$wf"
  grep -qx '          path: _site' "$wf"
  # The preview deploys the build job's artifact: it never runs the build with the token.
  preview_job=$(sed -n '/^  preview:$/,$p' "$wf")
  (! grep -q 'just site' <<<"$preview_job")
  grep -qx '          name: github-pages' <<<"$preview_job"
  grep -qF "if: github.event_name == 'pull_request' && !github.event.pull_request.draft && !endsWith(github.event.pull_request.user.login, '[bot]')" <<<"$preview_job"
  # shellcheck disable=SC2016
  grep -qF 'gh api "repos/$REPO/pulls/$PR" --jq '\''.state + " " + (.draft|tostring)'\''' <<<"$preview_job"
  # shellcheck disable=SC2016
  grep -qF '[ "$state" != "open false" ]' <<<"$preview_job"
  # shellcheck disable=SC2016
  grep -qF 'group: preview-site-${{ github.event.pull_request.number }}' <<<"$preview_job"
  grep -qF 'X-Robots-Tag: noindex' <<<"$preview_job"
  grep -qF "dlx wrangler@$wrangler_pin" <<<"$preview_job"
done
# The site build is a required check, and `just check` builds an Astro site.
jq -e '.rules[0].parameters.required_status_checks | any(.context == "site: build")' x/.github/rulesets/main-checks.json >/dev/null
jq -e '.rules[0].parameters.required_status_checks | any(.context == "site: build")' y/.github/rulesets/main-checks.json >/dev/null
(lacks -q '"site: build"' c/.github/rulesets/main-checks.json)
sed -n '/^check:/,/^$/p' y/justfile | grep -qx '    @just site'
(sed -n '/^check:/,/^$/p' x/justfile | lacks -q 'just site')

# Docs site: m (nested src), k (flat) and h (Go) answer docs_site=true; ds is a library
# without python_api. Built from docs/ with the pinned Zensical, deployed like the site.
zensical_pin=$(sed -n '/^zensical_version:/,/^$/s/^  default: //p' "$repo/copier.yml")
mkdocstrings_pin=$(sed -n '/^mkdocstrings_python_version:/,/^$/s/^  default: //p' "$repo/copier.yml")
for r in m k h ds; do
  for f in zensical.toml docs/index.md .github/workflows/docs.yml; do test -f "$r/$f"; done
  grep -qx '/_docs/' "$r/.gitignore"
  grep -qx 'site_dir = "_docs"' "$r/zensical.toml"
  grep -qF "zensical@$zensical_pin build --strict" "$r/justfile"
  grep -qF "zensical@$zensical_pin serve" "$r/justfile"
  wf=$r/.github/workflows/docs.yml
  test "$(grep -c 'pages: write' "$wf")" = 1
  grep -qx '      - run: just docs' "$wf"
  grep -qx '          path: _docs' "$wf"
  test "$(grep -c 'uses: actions/checkout@' "$wf")" = "$(grep -c 'persist-credentials: false' "$wf")"
  sed -n '/^  deploy:$/,$p' "$wf" | grep -qxF "    if: github.event_name != 'pull_request' && github.ref == 'refs/heads/main'"
  grep -q 'build_type=workflow' "$r/justfile"
done
# k keeps its own README.
for r in m h ds; do grep -qx '## Documentation' "$r/README.md"; done
for r in m h; do
  jq -e '.rules[0].parameters.required_status_checks | any(.context == "docs: build")' "$r/.github/rulesets/main-checks.json" >/dev/null
done
# The API reference only for a Python library used through its API.
for r in m k; do
  test -f "$r/docs/reference.md"
  grep -qF -- "--with mkdocstrings-python==$mkdocstrings_pin" "$r/justfile"
done
grep -qx '::: mutate_me' m/docs/reference.md
grep -qx 'paths = \["py/src"\]' m/zensical.toml
grep -qx 'paths = \["\."\]' k/zensical.toml
for r in h ds; do
  test ! -e "$r/docs/reference.md"
  (lacks -q 'mkdocstrings' "$r/justfile")
  (lacks -q 'mkdocstrings' "$r/zensical.toml")
done
# The badge page links SECURITY.md outside docs/ by URL, which a strict build accepts.
grep -qF '[SECURITY.md](https://github.com/example-org/example/blob/main/.github/SECURITY.md)' h/docs/assurance-case.md
for r in a c x w; do
  test ! -e "$r/zensical.toml"
  test ! -e "$r/.github/workflows/docs.yml"
  (lacks -q '^docs:' "$r/justfile")
done
(lacks -q '"docs: build"' c/.github/rulesets/main-checks.json)
# A real strict build: the API reference from the docstrings, and the badge pages.
(cd m && just docs >/dev/null 2>&1)
grep -qF 'Add two numbers' m/_docs/reference/index.html
(cd h && just docs >/dev/null 2>&1)
test -f h/_docs/assurance-case/index.html
# k's flat package: mkdocstrings finds the module at the root, through paths = ["."].
(cd k && just docs >/dev/null 2>&1)
# A private repo's page has no links into the repo, which its readers cannot open.
(lacks -rq 'github.com/' hush-plain/site hush-astro/site/src)
grep -q 'href="https://github.com/.*/issues"' x/site/index.html
# The plain starter is a tool page: the job under the name, or a TODO without a
# description; an input, a result and one action; a privacy line its CSP keeps true.
grep -qxF '    <p class="job">Tidies &#34;&lt;b&gt;&#34; tags &amp; more</p>' hush-plain/site/index.html
(lacks -q 'TODO: one sentence' hush-plain/site/index.html)
grep -qF 'TODO: one sentence naming the job' x/site/index.html
(lacks -q 'class="job"' x/site/index.html)
for r in x hush-plain; do
  grep -qF '<textarea id="input"' "$r/site/index.html"
  grep -qF '<pre id="result"' "$r/site/index.html"
  grep -qF '<button type="button" id="copy" class="primary">' "$r/site/index.html"
  grep -qF "content=\"default-src 'none'; script-src 'self';" "$r/site/index.html"
  (grep -F 'http-equiv="Content-Security-Policy"' "$r/site/index.html" | lacks -q 'connect-src')
  grep -qF 'what you type or open never leaves this page' "$r/site/index.html"
  node --check "$r/site/main.mjs"
done
grep -q 'Skip to the content' hush-astro/site/src/layouts/Base.astro
# The Astro layout holds the description as an expression, which Astro escapes at build. A
# quoted attribute would end at the description's first quote and fail the build.
grep -qxF '    <meta name="description" content={ "Tidies \"<b>\" tags & more" } />' hush-astro/site/src/layouts/Base.astro
# Site previews are <slug>-site-pr-<n>, apart from a web app's <slug>-pr-<n>.
# shellcheck disable=SC2016
grep -qF 'deploy-worker.sh" Preview "cli-me-site-pr-$PR" --config wrangler.site.jsonc' x/.github/workflows/site.yml
# shellcheck disable=SC2016
grep -qF 'deploy-worker.sh" Preview "pipe-me-site-pr-$PR" --config wrangler.site.jsonc' d/.github/workflows/site.yml
# One retire job per prefix, each in the group of the preview job it retires, so a site
# preview and a web-app preview of one PR never share a group.
grep -qx '          - {slug: cli-me-site, group: preview-site}' x/.github/workflows/preview-retire.yml
test "$(grep -c '^          - {slug: ' x/.github/workflows/preview-retire.yml)" = 1
grep -qx '          - {slug: pipe-me, group: preview}' d/.github/workflows/preview-retire.yml
grep -qx '          - {slug: pipe-me-site, group: preview-site}' d/.github/workflows/preview-retire.yml
grep -qx '          - {slug: app, group: preview}' s/.github/workflows/preview-retire.yml
test "$(grep -c '^          - {slug: ' s/.github/workflows/preview-retire.yml)" = 1
# Without a package.json, the preview job's pnpm comes from the pin; with one, from it.
grep -qxF "          version: \"$pnpm_pin\"" x/.github/workflows/site.yml
grep -qx '          package_json_file: web/package.json' d/.github/workflows/site.yml
# The starter page builds as it is.
(cd x && just site >/dev/null)
test -f x/_site/index.html
test -f x/_site/main.mjs
# deploy-worker.sh with the site's wrangler command and config.
(cd "$dstub/work" && env STUB="$dstub" PATH="$dstub:$PATH" GITHUB_OUTPUT="$dstub/gho" GITHUB_STEP_SUMMARY="$dstub/sum" \
  WRANGLER="pnpm dlx wrangler@$wrangler_pin" "$deploy_sh" Preview cli-me-site-pr-4 --config wrangler.site.jsonc >"$dstub/out" 2>&1)
test "$(tail -n 1 "$dstub/calls")" = "pnpm dlx wrangler@$wrangler_pin deploy --name cli-me-site-pr-4 --config wrangler.site.jsonc"
# A nested package's knip never sees the page's files.
jq -e '.knip | has("ignoreFiles") | not' d/web/package.json >/dev/null
# The preview serves the build under /<repo>/, as Pages does.
grep -qF "printf '/ /cli-me/ 302\n' > _site/_redirects" x/.github/workflows/site.yml
test ! -e x/site/package.json
# A project without the site gets none of it.
for r in a m w; do
  test ! -e "$r/site"
  test ! -e "$r/wrangler.site.jsonc"
  test ! -e "$r/.github/workflows/site.yml"
  test ! -e "$r/.github/workflows/preview-retire.yml"
  test ! -e "$r/.github/scripts/preview-retire.sh"
  test ! -e "$r/.github/scripts/deploy-worker.sh"
  (lacks -q '_site' "$r/.gitignore")
  (lacks -qx 'site:' "$r/justfile")
done
# m turns Pages on for its docs site.
for r in a w; do (lacks -qF 'repos/{owner}/{repo}/pages' "$r/justfile"); done
(lacks -q 'app-site' s/.github/workflows/preview-retire.yml)
# Astro site: y has no TypeScript stack, so the site's node and pnpm come from site.yml and
# site/package.json alone. t has it beside a TypeScript package at the root.
astro_pin=$(sed -n '/^astro_version:/,/^$/s/^  default: //p' "$repo/copier.yml")
test -n "$astro_pin"
for r in y t; do
  for f in astro.config.mjs package.json pnpm-workspace.yaml src/layouts/Base.astro src/pages/index.astro src/pages/about.md; do
    test -f "$r/site/$f"
  done
  test ! -e "$r/site/index.html"
  jq -e --arg v "$astro_pin" '.dependencies.astro == $v' "$r/site/package.json" >/dev/null
  jq -e --arg v "pnpm@$pnpm_pin" '.packageManager == $v' "$r/site/package.json" >/dev/null
  grep -qx 'minimumReleaseAge: 10080' "$r/site/pnpm-workspace.yaml"
  grep -qx '/site/dist/' "$r/.gitignore"
  grep -qx '/site/.astro/' "$r/.gitignore"
  grep -qF '"directory": "./site/dist"' "$r/wrangler.site.jsonc"
  grep -qx '    pnpm -C site install --frozen-lockfile' "$r/justfile"
  grep -qx 'site-sync:' "$r/justfile"
  wf=$r/.github/workflows/site.yml
  grep -qx '          path: site/dist' "$wf"
  # The build job sets up node and pnpm from the site's own package.json.
  sed -n '/^  build:$/,/^  deploy:$/p' "$wf" | grep -qx '          package_json_file: site/package.json'
  sed -n '/^  build:$/,/^  deploy:$/p' "$wf" | grep -q 'uses: actions/setup-node@'
  # Pages serves the site under /<repo>/, and so does its preview.
  grep -qx "  base: \"/$([ "$r" = y ] && echo site-me || echo lib-me)\"," "$r/site/astro.config.mjs"
  # The lockfile it writes is skipped by the YAML hooks at any depth.
  grep -qxF '  - "**/pnpm-lock.yaml"' "$r/.yamlfmt"
  test "$(grep -cxF '        exclude: (^|/)pnpm-lock\.yaml$' "$r/.pre-commit-config.yaml")" -ge 2
done
grep -qx '          version: "'"$pnpm_pin"'"' y/.github/workflows/site.yml
# shellcheck disable=SC2016
grep -qF 'tar -xf "$RUNNER_TEMP/pages/artifact.tar" -C site/dist/site-me' y/.github/workflows/site.yml
grep -qF "printf '/ /site-me/ 302\n' > site/dist/_redirects" y/.github/workflows/site.yml
# The site's package.json gets its own Dependabot entry; Renovate finds every package.json.
grep -A1 -x '  - package-ecosystem: npm' y/.github/dependabot.yml | grep -qx '    directory: /site'
(lacks -q 'directory: /site' x/.github/dependabot.yml)
(lacks -q 'ignorePaths\|enabledManagers' d/renovate.json5)
# A root package's tools leave the site alone: knip reports none of it, biome skips the
# .astro files it can only half read.
jq -e '.knip.ignoreFiles == ["site/**"]' t/package.json >/dev/null
jq -e '.files.includes | index("!site/**/*.astro")' t/biome.json >/dev/null
(lacks -q 'astro' x/.github/workflows/site.yml)
# The starter pages are the project's; package.json stays the template's.
for f in r/site/index.html r/site/style.css r/site/main.mjs y/site/astro.config.mjs \
  y/site/src/layouts/Base.astro y/site/src/pages/index.astro y/site/src/pages/about.md; do
  grep -q 'project edit' "$f"
done
(lacks -q 'project edit' y/site/package.json)
# It builds: every page, Markdown included, inside the layout.
astro_start=$SECONDS
(cd y && just site-sync >/dev/null 2>&1 && just site >/dev/null 2>&1)
echo "check-render: the Astro build took $((SECONDS - astro_start)) s" >&2
test -f y/site/dist/index.html
test -f y/site/dist/about/index.html
grep -qF '<h1>About</h1>' y/site/dist/about/index.html
grep -qF 'href="/site-me/about/"' y/site/dist/index.html
test -f y/site/pnpm-lock.yaml
# The deploy job's gate: it deploys only when Pages deploys from Actions, skips with a
# notice while Pages is off (404), and fails on any other error. Run against a stub gh.
gate_sh=$out/fake-pages-gate
mkdir -p "$gate_sh"
sed -n '/^  deploy:$/,/^  [a-z]/p' x/.github/workflows/site.yml |
  sed -n '/^          if build=/,/^          echo "run=false"/s/^          //p' >"$gate_sh/gate.sh"
test -s "$gate_sh/gate.sh"
cat >"$gate_sh/gh" <<'STUB'
#!/usr/bin/env bash
[ "$*" = 'api repos/o/r/pages --jq .build_type' ] || { echo "gh: unexpected call: $*" >&2; exit 2; }
case $PAGES in
  workflow | legacy) echo "$PAGES" ;;
  404) echo 'gh: Not Found (HTTP 404)' >&2 && exit 1 ;;
  *) echo 'gh: Server Error (HTTP 500)' >&2 && exit 1 ;;
esac
STUB
chmod +x "$gate_sh/gh"
pages_gate() {
  : >"$gate_sh/gho"
  (cd "$gate_sh" && env PAGES="$1" REPO=o/r PATH="$gate_sh:$PATH" GITHUB_OUTPUT="$gate_sh/gho" bash -e gate.sh >"$gate_sh/out" 2>&1)
}
pages_gate workflow
grep -qx 'run=true' "$gate_sh/gho"
pages_gate 404
grep -qx 'run=false' "$gate_sh/gho"
grep -qF '::notice::GitHub Pages is off' "$gate_sh/out"
pages_gate legacy
grep -qx 'run=false' "$gate_sh/gho"
# Any other error fails the job with gh's message, and sets no output.
(! pages_gate 500)
grep -qF 'HTTP 500' "$gate_sh/out"
test ! -s "$gate_sh/gho"
grep -qxF "      - if: steps.gate.outputs.run == 'true'" <<<"$(sed -n '/^  deploy:$/,/^  [a-z]/p' x/.github/workflows/site.yml)"
# dlx resolves wrangler without a lockfile, so it waits the same week as an install.
grep -qxF "          WRANGLER: pnpm --config.minimum-release-age=10080 dlx wrangler@$wrangler_pin" x/.github/workflows/site.yml
# The site's README section, with its own previews heading unless the web app's is there.
for r in x y d; do grep -qx '## Site' "$r/README.md"; done
grep -qx '### Pull request previews' x/README.md
test "$(grep -cx '### Pull request previews' d/README.md)" = 1
grep -qF 'cli-me-site-pr-<number>' x/README.md
grep -qF 'just site-sync' y/README.md
grep -q 'You need .*\[pnpm\]' y/README.md
(lacks -q '\[pnpm\]' x/README.md)
(lacks -qx '## Site' a/README.md)
# The copier-update PR names the Astro lockfile refresh too.
# shellcheck disable=SC2016
grep -qF '\`just site-sync\`' y/.github/workflows/copier-update.yml
(lacks -q 'site-sync' x/.github/workflows/copier-update.yml)
grep -q '^  # shortcut: the sweep matches Workers by name alone' x/.github/scripts/preview-retire.sh
# A web app at the repo root builds in place.
test -f s/wrangler.jsonc
grep -q '^  production:' s/.github/workflows/ts.yml
sed -n '/^  production:$/,/^  [a-z]/p' s/.github/workflows/ts.yml | grep -xF '    needs: [check, e2e]' >/dev/null
test -f s/.github/workflows/preview-retire.yml
grep -qx '          path: dist' s/.github/workflows/ts.yml
(lacks -q 'working-directory' s/.github/workflows/preview-retire.yml)
# Hosting and the Worker script. d, s, x and y keep the defaults: no script, no custom
# domain, the site on Pages. wk is a web app with both; cfp a plain site on a Worker with
# both; cfa an Astro site on a Worker at its workers.dev address.
for f in wk/wrangler.jsonc cfp/wrangler.site.jsonc; do
  grep -qF '"binding": "ASSETS",' "$f"
  grep -qF '"run_worker_first": ["/api/*"]' "$f"
done
grep -qF '"main": "./worker/index.ts",' wk/wrangler.jsonc
grep -qF '"main": "./site/worker/index.mjs",' cfp/wrangler.site.jsonc
for f in d/web/wrangler.jsonc s/wrangler.jsonc x/wrangler.site.jsonc cfa/wrangler.site.jsonc; do
  (lacks -qE '"main"|"binding"|run_worker_first' "$f")
done
for f in index.ts index.test.ts tsconfig.json; do test -f "wk/worker/$f"; done
test ! -e s/worker
test ! -e d/web/worker
grep -qF '"typecheck": "tsc && tsc -p worker"' wk/package.json
jq -e '.devDependencies["@cloudflare/workers-types"]' wk/package.json >/dev/null
grep -qF '"typecheck": "tsc"' s/package.json
(lacks -q 'workers-types' s/package.json d/web/package.json)
# The site's script: `just site` runs its tests with node, which the build job sets up,
# and leaves it out of the files it builds.
test -f cfp/site/worker/index.mjs
# A plain site on a Worker ships _headers, which a meta tag cannot replace for
# frame-ancestors; Pages and Astro get none. Its policy is the page's plus frame-ancestors.
test -f cfp/site/_headers
grep -qF 'X-Content-Type-Options: nosniff' cfp/site/_headers
grep -qF 'Strict-Transport-Security:' cfp/site/_headers
meta_csp=$(sed -n 's/.*http-equiv="Content-Security-Policy" content="\([^"]*\)".*/\1/p' cfp/site/index.html)
grep -qxF "  Content-Security-Policy: $meta_csp; frame-ancestors 'none'" cfp/site/_headers
for r in x cfa; do test ! -e "$r/site/_headers"; done
test -f cfp/site/worker/index.test.mjs
test ! -e x/site/worker
test ! -e cfa/site/worker
grep -qx '    node --test site/worker/index.test.mjs' cfp/justfile
(lacks -q 'node --test' x/justfile cfa/justfile)
(cd cfp && just site >/dev/null 2>&1)
test -f cfp/_site/index.html
test ! -e cfp/_site/worker
sed -n '/^  build:$/,/^  deploy:$/p' cfp/.github/workflows/site.yml | grep -q 'uses: actions/setup-node@'
(sed -n '/^  build:$/,/^  deploy:$/p' x/.github/workflows/site.yml | lacks -q 'uses: actions/setup-node@')
# A custom domain goes to production alone, as --domain: previews deploy the same config.
grep -qxF "        run: '\"\$GITHUB_WORKSPACE/.github/scripts/deploy-worker.sh\" Production \"\" --domain app.example.org'" wk/.github/workflows/ts.yml
(lacks -q 'Preview.*--domain' wk/.github/workflows/ts.yml cfp/.github/workflows/site.yml)
(lacks -q -- '--domain' d/.github/workflows/ts.yml s/.github/workflows/ts.yml cfa/.github/workflows/site.yml x/.github/workflows/site.yml)
# shellcheck disable=SC2016 # the backticks are Markdown
grep -qF 'Only `production`'"'"'s token also needs Zone > Workers Routes: Edit for the zone of `app.example.org`' wk/README.md
# shellcheck disable=SC2016 # the backticks are Markdown
grep -qF 'only `production`'"'"'s token also gets Zone > Workers Routes: Edit for the zone of `demo.example.org`' cfp/README.md
(lacks -q 'Workers Routes' d/README.md s/README.md cfa/README.md x/README.md)
# The site on a Worker: production deploys the build job's artifact with the site's
# config, in the production environment, and neither job touches Pages or serves under /<repo>/.
for r in cfp cfa; do
  wf=$r/.github/workflows/site.yml
  deploy_job=$(sed -n '/^  deploy:$/,/^  [a-z]/p' "$wf")
  grep -qx '      name: production' <<<"$deploy_job"
  grep -qx '      group: site-production' <<<"$deploy_job"
  grep -qxF "    if: github.event_name != 'pull_request' && github.ref == 'refs/heads/main'" <<<"$deploy_job"
  grep -qxF "          WRANGLER: pnpm --config.minimum-release-age=10080 dlx wrangler@$wrangler_pin" <<<"$deploy_job"
  (lacks -qE 'pages: write|id-token|deploy-pages|_redirects' "$wf")
  (lacks -qF 'repos/{owner}/{repo}/pages' "$r/justfile")
  test "$(grep -c '^    timeout-minutes:' "$wf")" = 3
  test "$(grep -c 'uses: actions/checkout@' "$wf")" = "$(grep -c 'persist-credentials: false' "$wf")"
done
grep -qxF "        run: '\"\$GITHUB_WORKSPACE/.github/scripts/deploy-worker.sh\" Production \"\" --config wrangler.site.jsonc --domain demo.example.org'" cfp/.github/workflows/site.yml
grep -qxF "        run: '\"\$GITHUB_WORKSPACE/.github/scripts/deploy-worker.sh\" Production \"\" --config wrangler.site.jsonc'" cfa/.github/workflows/site.yml
grep -qF "printf '\\n/*\\n  X-Robots-Tag: noindex\\n' >> _site/_headers" cfp/.github/workflows/site.yml
# cfd: the site deploys to its Worker, and repo-settings turns Pages on for docs.yml alone.
grep -qx '      name: production' <<<"$(sed -n '/^  deploy:$/,/^  [a-z]/p' cfd/.github/workflows/site.yml)"
(lacks -q 'pages: write' cfd/.github/workflows/site.yml)
test "$(grep -c 'pages: write' cfd/.github/workflows/docs.yml)" = 1
test "$(grep -cF 'POST repos/{owner}/{repo}/pages' cfd/justfile)" = 1
grep -qF "so docs.yml's deploy job skips." cfd/justfile
(lacks -qF -e "site.yml's deploy job" -e "For the site's previews" cfd/justfile)
grep -qx '    main_only_env production' cfd/justfile
# The Pages site keeps its deploy and its /<repo>/ previews.
grep -qx '      name: github-pages' <<<"$(sed -n '/^  deploy:$/,/^  [a-z]/p' x/.github/workflows/site.yml)"
# Astro on a Worker: `site` is the Worker's address, with no Pages base.
grep -qx '  site: "https://cfa-me-site.example-org.workers.dev",' cfa/site/astro.config.mjs
(lacks -q 'base:' cfa/site/astro.config.mjs)
# shellcheck disable=SC2016 # the backticks are Markdown
grep -q 'deploys that build to the Cloudflare Worker `cf-me-site`' cfp/README.md
grep -q 'deploys that build to GitHub Pages' x/README.md
# site_url: asked of a site on a Worker, defaulting to the site Worker's address; a Pages
# site has none.
grep -qx 'site_url: https://cfa-me-site.example-org.workers.dev' cfa/.copier-answers.yml
(lacks -q 'site_url' x/.copier-answers.yml y/.copier-answers.yml)
# Other kinds get none of it.
test ! -e a/wrangler.jsonc
(lacks -q 'production' a/.github/workflows/ts.yml)
test ! -e a/.github/workflows/preview-retire.yml
(lacks -q 'preview' a/.github/workflows/ts.yml)
grep -q 'stages: \[pre-push\]' d/.pre-commit-config.yaml
grep -qx 'default_install_hook_types: \[pre-commit, commit-msg, pre-push\]' d/.pre-commit-config.yaml
(lacks -q 'pre-push' a/.pre-commit-config.yaml)
# Commit messages and PR titles: one committed.toml, read by the commit-msg hook and
