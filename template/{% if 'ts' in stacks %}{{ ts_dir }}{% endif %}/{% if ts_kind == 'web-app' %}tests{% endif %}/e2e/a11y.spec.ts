import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";
import { ROUTES } from "./routes";

// WCAG 2.0, 2.1 and 2.2 at levels A and AA, plus axe's best-practice rules (landmarks,
// one h1). Any violation fails, whatever its impact.
const TAGS = ["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "wcag22aa", "best-practice"];

for (const colorScheme of ["light", "dark"] as const) {
  test.describe(`accessibility (${colorScheme})`, () => {
    test.use({ colorScheme });

    for (const path of ROUTES) {
      test(`${path} has no WCAG A or AA or best-practice violations`, async ({ page }) => {
        await page.goto(path);
        await expect(page.getByRole("main")).toBeVisible();

        const { violations } = await new AxeBuilder({ page }).withTags(TAGS).analyze();

        // One line per violation, then the selector of each element it hit. The
        // comparison is on the rule ids alone, so the diff stays short.
        const report = violations
          .map((v) => `${v.id} (${v.impact}): ${v.help}\n${v.nodes.map((n) => `  ${n.target.join(" ")}`).join("\n")}`)
          .join("\n");
        expect(
          violations.map((v) => v.id),
          report,
        ).toEqual([]);
      });
    }
  });
}
