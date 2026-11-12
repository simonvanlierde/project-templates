import assert from "node:assert/strict";
import test from "node:test";
import { copierCommand, profiles, recommend } from "../docs/assets/chooser.mjs";

test("every recommendation uses only released Copier answers", () => {
  const allowed = new Set(["stacks", "kind", "ts_kind", "rust_kind", "go_kind", "docker_image"]);
  for (const profile of profiles) {
    for (const key of Object.keys(profile.answers)) assert.ok(allowed.has(key), key);
    const command = copierCommand(profile);
    assert.ok(command.startsWith("copier copy --data "));
    assert.ok(command.endsWith(" gh:simonvanlierde/project-templates ."));
    assert.ok(!command.includes("--defaults"));
    assert.ok(!command.includes("user_data"));
    assert.ok(profile.files.length && profile.checks.length && profile.reason);
  }
});

test("a Python web service always includes its container", () => {
  const profile = recommend({ task: "tool", tool: "service", language: "rust" });
  assert.deepEqual(profile.answers, { stacks: ["python", "docker"], kind: "web-service", docker_image: true });
});

test("task changes ignore answers from hidden questions", () => {
  assert.equal(recommend({ task: "research", language: "go", tool: "service", research: "pipeline" }).id, "python-data-pipeline");
  assert.equal(recommend({ task: "website", language: "rust", website: "app", tool: "compose" }).id, "ts-web-app");
  assert.equal(recommend({ task: "package", language: "ts", tool: "service" }).id, "ts-library");
  assert.equal(recommend({ task: "tool", tool: "compose", language: "go" }).id, "docker-compose");
});

test("each offered language maps to the corresponding package or tool", () => {
  for (const language of ["python", "ts", "rust", "go"]) {
    assert.equal(recommend({ task: "package", language }).id, `${language}-library`);
    assert.equal(recommend({ task: "tool", tool: "app", language }).id, `${language}-${["rust", "go"].includes(language) ? "binary" : "app"}`);
  }
  assert.equal(recommend({ task: "research", research: "notebooks" }).id, "python-research");
});

test("incomplete, static-site and unrecognised answers do not invent a command", () => {
  for (const answers of [{}, { task: "package" }, { task: "website", website: "static" }, { task: "package", language: "$(touch bad)" }, { task: "tool", tool: "unknown", language: "python" }]) {
    assert.equal(recommend(answers), null);
  }
  assert.throws(() => copierCommand({ answers: { stacks: ["$(touch bad)"] } }));
});
