import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import { copierCommand, profiles, recommend } from "../docs/assets/chooser.mjs";

// Copier ignores --data for a key it has no question for, so a renamed question must fail here.
// Computed answers (`when: false`) are not answers a user passes.
const questions = new Set(readFileSync(new URL("../copier.yml", import.meta.url), "utf8")
  .split(/^(?=[a-z])/m).filter((block) => !/^  when: false$/m.test(block)).map((block) => block.match(/^([a-z]\w*):/)?.[1]).filter(Boolean));

test("every recommendation uses only Copier questions", () => {
  assert.ok(questions.has("stacks") && !questions.has("compose_only"), [...questions].join(" "));
  for (const profile of profiles) {
    for (const key of Object.keys(profile.answers)) assert.ok(questions.has(key), `${profile.id}: ${key} is not a question in copier.yml`);
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
  assert.deepEqual(profile.answers, { stacks: ["python", "docker"], python_kind: "web-service", docker_image: true });
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
