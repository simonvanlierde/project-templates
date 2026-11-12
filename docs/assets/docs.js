// Native buttons activate the theme's existing checkbox state on every input method.
(() => {
  function toggleButton(id) {
    const label = document.querySelector(`.md-header label[for="${id}"]`);
    if (!label) return null;
    const button = document.createElement("button");
    button.type = "button";
    button.className = label.className;
    button.dataset.docsToggle = id;
    button.append(...label.childNodes);
    button.addEventListener("click", () => document.getElementById(id).click());
    label.replaceWith(button);
    return button;
  }

  const menu = toggleButton("__drawer");
  const search = toggleButton("__search");
  search?.setAttribute("aria-haspopup", "dialog");
  const drawer = document.querySelector("#__drawer");
  const sidebar = document.querySelector(".md-sidebar--primary");
  if (!menu || !sidebar) return;
  sidebar.id = "docs-navigation";
  menu.setAttribute("aria-controls", sidebar.id);

  function syncDrawer() {
    menu.setAttribute("aria-expanded", String(drawer.checked));
    if (drawer.checked) {
      sidebar.querySelector("a[href]")?.focus();
    } else if (sidebar.contains(document.activeElement)) {
      menu.focus();
    }
  }
  drawer.addEventListener("change", syncDrawer);
  syncDrawer();
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && drawer.checked && !document.querySelector("#__search")?.checked) {
      drawer.click();
      menu.focus();
    }
  });
})();
