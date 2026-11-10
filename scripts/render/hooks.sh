# shellcheck shell=bash
# shellcheck disable=SC2154,SC2164 # check-render.sh sets out, repo, copier and set -e
# Commit rules and git hooks, run for real in copies of the renders.

# the pr-title workflow, in every render. The bots write titles that pass it.
grep -qx 'default_install_hook_types: \[pre-commit, commit-msg\]' a/.pre-commit-config.yaml
for r in a b c d; do
  grep -qx 'style = "conventional"' "$r/committed.toml"
  grep -qx '      - id: committed' "$r/.pre-commit-config.yaml"
  grep -q 'uvx --exclude-newer "1 week" committed@[0-9.]* --config committed.toml --commit-file -' "$r/.github/workflows/pr-title.yml"
  committed=$(sed -n 's/.*uvx --exclude-newer "1 week" committed@\([0-9.]*\) .*/\1/p' "$r/.github/workflows/pr-title.yml")
  for msg in 'chore: update from template v1.0.0' 'chore(deps): bump x from 1 to 2' 'feat!: drop x' 'revert: feat: add x'; do
    printf '%s\n' "$msg" | uvx -q "committed@$committed" --config "$r/committed.toml" --commit-file - >/dev/null
  done
  for msg in 'Add x' 'Revert "feat: add x"' 'feat: add x.'; do
    (! printf '%s\n' "$msg" | uvx -q "committed@$committed" --config "$r/committed.toml" --commit-file - >/dev/null 2>&1)
  done
done
# Spelling and links: a fresh render passes both hooks, and fails them on a misspelt
# word and on a relative link to a missing file. prek needs a git repo, so each check
# runs in a copy. lychee runs offline in the hook; links.yml checks the web weekly.
prek=(uvx -q "prek${PREK_VERSION:+@$PREK_VERSION}" run --all-files)
# yamlfmt leaves a fresh render's workflows as they are, or the project's own first
# `prek run --all-files` fails: dp ends python.yml on a `run: |` that yamlfmt would turn
# into `|-`, and preview-retire.yml's matrix (d both entries, s a web app, x a site) is
# written the way yamlfmt spaces flow mappings.
for r in dp d s x; do
  rm -rf "$r-yaml"
  cp -R "$r" "$r-yaml"
  git -C "$r-yaml" init -q
  git -C "$r-yaml" add -A
  (cd "$r-yaml" && "${prek[@]}" yamlfmt >/dev/null)
  rm -rf "$r-yaml"
done
for r in a b d h; do
  rm -rf "$r-hooks"
  cp -R "$r" "$r-hooks"
  git -C "$r-hooks" init -q
  git -C "$r-hooks" add -A
  (cd "$r-hooks" && "${prek[@]}" typos lychee jsonvet >/dev/null)
  # b is private with no license, so it has no reuse hook.
  [ "$r" = b ] || (cd "$r-hooks" && "${prek[@]}" reuse >/dev/null)
done
# Every Python render passes Scientific Python's repo-review, bar the checks its
# pyproject.toml ignores with a reason. Those depend on the answers: the bot, the
# license and a nested package each change the list.
rr_runs=0
for cfg in */.pre-commit-config.yaml; do
  r=${cfg%%/*}
  case $r in *-hooks | rr-*) continue ;; esac
  grep -q 'id: sp-repo-review$' "$cfg" || continue
  rm -rf "rr-$r"
  cp -R "$r" "rr-$r"
  git -C "rr-$r" init -q
  git -C "rr-$r" add -A
  (cd "rr-$r" && "${prek[@]}" sp-repo-review >"../rr-$r.log" 2>&1) || {
    cat "rr-$r.log" >&2
    exit 1
  }
  rr_runs=$((rr_runs + 1))
done
[ "$rr_runs" -ge 10 ]
# The hook is Python-only, and a nested package points it at its own directory.
(lacks -q 'sp-repo-review' h/.pre-commit-config.yaml compose/.pre-commit-config.yaml)
grep -qxF '        args: [--show=err, --package-dir=api]' c/.pre-commit-config.yaml
(lacks -q 'package-dir' w/.pre-commit-config.yaml)
# The ignore list follows the answers: the bot, the license and the package path.
grep -q '^GH212 = ' w/pyproject.toml
(lacks -q '^GH200 = ' w/pyproject.toml)
grep -q '^GH200 = ' d/pipe/pyproject.toml
(lacks -q '^GH212 = ' d/pipe/pyproject.toml)
grep -q '^PY003 = "no license yet' b/svc/pyproject.toml
grep -q '^PY003 = "LICENSE sits at the repo root' c/api/pyproject.toml
grep -q '^PY004 = ' c/api/pyproject.toml
(lacks -qE '^PY00[34] = ' w/pyproject.toml)
grep -qx 'strict = true' w/pyproject.toml
# The first-release checklist holds only the steps the answers need. w is a private-use
# app: nothing to register, so no checklist, no archive badge and no save link.
fr=.github/first-release.md
grep -q 'Zenodo' "a/$fr"
grep -qF '.github/allowed_signers' "a/$fr"
grep -q 'archive.softwareheritage.org/save/' "a/$fr"
grep -q 'research-software-directory.org' "a/$fr"
(lacks -qE 'PyPI|OpenSSF' "a/$fr")
grep -q 'PyPI trusted publishing' "c/$fr"
grep -q 'passing first, then silver' "h/$fr"
grep -q 'OpenSSF' "m/$fr"
(lacks -q 'then silver' "m/$fr")
test ! -e "w/$fr"
test ! -e "b/$fr"
grep -qF -- "--body-file $fr" a/justfile
(lacks -q 'first-release' w/justfile)
grep -qF '(https://archive.softwareheritage.org/browse/origin/?origin_url=https://github.com/example-org/render-me)' a/README.md
grep -q 'Archive it in Software Heritage' a/justfile
(lacks -q 'softwareheritage' w/README.md w/justfile b/README.md b/justfile)
# The web apps track the shots spec and ignore only the screenshots `just ts-shots` writes.
rm -rf s-git
cp -R s s-git
git -C s-git init -q
git -C s-git add -A
git -C s-git ls-files --error-unmatch tests/shots/shots.spec.ts >/dev/null
git -C s-git check-ignore -q shots/index-390-light.png
# A rumdl cache an older rumdl wrote has no ignore file of its own, and Biome formats its JSON.
git -C s-git check-ignore -q .rumdl_cache/0.3.1/entry.json
git -C d-hooks ls-files --error-unmatch web/tests/shots/shots.spec.ts >/dev/null
git -C d-hooks check-ignore -q web/shots/index-390-light.png
git -C d-hooks check-ignore -q web/.dev.vars
git -C d-hooks check-ignore -q deploy.pem
git -C d-hooks check-ignore -q tls.key
git -C d-hooks check-ignore -q web/.npmrc
git -C d-hooks check-ignore -q web/.dev.vars.production
# h's commit-msg hook takes a sign-off with an email, and refuses one without.
dco_hook=(uvx -q "prek${PREK_VERSION:+@$PREK_VERSION}" run --hook-stage commit-msg --commit-msg-filename msg dco-signoff)
printf 'feat: x\n\nSigned-off-by: Ada Lovelace <ada@example.com>\n' >h-hooks/msg
(cd h-hooks && "${dco_hook[@]}" >/dev/null)
printf 'feat: x\n\nSigned-off-by: Ada Lovelace\n' >h-hooks/msg
(cd h-hooks && ! "${dco_hook[@]}" >/dev/null 2>&1)
rm -rf h-hooks
# citesync passes on each fresh citable render: root (a), nested (c, d, m), one stack (h, r, t).
# Adding a release to CITATION.cff leaves codemeta.json stale, which fails the hook until
# the manual-stage writer fixes it. The writer re-indents codemeta.json, so a second
# pass of the hooks over the citation files must leave nothing to change. biome is skipped:
# it runs through pnpm, which CI's render job doesn't install.
write=(uvx -q "prek${PREK_VERSION:+@$PREK_VERSION}" run citesync-write --hook-stage manual --all-files)
cite_files=(env SKIP=biome uvx -q "prek${PREK_VERSION:+@$PREK_VERSION}" run --files CITATION.cff codemeta.json)
for r in a c d h m r t; do
  rm -rf "$r-cite"
  cp -R "$r" "$r-cite"
  git -C "$r-cite" init -q
  git -C "$r-cite" add -A
  (cd "$r-cite" && "${prek[@]}" citesync >/dev/null)
done
for r in a m r t; do
  printf 'version: "0.1.0"\ndate-released: 2026-10-29\ndoi: 10.5281/zenodo.1234\n' >>"$r-cite/CITATION.cff"
  sed -i.bak 's/^  "@type": "SoftwareSourceCode",$/&\n  "version": "0.0.9",/' "$r-cite/codemeta.json"
  rm "$r-cite/codemeta.json.bak"
  git -C "$r-cite" add -A
  (cd "$r-cite" && ! "${prek[@]}" citesync >../cite.err 2>&1)
  grep -q "version-mismatch.*'0.0.9'" cite.err
  (cd "$r-cite" && "${write[@]}" >/dev/null || true)
  (cd "$r-cite" && "${prek[@]}" citesync >/dev/null)
  grep -q '"version": "0.1.0"' "$r-cite/codemeta.json"
  git -C "$r-cite" add -A
  (cd "$r-cite" && "${cite_files[@]}" >/dev/null || true)
  git -C "$r-cite" add -A
  (cd "$r-cite" && "${cite_files[@]}" >/dev/null)
  git -C "$r-cite" diff --quiet
done
rm -rf a-cite c-cite d-cite h-cite m-cite r-cite t-cite cite.err
# Copier writes the template's commit id into the answers file, and a hex id can spell a
# word typos rejects, so typos skips that file.
printf '# definately\n' >>a-hooks/.copier-answers.yml
git -C a-hooks add .copier-answers.yml
(cd a-hooks && "${prek[@]}" typos >/dev/null)
printf 'This is definately wrong.\n' >a-hooks/docs/typo.md
printf 'See [the guide](missing.md).\n' >a-hooks/docs/dead.md
git -C a-hooks add docs/typo.md docs/dead.md
(cd a-hooks && ! "${prek[@]}" typos >typos.log 2>&1)
grep -qx 'This is definitely wrong.' a-hooks/docs/typo.md
# NumPy spells the flag `writeable`; typos must not rewrite the API to `writable`.
printf 'a.flags.writeable = False\nb = a.flags["WRITEABLE"]\n' >a-hooks/docs/flags.py
cp a-hooks/docs/flags.py flags.py.orig
git -C a-hooks add docs/flags.py
(cd a-hooks && "${prek[@]}" typos >/dev/null)
cmp a-hooks/docs/flags.py flags.py.orig
rm -f flags.py.orig
# typos knows English only, so it leaves translation catalogs alone: gettext .po files and
# whatever sits in a locales/ directory. The English typo above still fails.
mkdir -p a-hooks/po a-hooks/src/locales
printf 'msgid "Settings"\nmsgstr "Une ressource et une adresse"\n' >a-hooks/po/fr.po
printf '{"settings": "Un exemple de langage"}\n' >a-hooks/src/locales/fr.json
cp a-hooks/po/fr.po fr.po.orig
cp a-hooks/src/locales/fr.json fr.json.orig
git -C a-hooks add po/fr.po src/locales/fr.json
(cd a-hooks && "${prek[@]}" typos >/dev/null)
cmp a-hooks/po/fr.po fr.po.orig
cmp a-hooks/src/locales/fr.json fr.json.orig
rm -f fr.po.orig fr.json.orig
(cd a-hooks && ! "${prek[@]}" lychee >lychee.log 2>&1)
grep -q 'docs/missing.md.*File not found' a-hooks/lychee.log
# A web app's root-relative links resolve in public/, where Vite serves them from, and
# links.yml reads the same lychee.toml. A missing asset still fails.
sed -i 's|</head>|<link rel="icon" href="/favicon.svg" /></head>|' d-hooks/web/index.html
touch d-hooks/web/public/favicon.svg
git -C d-hooks add web/index.html web/public/favicon.svg
(cd d-hooks && "${prek[@]}" lychee >/dev/null)
git -C d-hooks rm -qf web/public/favicon.svg
(cd d-hooks && ! "${prek[@]}" lychee >lychee.log 2>&1)
grep -q 'web/public/favicon.svg.*File not found' d-hooks/lychee.log
# yamlfmt ignores a nested pnpm-lock.yaml passed by prek
mkdir -p a-hooks/ui
cat >a-hooks/ui/pnpm-lock.yaml <<'LOCK'
lockfileVersion: '9.0'

settings:
  autoInstallPeers: true
  excludeLinksFromLockfile: false
LOCK
git -C a-hooks add ui/pnpm-lock.yaml
(cd a-hooks && "${prek[@]}" yamlfmt >/dev/null)
git -C a-hooks diff --quiet ui/pnpm-lock.yaml
# end-of-file-fixer leaves tests/fixtures/ untouched
mkdir -p a-hooks/tests/fixtures
printf 'fixture content' >a-hooks/tests/fixtures/fixture.txt
git -C a-hooks add tests/fixtures/fixture.txt
(cd a-hooks && "${prek[@]}" end-of-file-fixer >/dev/null)
test "$(cat a-hooks/tests/fixtures/fixture.txt)" = 'fixture content'
rm -rf a-hooks b-hooks d-hooks
for r in a b; do
  grep -qx '      - id: typos' "$r/.pre-commit-config.yaml"
  grep -qx '        entry: lychee --no-progress --offline' "$r/.pre-commit-config.yaml"
  grep -q 'lycheeverse/lychee-action@' "$r/.github/workflows/links.yml"
  grep -q 'cron:' "$r/.github/workflows/links.yml"
done
# A private repo's own pages need a sign-in, so its link check skips them.
(lacks -q -- '--exclude' a/.github/workflows/links.yml)
grep -qF -- "--exclude '^https://github\\.com/example-org/odd-name--co([/#?]|\$)'" b/.github/workflows/links.yml
test "$(grep -c 'commit-message: {prefix: chore, include: scope}' a/.github/dependabot.yml)" -eq 5
grep -q "extends: \['config:best-practices', ':semanticCommits'\]" d/renovate.json5
grep -q "ignorePresets: \[':pinDevDependencies', 'security:minimumReleaseAgeNpm'\]" d/renovate.json5
grep -qx 'playwright-report/' d/.gitignore
# Outside CI, reusing a server on the preview port would test whichever app holds it.
(lacks -q reuseExistingServer d/web/playwright.config.ts)
(lacks -q 'playwright-report' a/.gitignore)
(lacks -q 'e2e' a/.github/workflows/ts.yml)
(lacks -qx 'shots/' a/.gitignore)
grep -q 'applies-to: security-updates' a/.github/dependabot.yml
# Actions and hook revs share one multi-ecosystem PR, with the same group in Renovate.
grep -qx '  actions-and-hooks:' a/.github/dependabot.yml
test "$(grep -c 'multi-ecosystem-group: actions-and-hooks' a/.github/dependabot.yml)" = 2
grep -q "groupName: 'actions and hooks'" d/renovate.json5
# Lock refreshes carry transitive security fixes, and the week's wait would block them.
grep -A3 'lockFileMaintenance: {' d/renovate.json5 | grep -q 'minimumReleaseAge: null'
# Minor and patch updates and the relock merge themselves, by Renovate, so the merge uses
# its app's bypass. Nothing else does: majors, copier and the actions group stay manual.
grep -qx '  platformAutomerge: false,' d/renovate.json5
grep -A4 'lockFileMaintenance: {' d/renovate.json5 | grep -qx '    automerge: true,'
grep -B3 'automerge: true' d/renovate.json5 | grep -q "groupName: 'runtime'"
test "$(grep -c 'automerge: true' d/renovate.json5)" = 2
# Exemptions that `pnpm audit --fix` writes for fresh security fixes clean themselves up.
grep -qx 'minimumReleaseAgeExcludePrune: true' d/web/pnpm-workspace.yaml
# Only data-pipeline renders it.
test ! -e a/sources.toml
test ! -e a/ATTRIBUTION.md
# Only web-service renders the FastAPI modules; the others keep the stdlib stub.
test ! -e a/src/render_me/app.py
(lacks -q fastapi a/pyproject.toml)
grep -q http.server a/src/render_me/__main__.py
# h: the unit test and the Example are two files, not one overwriting the other.
grep -q 'func TestAdd' h/add_test.go
grep -q 'func ExampleAdd' h/example_test.go

test -f i/main.go
grep -qx '/1tool' i/.gitignore
