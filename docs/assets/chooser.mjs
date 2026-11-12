const profile = (id, title, reason, answers, files, checks) =>
  Object.freeze({ id, title, reason, answers, files, checks });

export const profiles = Object.freeze([
  profile("python-library", "Python library", "Use this for a package that other Python code imports. It starts with a src/ layout and tests for the public API.", { stacks: ["python"], python_kind: "library" }, ["pyproject.toml", "src/", "tests/"], ["just py-sync", "just check"]),
  profile("python-app", "Python application", "Use this for a packaged Python tool that you run yourself, without publishing it as a library.", { stacks: ["python"], python_kind: "app" }, ["pyproject.toml", "src/", "tests/"], ["just py-sync", "just check"]),
  profile("python-research", "Python research project", "Use this for analysis and experiments. The package sits alongside notebooks/ and data/ so reusable code has a home outside notebooks.", { stacks: ["python"], python_kind: "research" }, ["pyproject.toml", "notebooks/", "data/"], ["just py-sync", "just check"]),
  profile("python-data-pipeline", "Python data pipeline", "Use this when fetching, building and validating data are repeatable steps. The starter tracks sources and separates those operations.", { stacks: ["python"], python_kind: "data-pipeline" }, ["sources.toml", "src/", "data/"], ["just py-sync", "just check"]),
  profile("python-web-service", "Python web service with Docker", "Use this for an HTTP API. The FastAPI starter includes /health and OpenTelemetry, and ships as a container.", { stacks: ["python", "docker"], python_kind: "web-service", docker_image: true }, ["Dockerfile", "compose.yaml", "src/"], ["just py-sync", "just check"]),
  profile("ts-library", "TypeScript library", "Use this for a Node package that other code imports. It builds JavaScript and type declarations into dist/.", { stacks: ["ts"], ts_kind: "library" }, ["package.json", "tsconfig.json", "src/"], ["just ts-sync", "just check"]),
  profile("ts-app", "TypeScript application", "Use this for a Node application that builds into dist/ without publishing a package.", { stacks: ["ts"], ts_kind: "app" }, ["package.json", "tsconfig.json", "src/"], ["just ts-sync", "just check"]),
  profile("ts-web-app", "TypeScript web app", "Use this for an interactive browser app. It starts with Vite, React or Preact, Playwright tests and deployment to Cloudflare Workers.", { stacks: ["ts"], ts_kind: "web-app" }, ["vite.config.ts", "src/App.tsx", "wrangler.jsonc"], ["just ts-sync", "just check"]),
  profile("rust-library", "Rust library", "Use this for a crate that other Rust code imports. It starts with a documented public API and doctests.", { stacks: ["rust"], rust_kind: "library" }, ["Cargo.toml", "src/lib.rs"], ["just rs-sync", "just check"]),
  profile("rust-binary", "Rust binary", "Use this for a standalone Rust program. It starts with src/main.rs and the checks for a binary crate.", { stacks: ["rust"], rust_kind: "binary" }, ["Cargo.toml", "src/main.rs"], ["just rs-sync", "just check"]),
  profile("go-library", "Go library", "Use this for a package that other Go code imports. It starts at the module root with an Example test.", { stacks: ["go"], go_kind: "library" }, ["go.mod", "example_test.go"], ["just go-sync", "just check"]),
  profile("go-binary", "Go binary", "Use this for a standalone Go program. It starts with package main at the module root.", { stacks: ["go"], go_kind: "binary" }, ["go.mod", "main.go"], ["just go-sync", "just check"]),
  profile("docker-compose", "Docker Compose project", "Use this to run existing container images together. It adds Compose configuration without creating a language package or building your own image.", { stacks: ["docker"] }, ["compose.yaml", ".env.example"], ["just check"]),
]);

export function recommend({ task, language, tool, research, website } = {}) {
  let id;
  if (task === "package" && ["python", "ts", "rust", "go"].includes(language)) id = `${language}-library`;
  if (task === "tool") {
    if (tool === "service") id = "python-web-service";
    if (tool === "compose") id = "docker-compose";
    if (tool === "app" && ["python", "ts", "rust", "go"].includes(language)) {
      id = `${language}-${["rust", "go"].includes(language) ? "binary" : "app"}`;
    }
  }
  if (task === "research" && research === "notebooks") id = "python-research";
  if (task === "research" && research === "pipeline") id = "python-data-pipeline";
  if (task === "website" && website === "app") id = "ts-web-app";
  return profiles.find((entry) => entry.id === id) ?? null;
}

export function copierCommand(selected) {
  if (!profiles.includes(selected)) throw new TypeError("Choose a known project profile.");
  const flags = Object.entries(selected.answers).map(([key, value]) => {
    const answer = Array.isArray(value) ? `[${value.join(",")}]` : String(value);
    return `--data '${key}=${answer}'`;
  });
  return `copier copy ${flags.join(" ")} gh:simonvanlierde/project-templates .`;
}

const form = globalThis.document?.querySelector("[data-chooser]");
if (form) {
  const root = form.closest("[data-chooser-root]");
  const result = root.querySelector("[data-chooser-result]");
  const staticHelp = root.querySelector("[data-chooser-static]");
  const command = root.querySelector("[data-chooser-command]");
  const status = root.querySelector("[data-chooser-status]");
  const copy = root.querySelector("[data-chooser-copy]");
  let currentCommand = "";

  function update() {
    const task = form.elements.task.value;
    const tool = form.elements.tool.value;
    const showLanguage = task === "package" || (task === "tool" && tool === "app");
    for (const group of form.querySelectorAll("[data-question]")) {
      const shown = group.dataset.question === "language" ? showLanguage : group.dataset.question === task;
      group.hidden = !shown;
      group.disabled = !shown;
    }
    const answers = Object.fromEntries(new FormData(form));
    const selected = recommend(answers);
    result.hidden = !selected;
    staticHelp.hidden = !(answers.task === "website" && answers.website === "static");
    status.textContent = "";
    currentCommand = selected ? copierCommand(selected) : "";
    if (!selected) return;
    root.querySelector("[data-chooser-title]").textContent = selected.title;
    root.querySelector("[data-chooser-reason]").textContent = selected.reason;
    for (const [attribute, values] of [["files", selected.files], ["checks", selected.checks]]) {
      const list = root.querySelector(`[data-chooser-${attribute}]`);
      list.replaceChildren(...values.map((value) => {
        const item = document.createElement("li");
        const code = document.createElement("code");
        code.textContent = value;
        item.append(code);
        return item;
      }));
    }
    command.textContent = currentCommand;
    status.textContent = `Recommendation: ${selected.title}`;
  }

  form.addEventListener("change", update);
  form.addEventListener("submit", (event) => event.preventDefault());
  copy.addEventListener("click", async () => {
    const text = currentCommand;
    try {
      await navigator.clipboard.writeText(text);
      if (currentCommand === text) status.textContent = "Command copied.";
    } catch {
      if (currentCommand !== text) return;
      const range = document.createRange();
      range.selectNodeContents(command);
      const selection = window.getSelection();
      selection.removeAllRanges();
      selection.addRange(range);
      status.textContent = "Copy is unavailable here. The command is selected; copy it with your keyboard or touch menu.";
    }
  });
  root.querySelector("[data-chooser-loading]").hidden = true;
  form.hidden = false;
  update();
}
