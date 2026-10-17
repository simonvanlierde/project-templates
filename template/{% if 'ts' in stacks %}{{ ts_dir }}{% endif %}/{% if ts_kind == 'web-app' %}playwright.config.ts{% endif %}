import { defineConfig, devices } from "@playwright/test";

const ci = Boolean(process.env.CI);
// vite preview's default port. --strictPort fails the run if it is taken,
// instead of serving on another port the tests never reach.
const url = "http://localhost:4173";

export default defineConfig({
  testDir: "tests/e2e",
  forbidOnly: ci,
  retries: ci ? 2 : 0,
  reporter: ci ? [["github"], ["html", { open: "never" }]] : [["list"], ["html", { open: "never" }]],
  use: { baseURL: url, trace: "on-first-retry" },
  projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"] } }],
  // The tests run against the production build, which is what Cloudflare Pages serves.
  webServer: {
    command: "pnpm build && pnpm preview --strictPort",
    url,
    reuseExistingServer: !ci,
    timeout: 120_000,
  },
});
