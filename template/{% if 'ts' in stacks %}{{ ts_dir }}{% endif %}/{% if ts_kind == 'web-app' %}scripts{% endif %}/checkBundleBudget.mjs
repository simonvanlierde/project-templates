// Fails when the largest JavaScript file in the build, gzipped, is over the
// budget. Run after `pnpm build`.
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import process from "node:process";
import { gzipSync } from "node:zlib";

// The budget, in gzipped bytes. Raise it on purpose, in its own commit.
const MAX_GZIP_BYTES = 100 * 1024;
const DIST_ASSETS_DIR = join(process.cwd(), "dist", "assets");

const jsAssets = readdirSync(DIST_ASSETS_DIR).filter((filename) => filename.endsWith(".js"));

if (jsAssets.length === 0) {
  throw new Error("No built JavaScript assets found in dist/assets");
}

const largestAsset = jsAssets
  .map((filename) => ({
    filename,
    gzipBytes: gzipSync(readFileSync(join(DIST_ASSETS_DIR, filename))).byteLength,
  }))
  .sort((left, right) => right.gzipBytes - left.gzipBytes)[0];

if (largestAsset.gzipBytes > MAX_GZIP_BYTES) {
  throw new Error(
    `Bundle budget exceeded: ${largestAsset.filename} gzip size ${largestAsset.gzipBytes} bytes exceeds ${MAX_GZIP_BYTES} bytes`,
  );
}

console.log(
  `Bundle budget OK: ${largestAsset.filename} gzip size ${largestAsset.gzipBytes} bytes within ${MAX_GZIP_BYTES} bytes`,
);
