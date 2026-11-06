// The Worker in front of the static assets in dist/. A request for a file is served
// from the assets without running this script; run_worker_first in wrangler.jsonc sends
// /api/* here first. Add a binding (KV, D1, a secret) in wrangler.jsonc and to Env.
export interface Env {
  ASSETS: Fetcher;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const { pathname } = new URL(request.url);
    if (pathname === "/api/health") {
      return Response.json({ ok: true });
    }
    if (pathname.startsWith("/api/")) {
      return Response.json({ error: "Not found" }, { status: 404 });
    }
    return env.ASSETS.fetch(request);
  },
} satisfies ExportedHandler<Env>;
