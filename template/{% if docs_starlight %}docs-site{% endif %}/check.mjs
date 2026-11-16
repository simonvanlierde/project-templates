// Checks the built docs in _docs/ without a browser (`just docs` runs it after the build):
// - every link, script, stylesheet and image on the site resolves to a file, and every #anchor to an id;
// - nothing loads from another origin, in the pages or in their stylesheets;
// - every page has one Content-Security-Policy that names the sha256 of each of its inline scripts,
//   and no source in it is a host or `*`;
// - the 404 page is out of search engines, and the sitemap lists every other page.
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { resolve } from "node:path";

const dist = resolve(import.meta.dirname, "../_docs");
const config = readFileSync(resolve(import.meta.dirname, "astro.config.mjs"), "utf8");
const base = config.match(/const BASE = "([^"]*)"/)[1];
const site = config.match(/const SITE = "([^"]*)"/)[1];
assert.ok(existsSync(dist), "Build first: _docs/ is missing");

const files = readdirSync(dist, { recursive: true, withFileTypes: true })
  .filter((f) => f.isFile())
  .map((f) => resolve(f.parentPath, f.name));
const pages = files.filter((f) => f.endsWith(".html"));
const html = new Map(pages.map((f) => [f, readFileSync(f, "utf8")]));
const ids = new Map([...html].map(([f, s]) => [f, new Set([...s.matchAll(/\sid="([^"]+)"/g)].map((m) => m[1]))]));
const problems = [];

/** The file that serves a site path, or undefined. A folder's address ends in a slash. */
const fileOf = (path) => {
  const rel = decodeURIComponent(path.slice(base.length)) || "/";
  const file = rel.endsWith("/") ? resolve(dist, `.${rel}`, "index.html") : resolve(dist, `.${rel}`);
  return existsSync(file) && statSync(file).isFile() ? file : undefined;
};

const hashOf = (code) => `'sha256-${createHash("sha256").update(code).digest("base64")}'`;
const rel = (f) => f.slice(dist.length + 1);

for (const [file, source] of html) {
  const here = rel(file);
  const generated = source.includes('<meta name="generator" content="Starlight');
  // Pagefind's own pages carry no policy; the site's pages must.
  const policies = [...source.matchAll(/<meta http-equiv="Content-Security-Policy" content="([^"]*)"/g)].map((m) => m[1]);
  if (generated) {
    if (policies.length !== 1) problems.push(`${here}: ${policies.length} Content-Security-Policy tags, expected 1`);
    else {
      const policy = policies[0];
      for (const [, attrs, code] of source.matchAll(/<script(?![^>]*\ssrc=)([^>]*)>([\s\S]*?)<\/script>/g)) {
        if (/type="(application\/(ld\+)?json|importmap)"/.test(attrs)) continue;
        if (!policy.includes(hashOf(code))) problems.push(`${here}: an inline script is not in the policy`);
      }
      if (/\*|https?:/.test(policy)) problems.push(`${here}: the policy names a host or *`);
    }
  }
  for (const [, tag, attr, url] of source.matchAll(/<(a|link|script|img|source|iframe|form)\b[^>]*?\s(href|src|action)="([^"]*)"/g)) {
    if (/^(mailto:|tel:|data:)/.test(url)) continue;
    const kind = tag.toLowerCase();
    const absolute = /^(https?:)?\/\//.test(url);
    if (absolute) {
      const own = url.startsWith(site);
      // A link a reader follows may leave the site; anything the page loads, or a canonical link, may not.
      const loads = kind !== "a" && !/<link\b[^>]*\srel="(canonical|alternate)"/.test(source.slice(source.indexOf(url) - 200, source.indexOf(url) + url.length + 5));
      if (loads && !own) problems.push(`${here}: loads ${url} from another origin`);
      if (!own || kind !== "a") continue;
    }
    const path = absolute ? new URL(url).pathname : url.startsWith("/") ? url.split(/[#?]/)[0] : undefined;
    const [, frag] = url.split("#");
    let target = file;
    if (path !== undefined) {
      if (!path.startsWith(base)) {
        problems.push(`${here}: ${url} is outside the base ${base}`);
        continue;
      }
      target = fileOf(path);
      if (!target) {
        problems.push(`${here}: ${url} does not resolve to a file`);
        continue;
      }
    } else if (url && !url.startsWith("#")) {
      problems.push(`${here}: ${url} is relative; Starlight writes site-rooted paths`);
      continue;
    }
    if (frag && ids.has(target) && !ids.get(target).has(decodeURIComponent(frag)))
      problems.push(`${here}: ${url} has no #${frag} on the page`);
  }
}

for (const css of files.filter((f) => f.endsWith(".css"))) {
  if (/@import|url\(\s*["']?(https?:)?\/\//.test(readFileSync(css, "utf8"))) problems.push(`${rel(css)}: loads from another origin`);
}
const notFound = html.get(resolve(dist, "404.html"));
if (!notFound?.includes('<meta name="robots" content="noindex"')) problems.push("404.html is not noindex");
const sitemap = readFileSync(resolve(dist, "sitemap-0.xml"), "utf8");
for (const [file, source] of html) {
  const canonical = source.match(/<link rel="canonical" href="([^"]+)"/)?.[1];
  if (canonical && !sitemap.includes(`<loc>${canonical}</loc>`)) problems.push(`${rel(file)}: ${canonical} is not in the sitemap`);
}

assert.deepEqual(problems, [], `\n${problems.join("\n")}`);
console.log(`docs check: ${pages.length} pages, links, anchors, origins and script hashes are fine`);
