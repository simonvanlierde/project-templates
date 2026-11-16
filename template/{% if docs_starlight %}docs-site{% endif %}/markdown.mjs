// Sätteri plugins for the Markdown in docs/, which stays the only source:
// - docLinks: a link to another page of docs/ goes to its Starlight page, and a link to any other
//   file of the repository goes to GitHub, so `usage.md#setup` and `../README.md` both work in the
//   editor and on the site. A link to a file that does not exist stops the build. The first h1 is
//   dropped, as the page's title is Starlight's.
// - docBoxes: a wide table or code block scrolls in its own box, which a keyboard can reach, named
//   by the heading above it so each landmark name is unique on the page.
import { existsSync, statSync } from "node:fs";
import { dirname, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(fileURLToPath(import.meta.url), "../..");
const DOCS = resolve(ROOT, "docs");

/** The file's path when it is Markdown under docs/, else undefined. */
const inDocs = (fileURL) => {
  const path = fileURL && fileURLToPath(fileURL);
  return path?.startsWith(DOCS + sep) ? path : undefined;
};

const rewrite = (url, from, { base, repo }) => {
  if (/^([a-z][a-z0-9+.-]*:|#|\/)/i.test(url)) return url;
  const [, path, tail = ""] = url.match(/^([^#?]*)([#?].*)?$/);
  const target = resolve(dirname(from), path);
  if (!existsSync(target)) throw new Error(`${relative(ROOT, from)}: the link ${url} points to a file that does not exist`);
  if (target.startsWith(DOCS + sep) && target.endsWith(".md")) {
    const page = relative(DOCS, target)
      .split(sep)
      .join("/")
      .replace(/\.md$/, "")
      .replace(/(^|\/)(readme|index)$/i, "$1")
      .replace(/\/$/, "");
    return `${base}/${page ? `${page}/` : ""}${tail}`;
  }
  const kind = statSync(target).isDirectory() ? "tree" : "blob";
  return `${repo}/${kind}/main/${relative(ROOT, target).split(sep).join("/")}${tail}`;
};

export const docLinks =
  (options) =>
  ({ fileURL }) => {
    const from = inDocs(fileURL);
    if (!from) return;
    let dropped = false;
    const go = (node, ctx) => ctx.setProperty(node, "url", rewrite(node.url, from, options));
    const h1 = (node, ctx) => {
      if (node.depth !== 1 || dropped) return;
      dropped = true;
      ctx.removeNode(node);
    };
    return { name: "doc-links", link: go, definition: go, heading: h1 };
  };

export const docBoxes = ({ fileURL }) => {
  if (!inDocs(fileURL)) return;
  let heading = "";
  const uses = new Map();
  const label = (kind) => {
    const key = heading ? `${kind}: ${heading}` : kind;
    const n = (uses.get(key) ?? 0) + 1;
    uses.set(key, n);
    return n > 1 ? `${key} (${n})` : key;
  };
  return {
    name: "doc-boxes",
    element: [
      {
        filter: ["h1", "h2", "h3", "h4", "h5", "h6"],
        visit(node, ctx) {
          heading = ctx.textContent(node).replace(/\s+/g, " ").trim();
        },
      },
      {
        filter: ["pre"],
        visit(node, ctx) {
          ctx.setProperty(node, "tabIndex", 0);
          ctx.setProperty(node, "role", "region");
          ctx.setProperty(node, "ariaLabel", label("Code"));
        },
      },
      {
        filter: ["table"],
        visit(node, ctx) {
          ctx.wrapNode(node, {
            type: "element",
            tagName: "div",
            properties: { className: ["scroll"], tabIndex: 0, role: "region", ariaLabel: label("Table") },
            children: [],
          });
        },
      },
    ],
  };
};
