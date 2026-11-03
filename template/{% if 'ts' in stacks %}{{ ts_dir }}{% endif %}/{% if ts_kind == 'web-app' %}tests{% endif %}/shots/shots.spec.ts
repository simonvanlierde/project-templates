import { test } from "@playwright/test";
import { ROUTES } from "../e2e/routes";

// `just ts-shots` runs this: a full-page PNG of every route at phone and desktop
// width, in light and dark, saved as shots/<route>-<width>-<scheme>.png.
const WIDTHS = [390, 1440];
const SCHEMES = ["light", "dark"] as const;

for (const path of ROUTES) {
  for (const width of WIDTHS) {
    for (const colorScheme of SCHEMES) {
      test(`${path} at ${width} px, ${colorScheme}`, async ({ browser, baseURL }) => {
        const context = await browser.newContext({ baseURL, colorScheme, viewport: { width, height: 900 } });
        const page = await context.newPage();
        await page.goto(path);
        const name = path === "/" ? "index" : path.slice(1).replaceAll("/", "-");
        await page.screenshot({ fullPage: true, path: `shots/${name}-${width}-${colorScheme}.png` });
        await context.close();
      });
    }
  }
}
