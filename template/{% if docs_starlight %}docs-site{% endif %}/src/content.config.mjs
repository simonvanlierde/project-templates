// The docs collection is the repository's docs/ folder: plain Markdown that needs no front matter.
// The page's title is its first heading (markdown.mjs drops that heading from the body), and a
// README.md is its folder's index page.
import { i18nLoader } from "@astrojs/starlight/loaders";
import { docsSchema, i18nSchema } from "@astrojs/starlight/schema";
import { defineCollection } from "astro:content";
import { glob } from "astro/loaders";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const base = resolve(import.meta.dirname, "../../docs");
const files = glob({
  pattern: "**/*.md",
  base,
  generateId: ({ entry }) => entry.replace(/\.md$/, "").replace(/(^|\/)readme$/i, "$1index"),
});
const titleOf = (filePath) => readFileSync(resolve(process.cwd(), filePath), "utf8").match(/^# (.+)$/m)?.[1].trim();

const loader = {
  ...files,
  load: (ctx) =>
    files.load({
      ...ctx,
      parseData: ({ id, filePath, data, ...rest }) =>
        ctx.parseData({ ...rest, id, filePath, data: { title: titleOf(filePath) ?? id, ...data } }),
    }),
};

export const collections = {
  docs: defineCollection({ loader, schema: docsSchema() }),
  // Empty: the docs are one language. Declared so Starlight finds the collection.
  i18n: defineCollection({ loader: i18nLoader(), schema: i18nSchema() }),
};
