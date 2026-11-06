// The Worker in front of the site's static files. A request for a file is served from
// the files without running this script; run_worker_first in wrangler.site.jsonc sends
// /api/* here first. `just site` runs the tests in index.test.mjs and leaves this folder
// out of the build, and wrangler bundles this file on every deploy.
export default {
  /**
   * @param {Request} request
   * @param {{ ASSETS: { fetch(request: Request): Promise<Response> } }} env
   * @returns {Promise<Response>}
   */
  async fetch(request, env) {
    const { pathname } = new URL(request.url);
    if (pathname === "/api/health") {
      return Response.json({ ok: true });
    }
    if (pathname.startsWith("/api/")) {
      return Response.json({ error: "Not found" }, { status: 404 });
    }
    return env.ASSETS.fetch(request);
  },
};
