import { expect, test } from "@playwright/test";
import { ROUTES } from "./routes";

// WCAG 1.4.10 Reflow: at 320 CSS px wide, content must not scroll sideways.
test.use({ viewport: { width: 320, height: 640 } });

for (const path of ROUTES) {
  test(`${path} does not scroll sideways at 320 px`, async ({ page }) => {
    await page.goto(path);
    await expect(page.getByRole("main")).toBeVisible();
    const { scrollWidth, innerWidth } = await page.evaluate(() => ({
      scrollWidth: document.documentElement.scrollWidth,
      innerWidth: window.innerWidth,
    }));
    expect(scrollWidth).toBeLessThanOrEqual(innerWidth);
  });
}
