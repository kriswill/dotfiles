// URL-hash integration at the App level: location.hash is handed to
// decodeHash raw (decoded exactly once), and malformed hashes must not throw
// during mount — pre-decoding in App used to crash component setup whenever a
// once-decoded hash still contained a literal '%'.
import { afterEach, describe, expect, spyOn, test } from "bun:test";
import { flushSync, mount, unmount } from "svelte";
import App from "./App.svelte";
import { buildModel } from "./data";
import { createVizState } from "./state.svelte";
import { cfg, makeStub, node } from "./test-helpers";

const model = () =>
  buildModel({
    nodes: [node("nvim/architecture", "Reference", "Arch")],
    edges: [],
    // The '%' in this path is the double-decode regression case: decoding its
    // (once-encoded) hash a second time throws URIError.
    files: { "docs/50%.md": { html: "", md: "# hi", lines: 1, size: 5, date: "", lang: "markdown", refs: [] } },
    cfg: cfg(),
  });

let cleanup: (() => void) | null = null;
const mountApp = (viz: ReturnType<typeof createVizState>) => {
  const app = mount(App, { target: document.body, props: { viz, createScene: () => makeStub() } });
  cleanup = () => unmount(app);
  flushSync();
};
afterEach(() => {
  cleanup?.();
  cleanup = null;
  document.body.innerHTML = "";
  location.hash = "";
  localStorage.clear();
});

describe("App hash handling", () => {
  test("percent-encoded hash decodes exactly once and is never rewritten", () => {
    location.hash = "#f/docs/50%25.md";
    const viz = createVizState(model());
    mountApp(viz);
    expect(viz.sel).toEqual({ kind: "file", path: "docs/50%.md" });
    // The URL must survive as shared: a canonicalizing rewrite would push a
    // history entry (Back trap) and produce a hash that no longer decodes.
    expect(location.hash).toBe("#f/docs/50%25.md");
  });

  test("back-navigation to an encoded entry re-applies it without rewriting", () => {
    location.hash = "#f/docs/50%25.md";
    const viz = createVizState(model());
    mountApp(viz);
    viz.selectConcept("nvim/architecture");
    flushSync();
    expect(location.hash).toBe("#c/nvim/architecture");
    location.hash = "#f/docs/50%25.md"; // simulate Back
    window.dispatchEvent(new Event("hashchange"));
    flushSync();
    expect(viz.sel).toEqual({ kind: "file", path: "docs/50%.md" });
    expect(location.hash).toBe("#f/docs/50%25.md");
  });

  test("malformed percent hash mounts without throwing and selects nothing", () => {
    location.hash = "#c/50%";
    const viz = createVizState(model());
    mountApp(viz);
    expect(viz.sel).toEqual({ kind: "none" });
  });

  test("UI-selecting a '%' path writes a decodable hash that survives the echo hashchange", () => {
    const viz = createVizState(model());
    mountApp(viz);
    viz.selectFile("docs/50%.md");
    flushSync();
    expect(location.hash).toBe("#f/docs/50%25.md");
    // Browsers fire hashchange asynchronously after the write-effect's hash
    // assignment — the echo must re-decode to the same selection, not clear it.
    window.dispatchEvent(new Event("hashchange"));
    flushSync();
    expect(viz.sel).toEqual({ kind: "file", path: "docs/50%.md" });
  });

  test("hashchange applies a new selection", () => {
    const viz = createVizState(model());
    mountApp(viz);
    location.hash = "#c/nvim/architecture";
    window.dispatchEvent(new Event("hashchange"));
    flushSync();
    expect(viz.sel).toEqual({ kind: "concept", id: "nvim/architecture" });
  });
});

describe("App filter persistence", () => {
  test("filter changes land in the URL without touching the selection part", () => {
    const viz = createVizState(model());
    mountApp(viz);
    viz.selectConcept("nvim/architecture");
    flushSync();
    viz.toggleType("Reference");
    viz.query = "arch";
    flushSync();
    expect(location.hash).toBe("#c/nvim/architecture?hide=Reference&q=arch");
    viz.setIsolate(1);
    flushSync();
    expect(location.hash).toBe("#c/nvim/architecture?hide=Reference&q=arch&isolate=1");
    viz.setFacet("platform", "macos");
    flushSync();
    expect(location.hash).toBe("#c/nvim/architecture?hide=Reference&q=arch&isolate=1&platform=macos");
    viz.setFilters([], "");
    flushSync();
    expect(location.hash).toBe("#c/nvim/architecture");
  });

  test("a deep link with filters applies them on mount", () => {
    location.hash = "#c/nvim/architecture?hide=Reference&q=arch";
    const viz = createVizState(model());
    mountApp(viz);
    expect(viz.sel).toEqual({ kind: "concept", id: "nvim/architecture" });
    expect([...viz.hidden]).toEqual(["Reference"]);
    expect(viz.query).toBe("arch");
    expect(location.hash).toBe("#c/nvim/architecture?hide=Reference&q=arch"); // applied, never rewritten
  });

  test("a deep link with an isolate param applies it on mount", () => {
    location.hash = "#c/nvim/architecture?hide=Reference&q=arch&isolate=1";
    const viz = createVizState(model());
    mountApp(viz);
    expect(viz.sel).toEqual({ kind: "concept", id: "nvim/architecture" });
    expect(viz.isolateDepth).toBe(1);
    expect(location.hash).toBe("#c/nvim/architecture?hide=Reference&q=arch&isolate=1"); // applied, never rewritten
  });

  test("a deep link combining a file selection with hide=/q= still applies both (isolate stays 0, not a concept)", () => {
    location.hash = "#f/docs/50%25.md?hide=Reference&q=arch";
    const viz = createVizState(model());
    mountApp(viz);
    expect(viz.sel).toEqual({ kind: "file", path: "docs/50%.md" });
    expect([...viz.hidden]).toEqual(["Reference"]);
    expect(viz.query).toBe("arch");
    expect(viz.isolateDepth).toBe(0);
    expect(location.hash).toBe("#f/docs/50%25.md?hide=Reference&q=arch"); // applied, never rewritten
  });

  test("a canonical ?platform= deep link applies the facet lens on mount (any selection kind)", () => {
    location.hash = "#c/nvim/architecture?platform=linux";
    const viz = createVizState(model());
    mountApp(viz);
    expect(viz.sel).toEqual({ kind: "concept", id: "nvim/architecture" });
    expect(viz.facetSel.platform).toBe("linux");
    expect(location.hash).toBe("#c/nvim/architecture?platform=linux"); // applied, never rewritten
  });

  test("legacy ?os= deep link: applies the lens, hash is NOT rewritten on load, next interaction re-encodes as platform=", () => {
    location.hash = "#c/nvim/architecture?os=linux";
    const viz = createVizState(model());
    mountApp(viz);
    expect(viz.sel).toEqual({ kind: "concept", id: "nvim/architecture" });
    expect(viz.facetSel.platform).toBe("linux");
    expect(location.hash).toBe("#c/nvim/architecture?os=linux"); // applied, never rewritten on load
    viz.setFacet("platform", "macos"); // any subsequent interaction re-encodes canonically
    flushSync();
    expect(location.hash).toBe("#c/nvim/architecture?platform=macos");
  });

  test("a platform-only change amends the URL in place (replaceState, no selection churn)", () => {
    const viz = createVizState(model());
    mountApp(viz);
    viz.selectConcept("nvim/architecture");
    flushSync();
    // Spy AFTER the selection settles so we observe only the filter-only write.
    const replace = spyOn(history, "replaceState");
    const push = spyOn(history, "pushState");
    viz.setFacet("platform", "macos");
    flushSync();
    expect(location.hash).toBe("#c/nvim/architecture?platform=macos");
    // The load-bearing guarantee: a filter-only change amends the current entry
    // (replaceState) rather than pushing a new one (the documented Back trap).
    expect(replace).toHaveBeenCalledTimes(1);
    expect(push).not.toHaveBeenCalled();
    replace.mockRestore();
    push.mockRestore();
    viz.setFacet("platform", "all");
    flushSync();
    expect(location.hash).toBe("#c/nvim/architecture");
  });

  test("selection navigation keeps active filters; Back to a bare hash clears them", () => {
    const viz = createVizState(model());
    mountApp(viz);
    viz.toggleType("Reference");
    flushSync();
    expect(location.hash).toBe("#?hide=Reference");
    viz.selectConcept("nvim/architecture");
    flushSync();
    expect(location.hash).toBe("#c/nvim/architecture?hide=Reference");
    viz.setIsolate(2);
    flushSync();
    expect(location.hash).toBe("#c/nvim/architecture?hide=Reference&isolate=2");
    location.hash = "#c/nvim/architecture"; // simulate Back to an unfiltered entry
    window.dispatchEvent(new Event("hashchange"));
    flushSync();
    expect(viz.hidden.size).toBe(0);
    expect(viz.isolateDepth).toBe(0);
    expect(viz.sel).toEqual({ kind: "concept", id: "nvim/architecture" });
  });
});
