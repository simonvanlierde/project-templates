// Loads each built page in Chromium, light and dark, at a phone and a desktop width, and fails on an
// axe violation, a request to another origin, a Content-Security-Policy violation or a page script
// error. It also checks that "/" opens the search. `just docs-check` runs it after `just docs`.

import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { createServer } from "node:http";
import { extname, resolve } from "node:path";
import AxeBuilder from "@axe-core/playwright";
import { chromium } from "playwright";
import config from "./astro.config.mjs";

const dist = resolve(import.meta.dirname, "../_docs");
const base = (config.base ?? "").replace(/\/$/, "");
const types = {
  ".html": "text/html",
  ".css": "text/css",
  ".js": "text/javascript",
  ".json": "application/json",
  ".svg": "image/svg+xml",
  ".wasm": "application/wasm",
  ".xml": "application/xml",
  ".png": "image/png",
};

// GitHub Pages in miniature: the site under its base, a folder's index.html, and 404.html for the rest.
const server = createServer((req, res) => {
  const path = decodeURIComponent(new URL(req.url, "http://x").pathname);
  const rel = path.startsWith(base) ? path.slice(base.length) : null;
  let file = rel === null ? undefined : resolve(dist, `.${rel}`);
  if (file && existsSync(file) && !extname(file)) file = resolve(file, "index.html");
  const found = file?.startsWith(dist) && existsSync(file) && extname(file);
  const target = found ? file : resolve(dist, "404.html");
  res.writeHead(found ? 200 : 404, { "content-type": types[extname(target)] ?? "application/octet-stream" });
  res.end(readFileSync(target));
});
await new Promise((ok) => server.listen(0, "127.0.0.1", ok));
const origin = `http://127.0.0.1:${server.address().port}`;

const sitemap = readFileSync(resolve(dist, "sitemap-0.xml"), "utf8");
const urls = [...sitemap.matchAll(/<loc>[^/]*\/\/[^/]+(\/[^<]*)<\/loc>/g)].map((m) => `${origin}${m[1]}`);
urls.push(`${origin}${base}/no-such-page/`);
assert.ok(urls.length > 1, "The sitemap lists no pages");

// Starlight's search button is named "Search" and shows "Search Ctrl K": the name holds the label,
// and the key hint is not part of it, so that experimental rule is off.
const browser = await chromium.launch();
const problems = [];
try {
  for (const colorScheme of ["light", "dark"]) {
    const context = await browser.newContext({ colorScheme });
    await context.route("**/*", (route) => {
      if (new URL(route.request().url()).origin === origin) return route.continue();
      problems.push(`request to ${route.request().url()}`);
      return route.abort();
    });
    const page = await context.newPage();
    page.on("pageerror", (error) => problems.push(`script error: ${error.message}`));
    await page.addInitScript(() => {
      document.addEventListener("securitypolicyviolation", (e) =>
        console.error(`CSP ${e.effectiveDirective}: ${e.blockedURI}`),
      );
    });
    // The 404 page's own address answers 404, which the browser logs.
    page.on(
      "console",
      (m) =>
        m.type() === "error" &&
        !m.location().url.endsWith("/no-such-page/") &&
        problems.push(`console: ${m.text()} ${m.location().url}`),
    );
    for (const width of [400, 1440]) {
      await page.setViewportSize({ width, height: 900 });
      for (const url of urls) {
        const where = `${url} (${colorScheme}, ${width}px)`;
        await page.goto(url);
        if (await page.evaluate(() => document.documentElement.scrollWidth > innerWidth))
          problems.push(`${where}: horizontal overflow`);
        const { violations } = await new AxeBuilder({ page }).disableRules(["label-content-name-mismatch"]).analyze();
        for (const v of violations)
          problems.push(`${where}: axe ${v.id} (${v.nodes.length}): ${v.help}: ${v.nodes[0].html.slice(0, 160)}`);
      }
    }
    await page.setViewportSize({ width: 1440, height: 900 });
    await page.goto(urls[0]);
    await page.keyboard.press("/");
    await page
      .locator("dialog[open]")
      .waitFor({ timeout: 5000 })
      .catch(() => problems.push(`${colorScheme}: "/" did not open the search`));
    await context.close();
  }
} finally {
  await browser.close();
  server.close();
}
assert.deepEqual(problems, [], `\n${[...new Set(problems)].join("\n")}`);
console.log(`docs axe: ${urls.length} pages, light and dark, 400 and 1440 px: no violations`);
