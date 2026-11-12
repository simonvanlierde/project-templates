import assert from "node:assert/strict";
import AxeBuilder from "@axe-core/playwright";
import { chromium, expect } from "@playwright/test";

const requireCsp = process.argv.includes("--require-csp");
const urls = process.argv.slice(2).filter((arg) => arg !== "--require-csp");
assert.ok(urls.length, "Pass the built documentation URLs");
// The theme's palette radio has no size: its focus ring shows on the label after it.
const focusOnScreen = () => {
  const el = document.activeElement;
  const shown = el.matches("input.md-option") ? el.nextElementSibling : el;
  const rect = shown.getBoundingClientRect();
  return rect.left >= 0 && rect.right <= innerWidth && rect.bottom > rect.top && shown.checkVisibility({ visibilityProperty: true });
};
const browser = await chromium.launch();
try {
  if (requireCsp) {
    const page = await browser.newPage();
    await page.goto(new URL("usage/", urls[0]).href);
    // These published fragments must survive splits of the usage guide.
    const oldAnchors = "moving-an-app-off-cloudflare-pages pull-request-previews public-repos making-a-repo-public protecting-main the-github-about-box keeping-your-project-up-to-date hearing-about-new-releases the-update-app publishing signed-release-tags first-release static-site the-plain-tool-page hosting-on-a-worker social-card openssf-best-practices-badge before-you-register register osps-baseline-level-1 dependency-updates spelling-and-link-checks scientific-python-repo-review documentation-rules adopting-the-template-in-an-existing-repo adopting-the-template-in-an-existing-python-package adopting-the-template-in-an-existing-web-app adopting-the-template-in-an-existing-compose-only-repo production workers-hosting levels how-much-documentation moving-up-a-tier".split(" ");
    for (const id of oldAnchors) await expect(page.locator(`[id="${id}"]`), `old usage link #${id}`).toHaveCount(1);
    await page.close();
  }
  for (const url of urls) {
    for (const colorScheme of ["light", "dark"]) {
      const context = await browser.newContext({ colorScheme });
      const external = new Set();
      const cspViolations = [];
      const errors = [];
      await context.route("**/*", (route) => {
        const requested = new URL(route.request().url());
        if (requested.origin === new URL(url).origin) return route.continue();
        external.add(requested.href);
        return route.abort();
      });
      const page = await context.newPage();
      page.on("pageerror", (error) => errors.push(error.message));
      page.setDefaultTimeout(10_000);
      await page.exposeFunction("reportCspViolation", (violation) => cspViolations.push(violation));
      await page.addInitScript(() => {
        document.addEventListener("securitypolicyviolation", (event) => {
          window.reportCspViolation(`${event.effectiveDirective}: ${event.blockedURI}`);
        });
      });
      for (const width of [320, 390, 1440]) {
        await page.setViewportSize({ width, height: 844 });
        const response = await page.goto(url);
        const policy = page.locator('meta[http-equiv="Content-Security-Policy"]');
        if (requireCsp) {
          await expect(policy).toHaveCount(1);
        }
        assert.ok(response?.ok(), `${url}: HTTP ${response?.status()}`);
        assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth),
          `${url} (${width}px): horizontal overflow`);
        const menu = page.locator('.md-header button[data-docs-toggle="__drawer"]');
        const search = width < 1220
          ? page.locator('.md-header button[data-docs-toggle="__search"]')
          : page.locator(".md-search__button");
        if (width < 1220) {
          await page.keyboard.press("Tab");
          await expect(page.locator(".md-skip")).toBeFocused();
          // An announcement bar's link and dismiss button come before the header.
          for (let tab = 0; tab < 4 && !(await menu.evaluate((el) => el === document.activeElement)); tab++) {
            await page.keyboard.press("Tab");
            assert.ok(await page.evaluate(focusOnScreen), `${url}: Tab entered invisible closed navigation`);
          }
          await expect(menu).toBeFocused();
          for (const key of ["Enter", "Space"]) {
            await page.keyboard.press(key);
            await expect(page.locator("#__drawer")).toBeChecked();
            await expect(page.locator(".md-sidebar--primary a[href]").first()).toBeFocused();
            await page.keyboard.press("Escape");
            await expect(page.locator("#__drawer")).not.toBeChecked();
            await expect(menu).toBeFocused();
          }
          // Past the header, focus reaches the page, not the links of the closed drawer.
          for (let tab = 0; tab < 4; tab++) {
            await page.keyboard.press("Tab");
            assert.ok(await page.evaluate(focusOnScreen), `${url}: Tab after the header entered closed navigation`);
          }
        }
        // The theme's palette radio has no box: Tab to it and expect an outline on its visible label.
        const palette = page.locator("input.md-option").first();
        if (await palette.count()) {
          await palette.focus();
          await page.keyboard.press("Shift+Tab");
          await page.keyboard.press("Tab");
          await expect(palette).toBeFocused();
          assert.notEqual(await page.evaluate(() => getComputedStyle(
            document.activeElement.parentElement.querySelector("label:not([hidden])")).outlineStyle), "none",
          `${url} (${width}px): focused palette control has no outline`);
        }
        await search.focus();
        await page.keyboard.press("Enter");
        const input = page.getByRole("combobox", { name: "Search", exact: true });
        await expect(input).toBeFocused();
        assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth),
          `${url} (${width}px): search causes horizontal overflow`);
        await input.fill("reference");
        await expect(page.getByRole("listbox", { name: "Search results" }).getByRole("option").first()).toBeVisible();
        await page.keyboard.press("Escape");
        await expect(input).not.toBeVisible();
        if (width < 1220) {
          await search.focus();
          await page.keyboard.press("Space");
          await expect(input).toBeFocused();
          await page.keyboard.press("Escape");
          await menu.focus();
          await page.keyboard.press("Enter");
        }
        {
          const { violations } = await new AxeBuilder({ page })
            .withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "wcag22aa", "best-practice"])
            .analyze();
          assert.deepEqual(violations.map(({ id, nodes }) => ({ id, targets: nodes.map((node) => node.target) })),
            [], `${url} (${width}px, ${colorScheme}): accessibility violations`);
        }
        if (width < 1220) await page.keyboard.press("Escape");
        const copy = page.locator("button.md-code__button").first();
        if (await copy.count()) {
          await context.grantPermissions(["clipboard-read", "clipboard-write"]);
          await page.evaluate(() => navigator.clipboard.writeText(""));
          const target = await copy.getAttribute("data-clipboard-target");
          const expected = (await page.locator(target).innerText()).trimEnd();
          await copy.click();
          await expect.poll(() => page.evaluate(() => navigator.clipboard.readText())).toBe(expected);
        }
        assert.deepEqual(errors, [], `${url}: JavaScript errors`);
        assert.deepEqual(cspViolations, [], `${url}: Content-Security-Policy violations`);
        if (await policy.count()) {
          await page.evaluate(() => {
            const script = document.createElement("script");
            script.textContent = "window.unapprovedInlineScript = true";
            document.head.append(script);
          });
          await expect.poll(() => cspViolations.length).toBe(1);
          assert.equal(await page.evaluate(() => window.unapprovedInlineScript), undefined,
            `${url}: CSP allowed an unapproved inline script`);
          assert.deepEqual(cspViolations.splice(0), ["script-src-elem: inline"]);
        }
        assert.deepEqual([...external], [], `${url}: external requests during load or local search`);
        console.log(`${url} (${width}px, ${colorScheme}): docs checks passed`);
      }
      const destination = await page.locator('.md-sidebar--primary a.md-nav__link[href]').evaluateAll((links) =>
        links.find((link) => new URL(link.href).pathname !== location.pathname && new URL(link.href).origin === location.origin)?.getAttribute("href"));
      assert.ok(destination, `${url}: no local navigation link`);
      const link = page.locator(`.md-sidebar--primary a.md-nav__link[href="${destination}"]`).first();
      await Promise.all([page.waitForURL(new URL(destination, page.url()).href), link.click()]);
      assert.deepEqual(errors, [], `${url}: JavaScript errors after navigation`);
      assert.deepEqual(cspViolations, [], `${url}: CSP violations after navigation`);
      await context.close();
    }
  }
} finally {
  await browser.close();
}
