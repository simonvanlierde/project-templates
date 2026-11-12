import assert from "node:assert/strict";
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { profiles } from "../docs/assets/chooser.mjs";

const repo = fileURLToPath(new URL("../", import.meta.url));
const workflow = readFileSync(join(repo, ".github/workflows/ci.yml"), "utf8");
const version = process.env.COPIER_VERSION || workflow.match(/^  COPIER_VERSION: (\S+)$/m)?.[1];
assert.match(version ?? "", /^\d+\.\d+\.\d+$/, "Set COPIER_VERSION to the CI Copier pin.");
assert.ok(profiles.length > 0, "The chooser must have recommendations to render.");

const temporary = mkdtempSync(join(tmpdir(), "chooser-renders-"));
let passed = 0;
try {
  for (const ref of ["v0.14.0", "HEAD"]) {
    for (const profile of profiles) {
      const label = `${ref}: ${profile.id}`;
      const destination = join(temporary, `${ref}-${profile.id}`);
      const data = join(temporary, "answers.json");
      writeFileSync(data, JSON.stringify({
        ...profile.answers,
        project_name: "chooser-example",
        github_user: "example-org",
        author_name: "Example Author",
        author_email: "author@example.org",
        author_orcid: "",
        // The browser app asks its user about data; this fixture keeps none.
        user_data: "nothing",
      }));
      const args = [
        "--exclude-newer", "1 week", `copier@${version}`, "copy",
        "--defaults", "--quiet", "--vcs-ref", ref,
        "--data-file", data, repo, destination,
      ];
      const result = spawnSync("uvx", args, {
        cwd: repo,
        encoding: "utf8",
        env: { ...process.env, COPIER_SETTINGS_PATH: join(temporary, "settings.yml") },
      });
      if (result.error || result.status !== 0) {
        throw new Error(`${label} failed\nuvx ${args.map((arg) => JSON.stringify(arg)).join(" ")}\n${result.error?.message ?? ""}\n${result.stdout ?? ""}${result.stderr ?? ""}`);
      }
      const answers = readFileSync(join(destination, ".copier-answers.yml"), "utf8");
      for (const [key, value] of Object.entries(profile.answers)) {
        // HEAD stores the renamed answer; released commands still use the old name.
        const savedKey = key === "kind" && ref === "HEAD" ? "python_kind" : key;
        // These profile values are plain scalars or lists of stack names.
        const expected = Array.isArray(value)
          ? `${savedKey}:\n${value.map((item) => `- ${item}\n`).join("")}`
          : `${savedKey}: ${value}\n`;
        assert.ok(answers.includes(`\n${expected}`), `${label} did not retain ${key}=${JSON.stringify(value)}`);
      }
      assert.ok(profile.files.length > 0, `${label} must name generated files.`);
      for (const file of profile.files) {
        assert.ok(existsSync(join(destination, file)), `${label} did not generate ${file}`);
      }
      if (profile.answers.kind === "web-service") {
        assert.ok(existsSync(join(destination, "Dockerfile")), `${label} needs its Docker image.`);
        assert.ok(existsSync(join(destination, "compose.yaml")), `${label} needs Compose configuration.`);
      }
      passed += 1;
    }
    console.log(`chooser renders: ${profiles.length} passed at ${ref}`);
  }
  assert.equal(passed, profiles.length * 2);
} finally {
  rmSync(temporary, { recursive: true, force: true });
}
