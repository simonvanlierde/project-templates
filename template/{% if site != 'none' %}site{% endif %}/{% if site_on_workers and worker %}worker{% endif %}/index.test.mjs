import assert from "node:assert/strict";
import { test } from "node:test";
import worker from "./index.mjs";

// Stands in for the assets binding: answers every request with the same file.
const env = { ASSETS: { fetch: async () => new Response("asset") } };
const get = (path) => worker.fetch(new Request(`https://example.org${path}`), env);

test("answers /api/health", async () => {
  const response = await get("/api/health");
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { ok: true });
});

test("answers 404 for an unknown API route", async () => {
  assert.equal((await get("/api/nope")).status, 404);
});

test("hands every other path to the files", async () => {
  assert.equal(await (await get("/about")).text(), "asset");
});
