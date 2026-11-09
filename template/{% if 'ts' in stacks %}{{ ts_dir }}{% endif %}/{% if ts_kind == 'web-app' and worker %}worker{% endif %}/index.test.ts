// @vitest-environment node
import { describe, expect, it } from "vitest";
import worker, { type Env } from "./index.ts";

// Stands in for the assets binding: answers every request with the same file.
const env = { ASSETS: { fetch: async () => new Response("asset") } } as unknown as Env;
const get = (path: string) => worker.fetch(new Request(`https://example.org${path}`), env);

describe("worker", () => {
  it("answers /api/health", async () => {
    const response = await get("/api/health");
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ ok: true });
  });

  it("answers 404 for an unknown API route", async () => {
    expect((await get("/api/nope")).status).toBe(404);
  });

  it("hands every other path to the assets", async () => {
    expect(await (await get("/about")).text()).toBe("asset");
  });
});
