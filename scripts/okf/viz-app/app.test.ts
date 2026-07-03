// URL-hash integration at the App level: location.hash is handed to
// decodeHash raw (decoded exactly once), and malformed hashes must not throw
// during mount — pre-decoding in App used to crash component setup whenever a
// once-decoded hash still contained a literal '%'.
import { afterEach, describe, expect, test } from "bun:test";
import { flushSync, mount, unmount } from "svelte";
import App from "./App.svelte";
import { buildModel } from "./data";
import { createVizState } from "./state.svelte";
import { makeStub, node } from "./test-helpers";

const model = () =>
  buildModel({
    nodes: [node("nvim/architecture", "Reference", "Arch")],
    edges: [],
    // The '%' in this path is the double-decode regression case: decoding its
    // (once-encoded) hash a second time throws URIError.
    files: { "docs/50%.md": { html: "", md: "# hi", lines: 1, size: 5, date: "", lang: "markdown", refs: [] } },
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
