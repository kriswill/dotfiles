import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { buildModel, type ConceptTree } from "./data";
import { createVizState } from "./state.svelte";
import { cfg, node } from "./test-helpers";

const model = () =>
  buildModel({
    nodes: [
      node("a", "Decision", "Alpha", { desc: "first decision", fm: { tags: ["stow", "symlinks"] } }),
      node("b", "Pattern", "Beta"),
      node("c", "Decision", "Gamma"),
    ],
    edges: [{ s: "a", t: "b" }],
    files: { "scripts/okf/viz.ts": { html: "", lines: 1, size: 10, date: "", lang: "ts", refs: ["a"] } },
    dirs: { "flakes/ccglass": { files: ["flakes/ccglass/flake.nix"], dirs: [], date: "2026-01-01", refs: ["a"] } },
  });

beforeEach(() => localStorage.clear());

describe("selection", () => {
  test("selectConcept sets sel, fly, scene index", () => {
    const s = createVizState(model());
    s.selectConcept("a");
    expect(s.sel).toEqual({ kind: "concept", id: "a" });
    expect(s.fly).toBe(true);
    expect(s.selectedConcept?.title).toBe("Alpha");
    expect(s.sceneSelectedIndex).toBe(0);
  });

  test("unknown ids are ignored", () => {
    const s = createVizState(model());
    s.selectConcept("nope");
    s.selectFile("nope.ts");
    s.selectDir("nope");
    expect(s.sel).toEqual({ kind: "none" });
  });

  test("file view keeps scene emphasis and back-link on last concept", () => {
    const s = createVizState(model());
    s.selectConcept("a");
    s.selectFile("scripts/okf/viz.ts");
    expect(s.sel).toEqual({ kind: "file", path: "scripts/okf/viz.ts" });
    expect(s.selectedConcept).toBeNull();
    expect(s.backConcept?.id).toBe("a");
    expect(s.sceneSelectedIndex).toBe(0);
  });

  test("dir view keeps scene emphasis and back-link on last concept", () => {
    const s = createVizState(model());
    s.selectConcept("a");
    s.selectDir("flakes/ccglass");
    expect(s.sel).toEqual({ kind: "dir", path: "flakes/ccglass" });
    expect(s.selectedConcept).toBeNull();
    expect(s.backConcept?.id).toBe("a");
    expect(s.sceneSelectedIndex).toBe(0);
  });

  test("clearSelection resets everything", () => {
    const s = createVizState(model());
    s.selectConcept("a");
    s.clearSelection();
    expect(s.sel).toEqual({ kind: "none" });
    expect(s.backConcept).toBeNull();
    expect(s.sceneSelectedIndex).toBeNull();
  });
});

describe("filtering", () => {
  test("toggleType hides and shows", () => {
    const s = createVizState(model());
    s.toggleType("Decision");
    expect(s.visible(s.model.nodes[0]!)).toBe(false);
    expect(s.visibleSorted.map((n) => n.id)).toEqual(["b"]);
    s.toggleType("Decision");
    expect(s.visibleSorted).toHaveLength(3);
  });

  test("query matches title/id/desc/type/tags, case-insensitive", () => {
    const s = createVizState(model());
    s.query = "ALPHA";
    expect(s.visibleSorted.map((n) => n.id)).toEqual(["a"]);
    s.query = "pattern";
    expect(s.visibleSorted.map((n) => n.id)).toEqual(["b"]);
    s.query = "first decision";
    expect(s.visibleSorted.map((n) => n.id)).toEqual(["a"]);
    s.query = "symlink";
    expect(s.visibleSorted.map((n) => n.id)).toEqual(["a"]);
    s.query = "";
    expect(s.visibleSorted).toHaveLength(3);
  });

  test("visibleSorted sorts by title", () => {
    const s = createVizState(model());
    expect(s.visibleSorted.map((n) => n.title)).toEqual(["Alpha", "Beta", "Gamma"]);
  });

  test("showAllTypes / hideAllTypes", () => {
    const s = createVizState(model());
    s.hideAllTypes();
    expect(s.visibleSorted).toHaveLength(0);
    expect(s.hidden.size).toBe(2); // Decision + Pattern
    s.showAllTypes();
    expect(s.visibleSorted).toHaveLength(3);
  });

  test("soloType isolates, re-solo restores, solo elsewhere switches", () => {
    const s = createVizState(model());
    s.soloType("Decision");
    expect(s.visibleSorted.map((n) => n.id)).toEqual(["a", "c"]);
    s.soloType("Pattern"); // switch the solo, not additive
    expect(s.visibleSorted.map((n) => n.id)).toEqual(["b"]);
    s.soloType("Pattern"); // solo again = restore all
    expect(s.visibleSorted).toHaveLength(3);
  });

  test("setFilters replaces hidden set and query wholesale", () => {
    const s = createVizState(model());
    s.toggleType("Pattern");
    s.setFilters(["Decision"], "gamma");
    expect([...s.hidden]).toEqual(["Decision"]);
    expect(s.query).toBe("gamma");
    s.setFilters([], "");
    expect(s.hidden.size).toBe(0);
    expect(s.visibleSorted).toHaveLength(3);
  });

  test("toggleGroup/soloGroup act across every type in the group, leaving other groups untouched", () => {
    const groupModel = () =>
      buildModel({
        nodes: [
          node("decisions/x", "Decision", "X"),
          node("patterns/y", "Pattern", "Y"),
          node("modules/z", "Darwin Module", "Z"),
        ],
        edges: [],
        cfg: cfg(),
      });
    const s = createVizState(groupModel());
    s.toggleGroup("Knowledge"); // Decision + Pattern
    expect(s.visibleSorted.map((n) => n.id)).toEqual(["modules/z"]);
    s.toggleGroup("Knowledge");
    expect(s.visibleSorted).toHaveLength(3);

    s.soloGroup("Knowledge"); // hides every other group's types (System here)
    expect(s.visibleSorted.map((n) => n.id).sort()).toEqual(["decisions/x", "patterns/y"]);
    s.soloGroup("Knowledge"); // solo again restores all
    expect(s.visibleSorted).toHaveLength(3);
  });

  test("toggleGroup escalates a partially-hidden group to fully hidden, never un-hides", () => {
    const groupModel = () =>
      buildModel({
        nodes: [
          node("decisions/x", "Decision", "X"),
          node("patterns/y", "Pattern", "Y"),
          node("modules/z", "Darwin Module", "Z"),
        ],
        edges: [],
        cfg: cfg(),
      });
    const s = createVizState(groupModel());
    s.toggleType("Decision"); // mixed state: Decision hidden, Pattern visible, both in Knowledge
    s.toggleGroup("Knowledge");
    expect(s.hidden.has("Decision")).toBe(true); // stays hidden
    expect(s.hidden.has("Pattern")).toBe(true); // escalates to fully hidden, not un-hidden
  });

  test("soloGroup hides every other group when 3+ groups are present", () => {
    const threeGroupModel = () =>
      buildModel({
        nodes: [
          node("decisions/x", "Decision", "X"),
          node("modules/z", "Darwin Module", "Z"),
          node("packages/p", "Nix Package", "P"),
        ],
        edges: [],
        cfg: cfg(),
      });
    const s = createVizState(threeGroupModel());
    s.soloGroup("Knowledge");
    expect(s.hidden.has("Darwin Module")).toBe(true);
    expect(s.hidden.has("Nix Package")).toBe(true);
    expect(s.hidden.has("Decision")).toBe(false);
    s.soloGroup("Knowledge"); // restore
    expect(s.hidden.size).toBe(0);
  });

  test("toggleGroup on an absent group name is a no-op", () => {
    const s = createVizState(model());
    s.toggleGroup("NoSuchGroup");
    expect(s.hidden.size).toBe(0);
  });

  test("soloGroup on an absent group name hides everything (soloing an empty set shows nothing)", () => {
    const s = createVizState(model());
    s.soloGroup("NoSuchGroup");
    expect(s.visibleSorted).toHaveLength(0);
  });

  test("hiddenMatchCount counts search hits suppressed by type toggles", () => {
    const s = createVizState(model());
    expect(s.hiddenMatchCount).toBe(0);
    s.toggleType("Decision");
    expect(s.hiddenMatchCount).toBe(0); // no query — nothing "swallowed"
    s.query = "gamma";
    expect(s.visibleSorted).toHaveLength(0);
    expect(s.hiddenMatchCount).toBe(1);
    s.showAllTypes();
    expect(s.hiddenMatchCount).toBe(0);
    expect(s.visibleSorted.map((n) => n.id)).toEqual(["c"]);
  });
});

describe("neighborhood isolation", () => {
  const isoModel = () =>
    buildModel({
      nodes: [
        node("a", "Decision", "Alpha"),
        node("b", "Pattern", "Beta"),
        node("c", "Pattern", "Gamma"),
        node("d", "Pattern", "Delta"),
      ],
      edges: [
        { s: "a", t: "b" },
        { s: "b", t: "c" },
      ],
    });

  test("setIsolate(1) restricts visibleSorted to the selection's 1-hop neighborhood", () => {
    const s = createVizState(isoModel());
    s.selectConcept("a");
    s.setIsolate(1);
    expect(s.visibleSorted.map((n) => n.id).sort()).toEqual(["a", "b"]);
  });

  test("setIsolate(2) reaches one more hop", () => {
    const s = createVizState(isoModel());
    s.selectConcept("a");
    s.setIsolate(2);
    expect(s.visibleSorted.map((n) => n.id).sort()).toEqual(["a", "b", "c"]);
  });

  test("isolation ANDs with type-hidden filters", () => {
    const s = createVizState(isoModel());
    s.selectConcept("a");
    s.setIsolate(2);
    s.toggleType("Pattern");
    expect(s.visibleSorted.map((n) => n.id)).toEqual(["a"]); // b, c are Pattern, hidden by type too
  });

  test("clearSelection resets isolation", () => {
    const s = createVizState(isoModel());
    s.selectConcept("a");
    s.setIsolate(2);
    s.clearSelection();
    expect(s.isolateDepth).toBe(0);
    expect(s.visibleSorted).toHaveLength(4);
  });

  test("isolation is sticky across concept-to-concept navigation, re-rooting on the new selection", () => {
    const s = createVizState(isoModel());
    s.selectConcept("a");
    s.setIsolate(1);
    s.selectConcept("c");
    expect(s.isolateDepth).toBe(1);
    expect(s.visibleSorted.map((n) => n.id).sort()).toEqual(["b", "c"]);
  });

  test("setIsolate clamps invalid depths to 0", () => {
    const s = createVizState(isoModel());
    s.selectConcept("a");
    s.setIsolate(3 as never);
    expect(s.isolateDepth).toBe(0);
  });

  test("hiddenMatchCount ignores matches suppressed only by isolation, not type", () => {
    const s = createVizState(isoModel());
    s.selectConcept("a");
    s.setIsolate(1); // neighborhood = {a, b}; c and d are isolation-hidden, no type hidden
    s.query = "gamma"; // matches c, which is Pattern (not type-hidden) but outside the 1-hop neighborhood
    expect(s.visibleSorted).toHaveLength(0); // c matches but isn't in the neighborhood
    expect(s.hiddenMatchCount).toBe(0); // hiddenMatchCount only tracks type-hidden suppression
  });

  test("setFilters accepts an isolate depth, defaults to 0 for existing 2-arg calls", () => {
    const s = createVizState(isoModel());
    s.selectConcept("a");
    s.setFilters(["Pattern"], "");
    expect(s.isolateDepth).toBe(0);
    s.setFilters([], "", 2);
    expect(s.isolateDepth).toBe(2);
  });

  test("opening a file/dir view suspends isolation (anchored on selectedConcept, not focusedConcept)", () => {
    const s = createVizState(model()); // a-b edge, plus a file and a dir to select
    s.selectConcept("a");
    s.setIsolate(1);
    expect(s.visibleSorted.map((n) => n.id).sort()).toEqual(["a", "b"]);
    s.selectFile("scripts/okf/viz.ts");
    expect(s.isolateDepth).toBe(1); // sticky: not reset by selectFile
    expect(s.neighborIds).toBeNull(); // but inactive: selectedConcept is null while a file view is open
    expect(s.visibleSorted).toHaveLength(3); // isolation stops restricting the list
    s.selectDir("flakes/ccglass");
    expect(s.neighborIds).toBeNull();
    expect(s.visibleSorted).toHaveLength(3);
  });
});

describe("pinned concept listing", () => {
  // a—b—c chain plus disconnected d (titles: Alpha, Beta, Gamma, Delta).
  const listModel = () =>
    buildModel({
      nodes: [
        node("a", "Decision", "Alpha"),
        node("b", "Pattern", "Beta"),
        node("c", "Pattern", "Gamma"),
        node("d", "Pattern", "Delta"),
      ],
      edges: [
        { s: "a", t: "b" },
        { s: "b", t: "c" },
      ],
    });
  const treeShape = (t: ConceptTree | null): unknown =>
    t === null ? null : t.children.length ? [t.node.id, t.children.map((c) => treeShape(c))] : t.node.id;

  test("no selection keeps the flat alphabetical list", () => {
    const s = createVizState(listModel());
    expect(s.listing.tree).toBeNull();
    expect(s.listing.rest.map((n) => n.id)).toEqual(["a", "b", "d", "c"]); // Alpha, Beta, Delta, Gamma
  });

  test("selection with isolation off pins the anchor with direct links; rest excludes tree members", () => {
    const s = createVizState(listModel());
    s.selectConcept("a");
    expect(treeShape(s.listing.tree)).toEqual(["a", ["b"]]);
    expect(s.listing.rest.map((n) => n.id)).toEqual(["d", "c"]); // Delta, Gamma
  });

  test("isolation depth controls nesting depth and empties the rest", () => {
    const s = createVizState(listModel());
    s.selectConcept("a");
    s.setIsolate(2);
    expect(treeShape(s.listing.tree)).toEqual(["a", [["b", ["c"]]]]);
    expect(s.listing.rest).toHaveLength(0);
    s.setIsolate(1);
    expect(treeShape(s.listing.tree)).toEqual(["a", ["b"]]);
    expect(s.listing.rest).toHaveLength(0);
  });

  test("type filters prune the tree", () => {
    const s = createVizState(listModel());
    s.selectConcept("a");
    s.setIsolate(2);
    s.toggleType("Pattern"); // hides b and c
    expect(treeShape(s.listing.tree)).toBe("a");
    expect(s.listing.rest).toHaveLength(0);
  });

  test("a file view keeps the pin on the back concept at depth 1 with the rest expanded", () => {
    const s = createVizState(model());
    s.selectConcept("a");
    s.setIsolate(1);
    s.selectFile("scripts/okf/viz.ts");
    expect(treeShape(s.listing.tree)).toEqual(["a", ["b"]]); // anchored on backConcept
    expect(s.listing.rest.map((n) => n.id)).toEqual(["c"]); // isolation suspended: rest reappears
  });

  test("the anchor stays pinned under a non-matching search", () => {
    const s = createVizState(listModel());
    s.selectConcept("a");
    s.query = "gamma"; // matches only c, two hops away
    expect(treeShape(s.listing.tree)).toBe("a"); // b fails the search and is spliced out; anchor kept
    expect(s.listing.rest.map((n) => n.id)).toEqual(["c"]);
  });
});

describe("focusedConcept", () => {
  test("is the selection, or the last concept while a file/dir view is open", () => {
    const s = createVizState(model());
    expect(s.focusedConcept).toBeNull();
    s.selectConcept("a");
    expect(s.focusedConcept?.id).toBe("a");
    s.selectFile("scripts/okf/viz.ts");
    expect(s.focusedConcept?.id).toBe("a");
  });
});

describe("facet lenses", () => {
  const platModel = () =>
    buildModel({
      nodes: [
        node("modules/nh", "Darwin Module", "Nh"),
        node("modules/keyring", "NixOS Module", "Keyring"),
        node("modules/tmux", "Dual Module", "Tmux"), // unlisted type -> unresolved, always visible
        node("decisions/x", "Decision", "Decide"), // unlisted type -> unresolved, always visible
      ],
      edges: [],
      cfg: cfg(),
    });

  test("default is 'all' for every facet — every node visible", () => {
    const s = createVizState(platModel());
    expect(s.facetSel).toEqual({ platform: "all" });
    expect(s.visibleSorted).toHaveLength(4);
  });

  test("macos lens shows macos + unresolved concepts, hides linux-only", () => {
    const s = createVizState(platModel());
    s.setFacet("platform", "macos");
    expect(s.visibleSorted.map((n) => n.id).sort()).toEqual(["decisions/x", "modules/nh", "modules/tmux"]);
  });

  test("linux lens shows linux + unresolved concepts, hides macos-only", () => {
    const s = createVizState(platModel());
    s.setFacet("platform", "linux");
    expect(s.visibleSorted.map((n) => n.id).sort()).toEqual(["decisions/x", "modules/keyring", "modules/tmux"]);
  });

  test("composes via AND with type and search filters", () => {
    const s = createVizState(platModel());
    s.setFacet("platform", "macos"); // {nh, tmux, x}
    s.toggleType("Dual Module"); // remove tmux -> {nh, x}
    expect(s.visibleSorted.map((n) => n.id).sort()).toEqual(["decisions/x", "modules/nh"]);
    s.query = "nh"; // -> {nh}
    expect(s.visibleSorted.map((n) => n.id)).toEqual(["modules/nh"]);
  });

  test("setFacet clamps values outside the facet's configured values to 'all'", () => {
    const s = createVizState(platModel());
    s.setFacet("platform", "bogus");
    expect(s.facetSel.platform).toBe("all");
  });

  test("setFacet on an unknown facet name is a no-op", () => {
    const s = createVizState(platModel());
    s.setFacet("nope", "macos");
    expect(s.facetSel).toEqual({ platform: "all" });
  });

  test("a generic (no-config) model has no facet lenses at all", () => {
    const s = createVizState(model()); // no cfg -> facets []
    expect(s.facetSel).toEqual({});
    s.setFacet("platform", "macos");
    expect(s.facetSel).toEqual({});
    s.setFilters([], "", 0, { platform: "macos" });
    expect(s.facetSel).toEqual({});
  });

  test("a facet lens is global: it does NOT reset on clearSelection", () => {
    const s = createVizState(platModel());
    s.selectConcept("modules/nh");
    s.setFacet("platform", "macos");
    s.clearSelection();
    expect(s.facetSel.platform).toBe("macos"); // unlike isolate, which resets
  });

  test("setFilters accepts a facet-selection record (4th arg), defaults to 'all'", () => {
    const s = createVizState(platModel());
    s.setFilters([], "", 0, { platform: "linux" });
    expect(s.facetSel.platform).toBe("linux");
    s.setFilters([], "");
    expect(s.facetSel.platform).toBe("all");
  });

  test("multi-facet AND visibility: a concept must match every active facet's selection", () => {
    const m = buildModel({
      nodes: [
        node("a", "Darwin Module", "A", { fm: { status: "stable" } }),
        node("b", "Darwin Module", "B", { fm: { status: "draft" } }),
        node("c", "NixOS Module", "C", { fm: { status: "stable" } }),
      ],
      edges: [],
      cfg: {
        facet: {
          platform: { values: ["macos", "linux"], types: { "Darwin Module": "macos", "NixOS Module": "linux" } },
          status: { frontmatter: "status" },
        },
      },
    });
    const s = createVizState(m);
    s.setFacet("platform", "macos");
    expect(s.visibleSorted.map((n) => n.id).sort()).toEqual(["a", "b"]);
    s.setFacet("status", "stable");
    expect(s.visibleSorted.map((n) => n.id)).toEqual(["a"]); // must be macos AND stable
  });
});

describe("panel width", () => {
  test("default clamp: min(460, 85%) capped at 92%", () => {
    const s = createVizState(model());
    expect(s.panelPx(1000)).toBe(460);
    expect(s.panelPx(400)).toBe(340);
  });

  test("explicit width respected up to 92% of stage", () => {
    const s = createVizState(model());
    s.setPanelW(800);
    expect(s.panelPx(1000)).toBe(800);
    s.setPanelW(2000);
    expect(s.panelPx(1000)).toBe(920);
  });

  test("persistPanelW round-trips through localStorage", () => {
    const s = createVizState(model());
    s.setPanelW(555);
    s.persistPanelW();
    expect(localStorage.getItem("okfVizPanelW")).toBe("555");
    const s2 = createVizState(model());
    expect(s2.panelW).toBe(555);
  });
});

describe("legend collapse", () => {
  test("defaults to collapsed with no stored choice", () => {
    const s = createVizState(model());
    expect(s.legendCollapsed).toBe(true);
  });

  test("setLegendCollapsed persists and a fresh state picks up the stored value", () => {
    const s = createVizState(model());
    s.setLegendCollapsed(false);
    expect(localStorage.getItem("okfVizLegendCollapsed")).toBe("0");
    const s2 = createVizState(model());
    expect(s2.legendCollapsed).toBe(false);
  });
});

describe("palette", () => {
  test("unregistered types get stable generated colors", () => {
    const s = createVizState(model());
    const a = s.colorOf("Some Future Type");
    expect(a).toMatch(/^#[0-9a-f]{6}$/);
    expect(s.colorOf("Some Future Type")).toBe(a); // stable within an instance
    expect(createVizState(model()).colorOf("Some Future Type")).toBe(a); // and across
    expect(s.colorOf("Another Future Type")).not.toBe(a); // names get distinct hues
  });
});

describe("theme toggle", () => {
  const rootVar = (k: string) => document.documentElement.style.getPropertyValue(k);
  beforeEach(() => document.documentElement.removeAttribute("style"));
  afterEach(() => {
    localStorage.removeItem("okfVizTheme");
    document.documentElement.removeAttribute("style");
  });

  test("defaults to light (index 0) with no stored choice and light scheme", () => {
    const s = createVizState(model());
    expect(s.themeIndex).toBe(0);
    expect(rootVar("--page")).toBe(""); // no inline override until a pick
  });

  test("setTheme applies inline vars, persists, and bumps the palette", () => {
    const s = createVizState(model());
    const before = s.paletteVersion;
    s.setTheme(1);
    expect(s.themeIndex).toBe(1);
    expect(rootVar("--page")).toBe("#0d0d0d"); // dark
    expect(localStorage.getItem("okfVizTheme")).toBe("1");
    expect(s.paletteVersion).toBe(before + 1);
    s.setTheme(99); // out of range ignored
    expect(s.themeIndex).toBe(1);
  });

  test("stored choice restores and applies on startup", () => {
    localStorage.setItem("okfVizTheme", "1");
    const s = createVizState(model());
    expect(s.themeIndex).toBe(1);
    expect(rootVar("--page")).toBe("#0d0d0d"); // dark
  });

  test("OS scheme flip moves the toggle only while unpicked", () => {
    const s = createVizState(model());
    s.systemSchemeChanged(true);
    expect(s.themeIndex).toBe(1); // unpicked: follows OS to dark
    s.setTheme(0); // explicit pick: light, despite OS being dark
    s.systemSchemeChanged(true); // OS "flips" (stays dark); explicit pick must hold
    expect(s.themeIndex).toBe(0); // explicit pick wins
  });
});
