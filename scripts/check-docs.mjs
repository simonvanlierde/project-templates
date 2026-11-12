import assert from "node:assert/strict";
import AxeBuilder from "@axe-core/playwright";
import { chromium, expect } from "@playwright/test";

const urls = process.argv.slice(2);
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
  for (const url of urls) {
    for (const colorScheme of ["light", "dark"]) {
      const context = await browser.newContext({ colorScheme });
      const external = new Set();
      await context.route("**/*", (route) => {
        const requested = new URL(route.request().url());
        if (requested.origin === new URL(url).origin) return route.continue();
        external.add(requested.href);
        return route.abort();
      });
      const page = await context.newPage();
      page.setDefaultTimeout(10_000);
      for (const width of [320, 390, 1440]) {
        await page.setViewportSize({ width, height: 844 });
        const response = await page.goto(url);
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
        if (width !== 320) {
          const { violations } = await new AxeBuilder({ page })
            .withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "wcag22aa", "best-practice"])
            .analyze();
          assert.deepEqual(violations.map(({ id, nodes }) => ({ id, targets: nodes.map((node) => node.target) })),
            [], `${url} (${width}px, ${colorScheme}): accessibility violations`);
        }
        assert.deepEqual([...external], [], `${url}: external requests during load or local search`);
        console.log(`${url} (${width}px, ${colorScheme}): docs checks passed`);
      }
      await context.close();
    }
  }
} finally {
  await browser.close();
}
