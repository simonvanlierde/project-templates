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
/** The first h1 outside front matter and fenced code, ATX or setext, as markdown.mjs drops it. */
const titleOf = (filePath) => {
  const lines = readFileSync(resolve(process.cwd(), filePath), "utf8").split("\n");
  let fence;
  let i = 0;
  if (lines[0]?.trim() === "---") i = lines.indexOf("---", 1) + 1;
  for (; i < lines.length; i++) {
    const line = lines[i];
    const mark = line.match(/^ {0,3}(`{3,}|~{3,})/)?.[1];
    if (fence) {
      if (mark?.[0] === fence[0] && mark.length >= fence.length) fence = undefined;
    } else if (mark) fence = mark;
    else if (/^ {0,3}# /.test(line)) return line.replace(/^ {0,3}# |\s+#+\s*$/g, "").trim();
    else if (line.trim() && /^ {0,3}=+\s*$/.test(lines[i + 1] ?? "")) return line.trim();
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
