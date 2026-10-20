import { expect, test } from "@playwright/test";
import { ROUTES } from "./routes";

// vite preview sends no headers, so apply the Content-Security-Policy from the
// built _headers file, the one Cloudflare Pages serves, and fail on any violation.
test("the built app runs under its own Content-Security-Policy", async ({ page }) => {
  const headersFile = await (await page.request.get("/_headers")).text();
  const policy = headersFile.match(/Content-Security-Policy:\s*(.+)/)?.[1];
  expect(policy).toContain("script-src 'self';");
  for (const name of [
    "X-Frame-Options",
    "X-Content-Type-Options",
    "Referrer-Policy",
    "Cross-Origin-Opener-Policy",
    "Cross-Origin-Resource-Policy",
    "Permissions-Policy",
    "Strict-Transport-Security",
  ]) {
    expect(headersFile, name).toMatch(new RegExp(`^\\s+${name}:`, "m"));
  }
  await page.route("**/*", async (route) => {
    const response = await route.fetch();
    await route.fulfill({
      response,
      headers: { ...response.headers(), "content-security-policy": policy as string },
    });
  });
  const violations: string[] = [];
  await page.exposeFunction("reportViolation", (text: string) => violations.push(text));
  await page.addInitScript(() => {
    document.addEventListener("securitypolicyviolation", (event) => {
      (window as unknown as { reportViolation: (t: string) => void }).reportViolation(
        `${event.violatedDirective} ${event.blockedURI}`,
      );
    });
  });

  for (const path of ROUTES) {
    const response = await page.goto(path);
    expect(response?.headers()["content-security-policy"]).toBe(policy);
    await expect(page.getByRole("main")).toBeVisible();
  }
  expect(violations).toEqual([]);

  // An injected inline <script> is reported, so the listener works and the
  // policy really blocks inline scripts.
  await page.evaluate(() => {
    const script = document.createElement("script");
    script.textContent = "void 0";
    document.head.append(script);
  });
  await expect.poll(() => violations).toEqual([expect.stringMatching(/^script-src-elem inline/)]);
});
