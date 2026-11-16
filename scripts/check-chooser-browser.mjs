import assert from "node:assert/strict";
import AxeBuilder from "@axe-core/playwright";
import { chromium, expect } from "@playwright/test";

const urls = process.argv.slice(2);
assert.ok(urls.length, "Pass the built documentation base URLs");
const browser = await chromium.launch();
try {
  for (const url of urls) {
    for (const width of [320, 390, 1440]) {
      const context = await browser.newContext({ viewport: { width, height: 844 } });
      const external = new Set();
      const errors = [];
      await context.route("**/*", (route) => {
        const requested = new URL(route.request().url());
        if (requested.origin === new URL(url).origin) return route.continue();
        external.add(requested.href);
        return route.abort();
      });
      await context.addInitScript(() => {
        Object.defineProperty(navigator, "clipboard", { value: {
          writeText: (text) => {
            window.copiedText = text;
            if (window.copyMode === "denied") return Promise.reject(new Error("Permission denied"));
            if (window.copyMode === "pending") return new Promise((_, reject) => { window.rejectCopy = reject; });
            return Promise.resolve();
          },
        } });
      });
      const page = await context.newPage();
      page.on("pageerror", (error) => errors.push(error.message));
      const response = await page.goto(new URL("choose/", url).href);
      assert.ok(response?.ok(), `Chooser HTTP ${response?.status()}`);
      const result = page.locator("[data-chooser-result]");
      const title = page.locator("[data-chooser-title]");
      const command = page.locator("[data-chooser-command]");
      const language = page.getByLabel("Which language will you use?");
      const tool = page.getByLabel("What will it do?");
      const website = page.getByLabel("What kind of website?");
      // The answers are spelled out here, not read from chooser.mjs, so a swapped value fails.
      const recommends = async (expected, ...answers) => {
        await expect(title).toHaveText(expected);
        await expect(command).toContainText(answers.map((answer) => `--data '${answer}'`).join(" \\\n  "));
      };
      await expect(result).toBeHidden();
      await page.getByRole("radio", { name: "A reusable package" }).focus();
      await page.keyboard.press("Space");
      await expect(language).toBeVisible();
      await page.keyboard.press("Tab");
      await expect(language).toBeFocused();
      for (const [value, expected, kind] of [["python", "Python library", "python_kind=library"], ["ts", "TypeScript library", "ts_kind=library"], ["rust", "Rust library", "rust_kind=library"], ["go", "Go library", "go_kind=library"]]) {
        await language.selectOption(value);
        await recommends(expected, `stacks=[${value}]`, kind);
        await expect(page.locator("[data-chooser-announce]")).toHaveText(`Recommendation: ${expected}`);
      }
      await page.getByRole("radio", { name: "A tool or service" }).check();
      await expect(result).toBeHidden();
      await expect(page.locator("[data-chooser-announce]")).toHaveText("Now answer the next question.");
      await expect(language).toBeHidden();
      await expect(language).toBeDisabled();
      await tool.selectOption("app");
      await recommends("Go binary", "stacks=[go]", "go_kind=binary");
      await language.selectOption("rust");
      await recommends("Rust binary", "stacks=[rust]", "rust_kind=binary");
      await language.selectOption("ts");
      await recommends("TypeScript application", "stacks=[ts]", "ts_kind=app");
      await language.selectOption("python");
      await recommends("Python application", "stacks=[python]", "python_kind=app");
      await tool.selectOption("service");
      await recommends("Python web service with Docker", "stacks=[python,docker]", "python_kind=web-service", "docker_image=true");
      await tool.selectOption("compose");
      await recommends("Docker Compose project", "stacks=[docker]");
      await expect(command).not.toContainText("kind=");
      await page.getByRole("radio", { name: "Research or a data project" }).check();
      await expect(result).toBeHidden();
      const research = page.getByLabel("How will you work with data?");
      await research.selectOption("notebooks");
      await recommends("Python research project", "stacks=[python]", "python_kind=research");
      await research.selectOption("pipeline");
      await recommends("Python data pipeline", "stacks=[python]", "python_kind=data-pipeline");
      await page.getByRole("radio", { name: "A website", exact: true }).check();
      await expect(result).toBeHidden();
      await website.selectOption("static");
      await expect(page.locator("[data-chooser-static]")).toBeVisible();
      await expect(result).toBeHidden();
      await website.selectOption("app");
      await recommends("TypeScript web app", "stacks=[ts]", "ts_kind=web-app");
      await expect(page.locator("[data-chooser-static]")).toBeHidden();
      await expect(command).not.toContainText("user_data");
      const copy = page.locator("[data-chooser-copy]");
      const status = page.locator("[data-chooser-status]");
      await copy.click();
      await expect(status).toHaveText("Command copied.");
      await expect(copy).toHaveText("Copied");
      assert.equal(await page.evaluate(() => window.copiedText), await command.textContent());
      await page.evaluate(() => { window.copyMode = "denied"; });
      await copy.click();
      await expect(status).toContainText("Copy is unavailable");
      assert.equal(await page.evaluate(() => getSelection().toString()), await command.textContent());
      await page.evaluate(() => { window.copyMode = "pending"; });
      await copy.click();
      await website.selectOption("static");
      await page.evaluate(() => window.rejectCopy(new Error("Permission denied")));
      await expect(status).toBeEmpty();
      await website.selectOption("app");
      assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), `${width}px: horizontal overflow`);
      const { violations } = await new AxeBuilder({ page })
        .withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "wcag22aa", "best-practice"]).analyze();
      assert.deepEqual(violations.map(({ id, nodes }) => ({ id, targets: nodes.map((node) => node.target) })), [], `${width}px: accessibility violations`);
      const codeCopy = page.locator('.chooser .md-code__button[data-md-type="copy"]');
      await expect(codeCopy).toHaveCount(2);
      await expect(codeCopy.last()).toBeVisible();
      await expect(codeCopy.last()).toHaveAttribute("data-clipboard-target", /#__code_1 > code/);
      assert.deepEqual((await page.locator(".md-sidebar--primary > .md-sidebar__scrollwrap > .md-sidebar__inner > nav > ul > li > :is(a, label)").allTextContents()).slice(0, 3).map(text => text.trim()),
        ["Get started", "Guides", "Reference"]);
      await expect(page.locator(".md-footer__link--prev")).toContainText("Overview");
      await expect(page.locator(".md-footer__link--next")).toContainText("Use the template");
      await page.goto(new URL("usage/?h=Copier", url).href);
      await expect(page.locator(".md-content mark").first()).toBeVisible();
      assert.deepEqual([...external], [], "Chooser made external requests");
      assert.deepEqual(errors, [], "Chooser raised browser errors");
      console.log(`${url} (${width}px): chooser checks passed`);
      await context.close();
    }
    const context = await browser.newContext({ javaScriptEnabled: false });
    const page = await context.newPage();
    await page.goto(new URL("choose/", url).href);
    await expect(page.locator("[data-chooser-loading]")).toBeVisible();
    const guide = new URL(await page.locator("[data-chooser-loading] a").first().getAttribute("href"), page.url());
    assert.equal(guide.pathname, new URL("usage/", url).pathname);
    assert.equal(guide.hash, "#choosing-your-stacks");
    await expect(page.locator("[data-chooser]")).toBeHidden();
    await context.close();
  }
} finally {
  await browser.close();
}
