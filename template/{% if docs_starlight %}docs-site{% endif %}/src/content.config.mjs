// The docs collection is the repository's docs/ folder: plain Markdown that needs no front matter.
// The page's title is its first heading (markdown.mjs drops that heading from the body), and a
// README.md is its folder's index page.

import { defineCollection } from "astro:content";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { i18nLoader } from "@astrojs/starlight/loaders";
import { docsSchema, i18nSchema } from "@astrojs/starlight/schema";
import { glob } from "astro/loaders";

const base = resolve(import.meta.dirname, "../../docs");
const files = glob({
  pattern: "**/*.md",
  base,
  generateId: ({ entry }) => entry.replace(/\.md$/, "").replace(/(^|\/)readme$/i, "$1index"),
});
/** The first ATX h1 outside a fenced code block, as markdown.mjs drops it. */
const titleOf = (filePath) => {
  let fence;
  for (const line of readFileSync(resolve(process.cwd(), filePath), "utf8").split("\n")) {
    const mark = line.match(/^ {0,3}(`{3,}|~{3,})/)?.[1];
    if (fence) {
      if (mark?.[0] === fence[0] && mark.length >= fence.length) fence = undefined;
    } else if (mark) fence = mark;
    else if (/^ {0,3}# /.test(line)) return line.replace(/^ {0,3}# |\s+#+\s*$/g, "").trim();
  }
};

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
