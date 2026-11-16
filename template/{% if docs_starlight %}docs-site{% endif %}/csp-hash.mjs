// An Astro integration that runs after the build. It gives every Starlight page a
// Content-Security-Policy meta tag that allows exactly the inline scripts the page has, by their
// sha256, and takes the 404 page out of search engines. Starlight writes data-theme="dark" into
// every page and its inline script corrects it; the attribute goes, so a reader without script
// gets the system's theme from docs.css.
// Astro's own `security.csp` leaves Starlight's `is:inline` scripts out of the hashes
// (withastro/astro#16664, closed as not planned) and writes its tag after the scripts in <head>,
// which a meta policy then does not cover (#18606), so the hashes come from the built files.
import { createHash } from "node:crypto";
import { readdirSync, readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

// A script with a `src` is the site's own file, which 'self' covers. A data block is not run.
const INLINE = /<script(?![^>]*\ssrc=)([^>]*)>([\s\S]*?)<\/script>/g;
const DATA = /\stype="(?:application\/json|application\/ld\+json|importmap)"/;

/** The sha256 source expressions of a page's inline scripts, each once. */
export function scriptHashes(html) {
  const hashes = new Set();
  for (const [, attrs, code] of html.matchAll(INLINE))
    if (!DATA.test(attrs)) hashes.add(`'sha256-${createHash("sha256").update(code).digest("base64")}'`);
  return [...hashes].sort();
}

/**
 * The pages' policy. Pagefind (the search) needs `connect-src 'self'` for its index and
 * 'wasm-unsafe-eval' for its WebAssembly; Astro and Starlight set `style` attributes, so styles may
 * be inline. Nothing is loaded from another origin.
 */
export function policy(html) {
  return [
    "default-src 'none'",
    `script-src 'self' 'wasm-unsafe-eval' ${scriptHashes(html).join(" ")}`.trim(),
    "style-src 'self' 'unsafe-inline'",
    "img-src 'self' data:",
    "font-src 'self'",
    "connect-src 'self'",
    "base-uri 'none'",
    "form-action 'none'",
  ].join("; ");
}

/** The page with its policy as a meta tag straight after the charset, before anything can run. */
export function withPolicy(html) {
  const tag = `<meta http-equiv="Content-Security-Policy" content="${policy(html)}"/>`;
  const clean = html.replace(/<meta http-equiv="Content-Security-Policy"[^>]*>/, "");
  return clean.replace(/(<meta charset="utf-8"\s*\/?>)/, `$1${tag}`);
}

const htmlFiles = (dir) =>
  readdirSync(dir, { recursive: true, withFileTypes: true })
    .filter((f) => f.isFile() && f.name.endsWith(".html"))
    .map((f) => resolve(f.parentPath, f.name));

/** Applies the policy to each Starlight page under `dir`. */
export function finish(dir) {
  for (const file of htmlFiles(dir)) {
    const html = readFileSync(file, "utf8");
    if (!html.includes('<meta name="generator" content="Starlight')) continue;
    let page = withPolicy(html).replace(/(<html[^>]*?) data-theme="dark"/, "$1");
    // GitHub Pages serves it for any address with no page, so it has no address of its own.
    if (file === resolve(dir, "404.html"))
      page = page
        .replace(/<link rel="canonical"[^>]*>|<meta property="og:url"[^>]*>/g, "")
        .replace("</title>", '</title><meta name="robots" content="noindex"/>');
    writeFileSync(file, page);
  }
}

export default function cspHash() {
  return {
    name: "csp-hash",
    hooks: { "astro:build:done": ({ dir }) => finish(fileURLToPath(dir)) },
  };
}
