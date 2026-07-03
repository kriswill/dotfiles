// Component smoke tests under happy-dom (svelte mount() verified working
// there — see docs/svelt/learnings.md 2026-07-02).
import { afterEach, describe, expect, test } from "bun:test";
import { flushSync, mount, unmount } from "svelte";
import ConceptList from "./ConceptList.svelte";
import { buildModel } from "./data";
import DetailPanel from "./DetailPanel.svelte";
import Legend from "./Legend.svelte";
import Search from "./Search.svelte";
import { createVizState } from "./state.svelte";
import { node } from "./test-helpers";
import Tooltip from "./Tooltip.svelte";

const model = () =>
  buildModel({
    nodes: [
      node("a", "Decision", "Alpha", {
        desc: "the alpha decision",
        fm: { type: "Decision", resource: "scripts/okf/viz.ts", description: "uses scripts/okf/viz.ts" },
        body: "## Context\nsee [beta](b.md)",
      }),
      node("b", "Pattern", "Beta"),
    ],
    edges: [{ s: "a", t: "b" }],
    files: {
      "scripts/okf/viz.ts": { html: "<span class=\"tok-k\">const</span>", lines: 3, size: 2048, date: "2026-01-01", lang: "ts", refs: ["a"] },
      "docs/notes.md": {
        html: "",
        md: "# Notes\nsee [beta](../knowledge/b.md) and [viz](../scripts/okf/viz.ts)",
        lines: 2,
        size: 64,
        date: "2026-01-01",
        lang: "markdown",
        refs: ["a"],
      },
    },
  });

let cleanup: (() => void) | null = null;
const mountC = (Component: unknown, props: Record<string, unknown>) => {
  const app = mount(Component as never, { target: document.body, props: props as never });
  cleanup = () => unmount(app);
  flushSync();
};
afterEach(() => {
  cleanup?.();
  cleanup = null;
  document.body.innerHTML = "";
});

describe("Legend", () => {
  test("renders type rows with counts; click toggles visibility class", () => {
    const state = createVizState(model());
    mountC(Legend, { viz: state });
    const rows = [...document.querySelectorAll(".leg")];
    // TYPE_ORDER slots Pattern before Decision; happy-dom keeps template whitespace.
    expect(rows.map((r) => r.textContent?.replace(/\s+/g, " ").trim())).toEqual(["Pattern 1", "Decision 1"]);
    (rows[0] as HTMLElement).click();
    flushSync();
    expect(document.querySelector(".leg")!.classList.contains("off")).toBe(true);
    expect(state.hidden.has("Pattern")).toBe(true);
  });
});

describe("ConceptList", () => {
  test("lists visible concepts sorted; click selects", () => {
    const state = createVizState(model());
    mountC(ConceptList, { viz: state });
    expect([...document.querySelectorAll("#list a")].map((a) => a.textContent)).toEqual(["Alpha", "Beta"]);
    expect(document.querySelectorAll("#list a .dot")).toHaveLength(2); // type color dot per entry
    state.query = "beta";
    flushSync();
    expect([...document.querySelectorAll("#list a")].map((a) => a.textContent)).toEqual(["Beta"]);
    (document.querySelector("#list a") as HTMLElement).click();
    flushSync();
    expect(state.sel).toEqual({ kind: "concept", id: "b" });
  });

  test("focused concept is marked, also while its file view is open", () => {
    const state = createVizState(model());
    mountC(ConceptList, { viz: state });
    expect(document.querySelector("#list a.selected")).toBeNull();
    state.selectConcept("a");
    flushSync();
    const sel = document.querySelector("#list a.selected")!;
    expect(sel.textContent).toBe("Alpha");
    expect(sel.getAttribute("aria-current")).toBe("true");
    state.selectFile("scripts/okf/viz.ts"); // file view keeps the referrer marked
    flushSync();
    expect(document.querySelector("#list a.selected")!.textContent).toBe("Alpha");
    state.clearSelection();
    flushSync();
    expect(document.querySelector("#list a.selected")).toBeNull();
  });
});

describe("Search", () => {
  test("input binds to state.query", () => {
    const state = createVizState(model());
    mountC(Search, { viz: state });
    const input = document.getElementById("q") as HTMLInputElement;
    input.value = "alpha";
    input.dispatchEvent(new Event("input", { bubbles: true }));
    flushSync();
    expect(state.query).toBe("alpha");
  });
});

describe("Tooltip", () => {
  test("renders hovered node at position", () => {
    const state = createVizState(model());
    mountC(Tooltip, { viz: state });
    expect(document.getElementById("tip")).toBeNull();
    state.hover = { i: 0, x: 40, y: 60 };
    flushSync();
    const tip = document.getElementById("tip")!;
    expect(tip.textContent).toContain("Alpha");
    expect(tip.textContent).toContain("the alpha decision");
    expect(tip.style.left).toBe("40px");
    expect(tip.style.top).toBe("60px");
  });
});

describe("ThemeSlider", () => {
  test("slider drives viz.setTheme and shows the stop name", async () => {
    const { default: ThemeSlider } = await import("./ThemeSlider.svelte");
    localStorage.removeItem("okfVizTheme"); // isolate from other suites
    document.documentElement.removeAttribute("style");
    const state = createVizState(model());
    mountC(ThemeSlider, { viz: state });
    const input = document.getElementById("theme-slider") as HTMLInputElement;
    expect(input.value).toBe("0");
    expect(input.max).toBe("3");
    expect(document.querySelector(".theme-bar .name")!.textContent).toBe("light");
    input.value = "2";
    input.dispatchEvent(new Event("input", { bubbles: true }));
    flushSync();
    expect(state.themeIndex).toBe(2);
    expect(document.querySelector(".theme-bar .name")!.textContent).toBe("dark");
    localStorage.removeItem("okfVizTheme");
    document.documentElement.removeAttribute("style");
  });
});

describe("DetailPanel", () => {
  const stage = () => {
    const el = document.createElement("main");
    document.body.appendChild(el);
    return el;
  };

  test("hidden when nothing selected", () => {
    const state = createVizState(model());
    mountC(DetailPanel, { viz: state, stageEl: stage() });
    expect(document.getElementById("panel")).toBeNull();
  });

  test("concept view: title, chip, fm resource link, markdown body, backlinks", () => {
    const state = createVizState(model());
    state.selectConcept("a");
    mountC(DetailPanel, { viz: state, stageEl: stage() });
    const panel = document.getElementById("panel")!;
    expect(panel.querySelector("h2")!.textContent).toBe("Alpha");
    expect(panel.querySelector(".bar .crumb")!.textContent).toBe("Alpha"); // locked header crumb
    expect(panel.querySelector(".bar .close")).not.toBeNull();
    expect(panel.querySelector(".chip")!.textContent).toContain("Decision");
    expect(panel.querySelector('td a[data-file="scripts/okf/viz.ts"]')).not.toBeNull();
    expect(panel.querySelector("#body-md h3")!.textContent).toBe("Context");
    expect(panel.querySelector('#body-md a[data-node="b"]')).not.toBeNull();
    const backlinks = [...panel.querySelectorAll(".backlinks")];
    expect(backlinks[0]!.textContent).toContain("Beta"); // Links to
    expect(backlinks[1]!.textContent).toContain("none"); // Cited by
  });

  test("markdown files render as documents, not source views", () => {
    const state = createVizState(model());
    state.selectConcept("a");
    state.selectFile("docs/notes.md");
    mountC(DetailPanel, { viz: state, stageEl: stage() });
    const panel = document.getElementById("panel")!;
    expect(panel.querySelector(".bar .back")!.textContent).toContain("Alpha"); // locked header back link
    const body = panel.querySelector("#body-md.md-doc")!;
    expect(body.querySelector("h3")!.textContent).toBe("Notes");
    expect(body.querySelector('a[data-node="b"]')).not.toBeNull(); // file-relative into knowledge/
    expect(body.querySelector('a[data-file="scripts/okf/viz.ts"]')).not.toBeNull();
    expect(panel.querySelector("pre.src")).toBeNull();
    expect(panel.querySelector("table.fm")).toBeNull();
  });

  test("directory view: resource dir link, listing, file click-through", () => {
    const dirModel = buildModel({
      nodes: [
        node("packages/ccglass", "Sub-flake", "ccglass", {
          fm: { type: "Sub-flake", resource: "flakes/ccglass/" },
          body: "consumed via [flake](../../flakes/ccglass/)",
        }),
      ],
      edges: [],
      files: {
        "flakes/ccglass/flake.nix": { html: "", lines: 12, size: 512, date: "2026-01-02", lang: "nix", refs: ["packages/ccglass"] },
      },
      dirs: {
        "flakes/ccglass": {
          files: ["flakes/ccglass/flake.nix", "flakes/ccglass/big.bin"],
          dirs: ["flakes/ccglass/sub"],
          date: "2026-01-02",
          refs: ["packages/ccglass"],
        },
        "flakes/ccglass/sub": { files: [], dirs: [], date: "2026-01-02", refs: ["packages/ccglass"] },
      },
    });
    const state = createVizState(dirModel);
    state.selectConcept("packages/ccglass");
    mountC(DetailPanel, { viz: state, stageEl: stage() });
    const panel = document.getElementById("panel")!;
    // fm resource cell links to the directory (body dir links resolve too).
    const resLink = panel.querySelector('td a[data-dir="flakes/ccglass"]') as HTMLElement;
    expect(resLink.textContent).toBe("flakes/ccglass/");
    expect(panel.querySelector('#body-md a[data-dir="flakes/ccglass"]')).not.toBeNull();
    resLink.click();
    flushSync();
    expect(state.sel).toEqual({ kind: "dir", path: "flakes/ccglass" });
    expect(panel.querySelector("h2")!.textContent).toBe("ccglass/");
    expect(panel.querySelector(".chip")!.textContent).toContain("directory");
    expect(panel.querySelector(".back")!.textContent).toContain("ccglass"); // back to the concept
    const rows = [...panel.querySelectorAll(".dir-list li")];
    expect(rows).toHaveLength(3); // subdir first, then files
    expect(panel.querySelector('.dir-list a[data-dir="flakes/ccglass/sub"]')!.textContent).toBe("sub/");
    expect(rows[2]!.textContent).toContain("big.bin"); // unembedded: listed, unlinked
    expect(rows[2]!.textContent).toContain("not embedded");
    (panel.querySelector('.dir-list a[data-file="flakes/ccglass/flake.nix"]') as HTMLElement).click();
    flushSync();
    expect(state.sel).toEqual({ kind: "file", path: "flakes/ccglass/flake.nix" });
  });

  test("file view via delegation: back-link, meta, source; close clears", () => {
    const state = createVizState(model());
    state.selectConcept("a");
    mountC(DetailPanel, { viz: state, stageEl: stage() });
    (document.querySelector('#panel a[data-file="scripts/okf/viz.ts"]') as HTMLElement).click();
    flushSync();
    const panel = document.getElementById("panel")!;
    expect(state.sel).toEqual({ kind: "file", path: "scripts/okf/viz.ts" });
    expect(panel.querySelector("h2")!.textContent).toBe("viz.ts");
    expect(panel.querySelector(".back")!.textContent).toContain("Alpha");
    expect(panel.querySelector(".src .tok-k")!.textContent).toBe("const");
    expect(panel.textContent).toContain("2.0 KB");
    (panel.querySelector(".back") as HTMLElement).click();
    flushSync();
    expect(state.sel).toEqual({ kind: "concept", id: "a" });
    (document.querySelector("#panel .close") as HTMLElement).click();
    flushSync();
    expect(state.sel).toEqual({ kind: "none" });
    expect(document.getElementById("panel")).toBeNull();
  });
});
